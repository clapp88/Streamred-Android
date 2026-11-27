import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/splash.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.play();
        }
      });
    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration && !_controller.value.isPlaying) {
        _next();
      }
    });
    Future.delayed(const Duration(milliseconds: 2500), _next);
  }

  bool _navigated = false;
  Future<void> _next() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Check for updates after splash
    await UpdateService.checkForUpdate(context);

    final prefs = await SharedPreferences.getInstance();
    final agreed = prefs.getBool('age_agreed') ?? false;
    if (!mounted) return;
    if (agreed) {
      final api = context.read<ApiService>();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => api.isLoggedIn ? const MainScreen() : const LoginScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AgeGateScreen()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : Image.asset('assets/logo.jpg', width: 220),
      ),
    );
  }
}

class AgeGateScreen extends StatelessWidget {
  const AgeGateScreen({super.key});

  Future<void> _agree(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('age_agreed', true);
    if (!context.mounted) return;
    final api = context.read<ApiService>();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => api.isLoggedIn ? const MainScreen() : const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.jpg', width: 160),
              const SizedBox(height: 40),
              const Text('18+ Only', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'You must be 18 years or older to use 88 Streams.\n\nBy continuing you confirm that you are 18 or older.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _agree(context),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('I am 18 or older', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
