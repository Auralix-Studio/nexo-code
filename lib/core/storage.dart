import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper delgado para persistencia local (token + datos básicos).
class AppStorage {
  AppStorage._(this._prefs);

  static AppStorage? _instance;
  final SharedPreferences _prefs;

  static Future<AppStorage> init() async {
    _instance ??= AppStorage._(await SharedPreferences.getInstance());
    return _instance!;
  }

  static AppStorage get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppStorage no inicializado — llama init() antes.');
    }
    return i;
  }

  static const _kToken = 'nexo.token';
  static const _kUser = 'nexo.user';
  static const _kTheme = 'nexo.themeMode';
  static const _kCredUser = 'nexo.cred.user';
  static const _kCredPass = 'nexo.cred.pass';
  static const _kCachePrefix = 'nexo.cache.';
  static const _kTerms = 'nexo.acceptedTerms';
  static const _kOnboard = 'nexo.seenOnboarding';
  static const _kNotifPrefs = 'nexo.notifPrefs';
  static const _kGradeSnap = 'nexo.gradeSnapshot';
  static const _kMsSession = 'nexo.ms.session';
  static const _kLocale = 'nexo.locale';
  static const _kUse24h = 'nexo.use24h';
  static const _kRunPortable = 'nexo.runPortable';
  static const _kWhatsappInvite = 'nexo.seenWhatsappInvite';
  static const _kFestivityDecor = 'nexo.festivityDecor';
  static const _kLumenModelId = 'nexo.lumen.modelId';
  static const _kIntranetCookies = 'nexo.intranet.cookies';
  static const _kIntranetUser = 'nexo.intranet.user';

  // ===== Autoupdater =====
  // Metadatos del último chequeo a GitHub Releases y del APK ya descargado
  // en disco (para no volver a bajarlo si el usuario aún no instaló).
  static const _kUpdLastCheckMs = 'nexo.upd.lastCheckMs';
  static const _kUpdLatestVer = 'nexo.upd.latestVer';
  static const _kUpdApkUrl = 'nexo.upd.apkUrl';
  static const _kUpdApkSize = 'nexo.upd.apkSize';
  static const _kUpdDownloadedVer = 'nexo.upd.downloadedVer';
  static const _kUpdApkPath = 'nexo.upd.apkPath';

  /// Preferencias de notificaciones (JSON serializado).
  String? get notifPrefsJson => _prefs.getString(_kNotifPrefs);
  Future<void> setNotifPrefsJson(String value) =>
      _prefs.setString(_kNotifPrefs, value);

  /// Snapshot de notas (firma) para detectar cambios.
  String? get gradeSnapshot => _prefs.getString(_kGradeSnap);
  Future<void> setGradeSnapshot(String value) =>
      _prefs.setString(_kGradeSnap, value);

  /// Sesión Microsoft (tokens + caducidad) serializada como JSON.
  /// Independiente de la sesión SIGMA.
  String? get msSessionJson => _prefs.getString(_kMsSession);
  Future<void> setMsSessionJson(String? value) async {
    if (value == null) {
      await _prefs.remove(_kMsSession);
    } else {
      await _prefs.setString(_kMsSession, value);
    }
  }

  bool get acceptedTerms => _prefs.getBool(_kTerms) ?? false;
  Future<void> setAcceptedTerms(bool v) => _prefs.setBool(_kTerms, v);

  bool get seenOnboarding => _prefs.getBool(_kOnboard) ?? false;
  Future<void> setSeenOnboarding(bool v) => _prefs.setBool(_kOnboard, v);

  bool get runPortable => _prefs.getBool(_kRunPortable) ?? false;
  Future<void> setRunPortable(bool v) => _prefs.setBool(_kRunPortable, v);

  bool get seenWhatsappInvite => _prefs.getBool(_kWhatsappInvite) ?? false;
  Future<void> setSeenWhatsappInvite(bool v) =>
      _prefs.setBool(_kWhatsappInvite, v);

  /// Adornos/animaciones de festividades (aniversario UPLA, Navidad, etc.).
  /// Activado por defecto; el usuario puede apagarlo en Configuración.
  bool get festivityDecor => _prefs.getBool(_kFestivityDecor) ?? true;
  Future<void> setFestivityDecor(bool v) =>
      _prefs.setBool(_kFestivityDecor, v);

  /// Id del modelo Lumen seleccionado por el usuario (ver LumenConfig.models).
  /// `null` si nunca eligió uno — el caller debe caer al default.
  String? get lumenModelId => _prefs.getString(_kLumenModelId);
  Future<void> setLumenModelId(String? value) async {
    if (value == null) {
      await _prefs.remove(_kLumenModelId);
    } else {
      await _prefs.setString(_kLumenModelId, value);
    }
  }

  /// Cookies persistidas de Intranet (PHPSESSID) — evita re-login en cold
  /// start. Pareadas con el usuario que las creó para invalidar si cambia.
  String? get intranetCookies => _prefs.getString(_kIntranetCookies);
  String? get intranetUser => _prefs.getString(_kIntranetUser);
  Future<void> setIntranetSession(String? cookies, String? user) async {
    if (cookies == null || user == null) {
      await _prefs.remove(_kIntranetCookies);
      await _prefs.remove(_kIntranetUser);
    } else {
      await _prefs.setString(_kIntranetCookies, cookies);
      await _prefs.setString(_kIntranetUser, user);
    }
  }

  /// 'light' | 'dark' | 'system'
  String? get themeMode => _prefs.getString(_kTheme);
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_kTheme, value);

  /// Código de idioma (`es`, `en`). Default = español.
  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String value) =>
      _prefs.setString(_kLocale, value);

  /// Formato de hora: true = 24h, false = 12h. Default = 24h.
  bool get use24h => _prefs.getBool(_kUse24h) ?? true;
  Future<void> setUse24h(bool value) => _prefs.setBool(_kUse24h, value);

  String? get token => _prefs.getString(_kToken);
  Future<void> setToken(String? value) async {
    if (value == null) {
      await _prefs.remove(_kToken);
    } else {
      await _prefs.setString(_kToken, value);
    }
  }

  String? get userJson => _prefs.getString(_kUser);
  Future<void> setUserJson(String? value) async {
    if (value == null) {
      await _prefs.remove(_kUser);
    } else {
      await _prefs.setString(_kUser, value);
    }
  }

  // ===== Credenciales (para re-login automático) =====
  // Nota: SharedPreferences no está cifrado. Aceptable para una app
  // personal; se ofuscan en base64 para no quedar en texto plano obvio.

  String? get credUser {
    final v = _prefs.getString(_kCredUser);
    if (v == null) return null;
    try {
      return utf8.decode(base64.decode(v));
    } catch (_) {
      return null;
    }
  }

  String? get credPass {
    final v = _prefs.getString(_kCredPass);
    if (v == null) return null;
    try {
      return utf8.decode(base64.decode(v));
    } catch (_) {
      return null;
    }
  }

  bool get hasCredentials =>
      (credUser?.isNotEmpty ?? false) && (credPass?.isNotEmpty ?? false);

  Future<void> setCredentials(String user, String pass) async {
    await _prefs.setString(_kCredUser, base64.encode(utf8.encode(user)));
    await _prefs.setString(_kCredPass, base64.encode(utf8.encode(pass)));
  }

  Future<void> clearCredentials() async {
    await _prefs.remove(_kCredUser);
    await _prefs.remove(_kCredPass);
  }

  // ===== Caché genérica (key → JSON + timestamp) =====

  Future<void> setCache(String key, Object data) async {
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    await _prefs.setString('$_kCachePrefix$key', payload);
  }

  /// Devuelve el contenido cacheado o null. [maxAge] opcional para invalidar.
  Object? getCache(String key, {Duration? maxAge}) {
    final raw = _prefs.getString('$_kCachePrefix$key');
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (maxAge != null) {
        final ts = m['ts'] as int? ?? 0;
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age > maxAge.inMilliseconds) return null;
      }
      return m['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCache() async {
    final keys =
        _prefs.getKeys().where((k) => k.startsWith(_kCachePrefix)).toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  // ===== Autoupdater =====

  int? get updLastCheckMs => _prefs.getInt(_kUpdLastCheckMs);
  Future<void> setUpdLastCheckMs(int value) =>
      _prefs.setInt(_kUpdLastCheckMs, value);

  String? get updLatestVer => _prefs.getString(_kUpdLatestVer);
  String? get updApkUrl => _prefs.getString(_kUpdApkUrl);
  int? get updApkSize => _prefs.getInt(_kUpdApkSize);

  Future<void> setUpdLatest({
    required String version,
    required String url,
    required int size,
  }) async {
    await _prefs.setString(_kUpdLatestVer, version);
    await _prefs.setString(_kUpdApkUrl, url);
    await _prefs.setInt(_kUpdApkSize, size);
  }

  Future<void> clearUpdLatest() async {
    await _prefs.remove(_kUpdLatestVer);
    await _prefs.remove(_kUpdApkUrl);
    await _prefs.remove(_kUpdApkSize);
  }

  String? get updDownloadedVer => _prefs.getString(_kUpdDownloadedVer);
  String? get updApkPath => _prefs.getString(_kUpdApkPath);

  Future<void> setUpdDownloaded(String version, String path) async {
    await _prefs.setString(_kUpdDownloadedVer, version);
    await _prefs.setString(_kUpdApkPath, path);
  }

  Future<void> clearUpdDownloaded() async {
    await _prefs.remove(_kUpdDownloadedVer);
    await _prefs.remove(_kUpdApkPath);
  }

  /// Limpia la sesión. [keepCredentials] permite el re-login automático.
  Future<void> clear({bool keepCredentials = true}) async {
    await _prefs.remove(_kToken);
    await _prefs.remove(_kUser);
    await clearCache();
    if (!keepCredentials) await clearCredentials();
  }
}
