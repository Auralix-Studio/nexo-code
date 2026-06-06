import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:printing/printing.dart';

import 'package:nexo/data/app_store.dart';
import 'package:nexo/features/reports/constancia_pdf.dart';
import 'package:nexo/features/reports/cronograma_pdf.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';

/// Orquestador del flujo: carga los datos (si no están), construye el PDF y
/// abre la vista previa nativa (con opciones Guardar / Compartir / Imprimir).
abstract final class PdfExport {
  /// Exporta la Constancia de Matrícula.
  static Future<void> constancia(BuildContext context, AppStore store) async {
    // Carga si hace falta.
    if (!store.constancia.hasValue || store.constancia.error != null) {
      await store.loadConstancia();
    }
    final data = store.constancia.value;
    if (data == null) {
      if (!context.mounted) return;
      ClipboardHelper.showError(
        context,
        store.constancia.error,
        fallback: AppLocalizations.of(context).pdfExportLoadConstanciaError,
      );
      return;
    }

    final periodo = store.periodoActivo;
    final doc = await buildConstanciaPdf(data);
    await Printing.layoutPdf(
      name: 'Constancia_${data.codigo}_${data.periodoLabel}.pdf',
      onLayout: (format) async {
        // Marca de uso (silencia warning de parámetro sin usar).
        periodo;
        return doc.save();
      },
    );
  }

  /// Exporta el Cronograma de Pagos.
  static Future<void> cronograma(BuildContext context, AppStore store) async {
    if (!store.cronograma.hasValue || store.cronograma.error != null) {
      await store.loadCronograma();
    }
    final data = store.cronograma.value;
    if (data == null) {
      if (!context.mounted) return;
      ClipboardHelper.showError(
        context,
        store.cronograma.error,
        fallback: AppLocalizations.of(context).pdfExportLoadCronogramaError,
      );
      return;
    }

    final doc = await buildCronogramaPdf(
      data,
      student: store.profile.value,
      periodo: store.periodoActivo,
    );
    final codigo = store.profile.value?.estId ?? '';
    final periodoLabel = store.periodoActivo == null
        ? ''
        : '${store.periodoActivo!.anio}-${store.periodoActivo!.periodo}';
    await Printing.layoutPdf(
      name: 'Cronograma_${codigo}_$periodoLabel.pdf',
      onLayout: (_) => doc.save(),
    );
  }
}
