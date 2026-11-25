import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VodPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const VodPlayerScreen({super.key, required this.data});

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  static const _pip = MethodChannel('com.streamred.app/pip');
  bool inPip = false;
  bool _autoPipOn = false;
  VideoPlayerController? controller;
  bool initialized = false;
  bool failed = false;
  bool showControls = true;
  bool dragging = false;
  double dragValue = 0;
  Timer? hideTimer;
  String? skipHint;
  Timer? hintTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.enable();
    _pip.setMethodCallHandler((call) async {
      if (call.method == 'pipChanged' && mounted) {
        final entered = call.arguments == true;
        setState(() {
          inPip = entered;
          if (entered) showControls = false;
        });
        if (entered) WakelockPlus.enable();
      }
    });
    _init();
  }

  Future<void> _init() async {
    final url = widget.data['videoUrl'] ?? widget.data['url'] ?? widget.data['hlsUrl'];
    if (url == null) {
      setState(() => failed = true);
      return;
    }
    final full = url.toString().startsWith('http') ? url.toString() : 'https://88streams.st$url';
    final c = VideoPlayerController.networkUrl(Uri.parse(full));
    controller = c;
    try {
      await c.initialize();
    } catch (_) {
      if (mounted) setState(() => failed = true);
      return;
    }
    if (!mounted) return;
    c.addListener(_onTick);
    setState(() => initialized = true);
    c.play();
    _scheduleHide();
  }

  void _onTick() {
    final playing = controller?.value.isPlaying == true;
    if (playing != _autoPipOn) _syncAutoPip(playing);
    if (mounted && !dragging) setState(() {});
  }

  Map<String, int> _pipSize() {
    final size = controller?.value.size;
    return {
      'width': (size != null && size.width > 0) ? size.width.round() : 16,
      'height': (size != null && size.height > 0) ? size.height.round() : 9,
    };
  }

  Future<void> _syncAutoPip(bool enabled) async {
    _autoPipOn = enabled;
    try {
      await _pip.invokeMethod('setAutoPip', {'enabled': enabled, ..._pipSize()});
    } catch (_) {}
  }

  Future<void> _enterPip() async {
    WakelockPlus.enable();
    try {
      final ok = await _pip.invokeMethod('enterPip', _pipSize());
      if (ok == true && mounted) {
        setState(() {
          inPip = true;
          showControls = false;
        });
      }
    } catch (_) {}
  }

  void _scheduleHide() {
    hideTimer?.cancel();
    hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && controller?.value.isPlaying == true && !dragging) {
        setState(() => showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => showControls = !showControls);
    if (showControls) _scheduleHide();
  }

  void _togglePlay() {
    final c = controller!;
    if (c.value.isPlaying) {
      c.pause();
      hideTimer?.cancel();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
      _scheduleHide();
    }
    setState(() {});
  }

  Future<void> _skip(Duration delta) async {
    final c = controller!;
    final total = c.value.duration;
    var target = c.value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > total) target = total;
    await c.seekTo(target);
    _flashHint(delta);
    if (showControls) _scheduleHide();
  }

  void _flashHint(Duration delta) {
    final secs = delta.inSeconds.abs();
    final label = secs >= 60 && secs % 60 == 0 ? '${secs ~/ 60} min' : '$secs sec';
    setState(() => skipHint = '${delta.isNegative ? '-' : '+'}$label');
    hintTimer?.cancel();
    hintTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => skipHint = null);
    });
  }

  Future<void> _toggleFullscreen() async {
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape) {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await Future.delayed(const Duration(milliseconds: 300));
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await Future.delayed(const Duration(milliseconds: 300));
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  @override
  void dispose() {
    hideTimer?.cancel();
    hintTimer?.cancel();
    _pip.setMethodCallHandler(null);
    _pip.invokeMethod('setAutoPip', {'enabled': false}).catchError((_) {});
    controller?.removeListener(_onTick);
    controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
  }

  double get _videoAspect {
    final size = controller!.value.size;
    if (size.width > 0 && size.height > 0) return size.width / size.height;
    final a = controller!.value.aspectRatio;
    return a > 0 ? a : 16 / 9;
  }

  Widget _skipButton(String label, Duration delta, {double size = 22}) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _skip(delta),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label, style: TextStyle(color: Colors.white, fontSize: size * 0.6, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _controls() {
    final c = controller!;
    final total = c.value.duration;
    final position = c.value.position > total ? total : c.value.position;
    final maxMs = total.inMilliseconds.toDouble();
    final current = dragging ? dragValue : position.inMilliseconds.toDouble().clamp(0, maxMs > 0 ? maxMs : 1);
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_fmt(Duration(milliseconds: current.toInt())), style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      activeTrackColor: Colors.red,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.red,
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      min: 0,
                      max: maxMs > 0 ? maxMs : 1,
                      value: current.toDouble(),
                      onChangeStart: (v) {
                        hideTimer?.cancel();
                        setState(() {
                          dragging = true;
                          dragValue = v;
                        });
                      },
                      onChanged: (v) => setState(() => dragValue = v),
                      onChangeEnd: (v) async {
                        await c.seekTo(Duration(milliseconds: v.toInt()));
                        if (mounted) setState(() => dragging = false);
                        _scheduleHide();
                      },
                    ),
                  ),
                ),
                Text(_fmt(total), style: const TextStyle(color: Colors.white, fontSize: 12)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                  tooltip: 'Pop out',
                  onPressed: _enterPip,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(landscape ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _skipButton('-5m', const Duration(minutes: -5)),
                  _skipButton('-1m', const Duration(minutes: -1)),
                  _skipButton('-10s', const Duration(seconds: -10)),
                  IconButton(
                    iconSize: 44,
                    icon: Icon(
                      c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlay,
                  ),
                  _skipButton('+10s', const Duration(seconds: 10)),
                  _skipButton('+1m', const Duration(minutes: 1)),
                  _skipButton('+5m', const Duration(minutes: 5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: (landscape || inPip)
          ? null
          : AppBar(
              title: Text(widget.data['title']?.toString() ?? 'Video'),
              actions: [
                if (initialized)
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt),
                    tooltip: 'Pop out',
                    onPressed: _enterPip,
                  ),
              ],
            ),
      body: failed
          ? const Center(child: Text('This video could not be played', style: TextStyle(color: Colors.white70)))
          : !initialized
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                  builder: (context, box) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _toggleControls,
                      onDoubleTapDown: (d) {
                        final left = d.localPosition.dx < box.maxWidth / 2;
                        _skip(Duration(seconds: left ? -10 : 10));
                      },
                      onDoubleTap: () {},
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: _videoAspect,
                              child: VideoPlayer(controller!),
                            ),
                          ),
                          if (controller!.value.isBuffering)
                            const Center(child: CircularProgressIndicator()),
                          if (skipHint != null && !inPip)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                                child: Text(skipHint!, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (showControls && !inPip)
                            Positioned(left: 0, right: 0, bottom: 0, child: _controls()),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
