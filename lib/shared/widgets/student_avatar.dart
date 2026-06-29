import 'package:flutter/material.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/shared/util/formatters.dart';

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.code,
    required this.name,
    this.size = 56,
    this.radius,
    this.borderColor,
    this.gradient,
  });
  final String? code;
  final String name;
  final double size;
  final double? radius;
  final Color? borderColor;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.32;
    final defaultGradient = LinearGradient(
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
        child: code == null || code!.isEmpty
            ? _Initials(name: name, size: size)
            : Image.network(
                AppConfig.photoUrlFor(code!),
                fit: BoxFit.cover,
                width: size,
                height: size,
                cacheWidth: (size * 2).toInt(),
                gaplessPlayback: true,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return _Initials(name: name, size: size, dim: true);
                },
                errorBuilder: (_, _, _) => _Initials(name: name, size: size),
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String name;
  final double size;
  final bool dim;
  const _Initials({required this.name, required this.size, this.dim = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: dim ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
