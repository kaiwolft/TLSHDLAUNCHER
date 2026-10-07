#!/usr/bin/env bash
# Instalador de The Last Story HD - Dionixu's Launcher (Linux: Debian, Ubuntu, Mint y derivados)
# Uso: bash instalar.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RT="$DIR/runtime"

# permisos (se pierden al copiar desde Windows o un USB)
chmod +x "$RT/electron" "$RT/chrome_crashpad_handler" "$RT/chrome-sandbox" 2>/dev/null
chmod +x "$DIR/payload/launcher/app/tls_bridge" "$DIR/payload/launcher/app/tls_logros" 2>/dev/null

echo "== The Last Story HD - Dionixu's Launcher =="

# glibc 2.34 o superior (Debian 12, Ubuntu 22.04, Mint 21 o mas nuevos)
GV="$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')"
if [ -n "$GV" ] && [ "$(printf '%s\n' 2.34 "$GV" | sort -V | head -1)" != "2.34" ]; then
  echo "AVISO: tu sistema tiene glibc $GV; se necesita 2.34 o superior (Debian 12 / Ubuntu 22.04 o mas nuevos)."
fi

# bibliotecas que necesita la interfaz
MISSING="$(ldd "$RT/electron" 2>/dev/null | grep 'not found' | awk '{print $1}')"
if [ -n "$MISSING" ]; then
  echo "Faltan bibliotecas del sistema:"; echo "$MISSING" | sed 's/^/  - /'
  echo "Instalalas con:"
  echo "  sudo apt install libnss3 libgtk-3-0 libgbm1 libxss1 libxtst6 libasound2 || sudo apt install libnss3 libgtk-3-0t64 libgbm1 libxss1 libxtst6 libasound2t64"
  exit 1
fi

# Dolphin (lo aporta el usuario): solo se avisa, el instalador permite elegirlo
if ! command -v dolphin-emu >/dev/null 2>&1 && ! flatpak info org.DolphinEmu.dolphin-emu >/dev/null 2>&1; then
  echo "Nota: no se encontro Dolphin. Instalalo con 'sudo apt install dolphin-emu' (incluye dolphin-tool)"
  echo "      o con Flatpak: flatpak install flathub org.DolphinEmu.dolphin-emu  - o eligelo en el instalador."
fi
command -v pactl >/dev/null 2>&1 || echo "Nota: sin 'pactl' el volumen del menu de pausa se aplica al iniciar el juego (sudo apt install pulseaudio-utils)."

exec "$RT/electron" --no-sandbox "$@"
