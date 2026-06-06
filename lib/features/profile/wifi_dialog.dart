import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/l10n/app_localizations.dart';

/// Abre un dialog flotante con las credenciales Wi-Fi institucionales.
/// Carga datos vía [AppStore.loadWifi] si aún no están disponibles.
Future<void> showWifiDialog(BuildContext context, AppStore store) {
  if (!store.wifi.hasValue && !store.wifi.loading) {
    store.loadWifi();
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _WifiDialog(store: store),
  );
}

class _WifiDialog extends StatefulWidget {
  final AppStore store;
  const _WifiDialog({required this.store});

  @override
  State<_WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<_WifiDialog>
    with SingleTickerProviderStateMixin {
  bool _show = false;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  /// La contraseña Wi-Fi es **solo el DNI**. Si el backend la entrega con
  /// prefijo "U", se quita para mostrar el valor real.
  String _soloDni(String contrasena) {
    final t = contrasena.trim();
    if (t.length > 1 &&
        (t.startsWith('U') || t.startsWith('u')) &&
        RegExp(r'^\d+$').hasMatch(t.substring(1))) {
      return t.substring(1);
    }
    return t;
  }

  void _copy(String text, String msg) {
    ClipboardHelper.copyAndShow(context, text, label: msg);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.wifi;
        final codigo =
            widget.store.profile.value?.estId ?? state.value?.usuario ?? '';
        final pwd = _soloDni(state.value?.contrasena ?? '');

        return Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(
                CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _Card(
                      loading: state.loading && !state.hasValue,
                      codigo: codigo,
                      contrasena: pwd,
                      show: _show,
                      onToggle: () => setState(() => _show = !_show),
                      onClose: () => Navigator.of(context).pop(),
                      onCopyUser: () => _copy(
                        codigo,
                        AppLocalizations.of(context).wifiUserCopied,
                      ),
                      onCopyPwd: () => _copy(
                        pwd,
                        AppLocalizations.of(context).wifiPasswordCopied,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final bool loading;
  final String codigo;
  final String contrasena;
  final bool show;
  final VoidCallback onToggle;
  final VoidCallback onClose;
  final VoidCallback onCopyUser;
  final VoidCallback onCopyPwd;

  const _Card({
    required this.loading,
    required this.codigo,
    required this.contrasena,
    required this.show,
    required this.onToggle,
    required this.onClose,
    required this.onCopyUser,
    required this.onCopyPwd,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: NexoTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cabecera con gradient.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [NexoTheme.primary, NexoTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.xxl),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: AppRadii.rMd,
                  ),
                  child: const Icon(Icons.wifi_rounded,
                      color: Colors.white, size: 22),
                ),
                const Gap.h(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.wifiTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFont.h3,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.wifiSubtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: AppFont.small,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.actionClose,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          // Contenido.
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: loading
                ? const SizedBox(
                    height: 120,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CredentialRow(
                        label: l.wifiUserLabel,
                        value: codigo,
                        masked: false,
                        onCopy: onCopyUser,
                      ),
                      const Gap(AppSpacing.md),
                      _CredentialRow(
                        label: l.wifiPasswordLabel,
                        value: contrasena,
                        masked: !show,
                        toggleable: true,
                        showToggleActive: show,
                        onToggle: onToggle,
                        onCopy: onCopyPwd,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  final bool masked;
  final bool toggleable;
  final bool showToggleActive;
  final VoidCallback? onToggle;
  final VoidCallback onCopy;

  const _CredentialRow({
    required this.label,
    required this.value,
    required this.masked,
    required this.onCopy,
    this.toggleable = false,
    this.showToggleActive = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg - 2,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const Gap(AppSpacing.xs),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    masked ? '•' * value.length : value,
                    key: ValueKey(masked),
                    style: TextStyle(
                      fontSize: AppFont.subtitle,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textPrimary,
                      letterSpacing: masked ? 2 : 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (toggleable && onToggle != null)
            IconButton(
              tooltip: showToggleActive ? l.actionHide : l.actionShow,
              icon: Icon(
                showToggleActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: NexoTheme.textSecondary,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          IconButton(
            tooltip: l.actionCopy,
            icon: Icon(Icons.copy_rounded,
                color: NexoTheme.textSecondary, size: 20),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}
