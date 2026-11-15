// Opciones de Firebase escritas a mano (sin flutterfire CLI), con los datos
// de android/app/google-services.json para pro.aurx.nexo.
//
// Solo Android: en el resto de plataformas no hay push y [currentPlatform]
// devuelve null, así que Firebase no se inicializa.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// Opciones de la plataforma actual, o `null` si no tiene push.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB0omVdOJSShq8a_Lxw8nARMGmcjHGZMKE',
    appId: '1:263762868243:android:6b8ae02ac1b6966594e7e6',
    messagingSenderId: '263762868243',
    projectId: 'nexo-85c19',
    storageBucket: 'nexo-85c19.firebasestorage.app',
  );
}
