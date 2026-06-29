import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/section_card.dart';

const _devName = 'Alessandro';
const _devGithubLabel = 'github.com/Alexito-Hub';
const _devGithubUrl = 'https://github.com/Alexito-Hub';

class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});
  void _copyGithub(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: _devGithubUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).developerGithubCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.titleDeveloper)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SectionCard(
                  title: l.titleDeveloper,
                  subtitle: l.developerSubtitle,
                  icon: Icons.code_rounded,
                  iconColor: NexoTheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _devName,
                        style: TextStyle(
                          fontSize: AppFont.h2,
                          fontWeight: FontWeight.w900,
                          color: NexoTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Gap(AppSpacing.xs),
                      Text(
                        l.developerRole,
                        style: TextStyle(
                          fontSize: AppFont.body,
                          height: 1.5,
                          color: NexoTheme.textSecondary,
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      InkWell(
                        onTap: () => _copyGithub(context),
                        borderRadius: AppRadii.rMd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm + 2,
                          ),
                          decoration: BoxDecoration(
                            color: NexoTheme.primary.withValues(alpha: 0.06),
                            borderRadius: AppRadii.rMd,
                            border: Border.all(
                              color: NexoTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: AppIcon.md,
                                color: NexoTheme.primary,
                              ),
                              const Gap.h(AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _devGithubLabel,
                                  style: TextStyle(
                                    fontSize: AppFont.body,
                                    fontWeight: FontWeight.w600,
                                    color: NexoTheme.primary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.copy_rounded,
                                size: AppIcon.sm,
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
                Text(
                  l.aboutFooterDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    height: 1.5,
                    color: NexoTheme.textMuted,
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
