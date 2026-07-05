# update_site.ps1 — Actualiza el sitio web nexo-releases con la nueva versión

# Lee release-meta.json (generado por build_release.ps1) y actualiza:
#   - downloads.html: versión en links, tamaños, SHA-256
#   - changelog.html: agrega la sección de la nueva versión
#   - Todos los nav-cta (botón "Descargar" del header) en todos los .html

# Uso:
#   powershell -ExecutionPolicy Bypass -File scripts\update_site.ps1 -MetaFile dist\release-meta.json
#   powershell -ExecutionPolicy Bypass -File scripts\update_site.ps1 -MetaFile dist\release-meta.json -Push
#     (además hace commit + push a nexo-releases)



param(

  [string]$MetaFile,

  [switch]$Push

)



$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..')

$siteDir = Join-Path (Resolve-Path (Join-Path $root '..')) 'nexo-releases'



if (-not (Test-Path $siteDir)) {

  throw "No se encontró el directorio nexo-releases en $(Resolve-Path (Join-Path $root '..'))"

}



# --- Resolver metafile ---

if (-not $MetaFile) {

  $MetaFile = Join-Path (Join-Path $root 'dist') 'release-meta.json'

}

if (-not (Test-Path $MetaFile)) {

  throw "No se encontró $MetaFile. Ejecutar build_release.ps1 primero."

}



$meta = [System.IO.File]::ReadAllText($MetaFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

$version = $meta.version

$tag = $meta.tag

$date = $meta.date



Write-Host "Actualizando sitio web para $tag ..." -ForegroundColor Cyan



# --- Detectar versión anterior en downloads.html ---

$dlPath = Join-Path $siteDir 'downloads.html'

$dlContent = [System.IO.File]::ReadAllText($dlPath, [System.Text.Encoding]::UTF8)



# Extraer versión anterior del primer link de descarga

$oldVerMatch = [regex]::Match($dlContent, 'download/v(\d+\.\d+\.\d+)/')

$oldVersion = if ($oldVerMatch.Success) { $oldVerMatch.Groups[1].Value } else { $null }



if (-not $oldVersion) {

  Write-Host "  No se pudo detectar la versión anterior en downloads.html" -ForegroundColor DarkYellow

  $oldVersion = '0.0.0'

}



$oldTag = "v$oldVersion"

Write-Host "  Versión anterior: $oldVersion" -ForegroundColor DarkGray

Write-Host "  Versión nueva   : $version" -ForegroundColor Green



# --- Actualizar downloads.html ---

Write-Host "`n  Actualizando downloads.html..." -ForegroundColor Yellow



# Reemplazar todas las ocurrencias de la versión anterior

$newDlContent = $dlContent -replace [regex]::Escape($oldTag), $tag

$newDlContent = $newDlContent -replace [regex]::Escape($oldVersion), $version



# Actualizar tamaños si tenemos los datos

foreach ($artifact in $meta.artifacts) {

  $name = $artifact.name

  $sizeMB = $artifact.sizeMB



  # Buscar la fila del artefacto por nombre de archivo y actualizar tamaño

  # Patrón: <td class="size">NNN MB</td>

  # Solo actualizamos si encontramos el nombre del archivo cerca

  if ($name -match 'universal') {

    $newDlContent = $newDlContent -replace '(nexo-[^"]*universal\.apk.*?<td class="size">)\d+ MB', "`${1}$sizeMB MB"

  }

}



# Actualizar SHA-256 si están en "pendiente"

foreach ($artifact in $meta.artifacts) {

  if ($artifact.sha256) {

    $fname = $artifact.name -replace [regex]::Escape($tag), "v$version"

    $shortName = [regex]::Escape($fname)

    # Reemplazar hashes pendientes o anteriores

    $newDlContent = $newDlContent -replace "($shortName.*?<span class=""sha"">)[^<]+", "`${1}$($artifact.sha256)"

  }

}



# Actualizar el eyebrow "Versión X.Y.Z"

$newDlContent = $newDlContent -replace 'Versi[oó]n \d+\.\d+\.\d+', "Versión $version"



[System.IO.File]::WriteAllText($dlPath, $newDlContent, [System.Text.UTF8Encoding]::new($false))

Write-Host "    downloads.html actualizado." -ForegroundColor Green



# --- Actualizar nav-cta en todos los HTML ---

Write-Host "`n  Actualizando links de descarga en headers..." -ForegroundColor Yellow

$htmlFiles = Get-ChildItem $siteDir -Filter '*.html' -File

foreach ($f in $htmlFiles) {

  $content = Get-Content $f.FullName -Raw -Encoding UTF8

  $updated = $content -replace "download/$oldTag/nexo-$oldTag-universal\.apk", "download/$tag/nexo-$tag-universal.apk"

  if ($updated -ne $content) {

    [System.IO.File]::WriteAllText($f.FullName, $updated, [System.Text.UTF8Encoding]::new($false))

    Write-Host "    $($f.Name) — nav-cta actualizado" -ForegroundColor Green

  }

}



# --- Actualizar changelog.html ---

Write-Host "`n  Actualizando changelog.html..." -ForegroundColor Yellow

$clPath = Join-Path $siteDir 'changelog.html'

if (Test-Path $clPath) {

  $clContent = [System.IO.File]::ReadAllText($clPath, [System.Text.Encoding]::UTF8)



  # Verificar si la versión ya existe en el changelog

  if ($clContent -match [regex]::Escape("Versión $version")) {

    Write-Host "    Versión $version ya existe en changelog.html — omitido" -ForegroundColor DarkGray

  } else {

    # Leer notas del CHANGELOG.md para insertar

    $changelogMd = Join-Path $siteDir 'CHANGELOG.md'

    if (Test-Path $changelogMd) {

      $mdLines = [System.IO.File]::ReadAllLines($changelogMd, [System.Text.Encoding]::UTF8)

      $inSection = $false

      $sectionLines = @()

      $tagline = ''



      foreach ($line in $mdLines) {

        if ($line -match "^## \[$version\]") {

          $inSection = $true

          continue

        }

        if ($inSection -and $line -match '^## \[') { break }

        if ($inSection) {

          if (-not $tagline -and $line.Trim()) { $tagline = $line.Trim() }

          $sectionLines += $line

        }

      }



      if ($sectionLines.Count -gt 0) {

        # Construir el HTML de la nueva sección

        $newSection = @"



    <section data-reveal>

      <h2>Versión $version</h2>

      <p>$tagline</p>

"@

        # Parsear las subsecciones del markdown a HTML

        $currentSubsection = ''

        $items = @()



        foreach ($line in $sectionLines) {

          if ($line -match '^### (.+)$') {

            # Cerrar subsección anterior

            if ($items.Count -gt 0) {

              $newSection += "      <h3>$currentSubsection</h3>`n      <ul>`n"

              foreach ($item in $items) {

                $newSection += "        <li>$item</li>`n"

              }

              $newSection += "      </ul>`n`n"

              $items = @()

            }

            $currentSubsection = $Matches[1]

          }

          elseif ($line -match '^\s*-\s+\*\*(.+?)\*\*(.*)$') {

            # Item con negrita

            $bold = $Matches[1]

            $rest = $Matches[2]

            $items += "<strong>$bold</strong>$rest"

          }

          elseif ($line -match '^\s*-\s+(.+)$') {

            # Item normal

            $items += $Matches[1]

          }

        }

        # Cerrar última subsección

        if ($items.Count -gt 0 -and $currentSubsection) {

          $newSection += "      <h3>$currentSubsection</h3>`n      <ul>`n"

          foreach ($item in $items) {

            $newSection += "        <li>$item</li>`n"

          }

          $newSection += "      </ul>`n"

        }

        $newSection += "    </section>`n"



        # Insertar después de <div class="split-content">

        $insertPoint = '<div class="split-content">'

        $clContent = $clContent -replace [regex]::Escape($insertPoint), "$insertPoint`n$newSection"

        [System.IO.File]::WriteAllText($clPath, $clContent, [System.Text.UTF8Encoding]::new($false))

        Write-Host "    changelog.html actualizado con sección de $version" -ForegroundColor Green

      } else {

        Write-Host "    No se encontró sección [$version] en CHANGELOG.md — omitido" -ForegroundColor DarkYellow

      }

    }

  }

}



# --- Commit y push (opcional) ---

if ($Push) {

  Write-Host "`n  Commiteando y pushing nexo-releases..." -ForegroundColor Yellow

  Push-Location $siteDir

  try {
    git add -A
    git commit -m "chore: actualizar sitio para $tag"
    git push
    Write-Host "    nexo-releases actualizado y pusheado." -ForegroundColor Green
  } catch {
    Write-Host "    Error al pushear: $_" -ForegroundColor Red
  } finally {
    Pop-Location
  }
}

Write-Host "`nSitio web actualizado para $tag" -ForegroundColor Green