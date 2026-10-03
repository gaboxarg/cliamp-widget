# Changelog

Todas las versiones notables de **cliamp-widget**.

## [1.1.1] - 2026-10-03

Corrección y documentación de la extensión de Pi (widget sin cambios).

### Extensión de Pi

- Documentación de requisitos: cliamp instalado, autenticación de YouTube Music
  (cookies del navegador u OAuth), navegadores soportados (`brave`, `chrome`,
  `chromium`, `firefox`, `edge`, `opera`, `safari` + perfiles/keyring) y `yt-dlp`.
- Manejo de errores de autenticación de YT Music (401/403, cookies vencidas,
  `cannot decrypt cookies`, keyring): reintento automático y mensaje accionable.
- Fix: desenvuelto de `job.result` en la IPC de cliamp (la búsqueda y la
  reproducción por query no encontraban las pistas).

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

[1.1.1]: https://github.com/gaboxarg/cliamp-widget/releases/tag/v1.1.1
[1.1.0]: https://github.com/gaboxarg/cliamp-widget/releases/tag/v1.1.0
