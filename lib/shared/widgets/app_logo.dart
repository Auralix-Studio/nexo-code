import 'package:flutter/material.dart';

/// Marca de Nexo utilizando el asset oficial generado.
class AppLogo extends StatelessWidget {
  final double size;
  final bool shadow;
  const AppLogo({super.key, this.size = 56, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    // cacheWidth limita la decodificación a ~3x el tamaño mostrado (suficiente
    // para retina) en vez de cargar el PNG a resolución completa en memoria.
    final cache = (size * 3).round();
    return Image.asset(
      'assets/icon.png',
      width: size,
      height: size,
      cacheWidth: cache,
      cacheHeight: cache,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
