# The Last Story — Proyecto launcher (notas para retomar)
Última sesión: 6 de octubre de 2026

## Estructura
- `F:\The last Story Proyect\TLS Juego beta\`
  - `THE LAST STORY.lnk` → abre el launcher
  - `launcher\` → Electron v44.5.1 (Chromium). Ejecutable `TheLastStory.exe`
    - `resources\app\main.js` (proceso principal), `preload.js`, `bridge.ps1` (mando XInput + foco)
    - `ui\index.html` (menú, intro FFXIII, ajustes por pestañas, viento WebGL), `ui\exit.html` (salir con L3+R3)
    - `ui\assets\` (arte, logo, hd.jpg, música, `sfx\` = sonidos SE_UICOM del juego, `art_wind.png` = máscara del viento)
    - `data\config.json` (ajustes), `paths.json`, `botones\xbox|wii\` (sets de iconos), `launcher.log`
  - `juego\US_INGLES\` y `juego\US_VOZ_JP\` → juego USA extraído (enlaces duros). `US_VOZ_JP` lleva voces JP + `lastworld.brsar` parcheado (`listo.txt`)
  - `extraido\US|JP\` → discos extraídos completos
  - `scripts\01..07` → pasos reproducibles (extraer, preparar, diagnóstico, launcher, parche voces, respaldo/Chromium, botones)
  - `herramientas\` → scripts Python de análisis (DOL, BRSAR, desensamblador PPC)
- Dolphin portable: `F:\The last Story Proyect\dolphin-2609-x64\Dolphin-x64\` (portable.txt). Texturas en `User\Load\Textures\SLSEXJ`
- Respaldo: `C:\Users\Admin\Documents\Backup tls\2026-10-06_1401`

## Hechos clave
- Juego: USA SLSEXJ. Voces JP: se copian VO_/SE_VO/ev*/RTMV_ del disco JP y se corrigen 11,977 tamaños en `lastworld.brsar`
  (si no, assert `snd_DvdSoundArchive.cpp:364 mSize <= GetSize()`).
- Dolphin ignora `-C GFX.*` al arrancar → el launcher escribe GFX.ini / Dolphin.ini directamente (función setIni).
- Línea verde inferior → `ImmediateXFBEnable = True` (pendiente de confirmar por el usuario).
- Botones Xbox: el atlas `d00268462c0c911d` se lee en escala de grises (base plateada + letra). Rehecho con letras blancas.
  `8797276bca6f38d0` con LT/RT/LB/RB. Mapeo mando: X→Button X, Y→Button Y.
- Pantalla de la correa: `StrapTask` → parche OnFrame `0x805A6294:dword:0x38C00002` (estado inicial 2).
- 60 FPS: código Gecko de la Dolphin Wiki (NA/EU), ganchos verificados contra main.dol USA. Lo genera main.js en
  `User\GameSettings\SLSEXJ.ini`. Problema conocido: jefe que rueda y acciones únicas de enemigos van al doble.
  Valores: 0x80C94DB0 = fps (60/30), 0x80C94C04 = multiplicador de tiempo (0.5/1.0), 0x8087FE78 = bandera de cinemática.
- Mejoras visuales (sergx12): sombras 0x80C94C70, color 0x80C94B84, DOF 0x80C9495C/60 + 0x80794DA0/A4, rayos 0x80880E2C.
- Funciones SDK localizadas: OSDisableInterrupts 0x805F1E80, VIWaitForRetrace 0x80603FF0, VIGetRetraceCount 0x806051C0.

## Pendiente
1. **60 FPS → 30 automático en jefes (opción 2):** buscar en memoria una bandera de "combate de jefe" con una partida
   guardada antes del jefe que rueda (~capítulo 6). Luego añadir condición Gecko como la de cinemáticas.
2. **Opción 1:** corregir rutinas de enemigos que cuentan cuadros (registro de accesos a 0x80C94C04 con el depurador).
3. **Logros sin conexión:** set RetroAchievements (109 logros, 800 pts, carlosrhv y Quenthel); evaluar condiciones leyendo memoria de Dolphin.
4. Opcional: re-editar videos de tutorial (tt005–tt009.thp) que muestran Wiimote/Nunchuk.
5. Confirmar: línea verde, transición sin ventana blanca, salida L3+R3.

## Icono de la ventana del juego (2026-10-06)
Dolphin toma el icono de su ventana de `Sys\Resources\dolphin_logo.png` y `dolphin_logo@2x.png`.
Se reemplazaron por el icono del juego (200 y 400 px). Originales en `TLS Juego beta\backup_icono_dolphin\`.

## Logros offline (2026-10-06)
- `scripts\09_DESCARGAR_LOGROS.bat`: baja una vez el set 27 (usa la sesión RA de Dolphin) → `launcher\data\logros\ra_27.json` + iconos en `ui\assets\logros\`.
- `resources\app\tls_logros.exe` (fuente: `herramientas\tls_logros.c`, rcheevos compilado con clang+mingw-w64): busca MEM1/MEM2 en Dolphin (región MEM_MAPPED 32 MB con "SLSE" y MEM2 a +0x10000000), evalúa a 60 Hz. Salida: READY/HOOKED/UNLOCK/PROGRESS/LOST; en stderr `DIAG zona=… p1=… p2=…` cada 5 s.
- Excluir ids >= 100000000 (aviso "Unknown Emulator" del servidor). `traducciones.json` es/fr.
- Pendiente: confirmar en partida real que los DIAG cambian y que salta un logro.

## Controles e idioma (2026-10-06)
- Pestaña CONTROLES: mando y teclado/ratón activos a la vez (expresiones `` `Button A` | `DInput/0/Keyboard Mouse:E` ``). Cámara con `RelativeMouse` × sensibilidad.
- El launcher reescribe `WiimoteNew.ini` y `Hotkeys.ini` (Dolphin por defecto: Esc = detener, Tab = sin límite de velocidad).
- F1 con el juego delante = diálogo de volver al launcher (bridge.ps1).
- Iconos del juego: auto/xbox/teclado/wii. Teclado: estáticos en `data\botones\teclado`, atlas d00268/8797/dcb1 dibujados por la UI con las teclas elegidas.
- Idioma del launcher (globo): es/en/fr, `cfg.ui`.

## Instaladores y Linux - Dionixu's Launcher (2026-10-07)
- Nombre del proyecto en todo (titulo, creditos, instalador, accesos directos): **Dionixu's Launcher**.
- `scripts\12_CREAR_INSTALADORES.bat` -> `Documentos\The Last Story HD PC\INSTALADOR\Windows` y `\Linux` (sin el juego).
  - Windows: `Instalar The Last Story HD.exe` (Electron del launcher) + `payload\` (launcher, Dolphin sin User, texturas sin Botones, parche).
  - Linux: `instalar.sh` + `runtime\` (Electron 44.5.1 linux-x64, descargado a `TLS Juego beta\descargas` y verificado con SHA256) + `payload\`.
- Fuente del instalador: `instalador\app\` (main.js, preload.js, ui\), `instalador\linux\instalar.sh`, `instalador\docs\INSTRUCCIONES_*.txt`.
- El instalador verifica las copias del usuario: ID SLSEXJ / SLSJ01 + MD5 de main.dol, boot.bin y lastworld.brsar; aplica el parche
  y comprueba el brsar resultante (378DE37B...). Extrae con DolphinTool (Windows: el incluido; Linux: el del usuario, apt o Flatpak).
- Al terminar abre el launcher con `--windowed`. config.json inicial: idioma elegido, voces JP, ventana.
- Logros: el set no se distribuye; el launcher pide usuario/contrasena de RetroAchievements una vez, baja el set 27 y no guarda ni la contrasena ni el token.
- Linux: `linux\tls_bridge` (fuente `herramientas\tls_bridge.c`: joystick del kernel, X11 por dlopen, Esc, foco, sin bordes) y
  `linux\tls_logros` (estatico; memoria de Dolphin por `/dev/shm/dolphin-emu.<pid>` via /proc/<pid>/fd, sin ptrace). glibc >= 2.34.
  Volumen en vivo con `pactl`. Dolphin con `-u <instalacion>/dolphin-user`. Mando por SDL.
- `main.js` del launcher es multiplataforma (IS_WIN / IS_LINUX); `paths.json` admite `dolphinUser` y en Linux `dolphinExe` = ruta, comando o `flatpak:org.DolphinEmu.dolphin-emu`.
