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

  Future<void> connect(String accessToken, String streamNanoId) async {
    await disconnect();
    messages.clear();
    error = null;
    connected = false;
    notifyListeners();

    final hubUrl = 'https://88streams.st/ws/chat?access_token=${Uri.encodeComponent(accessToken)}';

    connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000])
        .build();

    connection!.on('ReceiveMessage', (args) {
      _handleMessage(args);
    });

    connection!.on('receiveMessage', (args) {
      _handleMessage(args);
    });

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

  void _handleMessage(List<Object?>? args) {
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
    if (_seen.length > 300) _seen.remove(_seen.first);

    messages.add({
      'username': username,
      'content': content,
      'isBroadcaster': msg['isBroadcaster'] == true,
      'isModerator': msg['isModerator'] == true,
      'isVip': msg['isVip'] == true || msg['vip'] == true || msg['isVIP'] == true,
    });
    if (messages.length > 150) messages.removeAt(0);
    notifyListeners();
  }

  Future<void> send(String streamNanoId, String message) async {
    if (connection == null || !connected) return;
    try {
      await connection!.invoke('SendMessage', args: [streamNanoId, message]);
      // Do not add locally — the server will echo it back via ReceiveMessage
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
