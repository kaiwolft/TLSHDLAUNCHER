# The Last Story HD — Dionixu's Launcher

> I made this cuz it was my childhood dream.

[![Ko-fi](https://img.shields.io/badge/Ko--fi-Inv%C3%ADtame%20un%20caf%C3%A9-FF5E5B?logo=ko-fi&logoColor=white)](https://ko-fi.com/dionixu838824)

Launcher e instaladores para Windows y Linux que convierten **tu copia original** de *The Last Story* (Wii) en una experiencia de PC: texturas HD, 60 FPS adaptativos, voces japonesas, logros sin conexión, controles configurables y menú de pausa.

**Español** · [English](#english) · [Français](#français)

---

## ⚠️ Aviso legal

- Este proyecto **NO incluye el juego**.
- Necesitas **dos copias originales** de *The Last Story* para Wii, extraídas por ti de tus propios discos:
  - versión americana (NTSC-U, `SLSEXJ`);
  - versión japonesa (NTSC-J, `SLSJ01`).
- El instalador comprueba ambas copias (ID y huellas MD5) y **solo funcionará con tu copia oficial**. Rechaza las copias modificadas, incompletas o de otra región.
- **No se acepta ni se fomenta la piratería.** Necesitas tu copia oficial.
- Es un proyecto de aficionados sin fines de lucro, sin relación con Nintendo, Mistwalker ni AQ Interactive.

## Funciones

- Launcher con el estilo del juego, en español, inglés y francés (se cambia con el icono del globo).
- Texturas HD e iconos de botones de Xbox, Wii o teclado y ratón (QWERTY y ratón de 5 botones).
- 60 FPS adaptativos: baja a 30 FPS cuando el juego no los sostiene y vuelve a 60 después.
- Voces japonesas, también en las cinemáticas, con subtítulos en el idioma elegido.
- Logros de RetroAchievements evaluados sin conexión. El launcher no guarda ni la contraseña ni el token.
- Configuración de mando y de teclado y ratón.
- Menú de pausa con L3 + R3 o Esc, con volumen del juego en vivo y opción de volver al launcher.
- Ventana sin bordes, cursor personalizado y sin la pantalla de la correa del Wiimote.

## Instalación

Primero hay que generar los instaladores en Windows. Ejecuta:

```
scripts\12_CREAR_INSTALADORES.bat
```

El script crea `Documentos\The Last Story HD PC\INSTALADOR\Windows` y `\Linux`.

- **Windows:** sigue `instalador/docs/INSTRUCCIONES_Windows.txt`. Se abre con `Instalar The Last Story HD.exe`.
- **Linux** (Debian 12, Ubuntu 22.04, Mint 21 o más nuevos): sigue `instalador/docs/INSTRUCCIONES_Linux.txt`. Se abre con `bash instalar.sh`. Necesitas tu propio Dolphin, instalado con `apt` o con Flatpak.

## Estructura

| Carpeta | Contenido |
|---|---|
| `launcher/resources/app/` | Proceso principal (`main.js`, multiplataforma), puente de mando para Windows (`bridge.ps1`) y motor de logros y FPS (`tls_logros.exe`) |
| `launcher/ui/` | Interfaz del launcher, menú de pausa y notificaciones |
| `launcher/data/` | Sets de botones (xbox, wii, teclado) y traducciones de los logros |
| `instalador/` | Instalador (Electron), `instalar.sh` para Linux e instrucciones |
| `linux/` | `tls_bridge` (mando, Esc, foco, ventana sin bordes) y `tls_logros` para Linux |
| `herramientas/` | Código fuente en C de los motores y scripts de análisis |
| `scripts/` | Pasos reproducibles: extraer, preparar, parche de voces, logros, empaquetado e instaladores |

## ☕ Apoya el proyecto

Si te gustó y quieres apoyarme, puedes invitarme un café en Ko-fi: **https://ko-fi.com/dionixu838824**

## Créditos

- **Proyecto:** Dionixu's Launcher, por Dionixu ([@kaiwolft](https://github.com/kaiwolft)).
- **Desarrollado con la ayuda de Claude** (Anthropic), que escribió el código junto a Dionixu: launcher, instaladores, motores de logros y 60 FPS, y el puente de Linux.
- **Texturas HD:** pack HD de Matrix2525.
- **Botones Xbox:** pack de botones Xbox, adaptado.
- **Dolphin Emulator** (GPLv2): [dolphin-emu.org](https://dolphin-emu.org).
- **Electron** (MIT): [electronjs.org](https://www.electronjs.org).
- **rcheevos / RetroAchievements** (MIT). Set de logros por carlosrhv y Quenthel.
- **Código Gecko de 60 FPS:** Dolphin Wiki. Mejoras visuales: sergx12.
- **Fuentes:** Cinzel y Cormorant Garamond (SIL OFL).
- *The Last Story* © Nintendo / Mistwalker / AQ Interactive.

---

## English

Launcher and Windows/Linux installers that turn **your original copy** of *The Last Story* (Wii) into a PC experience:

- HD textures;
- adaptive 60 FPS;
- Japanese voices;
- offline achievements;
- remappable controls;
- a pause menu.

**Legal notice:**

- The game is **not included**.
- You need your own **original North American (`SLSEXJ`) and Japanese (`SLSJ01`)** copies.
- The installer verifies both and will **only work with your official copy**.
- **Piracy is not accepted or encouraged.**

To build the installers, run `scripts\12_CREAR_INSTALADORES.bat` on Windows. Then follow `instalador/docs/INSTRUCCIONES_*.txt`.

☕ **Buy me a coffee:** https://ko-fi.com/dionixu838824

**Credits:** Dionixu's Launcher by Dionixu. **Built with the help of Claude (Anthropic).** HD pack by Matrix2525. Also Dolphin, Electron and rcheevos/RetroAchievements. *The Last Story* © Nintendo / Mistwalker / AQ Interactive.

## Français

Launcher et installateurs Windows/Linux qui transforment **ta copie originale** de *The Last Story* (Wii) en expérience PC :

- textures HD ;
- 60 FPS adaptatifs ;
- voix japonaises ;
- succès hors ligne ;
- commandes configurables ;
- menu pause.

**Avertissement :**

- Le jeu **n'est pas inclus**.
- Il te faut tes **copies originales américaine (`SLSEXJ`) et japonaise (`SLSJ01`)**.
- L'installateur les vérifie et **fonctionne uniquement avec ta copie officielle**.
- **Le piratage n'est ni accepté ni encouragé.**

☕ **Offre-moi un café :** https://ko-fi.com/dionixu838824

**Crédits :** Dionixu's Launcher par Dionixu. **Développé avec l'aide de Claude (Anthropic).** Pack HD de Matrix2525. Aussi Dolphin, Electron et rcheevos/RetroAchievements.
