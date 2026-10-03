# cliamp-widget — Manual de referencia (handoff)

> Documento completo para retomar el trabajo ante cualquier problema, cambio o
> nueva versión. Contiene el estado actual, la arquitectura, todas las
> decisiones, los errores que ya se resolvieron (con su solución) y el
> troubleshooting. Guardado en el repo (`docs/HANDBOOK.md`) y en Google Drive.

---

## 1. Resumen del proyecto

Dos componentes para ver y controlar la música de [cliamp](https://github.com/bjarneo/cliamp):

1. **Widget de escritorio (Omarchy/Quickshell)** — tarjeta flotante con tapa,
   título, artista, barra de progreso + tiempo (`m:ss / m:ss`) y controles.
   Arrastrable, auto-ocultable, con botón en la barra y modo "peek".
2. **Extensión para Pi** — tools (`cliamp_search`, `cliamp_play`, `cliamp_control`,
   `cliamp_status`, `cliamp_playlists`), comando `/cliamp` y atajos globales
   (`Ctrl+Alt+Espacio`, `Ctrl+Alt+←/→`).

**Estado: publicado y aprobado en el marketplace de Omarchy.**

---

## 2. Estado actual (checklist rápido)

| Qué | Dónde / valor |
|---|---|
| Repo público | `https://github.com/gaboxarg/cliamp-widget` (rama `main`) |
| Versión estable | tag `v1.1.0` (release en GitHub) |
| Plugin id | `gabox.cliamp-now-playing` |
| Plugin instalado (live) | `~/.config/omarchy/plugins/gabox.cliamp-now-playing/` |
| Extensión Pi instalada | `~/.pi/agent/extensions/cliamp.ts` |
| Helper | autocontenido (lo arranca el plugin); systemd **desactivado** |
| Estado runtime | `~/.local/state/cliamp-widget/` (status.json, position.json, covers/, helper.log) |
| Marketplace | issue `omacom/omarchy-plugin-marketplace#9773` → `approved-and-verified` |
| cliamp | v2.0.1 (`/usr/bin/cliamp`), proveedor YT Music |
| Docs en Drive | `gdrive:cliamp-widget/` (README.md, README.es.md, NOTES.md, HANDBOOK.md) |

---

## 3. Arquitectura

```
                 ┌───────────────────────────────┐
 cliamp ──1s──▶ │ helper.sh (arrancado por el   │──▶ status.json + cover.jpg
                 │ plugin; systemd opcional)     │
                 └───────────────────────────────┘            │
                                                              ▼
        Service.qml (Quickshell) ◀── lee cada 1s ── ~/.local/state/cliamp-widget/
            │
            ├── tarjeta flotante (PanelWindow, layer-shell)
            └── botón de barra (BarWidget.qml) ⇄ serviceFor()
```

- **`helper.sh`**: loop infinito que sondea `cliamp remote state` cada 1s,
  extrae título/artista/estado/posición/duración/volumen, deriva la tapa de
  YouTube Music (del thumbnail) y escribe `status.json`. Tiene **guard de
  instancia única** (pidfile en `$XDG_RUNTIME_DIR/cliamp-widget-helper.pid`).
- **`Service.qml`**: lee `status.json` (cada 1s vía `Process`+`cat`), dibuja la
  tarjeta, arranca el helper (autocontenido) y expone IPC (`cliamp-widget`).
  Los botones ejecutan `cliamp toggle|next|prev`. El arrastre actualiza
  `margins.left/top` y guarda `position.json`.
- **`BarWidget.qml`**: botón ♫ en la barra. Usa `bar.shell.serviceFor(id)` para
  llamar `toggleHidden()` del service.
- **`install.sh`**: instalador idempotente. Default = solo widget. La extensión
  de Pi es opt-in (`--pi` / `--pi-only`).

---

## 4. Decisiones clave (por qué)

1. **`manifest.json` en la raíz del repo** — `omarchy plugin add <url>` clona el
   repo y lee `manifest.json` de la raíz. El repo ES el plugin.
2. **Autocontenido** — `Service.qml` arranca `helper.sh` por su cuenta. Así
   `omarchy plugin add` alcanza para todo. systemd quedó opcional (`--with-systemd`).
3. **Guard de instancia única** — evita duplicados si plugin y systemd corren a la vez.
4. **Extensión de Pi opt-in** — pedido de la revisión de seguridad del
   marketplace: no copiar código a `~/.pi/agent/extensions/` por defecto.
5. **Tapa solo YT Music** — cliamp NO expone arte (ni en IPC ni en MPRIS). Se
   deriva de `https://i.ytimg.com/vi/<id>/maxresdefault.jpg` (fallback hq/mq).
   Otros proveedores: título y controles funcionan, pero sin tapa.
6. **`manifest.__sourceDir`** — para resolver `settings.json` de forma portable.

---

## 5. Errores que ya se resolvieron (lecciones aprendidas)

Esto es lo más valioso para no repetir problemas:

### 5.1 Pi / extensión (TUI)
- **Crasheo de Pi: `Error: Unknown theme color: accent`** — se usó
  `theme.bg("accent", ...)`. `accent` es token de *foreground*, no de *fondo*.
  Para usar un color de foreground como fondo: `theme.style(text, { bg:
  theme.colors.accent })`. **Nunca** `theme.bg(token-fg)`.
- Un throw dentro del `render()` de un widget tumba toda la TUI. Siempre
  envolver el render en `try/catch` con fallback.
- Los atajos globales son `Key.ctrlAlt(...)`; el widget de terminal se registraba
  con `ctx.ui.setWidget(key, (tui, theme) => component, { placement })`.

### 5.2 Quickshell / Omarchy
- **Márgenes del PanelWindow**: en Quickshell 3 se usan `margins.bottom/right`
  (grupo `Margins`), NO `anchors.bottomMargin` (eso da "Cannot assign to
  non-existent property"). Los `anchors` solo tienen `top/bottom/left/right` (bool).
- **Tamaño del PanelWindow**: usar `implicitWidth`/`implicitHeight`
  (`width`/`height` están deprecados en PanelWindow).
- **QML disk cache**: si un cambio no se refleja, limpiar
  `~/.cache/quickshell/qmlcache/` y `omarchy restart shell`.
- **`keepLoaded` service**: los cambios de código solo aplican reiniciando el
  shell (`omarchy restart shell`).
- **Botón de barra ↔ service**: `bar.shell.serviceFor("<plugin-id>")` expone el
  root del Service.qml (props + funciones).
- **Process long-running**: `Process { command: [...] }` + `running = true`.
  Sobrevive reloads (PostReloadHook). Para matarlo: `running = false`.

### 5.3 cliamp
- **No hay arte** en IPC ni MPRIS (`mpris:artUrl` ausente). El snapshot trae
  `path` (URL de YouTube) → derivar thumbnail.
- MPRIS sí está expuesto: `org.mpris.MediaPlayer2.cliamp` (título, artista, url,
  length), útil para `playerctl` y widgets genéricos.
- Stream de eventos: `cliamp remote events runtime.state` (NDJSON).
- `cliamp remote state` cuando el daemon no corre → sale con error (no auto-inicia).

### 5.4 Instalación / GitHub / Marketplace
- **`omarchy plugin add`** exige `manifest.json` en la raíz del repo.
- **Usuario de GitHub**: `gaboxarg` (el `git config user.name` decía `gabox7`,
  que estaba mal). Corregido en URLs y LICENSE.
- **Marketplace**: el fallo "The analyzed validation reports failed integrity
  checks" fue un bug del workflow de Omarchy (Node 20 deprecado en
  `actions/upload-artifact`), no del plugin. La validación real había pasado.
- **Revisión de seguridad** pidió: (a) extensión de Pi opt-in (`INSTALL_PI=0`),
  (b) renombrar el heading del issue a `### Suggest a missing tag`. Luego editar
  el issue para re-validar.
- Para re-validar: **editar el issue** (cualquier edición) dispara el workflow.

### 5.5 Misc
- `pgrep -f "helper.sh"` se matchea a sí mismo → usar `pgrep -af 'helper\.sh$'`.
- `grim` usa coordenadas **lógicas** (monitor con scale=2 → lógico 1280x800).
- La tarjeta se oculta cuando `state == "stopped"` o no hay track (por diseño).

---

## 6. Troubleshooting rápido

| Síntoma | Chequear / solución |
|---|---|
| Widget no aparece | `cliamp status` (¿suena algo?). Se oculta si no reproduce. `omarchy-shell cliamp-widget state`. |
| No hay tapa | Solo YT Music. Ver `~/.local/state/cliamp-widget/helper.log`. Helper corriendo: `pgrep -af 'helper\.sh$'` (1 instancia). |
| Botón de barra no aparece | `omarchy-shell shell rescanPlugins`; verificar `bar.layout` en `~/.config/omarchy/shell.json`. |
| Cambios QML no aplican | `omarchy restart shell` (y/o limpiar `~/.cache/quickshell/qmlcache/`). |
| Helper duplicado | El pidfile evita duplicados; si quedaron 2, matar el viejo o reiniciar el shell. |
| Pi no carga la extensión | `node` parse check o `/reload`. El archivo es `~/.pi/agent/extensions/cliamp.ts`. |
| Posición del widget rara | `~/.local/state/cliamp-widget/position.json` (x,y lógicos). Borrarlo = vuelve a 24,24. |
| Marketplace re-validación | Editar el issue #9773. |

---

## 7. Cómo sacar una versión nueva

```bash
git clone https://github.com/gaboxarg/cliamp-widget.git
cd cliamp-widget
# 1) editar archivos
# 2) validar
bash -n install.sh helper.sh
omarchy plugin validate .
# 3) probar en vivo
cp manifest.json Service.qml BarWidget.qml helper.sh settings.json ~/.config/omarchy/plugins/gabox.cliamp-now-playing/
omarchy restart shell
# 4) versionar: subir "version" en manifest.json + actualizar CHANGELOG.md
# 5) commit + tag + push
git add -A && git commit -m "feat: ..."
git tag vX.Y.Z && git push && git push --tags
# 6) release
gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
# 7) marketplace: editar el issue #9773 para re-validar (o el flujo que indiquen)
```

---

## 8. Desinstalar / revertir

```bash
omarchy plugin remove gabox.cliamp-now-playing     # quita plugin + botón de barra
systemctl --user disable --now cliamp-widget.service 2>/dev/null || true
rm -f ~/.config/systemd/user/cliamp-widget.service
systemctl --user daemon-reload
rm -rf ~/.local/state/cliamp-widget                 # estado (tapas, posición)
rm -f ~/.pi/agent/extensions/cliamp.ts              # extensión de Pi
```

---

## 9. Enlaces útiles

- Repo: https://github.com/gaboxarg/cliamp-widget
- Release: https://github.com/gaboxarg/cliamp-widget/releases/tag/v1.1.0
- cliamp: https://github.com/bjarneo/cliamp
- Marketplace (catálogo): https://plugins.omarchy.org
- Issue de publicación: https://github.com/omacom/omarchy-plugin-marketplace/issues/9773
- Guía de desarrollo de plugins: https://plugins.omarchy.org/develop.html
- Guía de publicación: https://plugins.omarchy.org/publish.html
