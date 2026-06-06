import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Paleta y primitivos compartidos por los PDFs.
///
/// Estilo basado en las plantillas oficiales de Intranet UPLA: documento
/// formal, fondo blanco, tipografía sans-serif, tablas con bordes finos,
/// títulos centrados en mayúsculas. Sin degradados ni cabeceras de marca.
abstract final class PdfTheme {
  // Negro suave para textos (no #000 puro — más profesional).
  static const PdfColor text = PdfColor.fromInt(0xFF1A1A1A);
  static const PdfColor textSecondary = PdfColor.fromInt(0xFF555555);
  static const PdfColor textMuted = PdfColor.fromInt(0xFF888888);

  // Líneas de tabla y separadores.
  static const PdfColor border = PdfColor.fromInt(0xFFBFBFBF);
  static const PdfColor borderStrong = PdfColor.fromInt(0xFF707070);

  // Cabecera de tabla — gris muy claro como Intranet.
  static const PdfColor tableHeader = PdfColor.fromInt(0xFFE5E7EB);

  // Color institucional para el acento del título (mínimo).
  static const PdfColor institucional = PdfColor.fromInt(0xFF173E61);
}

/// Cabecera del documento estilo Intranet: título centrado en mayúsculas
/// con una línea sutil debajo. [periodoSuffix] aparece en una sub-línea.
pw.Widget pdfTitle(String titulo, {String? periodoSuffix}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfTheme.borderStrong, width: 1.2),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          titulo.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
            color: PdfTheme.institucional,
            letterSpacing: 0.5,
          ),
        ),
        if (periodoSuffix != null && periodoSuffix.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(
            periodoSuffix.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    ),
  );
}

/// Fila etiqueta:valor estilo Intranet. Etiqueta en bold, dos puntos, valor.
pw.Widget pdfDataRow(String label, String value, {double labelWidth = 110}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: labelWidth,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfTheme.text,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10, color: PdfTheme.text),
          ),
        ),
      ],
    ),
  );
}

/// Pie con créditos discretos y fecha de generación.
pw.Widget pdfFooter() {
  final ahora = DateTime.now();
  String fmt(int n) => n.toString().padLeft(2, '0');
  final fecha = '${fmt(ahora.day)}/${fmt(ahora.month)}/${ahora.year} '
      '${fmt(ahora.hour)}:${fmt(ahora.minute)}';
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 12),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfTheme.border)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generado por Nexo · $fecha',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfTheme.textMuted,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
        pw.Text(
          'Documento informativo · Para trámites oficiales usar los servicios oficiales UPLA',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfTheme.textMuted,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}

/// Encabezado de tabla estilo Intranet (fondo gris claro, texto negro).
pw.Widget pdfTableHeader(String text, {pw.TextAlign? align}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align ?? pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfTheme.text,
        ),
      ),
    );

/// Celda de tabla estándar.
pw.Widget pdfTableCell(String text, {pw.TextAlign? align}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align ?? pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9.5, color: PdfTheme.text),
      ),
    );
