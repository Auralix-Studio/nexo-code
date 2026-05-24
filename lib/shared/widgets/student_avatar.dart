import 'package:flutter/material.dart';

import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/shared/util/formatters.dart';

/// Avatar del estudiante: carga la foto desde academico.upla.edu.pe
/// y cae a las iniciales del nombre si falla (404, sin red, etc.).
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.codigo,
    required this.nombre,
    this.size = 56,
    this.radius,
    this.borderColor,
    this.gradient,
  });

  final String? codigo;
  final String nombre;
  final double size;
  final double? radius;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.32;
    final defaultGradient = const LinearGradient(
      colors: [NexoTheme.primary, NexoTheme.accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? defaultGradient,
        borderRadius: BorderRadius.circular(r),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: codigo == null || codigo!.isEmpty
            ? _Initials(nombre: nombre, size: size)
            : Image.network(
                AppConfig.photoUrlFor(codigo!),
                fit: BoxFit.cover,
                width: size,
                height: size,
                cacheWidth: (size * 2).toInt(),
                gaplessPlayback: true,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _Initials(nombre: nombre, size: size, dim: true);
                },
                errorBuilder: (_, _, _) =>
                    _Initials(nombre: nombre, size: size),
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String nombre;
  final double size;
  final bool dim;
  const _Initials({required this.nombre, required this.size, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: dim ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
      child: Text(
        Fmt.initials(nombre),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
