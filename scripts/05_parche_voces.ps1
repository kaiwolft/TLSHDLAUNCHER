# The Last Story - Paso 5: parche del archivo de sonido para las voces japonesas
$ErrorActionPreference = 'Stop'
$beta = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $beta 'logs'
Start-Transcript -Path (Join-Path $logs '05_parche_voces.log') -Force | Out-Null
try {
  $src   = Join-Path $beta 'extraido\US\DATA\files\sound\lastworld.brsar'
  $vjp   = Join-Path $beta 'juego\US_VOZ_JP'
  $dst   = Join-Path $vjp 'DATA\files\sound\lastworld.brsar'
  $patch = Join-Path $PSScriptRoot 'brsar_voces_jp.tlsp'
  $md5Src = 'E67F13C0558047667C4167399D60EF0F'
  $md5Dst = '378DE37B5EA4EFAE338390BC423BF2CF'

  Write-Host "Verificando archivo original..."
  if ((Get-FileHash $src -Algorithm MD5).Hash -ne $md5Src) { throw "El lastworld.brsar original no coincide con el esperado." }

  $b = [IO.File]::ReadAllBytes($src)
  $p = [IO.File]::ReadAllBytes($patch)
  if ([Text.Encoding]::ASCII.GetString($p, 0, 4) -ne 'TLSP') { throw "Archivo de parche invalido." }
  $n = [BitConverter]::ToUInt32($p, 4)
  Write-Host "Aplicando $n correcciones de tamano..."
  for ($i = 0; $i -lt $n; $i++) {
    $o   = 8 + $i * 12
    $off = [BitConverter]::ToUInt32($p, $o)
    $old = [BitConverter]::GetBytes([BitConverter]::ToUInt32($p, $o + 4)); [Array]::Reverse($old)
    $new = [BitConverter]::GetBytes([BitConverter]::ToUInt32($p, $o + 8)); [Array]::Reverse($new)
    for ($k = 0; $k -lt 4; $k++) { if ($b[$off + $k] -ne $old[$k]) { throw "Dato inesperado en la posicion $off" } }
    [Array]::Copy($new, 0, $b, $off, 4)
  }
  # El destino es un enlace al archivo original: se borra el enlace y se escribe un archivo nuevo
  if (Test-Path $dst) { Remove-Item $dst -Force }
  [IO.File]::WriteAllBytes($dst, $b)
  $h = (Get-FileHash $dst -Algorithm MD5).Hash
  if ($h -ne $md5Dst) { throw "El archivo parcheado no coincide ($h)." }
  if ((Get-FileHash $src -Algorithm MD5).Hash -ne $md5Src) { throw "El original se modifico por error." }
  Set-Content (Join-Path $vjp 'listo.txt') "voces japonesas + brsar parcheado" -Encoding ASCII

  $old = Join-Path $beta 'juego\JP_SOLO_DIALOGOS'
  if (Test-Path $old) { Remove-Item $old -Recurse -Force }
  Remove-Item (Join-Path $beta 'PRUEBA_2_JAPONES_SOLO_DIALOGOS.bat') -ErrorAction SilentlyContinue
  Write-Host "`nLISTO. Parche aplicado y verificado."
} catch { Write-Host "`nERROR: $($_.Exception.Message)" }
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
