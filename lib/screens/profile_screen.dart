import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final user = api.user;
    final followed = api.followed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(child: CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48))),
          const SizedBox(height: 12),
          Center(child: Text(user?['username'] ?? user?['name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 4),
          Center(child: Text(user?['email'] ?? '', style: TextStyle(color: Colors.grey[400]))),
          const SizedBox(height: 32),
          const Text('Following', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (followed.isEmpty)
            const Text('You are not following anyone yet', style: TextStyle(color: Colors.grey))
          else
            ...followed.map((c) => ListTile(title: Text(c), trailing: const Icon(Icons.check))),
          const SizedBox(height: 32),
          OutlinedButton(onPressed: api.logout, child: const Text('Log Out')),
        ],
      ),
    );
  }
}
