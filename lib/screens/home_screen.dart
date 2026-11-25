import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'categories_screen.dart';
import 'streamers_screen.dart';
import 'shorts_viewer.dart';
import 'channel_screen.dart';
import 'stream_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List streams = [];
  List shorts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final api = context.read<ApiService>();
    final s = await api.getStreams(limit: 30);
    final sh = await api.getShorts(limit: 20);
    if (mounted) {
      setState(() {
        streams = s;
        shorts = sh;
        loading = false;
      });
    }
  }

  void openItem(dynamic item) {
    final id = item['nanoId']?.toString() ?? '';
    final isShort = item['isShort'] == true || item['videoType'] == 0;
    if (isShort) {
      final index = shorts.indexWhere((s) => s['nanoId'] == id);
      Navigator.push(context, MaterialPageRoute(builder: (_) => ShortsViewer(shorts: shorts, initialIndex: index >= 0 ? index : 0)));
    } else if (id.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => StreamScreen(nanoId: id, data: Map<String, dynamic>.from(item))));
    }
  }

  void openChannel(String? name) {
    if (name != null && name.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelScreen(name: name)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = streams.where((s) => s['isLive'] == true).toList();
    final scheduled = streams.where((s) => s['isLive'] != true).toList();

    return Scaffold(
      appBar: AppBar(
        title: Image.asset('assets/logo.jpg', height: 36),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            child: const Text('Categories', style: TextStyle(fontSize: 16)),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StreamersScreen())),
            child: const Text('Streamers', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(
                children: [
                  if (live.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Live Now', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    ...live.map((s) => _Card(data: s, onTap: () => openItem(s), onChannel: () => openChannel(s['channelName']))),
                  ],
                  if (scheduled.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text('Scheduled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    ...scheduled.map((s) => _Card(data: s, isLive: false, onTap: () => openItem(s), onChannel: () => openChannel(s['channelName']))),
                  ],
                  if (shorts.isNotEmpty) ...[
                    const Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text('Shorts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    ...shorts.map((sh) => _Card(data: sh, isLive: false, isShort: true, onTap: () => openItem(sh), onChannel: () => openChannel(sh['channelName']))),
                  ],
                  if (live.isEmpty && scheduled.isEmpty && shorts.isEmpty)
                    const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No content right now'))),
                ],
              ),
            ),
    );
  }
}

class _Card extends StatelessWidget {
  final Map data;
  final bool isLive;
  final bool isShort;
  final VoidCallback onTap;
  final VoidCallback onChannel;
  const _Card({required this.data, this.isLive = true, this.isShort = false, required this.onTap, required this.onChannel});

  @override
  Widget build(BuildContext context) {
    final thumb = data['thumbnail'] ?? data['thumb'] ?? data['image'];
    final thumbUrl = thumb != null ? (thumb.toString().startsWith('http') ? thumb : 'https://88streams.st$thumb') : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thumbUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: isShort ? 9 / 16 : 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: Colors.grey[900]),
                    errorWidget: (_, __, ___) => Container(color: Colors.grey[900], child: const Icon(Icons.image, size: 40)),
                  ),
                ),
              )
            else
              Container(height: isShort ? 200 : 180, color: Colors.grey[900], child: const Center(child: Icon(Icons.videocam, size: 40))),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onChannel,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: data['avatar'] != null || data['channelAvatar'] != null
                          ? NetworkImage('https://88streams.st${data['avatar'] ?? data['channelAvatar']}')
                          : null,
                      child: (data['avatar'] == null && data['channelAvatar'] == null) ? const Icon(Icons.person, size: 18) : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['title'] ?? 'Untitled', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                        GestureDetector(
                          onTap: onChannel,
                          child: Text(data['channelName'] ?? data['username'] ?? '', style: const TextStyle(color: Colors.purple, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  if (isLive) const Chip(label: Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.red, visualDensity: VisualDensity.compact),
                  if (isShort) const Chip(label: Text('SHORT', style: TextStyle(color: Colors.white, fontSize: 10)), backgroundColor: Colors.purple, visualDensity: VisualDensity.compact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
