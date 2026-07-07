import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/section_card.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SupportScreen()));
  Future<void> _launchWhatsApp(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final url = Uri.https('wa.me', '/51907924307', {
      'text': l.supportWhatsAppMessage,
    });
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    ClipboardHelper.copyAndShow(
      context,
      '+51 907 924 307',
      label: l.supportWhatsAppCopied,
    );
  }

  Future<void> _launchEmail(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final url = Uri(
      scheme: 'mailto',
      path: 'alessandrovillogas@outlook.es',
      queryParameters: {
        'asignatura': l.supportEmailSubject,
        'body': l.supportEmailBody,
      },
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
        return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    ClipboardHelper.copyAndShow(
      context,
      'alessandrovillogas@outlook.es',
      label: l.supportEmailCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(title: Text(l.supportTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [NexoTheme.primary, NexoTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: AppRadii.rXxl,
                    boxShadow: [
                      BoxShadow(
                        color: NexoTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: AppRadii.rPill,
                        ),
                        child: Text(
                          l.supportHeroBadge,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: AppFont.small,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      Text(
                        l.supportHeroTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: AppFont.h2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        l.supportHeroBody,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.lg),
                SectionCard(
                  title: l.supportChannelsTitle,
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: NexoTheme.primary,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => _launchWhatsApp(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF25D366,
                                  ).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_android_rounded,
                                  color: Color(0xFF25D366),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.supportChannelWhatsApp,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: NexoTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '+51 907 924 307',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: NexoTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: NexoTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(color: NexoTheme.border, height: 24),
                      InkWell(
                        onTap: () => _launchEmail(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: NexoTheme.info.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: NexoTheme.info,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.supportChannelEmail,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: NexoTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'alessandrovillogas@outlook.es',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: NexoTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: NexoTheme.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: NexoTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NexoTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: NexoTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.supportInfoNote,
                          style: TextStyle(
                            fontSize: 12,
                            color: NexoTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
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
