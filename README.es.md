# cliamp-widget

[English](README.md) · **Español**

Widget de escritorio y extensión para **Pi** que muestran y controlan la música
que suena en [cliamp](https://github.com/bjarneo/cliamp) — el reproductor de
música retro para terminal.

> Muestra la tapa del álbum, el título, el artista, el progreso con tiempo
> transcurrido/total y controles de reproducción, directamente en el escritorio
> (y, opcionalmente, integra cliamp con tu agente Pi).

---

## Qué incluye

El repo tiene **dos componentes independientes**; podés usar uno, el otro o ambos:

| Componente | Para quién | Qué hace |
|---|---|---|
| Archivos del plugin (raíz del repo) | Escritorio **Omarchy 4+** (Hyprland + Quickshell) | Tarjeta flotante "now playing" + botón en la barra |
| `extension/` | **Pi** coding agent | Herramientas, comando `/cliamp` y atajos para controlar cliamp |

---

## 1) Widget de escritorio (Omarchy / Quickshell)

Una tarjeta flotante que aparece en el escritorio mientras suena música:

```
┌─────────────────────────────────────────────┐
│  ┌──────┐  Título de la canción             │
│  │ tapa │  Artista                          │
│  │      │  ⏮  ▶  ⏭                          │
│  └──────┘  ━━━━━━━━━━━━━━━━  9:01 / 59:20  │
└─────────────────────────────────────────────┘
```

### Características

- 🎨 **Tapa del álbum**: se deriva del thumbnail de YouTube Music y se cachea.
- ▶️ **Controles**: anterior / play-pausa / siguiente.
- ⏱️ **Tiempo**: `transcurrido / total` (formato `m:ss`, o `h:mm:ss` si supera la hora).
- 📊 **Barra de progreso** en vivo.
- ✋ **Arrastrable**: movelo a cualquier parte del escritorio; la posición se guarda.
- 🙈 **Auto-ocultado**: desaparece cuando no hay nada reproduciéndose.
- ⏲️ **Modo "peek"**: opcionalmente aparecer cada N segundos (ver configuración).
- 🎛️ **Botón en la barra**: un ícono ♫ en la barra de Omarchy para mostrar/ocultar.
- 🔌 **IPC**: controlable por terminal con `omarchy-shell cliamp-widget toggle`.

### Requisitos

- [cliamp](https://github.com/bjarneo/cliamp) v2.x con un proveedor configurado
  (por defecto **YT Music**).
- **Omarchy 4+** (Hyprland + el shell Quickshell).
- `jq` y `curl` (systemd es opcional — el plugin puede correr su propio helper).

> La tapa se obtiene del thumbnail de YouTube (YT Music). Otros proveedores
> (Spotify, Tidal, Qobuz…) no exponen arte vía cliamp; el título y los controles
> funcionan igual.

### Configuración

`~/.config/omarchy/plugins/gabox.cliamp-now-playing/settings.json`:

```json
{
  "peekEverySeconds": 0,
  "peekDurationSeconds": 6,
  "showOnTrackChange": true
}
```

| Clave | Descripción |
|---|---|
| `peekEverySeconds` | `0` = siempre visible mientras suena; `N > 0` = aparecer cada N segundos. |
| `peekDurationSeconds` | Cuántos segundos queda visible en cada "peek". |
| `showOnTrackChange` | Mostrarlo brevemente al cambiar de canción. |

Los cambios se aplican solos a los ~10 segundos (no hace falta reiniciar).

### Uso

- **Arrastrá** la tarjeta para moverla (la posición queda guardada).
- **Clic** en ⏮ / ▶ / ⏭ para controlar la reproducción.
- **Botón ♫** en la barra (sección derecha) para mostrar/ocultar el widget.
- Por terminal:

```bash
omarchy-shell cliamp-widget toggle   # mostrar/ocultar
omarchy-shell cliamp-widget state    # estado actual (JSON)
```

---

## 2) Extensión para Pi

Integra cliamp con el agente Pi.

### Qué aporta

- **Herramientas** (el modelo las usa automáticamente):
  - `cliamp_search` — buscar música.
  - `cliamp_play` — reproducir (búsqueda, índice, playlist o reanudar).
  - `cliamp_control` — play / pause / toggle / next / prev / stop / volume.
  - `cliamp_status` — estado de reproducción.
  - `cliamp_playlists` — listar playlists del proveedor.
- **Comando** `/cliamp`:

```
/cliamp search <query>       buscar (resultados numerados)
/cliamp play [n]             reproducir resultado n (o reanudar)
/cliamp pause | toggle | next | prev | stop
/cliamp volume <dB>          ajustar volumen
/cliamp status               estado actual
/cliamp playlists            listar playlists
/cliamp playlist <nombre>    cargar una playlist
```

- **Atajos globales** (funcionan mientras escribís):
  - `Ctrl+Alt+Espacio` — play/pausa.
  - `Ctrl+Alt+←` / `Ctrl+Alt+→` — anterior / siguiente.

### Requisitos

- [Pi](https://github.com/earendil-works/pi) con las extensiones de usuario en
  `~/.pi/agent/extensions/`.

---

## Instalación

### Automática (recomendada)

```bash
git clone https://github.com/gaboxarg/cliamp-widget.git
cd cliamp-widget
./install.sh              # instala todo lo que detecte
./install.sh --desktop-only   # solo el widget de escritorio
./install.sh --pi-only        # solo la extensión de Pi
./install.sh --with-systemd   # correr el helper como servicio systemd
```

El instalador es idempotente: copia los archivos, habilita el plugin en el
shell de Omarchy y, por defecto, deja que el plugin corra su propio helper.

### Vía `omarchy plugin add` (recomendado para el widget)

El widget es autocontenido: el plugin arranca su propio helper, así que con
instalar el plugin alcanza:

```bash
omarchy plugin add https://github.com/gaboxarg/cliamp-widget.git --enable
```

Listo: la tarjeta aparece mientras suena música.

> **Opcional — systemd en vez del helper interno.** Si preferís que el helper
> corra como servicio de systemd (logs en el journal + auto-reinicio),
> instalalo; el plugin detecta el helper ya corriendo y no arranca el suyo:
>
> ```bash
> mkdir -p ~/.config/systemd/user
> cp ~/.config/omarchy/plugins/gabox.cliamp-now-playing/systemd/cliamp-widget.service ~/.config/systemd/user/
> systemctl --user daemon-reload
> systemctl --user enable --now cliamp-widget.service
> omarchy restart shell
> ```

### Manual

**Widget de escritorio (autocontenido):**

```bash
# 1) plugin — arranca su propio helper
mkdir -p ~/.config/omarchy/plugins/gabox.cliamp-now-playing
cp manifest.json Service.qml BarWidget.qml helper.sh settings.json ~/.config/omarchy/plugins/gabox.cliamp-now-playing/
chmod +x ~/.config/omarchy/plugins/gabox.cliamp-now-playing/helper.sh

# 2) habilitar el plugin en el shell
omarchy-shell shell rescanPlugins
omarchy plugin enable gabox.cliamp-now-playing
omarchy restart shell
```

(Opcional: para correr el helper como servicio de systemd, copiá
`systemd/cliamp-widget.service` a `~/.config/systemd/user/` y ejecutá
`systemctl --user enable --now cliamp-widget.service`.)

**Extensión de Pi:**

```bash
mkdir -p ~/.pi/agent/extensions
cp extension/cliamp.ts ~/.pi/agent/extensions/cliamp.ts
# y recargá Pi con /reload (o reiniciá Pi)
```

---

## Desinstalar

```bash
# Quitar el plugin (también quita el botón de la barra)
omarchy plugin remove gabox.cliamp-now-playing

# Si usaste el helper de systemd, desactivalo y borralo
systemctl --user disable --now cliamp-widget.service 2>/dev/null || true
rm -f ~/.config/systemd/user/cliamp-widget.service
systemctl --user daemon-reload

# Opcional: borrar el estado del widget (caché de tapas, posición guardada)
rm -rf ~/.local/state/cliamp-widget

# Opcional: quitar la extensión de Pi
rm -f ~/.pi/agent/extensions/cliamp.ts
```

---

## Cómo funciona

```
                 ┌───────────────────────────────┐
 cliamp ──1s──▶ │ helper.sh (lo arranca el plugin) │──▶ status.json + cover.jpg
                 └───────────────────────────────┘            │
                                                            ▼
        Service.qml (Quickshell)  ◀── lee cada 1s ── ~/.local/state/cliamp-widget/
            │
            ├── tarjeta flotante (PanelWindow, layer-shell)
            └── botón de barra (BarWidget.qml) ⇄ serviceFor()
```

1. `helper.sh` (lo arranca el propio plugin, u opcionalmente systemd) sondea
   `cliamp remote state` cada segundo, extrae título/artista/estado/posición
   y baja la tapa de YouTube Music a
   `~/.local/state/cliamp-widget/covers/`.
2. `Service.qml` lee ese estado y dibuja la tarjeta; los botones ejecutan
   `cliamp toggle|next|prev`.
3. La extensión de Pi habla con la misma API IPC de cliamp para búsquedas,
   reproducción y controles desde el agente.

Nada de esto requiere modificar cliamp: usa su API IPC (`cliamp remote`).

---

## Solución de problemas

| Problema | Solución |
|---|---|
| El widget no aparece | Verificá que cliamp esté corriendo y que suene algo (`cliamp status`). El widget se oculta cuando no hay reproducción. |
| No hay tapa | Solo funciona con YT Music (thumbnail de YouTube). Revisá `~/.local/state/cliamp-widget/helper.log` (o `systemctl --user status cliamp-widget.service` si usás systemd). |
| No aparece el botón en la barra | `omarchy-shell shell rescanPlugins` y confirmá que `gabox.cliamp-now-playing` esté en `bar.layout` (`cat ~/.config/omarchy/shell.json`). |
| Cambios de QML no se aplican | Los servicios `keepLoaded` requieren reiniciar el shell: `omarchy restart shell`. |

---

## Licencia

[MIT](LICENSE)
