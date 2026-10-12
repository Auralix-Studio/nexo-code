/// Cuenta recordada en este dispositivo para el cambio rápido de cuenta.
///
/// Vive en el almacén seguro del sistema (Keychain / Keystore / DPAPI),
/// igual que la credencial de la sesión activa; en web solo en memoria.
class SavedAccount {
  const SavedAccount({
    required this.user,
    this.password,
    this.displayName = '',
    this.isTeacher = false,
    this.lastUsedMs = 0,
  });

  /// Código de usuario SIGMA, en mayúsculas.
  final String user;

  /// Contraseña guardada. `null` si dejó de ser válida (p. ej. la cambiaron
  /// desde SIGMA web): la cuenta sigue en la lista pero pide contraseña.
  final String? password;
  final String displayName;
  final bool isTeacher;
  final int lastUsedMs;

  bool get canQuickSwitch => (password ?? '').isNotEmpty;

  String get label => displayName.trim().isEmpty ? user : displayName.trim();

  /// Dos letras para el avatar: primer nombre + primer apellido.
  String get initials {
    final parts = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    // "NOMBRES APELLIDOS": el primer apellido cae a mitad de la lista.
    final apellido = parts[parts.length ~/ 2];
    return (parts.first.substring(0, 1) + apellido.substring(0, 1))
        .toUpperCase();
  }

  SavedAccount copyWith({
    String? password,
    bool clearPassword = false,
    String? displayName,
    bool? isTeacher,
    int? lastUsedMs,
  }) => SavedAccount(
    user: user,
    password: clearPassword ? null : (password ?? this.password),
    displayName: displayName ?? this.displayName,
    isTeacher: isTeacher ?? this.isTeacher,
    lastUsedMs: lastUsedMs ?? this.lastUsedMs,
  );

  Map<String, dynamic> toJson() => {
    'u': user,
    if (password != null) 'p': password,
    'n': displayName,
    't': isTeacher,
    'l': lastUsedMs,
  };

  static SavedAccount? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final user = raw['u'];
    if (user is! String || user.trim().isEmpty) return null;
    final p = raw['p'];
    final l = raw['l'];
    return SavedAccount(
      user: user.trim().toUpperCase(),
      password: p is String && p.isNotEmpty ? p : null,
      displayName: raw['n'] is String ? raw['n'] as String : '',
      isTeacher: raw['t'] == true,
      lastUsedMs: l is int ? l : 0,
    );
  }
}
