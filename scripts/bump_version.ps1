# bump_version.ps1 — Incrementa la versión de Nexo en pubspec.yaml
#
# Lee la versión actual de pubspec.yaml, la incrementa según el tipo
# (major, minor, patch) y actualiza pubspec.yaml + config.dart.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Type patch
#   powershell -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Type minor
#   powershell -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Type major
#   powershell -ExecutionPolicy Bypass -File scripts\bump_version.ps1 -Set 2.0.0
#
# El build number (+N) siempre se incrementa en 1 independientemente del tipo.

param(
  [ValidateSet('major', 'minor', 'patch')]
  [string]$Type,

  [string]$Set
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$pubspec = Join-Path $root 'pubspec.yaml'

if (-not $Type -and -not $Set) {
  throw "Especificar -Type (major|minor|patch) o -Set X.Y.Z"
}

# --- Leer versión actual ---
$lines = [System.IO.File]::ReadAllLines($pubspec, [System.Text.Encoding]::UTF8)
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\s*version:\s*(.+)$') {
    $idx = $i
    $rawVersion = $Matches[1].Trim()
    break
  }
}
if ($idx -lt 0) { throw "No se encontró 'version:' en $pubspec" }

$parts = $rawVersion -split '\+'
$oldSemver = $parts[0].Trim()
$oldBuild = if ($parts.Length -gt 1) { [int]$parts[1].Trim() } else { 0 }
$semParts = $oldSemver -split '\.'
if ($semParts.Length -ne 3) { throw "Versión '$oldSemver' no es X.Y.Z" }

$major = [int]$semParts[0]
$minor = [int]$semParts[1]
$patch = [int]$semParts[2]

Write-Host "Versión actual: $oldSemver+$oldBuild" -ForegroundColor Cyan

# --- Calcular nueva versión ---
if ($Set) {
  if ($Set -notmatch '^\d+\.\d+\.\d+$') { throw "Formato inválido: '$Set' (esperado X.Y.Z)" }
  $newSemver = $Set
} else {
  switch ($Type) {
    'major' { $major++; $minor = 0; $patch = 0 }
    'minor' { $minor++; $patch = 0 }
    'patch' { $patch++ }
  }
  $newSemver = "$major.$minor.$patch"
}

$newBuild = $oldBuild + 1
$newFull = "$newSemver+$newBuild"

Write-Host "Nueva versión : $newSemver+$newBuild" -ForegroundColor Green

# --- Actualizar pubspec.yaml ---
$lines[$idx] = "version: $newFull"
$lines | Set-Content $pubspec -Encoding UTF8

Write-Host "pubspec.yaml actualizado." -ForegroundColor Green

# --- Sincronizar config.dart ---
Write-Host ""
& (Join-Path $PSScriptRoot 'sync_version.ps1')

# --- Mostrar resumen ---
Write-Host ""
Write-Host "=== Resumen ===" -ForegroundColor Yellow
Write-Host "  Versión anterior : $oldSemver+$oldBuild"
Write-Host "  Versión nueva    : $newSemver+$newBuild"
Write-Host "  Tag para release : v$newSemver"
Write-Host ""
Write-Host "Siguiente paso: escribir las notas en CHANGELOG.md y luego:" -ForegroundColor Cyan
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts\build_release.ps1 -Publish" -ForegroundColor White
