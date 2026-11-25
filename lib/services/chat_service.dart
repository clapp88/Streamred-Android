import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';

class ChatService extends ChangeNotifier {
  HubConnection? connection;
  List<Map<String, dynamic>> messages = [];
  bool connected = false;
  String? error;
  int viewerCount = 0;
  String ticker = '';

  Future<void> connect(String accessToken, String streamNanoId) async {
    await disconnect();
    messages.clear();
    error = null;
    connected = false;

    final hubUrl = 'https://88streams.st/ws/chat?access_token=${Uri.encodeComponent(accessToken)}';

    connection = HubConnectionBuilder()
        .withUrl(hubUrl)
        .withAutomaticReconnect()
        .build();

    connection!.on('ReceiveMessage', (args) {
      if (args != null && args.isNotEmpty) {
        final msg = args[0] as Map<String, dynamic>? ?? {};
        messages.add({
          'username': msg['displayName'] ?? msg['username'] ?? 'User',
          'content': msg['content'] ?? '',
          'isBroadcaster': msg['isBroadcaster'] ?? false,
          'isModerator': msg['isModerator'] ?? false,
        });
        if (messages.length > 100) messages.removeAt(0);
        notifyListeners();
      }
    });

    connection!.on('ViewerCountUpdated', (args) {
      if (args != null && args.isNotEmpty) {
        viewerCount = args[0] as int? ?? 0;
        notifyListeners();
      }
    });

    connection!.on('TickerUpdated', (args) {
      if (args != null && args.isNotEmpty) {
        final data = args[0] as Map<String, dynamic>? ?? {};
        ticker = data['message'] ?? '';
        notifyListeners();
      }
    });

    connection!.on('RoomInfo', (args) {
      if (args != null && args.isNotEmpty) {
        final info = args[0] as Map<String, dynamic>? ?? {};
        ticker = info['tickerMessage'] ?? '';
        viewerCount = info['viewerCount'] ?? 0;
        notifyListeners();
      }
    });

    try {
      await connection!.start();
      connected = true;
      await connection!.invoke('JoinChat', args: [streamNanoId]);
      notifyListeners();
    } catch (e) {
      error = e.toString();
      connected = false;
      notifyListeners();
    }
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
