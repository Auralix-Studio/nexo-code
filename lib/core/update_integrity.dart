import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:nexo/core/config.dart';

class UpdateIntegrity {
  static String? digest(String? value) {
    if (value == null) return null;
    final raw = value.startsWith('sha256:') ? value.substring(7) : value;
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(raw)
        ? raw.toLowerCase()
        : null;
  }

  static bool releaseAsset(String url, String tag, String name) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path.toLowerCase() ==
            '/${UpdateConfig.repo}/releases/download/$tag/$name'.toLowerCase();
  }

  static Future<bool> verify(File file, String? expected, int? size) async {
    final hash = digest(expected);
    if (hash == null || !await file.exists()) return false;
    if (size != null && await file.length() != size) return false;
    return (await sha256.bind(file.openRead()).first).toString() == hash;
  }
}
