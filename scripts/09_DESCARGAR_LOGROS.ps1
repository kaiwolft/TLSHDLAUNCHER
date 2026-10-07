# Descarga UNA VEZ el set de logros de RetroAchievements (juego 27) y sus iconos.
# Usa la sesion que abriste en Dolphin (Opciones > Configuracion > Logros).
# Despues todo funciona sin internet.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root   = Split-Path -Parent $PSScriptRoot
$paths  = Get-Content (Join-Path $root 'launcher\data\paths.json') -Raw | ConvertFrom-Json
$dolDir = Split-Path -Parent $paths.dolphinExe
$ini    = Join-Path $dolDir 'User\Config\RetroAchievements.ini'
$outDir = Join-Path $root 'launcher\data\logros'
$imgDir = Join-Path $root 'launcher\ui\assets\logros'
New-Item -ItemType Directory -Force $outDir, $imgDir | Out-Null

function Fail($m) { Write-Host ''; Write-Host "ERROR: $m" -ForegroundColor Red; Read-Host 'Pulsa Enter para cerrar'; exit 1 }

if (-not (Test-Path $ini)) { Fail "No encuentro $ini.`nAbre Dolphin.exe > Opciones > Configuracion > Logros e inicia sesion." }
$user = $null; $tok = $null
foreach ($l in Get-Content $ini) {
  if ($l -match '^\s*Username\s*=\s*(.+?)\s*$') { $user = $Matches[1] }
  if ($l -match '^\s*ApiToken\s*=\s*(.+?)\s*$') { $tok = $Matches[1] }
}
if (-not $user -or -not $tok) { Fail "Dolphin no tiene sesion iniciada en RetroAchievements.`nAbre Dolphin.exe > Opciones > Configuracion > Logros e inicia sesion." }

$ua = 'TheLastStoryLauncher/1.0 (Windows)'
Write-Host "Descargando el set de logros de The Last Story (usuario $user)..." -ForegroundColor Cyan
$body = @{ r = 'patch'; u = $user; t = $tok; g = 27 }
try { $raw = Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'https://retroachievements.org/dorequest.php' -Body $body -UserAgent $ua }
catch { Fail "No se pudo contactar RetroAchievements: $($_.Exception.Message)" }
$j = $raw.Content | ConvertFrom-Json
if (-not $j.Success -or -not $j.PatchData) { Fail "RetroAchievements respondio: $($raw.Content.Substring(0, [Math]::Min(300, $raw.Content.Length)))" }

$p = $j.PatchData
$achs = @($p.Achievements | Where-Object { $_.Flags -eq 3 })
# Guardamos solo lo necesario (sin datos de tu cuenta)
$clean = [ordered]@{
  game = [ordered]@{ id = $p.ID; title = $p.Title; icon = $p.ImageIcon }
  achievements = @($achs | ForEach-Object { [ordered]@{
    id = $_.ID; title = $_.Title; description = $_.Description; points = $_.Points
    badge = $_.BadgeName; type = $_.Type; author = $_.Author; memaddr = $_.MemAddr } })
}
$json = $clean | ConvertTo-Json -Depth 6
[IO.File]::WriteAllText((Join-Path $outDir 'ra_27.json'), $json, (New-Object Text.UTF8Encoding $false))
Write-Host ("  {0} logros, {1} puntos" -f $achs.Count, (($achs | Measure-Object Points -Sum).Sum)) -ForegroundColor Green

Write-Host 'Descargando iconos...' -ForegroundColor Cyan
$wc = New-Object Net.WebClient
$wc.Headers.Add('User-Agent', $ua)
$i = 0
foreach ($a in $achs) {
  $i++
  foreach ($suf in @('', '_lock')) {
    $f = Join-Path $imgDir ($a.BadgeName + $suf + '.png')
    if (-not (Test-Path $f)) {
      try { $wc.DownloadFile("https://media.retroachievements.org/Badge/$($a.BadgeName)$suf.png", $f) } catch { Write-Host "  sin icono $($a.BadgeName)$suf" -ForegroundColor Yellow }
    }
  }
  Write-Progress -Activity 'Iconos de logros' -PercentComplete ($i * 100 / $achs.Count)
}
Write-Progress -Activity 'Iconos de logros' -Completed
Write-Host ''
Write-Host 'Listo. Ya no hace falta internet para los logros.' -ForegroundColor Green
Read-Host 'Pulsa Enter para cerrar'
