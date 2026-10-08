param([Parameter(Mandatory)][string[]]$Path)
$ErrorActionPreference = 'Stop'

# A custom scan reports detections without quarantining the developer's files.
# This does not change Defender settings or exclusions.
$platform = Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform'
$scanner = Get-ChildItem -LiteralPath $platform -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  ForEach-Object { Join-Path $_.FullName 'MpCmdRun.exe' } |
  Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
  Select-Object -First 1
if (-not $scanner) {
  $scanner = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
}
if (-not (Test-Path -LiteralPath $scanner -PathType Leaf)) {
  throw 'Microsoft Defender scanner is unavailable. Release verification cannot continue.'
}
foreach ($item in $Path) {
  $target = (Resolve-Path -LiteralPath $item).Path
  & $scanner -Scan -ScanType 3 -File $target -DisableRemediation
  if ($LASTEXITCODE -ne 0) {
    throw "Defender did not approve '$target' (exit $LASTEXITCODE). Review the detection or scan error before publishing."
  }
  Write-Host "PASS: Defender scan of $target"
}
