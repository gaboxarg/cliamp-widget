/**
 * cliamp Extension - Control cliamp (retro terminal music player) from Pi.
 *
 * Uses cliamp's version 2 IPC API to search, play, and control music.
 * Default provider is YouTube Music ("ytmusic").
 *
 * Provides:
 *  - Tools (auto-usable by the model from natural language):
 *      cliamp_search, cliamp_play, cliamp_control, cliamp_status, cliamp_playlists
 *  - A /cliamp command with subcommands:
 *      /cliamp search <query>       search and play first result
 *      /cliamp play                 resume playback
 *      /cliamp pause                pause playback
 *      /cliamp toggle               play/pause toggle
 *      /cliamp next | prev | stop
 *      /cliamp volume <dB>          set volume (e.g. -10, +3)
 *      /cliamp status               show current playback state
 *      /cliamp playlists            list provider playlists
 *      /cliamp playlist <name>      load a provider playlist
 */

import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Key } from "@earendil-works/pi-tui";

// ---------------------------------------------------------------------------
// Helpers to talk to cliamp's IPC API
// ---------------------------------------------------------------------------

const DEFAULT_PROVIDER = "ytmusic";

/** Run a cliamp CLI command and return parsed stdout. */
function run(args: string[]): { ok: boolean; stdout: string; stderr: string } {
  const { execFileSync } = require("node:child_process") as typeof import("node:child_process");
  try {
    const stdout = execFileSync("cliamp", args, {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 30_000,
    });
    return { ok: true, stdout: stdout.trim(), stderr: "" };
  } catch (err: any) {
    const stderr = err?.stderr?.toString?.() ?? "";
    const stdout = err?.stdout?.toString?.() ?? "";
    return { ok: false, stdout: stdout.trim(), stderr: stderr.trim() };
  }
}

/** Ensure the cliamp daemon is running so the IPC API is reachable. */
function ensureDaemon(): void {
  const r = run(["remote", "state"]);
  if (r.ok) return; // socket reachable
  const { spawn } = require("node:child_process") as typeof import("node:child_process");
  spawn("cliamp", ["--daemon"], { detached: true, stdio: "ignore" }).unref();
}

/** Call an IPC operation and return the parsed result payload. */
function call(operation: string, params: Record<string, unknown> = {}): unknown {
  ensureDaemon();
  const r = run([
    "remote",
    "call",
    operation,
    "--params",
    JSON.stringify(params),
    "--wait",
  ]);
  if (!r.ok) {
    throw new Error(`cliamp call ${operation} failed: ${r.stderr || r.stdout || "unknown error"}`);
  }
  try {
    const parsed = JSON.parse(r.stdout);
    return parsed?.result ?? parsed;
  } catch {
    return r.stdout;
  }
}

/** Read the runtime snapshot (safe fallback for status). */
function status(): unknown {
  const r1 = run(["remote", "state"]);
  if (r1.ok) {
    try {
      return JSON.parse(r1.stdout)?.result ?? JSON.parse(r1.stdout);
    } catch {
      /* fall through */
    }
  }
  return call("runtime.status");
}

// ---------------------------------------------------------------------------
// Formatting helpers (turn raw results into model-friendly text)
// ---------------------------------------------------------------------------

function fmt(obj: unknown): string {
  if (obj == null) return "(no result)";
  if (typeof obj === "string") return obj;
  return JSON.stringify(obj, null, 2);
}

/** Extract track-like objects from a search result payload. */
function extractTracks(result: unknown): unknown[] {
  const arr = Array.isArray(result)
    ? result
    : result && typeof result === "object"
      ? (result as any).tracks ?? (result as any).items ?? (result as any).results ?? []
      : [];
  return Array.isArray(arr) ? arr : [];
}

/**
 * Given a search result, return a human/machine-readable summary of the found
 * tracks (first N), so the model can present options or auto-pick.
 */
function summarizeSearch(result: unknown, limit = 10): string {
  const tracks = extractTracks(result);
  if (tracks.length === 0) {
    return fmt(result);
  }
  const lines: string[] = [];
  tracks.slice(0, limit).forEach((t: any, i: number) => {
    const title = t?.title ?? t?.name ?? t?.track?.title ?? `#${i}`;
    const artist = t?.artist ?? t?.artists?.map?.((a: any) => a?.name ?? a).join(", ") ?? t?.artistName ?? "";
    const album = t?.album ?? t?.albumName ?? "";
    lines.push(`${i}. ${title}${artist ? ` — ${artist}` : ""}${album ? ` (${album})` : ""}`);
  });
  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

const SearchParams = Type.Object({
  query: Type.String({ description: "Search query, e.g. song title, artist, or album" }),
  provider: Type.Optional(
    Type.String({ description: `Provider name, defaults to ${DEFAULT_PROVIDER}` }),
  ),
  limit: Type.Optional(Type.Number({ description: "Max results to return (default 10)" })),
});

const PlayParams = Type.Object({
  query: Type.Optional(Type.String({ description: "Optional search query to find a track to play" })),
  index: Type.Optional(Type.Number({ description: "Index of the result to play (0-based)" })),
  playlist: Type.Optional(Type.String({ description: "Name of a provider playlist to load and play" })),
  provider: Type.Optional(Type.String({ description: `Provider name, defaults to ${DEFAULT_PROVIDER}` })),
});

const ControlParams = Type.Object({
  action: Type.Union([
    Type.Literal("play"),
    Type.Literal("pause"),
    Type.Literal("toggle"),
    Type.Literal("next"),
    Type.Literal("prev"),
    Type.Literal("stop"),
    Type.Literal("volume"),
  ] as const, { description: "Playback action. Use 'volume' ONLY to change volume (never combine with other actions)." }),
  // For action="volume":
  value: Type.Optional(Type.Number({ description: "Volume level in dB. Absolute value within [-30, +6]." })),
  adjust: Type.Optional(Type.Number({ description: "Relative volume delta in dB (e.g. +2 to raise, -2 to lower)." })),
});

// ---------------------------------------------------------------------------
// Extension factory
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "cliamp_search",
    description: `Search for music on ${DEFAULT_PROVIDER} (or another provider) via cliamp and return a list of matching tracks. Use this when the user asks to find a song, artist, album, or playlist.`,
    parameters: SearchParams,
    async execute(_id, params) {
      const provider = params.provider ?? DEFAULT_PROVIDER;
      const limit = params.limit ?? 10;
      let result: unknown;
      try {
        result = call("provider.search", { provider, query: params.query, offset: 0, limit });
      } catch (e: any) {
        return {
          isError: true,
          content: [{ type: "text", text: `Search failed: ${e.message}` }],
        };
      }
      return {
        content: [{ type: "text", text: summarizeSearch(result, limit) }],
        details: { provider, query: params.query, result },
      };
    },
  });

  pi.registerTool({
    name: "cliamp_play",
    description: `Play music via cliamp. Can resume current playback, search and play a track by query, play a specific search result by index, or load and play a named playlist. Default provider: ${DEFAULT_PROVIDER}.`,
    parameters: PlayParams,
    async execute(_id, params) {
      const provider = params.provider ?? DEFAULT_PROVIDER;
      try {
        if (params.playlist) {
          const r = call("provider.load", { provider, playlist: params.playlist });
          call("play", {});
          return {
            content: [{ type: "text", text: `Loaded playlist "${params.playlist}" and started playback.` }],
            details: { provider, playlist: params.playlist, result: r },
          };
        }

        if (params.query) {
          const result = call("provider.search", { provider, query: params.query, offset: 0, limit: 20 });
          const tracks = extractTracks(result);
          if (tracks.length === 0) {
            return {
              isError: true,
              content: [{ type: "text", text: `No results found for "${params.query}".` }],
            };
          }
          const index = params.index ?? 0;
          const track = tracks[index];
          if (!track) {
            return {
              isError: true,
              content: [{ type: "text", text: `Index ${index} out of range (${tracks.length} results).` }],
            };
          }
          const r = call("track.play", { track, if_revision: 0 });
          const title = (track as any)?.title ?? (track as any)?.name ?? `result ${index}`;
          return {
            content: [{ type: "text", text: `Now playing: ${title} (index ${index}).` }],
            details: { provider, query: params.query, index, track, result: r },
          };
        }

        // No query/playlist -> resume
        call("play", {});
        return {
          content: [{ type: "text", text: "Resumed playback." }],
          details: { action: "play" },
        };
      } catch (e: any) {
        return { isError: true, content: [{ type: "text", text: `Play failed: ${e.message}` }] };
      }
    },
  });

  pi.registerTool({
    name: "cliamp_control",
    description: "Control cliamp playback: play, pause, toggle (play/pause), next, prev (previous), or stop. To change volume, use action='volume' with either 'value' (absolute dB) or 'adjust' (relative delta). Do NOT combine volume with other playback actions.",
    parameters: ControlParams,
    async execute(_id, params) {
      try {
        // Volume is handled separately and never combined with playback actions.
        if (params.action === "volume") {
          if (params.adjust != null) {
            const r = call("volume.adjust", { value: params.adjust });
            const vol = (r as any)?.volume ?? params.adjust;
            return {
              content: [{ type: "text", text: `Volume adjusted by ${params.adjust > 0 ? "+" : ""}${params.adjust} dB (now ${vol} dB).` }],
              details: { action: "volume", adjust: params.adjust, volume: vol },
            };
          }
          if (params.value != null) {
            const r = call("volume", { value: params.value });
            return {
              content: [{ type: "text", text: `Volume set to ${params.value} dB.` }],
              details: { action: "volume", value: params.value, result: r },
            };
          }
          return {
            isError: true,
            content: [{ type: "text", text: "For volume, provide 'value' (absolute dB) or 'adjust' (relative delta)." }],
          };
        }

        const op =
          params.action === "toggle"
            ? "toggle"
            : params.action === "next"
              ? "next"
              : params.action === "prev"
                ? "prev"
                : params.action === "stop"
                  ? "stop"
                  : params.action === "pause"
                    ? "pause"
                    : "play";
        call(op, {});
        return {
          content: [{ type: "text", text: `Done: ${params.action}` }],
          details: { action: params.action },
        };
      } catch (e: any) {
        return { isError: true, content: [{ type: "text", text: `Control failed: ${e.message}` }] };
      }
    },
  });

  pi.registerTool({
    name: "cliamp_status",
    description: "Get the current cliamp playback status (what's playing, position, volume, etc.).",
    parameters: Type.Object({}),
    async execute() {
      try {
        const s = status();
        return {
          content: [{ type: "text", text: fmt(s) }],
          details: { status: s },
        };
      } catch (e: any) {
        return { isError: true, content: [{ type: "text", text: `Status failed: ${e.message}` }] };
      }
    },
  });

  pi.registerTool({
    name: "cliamp_playlists",
    description: `List playlists from a provider (default ${DEFAULT_PROVIDER}). Use this when the user asks to see recommended or personal playlists.`,
    parameters: Type.Object({
      provider: Type.Optional(Type.String({ description: `Provider name, defaults to ${DEFAULT_PROVIDER}` })),
    }),
    async execute(_id, params) {
      const provider = params.provider ?? DEFAULT_PROVIDER;
      try {
        const result = call("provider.playlists", { provider, offset: 0, limit: 50 });
        return {
          content: [{ type: "text", text: fmt(result) }],
          details: { provider, result },
        };
      } catch (e: any) {
        return { isError: true, content: [{ type: "text", text: `Listing playlists failed: ${e.message}` }] };
      }
    },
  });

  // -------------------------------------------------------------------
  // /cliamp command (stateful: remembers last search results)
  // -------------------------------------------------------------------
  let lastSearch: { query: string; tracks: any[] } | null = null;

  pi.registerCommand("cliamp", {
    description: "Control cliamp music player (search, play, pause, next, volume, playlists)",
    async handler(args) {
      const parts = args.trim().split(/\s+/).filter(Boolean);
      const sub = parts[0]?.toLowerCase();

      const help = () =>
        "Usage:\n" +
        "  /cliamp search <query>        search YT Music (results numbered)\n" +
        "  /cliamp play [n]              play result #n (default: first / resume)\n" +
        "  /cliamp pause                 pause\n" +
        "  /cliamp toggle                play/pause\n" +
        "  /cliamp next | prev | stop\n" +
        "  /cliamp volume <dB>           set volume (-30 to +6)\n" +
        "  /cliamp volume +<dB>/<dB>      raise/lower relative (e.g. +2, -3)\n" +
        "  /cliamp status                current playback state\n" +
        "  /cliamp playlists             list provider playlists\n" +
        "  /cliamp playlist <name>       load a playlist";

      try {
        ensureDaemon();

        switch (sub) {
          case "search": {
            const query = parts.slice(1).join(" ");
            if (!query) return help();
            const result = call("provider.search", { provider: DEFAULT_PROVIDER, query, offset: 0, limit: 10 });
            const tracks = extractTracks(result);
            lastSearch = { query, tracks };
            if (tracks.length === 0) {
              return `No results for "${query}".`;
            }
            return (
              `Results for "${query}":\n` +
              tracks
                .slice(0, 10)
                .map((t: any, i: number) => {
                  const title = t?.title ?? t?.name ?? `#${i}`;
                  const artist = t?.artist ?? "";
                  const dur = t?.duration_secs ? ` (${Math.round(t.duration_secs / 60)}m${String(t.duration_secs % 60).padStart(2, "0")}s)` : "";
                  return `  ${i + 1}. ${title}${artist ? ` — ${artist}` : ""}${dur}`;
                })
                .join("\n") +
              `\n\nUse /cliamp play <n> to play one of these.`
            );
          }
          case "play": {
            const nArg = parts[1];
            if (nArg != null && /^\d+$/.test(nArg)) {
              const n = Number(nArg) - 1;
              if (!lastSearch || n < 0 || n >= lastSearch.tracks.length) {
                return lastSearch
                  ? `Invalid result number. Run /cliamp search first, then pick 1-${lastSearch.tracks.length}.`
                  : "No search results yet. Run /cliamp search <query> first.";
              }
              const track = lastSearch.tracks[n];
              call("track.play", { track, if_revision: 0 });
              const title = track?.title ?? track?.name ?? `result ${n + 1}`;
              return `Now playing: ${title} (result ${n + 1}).`;
            }
            // No number -> resume current playback
            call("play", {});
            return "Resumed playback.";
          }
          case "pause":
            call("pause", {});
            return "Paused.";
          case "toggle":
            call("toggle", {});
            return "Toggled playback.";
          case "next":
            call("next", {});
            return "Next track.";
          case "prev":
            call("prev", {});
            return "Previous track.";
          case "stop":
            call("stop", {});
            return "Stopped.";
          case "volume": {
            const vArg = parts[1];
            if (vArg == null) return "Usage: /cliamp volume <dB>  (absolute) or /cliamp volume +<dB> / -<dB> (relative)";
            const isRelative = /^[+-]/.test(vArg);
            const v = Number(vArg);
            if (Number.isNaN(v)) return "Usage: /cliamp volume <dB>  (e.g. 5, +2, -3)";
            if (isRelative) {
              const r = call("volume.adjust", { value: v });
              const vol = (r as any)?.volume ?? v;
              return `Volume adjusted by ${v > 0 ? "+" : ""}${v} dB (now ${vol} dB).`;
            }
            call("volume", { value: v });
            return `Volume set to ${v} dB.`;
          }
          case "status":
            return fmt(status());
          case "playlists":
            return fmt(call("provider.playlists", { provider: DEFAULT_PROVIDER, offset: 0, limit: 50 }));
          case "playlist": {
            const name = parts.slice(1).join(" ");
            if (!name) return "Usage: /cliamp playlist <name>";
            call("provider.load", { provider: DEFAULT_PROVIDER, playlist: name });
            call("play", {});
            return `Loaded playlist "${name}" and started playback.`;
          }
          default:
            return help();
        }
      } catch (e: any) {
        return `cliamp error: ${e.message}`;
      }
    },
  });

  // Global shortcuts for playback control (work while typing in the editor).
  pi.registerShortcut(Key.ctrlAlt("space"), {
    description: "cliamp play/pause",
    handler: async () => {
      try { call("toggle", {}); } catch {}
    },
  });
  pi.registerShortcut(Key.ctrlAlt("right"), {
    description: "cliamp next track",
    handler: async () => {
      try { call("next", {}); } catch {}
    },
  });
  pi.registerShortcut(Key.ctrlAlt("left"), {
    description: "cliamp previous track",
    handler: async () => {
      try { call("prev", {}); } catch {}
    },
  });
}
