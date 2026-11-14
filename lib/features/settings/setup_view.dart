import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/win_setup_service.dart';
import 'package:nexo/features/settings/install_dialog.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/core/design/tokens.dart';

enum InstallProgressStep {
  preparing,
  copying,
  shortcuts,
  registering,
  autoStart,
  done,
  error,
}

class InstallView extends StatefulWidget {
  final InstallOptions options;
  const InstallView({super.key, required this.options});
  @override
  State<InstallView> createState() => _InstallViewState();
}

class _InstallViewState extends State<InstallView> {
  InstallProgressStep _step = InstallProgressStep.preparing;
  double _progress = 0.0;
  String _errorMessage = "";
  @override
  void initState() {
    super.initState();
    _startInstallation();
  }

  Future<void> _startInstallation() async {
    try {
      await WinSetupService.copyApplicationFiles(
        onProgress: (p) {
          setState(() {
            _step = InstallProgressStep.copying;
            _progress = p * 0.70;
          });
        },
      );
      if (widget.options.desktopShortcut || widget.options.startMenuShortcut) {
        setState(() {
          _step = InstallProgressStep.shortcuts;
          _progress = 0.75;
        });
        await WinSetupService.createShortcuts(
          desktop: widget.options.desktopShortcut,
          startMenu: widget.options.startMenuShortcut,
        );
      }
      setState(() {
        _step = InstallProgressStep.registering;
        _progress = 0.85;
      });
      await WinSetupService.registerUninstall(version: AppConfig.appVersion);
      if (widget.options.autoStart) {
        setState(() {
          _step = InstallProgressStep.autoStart;
          _progress = 0.95;
        });
        await WinSetupService.registerAutoStart();
      } else {
        await WinSetupService.removeAutoStart();
      }
      setState(() {
        _step = InstallProgressStep.done;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _step = InstallProgressStep.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _launchAppAndExit() async {
    await WinSetupService.cleanupStaging();
    await Process.start(
      WinSetupService.officialExePath,
      [],
      mode: ProcessStartMode.detached,
    );
    Future<void>.delayed(const Duration(milliseconds: 500), () => exit(0));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_step == InstallProgressStep.error) {
      content = _buildErrorView();
    } else if (_step == InstallProgressStep.done) {
      content = _buildSuccessView();
    } else {
      content = _buildProgressView();
    }
    return installerButtonScope(context, content);
  }

  Widget _buildProgressView() {
    final l = AppLocalizations.of(context);
    String stepLabel = "";
    switch (_step) {
      case InstallProgressStep.preparing:
        stepLabel = l.setupProgressCopied;
        break;
      case InstallProgressStep.copying:
        final pct = (_progress / 0.70 * 100).toStringAsFixed(0);
        stepLabel = "${l.setupProgressCopied} ($pct%)";
        break;
      case InstallProgressStep.shortcuts:
        stepLabel = l.setupProgressShortcuts;
        break;
      case InstallProgressStep.registering:
        stepLabel = l.setupProgressRegister;
        break;
      case InstallProgressStep.autoStart:
        stepLabel = l.setupProgressAutoStart;
        break;
      default:
        stepLabel = "";
    }
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(NexoTheme.success),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              stepLabel,
              style: TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ClipRRect(
              borderRadius: AppRadii.rSm,
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: NexoTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(NexoTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: NexoTheme.success,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.setupSuccessTitle,
              style: TextStyle(
                fontSize: AppFont.heading,
                fontWeight: FontWeight.w900,
                color: NexoTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.tight),
            Text(
              l.setupSuccessDesc,
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ElevatedButton.icon(
              onPressed: _launchAppAndExit,
              icon: const Icon(Icons.play_arrow_rounded, size: AppIcon.sm),
              label: Text(l.setupBtnStart),
              style: ElevatedButton.styleFrom(
                backgroundColor: NexoTheme.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.snug,
                ),
                textStyle: const TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.w700,
                ),
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXs),
                elevation: 0,
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: NexoTheme.danger,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.setupErrorTitle,
              style: TextStyle(
                fontSize: AppFont.h3,
                fontWeight: FontWeight.w900,
                color: NexoTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              child: Text(
                _errorMessage,
                style: const TextStyle(
                  fontSize: AppFont.caption,
                  fontFamily: 'Courier',
                  color: NexoTheme.danger,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _step = InstallProgressStep.preparing;
                      _progress = 0.0;
                      _errorMessage = "";
                    });
                    _startInstallation();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NexoTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.snug,
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rXs,
                    ),
                    side: BorderSide(color: NexoTheme.border),
                  ),
                  child: Text(l.setupBtnRetry),
                ),
                const SizedBox(width: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => exit(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NexoTheme.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.snug,
                    ),
                    textStyle: const TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rXs,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: Text(l.setupBtnExit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UninstallView extends StatefulWidget {
  const UninstallView({super.key});
  @override
  State<UninstallView> createState() => _UninstallViewState();
}

enum UninstallViewState { idle, uninstalling, success, error }

class _UninstallViewState extends State<UninstallView> {
  AppLocalizations get _l => AppLocalizations.of(context);

  UninstallViewState _state = UninstallViewState.idle;
  bool _purgeData = true;
  String _currentStep = "";
  String _errorMessage = "";
  Future<void> _startUninstall() async {
    setState(() {
      _state = UninstallViewState.uninstalling;
      _currentStep = "Iniciando desinstalación...";
    });
    try {
      await WinSetupService.performUninstall(
        purgeData: _purgeData,
        onStepProgress: (stepMsg) {
          setState(() {
            _currentStep = stepMsg;
          });
        },
      );
      setState(() {
        _state = UninstallViewState.success;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await WinSetupService.triggerSelfDestruct();
    } catch (e) {
      setState(() {
        _state = UninstallViewState.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return installerButtonScope(
      context,
      Scaffold(
        backgroundColor: NexoTheme.bg,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.wide,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.roomy),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: _buildCurrentState(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: NexoTheme.primary.withValues(alpha: AppOpacity.tint),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: NexoTheme.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: NexoTheme.primary.withValues(alpha: AppOpacity.subtle),
                blurRadius: 16,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Image.asset('assets/icon.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: AppSpacing.snug),
        Text(
          'Nexo UPLA',
          style: TextStyle(
            fontSize: AppFont.lead,
            fontWeight: FontWeight.w900,
            color: NexoTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentState() {
    switch (_state) {
      case UninstallViewState.idle:
        return KeyedSubtree(key: const ValueKey('idle'), child: _buildIdle());
      case UninstallViewState.uninstalling:
        return KeyedSubtree(
          key: const ValueKey('uninstalling'),
          child: _buildUninstalling(),
        );
      case UninstallViewState.success:
        return KeyedSubtree(
          key: const ValueKey('success'),
          child: _buildSuccess(),
        );
      case UninstallViewState.error:
        return KeyedSubtree(key: const ValueKey('error'), child: _buildError());
    }
  }

  Widget _buildIdle() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _l.uninstallTitle,
          style: TextStyle(
            fontSize: AppFont.subtitle,
            fontWeight: FontWeight.w800,
            color: NexoTheme.textPrimary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.tight),
        Text(
          _l.uninstallSubtitle,
          style: TextStyle(
            fontSize: AppFont.caption,
            color: NexoTheme.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.roomy),
        InkWell(
          onTap: () => setState(() => _purgeData = !_purgeData),
          borderRadius: AppRadii.rMd,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.snug,
            ),
            decoration: BoxDecoration(
              color: _purgeData
                  ? NexoTheme.danger.withValues(alpha: AppOpacity.subtle)
                  : NexoTheme.surface,
              borderRadius: AppRadii.rMd,
              border: Border.all(
                color: _purgeData
                    ? NexoTheme.danger.withValues(alpha: 0.4)
                    : NexoTheme.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.delete_sweep_rounded,
                  size: AppIcon.md,
                  color: _purgeData ? NexoTheme.danger : NexoTheme.textMuted,
                ),
                const SizedBox(width: AppSpacing.snug),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _l.uninstallPurgeTitle,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w700,
                          color: _purgeData
                              ? NexoTheme.danger
                              : NexoTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _l.uninstallPurgeHint,
                        style: TextStyle(
                          fontSize: AppFont.micro,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Checkbox(
                    value: _purgeData,
                    activeColor: NexoTheme.danger,
                    onChanged: (v) => setState(() => _purgeData = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => exit(0),
              style: OutlinedButton.styleFrom(
                foregroundColor: NexoTheme.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.cozy,
                  vertical: 9,
                ),
                textStyle: const TextStyle(
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w700,
                ),
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXs),
                side: BorderSide(color: NexoTheme.border),
              ),
              child: Text(_l.actionCancel),
            ),
            const SizedBox(width: AppSpacing.snug),
            ElevatedButton.icon(
              onPressed: _startUninstall,
              icon: const Icon(Icons.delete_outline_rounded, size: 14),
              label: Text(_l.uninstallAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: NexoTheme.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.roomy,
                  vertical: 9,
                ),
                textStyle: const TextStyle(
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w700,
                ),
                shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXs),
                elevation: 0,
                minimumSize: Size.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUninstalling() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.sm),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(NexoTheme.danger),
          strokeWidth: 3,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          _currentStep,
          style: TextStyle(
            fontSize: AppFont.label,
            fontWeight: FontWeight.w700,
            color: NexoTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: NexoTheme.success,
        ),
        const SizedBox(height: AppSpacing.cozy),
        Text(
          _l.uninstallSuccessTitle,
          style: TextStyle(
            fontSize: AppFont.subtitle,
            fontWeight: FontWeight.w800,
            color: NexoTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.tight),
        Text(
          _l.uninstallSuccessBody,
          style: TextStyle(
            fontSize: AppFont.caption,
            color: NexoTheme.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: NexoTheme.danger,
          ),
        ),
        const SizedBox(height: AppSpacing.cozy),
        Text(
          _l.uninstallErrorTitle,
          style: TextStyle(
            fontSize: AppFont.subtitle,
            fontWeight: FontWeight.w800,
            color: NexoTheme.textPrimary,
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: AppRadii.rMd,
            border: Border.all(color: NexoTheme.border),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SingleChildScrollView(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: AppFont.caption,
                fontFamily: 'Courier',
                color: NexoTheme.danger,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: ElevatedButton(
            onPressed: () => exit(0),
            style: ElevatedButton.styleFrom(
              backgroundColor: NexoTheme.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.roomy,
                vertical: 9,
              ),
              textStyle: const TextStyle(
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w700,
              ),
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXs),
              elevation: 0,
              minimumSize: Size.zero,
            ),
            child: Text(_l.actionClose),
          ),
        ),
      ],
    );
  }
}
