# Read-only audit of release downloads and their unpacked contents.
param(
  [string]$ArtifactDir = (Join-Path $PSScriptRoot '..\dist')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$files = @(Get-ChildItem -LiteralPath $ArtifactDir -File |
  Where-Object { $_.Extension -in @('.apk', '.zip', '.exe', '.aab', '.msix') })
if ($files.Count -eq 0) { throw "No release artifacts found in $ArtifactDir" }
foreach ($file in $files) {
  $groups = @()
  $largest = @()
  $unpacked = $null
  if ($file.Extension -in @('.apk', '.zip', '.aab', '.msix')) {
    $archive = [IO.Compression.ZipFile]::OpenRead($file.FullName)
    try {
      $entries = @($archive.Entries | Where-Object { $_.Name })
      $unpacked = ($entries | Measure-Object Length -Sum).Sum
      $groups = @($entries | Group-Object -Property {
        if ($_.FullName -match '^(?:base/)?lib/([^/]+)/') { "native/$($Matches[1])" }
        elseif ($_.FullName -match 'flutter_assets/') { 'flutter_assets' }
        else { 'other' }
      } | ForEach-Object {
        [pscustomobject]@{
          Group = $_.Name
          Bytes = ($_.Group | Measure-Object Length -Sum).Sum
          CompressedBytes = ($_.Group | Measure-Object CompressedLength -Sum).Sum
        }
      })
      $largest = @($entries | Sort-Object Length -Descending | Select-Object -First 10 |
        ForEach-Object {
          [pscustomobject]@{ Path = $_.FullName; Bytes = $_.Length; CompressedBytes = $_.CompressedLength }
        })
    } finally { $archive.Dispose() }
  }
  [pscustomobject]@{
    Artifact = $file.Name
    Bytes = $file.Length
    MB = [math]::Round($file.Length / 1000000, 2)
    UnpackedBytes = $unpacked
    Groups = $groups
    Largest = $largest
  }
}
