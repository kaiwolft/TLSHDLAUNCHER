# The Last Story - Paso 2: variante con voces japonesas, texturas HD + Xbox, config de Dolphin
$ErrorActionPreference = 'Continue'
$beta    = Split-Path -Parent $PSScriptRoot
$root    = Split-Path -Parent $beta
$dolphin = Join-Path $root 'dolphin-2609-x64\Dolphin-x64'
$user    = Join-Path $dolphin 'User'
$logs    = Join-Path $beta 'logs'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
Start-Transcript -Path (Join-Path $logs '02_preparar.log') -Force | Out-Null

Add-Type -Namespace W -Name K -MemberDefinition @'
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
public static extern bool CreateHardLink(string newFile, string existingFile, IntPtr sa);
'@

# ---------- 1. Variante USA con voces japonesas ----------
$us  = Join-Path $beta 'extraido\US'
$jp  = Join-Path $beta 'extraido\JP'
$vjp = Join-Path $beta 'juego\US_VOZ_JP'
Write-Host "=== 1. Creando variante con voces japonesas en $vjp"
if (Test-Path $vjp) { Write-Host "Borrando variante anterior..."; Remove-Item $vjp -Recurse -Force }
$swap = '^(VO_.*|SE_VO.*|ev\d.*)\.brstm$|^RTMV_.*\.thp$'
$n = @{ link=0; jp=0; err=0 }
Get-ChildItem $us -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($us.Length + 1)
  $dst = Join-Path $vjp $rel
  $dir = Split-Path -Parent $dst
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $src = Join-Path $jp $rel
  if ($_.Name -match $swap -and (Test-Path $src)) {
    Copy-Item $src $dst -Force; $n.jp++
  } elseif ([W.K]::CreateHardLink($dst, $_.FullName, [IntPtr]::Zero)) { $n.link++ }
  else { Copy-Item $_.FullName $dst -Force; $n.err++ }
}
Write-Host ("Archivos enlazados (sin ocupar espacio): {0}  |  reemplazados por japones: {1}  |  copiados por fallo de enlace: {2}" -f $n.link, $n.jp, $n.err)

# ---------- 2. Texturas: HD GUI Plus + botones Xbox 360 ----------
$hd   = Join-Path $root 'TLS HD GUI Plus 1.0 PNG\SLSEXJ'
$xbox = Join-Path $root 'SLSEXJ'
$tex  = Join-Path $user 'Load\Textures\SLSEXJ'
Write-Host "`n=== 2. Texturas en $tex"
if (Test-Path $tex) { Remove-Item $tex -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tex | Out-Null
Get-ChildItem $hd -Recurse -File | Where-Object { $_.Name -ne 'Thumbs.db' } | ForEach-Object {
  $dst = Join-Path $tex $_.FullName.Substring($hd.Length + 1)
  $dir = Split-Path -Parent $dst
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  Copy-Item $_.FullName $dst
}
$xdir = Join-Path $tex 'Xbox360'
New-Item -ItemType Directory -Force -Path $xdir | Out-Null
Get-ChildItem $xbox -File -Filter 'tex1_*.png' | ForEach-Object {
  Get-ChildItem $tex -Recurse -File -Filter $_.Name | Where-Object { $_.DirectoryName -ne $xdir } | ForEach-Object {
    Write-Host "  Reemplazado por version Xbox: $($_.FullName.Substring($tex.Length+1))"; Remove-Item $_.FullName }
  Copy-Item $_.FullName $xdir
}
Write-Host ("Texturas instaladas: {0}" -f (Get-ChildItem $tex -Recurse -File).Count)

# ---------- 3. Configuracion de Dolphin ----------
Write-Host "`n=== 3. Configuracion de Dolphin (modo portable en $user)"
$cfg = Join-Path $user 'Config'
New-Item -ItemType Directory -Force -Path $cfg | Out-Null
@'
[Settings]
HiresTextures = True
CacheHiresTextures = True
InternalResolution = 3
ShaderCompilationMode = 2
WaitForShadersBeforeStarting = True
[Hardware]
VSync = True
'@ | Set-Content (Join-Path $cfg 'GFX.ini') -Encoding ASCII

@'
[Wiimote1]
Device = XInput/0/Gamepad
Extension = Classic
Classic/Buttons/A = `Button A`
Classic/Buttons/B = `Button B`
Classic/Buttons/X = `Button Y`
Classic/Buttons/Y = `Button X`
Classic/Buttons/ZL = `Shoulder L`
Classic/Buttons/ZR = `Shoulder R`
Classic/Buttons/- = Back
Classic/Buttons/+ = Start
Classic/Left Stick/Up = `Left Y+`
Classic/Left Stick/Down = `Left Y-`
Classic/Left Stick/Left = `Left X-`
Classic/Left Stick/Right = `Left X+`
Classic/Left Stick/Modifier = `Thumb L`
Classic/Left Stick/Dead Zone = 15.0
Classic/Right Stick/Up = `Right Y+`
Classic/Right Stick/Down = `Right Y-`
Classic/Right Stick/Left = `Right X-`
Classic/Right Stick/Right = `Right X+`
Classic/Right Stick/Modifier = `Thumb R`
Classic/Right Stick/Dead Zone = 15.0
Classic/Triggers/L = `Trigger L`
Classic/Triggers/R = `Trigger R`
Classic/Triggers/L-Analog = `Trigger L`
Classic/Triggers/R-Analog = `Trigger R`
Classic/D-Pad/Up = `Pad N`
Classic/D-Pad/Down = `Pad S`
Classic/D-Pad/Left = `Pad W`
Classic/D-Pad/Right = `Pad E`
Source = 1
[Wiimote2]
Source = 0
[Wiimote3]
Source = 0
[Wiimote4]
Source = 0
[BalanceBoard]
Source = 0
'@ | Set-Content (Join-Path $cfg 'WiimoteNew.ini') -Encoding ASCII
Write-Host "GFX.ini y WiimoteNew.ini escritos."

# ---------- 4. Atajos de prueba ----------
$exe = Join-Path $dolphin 'Dolphin.exe'
foreach ($v in @(@{n='PROBAR_VOCES_INGLES'; d=$us}, @{n='PROBAR_VOCES_JAPONES'; d=$vjp})) {
  $dol = Join-Path $v.d 'DATA\sys\main.dol'
  "@echo off`r`nstart `"`" `"$exe`" -b -e `"$dol`"" | Set-Content (Join-Path $beta "$($v.n).bat") -Encoding ASCII
}
$f = Get-PSDrive (Split-Path -Qualifier $beta).TrimEnd(':')
Write-Host ("`nEspacio libre restante: {0:N1} GB" -f ($f.Free/1GB))
Write-Host "`nLISTO. Ya puedes avisarle a Claude."
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
