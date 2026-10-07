# Cinematicas prerenderizadas con voces japonesas en la variante US_VOZ_JP.
# Solo cambian las 8 que tienen dialogo distinto entre versiones (mismo tamano, solo cambia el audio).
# Usa enlaces duros: no ocupa espacio extra. Se puede ejecutar varias veces.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$jp   = Join-Path $root 'extraido\JP\DATA\files\movie'
$dst  = Join-Path $root 'juego\US_VOZ_JP\DATA\files\movie'
$files = 'mv01_ev0405.thp','mv04-3-1_ev1510.thp','mv04-3-3_ev1510.thp','mv06_ev0507.thp',
         'mv13_ev2005.thp','mv17_ev3206.thp','mv18_ev3209.thp','mv19_ev3212.thp'

function Fail($m) { Write-Host "ERROR: $m" -ForegroundColor Red; Read-Host 'Pulsa Enter para cerrar'; exit 1 }
if (-not (Test-Path $jp))  { Fail "No encuentro $jp" }
if (-not (Test-Path $dst)) { Fail "No encuentro $dst" }

$ok = 0
foreach ($f in $files) {
  $s = Join-Path $jp $f; $d = Join-Path $dst $f
  if (-not (Test-Path $s)) { Write-Host "  falta $f en la version japonesa" -ForegroundColor Yellow; continue }
  if ((Test-Path $d) -and ((Get-Item $s).Length -ne (Get-Item $d).Length)) { Write-Host "  $f tiene otro tamano, se omite" -ForegroundColor Yellow; continue }
  if (Test-Path $d) { Remove-Item -LiteralPath $d -Force }
  try { New-Item -ItemType HardLink -Path $d -Target $s | Out-Null }
  catch { Copy-Item -LiteralPath $s -Destination $d -Force }
  Write-Host "  $f -> voces japonesas" -ForegroundColor Green
  $ok++
}
Write-Host ''
Write-Host "Listo: $ok de $($files.Count) cinematicas con voces japonesas." -ForegroundColor Cyan
Read-Host 'Pulsa Enter para cerrar'
