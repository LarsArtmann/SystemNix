# Pre-Deploy Unblock: Evidence Pull, `boot-metrics` 127, and the `bless-boot` / Mirror Race

**Session:** 2026-10-18 03:32 → 04:05 CEST
**Trigger:** owner pasted a `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` run that aborted at pre-deploy §15 (`101 passed, 6 warnings, 1 failed`) and asked for it to be worked through to a green end state.
**Predecessors:** [2026-10-18_00-39 boot-order/bootcounting counter flow](2026-10-18_00-39_boot-order-bootcounting-mirror-counter-flow.md) (the [watch] row this session answers) · [2026-10-18_00-58 boot-ee085387 thermal-trip diagnosis](2026-10-18_00-58_boot-ee085387-thermal-trip-crash-diagnosis-selfreview.md) (the previous crash of the same night)

## TL;DR

§15 was the ONLY blocker: the exposed boot `daecca67` had no committed evidence, so it was pulled canonically and committed, and the full battery now reads **104 passed / 6 warnings / 0 failed — "✅ Pre-deploy checks passed — safe to deploy"** (the stale `signoz_logs_pipeline_stale` §10 loan entry is retired as well, so §10 is 0-warning).

Verification surfaced two real defects. (1) `boot-metrics-emit` exits **127** on exactly the unfinished-boot class its new `transaction_open` gauge was built for — the helper that computes the age is defined BELOW the retry loop that calls it; fixed by hoisting, and proven both ways with an ad-hoc fixture. (2) `systemd-bless-boot` fails on EVERY boot: it reads `/boot` (the non-booted QLC ESP) 150 ms after `boot-mirror-sync` starts and 19 s before that sync reverse-propagates the loader's counter rename into `/boot` — queued with sub-second evidence and a proposed ordering fix, deliberately NOT patched (unverifiable without a reboot, and the box was crash-churning).

Context that must not get lost: `daecca67` was the night's THIRD freeze-class boot end (hardware watchdog reset, no shutdown sequence in the journal), the storm was still live during this session (guard trips `#3491`–`#3493`), and the bless failure means the loader's tries counter keeps decrementing unblessed (2 boots left before gen 929 is marked bad).

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| §15 blocked cleared: `daecca67` evidence pulled canonically (406 lines, canonical sections + census) | `docs/status/tasks/2026-10-18_01-32_boot-daecca67-evidence-pull.md` (committed `13d65f6b7`); gate re-run: `pre-vacuum gate: pass`, all 10 exposed boots `guarded` |
| Full pre-deploy battery re-run green | `104 passed, 6 warnings, 0 failed` — the 6 are the documented classes (§1 benign flake-check, §6 live failed units, §8 1 stale sandbox, §12 ×3 not-yet-built ExecStart: `boot-metrics-emit` (mine, rebuilt on deploy), `network-local-commands`, `pocket-id-provision`) |
| `boot-metrics-emit` 127 fix (helper hoisted above the retry loop that calls it) | `modules/nixos/services/boot-metrics.nix` (committed `534b37b26`); rendered script `bash -n` clean; fixture below |
| Fixture proving the fix AND reproducing the bug | `~/.cache/bootmetrics/run-fixture.sh`: refusing `systemd-analyze` stub + `systemctl` stub + scratch textfile dir → `transaction_open 1`, `scrape_errors 1`, exit 0; the same script with the helper stripped → exit **127**, `open_age_secs: command not found`, no textfile |
| §10 stale loan retired | `scripts/pre-deploy-check.sh` `KNOWN_NEW_METRICS=""` (committed `bb2569d0b`); §10-only run: `63 passed, 0 warnings, 0 failed` |
| [watch] "first reboot under boot counting" answered from live state | `docs/todo/stability.md` + `TODO_LIST.md` rows (committed `952cd4245`, `9f979c8cf`) |
| New follow-up rows on both surfaces (bless race, fixture leg, `daecca67` autopsy) | same two files, cross-linked |
| AGENTS.md live-probe rule gained the `journalctl -b` full-boot-id trap | `AGENTS.md` (committed `9f979c8cf`) |
| CHANGELOG entry for the whole session | `CHANGELOG.md` (committed `f4b61d4a5`) |

## b) VERIFIED LIVE (all read-only probes; the box is the production host)

| Claim | Evidence |
| --- | --- |
| Boot source still the Samsung mirror | `BootOrder` starts `000C`, `BootCurrent` `000C`, `LoaderDevicePartUUID` `023F66C0-3677-4C15-9CE7-F9E1F1457EDB` = `nvme0n1p1` = `/boot-mirror` |
| Loader counter rename is live | `LoaderBootCountPath` = `\loader\entries\nixos-e978cd89…+2-1.conf` |
| Sync reverse-propagation's first live branch = progress-rename, and sync green | `boot-mirror-sync: OK — 50 entries, counters[…e978cd89…+2-1.conf], 249M mirrored`; the `/boot` twin converged to the mirror's `+2-1` |
| `systemd-bless-boot` fails on a race, sub-second | `03:06:18.169` bless starts → `.242` sync starts → `.319` bless dies `Can't find boot counter source file for '/loader/entries/nixos-e978cd89…fdc943.conf'` → `03:06:37.407` sync finishes |
| bless operates on `/boot`, not the ESP `LoaderDevicePartUUID` names | non-root `/nix/store/…/systemd-bless-boot status` → `Failed to open file system "/dev/nvme1n1p7"` (= `/boot`); the booted ESP is `nvme0n1p1` |
| bless pull-in (fix blast radius) | `/run/systemd/generator.early/basic.target.wants/systemd-bless-boot.service`, FragmentPath `/etc/systemd/system/systemd-bless-boot.service`, `UnitFileState enabled-runtime`, `After=boot-complete.target` |
| `daecca67` ended by hardware watchdog, not a clean shutdown | journal tail ends mid-traffic (`tq` WARN `03:03:38`), ZERO `systemd-shutdown` / `Reached target Power-Off\|Reboot` / `Stopping …target` lines; the next boot's kernel: `x86/amd: Previous system reset reason [0x02000800]: hardware watchdog timer expired` |
| Storm state during/after the session | 15 zone-6 trips inside `daecca67` (`#3477`→`#3490`), trips `#3491`–`#3493` in the current boot (last `03:31:54`); at 04:00: IO PSI some avg10 24%, CPU PSI some avg10 95%, load 12, **no trip in the previous 20 min**, 0 D-state tasks, top process writer ~0.6 MB/s (writeback-class load) |

## c) FINDINGS

1. **`boot-metrics-emit` 127 — the gauge for hung boots was dead on hung boots.** `open_age_secs` was defined after the retry loop (line 154 call vs line 202 definition); `set -e` turned the 127 into a unit failure, so `transaction_open` was never written when `systemd-analyze` refused. Confirmed harmless-looking on a healthy boot (the loop body never runs) — which is why it shipped. Post-boot re-emits succeeded (the unit is absent from the §6 failed list now, only systemd-bless-boot remains).
2. **`systemd-bless-boot` fails every boot — a mirror-ordering bug, not a systemd quirk.** The design already says the sync "reverse-propagat[es] loader-owned state BEFORE the forward mirror"; bless simply runs concurrently with it. Consequence: the entry is never blessed, so the loader's counter (tries 3) keeps decrementing on every boot and the generation is marked bad at zero — a surprise rollback to the previous generation. Manual mitigation exists but only converges across a following sync.
3. **`daecca67`: third freeze-class end in 2h23m** (00:40:44 firmware power cut → `daecca67` WDT reset `03:03:38`), with a never-exiting thermal ENTER (`01:05:50`, 98 °C) and the guard's own "disk saturated while memory looks healthy" trip text (`MemAvailable=32.9%`, disk 99.3% busy).
4. **`journalctl -b` rejects an 8-char boot-id prefix** (`Failed to add match '<id>': Invalid argument`) and returns an EMPTY dump — a silent phantom-green source; `scripts/boot-evidence-pull.sh` resolves prefixes itself, ad-hoc greps do not.

## e) BOTCHED / MISSED (self-critique)

- **I concluded from an empty read once.** My first `daecca67` probes used `journalctl -b daecca67` (invalid prefix) and returned nothing; I initially read "0 shutdown markers" out of that emptiness. The conclusion survived a full-id re-run (the authoritative check is the missing shutdown SEQUENCE, not a grep count), but the evidence that produced it was worthless — the trap is now a rule in AGENTS.md.
- **A committed-looking edit was not on disk.** The first CHANGELOG.md insertion reported success, yet the file's mtime stayed at 02:23 and the content was absent (a parallel session rewriting the same file). Re-applied, re-verified, committed immediately after. Two files (AGENTS.md, CHANGELOG.md) still show the multi-session race pattern; every claim above was re-verified against the COMMITTED bytes, not against my memory of the edit.
- **I deliberately did not fix the defect I found.** The bless ordering fix is one line, but it is boot tooling whose verification requires a reboot, there is no fixture for the counter flow, and the box had just frozen twice — shipping it blind is the failure mode the 2026-10-17 self-review already paid for. Queued with the evidence instead; the owner can green-light it with the next deliberate reboot.
- **`§6` grew from 2 to 5 failed units during the session** (`bank-sync-paperless`, `ci-watchdog`, `inboxclean-sync`, `service-health-check`, `systemd-bless-boot`) — not investigated here (storm-casualty class outside this session's scope); the storm window is the first thing to check before treating them as regressions.

## f) FOLLOW-UPS (harvested at authoring time)

| Item | Surface |
| --- | --- |
| `systemd-bless-boot` ordering fix + its verification step | `TODO_LIST.md` [ready] row + `docs/todo/stability.md` (this report is the Source) |
| `CASES=bootmetrics` fixture/negative leg for the retry path | `TODO_LIST.md` [ready] row + library |
| `daecca67` freeze autopsy | `docs/todo/stability.md` [ready] row (deliberately NOT queued: the open crash-family rows — thermal shed-load escalation, restore hysteresis, full-disk-reader attribution, admission hole — own the dispatch) |

## g) OWNER DECISIONS / ACTIONS

1. **Deploy go-ahead** — the battery is green; the ENTRY gates will still demand `DEPLOY_FORCE_PRESSURE=1` while IO PSI ≥ 20% AND disk busy ≥ 20%, and the guard-trip leg self-clears 60 min after the last trip (`03:31:54`, so ≈`04:32`).
2. **Optional immediate mitigation for the counter exposure** (do it only AFTER a boot's sync has landed): `sudo systemd-bless-boot good` strips `/boot`'s `+2-1`; the next `boot-mirror-sync` forward-mirrors the blessed name and the loader stops counting that entry.
3. **Agent-blocked cleanup:** `sudo systemctl start nix-build-cleanup.service` for the one stale build sandbox (§8 warning).
