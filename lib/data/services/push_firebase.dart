import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nexo/data/services/notification_service.dart';
import 'package:nexo/data/services/push_service.dart';
import 'package:nexo/firebase_options.dart';

/// [PushTransport] sobre Firebase Cloud Messaging. Nada de esto se ejecuta
/// hasta [initialize], y PushService solo la llama en Android.
class FirebasePushTransport implements PushTransport {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<void> initialize() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options == null) {
      throw UnsupportedError('Push no disponible en esta plataforma.');
    }
    await Firebase.initializeApp(options: options);
  }

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  // firebase_messaging 17 marca obsoletos getToken/onTokenRefresh en favor de
  // register()/onRegistered, que entregan un FID para «direct send». El
  // backend envía con el token de registro clásico (`message.token` de la
  // API HTTP v1), así que se sigue usando ese token.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map(_toPush);

  @override
  Stream<PushMessage> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map(_toPush);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _toPush(message);
  }

  static PushMessage _toPush(RemoteMessage m) => PushMessage(
    title: m.notification?.title,
    body: m.notification?.body,
    data: m.data.map((k, v) => MapEntry(k, '$v')),
  );
}

/// Muestra el push en primer plano con las notificaciones locales, en el
/// canal de notas; al tocarlo abre la pantalla de notas.
class LocalPushPresenter implements PushPresenter {
  const LocalPushPresenter();

  @override
  Future<void> createChannel() =>
      NotificationService.instance.createGradesChannel();

  @override
  Future<void> show(PushMessage message) =>
      NotificationService.instance.showPush(
        title: message.title ?? '',
        body: message.body ?? '',
        tag: message.data['course'],
        payload: message.isGrade ? NotificationService.payloadOpenGrades : null,
      );
}
