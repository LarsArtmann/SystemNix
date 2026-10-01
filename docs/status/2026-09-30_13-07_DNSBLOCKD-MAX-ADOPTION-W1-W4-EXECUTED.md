# STATUS: dnsblockd Max-Adoption Plan — W1–W4 Executed, W5 Probe Design Flawed, W6–W8 Not Started

**Date:** 2026-09-30 13:07 · **Session:** executing `docs/planning/2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md`
**Commits this session (mine, all pathspec/amend-verified):** `485a4166` (M01), `d9556da2` (M02), `8165f8c1` (M03), `accb0522` (M05), `40eeac48` (M06–M08); memo daemon-swept into `3664ec5d`.
**Nothing deployed.** dnsblockd still runs v0.9.2-32 (`75b4ce9`) until the M11 user window — the allowlist data-loss window is still OPEN in prod.

---

## a) FULLY DONE ✅

| Task                                             | What landed                                                                                                                                                                                                                                                                                                                                       | Verification                                                                                                                                                                                                |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **M01** allowlist + rate-limit + log-sampling    | `allowlist_path=/var/lib/dnsblockd/allowlist`, `log_sampling 500/100` in render; rate limit **50/100 as host values** (plan said "add render keys" — options already existed at default 0, so the correct adaptation was host-config values, wrapper default stays upstream-matching)                                                             | Realized config drv grepped: all 5 keys present with exact values                                                                                                                                           |
| **M02** extraDomains (REVISED: wire, not delete) | Discovered the option carries real owner intent (reddit×4 + `us.i.posthog.com`, inherited by BOTH evo-x2 and rpi3). Wired as synthetic `systemnix-extra` hosts blocklist appended last (same whitelist filter, feeds both `dns_blocklists` + mapping.json). Plan's delete-branch was written on the "no data" assumption — falsified by F09 sweep | mapping.json totals delta **0** (pure belt); attribution preserved (first-wins → reddit=StevenBlack, posthog=HaGeZi-ultimate); all 5 domains were ALREADY blocked (see §d-1 for how I got this wrong first) |
| **M03** render-assertion test                    | `tests/test-dns-blocker-render.nix` + registration. Pure-eval checks (rate-limit values, anti-phantom invariant via mkForce variant, StateDirectory, tracking_mode owner gate) + builder greps on the REAL realized YAML (via ExecStart string context)                                                                                           | Green build; **negative-proven** via worktree mutation (removing `log_sampling_threshold` → `KeyError` → red)                                                                                               |
| **M04** FOD probe                                | `github:LarsArtmann/dnsblockd/master#default.goModules` GREEN at `f625cfee`                                                                                                                                                                                                                                                                       | Upstream moved since planning: 8531c772→f625cfee, +73 past v0.9.3 (docs/tests/refactors + T308/T316 telemetry, dep bumps — no breakers)                                                                     |
| **M05** lock bump                                | `75b4ce9d` → `f625cfee`, healthy node (no dirtyRev)                                                                                                                                                                                                                                                                                               | Package green from OUR lock (`dnsblockd-f625cfe`); full `nix flake check --no-build` passed                                                                                                                 |
| **M06** csrf_enabled                             | `csrf_enabled = true` rendered (T300 prerequisite carried by lock; cookie_secure stays default-true)                                                                                                                                                                                                                                              | Key present in realized config                                                                                                                                                                              |
| **M07** devices+users options                    | Full option surface (id/name/group/ips; name/devices) + render (group omitted when null) + **6 assertions** (upstream caps 256/16, dup ids, dup IPs, dangling refs, single ownership)                                                                                                                                                             | Render verified (5 devices, 1 user); **negative-proven**: dup-device assertion fires via extendModules                                                                                                      |
| **M08** LAN inventory                            | `ip neigh` sandbox-blocked → used `/proc/net/arp` + repo knowledge. Devices: `.150` evo-x2, `.151` rpi3, `.1` router, `.29` pixel6-candidate, `.62` lg-tv-candidate (both carry owner-confirm markers); `.53`/`.200` excluded (VRRP/blockIP, not devices)                                                                                         | Populated in dns-blocker-config.nix; renders                                                                                                                                                                |
| **M09** tracking-dial memo                       | `docs/services/dnsblockd-tracking-dial.md` (daemon-swept into `3664ec5d` — content intact; NOT amended because a parallel session's commit landed on top)                                                                                                                                                                                         | Complete: modes table, unlocks, non-stores, retention, prepared flip + coupled test edit, recommendation                                                                                                    |

**Every daemon sweep was stat-verified then amended** (4/4 commits) per the multi-agent discipline. Parallel sessions were active all session (3 docs commits from another session + a boot-mirror forensics batch at 13:06 — untouched, correctly attributed).

## b) PARTIALLY DONE 🔶

- **M10 (post-deploy smoke additions)** — researched but **no edits yet**, and the research produced a critical negative finding (§d-4): the planned csrf probe (grep `name="csrf_token"` on the block page) **does not discriminate** — the RUNNING v0.9.2 (csrf off) already emits 2 csrf_token fields on its block page. Probe needs redesign: config-key grep (safe), POST-without-token → 403 (real), or cookie double-submit check.
- **M13 (harvest verification)** — the 5 queue rows + 8 library entries landed at planning time, but the rows for landed work (allowlist batch, lock bump, extraDomains, csrf, devices) are NOT yet marked `[x]` — deliberate (work is in-tree but undeployed; marking done at M11 keeps the queue honest), needs a decision pass.
- **Formatting/lint verification after daemon amends** — my hand-written Nix went through amend-commits (hooks re-ran on amend, but the daemon-commit lint-bypass doctrine says re-run standalone); `nix fmt --no-update-lock-file -- --ci` + statix/deadnix standalone NOT yet run on the touched files.

## c) NOT STARTED ⬜

- **M11** USER deploy window (everything above goes live) + live probes + anchor check
- **M12** docs sweep: `dns-blocker-config.nix:14-17` stale recursion comment (T299 now in tree), AGENTS.md recursion/deployed-rev/tracking-dial paragraphs, blocklist count 25→23, runbook pointer
- **M14–M17** (W7): policies+shadow, trial blocklists+persistent cache dir, ECS (owner nod), h3 (UDP-443 check)
- **M18–M22** (W8): wrapper→upstream module migration (design/impl×2/verify/cutover) — sequenced LAST per guard #4
- **Push** — branch is many commits ahead (mine + parallel sessions'); nothing pushed this session

## d) TOTALLY FUCKED UP 💥 (all self-corrected, none landed as damage)

1. **Stale-store-derivation misdiagnosis**: I grepped mapping.json from the newest-by-mtime processed derivation (`2pvrlj5`) instead of the one the DEPLOYED config references (`4kf5v1q`) → wrongly concluded "posthog NOT blocked, live config-lie", built a narrative, THEN discovered both mappings show it blocked. The M02 wiring is still correct (belt), but the claim chain was wrong for ~10 minutes. **Rule reaffirmed: resolve the deployed config's OWN references, never `ls -td | head -1`.**
2. **`rg -rn` typo**: `-r` is ripgrep's REPLACE flag — `-rn "csrf"` replaced matches with "n", mangling output (`csrf_token`→`n_token`) and sending me grepping a nonexistent field. Cost: 3 wasted tool calls. **Never combine flags after `-r`.**
3. **extendModules listOf-concat oversight**: first test variant used plain `extraDomains = [ ]` which CONCATENATED with the host list (listOf merge semantics) — check failed on first build. Fixed with `mkForce`. This is the documented priority-gotcha class; I should have written mkForce from memory.
4. **Smoke probe design flaw (found by pre-validation, NOT yet fixed)**: grep-for-csrf_token-field phantom-greens — running csrf-OFF deployment already emits the field. Caught because I probed the live block page BEFORE writing the probe into the script. Redesign pending (§f-1).
5. **Plan-level miss (caught in execution)**: M02's delete-branch assumed extraDomains was data-free; the data + dual-host inheritance was discoverable at planning time. The F09 precondition ("confirms no other consumer") did its job — but the plan should have run it.

## e) WHAT TO IMPROVE

- **Probe discrimination before probe writing**: always run a candidate smoke assertion against BOTH the current-running and the to-be-deployed state (the 2-minute pre-validation caught §d-4; make it a habit for every new smoke check).
- **Realization chain is now cheap**: the `getContext`-drill for realizing writeText configs is 3 commands — wrap it as a snippet or fold it into the render test (already does this internally).
- **Commit cadence vs daemon**: 4/4 commits daemon-swept. Amend-forward works but costs a verify+amend cycle each time; consider committing immediately after each green eval rather than batching task-level.

## f) UP TO 50 NEXT THINGS (priority order)

**Immediate (pre-deploy):**

1. Redesign M10 csrf probe: config-key grep + POST-without-token→403 (the discriminating shape)
2. Write M10 smoke additions (allowlist wiring, devices render, csrf) + `bash -n` + commit
3. Run `nix fmt --no-update-lock-file -- --ci` over the tree; fix any drift on my files
4. Standalone statix/deadnix on `dns-blocker.nix`, `dns-blocker-config.nix`, `test-dns-blocker-render.nix` (daemon-amend lint doctrine)
5. Pre-build toplevel (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`) so the user deploy window hits a warm cache
6. Check if dnsblockd has a config-validate/dry-run CLI mode for pre-deploy binary acceptance of the new keys (devices/csrf/allowlist) — if yes, add to pre-deploy-check
7. Commit/mark plan file M01–M09 status (plan doc self-truth)

**M11 user window (deploy + live verify):**
8. USER: `nix run .#deploy` → anchor check (`readlink` both pointers, F43)
9. Verify allowlist persistence E2E: "Always allow" a domain → restart unit → allow survives
10. POST to /api/allow without csrf token → expect 403 (real csrf-active proof)
11. Dashboard walk: devices named in Top Clients, attribution working
12. Confirm pixel6 (.29) / lg-tv (.62) identity in dashboard activity (owner-confirm loop)
13. Verify DMS DnsStatsWidget unaffected by csrf (Bearer flow — reasoned safe, verify live)
14. `dig us.i.posthog.com @127.0.0.1` → block IP (belt now explicit)
15. Journal volume before/after (log-sampling effect on dnsblockd unit)
16. dnsblockd RSS baseline post-v0.9.3 (telemetry additions may shift memory)
17. Verify OIDC login flow with csrf on (dashboard forms)

**Post-deploy hygiene (W6):**
18. M12: fix `dns-blocker-config.nix:14-17` recursion comment (T299 landed in tree — forwarders now a choice, not a necessity)
19. M12: AGENTS.md dnsblockd section — deployed-rev claims (post-deploy: f625cfe), tracking-dial pointer, allowlist note
20. M12: blocklist count comment 25→23 in dns-blocker-config.nix header
21. M12: runbook pointer to the tracking-dial memo
22. M13: mark the 5 TODO queue rows `[x]` + prune to CHANGELOG per todo-system rules; update library entries
23. M13: verify queue/library non-drift (edit both surfaces)
24. Update deep-dive HTML report with a "landed" addendum + re-rate adoption (62 → ~75+)
25. Push (owner call — many unpushed commits incl. parallel sessions')

**W7 second wave (post-M11, paced):**
26. M14: policies option (name/groups/devices/block/allow/schedule) + shadow-mode probe doc
27. M15: `blocklist_trial_urls` + PERSISTENT `blocklist_cache_dir` + ReadWritePaths audit (PrivateTmp trap)
28. M16: ECS decision — owner nod pending (`dns_ecs_enabled` + /24; forwarders see client /24)
29. M17: h3 block pages (`tls_h3_enabled`) + UDP-443 firewall check
30. DHCP-lease discovery probe: `GET /api/devices/candidates` once devices are live (find uncovered leases)
31. Re-inventory LAN after a week (phone DHCP drift; pixel6 may move off .29)

**W8 migration (LAST, gated on stable W1–W7 surface):**
32. M18: option-by-option mapping table wrapper↔upstream module
33. M18: surface-preservation baseline (worktree eval of rendered YAML + unit text, stored JSON)
34. M19: consume upstream `services.dnsblockd` module, map W1–W7 keys
35. M20: re-add SystemNix overlays (whitelist pre-filter, attach-ip, harden/oomd/GOMEMLIMIT, sops CA)
36. M21: baseline set-compare + VM test (no paperless-/admin-class silent surface loss)
37. M22: USER cutover deploy + one-restart-cycle watch
38. Close `docs/todo/services.md:57` wrapper-duplication row after migration

**Already-tracked elsewhere (referenced, not duplicated):**
39. tracking.db hot-db wave (`docs/todo/storage.md`)
40. Orphaned 724 MB tracking DB cleanup `[blocked:user]`
41. Cached-/health + dashboard-auth live verifies `[blocked:user]`

**Watchlist / small:**
42. rpi3 parity decision: rate-limit + devices on the failover instance too (currently evo-x2-only by scope conservatism)
43. rpi3 runtime still on old lock until ITS next deploy — fine (failover role), but note in M12 docs
44. gatus: consider devices-attribution metric check once upstream exposes attributionRate as a metric
45. Consider `dns_cache_size` tuning after observing post-bump memory
46. If owner rejects METADATA_AND_DNS: evaluate BLOCKS_ONLY alternative (memo §)
47. Upstream: master-follow ratified by this bump — annotate `docs/todo/upstream.md` tag row with the FOD-green evidence
48. Upstream capability watch: policies/ECS/h3 all config-gated at f625cfe — no further lock prerequisites for W7
49. Add the master-vs-v0.9.3 delta note (F19) to the plan file's context block for the next executor
50. Consider a VM boot test of the new config shape (binary acceptance of devices/csrf keys) if no dry-run CLI exists (§f-6)

## g) UP TO 3 QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Device identities:** Is `192.168.1.29` (randomized WiFi MAC `2e:fd:a5:…`) really the Pixel 6, and `192.168.1.62` (Realtek NIC `00:e0:4c:…`) the LG TV? Both are inference-by-elimination and carry owner-confirm markers — wrong mapping means mis-attributed dashboard rows (harmless, fixable) but I cannot verify identity from the wire.
2. **Tracking dial (M09):** flip to `METADATA_AND_DNS` or stay on `METADATA_ONLY`? Memo at `docs/services/dnsblockd-tracking-dial.md` with my non-binding recommendation to flip — it gates the entire household-intelligence layer (Top Domains, Query Log, Likely-Broken Sites) and is a privacy stance only you can take.
3. **rpi3 parity:** should the failover DNS instance get the same rate-limit (50/100) + device registry when it next deploys, or stay minimal? (Its eval is green on the new lock; the question is stance, not feasibility.)

**Waiting for instructions.**
