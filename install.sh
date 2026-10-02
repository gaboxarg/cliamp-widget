#!/usr/bin/env bash
# cliamp-widget installer
# Instala el widget de escritorio (Omarchy) y/o la extensión de Pi.
# Idempotente: se puede correr varias veces.
set -euo pipefail

PLUGIN_ID="gabox.cliamp-now-playing"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
EXT_DIR="$HOME/.pi/agent/extensions"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="cliamp-widget.service"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALL_DESKTOP=1
INSTALL_PI=1

usage() {
  cat <<'EOF'
Uso: ./install.sh [opciones]

Sin opciones instala todo lo que detecte.

Opciones:
  --desktop-only   instalar solo el widget de escritorio (Omarchy)
  --pi-only        instalar solo la extensión de Pi
  -h, --help       esta ayuda
EOF
}

for arg in "$@"; do
  case "$arg" in
    --desktop-only) INSTALL_DESKTOP=1; INSTALL_PI=0 ;;
    --pi-only)      INSTALL_DESKTOP=0; INSTALL_PI=1 ;;
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
  for c in cliamp jq curl; do
    command -v "$c" >/dev/null 2>&1 || MISSING+=("$c")
  done
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Faltan dependencias: ${MISSING[*]} (el widget puede no funcionar)."
  fi

  # 1) plugin Quickshell
  mkdir -p "$PLUGIN_DIR"
  cp "$ROOT/omarchy-plugin/manifest.json" "$PLUGIN_DIR/manifest.json"
  cp "$ROOT/omarchy-plugin/Service.qml"   "$PLUGIN_DIR/Service.qml"
  cp "$ROOT/omarchy-plugin/BarWidget.qml" "$PLUGIN_DIR/BarWidget.qml"
  cp "$ROOT/omarchy-plugin/helper.sh"     "$PLUGIN_DIR/helper.sh"
  if [[ ! -f "$PLUGIN_DIR/settings.json" ]]; then
    cp "$ROOT/omarchy-plugin/settings.json" "$PLUGIN_DIR/settings.json"
  fi
  chmod +x "$PLUGIN_DIR/helper.sh"
  ok "Plugin instalado en $PLUGIN_DIR"

  # 2) servicio systemd (daemon helper)
  if command -v systemctl >/dev/null 2>&1; then
    mkdir -p "$SERVICE_DIR"
    cp "$ROOT/systemd/$SERVICE_NAME" "$SERVICE_DIR/$SERVICE_NAME"
    systemctl --user daemon-reload
    systemctl --user enable --now "$SERVICE_NAME"
    ok "Servicio systemd '$SERVICE_NAME' activado"
  else
    warn "systemctl no disponible; corré helper.sh a mano para tener tapa y estado."
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
