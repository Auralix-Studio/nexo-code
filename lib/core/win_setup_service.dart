import 'dart:io';
import 'package:path/path.dart' as p;

class WinSetupService {
  static String get localAppData => Platform.environment['LOCALAPPDATA'] ?? '';
  static String get appData => Platform.environment['APPDATA'] ?? '';
  static String get userProfile => Platform.environment['USERPROFILE'] ?? '';
  static String get officialInstallDir => p.join(localAppData, 'Nexo');
  static String get officialExePath =>
      p.join(officialInstallDir, 'bin', 'nexo.exe');
  static bool get isInstalledInstance {
    if (!Platform.isWindows) return true;
    final currentExe = p.canonicalize(Platform.resolvedExecutable);
    final officialExe = p.canonicalize(officialExePath);
    return currentExe == officialExe;
  }

  static Future<bool> checkIsAlreadyInstalled() async {
    return await File(officialExePath).exists();
  }

  static Future<void> copyApplicationFiles({
    required void Function(double progress) onProgress,
  }) async {
    final currentBinDir = p.dirname(Platform.resolvedExecutable);
    final targetBinDir = p.join(officialInstallDir, 'bin');
    final sourceDir = Directory(currentBinDir);
    final targetDir = Directory(targetBinDir);
    if (await targetDir.exists()) {
      try {
        await targetDir.delete(recursive: true);
      } catch (_) {}
    }
    await targetDir.create(recursive: true);
    final List<FileSystemEntity> entities = await sourceDir
        .list(recursive: true)
        .toList();
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

  static Future<void> registerUninstall({required String version}) async {
    final uninstallString = '"$officialExePath" --uninstall';
    final iconPath = '$officialExePath,0';
    final script =
        '''
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

  static Future<void> createShortcuts({
    required bool desktop,
    required bool startMenu,
  }) async {
    final workingDir = p.join(officialInstallDir, 'bin');
    final parts = <String>[r'$WshShell = New-Object -ComObject WScript.Shell'];
    if (desktop) {
      parts.add(
        r'''
        $DesktopPath = [System.Environment]::GetFolderPath('Desktop')
        $Shortcut1 = $WshShell.CreateShortcut("$DesktopPath\Nexo UPLA.lnk")
        $Shortcut1.TargetPath = "'''
        '$officialExePath'
        r'''"
        $Shortcut1.WorkingDirectory = "'''
        '$workingDir'
        r'''"
        $Shortcut1.IconLocation = "'''
        '$officialExePath'
        r''',0"
        $Shortcut1.Save()
      ''',
      );
    }
    if (startMenu) {
      parts.add(
        r'''
        $StartMenuPath = [System.Environment]::GetFolderPath('StartMenu')
        $ProgramsPath = Join-Path $StartMenuPath "Programs"
        $Shortcut2 = $WshShell.CreateShortcut("$ProgramsPath\Nexo UPLA.lnk")
        $Shortcut2.TargetPath = "'''
        '$officialExePath'
        r'''"
        $Shortcut2.WorkingDirectory = "'''
        '$workingDir'
        r'''"
        $Shortcut2.IconLocation = "'''
        '$officialExePath'
        r''',0"
        $Shortcut2.Save()
      ''',
      );
    }
    if (parts.length == 1) return;
    await Process.run('powershell', ['-Command', parts.join('\n')]);
  }

  static Future<void> registerAutoStart() async {
    final script =
        '''
      \$regPath = "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
      New-ItemProperty -Path \$regPath -Name "NexoUPLA" -Value '"$officialExePath"' -PropertyType String -Force | Out-Null
    ''';
    await Process.run('powershell', ['-Command', script]);
  }

  static Future<void> removeAutoStart() async {
    await Process.run('powershell', [
      '-Command',
      r'Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "NexoUPLA" -ErrorAction SilentlyContinue',
    ]);
  }

  static Future<void> performUninstall({
    required bool purgeData,
    required void Function(String message) onStepProgress,
  }) async {
    onStepProgress("Removiendo del Registro de Windows...");
    await Process.run('powershell', [
      '-Command',
      'Remove-Item -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\Nexo" -Recurse -ErrorAction SilentlyContinue',
    ]);
    onStepProgress("Eliminando accesos directos...");
    const script = '''
      \$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
      Remove-Item -Path (Join-Path \$DesktopPath "Nexo UPLA.lnk") -Force -ErrorAction SilentlyContinue
      \$StartMenuPath = [System.Environment]::GetFolderPath('StartMenu')
      \$ProgramsPath = Join-Path \$StartMenuPath "Programs"
      Remove-Item -Path (Join-Path \$ProgramsPath "Nexo UPLA.lnk") -Force -ErrorAction SilentlyContinue
    ''';
    await Process.run('powershell', ['-Command', script]);
    if (purgeData) {
      onStepProgress("Purgando base de datos y configuraciones locales...");
      final dbFile = File(p.join(localAppData, 'nexo_cache.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final roamingDir = Directory(p.join(appData, 'Nexo'));
      if (await roamingDir.exists()) {
        await roamingDir.delete(recursive: true);
      }
    }
    onStepProgress("Removiendo archivos de programa...");
    final binDir = Directory(p.join(officialInstallDir, 'bin'));
    if (await binDir.exists()) {
      final list = await binDir.list().toList();
      for (final entity in list) {
        if (entity is File &&
            !p.canonicalize(entity.path).endsWith('nexo.exe')) {
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

  static Future<void> triggerSelfDestruct() async {
    final cmdScript =
        'timeout /t 1 /nobreak && rmdir /s /q "$officialInstallDir"';
    await Process.start('cmd.exe', [
      '/c',
      cmdScript,
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}
