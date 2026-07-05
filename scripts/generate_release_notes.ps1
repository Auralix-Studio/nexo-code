# generate_release_notes.ps1 — Genera las notas del release para GitHub

# Extrae la sección correspondiente a la versión actual de CHANGELOG.md y
# genera un archivo RELEASE_NOTES.md en dist/ con la tabla de artefactos,
# hashes SHA-256 e instrucciones de instalación.

# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\generate_release_notes.ps1
#   (ejecutar DESPUÉS de build_release.ps1 para que dist/ tenga los artefactos)
#

# Fuentes:
#   - CHANGELOG.md del repo nexo-releases (../nexo-releases/CHANGELOG.md)
#     o fallback a uno local si no existe
#   - dist/ (artefactos compilados + SHA256SUMS.txt)



param(

  [string]$Version,

  [string]$DistDir,

  [string]$ChangelogPath

)



$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')



# --- Resolver parámetros ---

if (-not $Version) {

  $verLine = [System.IO.File]::ReadAllLines((Join-Path $root 'pubspec.yaml'), [System.Text.Encoding]::UTF8) | Where-Object { $_ -match '^\s*version:\s*(.+)$' }

  $Version = (($verLine -replace '^\s*version:\s*', '').Split('+')[0]).Trim()

}

if (-not $DistDir) { $DistDir = Join-Path $root 'dist' }

if (-not $ChangelogPath) {

  # Intentar el changelog del repo nexo-releases primero

  $releasesChangelog = Join-Path (Join-Path (Resolve-Path (Join-Path $root '..')) 'nexo-releases') 'CHANGELOG.md'

  if (Test-Path $releasesChangelog) {

    $ChangelogPath = $releasesChangelog

  } else {

    $ChangelogPath = Join-Path $root 'CHANGELOG.md'

  }

}



$tag = "v$Version"

Write-Host "Generando release notes para $tag ..." -ForegroundColor Cyan



# --- Extraer sección del CHANGELOG ---

$changelogNotes = ''

if (Test-Path $ChangelogPath) {

  $lines = [System.IO.File]::ReadAllLines($ChangelogPath, [System.Text.Encoding]::UTF8)

  $inSection = $false

  $sectionLines = @()

  $tagline = ''



  foreach ($line in $lines) {

    if ($line -match "^## \[$Version\]" -or $line -match "^## \[?$([regex]::Escape($Version))\]?") {

      $inSection = $true

      continue

    }

    if ($inSection -and $line -match '^## \[') {

      break  # Llegamos a la siguiente versión

    }

    if ($inSection) {

      # La primera línea no vacía después del header es el tagline

      if (-not $tagline -and $line.Trim()) {

        $tagline = $line.Trim()

      }

      $sectionLines += $line

    }

  }



  if ($sectionLines.Count -gt 0) {

    $changelogNotes = ($sectionLines -join "`n").Trim()

    Write-Host "  Extraídas notas del CHANGELOG ($($sectionLines.Count) líneas)" -ForegroundColor Green

  } else {

    Write-Host "  No se encontró sección para [$Version] en CHANGELOG.md" -ForegroundColor DarkYellow

  }

} else {

  Write-Host "  No se encontró CHANGELOG.md en $ChangelogPath" -ForegroundColor DarkYellow

}



# --- Generar tabla de artefactos ---

$artifactTable = ''

$artifacts = @()

if (Test-Path $DistDir) {

  $files = Get-ChildItem $DistDir -File -Exclude 'SHA256SUMS.txt', 'RELEASE_NOTES.md', 'release-meta.json'

  $sums = @{}

  $sumsFile = Join-Path $DistDir 'SHA256SUMS.txt'

  if (Test-Path $sumsFile) {

    [System.IO.File]::ReadAllLines($sumsFile, [System.Text.Encoding]::ASCII) | ForEach-Object {

      $p = $_ -split '\s+', 2

      if ($p.Length -eq 2) { $sums[$p[1].Trim()] = $p[0].Trim() }

    }

  }



  if ($files.Count -gt 0) {

    $artifactTable = "`n## Descarga`n`n"

    $artifactTable += "| Archivo | Tamaño | SHA-256 |`n"

    $artifactTable += "|---------|--------|---------|`n"



    foreach ($f in $files) {

      $sizeMB = [math]::Round($f.Length / 1MB, 0)

      $sha = if ($sums.ContainsKey($f.Name)) { "``$($sums[$f.Name].Substring(0,16))…``" } else { '—' }

      $url = "https://github.com/auralix-studio/nexo/releases/download/$tag/$($f.Name)"

      $artifactTable += "| [$($f.Name)]($url) | $sizeMB MB | $sha |`n"



      $artifacts += @{

        name = $f.Name

        size = $f.Length

        sizeMB = $sizeMB

        sha256 = if ($sums.ContainsKey($f.Name)) { $sums[$f.Name] } else { $null }

        url = $url

      }

    }

  }

}



# --- Instrucciones de verificación ---

$verifySection = @"



## Verificación



**PowerShell:**

``````

Get-FileHash -Algorithm SHA256 .\nexo-$tag-universal.apk

``````



**Bash:**

``````

sha256sum nexo-$tag-universal.apk

``````



## Instalación



- **Usuarios con versión anterior:** la app detecta esta versión al próximo arranque, baja el APK en background y muestra la notificación "Actualización lista para instalar".

- **Instalación limpia:** Android pedirá autorizar "fuente desconocida" para Nexo la primera vez.

"@



# --- Componer release notes ---

$body = "# Nexo $Version`n`n"



if ($changelogNotes) {

  $body += "$changelogNotes`n"

}



if ($artifactTable) {

  $body += $artifactTable

}



$body += $verifySection



# --- Escribir archivo ---

$outFile = Join-Path $DistDir 'RELEASE_NOTES.md'

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

[System.IO.File]::WriteAllText($outFile, $body, [System.Text.Encoding]::UTF8)



Write-Host "`nRelease notes escritas en: $outFile" -ForegroundColor Green



# --- Generar release-meta.json ---

$meta = @{

  version  = $Version

  tag      = $tag

  date     = (Get-Date -Format 'yyyy-MM-dd')

  artifacts = $artifacts

}

$metaFile = Join-Path $DistDir 'release-meta.json'

$meta | ConvertTo-Json -Depth 5 | Set-Content $metaFile -Encoding UTF8

Write-Host "Metadata escrita en: $metaFile" -ForegroundColor Green

