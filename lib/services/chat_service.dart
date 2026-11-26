import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ChatService extends ChangeNotifier {
  HubConnection? connection;
  List<Map<String, dynamic>> messages = [];
  final Set<String> _seen = {};
  bool connected = false;
  String? error;
  int viewerCount = 0;
  String ticker = '';

  // Keeps messages per stream while the app is running
  static final Map<String, List<Map<String, dynamic>>> _cache = {};

  Future<void> connect(String accessToken, String streamNanoId) async {
    await disconnect();
    error = null;
    connected = false;

    // Restore saved messages for this stream
    messages = List<Map<String, dynamic>>.from(_cache[streamNanoId] ?? []);
    _seen
      ..clear()
      ..addAll(messages.map((m) => m['key']?.toString() ?? '').where((k) => k.isNotEmpty));
    notifyListeners();

    final hubUrl = 'https://88streams.st/ws/chat?access_token=${Uri.encodeComponent(accessToken)}';

    connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000])
        .build();

    connection!.on('ReceiveMessage', (args) => _handleMessage(args, streamNanoId));
    connection!.on('receiveMessage', (args) => _handleMessage(args, streamNanoId));

    connection!.on('ViewerCountUpdated', (args) {
      if (args != null && args.isNotEmpty) {
        viewerCount = (args[0] as num?)?.toInt() ?? 0;
        notifyListeners();
      }
    });

    connection!.on('TickerUpdated', (args) {
      if (args != null && args.isNotEmpty) {
        final data = args[0];
        if (data is Map) ticker = data['message']?.toString() ?? '';
        notifyListeners();
      }
    });

    connection!.on('RoomInfo', (args) {
      if (args != null && args.isNotEmpty) {
        final info = args[0];
        if (info is Map) {
          ticker = info['tickerMessage']?.toString() ?? '';
          viewerCount = (info['viewerCount'] as num?)?.toInt() ?? 0;
        }
        notifyListeners();
      }
    });

    try {
      await connection!.start();
      connected = true;
      await connection!.invoke('JoinChat', args: [streamNanoId]);
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      connected = false;
      notifyListeners();
    }
  }

  void _handleMessage(List<Object?>? args, String streamNanoId) {
    if (args == null || args.isEmpty) return;
    final raw = args[0];
    Map<String, dynamic> msg = {};
    if (raw is Map) {
      msg = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty && raw[0] is Map) {
      msg = Map<String, dynamic>.from(raw[0] as Map);
    }
    if (msg.isEmpty) return;

    final username = (msg['displayName'] ?? msg['username'] ?? msg['user'] ?? 'User').toString();
    final content = (msg['content'] ?? msg['message'] ?? '').toString();
    final id = (msg['id'] ?? msg['messageId'] ?? '').toString();

    final key = id.isNotEmpty ? id : '$username|$content|${DateTime.now().millisecondsSinceEpoch ~/ 2000}';
    if (_seen.contains(key)) return;
    _seen.add(key);
    if (_seen.length > 400) _seen.remove(_seen.first);

    final entry = {
      'key': key,
      'username': username,
      'content': content,
      'isBroadcaster': msg['isBroadcaster'] == true,
      'isModerator': msg['isModerator'] == true,
      'isVip': msg['isVip'] == true || msg['vip'] == true || msg['isVIP'] == true,
    };

    messages.add(entry);
    if (messages.length > 200) messages.removeAt(0);

    // Save to cache
    _cache[streamNanoId] = List<Map<String, dynamic>>.from(messages);

    notifyListeners();
  }

  Future<void> send(String streamNanoId, String message) async {
    if (connection == null || !connected) return;
    try {
      await connection!.invoke('SendMessage', args: [streamNanoId, message]);
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      await connection?.stop();
    } catch (_) {}
    connection = null;
    connected = false;
  }
}
