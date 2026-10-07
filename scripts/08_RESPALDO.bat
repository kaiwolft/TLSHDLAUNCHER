@echo off
set D=C:\Users\Admin\Documents\Backup tls\%date:~-4%-%date:~3,2%-%date:~0,2%_%time:~0,2%%time:~3,2%
set D=%D: =0%
echo Respaldando en "%D%" ...
robocopy "%~dp0.." "%D%\TLS Juego beta" /E /XD "%~dp0..\extraido" "%~dp0..\juego" "%~dp0..\launcher\data\chromium" /R:1 /W:1 /NFL /NDL /NP
robocopy "%~dp0..\..\dolphin-2609-x64" "%D%\dolphin-2609-x64" /E /XD Cache Shaders Dump /R:1 /W:1 /NFL /NDL /NP
echo.
echo LISTO. Respaldo en "%D%"
pause
