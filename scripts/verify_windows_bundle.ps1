param([Parameter(Mandatory)][string]$Installer, [Parameter(Mandatory)][string]$Zip)
$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path -LiteralPath $Installer).Path
$Zip = (Resolve-Path -LiteralPath $Zip).Path
$bytes = [IO.File]::ReadAllBytes($Installer)
$pe = [BitConverter]::ToInt32($bytes, 0x3c)
if ([BitConverter]::ToUInt16($bytes, $pe + 24 + 68) -ne 2) { throw 'Installer must use GUI subsystem.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($Zip)
try {
  $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\','/') })
  foreach ($name in $names) {
    if ($name -match '(^|/)(\.dart_tool|\.git|updates)(/|$)|\.(db|msix|pdb)$|(^|/)\.\.(/|$)') { throw "Unexpected file in bundle: $name" }
  }
  foreach ($required in @('nexo.exe','nexo_setup_helper.exe','flutter_windows.dll','msvcp140.dll','vcruntime140.dll','data/icudtl.dat')) {
    if ($names -notcontains $required) { throw "Missing file: $required" }
  }
} finally { $archive.Dispose() }
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NexoResourceProbe {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibraryEx(string file, IntPtr reserved, uint flags);
  [DllImport("kernel32.dll")] public static extern IntPtr FindResource(IntPtr module, IntPtr id, IntPtr type);
  [DllImport("kernel32.dll")] public static extern IntPtr LoadResource(IntPtr module, IntPtr resource);
  [DllImport("kernel32.dll")] public static extern IntPtr LockResource(IntPtr resource);
  [DllImport("kernel32.dll")] public static extern uint SizeofResource(IntPtr module, IntPtr resource);
  [DllImport("kernel32.dll")] public static extern bool FreeLibrary(IntPtr module);
}
'@
# LOAD_LIBRARY_AS_DATAFILE reads resources without executing the installer.
$module = [NexoResourceProbe]::LoadLibraryEx($Installer, [IntPtr]::Zero, 2)
if ($module -eq [IntPtr]::Zero) { throw 'Cannot read installer resources.' }
try {
  $resource = [NexoResourceProbe]::FindResource($module, [IntPtr]101, [IntPtr]10)
  $size = [NexoResourceProbe]::SizeofResource($module, $resource)
  if ($size -eq 0) { throw 'Missing archive resource.' }
  $pointer = [NexoResourceProbe]::LockResource([NexoResourceProbe]::LoadResource($module, $resource))
  $payload = New-Object byte[] $size
  [Runtime.InteropServices.Marshal]::Copy($pointer, $payload, 0, $size)
  $hash = [Security.Cryptography.SHA256]::Create()
  try { $actual = [BitConverter]::ToString($hash.ComputeHash($payload)).Replace('-','') }
  finally { $hash.Dispose() }
  if ($actual -ne (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash) { throw 'Embedded payload differs from the verified ZIP.' }
} finally { [NexoResourceProbe]::FreeLibrary($module) | Out-Null }
Write-Host 'PASS: GUI installer, required runtime files, clean archive, matching embedded payload.'
Write-Host ('Authenticode: ' + (Get-AuthenticodeSignature -LiteralPath $Installer).Status)
