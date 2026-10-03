#!/usr/bin/env bash
# cliamp-widget installer
# Instala el widget de escritorio (Omarchy) y/o la extensión de Pi.
# Idempotente: se puede correr varias veces.
#
# Por defecto el widget es AUTOCONTENIDO: el propio plugin lanza el helper
# (el daemon que sondea cliamp y baja la tapa). Con --with-systemd, en su
# lugar se instala un servicio systemd que lo corre.
set -euo pipefail

PLUGIN_ID="gabox.cliamp-now-playing"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
EXT_DIR="$HOME/.pi/agent/extensions"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="cliamp-widget.service"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DESKTOP=1
# La extensión de Pi es OPT-IN explícita: nunca copiar código ejecutable a
# ~/.pi/agent/extensions/ por defecto (Pi auto-carga lo que hay ahí).
INSTALL_PI=0
WITH_SYSTEMD=0

usage() {
  cat <<'EOF'
Uso: ./install.sh [opciones]

Por defecto instala SOLO el widget de escritorio (Omarchy).
La extensión de Pi es opt-in explícita (--pi / --pi-only).

Opciones:
  --pi              instalar también la extensión de Pi (opt-in)
  --pi-only         instalar solo la extensión de Pi
  --desktop-only    instalar solo el widget de escritorio (default)
  --with-systemd    correr el helper como servicio systemd (en vez del plugin)
  -h, --help        esta ayuda
EOF
}

for arg in "$@"; do
  case "$arg" in
    --pi)           INSTALL_PI=1 ;;
    --pi-only)      INSTALL_DESKTOP=0; INSTALL_PI=1 ;;
    --desktop-only) INSTALL_DESKTOP=1; INSTALL_PI=0 ;;
    --with-systemd) WITH_SYSTEMD=1 ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "opción desconocida: $arg" >&2; usage; exit 2 ;;
  esac
done

ok()   { printf '✓ %s\n' "$*"; }
warn() { printf '⚠ %s\n' "$*"; }

# ---------------------------------------------------------------------------
# Extensión de Pi
# ---------------------------------------------------------------------------
if [[ "$INSTALL_PI" -eq 1 ]]; then
  if [[ -d "$HOME/.pi/agent/extensions" ]]; then
    mkdir -p "$EXT_DIR"
    cp "$ROOT/extension/cliamp.ts" "$EXT_DIR/cliamp.ts"
    ok "Extensión de Pi instalada en $EXT_DIR/cliamp.ts (recargá Pi con /reload)"
  else
    warn "Pi no detectado (~/.pi/agent/extensions no existe). Omito la extensión."
  fi
fi

# ---------------------------------------------------------------------------
# Widget de escritorio (Omarchy)
# ---------------------------------------------------------------------------
if [[ "$INSTALL_DESKTOP" -eq 1 ]]; then
  MISSING=()
  for c in cliamp jq curl bash; do
    command -v "$c" >/dev/null 2>&1 || MISSING+=("$c")
  done
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Faltan dependencias: ${MISSING[*]} (el widget puede no funcionar)."
  fi

  # 1) plugin Quickshell
  mkdir -p "$PLUGIN_DIR"
  cp "$ROOT/manifest.json" "$PLUGIN_DIR/manifest.json"
  cp "$ROOT/Service.qml"   "$PLUGIN_DIR/Service.qml"
  cp "$ROOT/BarWidget.qml" "$PLUGIN_DIR/BarWidget.qml"
  cp "$ROOT/helper.sh"     "$PLUGIN_DIR/helper.sh"
  if [[ ! -f "$PLUGIN_DIR/settings.json" ]]; then
    cp "$ROOT/settings.json" "$PLUGIN_DIR/settings.json"
  fi
  chmod +x "$PLUGIN_DIR/helper.sh"
  ok "Plugin instalado en $PLUGIN_DIR"

  # 2) helper: autocontenido (lo arranca el plugin) o systemd (opcional)
  if [[ "$WITH_SYSTEMD" -eq 1 ]]; then
    if command -v systemctl >/dev/null 2>&1; then
      mkdir -p "$SERVICE_DIR"
      cp "$ROOT/systemd/$SERVICE_NAME" "$SERVICE_DIR/$SERVICE_NAME"
      systemctl --user daemon-reload
      systemctl --user enable --now "$SERVICE_NAME"
      ok "Helper como servicio systemd ('$SERVICE_NAME')"
    else
      warn "systemctl no disponible; el helper lo correrá el propio plugin."
    fi
  else
    ok "Helper autocontenido (lo arranca el plugin al cargar)"
  fi

  # 3) habilitar el plugin en el shell de Omarchy
  if command -v omarchy-shell >/dev/null 2>&1; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    omarchy plugin enable  "$PLUGIN_ID" >/dev/null 2>&1 || true
    omarchy restart shell >/dev/null 2>&1 || true
    ok "Plugin habilitado en el shell (botón agregado a la barra, sección derecha)"
  else
    warn "omarchy-shell no disponible; habilitá el plugin a mano."
  fi
fi

echo
echo "Listo. Si instalaste la extensión, recargá Pi con /reload."
