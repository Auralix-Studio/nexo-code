import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nexo/core/design/breakpoints.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/app_logo.dart';

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final bool isIntro;
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.isIntro = false,
  });
}

List<_Page> _pages(AppLocalizations l) => [
  _Page(
    icon: Icons.auto_awesome,
    title: l.onboardingTitleWelcome,
    body: l.onboardingBodyWelcome,
    color: NexoTheme.primary,
    isIntro: true,
  ),
  _Page(
    icon: Icons.calendar_today_rounded,
    title: l.onboardingTitleSchedule,
    body: l.onboardingBodySchedule,
    color: NexoTheme.accent,
  ),
  _Page(
    icon: Icons.account_balance_wallet_rounded,
    title: l.onboardingTitlePayments,
    body: l.onboardingBodyPayments,
    color: NexoTheme.warning,
  ),
  _Page(
    icon: Icons.widgets_rounded,
    title: l.onboardingTitleWidgets,
    body: l.onboardingBodyWidgets,
    color: NexoTheme.success,
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  static const int _pageCount = 4;
  bool get _isLast => _index == _pageCount - 1;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      widget.onDone();
    } else {
      _controller.nextPage(
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDesktop = context.isDesktop;
    final pages = _pages(l);
    final page = pages[_index];
    final pager = PageView.builder(
      controller: _controller,
      itemCount: pages.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (_, i) =>
          _Slide(page: pages[i], active: _index == i, compact: isDesktop),
    );
    final controls = _Controls(
      index: _index,
      total: pages.length,
      color: page.color,
      isLast: _isLast,
      onSkip: _isLast ? null : widget.onDone,
      onNext: _next,
      l: l,
    );
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(flex: 5, child: _VisualPane(page: page)),
            Expanded(
              flex: 6,
              child: SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AnimatedOpacity(
                          opacity: _isLast ? 0 : 1,
                          duration: AppDurations.fast,
                          child: TextButton(
                            onPressed: _isLast ? null : widget.onDone,
                            child: Text(l.actionSkip),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: pager,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: controls,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  const AppLogo(size: 30, shadow: false),
                  const Gap.h(AppSpacing.sm),
                  Text(
                    'Nexo',
                    style: TextStyle(
                      fontSize: AppFont.h3,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: NexoTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: AppDurations.fast,
                    child: TextButton(
                      onPressed: _isLast ? null : widget.onDone,
                      child: Text(l.actionSkip),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: pager),
            controls,
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final int index;
  final int total;
  final Color color;
  final bool isLast;
  final VoidCallback? onSkip;
  final VoidCallback onNext;
  final AppLocalizations l;
  const _Controls({
    required this.index,
    required this.total,
    required this.color,
    required this.isLast,
    required this.onSkip,
    required this.onNext,
    required this.l,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == index ? color : NexoTheme.border,
                    borderRadius: AppRadii.rPill,
                  ),
                ),
            ],
          ),
          const Gap(AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Text(
                  isLast ? l.onboardingStart : l.actionNext,
                  key: ValueKey(isLast),
                  style: const TextStyle(
                    fontSize: AppFont.title,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisualPane extends StatelessWidget {
  final _Page page;
  const _VisualPane({required this.page});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.slow,
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [page.color, Color.lerp(page.color, Colors.black, 0.35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: _halo(260, Colors.white.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: _halo(240, Colors.white.withValues(alpha: 0.07)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.huge),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlassBadge(page: page),
                const Gap(AppSpacing.huge),
                Text(
                  page.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFont.display,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                    letterSpacing: -1.5,
                  ),
                ),
                const Gap(AppSpacing.lg),
                Text(
                  page.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: AppFont.h3,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _halo(double s, Color c) => Container(
    width: s,
    height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
  );
}

class _GlassBadge extends StatelessWidget {
  final _Page page;
  const _GlassBadge({required this.page});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(page.title),
      tween: Tween(begin: 0.8, end: 1),
      duration: AppDurations.slow,
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: page.isIntro
            ? const Center(child: AppLogo(size: 60, shadow: false))
            : Icon(page.icon, size: 44, color: Colors.white),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  final _Page page;
  final bool active;
  final bool compact;
  const _Slide({
    required this.page,
    required this.active,
    required this.compact,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!compact) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: active ? 1 : 0.85),
              duration: AppDurations.slow,
              curve: Curves.easeOutBack,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: _Illustration(page: page),
            ),
            const Gap(AppSpacing.huge),
          ],
          Text(
            page.title,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              fontSize: AppFont.h1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: NexoTheme.textPrimary,
            ),
          ),
          const Gap(AppSpacing.md),
          Text(
            page.body,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: TextStyle(
              fontSize: AppFont.subtitle,
              height: 1.5,
              color: NexoTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  final _Page page;
  const _Illustration({required this.page});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withValues(alpha: 0.08),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withValues(alpha: 0.14),
            ),
          ),
          ...List.generate(6, (i) {
            final a = (math.pi * 2 / 6) * i;
            return Transform.translate(
              offset: Offset(95 * math.cos(a), 95 * math.sin(a)),
              child: Container(
                width: i.isEven ? 10 : 6,
                height: i.isEven ? 10 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: page.color.withValues(alpha: 0.5),
                ),
              ),
            );
          }),
          page.isIntro
              ? const AppLogo(size: 104)
              : Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        page.color,
                        Color.lerp(page.color, Colors.black, 0.25)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: page.color.withValues(alpha: 0.4),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Icon(page.icon, size: 52, color: Colors.white),
                ),
        ],
      ),
    );
  }
}
