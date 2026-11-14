import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/data/services/integration_service.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:url_launcher/url_launcher.dart';

/// Conexiones del estudiante: compartir su horario con un calendario y dar
/// o quitar acceso a apps externas.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({
    super.key,
    required this.store,
    required this.directory,
  });

  final AppStore store;
  final DirectoryService directory;

  static Future<void> open(
    BuildContext context, {
    required AppStore store,
    required DirectoryService directory,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => IntegrationsScreen(store: store, directory: directory),
    ),
  );

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  late final IntegrationService _service = IntegrationService(
    directory: widget.directory,
  );

  @override
  void initState() {
    super.initState();
    _service.load().then((_) {
      // Si ya comparte, el horario del servidor se pone al día al entrar.
      if (mounted && _service.status.sharing) _share();
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _share() => _service.share(
    profile: widget.store.profile.value,
    schedule: widget.store.schedule.value ?? const [],
    term: widget.store.periodoActivo?.label,
  );

  Future<void> _after(Future<void> action) async {
    await action;
    if (!mounted || _service.error == null) return;
    final l = AppLocalizations.of(context);
    ClipboardHelper.showError(context, _service.error, fallback: l.integError);
  }

  Future<void> _stopSharing() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.integShareStop),
        content: Text(l.integShareStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NexoTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.integShareStop),
          ),
        ],
      ),
    );
    if (ok == true) await _after(_service.stopSharing());
  }

  Future<void> _connect() async {
    final l = AppLocalizations.of(context);
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _CodeDialog(),
    );
    if (code == null || !mounted) return;

    ConnectionRequest request;
    try {
      request = await _service.preview(code);
    } on BackendException catch (e) {
      if (!mounted) return;
      ClipboardHelper.showError(
        context,
        e.code == 'not_found' ? l.integConnectNotFound : e,
        fallback: l.integError,
      );
      return;
    }
    if (!mounted) return;

    final approve = await showDialog<bool>(
      context: context,
      builder: (_) => _ConsentDialog(request: request),
    );
    if (approve == null) return;
    await _after(_service.decide(request.code, approve: approve));
  }

  Future<void> _launch(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ClipboardHelper.showError(
        context,
        null,
        fallback: AppLocalizations.of(context).integError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(title: Text(l.integTitle)),
      body: ListenableBuilder(
        listenable: _service,
        builder: (context, _) {
          final status = _service.status;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Text(
                    l.integSubtitle,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      color: NexoTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const Gap(AppSpacing.lg),
                  Reveal.list(child: _shareCard(l, status)),
                  const Gap(AppSpacing.md),
                  Reveal.list(index: 1, child: _calendarCard(l, status)),
                  const Gap(AppSpacing.md),
                  Reveal.list(index: 2, child: _appsCard(l, status)),
                ],
              ),
              if (_service.loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _shareCard(AppLocalizations l, IntegrationStatus status) {
    final busy = _service.loading;
    return _Section(
      icon: Icons.share_rounded,
      color: status.sharing ? NexoTheme.success : NexoTheme.primary,
      title: l.integShareTitle,
      subtitle: status.sharing ? l.integShareOn : l.integShareOff,
      body: l.integShareBody,
      actions: [
        if (!status.sharing)
          FilledButton.icon(
            onPressed: busy ? null : () => _after(_share()),
            icon: const Icon(Icons.check_rounded),
            label: Text(l.integShareStart),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: busy ? null : () => _after(_share()),
            icon: const Icon(Icons.sync_rounded),
            label: Text(l.integShareSync),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: NexoTheme.danger),
            onPressed: busy ? null : _stopSharing,
            child: Text(l.integShareStop),
          ),
        ],
      ],
    );
  }

  Widget _calendarCard(AppLocalizations l, IntegrationStatus status) {
    final busy = _service.loading;
    final links = _service.links;
    return _Section(
      icon: Icons.event_available_rounded,
      color: NexoTheme.info,
      title: l.integCalendarTitle,
      body: status.sharing ? l.integCalendarBody : l.integCalendarNeedsShare,
      actions: [
        if (status.sharing && links != null) ...[
          FilledButton.icon(
            onPressed: () => _launch(links.googleUrl),
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(l.integCalendarGoogle),
          ),
          OutlinedButton.icon(
            onPressed: () => _launch(links.webcalUrl),
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l.integCalendarOpen),
          ),
          OutlinedButton.icon(
            onPressed: () => ClipboardHelper.copyAndShow(
              context,
              links.url,
              label: l.integCalendarCopy,
            ),
            icon: const Icon(Icons.copy_rounded),
            label: Text(l.integCalendarCopy),
          ),
        ] else if (status.sharing)
          FilledButton.icon(
            onPressed: busy ? null : () => _after(_service.enableCalendar()),
            icon: const Icon(Icons.link_rounded),
            label: Text(
              status.calendarEnabled
                  ? l.integCalendarRotate
                  : l.integCalendarCreate,
            ),
          ),
        if (status.calendarEnabled)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: NexoTheme.danger),
            onPressed: busy ? null : () => _after(_service.disableCalendar()),
            child: Text(l.integCalendarDisable),
          ),
      ],
      footer: status.calendarEnabled && links == null
          ? l.integCalendarActive
          : null,
    );
  }

  Widget _appsCard(AppLocalizations l, IntegrationStatus status) {
    final busy = _service.loading;
    return _Section(
      icon: Icons.apps_rounded,
      color: NexoTheme.accent,
      title: l.integAppsTitle,
      body: status.connections.isEmpty ? l.integAppsEmpty : null,
      actions: [
        OutlinedButton.icon(
          onPressed: busy || !status.sharing ? null : _connect,
          icon: const Icon(Icons.add_link_rounded),
          label: Text(l.integAppsConnect),
        ),
      ],
      children: [
        for (final app in status.connections)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.extension_rounded),
            title: Text(
              app.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              app.scopes.map((s) => _scopeLabel(l, s)).join(' · '),
            ),
            trailing: IconButton(
              tooltip: l.integAppsRevoke,
              icon: const Icon(Icons.link_off_rounded, color: NexoTheme.danger),
              onPressed: busy ? null : () => _after(_service.revoke(app.id)),
            ),
          ),
      ],
    );
  }
}

String _scopeLabel(AppLocalizations l, String scope) => switch (scope) {
  'profile' => l.integScopeProfile,
  'schedule' => l.integScopeSchedule,
  _ => scope,
};

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.body,
    this.footer,
    this.children = const [],
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? body;
  final String? footer;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, AppDurations.fast),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: AppOpacity.tint),
                  borderRadius: AppRadii.rMd,
                ),
                child: SizedBox.square(
                  dimension: AppSizes.touch,
                  child: Icon(icon, color: color),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (body != null) ...[
            const Gap(AppSpacing.md),
            Text(
              body!,
              style: TextStyle(
                fontSize: AppFont.body,
                color: NexoTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          ...children,
          if (footer != null) ...[
            const Gap(AppSpacing.sm),
            Text(
              footer!,
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textMuted,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const Gap(AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();
  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid =>
      _controller.text.replaceAll(RegExp('[^A-Za-z]'), '').length == 8;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.integAppsConnect),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: l.integConnectCode,
          helperText: l.integConnectHint,
          hintText: 'ABCD-EFGH',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(context, _controller.text.trim())
              : null,
          child: Text(l.integConnectContinue),
        ),
      ],
    );
  }
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog({required this.request});
  final ConnectionRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: Icon(Icons.verified_user_rounded, color: NexoTheme.primary),
      title: Text(l.integConnectAsks(request.appName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final scope in request.scopes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: AppIcon.md,
                    color: NexoTheme.success,
                  ),
                  const Gap.h(AppSpacing.sm),
                  Expanded(child: Text(_scopeLabel(l, scope))),
                ],
              ),
            ),
          const Gap(AppSpacing.sm),
          Text(
            l.integConnectNever,
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.integConnectDeny),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.integConnectApprove),
        ),
      ],
    );
  }
}
