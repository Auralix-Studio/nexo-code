import 'package:flutter/material.dart';

/// Marca de Nexo utilizando el asset oficial generado.
class AppLogo extends StatelessWidget {
  final double size;
  final bool shadow;
  const AppLogo({super.key, this.size = 56, this.shadow = true});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
