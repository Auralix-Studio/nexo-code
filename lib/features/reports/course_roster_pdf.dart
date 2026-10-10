import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:nexo/domain/course_roster_stats.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/reports/pdf_theme.dart';

/// Lista de la sección para el docente: código, alumno, nota final y
/// asistencia, con un resumen al inicio. Documento informativo (no oficial).
Future<pw.Document> buildCourseRosterPdf({
  required TeacherSubject course,
  required List<TeacherStudent> alumnos,
  TeacherInfo? teacher,
}) async {
  final doc = pw.Document(title: 'Lista de alumnos', author: 'Nexo');
  final ordered = CourseRosterStats.sorted(alumnos, RosterSort.name);
  final stats = CourseRosterStats.from(alumnos);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 16),
        child: pdfTitle(
          'Lista de alumnos',
          periodoSuffix: course.periodo.isEmpty ? null : course.periodo,
        ),
      ),
      footer: (_) => pdfFooter(),
      build: (_) => [
        pdfDataRow('Asignatura', course.subject),
        if (course.section.isNotEmpty) pdfDataRow('Sección', course.section),
        if (course.code.isNotEmpty) pdfDataRow('NRC', course.code),
        if (teacher != null && teacher.displayName.isNotEmpty)
          pdfDataRow('Docente', teacher.displayName),
        pdfDataRow(
          'Resumen',
          '${stats.total} alumnos · ${stats.approved} aprobados · '
              '${stats.failed} desaprobados · ${stats.noGrade} sin nota'
              '${stats.average == null ? '' : ' · promedio ${stats.average!.toStringAsFixed(2)}'}',
        ),
        pw.SizedBox(height: 14),
        _tabla(ordered),
      ],
    ),
  );
  return doc;
}

pw.Widget _tabla(List<TeacherStudent> alumnos) {
  if (alumnos.isEmpty) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(20),
      child: pw.Text(
        'Sin alumnos registrados.',
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfTheme.textMuted,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }
  String asis(TeacherStudent a) {
    final p = a.attendancePct;
    if (p == null) return '—';
    return '${p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(1)}%';
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfTheme.border, width: 0.6),
    columnWidths: const {
      0: pw.FixedColumnWidth(26),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(4),
      3: pw.FlexColumnWidth(1.1),
      4: pw.FlexColumnWidth(1.2),
    },
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfTheme.tableHeader),
        repeat: true,
        children: [
          pdfTableHeader('N°'),
          pdfTableHeader('Código'),
          pdfTableHeader('Apellidos y nombres', align: pw.TextAlign.left),
          pdfTableHeader('Nota'),
          pdfTableHeader('Asist.'),
        ],
      ),
      for (var i = 0; i < alumnos.length; i++)
        pw.TableRow(
          children: [
            pdfTableCell('${i + 1}'),
            pdfTableCell(alumnos[i].code),
            pdfTableCell(alumnos[i].displayName, align: pw.TextAlign.left),
            pdfTableCell(
              (alumnos[i].grade ?? '').trim().isEmpty ? '—' : alumnos[i].grade!,
            ),
            pdfTableCell(asis(alumnos[i])),
          ],
        ),
    ],
  );
}
