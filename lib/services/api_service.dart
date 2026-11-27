import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'https://88streams.st';
  String? _token;
  Map<String, dynamic>? user;
  final Set<String> followed = {};

  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  String? get token => _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final saved = prefs.getStringList('followed') ?? [];
    followed.addAll(saved);
    if (isLoggedIn) {
      await fetchMe();
      await syncFollows();
    }
    notifyListeners();
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await fetchMe();
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    notifyListeners();
  }

  Future<void> toggleFollow(String channel) async {
    if (followed.contains(channel)) followed.remove(channel);
    else followed.add(channel);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('followed', followed.toList());
    notifyListeners();
  }

  bool isFollowing(String channel) => followed.contains(channel);

  Map<String, String> get headers {
    final h = {'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<bool> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'] ?? data['access_token'] ?? data['jwt'] ?? data['accessToken'] ?? data['bearer'];
        if (token != null && token.toString().isNotEmpty) {
          await saveToken(token.toString());
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchMe() async {
    if (!isLoggedIn) return;
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/auth/me'), headers: headers);
      if (res.statusCode == 200) {
        user = jsonDecode(res.body);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<List> getStreams({int limit = 40}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/streams?limit=$limit'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List> getVideos({int limit = 40}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/videos?limit=$limit'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List> getChannels({int limit = 100}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/channels?limit=$limit'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List> getCategories() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/categories'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<List> getCategoryContent(String idOrName) async {
    try {
      final encoded = Uri.encodeComponent(idOrName);
      final urls = [
        '$baseUrl/api/categories/$encoded/browse',
        '$baseUrl/api/videos?category=$encoded&limit=150',
        '$baseUrl/api/streams?category=$encoded&limit=150',
      ];
      for (final url in urls) {
        final res = await http.get(Uri.parse(url), headers: headers);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final list = data is List ? data : (data['data'] ?? data['streams'] ?? data['videos'] ?? []);
          if (list is List && list.isNotEmpty) return list;
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> syncFollows() async {
    if (!isLoggedIn) return;
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/users/me/following'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data is List ? data : (data['data'] ?? []);
        followed.clear();
        for (final item in list) {
          final name = item['channelName'] ?? item['username'] ?? item['name'];
          if (name != null) followed.add(name.toString());
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('followed', followed.toList());
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<List> getShorts({int limit = 80}) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/shorts?limit=$limit'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['data'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  Future<Map> search(String query) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/search?q=${Uri.encodeComponent(query)}&limit=40'), headers: headers);
      if (res.statusCode == 200) return jsonDecode(res.body);
    } catch (_) {}
    return {};
  }

  Future<List> getChat(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/streams/$id/chat?limit=80'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) return data;
        return data['data'] ?? data['messages'] ?? data['chat'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<bool> sendChat(String id, String message) async {
    if (!isLoggedIn) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/streams/$id/chat'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );
      return res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204;
    } catch (_) {}
    return false;
  }
}
