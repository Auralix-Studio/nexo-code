import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/schedule/schedule_detail_screen.dart';
import 'package:nexo/shared/util/formatters.dart';

/// Tarjeta destacada con la **próxima clase** (hoy o el siguiente día con clases).
class NextClassWidget extends StatelessWidget {
  final List<ClaseHorario> all;
  final DateTime? nowOverride;
  const NextClassWidget({super.key, required this.all, this.nowOverride});

  DateTime get _now => nowOverride ?? DateTime.now();

  ({ClaseHorario clase, bool esHoy, int diasHasta})? _next() {
    if (all.isEmpty) return null;
    final now = _now;
    final nowMin = now.hour * 60 + now.minute;
    // Buscar en los próximos 7 días (incluye hoy).
    for (var offset = 0; offset < 8; offset++) {
      final dia = ((now.weekday - 1 + offset) % 7) + 1;
      final delDia = all.where((c) => c.idDia == dia).toList()
        ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      for (final c in delDia) {
        final ini = _toMin(c.horaInicio);
        if (offset == 0 && ini != null && ini <= nowMin) continue;
        return (clase: c, esHoy: offset == 0, diasHasta: offset);
      }
    }
    return null;
  }

  static int? _toMin(String hm) {
    final p = hm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }

  String _relativo(({ClaseHorario clase, bool esHoy, int diasHasta}) n) {
    if (!n.esHoy) {
      return n.diasHasta == 1
          ? 'Mañana · ${Fmt.dayLabel(n.clase.idDia)}'
          : Fmt.dayLabel(n.clase.idDia);
    }
    final now = _now;
    final ini = _toMin(n.clase.horaInicio);
    if (ini == null) return 'Hoy';
    final diff = ini - (now.hour * 60 + now.minute);
    if (diff <= 0) return 'Ahora';
    if (diff < 60) return 'En $diff min';
    final h = diff ~/ 60;
    final m = diff % 60;
    return m == 0 ? 'En ${h}h' : 'En ${h}h ${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final n = _next();
    if (n == null) return const SizedBox.shrink();
    final c = n.clase;
    // Construye un ClaseAgrupada con todas las sesiones del mismo curso ese día.
    final grupo = ClaseAgrupada.agrupar(
      all.where((x) => x.idDia == c.idDia && x.asignatura == c.asignatura).toList(),
    ).firstWhere(
      (g) => g.asignatura == c.asignatura,
      orElse: () => ClaseAgrupada(
        asignatura: c.asignatura,
        idDia: c.idDia,
        sesiones: [c],
      ),
    );

    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.rXxl,
      child: InkWell(
        onTap: () => ScheduleDetailScreen.open(context, grupo),
        borderRadius: AppRadii.rXxl,
        child: Container(
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
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: Colors.white, size: AppIcon.md),
              const Gap.h(AppSpacing.sm),
              Text(
                'PRÓXIMA CLASE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: AppFont.caption,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  _relativo(n),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Text(
            c.asignatura,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFont.h2,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.3,
            ),
          ),
          const Gap(AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _info(
                Icons.schedule,
                () {
                  final h24 = AppStorage.instance.use24h;
                  return '${Fmt.time(c.horaInicio, h24: h24)} – '
                      '${Fmt.time(c.horaFin, h24: h24)}';
                }(),
              ),
               if (c.aula.isNotEmpty)
                _info(Icons.location_on_outlined, Fmt.formatAula(c.aula)),
              _info(Icons.bookmark_border, c.tipoLargo),
              if (c.docente.isNotEmpty)
                _info(Icons.person_outline, c.docente),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIcon.sm, color: Colors.white.withValues(alpha: 0.85)),
          const Gap.h(AppSpacing.xs + 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: AppFont.small,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
}
