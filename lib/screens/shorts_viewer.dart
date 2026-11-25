import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ShortsViewer extends StatefulWidget {
  final List shorts;
  final int initialIndex;
  const ShortsViewer({super.key, required this.shorts, this.initialIndex = 0});

  @override
  State<ShortsViewer> createState() => _ShortsViewerState();
}

class _ShortsViewerState extends State<ShortsViewer> {
  late PageController pageController;
  final Map<int, VideoPlayerController> controllers = {};
  final Map<int, ChewieController> chewies = {};

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialIndex);
    _initController(widget.initialIndex);
  }

  void _initController(int index) {
    if (index < 0 || index >= widget.shorts.length) return;
    if (controllers.containsKey(index)) return;
    final url = widget.shorts[index]['videoUrl'];
    if (url == null) return;
    final fullUrl = url.toString().startsWith('http') ? url.toString() : 'https://88streams.st$url';
    final controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
    controllers[index] = controller;
    controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          chewies[index] = ChewieController(
            videoPlayerController: controller,
            autoPlay: true,
            looping: true,
            aspectRatio: 9 / 16,
            showControls: false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    for (final c in controllers.values) c.dispose();
    for (final ch in chewies.values) ch.dispose();
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.shorts.length,
        onPageChanged: (i) {
          _initController(i);
          _initController(i + 1);
        },
        itemBuilder: (context, index) {
          final short = widget.shorts[index];
          final chewie = chewies[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              if (chewie != null)
                Chewie(controller: chewie)
              else
                const Center(child: CircularProgressIndicator()),
              Positioned(
                left: 16,
                right: 80,
                bottom: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(short['channelName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(short['title'] ?? '', maxLines: 2, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
