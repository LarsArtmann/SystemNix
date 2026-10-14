# Switch-Anchor Failure + sudo env_keep Fix — Session Status

**Date:** 2026-10-14, session work 13:17–13:40 CEST, report authored 14:55 CEST
**Trigger:** owner's failed `nh os switch` (paste): activation succeeded, profile-set refused by the no-heavy-builds gate
**Repo state at authoring:** HEAD `bb070afc` (daemon commit carrying this session's 6 files + one foreign file), owner asked for status only — **WAITING FOR INSTRUCTIONS**

---

## 0. Verdict in one paragraph

The owner's switch was a **no-op re-activation of an already-deployed toplevel** (`hy79p8g5`); the refusal was nh's post-switch profile-set leg, whose `sudo env … nix build --profile …` stripped `NIX_HEAVY_GATE_FORCE` because sudo drops caller env. Three actors raced the same anchor gap today (owner 13:17, a parallel deploy 13:10, a parallel agent 12:57+13:22); the anchor is CLOSED and verified for two of its three legs. Root cause fixed in-tree (sudoers `env_keep`) with a selftest tripwire; fix is **deploy pending** behind the live storm. The report's own §f harvest obligations are settled (1 harvested pre-report, 3 deliberate non-harvests with rationale in §h).

---

## a) FULLY DONE

1. **Failure diagnosis** — exact mechanism identified: gate shim (`scripts/nix-heavy-builds-gate.sh` via the `nix` PATH shim, `modules/nixos/services/nix-heavy-builds-gate.nix`) correctly refused eval/build under trip-recency; the FORCE var died at the sudo boundary of nh's last leg (`crates/nh-core/src/command.rs` sudo env allowlist passes only USER/NIX_PATH/LOCALE_ARCHIVE/PATH).
2. **Three-actor timeline reconstructed** from sudo journal lines, `/var/log/systemnix-deploys/`, profile-dir mtimes, and trip-history: 12:57:26 boot of gen 882 (`mkrkj5lg`) → 13:10 deploy log (activated `hy79p8g5` 13:15:30, exit 14 UNANCHORED 13:21:44) → owner's 13:17:27 no-op activation + refused profile-set → 13:22:20+30 parallel `switch-to-configuration boot` ×2 re-anchoring.
3. **Anchor closed and verified (2 of 3 legs directly)** — `readlink -f /nix/var/nix/profiles/system` == `/run/current-system` == `/nix/store/hy79p8g509lm8adbqj3b3335fkzkyfvp-nixos-system-evo-x2-26.11.20261011.7fd4004` (gen 883). Profile-set executed via a guarded throwaway harness (`/tmp/complete-switch-profile.sh`, aborts if running≠target); by execution time the parallel actor had already flipped the profile — my run was the idempotent re-assert, no duplicate generation created.
4. **Root-cause fix landed** — `platforms/nixos/system/sudo.nix`: `Defaults env_keep += "NIX_HEAVY_GATE_FORCE"` with the why (2026-10-14 anchor incident).
5. **Regression tripwire landed** — `flake/parts/checks/selftests.nix` `nix-heavy-builds-gate-selftest` now greps sudo.nix for the env_keep (static tripwire, repo's guard-trip-persist idiom).
6. **Documentation trail** — gate module header "escape hatch crosses sudo" paragraph; `configuration.nix` gate comment extended; CHANGELOG `[Unreleased]` entry (deploy pending); queue pair: `TODO_LIST.md` + `docs/todo/stability.md` `[ready]` deploy rows, non-drifting.
7. **Verification battery** — gate script selftest OK; `nix build .#checks.x86_64-linux.nix-heavy-builds-gate-selftest` green (tripwire executes); `nix eval` evo-x2 toplevel green (new toplevel `ra30bf7p…`; the two eval warnings pre-exist and are unrelated); `nix fmt` 8 formatted / 0 changed; `buildflow --build-mode lightning` exit 0.
8. **Daemon-commit attribution verified** — `bb070afc` (13:35:17) contains exactly my 6 files + the live actor's `discordsync.nix` (+6); my content re-verified in HEAD post-commit (`git show HEAD:` grep).

## b) PARTIALLY DONE

1. **Anchor evidence, leg 3 of 3** — bootloader DEFAULT entry == `hy79p8g5` is **inferred** (the 13:22 `switch-to-configuration boot` sudo lines + boot semantics), not read directly: `/boot` is root-only (`fmask 0077`), and I chose not to run a second privileged probe for it. "A reboot will NOT revert" is 2/3 direct evidence. Convertible to direct with one `bootctl list`/`loader.conf` read.
2. **DiscordSync smoke FAIL** (13:10 deploy's 7 FAILs, "auth gateway broken", 1 check downgraded STORM-SUSPECT) — flagged, not triaged; guard churn-stop-awaiting-re-arm vs real regression is undetermined (one journal/pgrep probe away; it is the live actor's lane).
3. **Storm characterization** — PSI sampled at 4 points (avg10 31→50% during session); driver attribution not attempted (freeze-14 row owns the class). **Correction logged:** my "~14:12 safe" call was falsified — fresh trips at 13:53/14:03/14:13 re-armed the latch to ~15:13 (treated the latch as static; it is a moving window).
4. **Gate coverage claim on root legs** — the env_keep fix works whether the sudo'd `nix` resolves to the shim (var honored) or real nix (ungated), but WHICH happens on this box's root secure_path was never probed; the shim's reach as root is unverified.

## c) NOT STARTED

1. **Deploying the env_keep fix** (deliberately — third concurrent deploy into a live storm would be reckless; queued `[ready]`, deploy at next calm window).
2. **Post-deploy verification** that a `sudo env … nix eval/build` leg inherits the var (written into the stability.md row as the deploy's acceptance check).
3. **`docs/agents/stability.md` gate section** — the no-heavy-builds gate is documented NOWHERE in stability.md (grep: zero hits); my additions live in the module header + configuration.nix comment + CHANGELOG. Not started because the gate's author session was live in the same files mid-session.

## d) TOTALLY FUCKED UP

Nothing destroyed, nothing reverted, no secrets exposed, no foreign work clobbered — but three real process failures, owned:

1. **I analyzed instead of executing on the first turn.** I was ON evo-x2 with passwordless wheel and told the owner to run the one-liner themselves; it took the owner's explicit "execute and verify" mandate to act. The fix cost was one ~1s cached command.
2. **My harness guard was incomplete and I ignored its own output.** `/tmp/complete-switch-profile.sh` aborted only on `running≠target` — it had no "profile already correct, nothing to do" early-exit, and its first line PRINTED that the profile was already `hy79p8g5` before I ran the privileged step anyway. Idempotent by nix's grace, not by design; I acted on 13:23 state at ~13:30 with a known-live parallel actor. The correct behavior: re-probe immediately pre-op AND treat an unexpected reading (already-fixed) as a stop-and-explain, not a proceed.
3. **A falsifiable claim left falsified.** I predicted "~14:12 safe" from trip-history arithmetic at 13:2x and never re-checked before ending the session; trips at 13:53/14:03/14:13 falsified it within 90 minutes. A moving-window latch cannot be quoted as a deadline without a re-check discipline.

## e) WHAT WE SHOULD IMPROVE

1. **Act-don't-advise when local and privileged-capable** — the first response should have been the harness, not a suggestion.
2. **Pre-op state re-probe as a hard rule for root-level ops** in multi-actor sessions (state I read 7 minutes ago is not state).
3. **Guard scripts must encode the done-state**, not just the broken-state: "already X → exit 0 loudly" is part of idempotency.
4. **No static deadlines on moving windows** — quote the latch rule, not a wall-clock, or re-verify at the quoted time.
5. **Typing `sudo journalctl` after establishing the guard's ban list** — wasted a call; the verified pattern (plain `journalctl -g`) should be reflexive.
6. **Probe the cheap adjacent unknowns when they gate the verdict** — bootctl list (leg 3), one DiscordSync journal look — or explicitly mark the claim's leg unverified in the close-out headline (done here, but should have been in-chat too).
7. **Explain every observed delta or park it explicitly** — the gen-882 dbus/terminfo etc-delta is still unexplained (§f item); "interesting, moved on" is how split brains survive.

## f) Up to 50 things to get done next

*Direct follow-ups of THIS session (harvest ledger in §h) are marked ★; everything else is observed-in-passing or pre-existing queue rows, listed because the owner asked for the full next-work picture.*

**This fix's lifecycle**
1. ★ Deploy the sudo env_keep fix at the next calm window (queued `[ready]`, TODO_LIST + stability.md).
2. ★ Post-deploy: verify `sudo env … nix eval` inherits NIX_HEAVY_GATE_FORCE (acceptance check in the row).
3. ★ Probe whether root's secure_path resolves the gate shim or real nix (determines root-leg gate coverage vs bypass-only).
4. ★ Convert the bootloader-default leg to direct evidence (`bootctl list` / `/boot/loader/loader.conf` read via the sanctioned harness pattern).
5. Document the no-heavy-builds gate in `docs/agents/stability.md` (zero hits today), incl. the sudo env_keep leg — parked as the gate-author session's lane (see §h).
6. Decide whether nh's sudo env allowlist deserves an upstream issue (env_keep makes it moot here; close-the-loop rule says fixed-here is a valid terminal state — record as deliberate non-file).
7. Sweep the gate shim's PATH-shadow bound (module header admits user-profile shadowing) — one probe: `which -a nix` under the nh PATH shape.

**Live storm / stability adjacencies observed this session**
8. Attribute the current storm's driver (trips 12:32→14:13+, avg10 oscillating 31–51%) — feeds the open freeze-14 driver-identification row.
9. Triage DiscordSync (localhost:8085 auth gateway) — churn-stop vs regression; owner question §g.2.
10. Sweep the other 6 smoke FAILs from the 13:10 deploy log (`2026-10-14_13-10-29.log`), not just DiscordSync.
11. Re-run the 1 STORM-SUSPECT-downgraded check when PSI-calm (deploy log's own instruction).
12. The 12:03/12:31/13:10 deploy triple today — three deploys inside a storm window; consider whether the tq-pool/gate batch should have waited (owner call; the batch itself says "lands at the next deploy window" for its VM-test leg).
13. Explain the gen-882 (mkrkj5lg) dbus-1/terminfo etc-delta vs `hy79p8g5` — was that deploy built from a dirty tree? (owner question §g.1)
14. Post-ollama-removal guard-trip re-baseline (48h) — today's 8+ trips are exactly the datapoint that row wants (stability.md watch row, in progress by clock).
15. The trip-history latch semantics: 3 trips in 40 min re-arm a rolling window — the deploy-FIX text quotes "60 min past the last guard trip" but nothing surfaces "latch extends" to the operator; a `-g`-able journal line exists already; consider a `latch-until` field in the refusal text.
16. `/tmp/complete-switch-profile.sh` — self-cleans on reboot; deliberate non-action (§h).

**Pre-existing rows this session touched or validated as still-open**
17. freeze-14 death-minute nix driver + enforcement leg (TODO_LIST:179) — the gate now EXISTS (landed today by the actor); row's remaining ask is driver identity.
18. deploy.sh entry gate ordering (pressure/trip-recency BEFORE the 13-section battery) — today's 13:10 deploy ran its full battery inside trips; row still open.
19. Post-crash resumable-reader pause automation (TODO_LIST:186).
20. IO-pressure admission gate for midnight maintenance jobs (TODO_LIST:184).
21. Migrate-script entry gate + serialization (TODO_LIST:183).
22. tq-agent-pool write-side accounting residual (row closed today, shellcheck legs realize at first build — the 13:10 deploy was that first build? verify its log).
23. Guard VM-test RUN (deferred twice "at first PSI-calm window" per TODO_LIST:178) — still owed.
24. thermal-pstate-guard deep rung — landed in-tree today, same deploy-pending state as my fix; rides the same window.
25. Verify the catalog eval warning (≈20 subdomains "vanish from derived DNS once dns-local.nix is deleted") — time-bomb observed in my toplevel eval.
26. The second pre-existing eval warning ("the module header") — identify and silence its source.
27. BuildFlow binary freshness (built at `518739c`, HEAD `70ca69a`) — `nix build . && nix run .#reinstall` per its own fix line.
28. BuildFlow preflight FAIL: flake.nix/lock disagree on 20 inputs (`nixpkgs_4`, `go-cqrs-lite_7`, …) — pre-existing, unpicked.
29. BuildFlow preflight warn: 30 private-repo inputs fetched via `github:` — `buildflow -s nix-checker --fix` + `nix flake lock` per its fix line (owner call; touches the 927-line parser-locked registry — CANNOT move casually).
30. The daemon-commit mixing problem again: bb070afc carries foreign `discordsync.nix` with my 6 files — pathspec-commit discipline exists in AGENTS.md; today it fired anyway (daemon raced before any human commit).
31. gen 882 cleanup: two stale profile generations (882, and pre-881 chain) pin store paths — routine GC handles it; no action unless space-pressure.

**Queue hygiene (rules-mandated, noticed while editing)**
32. TODO_LIST:179 row has grown a 1,200+-char UPDATE chain — candidate for pruning to CHANGELOG per the `[x]`-row rule (it's still `[ ]`, so the chain keeps growing).
33. The `[x]` closed rows in TODO_LIST:177-182 are pruned-to-CHANGELOG candidates at the next pass (rule: `[x]` rows pruned every pass — none were this pass).
34. `docs/todo/upstream.md` was being edited live by the actor — after they finish, confirm their row pair (queue+library) is non-drifting (spot-check, not mine).

**Nothing-else-observed filler is omitted deliberately** (the ask is "up to 50"; 34 honest items beat 50 padded ones).

## g) Questions for the owner (cannot self-answer)

1. **Gen 882 (`mkrkj5lg`, booted 12:57) differs from the running toplevel ONLY in dbus-1/terminfo closure paths.** What was that deploy supposed to carry — i.e., was it built from a dirty tree mid-iteration (fine) or is a config delta missing from git (not fine)?
2. **DiscordSync smoke FAIL** (auth gateway, downgraded STORM-SUSPECT in the 13:10 deploy): is that your live session's lane (guard churn-stop, re-arm pending) or do you want me to triage it now?
3. **Deploy authority for the env_keep fix:** should I deploy it at the next calm window (latch currently ~15:13) with the forced-if-needed pattern, or does your other session own the next deploy?

## h) §f self-harvest ledger (TODO-system rule)

| Item | Disposition |
|---|---|
| Deploy env_keep fix + post-deploy var check | **HARVESTED pre-report** — `TODO_LIST.md` + `docs/todo/stability.md` `[ready]` rows (landed in `bb070afc`) |
| Bootloader-default direct evidence (leg 3) | **Deliberately not harvested** — folds into item 1's post-deploy verification (same window, same privileged probe batch); keeping the queue to one deploy-scoped row |
| stability.md gate section | **Deliberately not harvested** — the gate's author session was editing gate-adjacent docs live during this session; queuing a competing doc task invites the drift the rule exists to prevent. Revisit if no gate section appears within their close-out |
| /tmp harness cleanup | **Deliberately not harvested** — `/tmp` is tmpfs-scoped, self-cleaning at reboot; queuing it is noise |

---

*Report covers ONLY this session's work and in-passing observations per owner instruction; no external research performed. Waiting for instructions.*
