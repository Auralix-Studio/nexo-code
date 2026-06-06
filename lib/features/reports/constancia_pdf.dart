import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:nexo/domain/models.dart';
import 'package:nexo/features/reports/pdf_theme.dart';

/// PDF de Constancia de Matrícula con el estilo formal de Intranet.
Future<pw.Document> buildConstanciaPdf(ConstanciaMatricula c) async {
  final doc = pw.Document(
    title: 'Constancia de Matrícula ${c.periodoLabel}',
    author: 'Nexo',
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 30),
      header: (_) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 20),
        child: pdfTitle(
          'Constancia de Matrícula',
          periodoSuffix: '${c.periodoLabel}'
              '${c.modalidad.isNotEmpty ? ' · ${c.modalidad}' : ''}',
        ),
      ),
      footer: (_) => pdfFooter(),
      build: (_) => [
        _DatosEstudiante(c: c),
        pw.SizedBox(height: 18),
        _TablaCursos(cursos: c.cursos),
        pw.SizedBox(height: 14),
        _Resumen(c: c),
      ],
    ),
  );

  return doc;
}

class _DatosEstudiante extends pw.StatelessWidget {
  final ConstanciaMatricula c;
  _DatosEstudiante({required this.c});

  @override
  pw.Widget build(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pdfDataRow('Facultad', c.facultad),
        pdfDataRow(c.etiquetaCarrera, c.carrera),
        if (c.especialidad.isNotEmpty)
          pdfDataRow('Especialidad', c.especialidad),
        pdfDataRow('Código', c.codigo),
        pdfDataRow('Alumno', c.estudiante),
        pdfDataRow('Plan de Estudios', c.planEstudios),
        pdfDataRow('Nivel', c.nivel),
        pdfDataRow('Modalidad', c.modalidad),
      ],
    );
  }
}

class _TablaCursos extends pw.StatelessWidget {
  final List<MatriculaCurso> cursos;
  _TablaCursos({required this.cursos});

  @override
  pw.Widget build(pw.Context context) {
    if (cursos.isEmpty) {
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
        for (var i = 0; i < cursos.length; i++)
          pw.TableRow(
            children: [
              pdfTableCell('${i + 1}'),
              pdfTableCell(cursos[i].codigo),
              pdfTableCell(cursos[i].asignatura, align: pw.TextAlign.left),
              pdfTableCell(cursos[i].ciclo),
              pdfTableCell(cursos[i].seccion),
              pdfTableCell(cursos[i].creditos),
            ],
          ),
      ],
    );
  }
}

class _Resumen extends pw.StatelessWidget {
  final ConstanciaMatricula c;
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
            'Total de asignaturas: ${c.cursos.length}',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
            ),
          ),
          pw.Text(
            'Total de créditos: ${c.totalCreditos.toStringAsFixed(0)}',
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
