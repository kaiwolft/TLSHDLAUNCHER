# The Last Story - Paso 4: instalar y compilar el launcher + copiar archivos de sonido para analisis
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$beta    = Split-Path -Parent $PSScriptRoot
$root    = Split-Path -Parent $beta
$dolphin = Join-Path $root 'dolphin-2609-x64\Dolphin-x64'
$user    = Join-Path $dolphin 'User'
$logs    = Join-Path $beta 'logs'
$pc      = Join-Path $beta 'para_claude'
$L       = Join-Path $beta 'launcher'
New-Item -ItemType Directory -Force -Path $logs, $pc | Out-Null
Start-Transcript -Path (Join-Path $logs '04_launcher.log') -Force | Out-Null

# 1. Archivos de sonido para que Claude prepare el parche de voces
Write-Host "=== 1. Copiando archivos de sonido para analisis"
foreach ($v in 'US','JP') {
  foreach ($f in 'lastworld.brsar','LastWorld.rsid.csv') {
    $src = Join-Path $beta "extraido\$v\DATA\files\sound\$f"
    Copy-Item $src (Join-Path $pc "${v}_$f") -Force
    Write-Host "  $v $f -> $((Get-Item $src).Length) bytes"
  }
}

# 2. Carpetas del launcher
Write-Host "`n=== 2. Preparando carpetas"
$ui = Join-Path $L 'ui'; $data = Join-Path $L 'data'
New-Item -ItemType Directory -Force -Path (Join-Path $ui 'fonts'), (Join-Path $data 'botones\xbox'), (Join-Path $data 'botones\wii') | Out-Null
$mp3 = Get-ChildItem $root -Filter '*.mp3' | Select-Object -First 1
if ($mp3) { Copy-Item $mp3.FullName (Join-Path $ui 'assets\music.mp3') -Force; Write-Host "  Musica: $($mp3.Name)" }

# 3. Iconos de botones: set Xbox y set Wii (HD) intercambiables
Write-Host "`n=== 3. Sets de botones"
$tex   = Join-Path $user 'Load\Textures\SLSEXJ'
$hdPng = Join-Path $root 'TLS HD GUI Plus 1.0 PNG\SLSEXJ'
$xsrc  = Join-Path $root 'SLSEXJ'
Get-ChildItem $xsrc -File -Filter 'tex1_*.png' | ForEach-Object {
  Copy-Item $_.FullName (Join-Path $data 'botones\xbox') -Force
  $orig = Get-ChildItem $hdPng -Recurse -File -Filter $_.Name | Select-Object -First 1
  if ($orig) { Copy-Item $orig.FullName (Join-Path $data 'botones\wii') -Force }
}
$old = Join-Path $tex 'Xbox360'; if (Test-Path $old) { Remove-Item $old -Recurse -Force }
$active = Join-Path $tex 'Botones'
New-Item -ItemType Directory -Force -Path $active | Out-Null
Copy-Item (Join-Path $data 'botones\xbox\*.png') $active -Force
Write-Host ("  Xbox: {0}  Wii: {1}" -f (Get-ChildItem (Join-Path $data 'botones\xbox')).Count, (Get-ChildItem (Join-Path $data 'botones\wii')).Count)

# 4. Fuentes tipograficas (Google Fonts, licencia OFL)
Write-Host "`n=== 4. Descargando fuentes"
$fonts = @{
  'Cinzel.ttf'                     = 'https://github.com/google/fonts/raw/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf'
  'CormorantGaramond.ttf'          = 'https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf'
  'CormorantGaramond-Italic.ttf'   = 'https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond-Italic%5Bwght%5D.ttf'
  'OFL-Cinzel.txt'                 = 'https://github.com/google/fonts/raw/main/ofl/cinzel/OFL.txt'
  'OFL-CormorantGaramond.txt'      = 'https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/OFL.txt'
}
foreach ($k in $fonts.Keys) {
  try { Invoke-WebRequest -UseBasicParsing -Uri $fonts[$k] -OutFile (Join-Path $ui "fonts\$k"); Write-Host "  OK $k" }
  catch { Write-Host "  FALLO $k : $($_.Exception.Message)" }
}

# 5. WebView2 (componente de Microsoft para mostrar la interfaz)
Write-Host "`n=== 5. Descargando WebView2 SDK"
$pkg = Join-Path $L '_webview2'
if (-not (Test-Path (Join-Path $L 'Microsoft.Web.WebView2.Core.dll'))) {
  New-Item -ItemType Directory -Force -Path $pkg | Out-Null
  $zip = Join-Path $pkg 'webview2.zip'
  Invoke-WebRequest -UseBasicParsing -Uri 'https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2' -OutFile $zip
  Expand-Archive $zip -DestinationPath $pkg -Force
  foreach ($n in 'Microsoft.Web.WebView2.Core.dll','Microsoft.Web.WebView2.WinForms.dll') {
    $f = Get-ChildItem $pkg -Recurse -Filter $n | Where-Object { $_.FullName -match '\\lib\\net4' } | Sort-Object FullName -Descending | Select-Object -First 1
    Copy-Item $f.FullName $L -Force; Write-Host "  $($f.FullName.Substring($pkg.Length))"
  }
  $ld = Get-ChildItem $pkg -Recurse -Filter 'WebView2Loader.dll' | Where-Object { $_.FullName -match 'win-x64' } | Select-Object -First 1
  Copy-Item $ld.FullName $L -Force; Write-Host "  $($ld.FullName.Substring($pkg.Length))"
  Remove-Item $pkg -Recurse -Force
} else { Write-Host "  Ya estaba descargado." }

# 6. Rutas que usa el launcher
$paths = [ordered]@{
  dolphinExe    = (Join-Path $dolphin 'Dolphin.exe')
  gameEN        = (Join-Path $beta 'juego\US_INGLES')
  gameJP        = (Join-Path $beta 'juego\US_VOZ_JP')
  buttonsActive = $active
}
$paths | ConvertTo-Json | Set-Content (Join-Path $data 'paths.json') -Encoding UTF8
if (-not (Test-Path (Join-Path $data 'config.json'))) {
  '{"voice":"en","text":"en","res":"1080","fps":"30","mode":"full","hd":"on","buttons":"xbox","vsync":"on","music":"on"}' | Set-Content (Join-Path $data 'config.json') -Encoding ASCII
}

# 7. Registro de Dolphin: solo mensajes del juego (mas ligero)
$ini = "[Logs]`r`nOSREPORT = True`r`n[Options]`r`nVerbosity = 3`r`nWriteToFile = True`r`nWriteToConsole = False`r`nWriteToWindow = False`r`n"
Set-Content (Join-Path $user 'Config\Logger.ini') $ini -Encoding ASCII

# 8. Compilar
Write-Host "`n=== 8. Compilando el launcher"
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$exe = Join-Path $L 'TheLastStory.exe'
& $csc /nologo /target:winexe /platform:x64 /optimize+ "/out:$exe" "/win32icon:$(Join-Path $ui 'assets\icon.ico')" `
  /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Web.Extensions.dll `
  "/r:$(Join-Path $L 'Microsoft.Web.WebView2.Core.dll')" "/r:$(Join-Path $L 'Microsoft.Web.WebView2.WinForms.dll')" `
  (Join-Path $L 'src\Launcher.cs')
Write-Host "Codigo de salida del compilador: $LASTEXITCODE"

if (Test-Path $exe) {
  $ws = New-Object -ComObject WScript.Shell
  $lnk = $ws.CreateShortcut((Join-Path $beta 'THE LAST STORY.lnk'))
  $lnk.TargetPath = $exe; $lnk.WorkingDirectory = $L; $lnk.IconLocation = "$exe,0"; $lnk.Save()
  Write-Host "`nLISTO. Abre 'THE LAST STORY' en la carpeta TLS Juego beta."
} else { Write-Host "`nNO se genero el ejecutable. Avisale a Claude." }
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
