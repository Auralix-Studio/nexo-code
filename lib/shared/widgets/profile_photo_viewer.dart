import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/util/formatters.dart';

/// Abre el visor de foto de perfil a pantalla completa estilo red social,
/// con animación Hero, fondo oscuro con blur, zoom interactivo y opción de copiar enlace.
Future<void> showProfilePhotoViewer(
  BuildContext context, {
  required String? code,
  required String name,
  required Object heroTag,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: ProfilePhotoViewer(
            code: code,
            name: name,
            heroTag: heroTag,
          ),
        );
      },
    ),
  );
}

class ProfilePhotoViewer extends StatefulWidget {
  final String? code;
  final String name;
  final Object heroTag;

  const ProfilePhotoViewer({
    super.key,
    required this.code,
    required this.name,
    required this.heroTag,
  });

  @override
  State<ProfilePhotoViewer> createState() => _ProfilePhotoViewerState();
}

class _ProfilePhotoViewerState extends State<ProfilePhotoViewer> {
  final TransformationController _transformCtrl = TransformationController();
  TapDownDetails? _doubleTapDetails;
  double _dragOffsetY = 0;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (_transformCtrl.value != Matrix4.identity()) {
      _transformCtrl.value = Matrix4.identity();
    } else if (_doubleTapDetails != null) {
      final position = _doubleTapDetails!.localPosition;
      final zoomed = Matrix4.identity();
      zoomed.setEntry(0, 0, 2.5);
      zoomed.setEntry(1, 1, 2.5);
      zoomed.setEntry(0, 3, -position.dx * 1.5);
      zoomed.setEntry(1, 3, -position.dy * 1.5);
      _transformCtrl.value = zoomed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = widget.code != null && widget.code!.trim().isNotEmpty;
    final photoUrl = hasCode ? AppConfig.photoUrlFor(widget.code!) : null;

    final backgroundOpacity = (1.0 - (_dragOffsetY.abs() / 400).clamp(0.0, 0.7)) * 0.94;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fondo oscuro con desenfoque animado y dismiss al tocar
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Colors.black.withValues(alpha: backgroundOpacity),
                ),
              ),
            ),
          ),

          // Foto central con gestos interactivos (zoom, pan, drag vertical para cerrar)
          SafeArea(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapDetails = details,
              onDoubleTap: _handleDoubleTap,
              onVerticalDragUpdate: (details) {
                setState(() {
                  _dragOffsetY += details.delta.dy;
                });
              },
              onVerticalDragEnd: (details) {
                if (_dragOffsetY.abs() > 100 || (details.primaryVelocity?.abs() ?? 0) > 400) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _dragOffsetY = 0;
                  });
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformCtrl,
                    minScale: 0.8,
                    maxScale: 4.0,
                    clipBehavior: Clip.none,
                    child: Hero(
                      tag: widget.heroTag,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        constraints: const BoxConstraints(
                          maxWidth: 380,
                          maxHeight: 460,
                        ),
                        decoration: BoxDecoration(
                          color: NexoTheme.card,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: photoUrl != null
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return SizedBox(
                                      height: 380,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          _LargeInitials(name: widget.name),
                                          CircularProgressIndicator(
                                            value: progress.expectedTotalBytes != null
                                                ? progress.cumulativeBytesLoaded /
                                                    progress.expectedTotalBytes!
                                                : null,
                                            color: NexoTheme.primary,
                                            strokeWidth: 2.5,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => _LargeInitials(
                                    name: widget.name,
                                    subtitle: 'Foto no disponible en SIGMA',
                                  ),
                                )
                              : _LargeInitials(
                                  name: widget.name,
                                  subtitle: 'Sin código de estudiante',
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Barra superior (Estilo redes sociales)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Botón cerrar
                    _GlassButton(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),

                    // Nombre y código
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.code != null && widget.code!.isNotEmpty)
                            Text(
                              widget.code!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Botón copiar enlace de la foto
                    if (photoUrl != null)
                      _GlassButton(
                        icon: Icons.link_rounded,
                        tooltip: 'Copiar enlace de foto',
                        onTap: () {
                          ClipboardHelper.copyAndShow(
                            context,
                            photoUrl,
                            label: 'Enlace de foto',
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.2),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

class _LargeInitials extends StatelessWidget {
  final String name;
  final String? subtitle;

  const _LargeInitials({
    required this.name,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 380,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            Fmt.initials(name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 84,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
