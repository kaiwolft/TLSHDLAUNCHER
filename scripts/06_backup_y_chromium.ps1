# The Last Story - Paso 6: respaldo del proyecto + launcher en Chromium (Electron)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$beta    = Split-Path -Parent $PSScriptRoot
$root    = Split-Path -Parent $beta
$logs    = Join-Path $beta 'logs'
$L       = Join-Path $beta 'launcher'
Start-Transcript -Path (Join-Path $logs '06_backup_chromium.log') -Force | Out-Null

# ================= 1. RESPALDO =================
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$dest  = "C:\Users\Admin\Documents\Backup tls\$stamp"
$c = Get-PSDrive C
Write-Host ("=== 1. Respaldo en $dest  (libre en C: {0:N1} GB)" -f ($c.Free/1GB))
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# Proyecto (sin los datos del juego extraidos: se regeneran con los scripts 01, 03 y 05)
robocopy "$beta" (Join-Path $dest 'TLS Juego beta') /E /XD "$beta\extraido" "$beta\juego" "$L\data\chromium" "$L\data\webview" /R:1 /W:1 /NFL /NDL /NP /NJH | Out-Host
$r1 = $LASTEXITCODE
# Dolphin portable completo (configuracion, texturas instaladas y partidas guardadas)
robocopy (Join-Path $root 'dolphin-2609-x64') (Join-Path $dest 'dolphin-2609-x64') /E /XD Cache Shaders /R:1 /W:1 /NFL /NDL /NP /NJH | Out-Host
$r2 = $LASTEXITCODE
# Material de diseno
foreach ($f in 'Boceto de launcher.png','controller-settings.png','readme.txt') { Copy-Item (Join-Path $root $f) $dest -ErrorAction SilentlyContinue }
@"
Respaldo del proyecto The Last Story - $stamp
Incluye: TLS Juego beta (launcher, scripts, parches, registros), Dolphin portable (config, texturas, partidas), boceto.
No incluye: los .rvz originales, los packs de texturas originales, ni las carpetas 'extraido' y 'juego'
(se regeneran desde los .rvz con scripts\01, 03 y 05).
"@ | Set-Content (Join-Path $dest 'LEEME.txt') -Encoding UTF8

if ($r1 -ge 8 -or $r2 -ge 8) {
  Write-Host "`nERROR en el respaldo (robocopy $r1 / $r2). No continuo con el cambio de launcher."
  Stop-Transcript | Out-Null; Read-Host "Presiona Enter para cerrar"; exit 1
}
$size = (Get-ChildItem $dest -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host ("Respaldo completo: {0:N0} archivos, {1:N1} MB" -f (Get-ChildItem $dest -Recurse -File).Count, ($size/1MB))

# ================= 2. CHROMIUM (ELECTRON) =================
Write-Host "`n=== 2. Instalando Chromium (Electron)"
$ver = 'v38.2.0'
try { $ver = (Invoke-RestMethod -UseBasicParsing 'https://api.github.com/repos/electron/electron/releases/latest').tag_name } catch { Write-Host "  No pude consultar la ultima version; uso $ver" }
Write-Host "  Version: $ver"
$tmp = Join-Path $L '_electron'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'electron.zip'
Invoke-WebRequest -UseBasicParsing "https://github.com/electron/electron/releases/download/$ver/electron-$ver-win32-x64.zip" -OutFile $zip
Expand-Archive $zip -DestinationPath (Join-Path $tmp 'x') -Force
Remove-Item $zip -Force
if (-not (Test-Path (Join-Path $tmp 'x\electron.exe'))) { Write-Host "ERROR: la descarga de Electron fallo."; Stop-Transcript | Out-Null; Read-Host; exit 1 }

# Quitar el launcher anterior (WebView2). Queda copia en el respaldo.
foreach ($f in 'TheLastStory.exe','Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll','WebView2Loader.dll') { Remove-Item (Join-Path $L $f) -Force -ErrorAction SilentlyContinue }
foreach ($d in 'src','data\webview') { Remove-Item (Join-Path $L $d) -Recurse -Force -ErrorAction SilentlyContinue }

robocopy (Join-Path $tmp 'x') $L /E /MOVE /NFL /NDL /NP /NJH /NJS | Out-Null
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $L 'resources\default_app.asar') -Force -ErrorAction SilentlyContinue
Move-Item (Join-Path $L 'electron.exe') (Join-Path $L 'TheLastStory.exe') -Force
Set-Content (Join-Path $L 'version_electron.txt') $ver -Encoding ASCII

# Icono y nombre del ejecutable
$rc = Join-Path $L 'rcedit-x64.exe'
try {
  Invoke-WebRequest -UseBasicParsing 'https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe' -OutFile $rc
  & $rc (Join-Path $L 'TheLastStory.exe') --set-icon (Join-Path $L 'ui\assets\icon.ico') `
       --set-version-string FileDescription 'The Last Story' --set-version-string ProductName 'The Last Story' `
       --set-version-string OriginalFilename 'TheLastStory.exe'
  Write-Host "  Icono aplicado."
} catch { Write-Host "  No se pudo aplicar el icono: $($_.Exception.Message)" }
Remove-Item $rc -Force -ErrorAction SilentlyContinue

$exe = Join-Path $L 'TheLastStory.exe'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $beta 'THE LAST STORY.lnk'))
$lnk.TargetPath = $exe; $lnk.WorkingDirectory = $L; $lnk.IconLocation = "$exe,0"; $lnk.Save()
Write-Host "`nLISTO. Abre 'THE LAST STORY' en la carpeta TLS Juego beta."
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
