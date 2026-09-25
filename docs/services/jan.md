# Jan (Desktop LLM — Tauri v0.8 + llama.cpp)

Runbook for the Jan AI desktop app on evo-x2. Set up live 2026-09-06.

## Architecture

| Piece       | What                                                                                                                                                                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| App         | nixpkgs `jan` 0.8.4 (HM `home.nix` packages) — Tauri app in an FHS bubblewrap (`Jan-0.8.4-fhsenv-rootfs`), so its dynamically-linked engine children run without nix-ld                                                                                      |
| Data folder | `/data/ai/models/jan` (via `data_folder` in `~/.config/Jan/settings.json` AND `~/.local/share/Jan/settings.json`; the default path `~/.local/share/Jan/data` is a symlink to it — managed by `activation.jan-data-link` in `platforms/nixos/users/home.nix`) |
| Models      | `<data>/llamacpp/models/` — 92G GGUF tree (gemma-4 heretic variants, qwen3.6, BAGEL, …) MOVED from `/data/llamacpp-models` on 2026-09-06; a compat symlink keeps the old path working                                                                        |
| Engine      | Jan-managed llama.cpp downloads at `<data>/llamacpp/backends/<bNNNN>/<backend>/` — currently `b9967` + `linux-vulkan-common_cpus-x64`; auto-update is ON (Jan prunes superseded backend dirs itself)                                                         |
| GPU         | Vulkan → RADV STRIX_HALO; ~82GB device memory reported (GTT-first memory model — see AGENTS GPU section). Verify with `grep -c libggml-vulkan /proc/$(pgrep -x llama-server                                                                                  |
| Serving     | Router mode: one `llama-server --models-preset <data>/llamacpp/router.preset.ini --models-max 2 --no-ui` on an EPHEMERAL loopback port (57385, 56883, …) — Jan owns the port; nothing else may bind or monitor it                                            |

## Critical doctrine

- **Jan REJECTS any model path outside its data folder** (`list: skipping model … outside of Jan data folder`). Models MUST live at `<data>/llamacpp/models/`. Never point that dir (or the data folder) at a symlink whose REAL target lies outside — Jan canonicalizes and refuses. This silently emptied the model list on 2026-09-06 (92G invisible) — the entire reason for the /data migration.
- **Data on /data, not the NVMe root.** The NVMe is 90%+ full; a single model download can wedge the box (SLC/ENOSPC class). `services.ai-models.paths.jan` owns the dir (tmpfiles, `lars:users`).
- **Do NOT run the raw upstream/AppImage `jan` binary** — on NixOS it dies on stub-ld. The nixpkgs FHS wrapper is the supported path. `programs.nix-ld` (enabled 2026-09-06 with vulkan-loader) covers foreign dynamic binaries generically.
- **Engine auto-update downloads ~90MB per new llama.cpp release** into `<data>/llamacpp/backends/` — on /data, fine. Old b8671–b9244 empty shells were rmdir'd 2026-09-06.

## Verification

```bash
# engine alive + on Vulkan (Jan must be running)
pgrep -ax llama-server | grep router.preset
grep -c libggml-vulkan /proc/$(pgrep -x llama-server | tail -1)/maps   # >= 1
# models visible: app.log must have NO "outside of Jan data folder" lines
grep -c 'outside of Jan data folder' /data/ai/models/jan/logs/app.log
# data folder wiring
readlink ~/.local/share/Jan/data    # /data/ai/models/jan
cat ~/.config/Jan/settings.json     # {"data_folder":"/data/ai/models/jan"}
```

## Troubleshooting

- **Model list empty / "outside of Jan data folder" in `~/.local/share/Jan/data/logs/app.log`** — a model or the models dir escaped the data folder (symlink to outside, or models moved). Put them back under `/data/ai/models/jan/llamacpp/models/`.
- **`jan` command: "Could not start dynamically linked executable"** — something shadowed the nixpkgs wrapper on PATH (the activation removes a stray plain `~/.local/bin/jan`; check for new copies). Launch via the HM profile binary.
- **Engine fails after an auto-update** — pin back in Jan UI: Settings → Llama.cpp → Version/Backend (dropdown shows installed + remote releases), or delete `<data>/llamacpp/backends/<bad>` and relaunch.
- **AMD GPU offload** — model settings: ngl > 0 (e.g. 31), flash_attn auto. Jan's hardware panel must show "AMD Radeon 8060S Graphics (RADV STRIX_HALO)".
- **RESOLVED (2026-09-12)**: the corrupt `/data/models/llm/gemma-4-31b-abliterated-Q8_0.gguf` (header EIO, os error 5; /data bounded-damage class) was trashed to `/data/.Trash-1000` — extents free as btrbk /data snapshots expire. Do NOT import any re-download without re-validating its GGUF header first. Repair procedure for the NEXT victim: the recipe below.
- **Disk-space cleanup of the jan tree (92G, near-all `llamacpp/`)** — `/data` is snapshotted nightly (14d 4w), so `rm` of a model or an auto-pruned engine backend frees its extents only after the /data snapshot window (~4-5 weeks worst case); `trash` first parks the bytes in `/data/.Trash-1000` until emptied (same pin clock starts on empty). Deleting for space: prefer unsnapshotted paths (`/nix`, `~/.cache`) or plan around the window — full table in AGENTS.md "Snapshot-pinning doctrine" (BTRFS section).

## Single-victim /data repair recipe

For ANY newly-discovered EIO-corrupt file on /data (the 2026-09-12 gemma GGUF class): three steps, ONE commit. The 2026-09-12 fix updated only 2 of 3 doc surfaces and AGENTS.md went stale within hours, redirecting a future agent at a nonexistent file — this checklist exists so that cannot recur.

1. **Trash, same filesystem.** `trash <file>` — `/data` and `/data/.Trash-1000` share the btrfs toplevel, so the move is a RENAME: zero data copy, no NVMe write. Confirm with `stat` (old path ENOENT, trash path present with the original size/mtime). The trashed copy is evidence + the step-2 re-verify target, not a space measure — `trash` on /data frees NOTHING until the /data snapshot window expires (AGENTS.md "Snapshot-pinning doctrine", BTRFS section).
2. **Re-verify the corruption on the TRASHED copy** — proves the damaged file is the one discarded and nothing healthy left: `dd if=<trashed-path> bs=4k count=1` — damaged ⇒ `Input/output error` (os error 5), exit 1, `0+0 records in`; healthy ⇒ copies exactly 4096 bytes (re-verified live 2026-09-25 on a healthy jan GGUF: `1+0 records in/out, 4096 bytes copied`, rc 0). Run it UNMASKED: never `dd … | tail` — the filter hides both the error text and dd's exit code (pipeline-masking trap; the only surviving tell is `0+0 records in`).
3. **Atomic doc sweep.** `grep -rn "<filename>" --include='*.md'` over the repo, then update EVERY live surface that mentions the file — the TODO row/library entry, the owning service runbook, and AGENTS.md — in ONE commit. `docs/status/**` reports are point-in-time archives: never edit them. If a re-download follows, record the source URL + expected size in the runbook FIRST (no URL guessing), and validate the new file's GGUF header (`dd bs=4k count=1` must copy 4096 bytes) BEFORE Jan import.
