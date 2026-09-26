import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class WindowsProcess {
  static String literal(String value) => "'${value.replaceAll("'", "''")}'";
  static Future<void> script(String body, {bool detached = false}) async {
    if (!Platform.isWindows) throw UnsupportedError('Windows only');
    final helper = p.join(
      p.dirname(Platform.resolvedExecutable),
      'nexo_setup_helper.exe',
    );
    if (!await File(helper).exists())
      throw StateError(
        'Falta nexo_setup_helper.exe. Reinstala el paquete completo.',
      );
    final script =
        "\$ErrorActionPreference = 'Stop'\ntry {\n$body\nexit 0\n} catch { exit 1 }";
    final bytes = <int>[];
    for (final unit in script.codeUnits) {
      bytes.addAll([unit & 255, unit >> 8]);
    }
    final result = await Process.run(helper, [
      '--powershell',
      base64Encode(bytes),
      if (detached) '--detach',
    ]);
    if (result.exitCode != 0)
      throw ProcessException(
        helper,
        [],
        'No se completó la operación de Windows (código ${result.exitCode}).',
        result.exitCode,
      );
  }
}
