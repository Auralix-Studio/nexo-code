import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';

/// Carrusel horizontal con los anuncios/banners institucionales de SIGMA.
class PublicacionesWidget extends StatefulWidget {
  final List<Publicacion> items;
  const PublicacionesWidget({super.key, required this.items});

  @override
  State<PublicacionesWidget> createState() => _PublicacionesWidgetState();
}

class _PublicacionesWidgetState extends State<PublicacionesWidget> {
  final _controller = PageController(viewportFraction: 0.92);
  int _idx = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _idx = i),
            itemBuilder: (_, i) => _Slide(p: widget.items[i]),
          ),
        ),
        const Gap(AppSpacing.sm),
        if (widget.items.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                  width: i == _idx ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _idx
                        ? NexoTheme.primary
                        : NexoTheme.border,
                    borderRadius: AppRadii.rPill,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Slide extends StatelessWidget {
  final Publicacion p;
  const _Slide({required this.p});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: AppRadii.rXl,
        child: p.esImagen && p.urlPrincipal.isNotEmpty
            ? Image.network(
                p.urlPrincipal,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, prog) =>
                    prog == null ? child : const _Placeholder(loading: true),
                errorBuilder: (_, _, _) => const _Placeholder(loading: false),
              )
            : const _Placeholder(loading: false),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool loading;
  const _Placeholder({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: NexoTheme.surface,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator(strokeWidth: 2)
          : Icon(
              Icons.image_outlined,
              size: 36,
              color: NexoTheme.textMuted,
            ),
    );
  }
}
