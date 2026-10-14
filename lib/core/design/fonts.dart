/// Opciones de tipografía para toda la aplicación.
class NexoFontOption {
  final String id;
  final String name;
  final String description;

  /// Familia de fuente que Flutter usará (null para la fuente nativa del SO).
  final String? fontFamily;

  const NexoFontOption({
    required this.id,
    required this.name,
    required this.description,
    this.fontFamily,
  });

  /// Lista de tipografías sugeridas y empaquetadas en la app.
  static const List<NexoFontOption> presets = [
    NexoFontOption(
      id: 'Roboto',
      name: 'Roboto',
      description: 'Limpia, equilibrada y moderna',
      fontFamily: 'Roboto',
    ),
    NexoFontOption(
      id: 'system',
      name: 'Sistema (Nativa)',
      description: 'Fuente por defecto de tu dispositivo',
      fontFamily: null,
    ),
    NexoFontOption(
      id: 'Hypero',
      name: 'Hypero',
      description: 'Geométrica con carácter propio',
      fontFamily: 'Hypero',
    ),
    NexoFontOption(
      id: 'SuperMindset',
      name: 'Super Mindset',
      description: 'Display dinámica e informal',
      fontFamily: 'SuperMindset',
    ),
  ];

  /// Resuelve el nombre real de la familia de fuente a partir del id configurado.
  static String? resolveFontFamily(String? id) {
    if (id == null ||
        id.trim().isEmpty ||
        id.toLowerCase() == 'system' ||
        id.toLowerCase() == 'sistema') {
      return null;
    }
    final match = presets.where((p) => p.id == id).firstOrNull;
    if (match != null) return match.fontFamily;
    return id.trim();
  }

  /// Nombre amigable para mostrar en la interfaz.
  static String displayName(String? id) {
    if (id == null || id.isEmpty || id.toLowerCase() == 'system') {
      return 'Sistema';
    }
    final match = presets.where((p) => p.id == id).firstOrNull;
    return match?.name ?? id;
  }
}
