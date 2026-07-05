# sync_version.ps1 — Sincroniza la versión de pubspec.yaml → config.dart
#
# Fuente de verdad: pubspec.yaml (campo `version: X.Y.Z+B`).
# Destino: lib/core/config.dart (constantes `appVersion` y `appBuild`).
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\sync_version.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\sync_version.ps1 -Check
#     (solo verifica sin modificar; exit code 1 si están desincronizados)

param(
  [switch]$Check
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspec = Join-Path $root 'pubspec.yaml'
$config  = Join-Path (Join-Path (Join-Path $root 'lib') 'core') 'config.dart'

# --- Leer versión de pubspec.yaml ---
$pubLines = [System.IO.File]::ReadAllLines($pubspec, [System.Text.Encoding]::UTF8)
$verMatch = $pubLines | Select-String -Pattern '^\s*version:\s*(.+)$' | Select-Object -First 1
if (-not $verMatch) { throw "No se encontró 'version:' en $pubspec" }

$rawVersion = $verMatch.Matches[0].Groups[1].Value.Trim()
# Separar semver y build number: "1.3.0+5" → "1.3.0", 5
$parts = $rawVersion -split '\+'
$semver = $parts[0].Trim()
$buildNum = if ($parts.Length -gt 1) { [int]$parts[1].Trim() } else { 1 }

if ($semver -notmatch '^\d+\.\d+\.\d+$') {
  throw "Versión '$semver' no tiene formato semver válido (X.Y.Z)"
}

Write-Host "pubspec.yaml  : version=$semver  build=$buildNum" -ForegroundColor Cyan

# --- Leer valores actuales de config.dart ---
$configContent = [System.IO.File]::ReadAllText($config, [System.Text.Encoding]::UTF8)

$currentVer = if ($configContent -match "appVersion\s*=\s*'([^']+)'") { $Matches[1] } else { $null }
$currentBuild = if ($configContent -match "appBuild\s*=\s*(\d+)") { [int]$Matches[1] } else { $null }

Write-Host "config.dart   : version=$currentVer  build=$currentBuild" -ForegroundColor Cyan

if ($currentVer -eq $semver -and $currentBuild -eq $buildNum) {
  Write-Host "`nYa están sincronizados." -ForegroundColor Green
  exit 0
}

if ($Check) {
  Write-Host "`nDESINCRONIZADOS. Ejecutar sin -Check para corregir." -ForegroundColor Red
  exit 1
}

# --- Actualizar config.dart ---
$newContent = $configContent
$newContent = $newContent -replace "(appVersion\s*=\s*')[^']+'", "`${1}$semver'"
$newContent = $newContent -replace "(appBuild\s*=\s*)\d+", "`${1}$buildNum"

[System.IO.File]::WriteAllText($config, $newContent, [System.Text.Encoding]::UTF8)

Write-Host "`nconfig.dart actualizado:" -ForegroundColor Green
Write-Host "  appVersion = '$semver'" -ForegroundColor Green
Write-Host "  appBuild   = $buildNum" -ForegroundColor Green
