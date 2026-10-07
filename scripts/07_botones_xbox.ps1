# The Last Story - Paso 7: pack alternativo de botones Xbox + volcado de texturas para encontrar las que faltan
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$beta    = Split-Path -Parent $PSScriptRoot
$root    = Split-Path -Parent $beta
$user    = Join-Path $root 'dolphin-2609-x64\Dolphin-x64\User'
$logs    = Join-Path $beta 'logs'
$out     = Join-Path $beta 'para_claude\xbox_alt'
Start-Transcript -Path (Join-Path $logs '07_botones.log') -Force | Out-Null
New-Item -ItemType Directory -Force -Path $out | Out-Null

Write-Host "=== 1. Descargando packs de botones del foro de Dolphin"
$packs = @{ 'xbox_original.7z' = 13364; 'xbox_modificado.7z' = 13370 }
foreach ($k in $packs.Keys) {
  $f = Join-Path $out $k
  try {
    Invoke-WebRequest -UseBasicParsing -UserAgent 'curl/8.4.0' -Uri "https://forums.dolphin-emu.org/attachment.php?aid=$($packs[$k])" -OutFile $f
    $sig = [IO.File]::ReadAllBytes($f)[0..1]
    if ($sig[0] -eq 0x37 -and $sig[1] -eq 0x7A) {
      $d = Join-Path $out ([IO.Path]::GetFileNameWithoutExtension($k)); New-Item -ItemType Directory -Force -Path $d | Out-Null
      tar -xf $f -C $d
      Write-Host "  OK $k -> $((Get-ChildItem $d -Recurse -File).Count) archivos"
      Get-ChildItem $d -Recurse -File | ForEach-Object { Write-Host "     $($_.FullName.Substring($d.Length+1))  $($_.Length)" }
    } else { Write-Host "  $k no es un 7z valido (posible bloqueo del foro)"; }
  } catch { Write-Host "  FALLO $k : $($_.Exception.Message)" }
}

Write-Host "`n=== 2. Activando volcado de texturas (solo la proxima partida)"
Set-Content (Join-Path $beta 'launcher\data\dump_textures.on') 'on' -Encoding ASCII
$dump = Join-Path $user 'Dump\Textures\SLSEXJ'
if (Test-Path $dump) { Remove-Item $dump -Recurse -Force }
Write-Host "  Listo. Las texturas se guardaran en $dump"
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
