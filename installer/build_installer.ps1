param(
  [Parameter(Mandatory)][string]$ReleaseDir,
  [Parameter(Mandatory)][string]$OutFile,
  [string]$ZipOutFile,
  [switch]$ZipOnly,
  [string]$CertificateThumbprint = $env:NEXO_SIGN_CERT_SHA1
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
$OutFile = [IO.Path]::GetFullPath($OutFile)
foreach ($required in @('nexo.exe','nexo_setup_helper.exe','flutter_windows.dll','data\icudtl.dat')) {
  if (-not (Test-Path -LiteralPath (Join-Path $ReleaseDir $required))) { throw "Incomplete release: $required" }
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw 'Visual Studio C++ tools not found.' }
$vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
$work = Join-Path ([IO.Path]::GetTempPath()) ('nexo-build-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $bundle = Join-Path $work 'bundle'
  New-Item -ItemType Directory -Path $bundle | Out-Null
  foreach ($name in @('nexo.exe','nexo_setup_helper.exe','native_assets.json','data')) {
    $source = Join-Path $ReleaseDir $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $bundle -Recurse }
  }
  Get-ChildItem -LiteralPath $ReleaseDir -Filter '*.dll' -File | Copy-Item -Destination $bundle
  # Include the Microsoft runtime for machines without Visual Studio installed.
  $crt = Get-ChildItem -Path (Join-Path $vsPath 'VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT') -Directory | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $crt) { throw 'Visual C++ redistributable DLLs not found.' }
  Get-ChildItem -LiteralPath $crt.FullName -Filter '*.dll' -File | Copy-Item -Destination $bundle -Force
  $payload = Join-Path $work 'payload.zip'
  Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $payload
  if ($ZipOutFile) {
    $ZipOutFile = [IO.Path]::GetFullPath($ZipOutFile)
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ZipOutFile) | Out-Null
    Copy-Item -LiteralPath $payload -Destination $ZipOutFile -Force
  }
  if ($ZipOnly) { return }
  $resourcePath = $payload.Replace('\','\\')
  $iconPath = (Join-Path $here '..\windows\runner\resources\app_icon.ico').Replace('\','\\')
  @("101 RCDATA `"$resourcePath`"", "1 ICON `"$iconPath`"") | Set-Content -LiteralPath (Join-Path $work 'payload.rc') -Encoding ascii
  $main = Join-Path $here 'main.cpp'
  $built = Join-Path $work 'setup.exe'
  $sign = ''
  if ($CertificateThumbprint) {
    if ($CertificateThumbprint -notmatch '^[0-9a-fA-F]{40}$') { throw 'Invalid signing certificate thumbprint.' }
    $sign = "signtool sign /sha1 $CertificateThumbprint /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 `"$built`" >> build.log 2>&1`r`nif errorlevel 1 exit /b 1"
  }
  @"
@echo off
call "$vcvars" >nul 2>nul
cd /d "$work"
rc /nologo payload.rc >build.log 2>&1
if errorlevel 1 exit /b 1
cl /nologo /O2 /MT /EHsc /utf-8 /DUNICODE /D_UNICODE "$main" payload.res /Fe:"$built" /link /SUBSYSTEM:WINDOWS shell32.lib ole32.lib user32.lib gdi32.lib >>build.log 2>&1
if errorlevel 1 exit /b 1
$sign
"@ | Set-Content -LiteralPath (Join-Path $work 'compile.bat') -Encoding ascii
  & cmd /c "`"$(Join-Path $work 'compile.bat')`""
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $built)) {
    Get-Content -LiteralPath (Join-Path $work 'build.log')
    throw 'Installer compilation/signing failed.'
  }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
  Copy-Item -LiteralPath $built -Destination $OutFile -Force
  if (-not $CertificateThumbprint) { Write-Warning 'Unsigned installer: configure NEXO_SIGN_CERT_SHA1 for Authenticode signing.' }
  Write-Host "OK: $OutFile"
} finally {
  $resolvedWork = [IO.Path]::GetFullPath($work)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
  if (-not $resolvedWork.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path -Leaf $resolvedWork) -notlike 'nexo-build-*') { throw 'Unsafe build cleanup path.' }
  Remove-Item -LiteralPath $resolvedWork -Recurse -Force
}
