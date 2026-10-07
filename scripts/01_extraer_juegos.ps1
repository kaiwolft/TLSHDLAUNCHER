# The Last Story - Paso 1: extraer el contenido de los discos USA y JP
$ErrorActionPreference = 'Continue'
$beta    = Split-Path -Parent $PSScriptRoot          # ...\TLS Juego beta
$root    = Split-Path -Parent $beta                  # ...\The last Story Proyect
$tool    = Join-Path $root 'dolphin-2609-x64\Dolphin-x64\DolphinTool.exe'
$logs    = Join-Path $beta 'logs'
$out     = Join-Path $beta 'extraido'
New-Item -ItemType Directory -Force -Path $logs, $out | Out-Null
Start-Transcript -Path (Join-Path $logs '01_extraer.log') -Force | Out-Null

$juegos = @(
  @{ id='US'; file=(Join-Path $root 'Last Story, The (USA) (En,Fr,Es).rvz') },
  @{ id='JP'; file=(Join-Path $root 'Last Story, The (Japan).rvz') }
)

$drive = (Get-Item $beta).PSDrive
Write-Host ("Espacio libre en {0}: {1:N1} GB (se necesitan ~10 GB)" -f $drive.Name, ($drive.Free/1GB))
if (-not (Test-Path $tool)) { Write-Host "ERROR: no encuentro DolphinTool.exe en $tool" }

foreach ($j in $juegos) {
  $dest = Join-Path $out $j.id
  Write-Host "`n=== $($j.id): $($j.file)"
  if (-not (Test-Path $j.file)) { Write-Host "ERROR: no existe el archivo"; continue }
  & $tool header -i $j.file
  if (Test-Path (Join-Path $dest 'DATA')) { Write-Host "Ya extraido, lo salto." }
  else {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Write-Host "Extrayendo (puede tardar varios minutos)..."
    & $tool extract -i $j.file -o $dest
    Write-Host "Codigo de salida: $LASTEXITCODE"
  }
  # Inventario: ruta relativa, tamano y MD5 (para comparar voces entre versiones)
  $lista = Join-Path $logs "lista_$($j.id).tsv"
  Get-ChildItem -Path $dest -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($dest.Length + 1)
    $md5 = (Get-FileHash $_.FullName -Algorithm MD5).Hash
    "{0}`t{1}`t{2}" -f $rel, $_.Length, $md5
  } | Set-Content -Path $lista -Encoding UTF8
  Write-Host "Inventario guardado en $lista"
}
Write-Host "`nLISTO. Ya puedes avisarle a Claude."
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
