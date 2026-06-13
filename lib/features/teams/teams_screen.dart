import 'package:flutter/material.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/ms_auth_service.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/teams_classes_widget.dart';
import 'package:nexo/shared/widgets/upcoming_assignments_widget.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key, required this.store, required this.msAuth});

  final AppStore store;
  final MsAuthService msAuth;

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  @override
  void initState() {
    super.initState();
    widget.msAuth.addListener(_onAuthChange);
    if (widget.msAuth.isAuthenticated) _ensureLoaded();
  }

  @override
  void dispose() {
    widget.msAuth.removeListener(_onAuthChange);
    super.dispose();
  }

  void _onAuthChange() {
    if (widget.msAuth.isAuthenticated) {
      _ensureLoaded();
    } else {
      widget.store.clearTeams();
    }
  }

  void _ensureLoaded() {
    final s = widget.store;
    if (!s.teamsClasses.hasValue && !s.teamsClasses.loading) {
      s.loadTeams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.msAuth, widget.store]),
      builder: (context, _) {
        final auth = widget.msAuth;
        final l = AppLocalizations.of(context);
        return Column(
          children: [
            PageHeader(
              title: l.tabTeams,
              subtitle: l.teamsSubtitle,
              actions: [
                if (auth.isAuthenticated)
                  IconButton(
                    tooltip: l.teamsDisconnect,
                    onPressed: auth.signOut,
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            ),
            Expanded(child: _body(auth)),
          ],
        );
      },
    );
  }

  Widget _body(MsAuthService auth) {
    if (!auth.isConfigured) {
      return const _ScrollBody(child: _NotConfiguredCard());
    }
    if (auth.isConnecting) {
      return _ScrollBody(child: _DeviceCodeCard(auth: auth));
    }
    if (!auth.isAuthenticated) {
      return _ScrollBody(child: _ConnectCard(auth: auth));
    }
    return RefreshIndicator(
      onRefresh: () => widget.store.loadTeams(),
      child: _ScrollBody(
        alwaysScrollable: true,
        child: _ConnectedView(store: widget.store),
      ),
    );
  }
}

class _ScrollBody extends StatelessWidget {
  final Widget child;
  final bool alwaysScrollable;
  const _ScrollBody({required this.child, this.alwaysScrollable = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: alwaysScrollable
          ? const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())
          : const BouncingScrollPhysics(),
      child: PageBody(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          child: child,
        ),
      ),
    );
  }
}

class _ConnectedView extends StatelessWidget {
  final AppStore store;
  const _ConnectedView({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final classes = store.teamsClasses;
    final assignments = store.teamsAssignments;
    final classNames = {
      for (final c in classes.value ?? const <TeamsClass>[])
        c.id: c.displayName,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Slice(
          state: classes,
          title: l.teamsMySubjects,
          icon: Icons.groups_outlined,
          builder: (v) => TeamsClassesWidget(clases: v),
        ),
        const Gap(AppSpacing.lg),
        _Slice(
          state: assignments,
          title: l.teamsAssignments,
          icon: Icons.assignment_outlined,
          builder: (v) =>
              UpcomingAssignmentsWidget(assignments: v, classNames: classNames),
        ),
      ],
    );
  }
}

class _Slice<T> extends StatelessWidget {
  final AsyncValue<List<T>> state;
  final String title;
  final IconData icon;
  final Widget Function(List<T> value) builder;
  const _Slice({
    required this.state,
    required this.title,
    required this.icon,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return SectionCard(
        title: title,
        icon: icon,
        child: const Column(
          children: [
            Skeleton(height: 64, radius: 14),
            SizedBox(height: 10),
            Skeleton(height: 64, radius: 14),
          ],
        ),
      );
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: title,
        icon: icon,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l.teamsLoadError,
          subtitle: humanizeError(state.error),
          color: NexoTheme.danger,
        ),
      );
    }
    return builder(state.value ?? const []);
  }
}

class _ConnectCard extends StatelessWidget {
  final MsAuthService auth;
  const _ConnectCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.teamsConnectTitle,
      subtitle: l.teamsConnectSubtitle,
      icon: Icons.cloud_sync_outlined,
      iconColor: NexoTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.teamsConnectBody,
            style: TextStyle(
              fontSize: AppFont.body,
              height: 1.45,
              color: NexoTheme.textSecondary,
            ),
          ),
          if (auth.error != null) ...[
            const Gap(AppSpacing.lg),
            _ErrorBox(message: auth.error!),
          ],
          const Gap(AppSpacing.xl),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: auth.startSignIn,
              icon: const Icon(Icons.login_rounded),
              label: Text(
                l.teamsConnectButton,
                style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCodeCard extends StatelessWidget {
  final MsAuthService auth;
  const _DeviceCodeCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final info = auth.deviceCode;
    if (info == null) {
      return SectionCard(
        title: l.teamsDeviceCodeGenerating,
        icon: Icons.cloud_sync_outlined,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return SectionCard(
      title: l.teamsDeviceCodeConfirmTitle,
      subtitle: l.teamsDeviceCodeConfirmSubtitle,
      icon: Icons.verified_user_outlined,
      iconColor: NexoTheme.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Step(
            number: '1',
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: AppFont.body,
                        color: NexoTheme.textSecondary,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: l.teamsDeviceCodeStep1Prefix),
                        TextSpan(
                          text: info.verificationUri,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NexoTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l.teamsCopyLink,
                  iconSize: AppIcon.md,
                  onPressed: () =>
                      _copy(context, info.verificationUri, l.teamsLinkCopied),
                  icon: const Icon(Icons.link_rounded),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.md),
          _Step(
            number: '2',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.teamsDeviceCodeStep2Label,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    color: NexoTheme.textSecondary,
                  ),
                ),
                const Gap(AppSpacing.sm),
                _CodeChip(
                  code: info.userCode,
                  onCopy: () =>
                      _copy(context, info.userCode, l.teamsCodeCopied),
                ),
              ],
            ),
          ),
          const Gap(AppSpacing.xl),
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Text(
                  l.teamsDeviceCodeAutoRefresh,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textMuted,
                  ),
                ),
              ),
              TextButton(
                onPressed: auth.cancelSignIn,
                child: Text(l.actionCancel),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String text, String msg) {
    ClipboardHelper.copyAndShow(context, text, label: msg);
  }
}

class _Step extends StatelessWidget {
  final String number;
  final Widget child;
  const _Step({required this.number, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NexoTheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.w800,
              color: NexoTheme.primary,
            ),
          ),
        ),
        const Gap.h(AppSpacing.md),
        Expanded(child: child),
      ],
    );
  }
}

class _CodeChip extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;
  const _CodeChip({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.primary.withValues(alpha: 0.06),
        borderRadius: AppRadii.rMd,
        border: Border.all(color: NexoTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(
            code,
            style: TextStyle(
              fontSize: AppFont.h3,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: NexoTheme.primary,
            ),
          ),
          const Gap.h(AppSpacing.sm),
          IconButton(
            tooltip: l.teamsCopyCode,
            iconSize: AppIcon.md,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: NexoTheme.danger.withValues(alpha: 0.08),
        borderRadius: AppRadii.rMd,
        border: Border.all(color: NexoTheme.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: NexoTheme.danger,
            size: AppIcon.lg,
          ),
          const Gap.h(AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: NexoTheme.danger,
                fontSize: AppFont.body,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotConfiguredCard extends StatelessWidget {
  const _NotConfiguredCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: l.teamsUnderConstruction,
      subtitle: l.teamsSoonAvailable,
      icon: Icons.construction_rounded,
      iconColor: NexoTheme.warning,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.xl,
          horizontal: AppSpacing.md,
        ),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(
              Icons.engineering_outlined,
              size: 48,
              color: NexoTheme.warning,
            ),
            const Gap(AppSpacing.md),
            Text(
              l.teamsWorkingOnSection,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFont.subtitle,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textPrimary,
              ),
            ),
            const Gap(AppSpacing.xs),
            Text(
              l.teamsComeBackLater,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFont.body,
                color: NexoTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ..._TeamsFaqItem.getItems(context).map((item) => _CollapsibleInfo(
                  title: item.title,
                  description: item.description,
                  bulletPoints: item.bulletPoints,
                )),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleInfo extends StatefulWidget {
  final String title;
  final String description;
  final List<String> bulletPoints;

  const _CollapsibleInfo({
    required this.title,
    required this.description,
    required this.bulletPoints,
  });

  @override
  State<_CollapsibleInfo> createState() => _CollapsibleInfoState();
}

class _CollapsibleInfoState extends State<_CollapsibleInfo> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: NexoTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: NexoTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 1,
                    color: NexoTheme.border,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  Text(
                    widget.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                  if (widget.bulletPoints.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final point in widget.bulletPoints)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 6),
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: NexoTheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                point,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: NexoTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _TeamsFaqItem {
  final String title;
  final String description;
  final List<String> bulletPoints;

  _TeamsFaqItem({
    required this.title,
    required this.description,
    required this.bulletPoints,
  });

  static List<_TeamsFaqItem> getItems(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'en') {
      return [
        _TeamsFaqItem(
          title: "What is the Microsoft Teams integration?",
          description: "Nexo UPLA will securely connect with the university's Microsoft Teams servers using your institutional credentials. This will unify your virtual classes, assignments, and grades in a single interface.",
          bulletPoints: [
            "Virtual Classes View: See your class schedule, direct links to join videocalls, and past recordings without leaving Nexo.",
            "Assignments Monitoring: Automated synchronization of all pending Teams assignments, including due dates and notifications before they expire.",
            "Grades and Feedback: Access comments and scores directly from your teachers on your dashboard.",
            "Security and Privacy: Sign-in is done securely via Microsoft Device Code, ensuring your password is never stored or processed by Nexo.",
          ],
        ),
        _TeamsFaqItem(
          title: "How will account linking work?",
          description: "When this feature is released, linking your account will be quick and secure:",
          bulletPoints: [
            "Nexo will display a unique Microsoft verification code.",
            "You will click the link to open the official Microsoft login page in your browser.",
            "Log in using your official institutional email and password.",
            "Once authorized, Nexo will immediately sync your classes and tasks in real-time.",
          ],
        ),
      ];
    } else if (locale == 'qu') {
      return [
        _TeamsFaqItem(
          title: "Imamanta Microsoft Teams chaskina rimakun? (Integración)",
          description: "Nexo UPLA Microsoft Teams llikawan tupanqa (correo institucional yupaywan). Kaypi virtual yachayniykikunata, ruranakunata hinaspa notasniykikunata qawayta atinki.",
          bulletPoints: [
            "Virtual Yachaykuna Qaway (Clases Virtuales): Horariota hinaspa directollanta link videollamadasman yaykunaykipaq.",
            "Ruranakuna (Tareas y Entregas): Sincronización automática de todas las asignaciones pendientes en Teams.",
            "Seguridad y Privacidad: Microsoft Device Code nisqawan, contraseñaykiqa mana Nexopi churasqachu kanqa.",
          ],
        ),
      ];
    } else {
      return [
        _TeamsFaqItem(
          title: "¿De qué trata la integración con Microsoft Teams?",
          description: "Nexo UPLA se conectará de manera segura y directa con los servidores de Microsoft Teams de la universidad (utilizando las credenciales de tu correo institucional). Esto permitirá unificar tus clases virtuales, tareas y calificaciones en un solo entorno.",
          bulletPoints: [
            "Visualización de Clases Virtuales: Podrás ver el horario, enlace directo a las videollamadas de tus clases y las grabaciones pasadas de cada asignatura sin salir de Nexo.",
            "Monitoreo de Tareas y Entregas: Sincronización automática de todas las asignaciones pendientes en Teams, incluyendo fechas límite y notificaciones automáticas antes de que expiren.",
            "Historial de Calificaciones e Indicadores: Visualiza los comentarios y notas de los docentes de forma inmediata en tu dashboard.",
            "Seguridad y Privacidad: La autenticación se realiza directamente mediante Microsoft Device Code, lo que garantiza que tus contrasezas nunca pasen ni se almacenen en nuestros servidores locales.",
          ],
        ),
        _TeamsFaqItem(
          title: "¿Cómo funcionará la vinculación de cuenta?",
          description: "Cuando la función esté disponible, el proceso de vinculación será rápido y seguro:",
          bulletPoints: [
            "Nexo te mostrará un código de verificación de Microsoft único de un solo uso.",
            "Presionarás el enlace para abrir la página oficial de Microsoft en tu navegador.",
            "Iniciarás sesión con tu correo institucional y contraseña oficial.",
            "Una vez autorizado, Nexo comenzará a sincronizar tus datos en tiempo real.",
          ],
        ),
      ];
    }
  }
}
