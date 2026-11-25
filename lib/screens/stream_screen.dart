import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';

class MiniPlayer {
  static const platform = MethodChannel('com.streamred.app/pip');
  static Map<String, dynamic>? currentData;
  static String? currentId;
  static VideoPlayerController? controller;
  static ChewieController? chewie;
  static bool isVisible = false;

  static Future<void> enterPip() async {
    try {
      await platform.invokeMethod('enterPip');
    } catch (_) {}
  }

  static void start(String id, Map<String, dynamic> data, String url) {
    stop();
    currentId = id;
    currentData = data;
    controller = VideoPlayerController.networkUrl(Uri.parse(url));
    chewie = ChewieController(
      videoPlayerController: controller!,
      autoPlay: true,
      aspectRatio: 16 / 9,
      showControls: false,
    );
    isVisible = true;
  }

  static void stop() {
    controller?.dispose();
    chewie?.dispose();
    controller = null;
    chewie = null;
    currentData = null;
    currentId = null;
    isVisible = false;
  }
}

class StreamScreen extends StatefulWidget {
  final String nanoId;
  final Map<String, dynamic> data;
  const StreamScreen({super.key, required this.nanoId, required this.data});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> with WidgetsBindingObserver {
  bool inPip = false;
  final chatCtrl = TextEditingController();
  late ChatService chatService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    chatService = ChatService();
    final url = widget.data['hlsUrl'] ?? widget.data['videoUrl'] ?? widget.data['url'];
    if (url != null && url.toString().isNotEmpty && url.toString() != 'null') {
      MiniPlayer.start(widget.nanoId, widget.data, url.toString());
    }
    _startChat();
  }

  Future<void> _startChat() async {
    final api = context.read<ApiService>();
    if (api.isLoggedIn && api.token != null) {
      await chatService.connect(api.token!, widget.nanoId);
    }
  }

  Future<void> sendMessage() async {
    final text = chatCtrl.text.trim();
    if (text.isEmpty) return;
    await chatService.send(widget.nanoId, text);
    chatCtrl.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && MiniPlayer.isVisible) {
      MiniPlayer.enterPip();
      setState(() => inPip = true);
    } else if (state == AppLifecycleState.resumed) {
      setState(() => inPip = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    chatService.disconnect();
    chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final channel = widget.data['channelName'] ?? widget.data['username'] ?? '';
    final following = api.isFollowing(channel);

    return ChangeNotifierProvider.value(
      value: chatService,
      child: Scaffold(
        appBar: inPip
            ? null
            : AppBar(
                title: Text(widget.data['title'] ?? 'Watch', maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt),
                    onPressed: () {
                      MiniPlayer.enterPip();
                      setState(() => inPip = true);
                    },
                  ),
                ],
              ),
        body: inPip
            ? (MiniPlayer.chewie != null ? Chewie(controller: MiniPlayer.chewie!) : const Center(child: Text('No video')))
            : Column(
                children: [
                  if (MiniPlayer.chewie != null)
                    AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: MiniPlayer.chewie!))
                  else
                    Container(height: 220, color: Colors.black, alignment: Alignment.center, child: const Text('No playback URL', style: TextStyle(color: Colors.white70))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(channel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                        OutlinedButton(onPressed: () => api.toggleFollow(channel), child: Text(following ? 'Following' : 'Follow')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.favorite, size: 16), label: const Text('Donate')),
                      ],
                    ),
                  ),
                  Consumer<ChatService>(
                    builder: (context, chat, _) {
                      if (chat.ticker.isNotEmpty) {
                        return Container(
                          width: double.infinity,
                          color: Colors.purple.withOpacity(0.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Text(chat.ticker, style: const TextStyle(fontSize: 13)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Expanded(
                    child: Consumer<ChatService>(
                      builder: (context, chat, _) {
                        if (!chat.connected && chat.error != null) {
                          return Center(child: Text('Chat error: ${chat.error}', style: const TextStyle(color: Colors.red)));
                        }
                        return ListView.builder(
                          reverse: true,
                          itemCount: chat.messages.length,
                          itemBuilder: (_, i) {
                            final m = chat.messages[chat.messages.length - 1 - i];
                            final isBroadcaster = m['isBroadcaster'] == true;
                            final isModerator = m['isModerator'] == true;
                            final isVip = m['isVip'] == true || m['vip'] == true;
                            Color nameColor = Colors.white;
                            if (isBroadcaster) nameColor = Colors.red;
                            else if (isModerator) nameColor = Colors.green;
                            else if (isVip) nameColor = Colors.purple;

                            return ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  if (isBroadcaster) const Text('🔴 ', style: TextStyle(fontSize: 12)),
                                  if (isModerator) const Text('🛡️ ', style: TextStyle(fontSize: 12)),
                                  if (isVip) const Text('⭐ ', style: TextStyle(fontSize: 12)),
                                  Flexible(
                                    child: Text(
                                      m['username'] ?? '',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: nameColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(m['content'] ?? ''),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 48),
                    child: Row(
                      children: [
                        Expanded(child: TextField(controller: chatCtrl, decoration: const InputDecoration(hintText: 'Send a message...', border: OutlineInputBorder(), isDense: true))),
                        IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
