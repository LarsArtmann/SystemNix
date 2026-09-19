# TODO — Desktop

niri, DMS/Quickshell, Qt, audio (smart-audio/WirePlumber), shell UX (fish), Signal, btop, GUI runtime verifications.

Domain LIBRARY of the [TODO system](../../TODO_LIST.md) — every open item for this domain, any lifecycle. The dispatch QUEUE of agent-actionable (`[ready]`) items is `TODO_LIST.md`; the tq pool harvests only the queue.

House rules (enforced by convention, see AGENTS.md → "TODO System"): file an item under the domain that owns the FIX, not the symptom it mentions; one item = one ask + `**Source:**` pointer — verification narratives go to the status report, never the item; `[x]` rows are pruned to `CHANGELOG.md` at every pass; NO system-state narratives here (AGENTS.md and `docs/services/*` runbooks own state).

Tag legend: `[ready]` agent-actionable · `[blocked:user]` needs sudo/browser/external console/owner hands · `[blocked:push]` needs an upstream push/tag (agents implement, never push) · `[blocked:deploy]` waits on a deploy · `[watch]` time-gated verification · `[decision]` owner question.

## Prioritized

- [ ] [blocked:user] **Runtime-verify wf-recorder screen recording on niri** — build-proven only. **Source:** 08-16 22-00 §c.1
- [ ] [blocked:user] **Smart-audio: verify audible output + reverse direction (incl. DP-2 cross-output path, never tested)** — test-tone tooling is on PATH since 08-22. **Source:** archived 08-14 08-24
- [ ] [decision] **btop privileges + terminal-restore policy (user, niri-storm session)** — sudoers NOPASSWD vs unprivileged btop; restore ONE ghostty per login (current) vs ZERO (`skip_apps`). **Source:** `2026-08-31_15-11_*` §Q1-2
- [ ] [ready] **fish startup profiling** — 908-1211 ms under deploy IO (threshold 200 ms, 60 ms when calm); profile or make the check pressure-aware. **Source:** `2026-08-29_17-29_*` §f.26, `2026-08-30_11-15_*` §f.20
- [ ] [ready] **Enable niri blur** — transparent terminals without blur are hard to read
- [ ] [ready] **Verify `audio.nix` WirePlumber priority rules don't fight smart-audio**

## Backlog (untriaged harvest)

- [ ] [blocked:user] Post-storm live confirmation on evo-x2: one login/restart cycle, journal shows exactly one restore pass, no empty-shell ghostty pile — closes the 2026-08-31 incident loop against RUNTIME behavior (only the binary version was verified). **Source:** docs/status/2026-09-14_00-23 §c.4
- [ ] [decision] **Signal Desktop backlog (DECIDED scope: theme shipped; chat-color automation pending user approval)** — (a) pick the green preset in the UI (one-time; presets: forest/wintergreen/basil/sea/lagoon) or approve the SQLCipher seeding script (DB-copy harness, refuse-while-running, backup-first); (b) write `docs/services/signal.md` (storage layout, what is/isn't configurable, preset list, per-conversation vs global color distinction); (c) verify-or-retract the "appearance syncs to linked devices" claim. **Source:** `2026-09-14_16-16` §f.3-22
- [ ] [blocked:user] Verify the niri gatus fix live: `system_niri_metrics_fresh 1` in `:9100/metrics`; replay the 2026-08-24 bounce cadence (or wait for a real login bounce) and watch "Niri Desktop Died" flip red within 2-4 collector ticks and HOLD through greeter gaps; a real SDDM login closes the source report's last open item. **Source:** same report §f22 — BLOCKED: live incident-path replay and real SDDM login are owner-performed actions
- [ ] [ready] Anchor the four sibling niri checks (`desktop_died`/`crash_loop`/`zombie`/`aw-watcher`) to the line-anchored VALUE form (safe today only because niri.prom has no HELP/TYPE comments — one collector rewrite from the 2026-08-22 phantom-green class). **Source:** same report §f23
- [ ] [ready] Document the freshness-composite contract ("Niri Compositor owns collector-death alerting for all niri checks") in AGENTS.md's niri bullet. **Source:** same report §f24
- [ ] [ready] Audit the niri-health collector's journalctl greps for `timeout N` wrappers per the 2026-08-31 journal-stall doctrine. **Source:** same report §f25

