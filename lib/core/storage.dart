import 'dart:convert';
import 'package:nexo/core/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/config.dart';

class AppStorage {
  AppStorage._(this._prefs, this._secrets);
  static AppStorage? _instance;
  final SharedPreferences _prefs;
  final SecretStore _secrets;
  final Map<String, String> _auth = {};
  Future<void> _writes = Future.value();
  static const _authKey = 'nexo.auth.v1';

  static Future<AppStorage> init({SecretStore? secrets}) async {
    if (_instance != null && secrets == null) return _instance!;
    final storage = AppStorage._(
      await SharedPreferences.getInstance(),
      secrets ?? createSecretStore(),
    );
    await storage._loadSecrets();
    _instance = storage;
    return storage;
  }

  Future<void> _loadSecrets() async {
    const legacyKeys = [
      _kToken,
      _kUser,
      _kCredUser,
      _kCredPass,
      _kIntranetCookies,
      _kIntranetUser,
    ];
    try {
      final saved = await _secrets.read(_authKey);
      if (saved != null) {
        _auth.addAll(Map<String, String>.from(jsonDecode(saved) as Map));
      } else {
        // Old preferences caches have no owner and cannot be trusted after
        // upgrading from a version that allowed cross-account responses.
        await clearCache();
        await _prefs.remove(_kGradeSnap);
        for (final key in legacyKeys) {
          var value = _prefs.getString(key);
          if (value == null) continue;
          if (key == _kCredUser || key == _kCredPass) {
            try {
              value = utf8.decode(base64.decode(value));
            } catch (_) {
              continue;
            }
          }
          _auth[key] = value;
        }
        if (_auth.isNotEmpty) await _secrets.write(_authKey, jsonEncode(_auth));
      }
    } finally {
      // Never leave reusable secrets in preferences, even if the vault fails.
      for (final key in legacyKeys) {
        await _prefs.remove(key);
      }
    }
  }

  Future<void> _updateAuth(Map<String, String?> changes) {
    for (final entry in changes.entries) {
      if (entry.value == null) {
        _auth.remove(entry.key);
      } else {
        _auth[entry.key] = entry.value!;
      }
    }
    final snapshot = _auth.isEmpty ? null : jsonEncode(_auth);
    final write = _writes.then((_) => _secrets.write(_authKey, snapshot));
    // Preserve ordering after errors; report the failure to the original caller.
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  Future<void> setAuthenticatedSession({
    required String token,
    required String account,
    required String password,
    String? userJson,
  }) => _updateAuth({
    _kToken: token,
    _kCredUser: account,
    _kCredPass: password,
    _kUser: userJson,
  });

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
  static const _kTermsVersion = 'nexo.acceptedTermsVersion';
  static const _kOnboard = 'nexo.seenOnboarding';
  static const _kNotifPrefs = 'nexo.notifPrefs';
  static const _kGradeSnap = 'nexo.gradeSnapshot';
  static const _kLocale = 'nexo.locale';
  static const _kUse24h = 'nexo.use24h';
  static const _kRunPortable = 'nexo.runPortable';
  static const _kWhatsappInvite = 'nexo.seenWhatsappInvite';
  static const _kFestivityDecor = 'nexo.festivityDecor';
  static const _kIntranetCookies = 'nexo.intranet.cookies';
  static const _kIntranetUser = 'nexo.intranet.user';
  static const _kUpdLastCheckMs = 'nexo.upd.lastCheckMs';
  static const _kUpdLatestVer = 'nexo.upd.latestVer';
  static const _kUpdApkUrl = 'nexo.upd.apkUrl';
  static const _kUpdApkSize = 'nexo.upd.apkSize';
  static const _kUpdSha256 = 'nexo.upd.sha256';
  static const _kUpdDownloadedVer = 'nexo.upd.downloadedVer';
  static const _kUpdApkPath = 'nexo.upd.apkPath';
  static const _kDashboardConfig = 'nexo.dashboardConfig';
  String? get notifPrefsJson => _prefs.getString(_kNotifPrefs);
  Future<void> setNotifPrefsJson(String value) =>
      _prefs.setString(_kNotifPrefs, value);
  String? get gradeSnapshot => _prefs.getString(_kGradeSnap);
  Future<void> setGradeSnapshot(String value) =>
      _prefs.setString(_kGradeSnap, value);
  String? get dashboardConfigJson => _prefs.getString(_kDashboardConfig);
  Future<void> setDashboardConfigJson(String value) =>
      _prefs.setString(_kDashboardConfig, value);

  /// Aceptados **estos** términos, no unos cualesquiera: si sube
  /// `LegalTerms.version` la aceptación anterior deja de valer y se vuelven a
  /// mostrar.
  bool get acceptedTerms => acceptedTermsVersion >= LegalTerms.version;

  int get acceptedTermsVersion {
    final stored = _prefs.getInt(_kTermsVersion);
    if (stored != null) return stored;
    // Antes solo se guardaba un booleano: quien ya había aceptado cuenta como
    // que aceptó la primera versión.
    return (_prefs.getBool(_kTerms) ?? false) ? 1 : 0;
  }

  Future<void> setAcceptedTerms(bool v) async {
    await _prefs.setBool(_kTerms, v);
    await _prefs.setInt(_kTermsVersion, v ? LegalTerms.version : 0);
  }

  bool get seenOnboarding => _prefs.getBool(_kOnboard) ?? false;
  Future<void> setSeenOnboarding(bool v) => _prefs.setBool(_kOnboard, v);
  bool get runPortable => _prefs.getBool(_kRunPortable) ?? false;
  Future<void> setRunPortable(bool v) => _prefs.setBool(_kRunPortable, v);
  bool get seenWhatsappInvite => _prefs.getBool(_kWhatsappInvite) ?? false;
  Future<void> setSeenWhatsappInvite(bool v) =>
      _prefs.setBool(_kWhatsappInvite, v);
  bool get festivityDecor => _prefs.getBool(_kFestivityDecor) ?? true;
  Future<void> setFestivityDecor(bool v) => _prefs.setBool(_kFestivityDecor, v);
  String? get intranetCookies => _auth[_kIntranetCookies];
  String? get intranetUser => _auth[_kIntranetUser];
  Future<void> setIntranetSession(String? cookies, String? user) =>
      _updateAuth({_kIntranetCookies: cookies, _kIntranetUser: user});

  String? get themeMode => _prefs.getString(_kTheme);
  Future<void> setThemeMode(String value) => _prefs.setString(_kTheme, value);
  String? get localeCode => _prefs.getString(_kLocale);
  Future<void> setLocaleCode(String value) => _prefs.setString(_kLocale, value);
  bool get use24h => _prefs.getBool(_kUse24h) ?? true;
  Future<void> setUse24h(bool value) => _prefs.setBool(_kUse24h, value);
  String? get token => _auth[_kToken];
  Future<void> setToken(String? value) => _updateAuth({_kToken: value});
  String? get userJson => _auth[_kUser];
  Future<void> setUserJson(String? value) => _updateAuth({_kUser: value});
  String? get credUser => _auth[_kCredUser];
  String? get credPass => _auth[_kCredPass];
  bool get hasCredentials =>
      (credUser?.isNotEmpty ?? false) && (credPass?.isNotEmpty ?? false);
  Future<void> setCredentials(String user, String pass) =>
      _updateAuth({_kCredUser: user, _kCredPass: pass});
  Future<void> clearCredentials() =>
      _updateAuth({_kCredUser: null, _kCredPass: null});

  Future<void> setCache(String key, Object data) async {
    final payload = jsonEncode({
      'ts': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
    await _prefs.setString('$_kCachePrefix$key', payload);
  }

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
    final keys = _prefs
        .getKeys()
        .where((k) => k.startsWith(_kCachePrefix))
        .toList();
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }

  int? get updLastCheckMs => _prefs.getInt(_kUpdLastCheckMs);
  Future<void> setUpdLastCheckMs(int value) =>
      _prefs.setInt(_kUpdLastCheckMs, value);
  String? get updLatestVer => _prefs.getString(_kUpdLatestVer);
  String? get updApkUrl => _prefs.getString(_kUpdApkUrl);
  int? get updApkSize => _prefs.getInt(_kUpdApkSize);
  String? get updSha256 => _prefs.getString(_kUpdSha256);
  Future<void> setUpdLatest({
    required String version,
    required String url,
    required int size,
    String? sha256,
  }) async {
    await _prefs.setString(_kUpdLatestVer, version);
    await _prefs.setString(_kUpdApkUrl, url);
    await _prefs.setInt(_kUpdApkSize, size);
    if (sha256 == null) {
      await _prefs.remove(_kUpdSha256);
    } else {
      await _prefs.setString(_kUpdSha256, sha256);
    }
  }

  Future<void> clearUpdLatest() async {
    await _prefs.remove(_kUpdLatestVer);
    await _prefs.remove(_kUpdApkUrl);
    await _prefs.remove(_kUpdApkSize);
    await _prefs.remove(_kUpdSha256);
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

  Future<void> clear({bool keepCredentials = true}) async {
    final cleared = _updateAuth({
      _kToken: null,
      _kUser: null,
      _kIntranetCookies: null,
      _kIntranetUser: null,
      if (!keepCredentials) _kCredUser: null,
      if (!keepCredentials) _kCredPass: null,
    });
    await clearCache();
    await _prefs.remove(_kGradeSnap);
    await cleared;
  }
}
