import 'package:flutter/material.dart';
import 'package:nexo/core/design/breakpoints.dart';
import 'package:nexo/core/design/theme.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.contentPadding,
        24,
        context.contentPadding,
        16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: context.isDesktop ? 1500 : 1240,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: NexoTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
        ),
      ),
    );
  }
}

class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.isDesktop ? 1500 : 1240),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.contentPadding,
            vertical: 4,
          ),
          child: child,
        ),
      ),
    );
  }
}
