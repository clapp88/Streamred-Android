import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import 'stream_screen.dart';
import 'shorts_viewer.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List categories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final list = await context.read<ApiService>().getCategories();
    if (mounted) setState(() { categories = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final c = categories[i];
                final name = c['name'] ?? c['title'] ?? c['id']?.toString() ?? 'Category';
                return ListTile(
                  title: Text(name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryBrowseScreen(name: name)));
                  },
                );
              },
            ),
    );
  }
}

class CategoryBrowseScreen extends StatefulWidget {
  final String name;
  const CategoryBrowseScreen({super.key, required this.name});

  @override
  State<CategoryBrowseScreen> createState() => _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends State<CategoryBrowseScreen> {
  List items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final list = await context.read<ApiService>().getCategoryContent(widget.name);
    if (mounted) setState(() { items = list; loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No content in this category'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final id = item['nanoId']?.toString() ?? '';
                    final isShort = item['isShort'] == true || item['videoType'] == 0;
                    final thumb = item['thumbnail'] ?? item['thumb'] ?? item['image'];
                    final thumbUrl = thumb != null ? (thumb.toString().startsWith('http') ? thumb : 'https://88streams.st$thumb') : null;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: InkWell(
                        onTap: () {
                          if (isShort) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ShortsViewer(shorts: [item], initialIndex: 0)));
                          } else if (id.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => StreamScreen(nanoId: id, data: Map<String, dynamic>.from(item))));
                          }
                        },
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
                                    errorWidget: (_, __, ___) => Container(color: Colors.grey[900], child: const Icon(Icons.image)),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'] ?? 'Untitled', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text(item['channelName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
