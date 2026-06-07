import 'package:flutter/material.dart';

/// Avatar/ícono de Lumen — el destello multicolor. Reemplaza al
/// `Icons.auto_awesome` con gradiente naranja que usábamos antes del
/// branding final.
///
/// La imagen ya trae sus propios colores y fondo transparente, por eso
/// no le ponemos un container con gradiente atrás — pisaría el look.
class LumenLogo extends StatelessWidget {
  const LumenLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/lumen_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Wordmark "LUMEN AI" en outline blanco con detalle ámbar/violeta.
/// Diseñado sobre fondo claro, conviene usarlo solo en headers o
/// pantallas con suficiente contraste.
class LumenWordmark extends StatelessWidget {
  const LumenWordmark({super.key, this.height = 24});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/lumen_wordmark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
