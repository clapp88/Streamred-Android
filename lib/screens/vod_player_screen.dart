import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VodPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const VodPlayerScreen({super.key, required this.data});

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  VideoPlayerController? controller;
  bool initialized = false;
  bool showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _init();
  }

  Future<void> _init() async {
    final url = widget.data['videoUrl'] ?? widget.data['url'] ?? widget.data['hlsUrl'];
    if (url == null) return;
    final full = url.toString().startsWith('http') ? url.toString() : 'https://88streams.st$url';
    controller = VideoPlayerController.networkUrl(Uri.parse(full));
    await controller!.initialize();
    if (mounted) {
      setState(() => initialized = true);
      controller!.play();
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape ? null : AppBar(title: Text(widget.data['title'] ?? 'Video')),
      body: !initialized
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => setState(() => showControls = !showControls),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller!),
                    ),
                  ),
                  if (showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(controller!.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  controller!.value.isPlaying ? controller!.pause() : controller!.play();
                                });
                              },
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                controller!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(playedColor: Colors.red),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
