import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/core/design/tokens.dart';

const whatsappChannelUrl =
    'https://whatsapp.com/channel/0029VbDh4pf2ZjCfpiccSj3Y';
const whatsappGreen = Color(0xFF25D366);
Future<void> openWhatsappChannel() => launchUrl(
  Uri.parse(whatsappChannelUrl),
  mode: LaunchMode.externalApplication,
);
Future<void> maybeShowWhatsappInvite(BuildContext context) async {
  if (AppStorage.instance.seenWhatsappInvite) return;
  await AppStorage.instance.setSeenWhatsappInvite(true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _WhatsappInviteDialog(),
  );
}

class _WhatsappInviteDialog extends StatelessWidget {
  const _WhatsappInviteDialog();
  Future<void> _open(BuildContext context) async {
    await openWhatsappChannel();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NexoTheme.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxl,
            AppSpacing.xxl,
            18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: whatsappGreen.withValues(alpha: AppOpacity.tint),
                  borderRadius: AppRadii.rXl,
                  border: Border.all(
                    color: whatsappGreen.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: whatsappGreen.withValues(alpha: AppOpacity.tint),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  size: 28,
                  color: whatsappGreen,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppLocalizations.of(context).whatsappBannerTitle,
                style: TextStyle(
                  fontSize: AppFont.lead,
                  fontWeight: FontWeight.w900,
                  color: NexoTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.of(context).whatsappBannerDesc,
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textSecondary,
                  height: 1.45,
                  letterSpacing: -0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: AppIcon.sm),
                  label: Text(
                    AppLocalizations.of(context).whatsappBannerFollow,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: whatsappGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppFont.label,
                      fontWeight: FontWeight.w800,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rSm,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: NexoTheme.textMuted,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.snug,
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(AppLocalizations.of(context).whatsappBannerLater),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
