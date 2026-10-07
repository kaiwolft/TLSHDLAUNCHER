# 1) Respaldo del proyecto en Documentos\Backup tls\<fecha>
# 2) Juego listo para usar en Documentos\The Last Story HD PC\TLSHDWINDOWS
#    (launcher + Dolphin + juego en ingles + juego con voces japonesas, rutas relativas)
$ErrorActionPreference = 'Stop'
$proj   = Split-Path -Parent $PSScriptRoot                       # ...\TLS Juego beta
$dolSrc = Join-Path (Split-Path -Parent $proj) 'dolphin-2609-x64\Dolphin-x64'
$docs   = [Environment]::GetFolderPath('MyDocuments')
$pack   = Join-Path $docs 'The Last Story HD PC'
$dest   = Join-Path $pack 'TLSHDWINDOWS'
$stamp  = Get-Date -Format 'yyyy-MM-dd_HHmm'
$bak    = Join-Path $docs ('Backup tls\' + $stamp)

function Fail($m) { Write-Host ''; Write-Host "ERROR: $m" -ForegroundColor Red; Read-Host 'Pulsa Enter para cerrar'; exit 1 }
function Step($m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
function RC($src, $dst, [string[]]$xd = @(), [string[]]$xf = @()) {
  $a = @($src, $dst, '/E', '/R:1', '/W:1', '/NFL', '/NDL', '/NP', '/NJH', '/MT:8')
  if ($xd.Count) { $a += '/XD'; $a += $xd }
  if ($xf.Count) { $a += '/XF'; $a += $xf }
  & robocopy @a | Out-Null
  if ($LASTEXITCODE -ge 8) { Fail "robocopy fallo copiando $src (codigo $LASTEXITCODE)" }
}
if (-not (Test-Path (Join-Path $dolSrc 'Dolphin.exe'))) { Fail "No encuentro Dolphin en $dolSrc" }
if (Get-Process -Name TheLastStory, Dolphin -ErrorAction SilentlyContinue) { Fail 'Cierra el launcher y el juego antes de continuar.' }

# ---------------------------------------------------------------- 1. respaldo
Step "Respaldo del proyecto -> $bak"
RC $proj (Join-Path $bak 'TLS Juego beta') @((Join-Path $proj 'extraido'), (Join-Path $proj 'juego'), (Join-Path $proj 'launcher\data\chromium'), (Join-Path $proj 'para_claude'))
RC $dolSrc (Join-Path $bak 'dolphin-2609-x64\Dolphin-x64') @('Cache', 'Shaders', 'Dump', 'Logs')
Write-Host '   respaldo listo' -ForegroundColor Green

# ---------------------------------------------------------------- 2. espacio
$en = Join-Path $proj 'juego\US_INGLES'
$jp = Join-Path $proj 'juego\US_VOZ_JP'
if (-not (Test-Path $en)) { Fail "No encuentro $en" }
Step 'Calculando espacio necesario...'
$enFiles = Get-ChildItem -LiteralPath $en -Recurse -File
$enMap = @{}; foreach ($f in $enFiles) { $enMap[$f.FullName.Substring($en.Length)] = $f }
$jpFiles = if (Test-Path $jp) { Get-ChildItem -LiteralPath $jp -Recurse -File } else { @() }
# en US_VOZ_JP solo ocupan espacio los archivos distintos (voces, videos y el brsar parcheado); el resto se enlaza
$jpUnique = @($jpFiles | Where-Object { $o = $enMap[$_.FullName.Substring($jp.Length)]; -not $o -or $o.Length -ne $_.Length -or $o.LastWriteTimeUtc -ne $_.LastWriteTimeUtc })
$need = ($enFiles | Measure-Object Length -Sum).Sum + ($jpUnique | Measure-Object Length -Sum).Sum +
        (Get-ChildItem -LiteralPath $dolSrc -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\User\\(Cache|Shaders|Dump|Logs)\\' } | Measure-Object Length -Sum).Sum +
        (Get-ChildItem -LiteralPath (Join-Path $proj 'launcher') -Recurse -File | Where-Object { $_.FullName -notmatch '\\data\\chromium\\' } | Measure-Object Length -Sum).Sum
$drive = Get-PSDrive -Name ($docs.Substring(0, 1))
$needGB = [math]::Round($need / 1GB, 1); $freeGB = [math]::Round($drive.Free / 1GB, 1)
Write-Host "   necesario: $needGB GB - libre en $($drive.Name): $freeGB GB"
if ($drive.Free -lt $need * 1.05) { Fail "No hay espacio suficiente en $($drive.Name): (faltan $([math]::Round(($need * 1.05 - $drive.Free) / 1GB, 1)) GB)." }

# ---------------------------------------------------------------- 3. paquete
Step "Creando $dest"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Write-Host '   launcher...'
RC (Join-Path $proj 'launcher') (Join-Path $dest 'launcher') @('chromium') @('launcher.log', 'activos.txt', 'dump_textures.on')
Write-Host '   Dolphin, texturas HD y partidas guardadas...'
RC $dolSrc (Join-Path $dest 'dolphin') @('Cache', 'Shaders', 'Dump', 'Logs', 'ScreenShots')
Write-Host '   juego (ingles)... esto tarda unos minutos'
RC $en (Join-Path $dest 'juego\US_INGLES')
if ($jpFiles.Count) {
  Write-Host '   juego (voces japonesas)...'
  $dEn = Join-Path $dest 'juego\US_INGLES'; $dJp = Join-Path $dest 'juego\US_VOZ_JP'
  $uniq = @{}; foreach ($u in $jpUnique) { $uniq[$u.FullName] = $true }
  $i = 0
  foreach ($f in $jpFiles) {
    $i++; if ($i % 400 -eq 0) { Write-Progress -Activity 'Voces japonesas' -PercentComplete ($i * 100 / $jpFiles.Count) }
    $rel = $f.FullName.Substring($jp.Length); $t = $dJp + $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $t) | Out-Null
    if (Test-Path -LiteralPath $t) { continue }
    if ($uniq[$f.FullName]) { Copy-Item -LiteralPath $f.FullName -Destination $t }
    else {
      try { New-Item -ItemType HardLink -Path $t -Target ($dEn + $rel) | Out-Null }   # mismo archivo que en ingles: sin espacio extra
      catch { Copy-Item -LiteralPath $f.FullName -Destination $t }
    }
  }
  Write-Progress -Activity 'Voces japonesas' -Completed
}

# rutas relativas (el paquete funciona desde cualquier carpeta o disco)
$pj = [ordered]@{ dolphinExe = '../dolphin/Dolphin.exe'; gameEN = '../juego/US_INGLES'; gameJP = '../juego/US_VOZ_JP'; buttonsActive = '../dolphin/User/Load/Textures/SLSEXJ/Botones' }
[IO.File]::WriteAllText((Join-Path $dest 'launcher\data\paths.json'), ($pj | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))
if (-not (Test-Path (Join-Path $dest 'dolphin\portable.txt'))) { Set-Content -LiteralPath (Join-Path $dest 'dolphin\portable.txt') -Value '' }

# acceso directo con el icono del juego
$exe = Join-Path $dest 'launcher\TheLastStory.exe'
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut((Join-Path $dest 'THE LAST STORY HD.lnk'))
$lnk.TargetPath = $exe; $lnk.WorkingDirectory = Split-Path -Parent $exe
$ico = Join-Path $dest 'launcher\ui\assets\icon.ico'; if (Test-Path $ico) { $lnk.IconLocation = $ico }
$lnk.Description = 'The Last Story HD'; $lnk.Save()

@"
THE LAST STORY HD - PC (Windows)
================================
Abre "THE LAST STORY HD" (acceso directo) o launcher\TheLastStory.exe.

Carpetas:
  launcher\   launcher (ajustes, logros, controles)
  dolphin\    emulador portable, texturas HD, botones y partidas guardadas
  juego\      US_INGLES (voces en ingles) y US_VOZ_JP (voces japonesas)

Todo usa rutas relativas: puedes mover la carpeta TLSHDWINDOWS completa a otro disco.
Durante el juego: L3 + R3 (mando) o Esc (teclado) abre el menu de pausa.
"@ | Set-Content -LiteralPath (Join-Path $dest 'LEEME.txt') -Encoding UTF8

$size = [math]::Round(((Get-ChildItem -LiteralPath $dest -Recurse -File | Measure-Object Length -Sum).Sum) / 1GB, 1)
Step 'LISTO'
Write-Host "   Respaldo: $bak" -ForegroundColor Green
Write-Host "   Juego:    $dest  ($size GB en disco aparente; los archivos compartidos no ocupan doble)" -ForegroundColor Green
Read-Host 'Pulsa Enter para cerrar'
