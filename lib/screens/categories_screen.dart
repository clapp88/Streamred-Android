import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

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
                    return ListTile(
                      title: Text(item['title'] ?? 'Untitled'),
                      subtitle: Text(item['channelName'] ?? ''),
                      onTap: () {
                        // Reuse existing open logic if possible
                      },
                    );
                  },
                ),
    );
  }
}
