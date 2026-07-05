import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/features/reports/pdf_theme.dart';

Future<pw.Document> buildSchedulePdf(
  PaymentSchedule data, {
  Student? student,
  Term? periodo,
}) async {
  final doc = pw.Document(title: 'Schedule de Pagos', author: 'Nexo');
  final periodLabel = periodo == null
      ? ''
      : '${periodo.year}-${periodo.number == 1 ? 'I' : 'II'}';
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 20),
        child: pdfTitle(
          'Schedule de Pagos',
          periodoSuffix: periodLabel.isEmpty ? null : 'Semestre $periodLabel',
        ),
      ),
      footer: (_) => pdfFooter(),
      build: (_) => [
        if (student != null) _DatosEstudiante(student: student),
        if (student != null) pw.SizedBox(height: 18),
        _TablaCuotas(installments: data.installments),
        pw.SizedBox(height: 10),
        _Total(totalAmount: data.totalAmount),
      ],
    ),
  );
  return doc;
}

class _DatosEstudiante extends pw.StatelessWidget {
  final Student student;
  _DatosEstudiante({required this.student});
  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfDataRow('Facultad', student.faculty),
        pdfDataRow('Carrera', student.career),
        pdfDataRow('Código', student.id),
        pdfDataRow('Estudiante', student.fullName),
        pdfDataRow('Modalidad', student.modality),
      ],
    );
  }
}

class _TablaCuotas extends pw.StatelessWidget {
  final List<PaymentInstallment> installments;
  _TablaCuotas({required this.installments});
  @override
  pw.Widget build(pw.Context context) {
    if (installments.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Sin installments registradas.',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfTheme.textMuted,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      );
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfTheme.border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfTheme.tableHeader),
          children: [
            pdfTableHeader('Nº de Cuota'),
            pdfTableHeader('Monto'),
            pdfTableHeader('Fecha de Vencimiento'),
          ],
        ),
        for (final c in installments)
          pw.TableRow(
            children: [
              pdfTableCell(c.number),
              pdfTableCell('S/ ${c.amount.toStringAsFixed(2)}'),
              pdfTableCell(c.rawDueDate),
            ],
          ),
      ],
    );
  }
}

class _Total extends pw.StatelessWidget {
  final double totalAmount;
  _Total({required this.totalAmount});
  @override
  pw.Widget build(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfTheme.borderStrong, width: 0.8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MONTO TOTAL DEL SEMESTRE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
              letterSpacing: 0.4,
            ),
          ),
          pw.Text(
            'S/ ${totalAmount.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.institucional,
            ),
          ),
        ],
      ),
    );
  }
}
