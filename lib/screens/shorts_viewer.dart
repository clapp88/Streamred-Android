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
  int currentIndex = 0;
  final Map<int, VideoPlayerController> controllers = {};
  final Map<int, ChewieController> chewies = {};

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: currentIndex);
    _prepare(currentIndex);
  }

  Future<void> _prepare(int index) async {
    if (index < 0 || index >= widget.shorts.length) return;
    if (controllers.containsKey(index)) return;

    final url = widget.shorts[index]['videoUrl'];
    if (url == null) return;
    final fullUrl = url.toString().startsWith('http') ? url.toString() : 'https://88streams.st$url';

    final controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
    controllers[index] = controller;
    await controller.initialize();
    if (!mounted) return;

    final chewie = ChewieController(
      videoPlayerController: controller,
      autoPlay: false,
      looping: true,
      showControls: false,
    );
    chewies[index] = chewie;
    setState(() {});
    if (index == currentIndex) {
      controller.play();
    }
  }

  void _pauseAllExcept(int keep) {
    for (final entry in controllers.entries) {
      if (entry.key != keep) {
        entry.value.pause();
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    for (final ch in chewies.values) {
      ch.dispose();
    }
    pageController.dispose();
    super.dispose();
  }

  Widget _fitted(VideoPlayerController c) {
    final size = c.value.size;
    final portrait = size.height > size.width;
    return SizedBox.expand(
      child: FittedBox(
        fit: portrait ? BoxFit.cover : BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(c)),
      ),
    );
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
          setState(() => currentIndex = i);
          _pauseAllExcept(i);
          _prepare(i);
          _prepare(i + 1);
          controllers[i]?.play();
        },
        itemBuilder: (context, index) {
          final short = widget.shorts[index];
          final isCurrent = index == currentIndex;

          return Stack(
            fit: StackFit.expand,
            children: [
              if (controllers[index] != null && controllers[index]!.value.isInitialized)
                _fitted(controllers[index]!)
              else
                const Center(child: CircularProgressIndicator()),
              if (isCurrent)
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
