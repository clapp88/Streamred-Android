import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'channel_screen.dart';

class StreamersScreen extends StatefulWidget {
  const StreamersScreen({super.key});

  @override
  State<StreamersScreen> createState() => _StreamersScreenState();
}

class _StreamersScreenState extends State<StreamersScreen> {
  List channels = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final list = await context.read<ApiService>().getChannels(limit: 200);
    final filtered = list.where((c) {
      final isLive = c['isLive'] == true;
      final followers = (c['followerCount'] as num?)?.toInt() ?? 0;
      return isLive || followers > 0;
    }).toList();
    if (mounted) setState(() { channels = filtered; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streamers')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: channels.length,
              itemBuilder: (_, i) {
                final c = channels[i];
                final name = c['channelName'] ?? c['username'] ?? c['name'] ?? 'Streamer';
                final avatar = c['avatar'] ?? c['channelAvatar'];
                final avatarUrl = avatar != null ? (avatar.toString().startsWith('http') ? avatar : 'https://88streams.st$avatar') : null;
                final isLive = c['isLive'] == true;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(name),
                  trailing: isLive ? const Chip(label: Text('LIVE', style: TextStyle(fontSize: 10)), backgroundColor: Colors.red, visualDensity: VisualDensity.compact) : null,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(name: name)));
                  },
                );
              },
            ),
    );
  }
}
