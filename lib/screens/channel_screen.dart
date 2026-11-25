import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ChannelScreen extends StatelessWidget {
  final String name;
  const ChannelScreen({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final following = api.isFollowing(name);

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 48)),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => api.toggleFollow(name),
              child: Text(following ? 'Following' : 'Follow'),
            ),
            const SizedBox(height: 32),
            const Text('Channel content will appear here', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
