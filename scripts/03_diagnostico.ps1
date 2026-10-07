# The Last Story - Paso 3: diagnostico del congelamiento + variantes de prueba
$ErrorActionPreference = 'Continue'
$beta    = Split-Path -Parent $PSScriptRoot
$root    = Split-Path -Parent $beta
$dolphin = Join-Path $root 'dolphin-2609-x64\Dolphin-x64'
$user    = Join-Path $dolphin 'User'
$logs    = Join-Path $beta 'logs'
$pc      = Join-Path $beta 'para_claude'
New-Item -ItemType Directory -Force -Path $logs, $pc | Out-Null
Start-Transcript -Path (Join-Path $logs '03_diagnostico.log') -Force | Out-Null

Add-Type -Namespace W -Name K -MemberDefinition @'
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
public static extern bool CreateHardLink(string newFile, string existingFile, IntPtr sa);
'@

$us = Join-Path $beta 'extraido\US'
$jp = Join-Path $beta 'extraido\JP'

# 1. Copias normales (no enlazadas) de archivos que Claude necesita analizar
Write-Host "=== 1. Copiando archivos para analisis"
Copy-Item (Join-Path $us 'DATA\sys\main.dol')     (Join-Path $pc 'US_main.dol') -Force
Copy-Item (Join-Path $jp 'DATA\sys\main.dol')     (Join-Path $pc 'JP_main.dol') -Force
Copy-Item (Join-Path $us 'DATA\files\config.ini') (Join-Path $pc 'US_config.ini') -Force
Copy-Item (Join-Path $us 'DATA\files\sound\stream\VO_EV0107_010.brstm') (Join-Path $pc 'US_VO_EV0107_010.brstm') -Force -ErrorAction SilentlyContinue
Copy-Item (Join-Path $jp 'DATA\files\sound\stream\VO_EV0107_010.brstm') (Join-Path $pc 'JP_VO_EV0107_010.brstm') -Force -ErrorAction SilentlyContinue

# 2. Variantes de prueba (todo con enlaces duros: no ocupan espacio)
function New-Variant($name, $pattern) {
  $dst = Join-Path $beta "juego\$name"
  if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
  $c = @{ us=0; jp=0 }
  Get-ChildItem $us -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($us.Length + 1)
    $out = Join-Path $dst $rel
    $dir = Split-Path -Parent $out
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $src = Join-Path $jp $rel
    if ($pattern -and $_.Name -match $pattern -and (Test-Path $src)) { $from = $src; $c.jp++ } else { $from = $_.FullName; $c.us++ }
    if (-not [W.K]::CreateHardLink($out, $from, [IntPtr]::Zero)) { Copy-Item $from $out -Force }
  }
  Write-Host ("  {0}: {1} archivos USA, {2} japoneses" -f $name, $c.us, $c.jp)
}
Write-Host "`n=== 2. Creando variantes"
New-Variant 'US_INGLES'        $null
New-Variant 'JP_SOLO_DIALOGOS' '^VO_.*\.brstm$'
New-Variant 'US_VOZ_JP'        '^(VO_.*|SE_VO.*|ev\d.*)\.brstm$|^RTMV_.*\.thp$'

# 3. Registro de Dolphin a archivo
Write-Host "`n=== 3. Activando registro de Dolphin"
$cats = 'BOOT','DVD','FileMon','OSREPORT','OSREPORT_HLE','IOS_DI','Audio','CORE','PowerPC','Video'
$ini = "[Logs]`r`n" + (($cats | ForEach-Object { "$_ = True" }) -join "`r`n") + "`r`n[Options]`r`nVerbosity = 4`r`nWriteToFile = True`r`nWriteToConsole = False`r`nWriteToWindow = False`r`n"
Set-Content (Join-Path $user 'Config\Logger.ini') $ini -Encoding ASCII

# 4. Atajos de prueba (esperan a que cierres Dolphin y guardan el registro)
$exe  = Join-Path $dolphin 'Dolphin.exe'
$dlog = Join-Path $user 'Logs\dolphin.log'
Remove-Item (Join-Path $beta 'PROBAR_VOCES_*.bat') -ErrorAction SilentlyContinue
$tests = @(
  @{ n='PRUEBA_1_INGLES';               d='US_INGLES' },
  @{ n='PRUEBA_2_JAPONES_SOLO_DIALOGOS';d='JP_SOLO_DIALOGOS' },
  @{ n='PRUEBA_3_JAPONES_COMPLETO';     d='US_VOZ_JP' }
)
foreach ($t in $tests) {
  $dol = Join-Path $beta "juego\$($t.d)\DATA\sys\main.dol"
  $bat = "@echo off`r`n" +
         "del /q `"$dlog`" 2>nul`r`n" +
         "echo Jugando $($t.n)... cierra Dolphin cuando termines la prueba.`r`n" +
         "start `"`" /wait `"$exe`" -b -e `"$dol`"`r`n" +
         "copy /y `"$dlog`" `"$logs\$($t.n).log`" >nul`r`n" +
         "echo Registro guardado. Ya puedes avisarle a Claude.`r`n" +
         "timeout /t 5 >nul`r`n"
  Set-Content (Join-Path $beta "$($t.n).bat") $bat -Encoding ASCII
}
$f = Get-PSDrive (Split-Path -Qualifier $beta).TrimEnd(':')
Write-Host ("`nEspacio libre: {0:N1} GB" -f ($f.Free/1GB))
Write-Host "`nLISTO."
Stop-Transcript | Out-Null
Read-Host "Presiona Enter para cerrar"
