/// Proof that a request to Nexo's backend comes from the genuine app.
///
/// The backend verifies a Firebase App Check token (Play Integrity on Android,
/// App Attest on iOS) sent in [header]. Until the Firebase project exists the
/// app uses [none], which sends nothing: the backend then accepts requests
/// only while its `APP_CHECK_MODE` is `monitor` or `off`.
///
/// To switch it on, add `firebase_core` and `firebase_app_check`, initialize
/// Firebase in `main.dart`, and pass an
/// implementation whose [token] returns `FirebaseAppCheck.instance.getToken()`.
abstract class AppAttestation {
  const AppAttestation();

  /// Header the backend reads the token from.
  static const String header = 'x-firebase-appcheck';

  /// No attestation (before Firebase is configured).
  static const AppAttestation none = _NoAttestation();

  /// A current token, or `null` when none can be obtained.
  Future<String?> token();
}

class _NoAttestation extends AppAttestation {
  const _NoAttestation();

  @override
  Future<String?> token() async => null;
}
