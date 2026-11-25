import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VodPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const VodPlayerScreen({super.key, required this.data});

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  VideoPlayerController? controller;
  ChewieController? chewie;

  @override
  void initState() {
    super.initState();
    final url = widget.data['videoUrl'] ?? widget.data['url'] ?? widget.data['hlsUrl'];
    if (url != null) {
      final full = url.toString().startsWith('http') ? url.toString() : 'https://88streams.st$url';
      controller = VideoPlayerController.networkUrl(Uri.parse(full));
      controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            chewie = ChewieController(
              videoPlayerController: controller!,
              autoPlay: true,
              aspectRatio: controller!.value.aspectRatio,
              showControls: true,
              allowFullScreen: true,
              allowMuting: true,
              showControlsOnInitialize: true,
            );
          });
        }
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    chewie?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: isLandscape ? null : AppBar(title: Text(widget.data['title'] ?? 'Video')),
      body: chewie == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: Chewie(controller: chewie!),
              ),
            ),
    );
  }
}
