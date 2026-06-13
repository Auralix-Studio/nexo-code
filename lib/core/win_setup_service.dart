import 'dart:io';
import 'package:path/path.dart' as p;

class WinSetupService {
  /// Directorio %LOCALAPPDATA%
  static String get localAppData => Platform.environment['LOCALAPPDATA'] ?? '';

  /// Directorio %APPDATA%
  static String get appData => Platform.environment['APPDATA'] ?? '';

  /// Directorio %USERPROFILE%
  static String get userProfile => Platform.environment['USERPROFILE'] ?? '';

  /// Directorio de instalación oficial: %LOCALAPPDATA%\Nexo
  static String get officialInstallDir => p.join(localAppData, 'Nexo');

  /// Ruta del ejecutable oficial instalado: %LOCALAPPDATA%\Nexo\bin\nexo.exe
  static String get officialExePath => p.join(officialInstallDir, 'bin', 'nexo.exe');

  /// Verifica si la instancia actual está corriendo desde la ruta oficial instalada
  static bool get isInstalledInstance {
    if (!Platform.isWindows) return true;
    final currentExe = p.canonicalize(Platform.resolvedExecutable);
    final officialExe = p.canonicalize(officialExePath);
    return currentExe == officialExe;
  }

  /// Verifica si existe una versión instalada previamente en el sistema
  static Future<bool> checkIsAlreadyInstalled() async {
    return await File(officialExePath).exists();
  }

  /// Copia recursivamente el directorio actual del ejecutable hacia el destino de instalación.
  static Future<void> copyApplicationFiles({
    required void Function(double progress) onProgress,
  }) async {
    final currentBinDir = p.dirname(Platform.resolvedExecutable);
    final targetBinDir = p.join(officialInstallDir, 'bin');

    final sourceDir = Directory(currentBinDir);
    final targetDir = Directory(targetBinDir);

    if (await targetDir.exists()) {
      // Elimina contenido anterior si existe para evitar archivos residuales corruptos
      try {
        await targetDir.delete(recursive: true);
      } catch (_) {}
    }
    await targetDir.create(recursive: true);

    // Contar total de archivos para calcular el progreso
    final List<FileSystemEntity> entities = await sourceDir.list(recursive: true).toList();
    final total = entities.length;
    if (total == 0) return;

    int copied = 0;
    for (final entity in entities) {
      final relativePath = p.relative(entity.path, from: currentBinDir);
      final destPath = p.join(targetBinDir, relativePath);

      if (entity is Directory) {
        await Directory(destPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(destPath)).create(recursive: true);
        await entity.copy(destPath);
      }
      
      copied++;
      onProgress(copied / total);
    }
  }

  /// Registra la aplicación en el registro de Windows del usuario actual (sin privilegios de admin).
  static Future<void> registerUninstall({required String version}) async {
    final uninstallString = '"$officialExePath" --uninstall';
    final iconPath = '$officialExePath,0';

    final script = '''
      \$regPath = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Nexo"
      New-Item -Path \$regPath -Force | Out-Null
      New-ItemProperty -Path \$regPath -Name "DisplayName" -Value "Nexo UPLA" -PropertyType String -Force | Out-Null
      New-ItemProperty -Path \$regPath -Name "UninstallString" -Value '$uninstallString' -PropertyType String -Force | Out-Null
      New-ItemProperty -Path \$regPath -Name "DisplayIcon" -Value "$iconPath" -PropertyType String -Force | Out-Null
      New-ItemProperty -Path \$regPath -Name "DisplayVersion" -Value "$version" -PropertyType String -Force | Out-Null
      New-ItemProperty -Path \$regPath -Name "Publisher" -Value "Nexo Team" -PropertyType String -Force | Out-Null
    ''';

    await Process.run('powershell', ['-Command', script]);
  }

  /// Crea los accesos directos solicitados. Cada uno es opcional: si el
  /// usuario desmarcó la opción en el asistente, no se crea ese atajo.
  static Future<void> createShortcuts({
    required bool desktop,
    required bool startMenu,
  }) async {
    final workingDir = p.join(officialInstallDir, 'bin');
    final parts = <String>[r'$WshShell = New-Object -ComObject WScript.Shell'];

    if (desktop) {
      parts.add(r'''
        $DesktopPath = [System.Environment]::GetFolderPath('Desktop')
        $Shortcut1 = $WshShell.CreateShortcut("$DesktopPath\Nexo UPLA.lnk")
        $Shortcut1.TargetPath = "''' '$officialExePath' r'''"
        $Shortcut1.WorkingDirectory = "''' '$workingDir' r'''"
        $Shortcut1.IconLocation = "''' '$officialExePath' r''',0"
        $Shortcut1.Save()
      ''');
    }
    if (startMenu) {
      parts.add(r'''
        $StartMenuPath = [System.Environment]::GetFolderPath('StartMenu')
        $ProgramsPath = Join-Path $StartMenuPath "Programs"
        $Shortcut2 = $WshShell.CreateShortcut("$ProgramsPath\Nexo UPLA.lnk")
        $Shortcut2.TargetPath = "''' '$officialExePath' r'''"
        $Shortcut2.WorkingDirectory = "''' '$workingDir' r'''"
        $Shortcut2.IconLocation = "''' '$officialExePath' r''',0"
        $Shortcut2.Save()
      ''');
    }

    if (parts.length == 1) return; // No hay nada que crear.
    await Process.run('powershell', ['-Command', parts.join('\n')]);
  }

  /// Registra Nexo en el arranque de Windows del usuario actual (sin admin).
  /// Usa `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` — el lugar
  /// estándar y seguro para auto-arranque por-usuario.
  static Future<void> registerAutoStart() async {
    final script = '''
      \$regPath = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
      New-ItemProperty -Path \$regPath -Name "NexoUPLA" -Value '"$officialExePath"' -PropertyType String -Force | Out-Null
    ''';
    await Process.run('powershell', ['-Command', script]);
  }

  /// Quita Nexo del arranque automático (usado en desinstalación o cuando
  /// el usuario desactiva la opción manualmente).
  static Future<void> removeAutoStart() async {
    await Process.run('powershell', [
      '-Command',
      r'Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "NexoUPLA" -ErrorAction SilentlyContinue'
    ]);
  }

  /// Ejecuta el proceso de desinstalación removiendo registros, accesos directos y datos
  static Future<void> performUninstall({
    required bool purgeData,
    required void Function(String message) onStepProgress,
  }) async {
    // 1. Eliminar del Registro de Windows
    onStepProgress("Removiendo del Registro de Windows...");
    await Process.run('powershell', [
      '-Command',
      'Remove-Item -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Nexo" -Recurse -ErrorAction SilentlyContinue'
    ]);

    // 2. Eliminar accesos directos
    onStepProgress("Eliminando accesos directos...");
    const script = '''
      \$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
      Remove-Item -Path (Join-Path \$DesktopPath "Nexo UPLA.lnk") -Force -ErrorAction SilentlyContinue
      
      \$StartMenuPath = [System.Environment]::GetFolderPath('StartMenu')
      \$ProgramsPath = Join-Path \$StartMenuPath "Programs"
      Remove-Item -Path (Join-Path \$ProgramsPath "Nexo UPLA.lnk") -Force -ErrorAction SilentlyContinue
    ''';
    await Process.run('powershell', ['-Command', script]);

    // 3. Limpiar base de datos y preferencias del usuario
    if (purgeData) {
      onStepProgress("Purgando base de datos y configuraciones locales...");
      
      // SQLite cache db
      final dbFile = File(p.join(localAppData, 'nexo_cache.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // Shared Preferences
      final roamingDir = Directory(p.join(appData, 'Nexo'));
      if (await roamingDir.exists()) {
        await roamingDir.delete(recursive: true);
      }
    }

    // 4. Eliminar ejecutables principales
    onStepProgress("Removiendo archivos de programa...");
    final binDir = Directory(p.join(officialInstallDir, 'bin'));
    if (await binDir.exists()) {
      // Nota: Dado que estamos ejecutando la app actual desde bin, este ejecutable se bloqueará.
      // Así que borraremos todo lo demás que se pueda en bin, y lo residual se purgará
      // en la fase de autodestrucción.
      final list = await binDir.list().toList();
      for (final entity in list) {
        if (entity is File && !p.canonicalize(entity.path).endsWith('nexo.exe')) {
          try {
            await entity.delete();
          } catch (_) {}
        } else if (entity is Directory) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    }
  }

  /// Ejecuta un comando desprendido de Windows CMD para borrar la carpeta del programa
  /// una vez que este ejecutable se haya apagado por completo.
  static Future<void> triggerSelfDestruct() async {
    // CMD esperará 1 segundo y eliminará recursivamente el directorio
    final cmdScript = 'timeout /t 1 /nobreak && rmdir /s /q "$officialInstallDir"';

    await Process.start(
      'cmd.exe',
      ['/c', cmdScript],
      mode: ProcessStartMode.detached,
    );

    exit(0);
  }
}
