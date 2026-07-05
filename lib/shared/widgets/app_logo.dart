import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool shadow;
  const AppLogo({super.key, this.size = 56, this.shadow = true});
  @override
  Widget build(BuildContext context) {
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
