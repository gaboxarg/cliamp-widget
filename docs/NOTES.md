# cliamp-widget — Notas del proyecto

> Documento de referencia para no perder el contexto: qué es, cómo está armado,
> decisiones tomadas y cómo seguir trabajando en nuevas versiones.

## Qué es

Dos componentes para ver y controlar la música de [cliamp](https://github.com/bjarneo/cliamp):

1. **Widget de escritorio (Omarchy/Quickshell)** — tarjeta flotante con tapa, título,
   artista, progreso + tiempo y controles. Arrastrable, auto-ocultable, con botón
   en la barra y modo "peek".
2. **Extensión para Pi** — tools (`cliamp_search`, `cliamp_play`, `cliamp_control`,
   `cliamp_status`, `cliamp_playlists`), comando `/cliamp` y atajos globales.

## Dónde vive todo

| Qué | Dónde |
|---|---|
| Código fuente (repo) | `~/cliamp-widget/` (git) |
| Repo público | `https://github.com/gaboxarg/cliamp-widget` |
| Plugin instalado (live) | `~/.config/omarchy/plugins/gabox.cliamp-now-playing/` |
| Extensión Pi instalada | `~/.pi/agent/extensions/cliamp.ts` |
| Estado runtime (tapa, posición, status) | `~/.local/state/cliamp-widget/` |
| Docs en Google Drive | `gdrive:cliamp-widget/` (README.md, README.es.md) |
| Issue del marketplace | `https://github.com/omacom/omarchy-plugin-marketplace/issues/9773` |

## Arquitectura

```
                 ┌───────────────────────────────┐
 cliamp ──1s──▶ │ helper.sh (arrancado por el   │──▶ status.json + cover.jpg
                 │ plugin, u opcional systemd)  │
                 └───────────────────────────────┘            │
                                                              ▼
        Service.qml (Quickshell) ◀── lee cada 1s ── ~/.local/state/cliamp-widget/
            │
            ├── tarjeta flotante (PanelWindow, layer-shell)
            └── botón de barra (BarWidget.qml) ⇄ serviceFor()
```

- `helper.sh`: sondea `cliamp remote state` cada 1s, baja la tapa de YT Music
  (deriva el thumbnail de la URL de YouTube) y escribe `status.json`.
- `Service.qml`: lee `status.json`, dibuja la tarjeta y arranca el helper
  (autocontenido). Expone IPC (`cliamp-widget` target) y `hidden/toggleHidden()`
  para el botón de barra.
- `BarWidget.qml`: botón ♫ que alterna `hidden` vía `bar.shell.serviceFor(id)`.
- `install.sh`: instalador idempotente.

## Decisiones clave (por qué)

1. **Manifest en la raíz del repo** — `omarchy plugin add <url>` clona el repo y
   lee `manifest.json` de la raíz. Por eso el repo ES el plugin (los archivos del
   plugin están en la raíz, no en una subcarpeta).
2. **Autocontenido** — `Service.qml` arranca `helper.sh` por su cuenta, así
   `omarchy plugin add` alcanza para tener todo andando. systemd quedó como
   opcional (`--with-systemd`).
3. **Guard de instancia única (pidfile)** en `helper.sh` — evita duplicados si el
   plugin y systemd corren a la vez.
4. **Extensión de Pi opt-in** — no copiar código a `~/.pi/agent/extensions/` por
   defecto (pedido de la revisión de seguridad del marketplace). Se activa con
   `--pi` / `--pi-only`.
5. **Tapa solo para YT Music** — cliamp no expone arte; se deriva de
   `https://i.ytimg.com/vi/<id>/maxresdefault.jpg` (fallback hq/mq). Otros
   proveedores no tienen arte, pero título y controles funcionan.
6. **`manifest.__sourceDir`** para resolver `settings.json` (portable entre
   instalaciones).

## Cómo hacer cambios / sacar una versión nueva

1. **Clonar / arrancar:**
   ```bash
   git clone https://github.com/gaboxarg/cliamp-widget.git
   cd cliamp-widget
   ```
2. **Editar** los archivos (Service.qml, helper.sh, install.sh, etc.).
3. **Validar:**
   ```bash
   bash -n install.sh helper.sh
   omarchy plugin validate .
   ```
4. **Probar en vivo:** copiar a `~/.config/omarchy/plugins/gabox.cliamp-now-playing/`
   y `omarchy restart shell`.
5. **Versionar:** subir `version` en `manifest.json` y actualizar `CHANGELOG.md`.
6. **Commitear y taggear:**
   ```bash
   git add -A && git commit -m "feat: ..."
   git tag vX.Y.Z && git push && git push --tags
   ```
7. **Release en GitHub:** `gh release create vX.Y.Z --notes "..."`.
8. **Actualizar el marketplace:** si hay cambios funcionales, editar el issue
   #9773 (o abrir uno nuevo según indique el marketplace) para re-validar.

## Estado actual

- Publicado y **aprobado** en el marketplace (`approved-and-verified`), a la
  espera de aparecer en https://plugins.omarchy.org.
- Versión estable publicada: `v1.1.0` (ver `CHANGELOG.md`).
