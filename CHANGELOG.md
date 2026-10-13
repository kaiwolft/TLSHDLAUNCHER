## 🎮 The Last Story HD — TLSHD Launcher v1.1.0 (Dionixu's Launcher)

> ⚠️ **No incluye el juego.**
> - Necesitas tus copias **originales** de la versión americana (`SLSEXJ`) y de la versión japonesa (`SLSJ01`).
> - El instalador las verifica y **solo funciona con tu copia oficial**.
> - No se acepta ni se fomenta la piratería.

### 📦 Archivos
| Archivo | Sistema | Cómo se usa |
|---|---|---|
| **TLSHD.LAUNCHER.WINDOWS.ver.1.1.0.rar** | Windows 10/11 (64 bits) | Descomprime y abre `Instalar The Last Story HD.exe` |
| **TLSHD-Instalador-Linux-x86_64.AppImage** | Linux (Debian 12, Ubuntu 22.04, Mint 21 o más nuevos) | Instalador todo en uno (recomendado): márcalo como ejecutable y ábrelo |
| **TLSHD-Instalador-Linux-x86_64.tar.gz** | Linux | Archivos del launcher portátil |

---

### 🛠️ Corrección importante — Windows
- **Corregido:** al terminar la instalación aparecía el error `spawn ...\launcher\TheLastStory.exe ENOENT`, porque `TheLastStory.exe` no se copiaba a la carpeta `launcher`. El instalador dejaba fuera su propio ejecutable, que es el que se renombra a `TheLastStory.exe`.
- Ahora el instalador **comprueba que `TheLastStory.exe` exista** antes de dar la instalación por terminada.
- Si el launcher no puede abrirse al final, se muestra un **mensaje claro** en el instalador (español, inglés o francés) en vez de una ventana de error de JavaScript.
- El registro de instalación ahora muestra **una línea por mensaje**.

> **¿Ya instalaste y te salió ese error?** No hace falta reinstalar:
> 1. Copia `Instalar The Last Story HD.exe` (del instalador) dentro de la carpeta `launcher` de tu instalación.
> 2. Cámbiale el nombre a `TheLastStory.exe`.
>
> O descarga este instalador corregido e instala de nuevo.

### ✅ Novedades — Linux
- Corrección definitiva de controles en Linux (soporte para mandos genéricos/DirectInput como Shanwan)
- El launcher ya no sobreescribe la configuración de mandos del usuario
- El teclado ahora funciona correctamente dentro del juego
- Dolphin ya no pausa el juego por pérdida de foco en Wayland
- Detección mejorada de cruceta (D-pad) en mandos genéricos en el menú del launcher

### 🕹️ Configuración del mando en Linux — MUY IMPORTANTE
**Se recomienda encarecidamente cambiar los controles in-game a Combate Manual** (Battle Style: Manual) en las opciones dentro del juego.

Para mapear correctamente tu mando en Linux:
1. Abre **Dolphin Emulator** directamente desde tus aplicaciones
2. Ve a **Mandos → Mando de Wii 1 → Configurar**
3. Asegúrate de tener la extensión **Classic Controller** activa
4. Selecciona tu dispositivo y mapea cada botón manualmente
5. Cierra Dolphin y lanza el juego desde el Launcher

### ⭐ También en v1.1
- **60 FPS fijos.** La CPU emulada va al 150 % para reducir las ralentizaciones, y la carga de disco es rápida, lo que evita los tirones antes de las cinemáticas.
- **Barra de sensibilidad del ratón** en *Ajustes → Controles → Teclado y ratón*.
- **Créditos ampliados:** música del launcher y aviso de derechos.

---

### English
- **Windows fix:** the installer finished without copying `TheLastStory.exe`, which caused the `spawn ... TheLastStory.exe ENOENT` error. It is now copied and checked, and any launch problem shows a clear message.
  - **Already installed?** Copy `Instalar The Last Story HD.exe` into your `launcher` folder and rename it to `TheLastStory.exe`.
- **Linux:** controller fixes (generic/DirectInput pads), keyboard works in game, no pause on focus loss under Wayland, all-in-one AppImage installer.
- **The game is not included.** You need your own original US (`SLSEXJ`) and Japanese (`SLSJ01`) copies. No piracy.

### ☕ Apoya el proyecto / Support
https://ko-fi.com/dionixu838824

### Créditos / Credits
- **Dionixu's Launcher**, por Dionixu.
- **Desarrollado con la ayuda de Claude (Anthropic).**
- Pack HD de Matrix2525.
- Música del launcher: «Toberu mono».
  - Compositor: Nobuo Uematsu.
  - Voz: Kanon.
  - Arreglo: Yoshitaka Suzuki.
  - Fuente: *The Last Story Original Soundtrack* (Dog Ear Records).
- Dolphin Emulator (GPLv2), Electron y rcheevos/RetroAchievements.
- *The Last Story* © Nintendo / Mistwalker / AQ Interactive.
- Homenaje de fans sin fines de lucro.
