# DNSBLOCKD Max-Adoption — Session 6 (M17 done, M18 done, M19 upstream-prep landed unpushed)

**Session window:** 2026-10-01 ~03:50 → 05:30 CEST (resumed from session 5's WAIT on the user's "READ, UNDERSTAND… keep going" directive)
**Repo state at start:** daemon-swept session-5 work (M14-M16 in `47b64574`-era lineage, 03-47 report in `f21be80a`), tree clean except foreign FEATURES.md.
**Repo state at end:** SystemNix tree clean (my work daemon-swept: plan-doc M18 § via `ad714882`, M17 via `47b64574` + `70711934`); dnsblockd upstream carrying MY unpushed module options (daemon commit `4e99b6d1`, eval-verified green after the sweep).
**Lock:** f625cfee (UNCHANGED, guard held). **No deploy. No push. No tracking_mode flip.**

---

## a) FULLY DONE

1. **Re-baseline** — git log/status both repos; confirmed M14-M16 + the 03-47 report landed; only foreign files dirty.
2. **M17 — `tlsH3Enabled` (h3/QUIC block pages), inert default false — DONE and daemon-swept** (`47b64574` bulk + `70711934` echo-line):
   - Upstream evidence first: koanf tag `tls_h3_enabled` (config.go:316, default false :438), `errH3RequiresTLSPort` (`tls_port > 0`, validation.go:36/671), doh3/doq UDP-conflict checks (unreachable from wrapper — no such options).
   - **Plan's "UDP-443 firewall check" was ALREADY SATISFIED**: `platforms/nixos/system/networking.nix` opens 443/udp host-wide (caddy h3 precedent; LAN rides trusted eno1). Option text documents the non-default-port case + the specific-IP-vs-wildcard coexistence with caddy.
   - Module: option after the ECS block, render `tls_h3_enabled = cfg.tlsH3Enabled;` beside `tls_port` (M16 unconditional pattern), assertion `!cfg.tlsH3Enabled || cfg.blockTLSPort > 0` citing upstream.
   - Test: `h3Exec` extendModules variant + host-inert check + anti-phantom `!= exec` + negative proof + python content asserts (host false, variant true, tls_port 443 preserved).
   - **Evidence:** green build store `rbg92617856jv2mjxpppml4hwv2lm4wq` with the NEW marker text ("…ECS, h3 OK" — new path proves real change); worktree negative proof `wk7p01j54156xjzmmzhapdgimz6g7snq` failing with EXACTLY "h3-without-tls-port assertion does not fire (upstream errH3RequiresTLSPort must be mirrored)" and nothing else. statix/deadnix clean.
3. **M18 — wrapper→upstream mapping table + pre-migration baseline — DONE** (plan doc §"M18 deliverable" at :258+, daemon `ad714882`):
   - Enumerated the FULL wrapper surface (~50 top-level options) vs upstream `services.dnsblockd` (core 43 + dns 75 + tracking 11 + proxy-tls 9 options; snake_case; `mkRenamedOptionModule` blockIP alias).
   - **Findings that reshape the migration** (all recorded in the table):
     - **csrf HARD GAP**: upstream `config.go:400` defaults `CSRFEnabled: false` and config.nix NEVER renders the key — a naive migration silently drops the M06 csrf belt. Mitigation found: koanf env bridge `DNSBLOCKD_CSRF_ENABLED=true` works at ANY rev (config.go:20 envPrefix + flat-tag mapping, config_test.go:90 precedent). Then fixed properly upstream (see b).
     - **Disk-state deltas**: `allowlist_path`/`temp_allowlist_path` upstream defaults carry `.json` suffix — MUST set explicitly or the LIVE allowlist file orphans and dashboard "Always allow" history restarts empty.
     - **Unit identity**: wrapper unit runs as ROOT (root-owned `/var/lib/dnsblockd`); upstream runs as dedicated `dnsblockd` user + Type=notify + AF_UNIX — migration needs a one-time chown heal or a `user="root"` override.
     - **Default deltas to pin**: `listen_addr`/`dns_listen_addr` default `::` (vs .200/0.0.0.0), `dns_enabled` false, `memory_max` 512M (vs 4G).
     - **extraDomains has NO expression path at f625cfee**: empty-target policies are rejected at startup (`ErrNoTargets`, policy.go:164) — global extra-domains need a file-carrying upstream option.
     - **Pre-filter is a BELT, not the only mechanism**: upstream's processor already applies the whitelist to mapping.json, and the runtime handler consults allowlists — so the wrapper's build-time pre-filter is load-efficiency/attribution, droppable post-migration.
     - Wrapper/upstream `devices`/`users`/`policies` submodule shapes are IDENTICAL (M14-M16 aligned perfectly).
   - Baseline captured `/tmp/m18-baseline/` (ANCHOR `3cc72123`, rendered config `lr78gq5g…` 7.3 KB/96 keys, deployed unit text 53 lines) + M21 procedure documented (worktree re-derive, set-compare, store-path-noise filter) per the surface-preservation doctrine.
4. **Self-harvest executed** (the TODO-system rule): services.md migration row re-tagged `[ready]`→`[blocked:push]` with rationale; new `[blocked:push]` library entry for the upstream push + lock gate; `check-todo-system.sh` structural check OK.

## b) PARTIALLY DONE

1. **M19 — migration impl A — STARTED, deliberately RE-SCOPED to upstream-first** (reasoning recorded below in e/§decisions):
   - **Upstream dnsblockd module options AUTHORED + LANDED (locally, unpushed)** in `~/projects/dnsblockd`, daemon-swept as `4e99b6d1` (5 files, +63/−10):
     - `csrf_enabled` option (core.nix, bool, default false mirroring Go) + render in config.nix.
     - `blocklist_files` option (dns.nix; `name`/`file` submodule) — pre-built hosts files appended AFTER fetched lists (attribution order documented), wired into BOTH the runtime loader (`dns_blocklists`) and the processor args (mapping.json attribution).
     - `temp_allow_all` assertion extended to require `blocklist_files == []`.
     - Golden option list regenerated (117 options).
   - **Verification state:** `nix build .#checks.x86_64-linux.nixos-module-eval` GREEN (`zjx5gnnd`) and `nixos-module-options-gate` GREEN (`28q8p3f6`) — run AFTER the daemon sweep, proving the landed state evals and the golden list matches. **NOT yet run:** the upstream VM test (boots the module, exercises DNS+HTTP — would exercise my processor-path change), any upstream `nix flake check` full pass, and the SystemNix-side consumption (nothing in SystemNix references these options yet).
2. **M20/M21 — NOT BEGUN** (blocked on the above landing upstream + lock bump — by design, see decisions).

## c) NOT STARTED

1. **M19 SystemNix half** — wrapper restructure to consume `inputs.dnsblockd.nixosModules.dnsblockd` (import mechanics verified: both hosts pass `specialArgs.inputs`; module exists AT f625cfee; flake exports `.default`/`.dnsblockd`).
2. **M20** — overlays re-add (filter pipeline via `blocklist_files`, attach-ip, oomd/GOMEMLIMIT/GOTRACEBACK, sops CA + secret gates, restartTriggers, csrf via yaml now that the option exists).
3. **M21** — baseline set-compare + VM test of the migrated unit.
4. **M22** — user cutover runbook (deploy command, smoke, restart-cycle watch, rollback).
5. **Close-out report** superseding `2026-09-30_13-07_*` (disposition table M01-M22, SHA corrections for `accb0522`/`40eeac48`, M12 attribution note).
6. Standing from earlier sessions: M11 dashboard walk (user), TODO_LIST queue-row close-outs gated on it, tracking-dial flip (owner).

## d) TOTALLY FUCKED UP (honest)

1. **The typo hunt (M17 test wiring)** — my `fail()` anchor said `dns-blockd` where the file says `dns-blocker`. I burned ~5 tool calls hunting an "invisible character" (od dumps, codepoint differ, regex probes) — the diff output had literally printed `'blocker re' vs 'blockd ren'` at position 24 and I read past it. Lesson: when a matcher fails, diff the EXACT strings first; grep the anchor BEFORE python/edit.
2. **multiedit partial-failure misdiagnosis** — "Applied 3 of 5" and I guessed wrong about WHICH two failed, then reasoned from a stale assumption. Should have immediately grepped for each hunk's sentinel content.
3. **Daemon race cost the echo-line edit** — the marker line update was swept out between edit and verify; I initially misread the stale marker as the eval-cache trap before `git log` showed the daemon had committed the file mid-flight. Post-edit content verification (grep the new text IMMEDIATELY) would have caught it in one step.
4. **Negative-proof priority conflict (avoidable)** — my first M17 negative proof set `blockTLSPort = 0` (plain) against the host's plain `443` → eval conflict. The offsite-borg `mkOverride 50` lesson in AGENTS.md already covers exactly this; fixed with `pkgs.lib.mkForce 0`.
5. **Upstream edits landed unverified (ordering sin)** — I edited dnsblockd module files while ITS auto-commit daemon runs; the daemon swept them BEFORE I ran any check. Recovered by verifying after (both checks green), but the correct order is edit→verify→(daemon sweeps verified state). In the window between sweep and verify, the repo carried unverified module changes.

## e) WHAT WE SHOULD IMPROVE

1. **Anchor-verify discipline**: grep every edit anchor against the live file (not the last view) before multiedit — kills both the typo class and the mtime-race class in one step.
2. **Immediate post-edit content grep** on daemon-shared files (the echo-line loss would have been a 10-second fix instead of a rebuild-diagnosis detour).
3. **Architecture decision recorded (upstream-first over dual-mode wrapper)**: a flag-gated dual-mode wrapper (`consumeUpstreamModule`) was designed and REJECTED — it is unflippable until the lock moves either way, so it buys risk, not value; the durable work is the upstream options (done) + a single clean REPLACE migration in the next session against the complete surface. The dual-mode sketch lives in this session's reasoning; do not resurrect it without new constraints.
4. **Render test scale**: `test-dns-blocker-render.nix` is now ~400 lines with 5 exec variants and a 2-layer assert model — the next wrapper change should table-drive the variant matrix before it grows a 6th.
5. **Cross-repo daemon awareness**: working in ~/projects/dnsblockd means TWO daemons race you. Same rules apply there (pathspec commits, post-edit verify) — I applied edits without a pre-flight `git status` of that repo's daemon cadence.
6. **M18's `/tmp` baseline is intentionally ephemeral** — M21 MUST re-derive from the worktree (documented in the plan doc); anyone tempted to "save time" by diffing against /tmp files later is re-creating the 2026-09-15 stale-baseline trap.

## f) NEXT (up to 50, rough order)

**Upstream (dnsblockd repo):**
1. Run the upstream VM test (`checks.*` nixos-vm) against `4e99b6d1` — exercises DNS+HTTP through the changed processor path.
2. Full `nix flake check --no-build` in dnsblockd.
3. Add upstream negative tests: `blocklist_files` rides loader+processor (assert mapping.json gains its entries); `csrf_enabled` renders (module-eval content assert).
4. Consider upstream doc note in the module README/changelog for the two new options.
5. PUSH dnsblockd master (USER or sanctioned session — g/Q1).
6. Re-verify FOD at the pushed rev (`nix build github:LarsArtmann/dnsblockd/master#default.goModules` — the M05 verb).

**SystemNix lock + migration (M19-M21):**
7. `nix flake lock --update-input dnsblockd` after push; package verify from OUR lock; `nix flake check --no-build --all-systems`.
8. Author the migration REPLACE of `dns-blocker.nix` per the mapping table (A): all ~50 option mappings, explicit `allowlist_path`/`temp_allowlist_path` (no-.json values!), `listen_addr`/`dns_listen_addr`/`dns_enabled`/`memory_max` pins.
9. Decide + implement unit identity: non-root user + one-time chown heal ExecStartPre (recommended) — g/Q2.
10. M20 overlays: whitelist pre-filter + systemnix-extra via `blocklist_files` (keep the mapping.json non-empty build gate!); attach-ip unit + device ordering; oomd exemption/MemoryMax 4G/GOMEMLIMIT/GOTRACEBACK; sops CA paths + secret-wait gate + oidc env-file bridge (upstream `oidc_client_secret_file` likely consumes the SAME env file — verify key name); restartTriggers; csrf now via the yaml option (drop the env-bridge fallback once rendered).
11. M20 semantics check: `temp_allow_all` upstream asserts lists EMPTY — wrapper's kill-switch-with-lists-configured behavior needs the overlay shape from the mapping table (B6).
12. M21: worktree baseline at the pre-migration commit; set-compare rendered YAML + unit (order-insensitive, store-noise filtered); explain EVERY delta.
13. M21: VM test — migrated unit boots, DNS serves, block page renders, allowlist persists.
14. M21: gatus + integration registry + textfile collectors survive unchanged (they key on unit name `dnsblockd` — unchanged).
15. M21: confirm `services.dns-blocker` wrapper OPTION surface stays (host config `dns-blocker-config.nix` untouched) vs renaming — recommend: keep wrapper name this migration, rename later if ever.
16. Commit migration pathspec; close services.md:57 row.

**M22 + close-out:**
17. Write the M22 cutover runbook (deploy cmd, post-deploy smoke incl. the §-gates that mention dnsblockd, one DNS restart-cycle watch, rollback = revert + redeploy).
18. Close-out report: M01-M22 disposition table, SHA corrections (`accb0522`/`40eeac48` → content citations), M12 attribution note (`6dfcf827`/`bba88c9e`), supersede `2026-09-30_13-07_*`.
19. After cutover: AGENTS.md dnsblockd section sweep (wrapper→upstream-module phrasing, "sole resolver" facts unchanged, migration note).
20. After cutover: prune the now-dead wrapper render path from docs referencing it (services.md rows, research doc pointers).

**Standing/user-gated:**
21. M11 dashboard walk (devices named, Likely-Broken Sites, csrf form post) — then mark the 5 TODO_LIST queue rows `[x]` (226-228 lineage).
22. Tracking-dial decision (memo at docs/services/dnsblockd-tracking-dial.md) — flip ONLY with owner sanction + same-commit test update.
23. lg-tv identity confirm + rpi3-dns/lan-router keep/drop — g/Q3.
24. pixel6 decommission rides the next deploy (already in tree) — verify absence in the deployed config post-deploy.
25. Harvest discipline: next session re-checks `check-todo-system.sh` (the 54-report WARN is foreign debt, not ours).

**Smaller hardening noticed this session:**
26. The render test's `policyAssertionFires` helper now carries 7 callers — rename to `assertionFires` on next touch (name predates generalization).
27. `docs/services/dnsblockd.md` runbook: add an "h3/QUIC" paragraph once anyone flips `tlsH3Enabled` (UDP listener + coexistence notes from the option text).
28. Consider an eval-time guard that the upstream module import stays version-aligned (option presence probe `options ? services.dnsblockd.blocklist_files` as the lock-floor canary inside the migrated wrapper — flips a WARNING if the lock regresses below the needed rev).
29. `nix flake check` in dnsblockd upstream may grow a golden-drift trap for future option additions — my regeneration pattern (rebuild sorted list) is the documented verb; note it in the upstream module README.
30. If the chown-heal path is chosen (Q2): steal the cv-state-perms heal shape (fast-path predicate == repair set, journal summary, CAP_FOWNER) — do not hand-roll fresh.

## g) QUESTIONS (cannot figure out myself)

1. **Upstream push + lock move sanction**: the migration is now blocked on dnsblockd master carrying `4e99b6d1` (csrf_enabled + blocklist_files options). My guards forbid pushes and lock moves. Should (a) YOU push dnsblockd master, or (b) a next session be sanctioned to push + run the M05-protocol lock bump? Until then M19-M21 SystemNix work cannot even eval against the real options.
2. **Post-migration unit identity**: adopt upstream's non-root `dnsblockd` user (one-time chown heal over `/var/lib/dnsblockd` — allowlist/tracking.db/blocklist-cache are root-owned today; recommended: keeps the non-root win, heals once) — or override `user = "root"` (zero migration risk, loses the privilege drop)? This decides M20's overlay shape.
3. **Device registry confirmations (carry-over, gates queue close-outs)**: is `lg-tv = 192.168.1.62` (Realtek `00:e0:4c` OUI) the LG TV SSCR2 — and should `rpi3-dns` (.151) / `lan-router` (.1) STAY in the devices list (they own real DNS traffic) or drop (not "household machines")?

---

**Mode after this report: WAITING FOR INSTRUCTIONS** (per standing directive).
