# Changelog

Todas las versiones notables de **cliamp-widget**.

## [1.1.0] - 2026-10-02

Primera versión publicada en el marketplace de Omarchy.

### Características

- Tarjeta flotante "now playing" (Quickshell) con tapa, título, artista, barra de progreso y tiempo `m:ss / m:ss`.
- Controles ⏮ / ▶ / ⏭.
- Arrastrable, con posición persistida.
- Auto-ocultado cuando no hay reproducción y modo "peek" configurable (`settings.json`).
- Botón en la barra de Omarchy para mostrar/ocultar el widget.
- IPC: `omarchy-shell cliamp-widget toggle|show|hide|state`.
- Autocontenido: el plugin arranca su propio helper (systemd es opcional).
- Extensión para Pi (opt-in): herramientas, comando `/cliamp` y atajos globales.
- Instalable con `omarchy plugin add <url>`.

### Notas técnicas

- `manifest.json` en la raíz del repo (requisito para `omarchy plugin add`).
- Guard de instancia única (pidfile) en `helper.sh`.
- `preview.png` para el marketplace.
- `install.sh` idempotente; la extensión de Pi es opt-in (`--pi` / `--pi-only`).

[1.1.0]: https://github.com/gaboxarg/cliamp-widget/releases/tag/v1.1.0
