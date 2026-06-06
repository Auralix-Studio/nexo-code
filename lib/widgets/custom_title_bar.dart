import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:nexo/core/design/theme.dart';

class CustomTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        border: Border(
          bottom: BorderSide(color: NexoTheme.border),
        ),
      ),
      child: Row(
        children: [
          // Icono y Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Image.asset('assets/icon.png', width: 18, height: 18),
                const SizedBox(width: 8),
                Text(
                  'Nexo UPLA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          // Área de Arrastre
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                bool isMax = await windowManager.isMaximized();
                if (isMax) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
          // Botones de Control
          const _WindowButtons(),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: Icons.remove_rounded,
          onTap: () => windowManager.minimize(),
        ),
        _ControlButton(
          icon: Icons.crop_square_rounded,
          onTap: () async {
            bool isMax = await windowManager.isMaximized();
            if (isMax) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _ControlButton(
          icon: Icons.close_rounded,
          hoverColor: NexoTheme.danger,
          iconHoverColor: Colors.white,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? hoverColor;
  final Color? iconHoverColor;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.hoverColor,
    this.iconHoverColor,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final themeHoverColor = widget.hoverColor ?? NexoTheme.primary.withValues(alpha: 0.08);
    final themeIconColor = _isHovered
        ? (widget.iconHoverColor ?? NexoTheme.primary)
        : NexoTheme.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 46,
          height: 40,
          color: _isHovered ? themeHoverColor : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: themeIconColor),
        ),
      ),
    );
  }
}
