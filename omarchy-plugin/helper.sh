#!/usr/bin/env bash
# cliamp desktop widget helper.
# Polls the cliamp IPC snapshot once per second, derives the YouTube Music
# cover art (cliamp does not expose art natively), and writes a small status
# JSON that the Quickshell widget reads.
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cliamp-widget"
COVERS_DIR="$STATE_DIR/covers"
STATUS="$STATE_DIR/status.json"
mkdir -p "$COVERS_DIR"

write_status() {
  local title="$1" artist="$2" state="$3" art="$4" volume="$5" position="$6" duration="$7"
  jq -n \
    --arg title "$title" --arg artist "$artist" --arg state "$state" --arg art "$art" \
    --argjson volume "$volume" --argjson position "$position" --argjson duration "$duration" \
    '{title:$title, artist:$artist, state:$state, art:$art, volume:$volume, position:$position, duration:$duration}' \
    > "$STATUS.tmp" && mv "$STATUS.tmp" "$STATUS"
}

extract_vid() {
  local path="$1" vid=""
  vid="$(printf '%s' "$path" | sed -nE 's#.*[?&]v=([A-Za-z0-9_-]{11}).*#\1#p')"
  if [[ -z "$vid" ]]; then
    vid="$(printf '%s' "$path" | sed -nE 's#.*youtu\.be/([A-Za-z0-9_-]{11}).*#\1#p')"
  fi
  if [[ -z "$vid" ]]; then
    vid="$(printf '%s' "$path" | sed -nE 's#.*/(shorts|embed)/([A-Za-z0-9_-]{11}).*#\2#p')"
  fi
  printf '%s' "$vid"
}

while true; do
  snap="$(cliamp remote state 2>/dev/null || true)"
  if [[ -z "$snap" ]]; then
    write_status "" "" "stopped" "" 0 0 0
    sleep 2
    continue
  fi

  title="$(jq -r '.snapshot.logical_track.title // .snapshot.track.title // ""' <<<"$snap")"
  artist="$(jq -r '.snapshot.logical_track.artist // .snapshot.track.artist // ""' <<<"$snap")"
  path="$(jq -r '.snapshot.logical_track.path // .snapshot.track.path // ""' <<<"$snap")"
  state="$(jq -r '.snapshot.state // "stopped"' <<<"$snap")"
  volume="$(jq -r '.snapshot.volume // 0' <<<"$snap")"
  position="$(jq -r '.snapshot.position // 0' <<<"$snap")"
  duration="$(jq -r '.snapshot.duration // .snapshot.logical_track.duration_secs // .snapshot.track.duration_secs // 0' <<<"$snap")"

  art=""
  vid="$(extract_vid "$path")"
  if [[ -n "$vid" ]]; then
    cover="$COVERS_DIR/$vid.jpg"
    if [[ ! -s "$cover" ]]; then
      for q in maxresdefault hqdefault mqdefault; do
        if curl -fsSL --max-time 10 -o "$cover.tmp" "https://i.ytimg.com/vi/$vid/$q.jpg"; then
          mv "$cover.tmp" "$cover"
          break
        fi
      done
      rm -f "$cover.tmp"
    fi
    [[ -s "$cover" ]] && art="$cover"
  fi

  write_status "$title" "$artist" "$state" "$art" "$volume" "$position" "$duration"
  sleep 1
done
