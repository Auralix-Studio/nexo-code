# update_site.ps1 - Actualiza nexo-releases

param(
  [string]$MetaFile,
  [switch]$Push
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$siteDir = Join-Path (Resolve-Path (Join-Path $root '..')) 'nexo-releases'

if (-not $MetaFile) {
  $MetaFile = Join-Path (Join-Path $root 'dist') 'release-meta.json'
}

$meta = [System.IO.File]::ReadAllText($MetaFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$version = $meta.version
$tag = $meta.tag

Write-Host "Actualizando sitio web para $tag ..." -ForegroundColor Cyan



# --- Actualizar changelog.html ---
$clPath = Join-Path $siteDir 'changelog.html'
if (Test-Path $clPath) {
  $clContent = [System.IO.File]::ReadAllText($clPath, [System.Text.Encoding]::UTF8)
  if ($clContent -match [regex]::Escape("Versión $version")) {
    Write-Host "  Versión $version ya existe en changelog.html" -ForegroundColor DarkGray
  } else {
    $changelogMd = Join-Path $siteDir 'CHANGELOG.md'
    if (Test-Path $changelogMd) {
      $mdLines = [System.IO.File]::ReadAllLines($changelogMd, [System.Text.Encoding]::UTF8)
      $inSection = $false
      $sectionLines = @()
      $tagline = ''
      foreach ($line in $mdLines) {
        if ($line -match "^## \[$version\]") { $inSection = $true; continue }
        if ($inSection -and $line -match '^## \[') { break }
        if ($inSection) {
          if (-not $tagline -and $line.Trim()) { $tagline = $line.Trim() }
          $sectionLines += $line
        }
      }
      
      if ($sectionLines.Count -gt 0) {
        $newSection = '    <section data-reveal>' + "`n"
        $newSection += '      <h2>Versión ' + $version + '</h2>' + "`n"
        $newSection += '      <p>' + $tagline + '</p>' + "`n"
        
        $currentSubsection = ''
        $items = @()
        foreach ($line in $sectionLines) {
          if ($line -match '^### (.+)$') {
            if ($items.Count -gt 0) {
              $newSection += '      <h3>' + $currentSubsection + '</h3>' + "`n"
              $newSection += '      <ul>' + "`n"
              foreach ($item in $items) { $newSection += '        <li>' + $item + '</li>' + "`n" }
              $newSection += '      </ul>' + "`n`n"
              $items = @()
            }
            $currentSubsection = $Matches[1]
          }
          elseif ($line -match '^\s*-\s+\*\*(.+?)\*\*(.*)$') { $items += '<strong>' + $Matches[1] + '</strong>' + $Matches[2] }
          elseif ($line -match '^\s*-\s+(.+)$') { $items += $Matches[1] }
        }
        if ($items.Count -gt 0 -and $currentSubsection) {
          $newSection += '      <h3>' + $currentSubsection + '</h3>' + "`n"
          $newSection += '      <ul>' + "`n"
          foreach ($item in $items) { $newSection += '        <li>' + $item + '</li>' + "`n" }
          $newSection += '      </ul>' + "`n"
        }
        $newSection += '    </section>' + "`n"
        
        $insertPoint = '<div class="split-content">'
        $clContent = $clContent -replace [regex]::Escape($insertPoint), ($insertPoint + "`n" + $newSection)
        [System.IO.File]::WriteAllText($clPath, $clContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  changelog.html actualizado." -ForegroundColor Green
      }
    }
  }
}

if ($Push) {
  Push-Location $siteDir
  git add -A
  git commit -m "chore: actualizar sitio para $tag"
  git push
  Pop-Location
}