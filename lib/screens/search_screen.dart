import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'stream_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ctrl = TextEditingController();
  Map results = {};
  bool searching = false;

  Future<void> doSearch() async {
    final q = ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() => searching = true);
    final data = await context.read<ApiService>().search(q);
    if (mounted) setState(() { results = data; searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final streams = (results['streams'] as List?) ?? [];
    final videos = (results['videos'] as List?) ?? [];
    final channels = (results['channels'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                filled: true,
              ),
              onSubmitted: (_) => doSearch(),
            ),
          ),
          if (searching) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                if (streams.isNotEmpty) const ListTile(title: Text('Streams', style: TextStyle(fontWeight: FontWeight.bold))),
                ...streams.map((s) => ListTile(
                      title: Text(s['title'] ?? ''),
                      subtitle: Text(s['channelName'] ?? ''),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreamScreen(nanoId: s['nanoId'] ?? '', data: Map<String, dynamic>.from(s)))),
                    )),
                if (videos.isNotEmpty) const ListTile(title: Text('Videos', style: TextStyle(fontWeight: FontWeight.bold))),
                ...videos.map((v) => ListTile(
                      title: Text(v['title'] ?? ''),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreamScreen(nanoId: v['nanoId'] ?? '', data: Map<String, dynamic>.from(v)))),
                    )),
                if (channels.isNotEmpty) const ListTile(title: Text('Channels', style: TextStyle(fontWeight: FontWeight.bold))),
                ...channels.map((c) => ListTile(title: Text(c['name'] ?? c['username'] ?? ''))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
