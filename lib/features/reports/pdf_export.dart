import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:printing/printing.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/reports/certificate_pdf.dart';
import 'package:nexo/features/reports/course_roster_pdf.dart';
import 'package:nexo/features/reports/schedule_pdf.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';

abstract final class PdfExport {
  static Future<void> certificate(BuildContext context, AppStore store) async {
    if (!store.certificate.hasValue || store.certificate.error != null) {
      await store.loadCertificate();
    }
    final data = store.certificate.value;
    if (data == null) {
      if (!context.mounted) return;
      ClipboardHelper.showError(
        context,
        store.certificate.error,
        fallback: AppLocalizations.of(context).pdfExportLoadConstanciaError,
      );
      return;
    }
    final periodo = store.periodoActivo;
    final doc = await buildCertificatePdf(data);
    await Printing.layoutPdf(
      name: 'Constancia_${data.code}_${data.periodLabel}.pdf',
      onLayout: (format) async {
        periodo;
        return doc.save();
      },
    );
  }

  static Future<void> schedule(BuildContext context, AppStore store) async {
    if (!store.paymentSchedule.hasValue ||
        store.paymentSchedule.error != null) {
      await store.loadPaymentSchedule();
    }
    final data = store.paymentSchedule.value;
    if (data == null) {
      if (!context.mounted) return;
      ClipboardHelper.showError(
        context,
        store.paymentSchedule.error,
        fallback: AppLocalizations.of(context).pdfExportLoadCronogramaError,
      );
      return;
    }
    final doc = await buildSchedulePdf(
      data,
      student: store.profile.value,
      periodo: store.periodoActivo,
    );
    final code = store.profile.value?.id ?? '';
    final periodLabel = store.periodoActivo == null
        ? ''
        : '${store.periodoActivo!.year}-${store.periodoActivo!.number}';
    await Printing.layoutPdf(
      name: 'Cronograma_${code}_$periodLabel.pdf',
      onLayout: (_) => doc.save(),
    );
  }

  /// Lista de alumnos de una sección del docente (nota final y asistencia).
  static Future<void> courseRoster(
    BuildContext context,
    AppStore store,
    TeacherSubject course,
  ) async {
    final l = AppLocalizations.of(context);
    final alumnos = store.alumnosDe(course.id).value;
    if (alumnos == null) {
      ClipboardHelper.showError(
        context,
        store.alumnosDe(course.id).error,
        fallback: l.docenteExportError,
      );
      return;
    }
    try {
      final doc = await buildCourseRosterPdf(
        course: course,
        alumnos: alumnos,
        teacher: store.teacherInfo.value,
      );
      final safe = course.subject
          .replaceAll(RegExp(r'[^A-Za-z0-9áéíóúÁÉÍÓÚñÑ ]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      await Printing.layoutPdf(
        name: 'Lista_${safe.isEmpty ? course.id : safe}_${course.section}.pdf',
        onLayout: (_) => doc.save(),
      );
    } catch (e) {
      if (!context.mounted) return;
      ClipboardHelper.showError(context, e, fallback: l.docenteExportError);
    }
  }
}
