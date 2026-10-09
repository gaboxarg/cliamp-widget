# cliamp-widget

**English** · [Español](README.es.md)

Desktop widget and **Pi** extension that show and control the music playing in
[cliamp](https://github.com/bjarneo/cliamp) — the retro terminal music player.

> Shows album art, title, artist, progress with elapsed/total time, and playback
> controls, right on your desktop (and optionally integrates cliamp with your
> Pi agent).

---

## What's included

The repo contains **two independent components**; use one, the other, or both:

| Component | For | What it does |
|---|---|---|
| Plugin files (repo root) | **Omarchy 4+** desktop (Hyprland + Quickshell) | Floating "now playing" card + bar button |
| `extension/` | **Pi** coding agent | Tools, `/cliamp` command, and shortcuts to control cliamp |

---

## 1) Desktop widget (Omarchy / Quickshell)

A floating card that appears on the desktop while music plays:

```
┌─────────────────────────────────────────────┐
│  ┌──────┐  Track title                      │
│  │ art  │  Artist                           │
│  │      │  ⏮  ▶  ⏭                          │
│  └──────┘  ━━━━━━━━━━━━━━━━  9:01 / 59:20  │
└─────────────────────────────────────────────┘
```

### Features

- 🎨 **Album art**: derived from the YouTube Music thumbnail and cached.
- ▶️ **Controls**: previous / play-pause / next.
- ⏱️ **Time**: `elapsed / total` (`m:ss`, or `h:mm:ss` when over an hour).
- 📊 **Progress bar** updating live.
- ✋ **Draggable**: move it anywhere; the position is persisted.
- 🙈 **Auto-hide**: disappears when nothing is playing.
- ⏲️ **Peek mode**: optionally appear every N seconds (see configuration).
- 🎛️ **Bar button**: a ♫ icon in the Omarchy bar to show/hide it; hides itself when cliamp is idle (`hideBarWhenIdle`).
- 🔌 **IPC**: scriptable via `omarchy-shell cliamp-widget toggle`.

### Requirements

- [cliamp](https://github.com/bjarneo/cliamp) v2.x with a provider configured
  (**YT Music** by default).
- **Omarchy 4+** (Hyprland + the Quickshell shell).
- `jq` and `curl` (systemd is optional — the plugin can run its own helper).

> Art comes from the YouTube thumbnail (YT Music). Other providers (Spotify,
> Tidal, Qobuz…) don't expose art through cliamp; title and controls still work.

### Configuration

`~/.config/omarchy/plugins/gabox.cliamp-now-playing/settings.json`:

```json
{
  "peekEverySeconds": 0,
  "peekDurationSeconds": 6,
  "showOnTrackChange": true,
  "hideBarWhenIdle": true
}
```

| Key | Description |
|---|---|
| `peekEverySeconds` | `0` = always visible while playing; `N > 0` = show every N seconds. |
| `peekDurationSeconds` | How long it stays visible on each peek. |
| `showOnTrackChange` | Briefly show it when the track changes. |
| `hideBarWhenIdle` | `true` = hide the ♫ bar button when cliamp is idle (stopped / no track), freeing bar space. Set `false` to keep it always visible. |

Changes apply on their own within ~10 seconds (no restart needed).

### Usage

- **Drag** the card to move it (the position is saved).
- **Click** ⏮ / ▶ / ⏭ to control playback.
- **♫ button** in the bar (right section) to show/hide the widget.
- From the terminal:

```bash
omarchy-shell cliamp-widget toggle   # show/hide
omarchy-shell cliamp-widget state    # current state (JSON)
```

---

## 2) Pi extension

Integrates cliamp with the Pi agent.

### What it provides

- **Tools** (the model uses them automatically):
  - `cliamp_search` — search for music.
  - `cliamp_play` — play (by search, index, playlist, or resume).
  - `cliamp_control` — play / pause / toggle / next / prev / stop / volume.
  - `cliamp_status` — playback status.
  - `cliamp_playlists` — list provider playlists.
- **Command** `/cliamp`:

```
/cliamp search <query>       search (numbered results)
/cliamp play [n]             play result n (or resume)
/cliamp pause | toggle | next | prev | stop
/cliamp volume <dB>          adjust volume
/cliamp status               current state
/cliamp playlists            list playlists
/cliamp playlist <name>      load a playlist
```

- **Global shortcuts** (work while typing):
  - `Ctrl+Alt+Space` — play/pause.
  - `Ctrl+Alt+←` / `Ctrl+Alt+→` — previous / next.

### Requirements

- [Pi](https://github.com/earendil-works/pi) with user extensions under
  `~/.pi/agent/extensions/`.
- [cliamp](https://github.com/bjarneo/cliamp) installed and on `PATH`.
- YouTube Music authenticated in cliamp — browser cookies or OAuth. The
  easiest path is `cliamp setup` (or edit `~/.config/cliamp/config.toml`):

  ```toml
  [ytmusic]
  cookies_from = "brave"   # brave, chrome, chromium, firefox, edge, opera, safari
  ```

  Profile/keyring syntax: `"chrome:Profile 1"`, `"firefox:default-release"`,
  `"chromium+gnomekeyring"`, `"brave+kwallet"`.
- `yt-dlp` on `PATH` for playback (`pip install yt-dlp`).

> **401 at the start of a session.** The first search of a fresh Pi session can
> return `401 Unauthorized` (or `cannot decrypt v11 cookies: no key found`)
> while cliamp refreshes the browser-cookie session; the next request usually
> succeeds. The extension retries once and prints a fix instead of the raw
> error. If it persists, sign in to music.youtube.com in that browser or re-run
> `cliamp setup` (on Linux keyrings use a suffix like `brave+gnomekeyring`).

---

## Installation

### Automatic (recommended)

```bash
git clone https://github.com/gaboxarg/cliamp-widget.git
cd cliamp-widget
./install.sh              # desktop widget (default; Pi extension is opt-in)
./install.sh --pi         # also install the Pi extension
./install.sh --pi-only    # Pi extension only
./install.sh --with-systemd   # run the helper as a systemd service instead
```

The installer is idempotent: it copies the files, enables the plugin in the
Omarchy shell, and (by default) lets the plugin run its own helper.

### Via `omarchy plugin add` (recommended for the widget)

The widget is self-contained — the plugin starts its own helper, so installing
the plugin is all you need:

```bash
omarchy plugin add https://github.com/gaboxarg/cliamp-widget.git --enable
```

That's it: the card appears while music plays.

> **Optional — systemd instead of the built-in helper.** If you prefer the
> helper to run as a systemd service (journal logging + auto-restart), install
> it; the plugin detects the already-running helper and skips its own:
>
> ```bash
> mkdir -p ~/.config/systemd/user
> cp ~/.config/omarchy/plugins/gabox.cliamp-now-playing/systemd/cliamp-widget.service ~/.config/systemd/user/
> systemctl --user daemon-reload
> systemctl --user enable --now cliamp-widget.service
> omarchy restart shell
> ```

### Manual

**Desktop widget (self-contained):**

```bash
# 1) plugin — starts its own helper
mkdir -p ~/.config/omarchy/plugins/gabox.cliamp-now-playing
cp manifest.json Service.qml BarWidget.qml helper.sh settings.json ~/.config/omarchy/plugins/gabox.cliamp-now-playing/
chmod +x ~/.config/omarchy/plugins/gabox.cliamp-now-playing/helper.sh

# 2) enable the plugin in the shell
omarchy-shell shell rescanPlugins
omarchy plugin enable gabox.cliamp-now-playing
omarchy restart shell
```

(Optional: to run the helper as a systemd service instead, copy
`systemd/cliamp-widget.service` to `~/.config/systemd/user/` and run
`systemctl --user enable --now cliamp-widget.service`.)

**Pi extension:**

```bash
mkdir -p ~/.pi/agent/extensions
cp extension/cliamp.ts ~/.pi/agent/extensions/cliamp.ts
# then reload Pi with /reload (or restart Pi)
```

---

## Uninstall

```bash
# Remove the plugin (also removes the bar button)
omarchy plugin remove gabox.cliamp-now-playing

# If you used the systemd helper, disable and remove it
systemctl --user disable --now cliamp-widget.service 2>/dev/null || true
rm -f ~/.config/systemd/user/cliamp-widget.service
systemctl --user daemon-reload

# Optional: remove the widget state (cover art cache, saved position)
rm -rf ~/.local/state/cliamp-widget

# Optional: remove the Pi extension
rm -f ~/.pi/agent/extensions/cliamp.ts
```

---

## How it works

```
                 ┌───────────────────────────────┐
 cliamp ──1s──▶ │ helper.sh (started by plugin) │──▶ status.json + cover.jpg
                 └───────────────────────────────┘            │
                                                            ▼
        Service.qml (Quickshell)  ◀── reads every 1s ── ~/.local/state/cliamp-widget/
            │
            ├── floating card (PanelWindow, layer-shell)
            └── bar button (BarWidget.qml) ⇄ serviceFor()
```

1. `helper.sh` (started by the plugin itself, or optionally by systemd) polls
   `cliamp remote state` every second, extracts title/artist/state/position,
   and downloads the YouTube Music art to
   `~/.local/state/cliamp-widget/covers/`.
2. `Service.qml` reads that state and draws the card; the buttons run
   `cliamp toggle|next|prev`.
3. The Pi extension talks to the same cliamp IPC API for searches, playback,
   and controls from the agent.

None of this requires modifying cliamp: it uses its IPC API (`cliamp remote`).

---

## Troubleshooting

| Problem | Solution |
|---|---|
| Widget doesn't appear | Make sure cliamp is running and something is playing (`cliamp status`). The widget hides when nothing is playing. |
| No art | Only works with YT Music (YouTube thumbnail). Check `~/.local/state/cliamp-widget/helper.log` (or `systemctl --user status cliamp-widget.service` if using systemd). |
| Bar button missing | `omarchy-shell shell rescanPlugins` and confirm `gabox.cliamp-now-playing` is in `bar.layout` (`cat ~/.config/omarchy/shell.json`). |
| QML changes don't apply | `keepLoaded` services need a shell restart: `omarchy restart shell`. |
| Pi search returns 401 / auth error | cliamp needs a valid YT Music session. Sign in to music.youtube.com in the configured browser, or re-run `cliamp setup`. On Linux keyrings use `cookies_from = "brave+gnomekeyring"` (or `+kwallet`). |

---

## License

[MIT](LICENSE)
