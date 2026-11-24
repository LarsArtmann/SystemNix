# Polkit render FAIL = repro-harness false positive; leg scoped + tiered (2026-11-24 22:15)

**Trigger:** user-pasted `FAIL Desktop - polkit render: 4 QQC2 'module ... is not installed' abort(s) in last 24h (the 2026-08-18 polkit crash-loop class)` — the same leg that FAILed the 21:54 gen-1028 deploy smoke.

**One-line verdict:** the 4 counted journal lines came from a MANUAL repro harness (`~/.cache/polkit-fusion-repro`, run 2026-11-24 00:54:52, broken by design), NOT from the deployed stack — which is fully healthy. The leg now FAILs only on aborts inside the deployed polkit host units and WARNs (non-blocking) on everything else.

---

## §a Root cause + work FULLY DONE

### Root cause (journal forensics, live)

- All 4 counted lines: `qml[1652028/1652961/1652965]` loading `file:///home/lars/.cache/polkit-fusion-repro/polkit-kde-agent-1-6.7.4/qml/QuickAuthDialog.qml` → 3× `module "org.kde.polkitkde" is not installed` + 1× `module "fusion" is not installed`, all at `2026-11-24 00:54:52` (pre-switch, previous boot).
- The harness (`repro.sh` / `repro2.sh` / `qml-load.sh` + `agent2.log`) deliberately runs an UNWRAPPED store-path `polkit-kde-authentication-agent-1` with a scrubbed env — it reproduces the OLD crash class on purpose. Its `polkit_agent_listener_register_with_options` CRITICAL line shows a null-subject registration attempt that failed before touching the real slot (no harm to the live agent).
- wireplumber's `libcamera is not installed` lines matched the check's `--grep 'is not installed'` but not the `grep 'module'` filter → correctly not counted.
- **Deployed stack verified healthy:** `journalctl --user -u dms.service --since -48h --grep 'not installed'` → zero matches; `niri-flake-polkit.service` → no entries (disabled since 2026-10-04); the FAIL message carried ONLY the abort clause, so both Qt env legs passed.

### Parallel-session race (the session discipline paid off)

- The TODO tick (`TODO_LIST.md:3200`, authored ~21:5x by the "GLM-5.4 deploy session") claimed the leg already fixed observation-style — but at 22:0x the tree still carried the OLD text (my sed read proved it), and the fix landed on disk only at `22:06:40` (`stat`), uncommitted, bundled with an unrelated Attic-check removal in the same file. **Phantom-tick window ~10–15 min: the tick predated its own edit.**
- Protocol followed: mtime stability wait (~2 min quiet), fresh View of the region immediately before editing, additive edit on top of the other session's text (nothing of theirs reverted).

### What landed (my layer, `scripts/post-deploy-check.sh` polkit render leg)

1. FAIL trigger scoped to the DEPLOYED polkit host units: `journalctl --user -u dms.service -u niri-flake-polkit.service --since "-24 hours" --grep 'is not installed' | grep 'module'` — the actual 2026-08-18/2026-10-03 crash-loop class (both historical incidents were systemd user units).
2. Non-unit lines → separate `report_warn` (non-blocking): count + newest line when no unit aborts, so manual/repro QML runs stay observable but can never FAIL a deploy smoke again.
3. Observation-style reporting preserved from the other session's design (count + newest line with ISO timestamp + source path; no cause attribution, no fix prescription).
4. Intro comment updated to state the scoping rationale (names the 2026-11-24 false-FAIL).

### Verification (three paths, all executed)

- `bash -n` OK; `shellcheck -S warning` no findings (see §b/§d for the probe's own ambiguity).
- **Live** (extracted leg run against the real journal): `PASS Desktop - polkit dialog render sanity (…no QQC2 aborts in deployed polkit host units)` + `WARN Desktop - polkit render: 4 'module ... is not installed' journal line(s) OUTSIDE deployed polkit host units … newest: 2026-11-24T00:54:52+01:00 evo-x2 qml[1652965]: file:///home/lars/.cache/polkit-fusion-repro/…module "fusion" is not installed`.
- **Stub-negative** (fake journalctl on PATH): unit-abort case → FAIL naming the host units + newest line, plus WARN for the remainder; clean case → PASS, no WARN.

### Surface corrections (a claim must name its surfaces)

- `TODO_LIST.md:3200` + `docs/todo/pipeline.md:1037`: tick notes appended with the follow-up facts (scoped FAIL, WARN tier, live + stub proof) — rows stay single physical lines.
- `docs/agents/desktop.md` (Qt bullet): stale "fails on … journal aborts" sentence rewritten to the scoped semantics (fixed at report time; it went stale the moment my edit landed).

---

## §b PARTIALLY done

- **Which copy of post-deploy-check.sh the deploy battery executes is UNVERIFIED** (repo checkout vs flake-built store path). The 21:54 smoke ran the OLD leg; the next smoke is the first carrier of the scoped leg — not yet observed.
- Harness files `repro.sh` and `qml-load.sh` were never read (`agent.log` is 0 bytes; `agent2.log` + `repro2.sh` read, clean of secrets). Secret-hygiene of the unread two is unverified (gitleaks does not scan `~/.cache`).
- The shellcheck probe's compound guard printed nothing; clean-by-elimination rather than by positive marker (see §d).

## §c NOT started (deliberate or deferred)

- Attribution of the 00:54:52 runner (`.crush/crush.db` + /proc forensics) — skipped as low-value: the harness self-documents intent, and the fix did not depend on who ran it.
- Disposition of `~/.cache/polkit-fusion-repro/` — owner question (§g); left in place (referenced as evidence by the ticked rows; `~/.cache` volatility will eventually remove it).
- Verification of the parallel session's untracked work (Attic-check removal in post-deploy-check.sh, `docs/status/2026-11-24_21-07_ai-meter-…md`, "six→five" Description comment edit) — flagged to the user, not co-verified (rule: don't silently verify foreign work).
- Slot-ownership leg live owner proof — pre-existing `[blocked:user]` rows (`docs/todo/desktop.md` rows 67/196); untouched.

## §d Mistakes + near-misses (nothing destructive — honesty ledger)

1. First edit attempt was rejected by the read-first guard (sed/grep reads don't count as View) — wasted a round trip; the guard worked as designed.
2. My sed-read of the leg (~22:0x) and the parallel session's 22:06:40 write RACED: my knowledge of the file was stale when I first formed the edit. The View-before-edit requirement + quiescence wait prevented a stale-text edit; lesson: for shared files, View IMMEDIATELY before the edit, not minutes before.
3. The shellcheck one-liner lacked an explicit success marker; "no output" had to be resolved by elimination (fallback string would have printed if shellcheck were absent). Same quote-scrutiny standard I hold analysis one-liners to.
4. My first-pass mental model ("the tick is a phantom, fix never landed") was WRONG for ~10 minutes — the fix was landing concurrently. Corrected by the diff, not by assumption.

## §e What to improve

- **Tick-after-land rule:** a `[x] DONE` tick must post-date the on-disk edit (this session observed a ~10–15 min phantom window). Cheap discipline: tick only after `git diff` shows the change.
- **Journal-grepping check legs should unit-scope by default** — the polkit leg was the live case of a broad user-journal grep false-FAILing on manual processes.
- **Verification one-liners need explicit success markers** (`&& echo CLEAN`), including my own.
- Consider a fixture-selftest pattern for post-deploy-check journal legs (my throwaway stub harness is the design sketch — productize it, §f.1).

## §f Self-harvested follow-ups (landed in TODO_LIST.md queue + docs/todo/pipeline.md at authoring time)

1. `[ready]` Productize the polkit-leg stub harness into a fixture selftest (FAIL/WARN/PASS paths) — TODO_LIST queue + pipeline.md.
2. `[ready]` Verify which post-deploy-check.sh copy the battery runs (checkout vs store) and that the next smoke carries the scoped leg — TODO_LIST queue + pipeline.md.
3. `[ready]` Sweep other journal-grep legs in post-deploy-check.sh for the same broad-grep false-FAIL class — TODO_LIST queue + pipeline.md.
4. `[watch]` (library only) Next deploy smoke WILL print the polkit-render WARN naming `~/.cache/polkit-fusion-repro` until the 00:54:52 window rolls off (~2026-11-25 01:00) — expected, not a regression.

Deliberately NOT harvested: repro-harness disposition (owner question §g.2); 00:54 runner attribution (evidence-value too low to spend a dispatch); parallel-session verification (foreign scope, flagged instead).

## §g Questions for the owner (cannot be resolved from here)

1. Did any GUI auth dialog actually fail to open in the last 24h? (The journal shows no deployed-agent aborts; only you can confirm observed behavior.)
2. Preserve or dispose `~/.cache/polkit-fusion-repro/`? It is referenced as live proof by the ticked rows, but it is repro scratch in volatile cache — your evidence call.
3. The parallel session editing this file tonight (Attic-check removal + untracked ai-meter status report): deliberate, and do you want it verified by me or left to its owning session?

---

## Evidence appendix

- Journal (live pull, `--grep 'is not installed'`, user scope, 24h): 4 `qml[…]` lines at `00:54:52` from `~/.cache/polkit-fusion-repro/…/QuickAuthDialog.qml` (`org.kde.polkitkde` ×3, `fusion` ×1) + wireplumber `libcamera` noise (unmatched by the module filter).
- Host units: `dms.service` 48h zero matches; `niri-flake-polkit.service` zero entries.
- mtime timeline: tick ~21:5x (claims fix) → my sed read of OLD text ~22:0x → on-disk fix `22:06:40` → my View+edit `~22:12` (after ~2 min mtime stability).
- Stub tests: unit-abort → `FAIL … 1 abort(s) in deployed polkit host units (dms.service, niri-flake-polkit.service) … newest: … dms[123]…fusion…` + WARN remainder; clean → PASS only.
- Files touched this session: `scripts/post-deploy-check.sh` (scoped+tiered leg), `TODO_LIST.md:3200` + `docs/todo/pipeline.md:1037` (tick corrections), `docs/agents/desktop.md` (Qt bullet sentence), `docs/todo/pipeline.md` + `TODO_LIST.md` queue (§f harvests), this report.
