import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/core/windows_process.dart';
import 'package:nexo/core/install_transaction.dart';

class WinSetupService {
  static String get localAppData {
    final value = Platform.environment['LOCALAPPDATA'];
    if (value == null || !p.isAbsolute(value)) {
      throw StateError('LOCALAPPDATA inválido.');
    }
    return value;
  }

  static String get officialInstallDir => p.join(localAppData, 'Nexo');
  static String get databaseDirectory => p.join(officialInstallDir, 'data');
  static Future<void> prepareDatabaseDirectory() async {
    await databaseFactory.setDatabasesPath(databaseDirectory);
    final destination = p.join(databaseDirectory, 'nexo_cache.db');
    if (await File(destination).exists()) return;
    for (final folder in ['bin', 'bin.previous']) {
      final legacy = p.join(
        officialInstallDir,
        folder,
        '.dart_tool',
        'sqflite_common_ffi',
        'databases',
        'nexo_cache.db',
      );
      if (!await File(legacy).exists()) continue;
      final resolved = await File(legacy).resolveSymbolicLinks();
      if (!p.isWithin(p.canonicalize(officialInstallDir), resolved)) continue;
      await Directory(databaseDirectory).create(recursive: true);
      final database = await databaseFactory.openDatabase(
        legacy,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        // SQLite takes a consistent snapshot, including any WAL transactions.
        await database.execute('VACUUM INTO ?', [destination]);
      } finally {
        await database.close();
      }
      return;
    }
  }

  static String get officialExePath =>
      p.join(officialInstallDir, 'bin', 'nexo.exe');
  static bool get isInstalledInstance =>
      !Platform.isWindows ||
      p.equals(
        p.canonicalize(Platform.resolvedExecutable).toLowerCase(),
        p.canonicalize(officialExePath).toLowerCase(),
      );
  static Future<bool> checkIsAlreadyInstalled() =>
      File(officialExePath).exists();
  static String _q(String value) => WindowsProcess.literal(value);
  static Future<void> _closeInstalledApp() => WindowsProcess.script('''
    \$apps = @(Get-Process -Name nexo -ErrorAction SilentlyContinue | Where-Object { \$_.Id -ne $pid -and \$_.Path -eq ${_q(officialExePath)} })
    foreach (\$app in \$apps) {
      if (-not \$app.CloseMainWindow()) { throw 'Cierra Nexo antes de continuar.' }
      if (-not \$app.WaitForExit(15000)) { throw 'Nexo sigue abierto.' }
    }
  ''');
  static Future<void> copyApplicationFiles({
    required void Function(double) onProgress,
  }) async {
    if (isInstalledInstance) {
      throw StateError('Abre el instalador descargado para actualizar.');
    }
    await _closeInstalledApp();
    await InstallTransaction.install(
      source: Directory(p.dirname(Platform.resolvedExecutable)),
      root: Directory(officialInstallDir),
      onProgress: onProgress,
    );
  }

  static const _uninstallKey =
      r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Nexo';
  static const _runKey = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
  static Future<void> registerUninstall({required String version}) =>
      WindowsProcess.script('''
    \$key = ${_q(_uninstallKey)}
    New-Item -Path \$key -Force | Out-Null
    \$values = @{
      DisplayName = 'Nexo UPLA'; DisplayVersion = ${_q(version)}; Publisher = 'Auralix Studio';
      UninstallString = ${_q('"$officialExePath" --uninstall')};
      DisplayIcon = ${_q('$officialExePath,0')}; InstallLocation = ${_q(officialInstallDir)}
    }
    foreach (\$name in \$values.Keys) { New-ItemProperty -LiteralPath \$key -Name \$name -Value \$values[\$name] -PropertyType String -Force | Out-Null }
    foreach (\$name in @('NoModify','NoRepair')) { New-ItemProperty -LiteralPath \$key -Name \$name -Value 1 -PropertyType DWord -Force | Out-Null }
  ''');
  static Future<void> createShortcuts({
    required bool desktop,
    required bool startMenu,
  }) async {
    if (!desktop && !startMenu) return;
    await WindowsProcess.script('''
      \$shell = New-Object -ComObject WScript.Shell
      \$folders = @(${[if (desktop) "[Environment]::GetFolderPath('Desktop')", if (startMenu) "[Environment]::GetFolderPath('Programs')"].join(',')})
      foreach (\$folder in \$folders) {
        \$link = \$shell.CreateShortcut((Join-Path \$folder 'Nexo UPLA.lnk'))
        \$link.TargetPath = ${_q(officialExePath)}
        \$link.WorkingDirectory = ${_q(p.dirname(officialExePath))}
        \$link.IconLocation = ${_q('$officialExePath,0')}
        \$link.Save()
      }
    ''');
  }

  static Future<void> registerAutoStart() => WindowsProcess.script('''
    New-Item -Path ${_q(_runKey)} -Force | Out-Null
    New-ItemProperty -LiteralPath ${_q(_runKey)} -Name NexoUPLA -Value ${_q('"$officialExePath"')} -PropertyType String -Force | Out-Null
  ''');
  static Future<void> removeAutoStart() => WindowsProcess.script('''
    if (Get-ItemProperty -LiteralPath ${_q(_runKey)} -Name NexoUPLA -ErrorAction SilentlyContinue) {
      Remove-ItemProperty -LiteralPath ${_q(_runKey)} -Name NexoUPLA
    }
  ''');
  static Future<void> performUninstall({
    required bool purgeData,
    required void Function(String) onStepProgress,
  }) async {
    onStepProgress('Cerrando Nexo…');
    await _closeInstalledApp();
    if (purgeData) {
      onStepProgress('Eliminando credenciales y datos locales…');
      await AppStorage.instance.clear(keepCredentials: false);
      await deleteDatabase(p.join(await getDatabasesPath(), 'nexo_cache.db'));
      await (await SharedPreferences.getInstance()).clear();
    }
    onStepProgress('Eliminando accesos directos y registro…');
    await removeAutoStart();
    await WindowsProcess.script('''
      if (Test-Path -LiteralPath ${_q(_uninstallKey)}) { Remove-Item -LiteralPath ${_q(_uninstallKey)} -Recurse }
      foreach (\$folder in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
        \$link = Join-Path \$folder 'Nexo UPLA.lnk'
        if (Test-Path -LiteralPath \$link) { Remove-Item -LiteralPath \$link -Force }
      }
    ''');
  }

  static Future<void> _cleanupAfterExit(List<String> children) async {
    final root = p.normalize(p.absolute(officialInstallDir));
    for (final child in children) {
      if (!p.isWithin(root, p.normalize(p.absolute(child)))) {
        throw StateError('Ruta de limpieza inválida.');
      }
    }
    await WindowsProcess.script('''
      \$parent = Get-Process -Id $pid -ErrorAction SilentlyContinue
      if (\$parent) { \$parent.WaitForExit() }
      \$root = [IO.Path]::GetFullPath(${_q(root)})
      if ((Get-Item -LiteralPath \$root).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Ruta redirigida' }
      foreach (\$path in @(${children.map(_q).join(',')})) {
        \$full = [IO.Path]::GetFullPath(\$path)
        if (-not \$full.StartsWith(\$root + '\\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Ruta fuera de Nexo' }
        if (Test-Path -LiteralPath \$full) {
          if ((Get-Item -LiteralPath \$full).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Ruta redirigida' }
          if (Get-ChildItem -LiteralPath \$full -Recurse -Force | Where-Object { \$_.Attributes -band [IO.FileAttributes]::ReparsePoint }) { throw 'La carpeta contiene enlaces' }
          Remove-Item -LiteralPath \$full -Recurse -Force
        }
      }
    ''', detached: true);
  }

  static Future<void> cleanupStaging() async {
    final source = p.dirname(Platform.resolvedExecutable);
    final stage = p.join(officialInstallDir, '_stage');
    if (p.isWithin(stage, source)) await _cleanupAfterExit([source]);
  }

  static Future<void> triggerSelfDestruct() async {
    await _cleanupAfterExit([
      p.join(officialInstallDir, 'bin'),
      p.join(officialInstallDir, 'bin.previous'),
    ]);
    exit(0);
  }
}
