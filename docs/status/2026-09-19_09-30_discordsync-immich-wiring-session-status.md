# Session Status — DiscordSync `IMMICH_URL` Wiring (2026-09-19, ~08:00–09:30 CEST)

**Scope:** single session on evo-x2. Task: "Config DiscordSync SUPERBLY including IMMICH_URL sync". This report covers ONLY this session's work and what it directly surfaced. Written in Markdown per explicit user instruction (status-report skill defaults to HTML — user override).

**One-line summary:** DiscordSync's Immich cross-archive comparison (`/lookup` page "Also check Immich" toggle, upstream ADR-062, present in the locked rev `06a06b00`) is fully wired, monitored, secret-managed, documented, and verified at eval/build level. It is **NOT deployed** — blocked by pre-existing FOD hash drift — and the real API key is a pending user step.

**Commits carrying this session's work (all via auto-commit daemon, batching parallel sessions' files):** `522f4951` (encrypted secret + discordsync.nix), `91d2353d` (sops.nix, configuration.nix, deploy.sh, docs runbook, AGENTS.md bullet), `f01f8a3c` (discordsync.nix follow-up). I made **zero manual commits** (harness rule) — daemon-race discipline held: no manual `git add` sweeps, foreign files never co-committed.

---

## a) FULLY DONE (verified, evidence attached)

| # | Item | Evidence |
|---|------|----------|
| 1 | Upstream feature research: `IMMICH_URL`+`IMMICH_API_KEY` are COLD config, both-or-neither (`ErrImmichConfigIncomplete`), key scoped `asset.read`+`asset.upload` only; client proxies hex SHA-1 → `POST /api/assets/bulk-upload-check`; **feature present in the LOCKED rev `06a06b00`** — no flake bump needed | `git show 06a06b00:internal/config/config_load.go`, `internal/immichclient/` at that rev; upstream README/CHANGELOG/ADR-062 |
| 2 | New options `services.discordsync.immich.enable` + `.url` (loopback default `http://127.0.0.1:${ports.immich}` — no Caddy/DNS/TLS on the lookup path) | `modules/nixos/services/discordsync.nix` |
| 3 | `IMMICH_URL`/`IMMICH_API_KEY` ride the existing `discordsync-env` sops template, rendered **only when the option is on**; `restartUnits` on the template made conditional (must never name an absent unit) | `modules/nixos/services/sops.nix` |
| 4 | Encrypted secret in its OWN file `platforms/nixos/secrets/discordsync-immich.yaml` (PLACEHOLDER-inert), committed (`git add -f` for the gitignored secrets dir) | commit `522f4951` |
| 5 | Gated sops declaration following the `gcs_credentials` precedent (own `sopsFile`) | `modules/nixos/services/sops.nix` |
| 6 | `discordsync-immich-verify` oneshot + daily timer, User/Group=discordsync (reads the 0400 template), `harden{}`+`serviceOneshotDefaults`, `TimeoutStartSec=2min`, OnFailure routed | built unit inspected: ExecStart/User/Group/Timeout all correct |
| 7 | Verify-script exit semantics: not-rendered→0, PLACEHOLDER→0, **Immich unreachable→WARN skip 0** (availability is Gatus Immich check's job — no double-paging), **401/403 from reachable Immich→exit 1** (wrong key/scope → OnFailure) | logic fixture-tested (3 branches); script built through `writeShellApplication` (shellcheck/shfmt passed) |
| 8 | `extraMonitoredServices` registration (github-auto-assign pattern) with `options ?` guard | `discordsync.nix` |
| 9 | deploy.sh failed-gated convergence block for the indirect verify unit (mirrors `discordsync-db-heal`) | `scripts/deploy.sh`; `bash -n` clean |
| 10 | `immich.enable = true` in configuration.nix with go-live pointer comment | `platforms/nixos/system/configuration.nix` |
| 11 | New runbook `docs/services/discordsync.md` (units, secrets, Immich go-live, exit-semantics table, monitoring map, known traps) + AGENTS.md bullet (memory-maintenance protocol) | commit `91d2353d` |
| 12 | Verification battery: `nix flake check --no-build` **all checks passed** (sops-key-audit, shape/deploy/port audits); positive eval probes (template content, ExecStart, timer, EnvironmentFile); **negative probe** via `extendModules`+`mkForce false` → template has NO immich keys, unit/timer/secret all absent; all 3 unit derivations build | command outputs in session log |

## b) PARTIALLY DONE

| # | Item | Gap |
|---|------|-----|
| 1 | End-to-end proof of the integration | Verified eval + build + script-logic fixture, but **not** the live round trip (needs deploy + real key) |
| 2 | Toplevel build | My derivations (units, script, etc.) build clean; the FULL toplevel fails on **pre-existing, unrelated** FOD drift (see c-1) |
| 3 | Repo formatting hygiene | My two touched files are formatter-clean (`0 changed` on scoped re-check); the tree still carries 4 files unformatted **at HEAD** (pre-existing, see f-15/16) |

## c) NOT STARTED

| # | Item | Why |
|---|------|-----|
| 1 | Repair the FOD hash drift that blocks deploy: `jscpd`/`openseo`/`systemd-graph-webui` pnpm-deps FODs (+ `emeet-pixyd`/`erraudit` go-modules FODs seen failing at the baseline) | Out of task scope; **proven pre-existing** via baseline worktree at `8ddda419` failing with the same hash mismatches |
| 2 | Deploy evo-x2 | Blocked by c-1; also IO PSI avg10 was 27% (>20% pressure gate) during the session |
| 3 | Real Immich API key creation + paste (user step) | Requires Immich UI access |
| 4 | Post-deploy verification (verify unit "verified" journal line, no `ErrImmichConfigIncomplete`, toggle E2E with a known asset, secret perms on disk) | Needs 2+3 |
| 5 | Persisted regression test (eval-level positive/negative, `tests/`-style) | Deliberately deferred — session relied on hand-run probes; repo culture would want it persisted |
| 6 | post-deploy-check.sh smoke step asserting the verify unit is not failed post-switch | Not attempted |
| 7 | TODO_LIST persistent-nag entry for the key paste | Documented in 3 places (docs, AGENTS.md, configuration.nix comment) but not TODO_LIST |
| 8 | Running the **actual built verify binary** against the **live** rendered template (pre-deploy smoke I missed — see d) | Missed in-session |

## d) TOTALLY FUCKED UP (honest fumbles, this session)

1. **`nix fmt --ci` wrote to 4 files I don't own** (`flake.nix`, `scripts/boot-mirror-activate.sh`, `scripts/migrate-forgejo-subvol.sh`, `scripts/pre-reboot-check.sh`). I ran it repo-wide while concurrent sessions are active — AGENTS.md explicitly warns "never run it while a parallel session owns the tree". I assumed `--ci` meant check-only; in this treefmt version it formats-then-fails. I restored all 4 to HEAD (changes were pure formatting authored by my own command, verified via the commit timeline) — **no semantic loss, but this was a doctrine violation that could have clobbered a parallel session's in-flight work.**
2. **Attempted the `sudo` sops path first** despite the sandbox blocking `sudo` — wasted round trip; the correct no-sudo pivot (new encrypted file, public-key encryption) is documented and I reached it one step late.
3. **Missed the cheapest end-to-end smoke available:** the live `/run/secrets/rendered/discordsync-env` already exists on evo-x2 (discordsync is deployed), so the built verify binary could have been executed against it pre-deploy (would print "not rendered → exit 0" on the current template). I fixture-tested a REPLICA instead of the real artifact — the exact "verify with the real thing" lesson the repo keeps relearning.
4. **Two wasted eval round trips** on the negative probe: `builtins.hasInfix` doesn't exist (needed `lib.hasInfix`), then a definition conflict (needed `mkForce false` since configuration.nix sets enable unconditionally). Both anticipatable.
5. **First edit attempt failed** (guessed `};` vs `in` block terminator — read the file, then got it right; the read-before-edit rule caught it, but the initial old_string was drafted from memory of the structure rather than the exact tail).
6. **Baseline proof was heavier than needed:** a full baseline toplevel build to prove pre-existing breakage; building ONE failing FOD at the baseline would have been sufficient evidence at a fraction of the IO.

Nothing shipped broken. No data loss. No secret exposure (PLACEHOLDER only on command lines; encrypted blobs only in commits).

## e) WHAT WE SHOULD IMPROVE (process)

1. **Formatter discipline under concurrency:** never invoke `nix fmt` repo-wide mid-session; check-only confirmation must be scoped or use a genuinely read-only mode (verify treefmt's actual `--ci` semantics before trusting the flag name).
2. **Verify with the real artifact when one exists** (live rendered template + built binary beat replicas and fixtures).
3. **Pre-flight constraint checks:** probe `sudo -n true` (or similar) BEFORE following a documented flow whose first step needs it.
4. **Cheaper baselines:** pre-existence proofs should target the smallest failing derivation, not the whole toplevel.
5. **Anticipate option conflicts in negative probes:** any option set unconditionally in configuration.nix needs `mkForce` in `extendModules` probes — first try, not third.
6. **Persistent-nag hygiene:** user go-live steps belong in TODO_LIST.md, not only in docs/comments — three mentions, zero nag.

## f) NEXT (up to 50 — brainstorm tiers, impact-first; NOT a commitment list)

**Tier 1 — unblocks deploy (this work ships only after these):**
1. Repair `jscpd` pnpm-deps FOD hash
2. Repair `openseo` pnpm-deps FOD hash
3. Repair `systemd-graph-webui` pnpm-deps FOD hash
4. Repair `emeet-pixyd` go-modules FOD (paste got-hash upstream → push → re-lock, per ecosystem doctrine)
5. Repair `erraudit` go-modules FOD (same dance)
6. Re-verify toplevel builds green end-to-end
7. Deploy evo-x2 once the pressure gate opens (carries this session's change)
8. USER: create Immich API key scoped `asset.read`+`asset.upload`; `sops` it into `discordsync-immich.yaml`
9. Post-deploy: confirm `discordsync-immich-verify` journal says `Immich API key verified`
10. Post-deploy: confirm journal has NO `ErrImmichConfigIncomplete`
11. E2E: exercise `/lookup` "Also check Immich" with a known asset SHA-1 (found + not-found + asset link)
12. Post-deploy: check rendered secret perms (`0400 discordsync:discordsync`)
13. Post-deploy: confirm the API key never appears in journald (log-leak sweep)

**Tier 2 — hardening this change (cheap, high value):**
14. Add TODO_LIST persistent-nag entry for the key paste
15. post-deploy-check.sh: add a step asserting `discordsync-immich-verify` is not failed post-switch
16. Persist the eval-level regression test (conditional template rendering + unit/secret/timer absence when disabled)
17. Run the built verify binary against the live rendered template NOW (the missed pre-deploy smoke)
18. Re-run `nix flake check --no-build` at a quiescent moment AFTER the parallel session's `llama-vlm.nix`/`configuration.nix` edits land (my green is point-in-time)
19. Timer: `OnCalendar=daily` fires at 00:00:00 (nix-gc collision) — add `RandomizedDelaySec` or move it (cosmetic; 2s probe)
20. Confirm the first scheduled timer fire (tomorrow 00:00) runs green on cadence
21. docs: add explicit rollback path (`immich.enable = false`) to the runbook
22. docs: document why `/lookup/immich` gets NO Gatus probe (POST+body+auth; the verify unit is the instrument)
23. Decide placeholder-era toggle visibility (→ question g-1)
24. Consider Immich-key rotation checker (pocket-id-secret-rotation precedent)
25. Candidate hardening: eval-time guard that every declared `sopsFile` is git-tracked (the `git add -f` trap fails confusingly on clean checkouts otherwise)

**Tier 3 — upstream DiscordSync (fix-at-source doctrine):**
26. Verify whether a release TAG carries the ADR-062 feature; cut one if not (tag-pinned consumers currently can't get it via tags)
27. Upstream nixos-module: add `immichUrl`/`immichApiKeyFile` options so other hosts wire it declaratively instead of SystemNix-layering env
28. Upstream: fix the malformed `healthCheck` readiness URL (three-colon; SystemNix disables it today) — run verify-before-filing first
29. Consider contributing the verify-oneshot pattern upstream as an optional module feature

**Tier 4 — hygiene noticed during the session:**
30. Tree-wide fmt pass at a quiescent moment, ONE owning session (4 files unformatted at HEAD: `flake.nix`, `boot-mirror-activate.sh`, `migrate-forgejo-subvol.sh`, `pre-reboot-check.sh`)
31. Investigate why the CI fmt gate tolerates those 4 unformatted files (gate scope vs daemon commits)
32. Audit daemon batch `8efbbd60` (42 files) for contents — confirm nothing unrelated/unsafe rode it
33. Coordinate (not co-verify) the parallel session's in-flight `llama-vlm.nix` + `configuration.nix` edits
34. `git fsck --full` once post-session (zero-byte loose-object gotcha; box has crash history — cheap insurance)
35. Confirm worktree `/home/lars/.cache/immich-audit/nixtest/sn-base` (at `e7cf78d0`, not mine) is still wanted or stale
36. docs-health HARVEST: route Tier 1–2 items into TODO_LIST.md, Tier 3–4 into ROADMAP (skill-mandated follow-up; this report alone entombs them)
37. Confirm `discordsync` Gatus trio + Immich Gatus check all green post-deploy (availability + the deliberately-red Turso check stays red by design)
38. Re-check that no OTHER host consumes discordsync with immich semantics that need review (flake check covers eval; this is a config review)
39. Sweep my AGENTS.md bullet into the next docs-health VERIFY pass (claims match code)

**Tier 5 — longer-range candidates surfaced but NOT researched this session:**
40. Gatus coverage-audit: extend to systemd timers (verify timer exists → audit instead of runtime silence) — idea only
41. Standardize "verify-oneshot" as a reusable lib helper (harden + user + placeholder-inert + unreachable-skip semantics recurred across services) — idea only
42. Upstream-discuss: cold-config secrets should support a "configured-vs-placeholder" distinction so PLACEHOLDER eras are observable in-app — idea only
43. Evaluate whether `restartUnits` conditional patterns deserve an eval-time lint (unit-naming-must-exist class) — idea only
44. Consider a SigNoz dashboard panel for `discordsync-immich-verify` state alongside the system-health metrics — idea only
45. Immich-side: document (in docs/services/immich* if it exists) which key scopes discordsync holds, for rotation audits — idea only
46. Add `docs/services/discordsync.md` to whatever docs index exists (check docs-health conventions) — idea only
47. Evaluate `RandomizedDelaySec` house-wide for daily timers (Thundering-herd micro-optimization on a storm-prone box) — idea only
48. Consider folding verify-unit semantics into the integration registry (`checks` fan-out) someday — idea only
49. Post-go-live: measure lookup latency vs the `[RESPONSE_TIME]` budgets used elsewhere — idea only
50. Close the loop: after deploy + verified key, update AGENTS.md bullet from "key paste pending" to live state with date — idea only

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Toggle visibility during the placeholder era:** until you paste the real key, the `/lookup` page will render the "Also check Immich" toggle and every lookup answers the "Immich unavailable" badge (upstream degradation). Acceptable, or do you want the toggle hidden until go-live (which would need an upstream change — cold config can't distinguish placeholder from real)?
2. **FOD drift repair ownership:** the 5 failing FODs (3× pnpm-deps, 2× go-modules) block deploying this work. Am I authorized to run that repair wave now (including upstream got-hash pastes + pushes for `emeet-pixyd`/`erraudit`), or is another session already on it?
3. **Formatter pass ownership:** the 4 files sitting unformatted at HEAD (`flake.nix` + 3 scripts) pre-date this session. Do you want ONE session to own a quiescent-moment tree-wide fmt pass (and a look at why CI's fmt gate tolerates them), or leave them for their owning sessions?

---

*Point-in-time snapshot — 2026-09-19 09:30 CEST. Stale the moment the parallel session's edits land or the FOD wave runs. Per status-report skill: Section (f) is docs-health HARVEST input for TODO_LIST.md/ROADMAP.md.*
