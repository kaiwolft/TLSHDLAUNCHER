# The Last Story HD - Dionixu's Launcher
# Crea los instaladores SIN el juego en <carpeta del proyecto>\INSTALADOR\Windows y \Linux
#   Windows: Electron del launcher + app del instalador + payload (launcher, Dolphin portable sin datos personales, texturas, parche)
#   Linux:   Electron para Linux (se descarga una vez de GitHub y se verifica) + payload (launcher, puente y motor Linux, texturas, parche)
# Nunca se copian: el juego, partidas, configuracion personal, sesion de RetroAchievements ni el set de logros descargado.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$proj   = Split-Path -Parent $PSScriptRoot                       # ...\TLS Juego beta
$dolSrc = Join-Path (Split-Path -Parent $proj) 'dolphin-2609-x64\Dolphin-x64'
$docs   = [Environment]::GetFolderPath('MyDocuments')
$out    = Join-Path (Split-Path -Parent $proj) 'INSTALADOR'          # F:\The last Story Proyect\INSTALADOR
$wDir   = Join-Path $out 'Windows'
$lDir   = Join-Path $out 'Linux'
$cache  = Join-Path $proj 'descargas'
$EV     = '44.5.1'
$ezip   = "electron-v$EV-linux-x64.zip"
$eurl   = "https://github.com/electron/electron/releases/download/v$EV"

$L   = Join-Path $proj 'launcher'
$LA  = Join-Path $L 'resources\app'
$INS = Join-Path $proj 'instalador'
$LNX = Join-Path $proj 'linux'
$tex = Join-Path $dolSrc 'User\Load\Textures\SLSEXJ'
New-Item -ItemType Directory -Force -Path (Join-Path $proj 'logs') | Out-Null
try { Start-Transcript -Path (Join-Path $proj 'logs\12_instaladores.log') -Force | Out-Null } catch {}
$patch = @((Join-Path $proj 'scripts\brsar_voces_jp.tlsp'), (Join-Path $proj 'brsar_voces_jp.tlsp')) | Where-Object { Test-Path $_ } | Select-Object -First 1

function Fail($m) { Write-Host ''; Write-Host "ERROR: $m" -ForegroundColor Red; Read-Host 'Pulsa Enter para cerrar'; exit 1 }
trap { Fail ("$_  (linea " + $_.InvocationInfo.ScriptLineNumber + ")") }
function Step($m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
function RC($src, $dst, [string[]]$xd = @(), [string[]]$xf = @()) {
  $a = @($src, $dst, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/NJH', '/NJS', '/MT:8')
  if ($xd.Count) { $a += '/XD'; $a += $xd }
  if ($xf.Count) { $a += '/XF'; $a += $xf }
  & robocopy @a | Out-Null
  if ($LASTEXITCODE -ge 8) { Fail "robocopy fallo copiando $src (codigo $LASTEXITCODE)" }
}
function CopyF($src, $dst) {
  if (-not (Test-Path -LiteralPath $src)) { Fail "Falta $src" }
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
  Copy-Item -LiteralPath $src -Destination $dst -Force
}

# ---------------------------------------------------------------- comprobaciones
$need = @(
  (Join-Path $L 'TheLastStory.exe'), (Join-Path $LA 'main.js'), (Join-Path $LA 'preload.js'), (Join-Path $LA 'bridge.ps1'), (Join-Path $LA 'tls_logros.exe'),
  (Join-Path $INS 'app\main.js'), (Join-Path $INS 'app\preload.js'), (Join-Path $INS 'app\package.json'), (Join-Path $INS 'app\ui\index.html'),
  (Join-Path $INS 'linux\instalar.sh'), (Join-Path $INS 'docs\INSTRUCCIONES_Windows.txt'), (Join-Path $INS 'docs\INSTRUCCIONES_Linux.txt'),
  (Join-Path $LNX 'tls_bridge'), (Join-Path $LNX 'tls_logros'), (Join-Path $dolSrc 'Dolphin.exe'), (Join-Path $dolSrc 'DolphinTool.exe'), $tex)
foreach ($f in $need) { if (-not (Test-Path -LiteralPath $f)) { Fail "Falta $f" } }
if (-not $patch) { Fail 'No encuentro brsar_voces_jp.tlsp (en scripts\ o en la carpeta del proyecto)' }

# ---------------------------------------------------------------- partes comunes
function Add-InstallerApp($appDir) {
  RC (Join-Path $INS 'app') $appDir
  $ui = Join-Path $appDir 'ui'
  RC (Join-Path $L 'ui\fonts') (Join-Path $ui 'fonts')
  foreach ($f in 'parchment.jpg', 'logo.png', 'art.png', 'icon.ico', 'icon.png') { CopyF (Join-Path $L "ui\assets\$f") (Join-Path $ui "assets\$f") }
  RC (Join-Path $L 'ui\assets\cursor') (Join-Path $ui 'assets\cursor')
  RC (Join-Path $L 'ui\assets\sfx') (Join-Path $ui 'assets\sfx')
}
function Add-Payload($pay, [bool]$win) {
  $pa = Join-Path $pay 'launcher\app'
  New-Item -ItemType Directory -Force -Path $pa | Out-Null
  Get-ChildItem -LiteralPath $LA -File | Where-Object { $_.Extension -in '.js', '.json' } | ForEach-Object { CopyF $_.FullName (Join-Path $pa $_.Name) }
  if ($win) { CopyF (Join-Path $LA 'bridge.ps1') (Join-Path $pa 'bridge.ps1'); CopyF (Join-Path $LA 'tls_logros.exe') (Join-Path $pa 'tls_logros.exe') }
  else      { CopyF (Join-Path $LNX 'tls_bridge') (Join-Path $pa 'tls_bridge'); CopyF (Join-Path $LNX 'tls_logros') (Join-Path $pa 'tls_logros') }
  # interfaz del launcher sin los iconos de logros descargados (se bajan al iniciar sesion en RetroAchievements)
  RC (Join-Path $L 'ui') (Join-Path $pay 'launcher\ui') @((Join-Path $L 'ui\assets\logros'))
  # datos: botones y traducciones de logros; nada personal
  $pd = Join-Path $pay 'launcher\data'
  RC (Join-Path $L 'data\botones') (Join-Path $pd 'botones')
  $tr = Join-Path $L 'data\logros\traducciones.json'
  if (Test-Path $tr) { CopyF $tr (Join-Path $pd 'logros\traducciones.json') }
  CopyF $patch (Join-Path $pay 'patch\brsar_voces_jp.tlsp')
  RC $tex (Join-Path $pay 'textures\SLSEXJ') @((Join-Path $tex 'Botones'))
}

# ---------------------------------------------------------------- Windows
Step "Instalador de Windows -> $wDir"
if (Test-Path $wDir) { Remove-Item -LiteralPath $wDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $wDir | Out-Null
Write-Host '   motor Electron...'
RC $L $wDir @((Join-Path $L 'resources'), (Join-Path $L 'ui'), (Join-Path $L 'data')) @('*.log', 'activos.txt', 'dump_textures.on')
Rename-Item -LiteralPath (Join-Path $wDir 'TheLastStory.exe') -NewName 'Instalar The Last Story HD.exe'
Write-Host '   instalador...'
Add-InstallerApp (Join-Path $wDir 'resources\app')
Write-Host '   launcher, texturas HD y parche...'
Add-Payload (Join-Path $wDir 'payload') $true
Write-Host '   Dolphin portable (sin carpeta User: ni partidas ni sesiones)...'
RC $dolSrc (Join-Path $wDir 'payload\dolphin') @((Join-Path $dolSrc 'User')) @('portable.txt', 'portable.txt.txt')
CopyF (Join-Path $INS 'docs\INSTRUCCIONES_Windows.txt') (Join-Path $wDir 'INSTRUCCIONES.txt')

# ---------------------------------------------------------------- Linux
Step "Instalador de Linux -> $lDir"
New-Item -ItemType Directory -Force -Path $cache | Out-Null
$zipPath = Join-Path $cache $ezip
$sumPath = Join-Path $cache "SHASUMS256-$EV.txt"
if (-not (Test-Path $sumPath)) { Write-Host '   descargando lista de firmas de Electron...'; Invoke-WebRequest -UseBasicParsing -Uri "$eurl/SHASUMS256.txt" -OutFile $sumPath }
$want = ((Get-Content $sumPath) | Where-Object { $_ -match ([regex]::Escape($ezip) + '$') } | Select-Object -First 1)
if (-not $want) { Fail "No encuentro $ezip en SHASUMS256.txt" }
$want = ($want -split '\s+')[0].ToUpper()
$ok = (Test-Path $zipPath) -and ((Get-FileHash $zipPath -Algorithm SHA256).Hash -eq $want)
if (-not $ok) {
  Write-Host "   descargando Electron $EV para Linux (unos 120 MB, solo la primera vez)..."
  Invoke-WebRequest -UseBasicParsing -Uri "$eurl/$ezip" -OutFile $zipPath
  if ((Get-FileHash $zipPath -Algorithm SHA256).Hash -ne $want) { Remove-Item $zipPath -Force; Fail 'La descarga de Electron no coincide con su firma SHA256. Vuelve a intentarlo.' }
}
if (Test-Path $lDir) { Remove-Item -LiteralPath $lDir -Recurse -Force }
$rt = Join-Path $lDir 'runtime'
New-Item -ItemType Directory -Force -Path $rt | Out-Null
Write-Host '   descomprimiendo Electron...'
Expand-Archive -LiteralPath $zipPath -DestinationPath $rt -Force
Remove-Item -LiteralPath (Join-Path $rt 'resources\default_app.asar') -Force -ErrorAction SilentlyContinue
Write-Host '   instalador...'
Add-InstallerApp (Join-Path $rt 'resources\app')
Write-Host '   launcher, puente y motor Linux, texturas HD y parche...'
Add-Payload (Join-Path $lDir 'payload') $false
CopyF (Join-Path $INS 'linux\instalar.sh') (Join-Path $lDir 'instalar.sh')
CopyF (Join-Path $INS 'docs\INSTRUCCIONES_Linux.txt') (Join-Path $lDir 'INSTRUCCIONES.txt')

# ---------------------------------------------------------------- resumen
function Size($d) { [math]::Round(((Get-ChildItem -LiteralPath $d -Recurse -File | Measure-Object Length -Sum).Sum) / 1GB, 2) }
Step 'LISTO'
Write-Host "   Windows: $wDir  ($(Size $wDir) GB)" -ForegroundColor Green
Write-Host "            -> abre 'Instalar The Last Story HD.exe'"
Write-Host "   Linux:   $lDir  ($(Size $lDir) GB)" -ForegroundColor Green
Write-Host "            -> copia la carpeta al equipo Linux y ejecuta: bash instalar.sh"
Write-Host '   Ninguno incluye el juego: piden las copias originales USA (SLSEXJ) y JP (SLSJ01) del usuario.'
Start-Process explorer.exe $out
Read-Host 'Pulsa Enter para cerrar'
