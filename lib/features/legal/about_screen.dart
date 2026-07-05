import 'package:flutter/material.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/app_logo.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/whatsapp_invite_dialog.dart';

class _Feature {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _Feature(this.icon, this.title, this.body, this.color);
}

List<_Feature> _features(AppLocalizations l) => <_Feature>[
  _Feature(
    Icons.dashboard_rounded,
    l.aboutFeatureAllInOneTitle,
    l.aboutFeatureAllInOneBody,
    NexoTheme.primary,
  ),
  _Feature(
    Icons.devices_rounded,
    l.aboutFeatureMultiplatformTitle,
    l.aboutFeatureMultiplatformBody,
    NexoTheme.accent,
  ),
  _Feature(
    Icons.lock_outline,
    l.aboutFeaturePrivacyTitle,
    l.aboutFeaturePrivacyBody,
    NexoTheme.info,
  ),
  _Feature(
    Icons.bolt_rounded,
    l.aboutFeatureNoSdkTitle,
    l.aboutFeatureNoSdkBody,
    NexoTheme.success,
  ),
];

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.titleAbout)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                const _Hero(),
                const Gap(AppSpacing.xl),
                for (final f in _features(l)) ...[
                  _FeatureCard(feature: f),
                  const Gap(AppSpacing.md),
                ],
                const Gap(AppSpacing.lg),
                _MetaCard(),
                const Gap(AppSpacing.lg),
                const _WhatsappRow(),
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

class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
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
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const AppLogo(size: 60),
          const Gap.h(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nexo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFont.h1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  l.aboutHeroSubtitle(AppConfig.appVersion),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: AppRadii.rMd,
            ),
            child: Icon(feature.icon, size: AppIcon.lg, color: feature.color),
          ),
          const Gap.h(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: AppFont.title,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const Gap(AppSpacing.sm),
                Text(
                  feature.body,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    height: 1.5,
                    color: NexoTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.aboutDetailsTitle,
      icon: Icons.info_outline,
      iconColor: NexoTheme.info,
      child: Column(
        children: [
          _MetaRow(
            label: l.aboutDetailsVersionLabel,
            value: AppConfig.appVersion,
          ),
          _MetaRow(
            label: l.aboutDetailsBuildLabel,
            value: '${AppConfig.appBuild}',
          ),
          _MetaRow(
            label: l.aboutDetailsPlatformsLabel,
            value: l.aboutDetailsPlatformsValue,
          ),
          _MetaRow(
            label: l.aboutDetailsTechLabel,
            value: l.aboutDetailsTechValue,
          ),
        ],
      ),
    );
  }
}

class _WhatsappRow extends StatelessWidget {
  const _WhatsappRow();
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: openWhatsappChannel,
      borderRadius: AppRadii.rXl,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: NexoTheme.surface,
          borderRadius: AppRadii.rXl,
          border: Border.all(color: NexoTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: whatsappGreen.withValues(alpha: 0.12),
                borderRadius: AppRadii.rMd,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                size: 18,
                color: whatsappGreen,
              ),
            ),
            const Gap.h(AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canal de WhatsApp',
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Síguenos para novedades y avisos de Nexo',
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: NexoTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFont.body,
                color: NexoTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppFont.body,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
