import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  // Change this URL to wherever you host the latest version info
  // Example: a raw GitHub file or your own JSON
  static const String versionUrl = 'https://raw.githubusercontent.com/clapp88/Streamred-Android/main/version.json';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Split-per-abi builds add an ABI offset (e.g. 2029 for build 29).
      final currentBuild = (int.tryParse(info.buildNumber) ?? 0) % 1000;

      final res = await http.get(Uri.parse(versionUrl)).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final latestBuild = data['build'] as int? ?? 0;
      final downloadUrl = data['url'] as String? ?? '';
      final message = data['message'] as String? ?? 'A new version is available.';

      if (latestBuild > currentBuild && downloadUrl.isNotEmpty && context.mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(downloadUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Download'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // Silent fail — don't block the app if the check fails
    }
  }
}
