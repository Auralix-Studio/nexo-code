import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Entrega un archivo generado al usuario de la forma natural en cada
/// plataforma: en el celular abre la hoja de compartir (WhatsApp, Drive,
/// correo…); en escritorio lo guarda en Descargas y lo abre.
///
/// Devuelve la ruta donde quedó guardado en escritorio, o `null` si se
/// compartió.
Future<String?> deliverFile(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) async {
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (kIsWeb || isMobile) {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: filename, mimeType: mimeType)],
        fileNameOverrides: [filename],
      ),
    );
    return null;
  }
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final path = _uniquePath(dir.path, filename);
  await File(path).writeAsBytes(bytes, flush: true);
  await launchUrl(Uri.file(path));
  return path;
}

String _uniquePath(String dir, String filename) {
  final base = p.basenameWithoutExtension(filename);
  final ext = p.extension(filename);
  var candidate = p.join(dir, filename);
  var i = 1;
  while (File(candidate).existsSync()) {
    candidate = p.join(dir, '$base ($i)$ext');
    i++;
  }
  return candidate;
}

/// MIME según la extensión de los reportes de SIGMA.
String mimeForExtension(String filename) {
  final ext = p.extension(filename).toLowerCase();
  return switch (ext) {
    '.pdf' => 'application/pdf',
    '.xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    '.xls' => 'application/vnd.ms-excel',
    _ => 'application/octet-stream',
  };
}
