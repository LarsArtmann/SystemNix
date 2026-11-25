# supplements-weekly-print

**Module:** `modules/nixos/services/supplements-weekly-print.nix` (`services.supplements-weekly-print`)
**Pipeline (single source of truth):** `tracking-papers/pkgs/print-supplements-weekly.nix` — flake app `print-supplements-weekly` in that repo (floating `master`→`main` input `tracking-papers`, locked at adoption 2026-11-25 @ `4651119a`).
**Enabled:** `platforms/nixos/system/configuration.nix` (evo-x2).
**Created:** 2026-11-25 — resolves tracking-papers TODO #2 (print mechanism, Option 2 systemd timer) and #5 (print-safe vendored as flake app).

## What it does

Every Monday 00:00 local (`OnCalendar = Mon *-*-* 00:00:00`, `Persistent = true`), a oneshot unit runs the tracking-papers pipeline end to end:

1. compute the current ISO week (`date +%-G`/`%-V`) — the week STARTING at fire time, deliberately not the generator's next-week default (at Mon 00:00 that would print W+2; a Persistent catch-up later in the week must print the RUNNING week);
2. generate with `-print -dry-run` (gray-flood size guard, 1.5 MiB ceiling);
3. print-safe **dry-run** — validates the full raster path with zero ink;
4. real print-safe — binary-threshold pipeline + raw USB queue (never plain `lpr`; color forbidden);
5. verify completion via `lpstat -W completed`, release held jobs for up to 600 s (asleep-printer mode);
6. append an outcome row to `~/projects/tracking-papers/docs/printer-log.md`;
7. prune staging editions older than 8 weeks.

Artifacts stage in `~/.local/state/tracking-papers/sheets/` — the repo's `sheets/` gallery stays human-curated on purpose (every dated edition there requires a conscious `gallery/catalog.go` line + tripwire bump; automation writing there would redden `nix flake check` weekly).

## Why (decision class)

Tracking-papers TODO #2 ("W\<nn+1\> sheet exists before Sunday") sat open since 2026-09: the mechanism brief (`tracking-papers/docs/planning/2026-10-04_print-mechanism-brief.md`) sketched a systemd timer and Lars picked automation 2026-11-24. The schedule lives here, the pipeline lives in tracking-papers (the print pipeline is that repo's product concern: generator, print-safe mirror, gray-flood incident record).

## Alerting

`onFailure = onFailureP0` (Discord direct). A 00:00 failure fires while nobody is at the desktop — a toast is guaranteed unseen; this is the 2026-10-12 toast-only lesson applied to a unit whose whole purpose is cadence guarantee.

## Safety rails

- **Dry-run before ink, always** — the unit cannot send a page that failed the gray-flood guard or the raster validation.
- **`harden {}` + `MemoryMax 512M` + `ReadWritePaths`** limited to the repo docs dir, the staging dir, and `~/.cache/fontconfig`; `HOME=%h` because WeasyPrint's fontconfig needs a home (systemd does not export it).
- **`TimeoutStartSec = 25min`** — generator + WeasyPrint + up to 600 s printer wait + up to 600 s release loop exceed the 5 min oneshot floor.
- **`User = primaryUser`** — CUPS USB access runs as the user; `after/wants cups.service`.
- **print-safe itself** re-validates the raster against its own header and retries up to 5× (the 2026-11-10 imagetoraster crash hardening); it records requested/validated/completed/failed into the print-log ledger best-effort (`PRINT_LOG_BIN` → PATH → `~/.local/bin/print-log`; absent ledger = logging skipped, printing unaffected).

## Knobs

- `services.supplements-weekly-print.onCalendar` — schedule override (default Monday 00:00).
- Pipeline env: `PRINT_SUPPLEMENTS_DRY_RUN=1` (no ink), `PRINT_SUPPLEMENTS_PRINTER`, `TRACKING_PAPERS_REPO`, `TRACKING_PAPERS_PRINTER_LOG`, `TRACKING_PAPERS_SHEETS_DIR` — see the app header in tracking-papers.

## Verification

- `systemctl list-timers supplements-weekly-print.timer` — next elapse Monday 00:00, `Persistent` shown in the rendered unit.
- Rehearsal without ink on the host: `PRINT_SUPPLEMENTS_DRY_RUN=1 nix run ~/projects/tracking-papers#print-supplements-weekly` — rc 0, W<current> detected, PDF < 1.5 MiB, MD row appended, no paper.
- First live fire: Monday 2026-11-30 00:00 — check `docs/printer-log.md` for the outcome row and the paper tray.
