import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const StreamRedApp());
}

class StreamRedApp extends StatelessWidget {
  const StreamRedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ApiService()..loadToken(),
      child: Consumer<ApiService>(
        builder: (context, api, _) {
          return MaterialApp(
            title: 'StreamRed',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(primary: Colors.purple, surface: Color(0xFF18181B)),
              scaffoldBackgroundColor: const Color(0xFF0E0E10),
              appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF18181B), elevation: 0),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF18181B),
                selectedItemColor: Colors.purple,
                unselectedItemColor: Colors.grey,
              ),
            ),
            home: api.isLoggedIn ? const MainScreen() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
