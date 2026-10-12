import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/domain/saved_account.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';

/// Hoja para cambiar de cuenta con un toque. La abre el perfil (estudiante y
/// docente), la barra lateral de escritorio y el atajo Ctrl/Cmd + Shift + A.
Future<void> showAccountSwitcher(BuildContext context, SessionService session) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: NexoTheme.bg,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => _AccountSwitcherSheet(session: session),
  );
}

class _AccountSwitcherSheet extends StatelessWidget {
  final SessionService session;
  const _AccountSwitcherSheet({required this.session});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final current = session.currentAccount;
        final accounts = session.savedAccounts;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.accountSwitchTitle,
                  style: TextStyle(
                    fontSize: AppFont.h3,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l.accountSwitchHint,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final a in accounts) ...[
                  AccountTile(
                    account: a,
                    isCurrent: a.user == current,
                    onTap: a.user == current
                        ? () => Navigator.of(context).pop()
                        : () {
                            Navigator.of(context).pop();
                            session.switchTo(a.user);
                          },
                    onRemove: a.user == current
                        ? null
                        : () async {
                            await session.forgetAccount(a.user);
                            if (context.mounted) {
                              ClipboardHelper.showSuccess(
                                context,
                                l.accountRemoved,
                              );
                            }
                          },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // La cuenta actual queda guardada para volver con un toque.
                    session.logout(forget: false);
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(l.accountAddAnother),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l.accountLogoutKeepHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFont.caption,
                    color: NexoTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Fila de una cuenta recordada: avatar, nombre, código y rol.
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.account,
    required this.onTap,
    this.isCurrent = false,
    this.onRemove,
    this.enabled = true,
  });

  final SavedAccount account;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final bool isCurrent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final roleColor = account.isTeacher ? NexoTheme.accent : NexoTheme.info;
    final subtitle = [
      account.user,
      if (!account.canQuickSwitch && !isCurrent) l.accountNeedsPassword,
    ].join(' · ');
    // El color va en el Material para que el efecto al tocar se vea.
    return Material(
      color: isCurrent
          ? Color.alphaBlend(
              NexoTheme.primary.withValues(alpha: 0.08),
              NexoTheme.card,
            )
          : NexoTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rLg,
        side: BorderSide(
          color: isCurrent
              ? NexoTheme.primary.withValues(alpha: 0.45)
              : NexoTheme.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: NexoTheme.primary.withValues(alpha: 0.14),
                child: Text(
                  account.initials,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 2,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: AppRadii.rPill,
                          ),
                          child: Text(
                            account.isTeacher
                                ? l.accountRoleTeacher
                                : l.accountRoleStudent,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: roleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFont.small,
                              color: NexoTheme.textMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: AppIcon.md,
                        color: NexoTheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l.accountCurrent,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w700,
                          color: NexoTheme.primary,
                        ),
                      ),
                    ],
                  ),
                )
              else if (onRemove != null)
                IconButton(
                  tooltip: l.accountRemove,
                  onPressed: enabled ? onRemove : null,
                  icon: Icon(
                    Icons.close_rounded,
                    size: AppIcon.md,
                    color: NexoTheme.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pantalla breve mientras se entra a otra cuenta. Evita que asome el login
/// entre la sesión anterior y la nueva.
class AccountSwitchingScreen extends StatelessWidget {
  const AccountSwitchingScreen({super.key, required this.account});
  final SavedAccount account;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: NexoTheme.primary.withValues(alpha: 0.14),
                  child: Text(
                    account.initials,
                    style: TextStyle(
                      fontSize: AppFont.h2,
                      fontWeight: FontWeight.w800,
                      color: NexoTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l.accountSwitching(account.label),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFont.title,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  account.user,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textMuted,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                ClipRRect(
                  borderRadius: AppRadii.rPill,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: NexoTheme.primary,
                    backgroundColor: NexoTheme.border,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
