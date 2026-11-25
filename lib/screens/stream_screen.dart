import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/api_service.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final url = widget.data['hlsUrl'] ?? widget.data['videoUrl'] ?? widget.data['url'];
    if (url != null && url.toString().isNotEmpty && url.toString() != 'null') {
      MiniPlayer.start(widget.nanoId, widget.data, url.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && MiniPlayer.isVisible) {
      MiniPlayer.enterPip();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final channel = widget.data['channelName'] ?? widget.data['username'] ?? '';
    final following = api.isFollowing(channel);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data['title'] ?? 'Watch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt),
            onPressed: MiniPlayer.enterPip,
            tooltip: 'Picture in Picture',
          ),
        ],
      ),
      body: Column(
        children: [
          if (MiniPlayer.chewie != null)
            AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: MiniPlayer.chewie!))
          else
            Container(
              height: 220,
              color: Colors.black,
              alignment: Alignment.center,
              child: const Text('No playback URL', style: TextStyle(color: Colors.white70)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(channel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                OutlinedButton(
                  onPressed: () => api.toggleFollow(channel),
                  child: Text(following ? 'Following' : 'Follow'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.favorite, size: 16), label: const Text('Donate')),
              ],
            ),
          ),
          const Expanded(child: Center(child: Text('Chat coming later'))),
        ],
      ),
    );
  }
}
