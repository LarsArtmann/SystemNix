# 2026-11-22 15:15 — owner `nh os switch` exit-4: unanchored runtime repaired (gen-1023), boot-mirror path-watch miss found

**Session type:** ad-hoc fix (owner pasted a failed `nh os switch . -v --keep-going` transcript).
**Pre-read done:** `ls -t docs/status/` (14:54 mic-monitor closeout was newest — no armed executor on this
incident), deploy logs (07:41 + 08:11 both entry-refused code=12), live anchor/PSI/git pinned before acting.

---

## a) What the owner hit

- 14:06 `nh os switch` (run DIRECTLY, not `nix run .#deploy` — bypassed deploy.sh's pressure gate on an
  io-storm day where both morning deploy attempts had been refused code=12 at entry).
- Diff: kith-crm `6a43482f → 9a5b155b` (flake.lock float, committed in `9e917e317`) + the boot-metrics-emit
  wiring + the (still-uncommitted) monitor365 `//`→`mkMerge` refactor riding the working tree.
- Build fine (52s), activation ran: units stopped/started/restarted, `/run/current-system` flipped to
  `4b1h1ymh…` — then **`switch-to-configuration` exited 4**: `system-health-metrics.service` (2-min TIMER
  oneshot, NOT in the transaction) failed mid-window, and stc counts every failed unit at settle.
  "the new generation will not be added to the bootloader" + no profile bump.
- Net state at session start: **runtime fully on the new toplevel, UNANCHORED** — profile stopped at
  system-1022 (`yxpz58jx…`), boot entries without gen-1023, mirror stale. A reboot/crash would have silently
  reverted (and the box ran memory-PSI ~48% + load 82 all afternoon — freeze risk was live).

## b) Root cause (verified, not inferred)

- `system-health-metrics` journal scans (pocket-id busy / papdashboard ingest / memcg oom) run under
  `timeout` (50s budget) and ALL timed out (`status 124`) in the 14:11 storm window — the collector reads
  multi-GB journals; concurrent load was a foreign `nix flake check --all-systems` (8.2 GB RSS, 145% CPU),
  nixbld Go builds, a drive-paperless VM test, cqrs tests, two llama servers, clickhouse (io PSI some
  avg10 23-43%, load 82).
- The collector exits 1 on any incomplete sweep ("partial file published, exiting non-zero") — deliberate
  fail-visible design, but it makes an unrelated timer unit able to VETO an activation.
- Same partial sweeps flipped gatus "PapDashboard Ingest" RED at 14:12/14:30 (ingest freshness metric stale
  + brief connection-refused) — self-healed once clean sweeps resumed 14:55; 8088 listener answering, gatus
  "Failed to send" count 0 since 15:00, papdashboard serving 200s throughout the tail.

## c) Repair (executed + verified)

1. **Anchor** (the sanctioned UNANCHORED procedure, avoiding a re-activation race):
   `sudo nix build --no-link --profile /nix/var/nix/profiles/system /nix/store/4b1h1ymh…` → PROFILE-SET OK
   (system-1023-link → `4b1h1ymh…`), then `sudo …/bin/switch-to-configuration boot` (entries installed,
   loader binaries same-version-skipped).
2. **pre-reboot-check**: 16 pass / 5 warn / **1 FAIL — "mirror tree DIFFERS from /boot" (REBOOT BLOCKED)**.
   Root finding: `boot-mirror-sync.path` was ActiveState=active but its last fire was 01:03:59 — it missed
   BOTH deploy #2's 01:46 entry install AND my 15:00 `stc boot` (13h stale mirror). The 2026-10-17
   "raw-stc class CLOSED" doctrine is re-opened as best-effort. Healed via
   `sudo systemctl restart boot-mirror-sync` → "OK — 50 entries, 403M mirrored" (gen-1023 entry
   `2abfc8b1…+3.conf` in the counters list).
3. **Half-applied units verified healthy**: crm-server on the new `9a5b155b` build serving 200s,
   monitor365-server 200s, boot-metrics-emit finished clean 14:12:18, summit-planner /healthz 200/60s,
   paperless-gpt 200s (DisallowedHost stays 0).
4. **Post-repair state**: `readlink /run/current-system` == `system-1023-link` == `4b1h1ymh…`; anchor clean.
   pre-reboot-check residual warnings are pre-existing advisories (failed forgejo-github-sync +
   inboxclean-sync with changed unit files — next deploy exit-4 class, deploy.sh reset-failed recovers;
   19-entry smoke baseline).

## d) Findings & fixes shipped this session

- **Live identity.db was 0644, not the designed 0600** (handoff follow-up answered: exists YES — owner
  registered ~00:46, WAL 370K, backup artifact proves it — mode NO). Fixed twice: live files chmodded
  0600 by hand (identity.db/-shm/-wal), and `UMask = "0077"` added to the summit-planner unit
  (modules/nixos/services/summit-planner.nix; eval-verified `"0077"`) so every (re)creation is private.
  Deploy-gated; the backup leg already wrote 0600 artifacts by design.
- **First backup artifacts CONFIRMED** (pipeline row 1172's backup half): `/mnt/pool/backups/summit-planner/
  summit-planner-2026-11-22.db` 323K/0644 + `identity-2026-11-22.db` 200K/0600, from the 04:01 run of the
  03:55 timer. Gatus "Backup Freshness: summit-planner" failure-silent since (journal-cadence-class
  evidence; API token-gated).
- **systemd.md**: new activation-section bullet (timer-unit veto class + the no-reactivation repair recipe)
  and a boot-mirror-section bullet (path-watch missed fires). **AGENTS.md**: fd-3 redirection trap added to
  the shell-traps bullet; missed-fire caveat added to the boot-mirror doctrine paragraph.

## e) Left open (deliberately)

- **Calm-box battery re-run** (pipeline.md row 1172, battery half): box was NOT calm (load 82, io PSI
  43% avg10 at 15:05) — running post-deploy-check.sh now would poison a second baseline. Row updated with
  the verified backup half; battery half stays queued for a sub-30% window.
- **monitor365.nix WIP (`//`→mkMerge refactor) is UNCOMMITTED and IS inside gen-1023** (built from the
  working tree) — the owning session must commit it; gen-1023 is otherwise tree-reproducible.
- **No deploy fired by this session**: runtime == anchored gen-1023 == consistent; the UMask fix + monitor365
  WIP ride the next calm deploy naturally.
- **§g questions from the 02:50 report remain unanswered** (re-surfaced below).

## f) Self-harvest (all landed at authoring time)

- TODO_LIST.md + docs/todo/storage.md: boot-mirror-sync.path missed-fire backstop row.
- TODO_LIST.md + docs/todo/monitoring.md: system-health-metrics cannot-veto-activation row.
- docs/agents/systemd.md (2 bullets), AGENTS.md (2 gotcha writes) — done in-session, not queued.
- pipeline.md row 1172 updated (backup half verified) — full-line edit, queue/library in sync.

## g) Re-surfaced owner questions (from docs/status/2026-11-22_02-50_…md §g)

1. **Adopt-in-place confirm** — you registered (identity data live + backed up); confirm the dev DB
   (open-source-summit-japan-2026 event et al.) stays as prod data.
2. **Baseline restore vs natural re-baseline** — restore `~/.cache/lockfloat/baseline-pre-resume2-20261121.txt`
   over the storm-poisoned smoke-fail baseline, or let the queued calm-box re-run re-baseline naturally?
3. **Push arrangement** — master is now further ahead of origin across sessions; push window once the CI
   bundle key lands, or local-only by policy?

---

**Working notes:** sudo live in this session's shells (probe `sudo -n true` rc=0 — the NNP-exception class);
typed `sudo systemctl restart` ALSO passed the guard here (session-class dependent — do not assume).
`ls /boot/loader/entries` unprivileged = Permission denied (ESP root-only) — use sudo. The collector's
clean-sweep signature for retry-readiness: `journalctl -u system-health-metrics` showing "Deactivated
successfully" with no "WARN incomplete sweep". Post-repair anchor evidence: profile listing by NUMBER
(system-1023-link), not mtime.

---

## Closeout addendum (15:45) — commit ride + reconciliation evidence

- **Commit attribution:** the UMask module edit did NOT land under its own commit. The first attempt's
  pre-commit battery aborted on a transient "store path …-flake-input-pin-audit/sample-flake.nix does not
  exist" (a lazy source-copy race — a standalone `nix eval` of the same check attr passed seconds later),
  which left the file STAGED in the shared index; a parallel session's commit `1f1517f8e` ("fix(services):
  stop ioTier precedence loss and world-readable identity DB", 15:35:10) then absorbed it and described it
  accurately in its body. No amend (foreign, properly-messaged HEAD — land-as-is). The monitor365
  `//`→mkMerge WIP named in §e is committed in that same commit, so that item is closed too. New policy
  clause (5) added to CONTRIBUTING's daemon-race paragraph.
- **Reconciliation row CLOSED** (docs/todo/services.md + its TODO_LIST pair): `nix store diff-closures`
  gen-1022→gen-1023 = one change (kith-crm 6a43482f→9a5b155b + its `source` path), zero removals; 910/910
  unit files identical (`comm` on captured listings — a first `diff <(…)` attempt was discarded as an
  UNVALIDATED pipeline that happened to agree); gen-1021→gen-1023 adds only the atlas package swap that
  deploy #2 itself introduced. Live summit-planner exe `5abv8snw…` == gen-1023 unit ExecStart; 53
  seed-skip fingerprint lines today.
- **Anchor re-verified 15:40:** `/run/current-system` == `system-1023-link` == `4b1h1ymh…`; no deploy since
  (newest deploy log still 08:11); identity files still 0600.

---

## Correction addendum (15:55) — §b "self-healed" was premature; reboot gate closed; thermal note

- **Correction to §b:** the ingest chain did NOT stay healed. 15:00→15:49 the collector logged **13 incomplete
  vs 11 clean sweeps**, and "PapDashboard Ingest" TRIGGERED a third time at 15:30:52 (after 14:12 and 14:30).
  The "Failed to send" lines since 15:00 are client TIMEOUTS on `POST localhost:8088/api/ingest` (15:05:38,
  15:08:02, 15:10:16), not refusals. Mechanism (gatus-config.nix:1651-1656): the check conditions on the
  collector's OWN `system_papdashboard_ingest_scrape_errors 0` line — every incomplete sweep flips it to 1
  and the endpoint goes red until the next clean sweep. The ingest path itself is healthy: 200s in 10-97 ms
  at 15:48-15:49, `ok_1h 34 / errors_1h 3`. Verdict: the MONITOR flaps on the storm; the dashboard does not
  fail. §b's "0 failed sends since 15:00" was true at 15:02 and false by 15:10.
- **Gate closed by the actual gate (re-run 15:50):** `nix run .#pre-reboot-check` → rc=0, "17 passed, 5
  warnings, 0 failed — SAFE TO REBOOT with notes above" (it said REBOOT BLOCKED on §11 at 15:01).
- **Stability note for the owner:** CPU Tctl read a sustained 98 °C at 15:52 (3 samples); the afternoon's
  alerts include `monitoring_cpu-thermal-alert`, `filesystem_i-o-stall-rate` and Memory Pressure. Load is
  the parallel sessions' builds/tests (foreign `nix flake check --all-systems`, Go builds, VM tests,
  buildflow) on top of a constantly busy bge-m3 embedding server (~60% CPU since 01:03) — the documented
  freeze class. Nothing was killed (foreign workloads). With gen-1023 anchored and the mirror synced, an
  unplanned watchdog reboot now boots the RUNNING generation instead of silently reverting.

---

## Addendum (16:05) — collateral findings from the failed-unit sweep

- **forgejo-github-sync has not succeeded since at least 2026-11-18** (journal census: 24/26/24/24/17 failed
  runs per day 11-18→11-22, zero "Finished" lines). Every run dies on ONE repo: `PATCH lars/nixpkgs failed
  (HTTP 500)` → `checked=486 patched=0 already-at-target=485 failed=1` → exit 1. The unit therefore sits
  permanently `failed`, which makes `service-health-check.service` exit 1 on every cycle (it lists the failed
  set) and would trip any activation outside deploy.sh. Evidence appended to the EXISTING row
  docs/todo/services.md "Re-interval N-strike de-escalation" (open since 2026-10-12) and its queue pair —
  not re-queued.
- The other members of the failed set at 15:49 were `inboxclean-sync` (exit 75 = deliberate temporary
  failure, retries on its timer), two transient `llama-vlm-cap@…` caption instances, and the user unit
  `nextd-refresh.service`. deploy.sh clears failed units before switching (scripts/deploy.sh:394,757), so
  the canonical path is protected; a direct `nh os switch` is not.
