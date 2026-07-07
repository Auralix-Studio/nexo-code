import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/reports/pdf_theme.dart';

Future<pw.Document> buildCertificatePdf(EnrollmentCertificate c) async {
  final doc = pw.Document(
    title: 'Certificate de Matrícula ${c.periodLabel}',
    author: 'Nexo',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 20),
        child: pdfTitle(
          'Certificate de Matrícula',
          periodoSuffix:
              '${c.periodLabel}'
              '${c.modality.isNotEmpty ? ' · ${c.modality}' : ''}',
        ),
      ),
      footer: (_) => pdfFooter(),
      build: (_) => [
        _DatosEstudiante(c: c),
        pw.SizedBox(height: 18),
        _TablaCursos(courses: c.courses),
        pw.SizedBox(height: 14),
        _Resumen(c: c),
      ],
    ),
  );
  return doc;
}

class _DatosEstudiante extends pw.StatelessWidget {
  final EnrollmentCertificate c;
  _DatosEstudiante({required this.c});
  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfDataRow('Facultad', c.faculty),
        pdfDataRow(c.careerLabel, c.career),
        if (c.specialty.isNotEmpty) pdfDataRow('Especialidad', c.specialty),
        pdfDataRow('Código', c.code),
        pdfDataRow('Estudiante', c.student),
        pdfDataRow('Plan de Estudios', c.studyPlan),
        pdfDataRow('Nivel', c.level),
        pdfDataRow('Modalidad', c.modality),
      ],
    );
  }
}

class _TablaCursos extends pw.StatelessWidget {
  final List<EnrollmentCourse> courses;
  _TablaCursos({required this.courses});
  @override
  pw.Widget build(pw.Context context) {
    if (courses.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Sin asignaturas registradas en este periodo.',
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
        0: pw.FlexColumnWidth(0.6),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(4.0),
        3: pw.FlexColumnWidth(0.7),
        4: pw.FlexColumnWidth(0.9),
        5: pw.FlexColumnWidth(0.9),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfTheme.tableHeader),
          children: [
            pdfTableHeader('Nº'),
            pdfTableHeader('Código'),
            pdfTableHeader('Asignatura', align: pw.TextAlign.left),
            pdfTableHeader('Ciclo'),
            pdfTableHeader('Sección'),
            pdfTableHeader('Créditos'),
          ],
        ),
        for (var i = 0; i < courses.length; i++)
          pw.TableRow(
            children: [
              pdfTableCell('${i + 1}'),
              pdfTableCell(courses[i].code),
              pdfTableCell(courses[i].subject, align: pw.TextAlign.left),
              pdfTableCell(courses[i].cycle),
              pdfTableCell(courses[i].section),
              pdfTableCell(courses[i].creditos),
            ],
          ),
      ],
    );
  }
}

class _Resumen extends pw.StatelessWidget {
  final EnrollmentCertificate c;
  _Resumen({required this.c});
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
            'Total de asignaturas: ${c.courses.length}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
            ),
          ),
          pw.Text(
            'Total de créditos: ${c.totalCredits.toStringAsFixed(0)}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}
