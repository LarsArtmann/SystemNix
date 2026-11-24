# Attic Decommission (cache.home.lan) — Full Status, Live-Verified

**Session scope:** owner asked "should we delete cache.home.lan or make it worth it?" → evidence answered (pure cost) → owner ruled **"just remove it"** → full decommission executed, deployed, and live-verified this session.

**Pins:** session start HEAD `2414a16d4` (clean tree) · removal commit `cc4adb1e5` (daemon sweep, 23-file stat = exactly my change set, +19/−747) · deploy evaluated HEAD `6a5ecfdaf` → **gen-1029** (`gwfgxm1vy9`), 22:25:05 → 23:41:25 (4580s), exit 0.

---

## a) FULLY DONE

1. **Decision evidence (live-probed before touching anything):** server.db held exactly 1 cache (`monitor365`, created 2026-08-02) with **0 objects / 0 NARs / 0 chunks**; storage dir 0 bytes; `attic_storage_bytes 0` in metrics; CI push leg never existed (JWT token row open since 2026-08-21, `pipeline.md:85`); sole consumer evo-x2 (darwin never carried the substituter; native-host forgejo runner shares `/nix/store`); DAS-pool storage = fails under build storms (~7 incident sessions: DAS 502 waves, DNS chicken-and-egg deploy blocks, nix#3768 standing exposure).
2. **Repo removal complete** — deleted: `modules/nixos/services/attic.nix` (535 lines), `tests/test-attic.nix` (138), `docs/services/atticd.md`, `platforms/nixos/secrets/attic.yaml` (sops RS256 secret). Edited 19 more files: `configuration.nix` (enable block), `dns-local.nix` ("cache" subdomain), `lib/ports.nix` (8200), `deploy.sh` (provisioner list + comment: `atticd-storage-dir atticd-bootstrap` out), `snapshots.nix` (btrbk row + comment), `boot.nix`, `lib/default.nix`, `systemd.md`, `tests/{default,shared,test-gatus-patterns}.nix`, `post-deploy-check.sh` (Attic probe out, comment trimmed), `README.md` (row + counts), `FEATURES.md` (row → ❌ REMOVED + counts + stamp), `nix-flakes.md` (2 bullets), `storage.md` (layout), `agents/README.md`, `CHANGELOG.md` (entry), `integration-registry.md` (matrix re-spliced, 98→97 rows), `pipeline.md` (CI-token row → MOOT).
3. **Counts re-derived by eval and re-stamped:** nixosModules 157→**156**, gatus endpoints 321→**319** (Attic Binary Cache + Attic Storage Size registry checks), module files 163→162, helpers 6. `checks.doc-counts` green.
4. **Full eval battery GREEN:** `nix flake check --no-build --all-systems` → rc=0, "all checks passed" (captured once to `~/.cache/attic-removal/fc.log`) — covers doc-counts, registry-matrix-drift, features-drift (❌ REMOVED row accepted), sops key/recipient audits (attic.yaml removed in sync), port registry, tile coverage, negative-test lints.
5. **Deployed:** pre-deploy battery green (§0–§19, incl. §19 sops gate); gen-1029 anchored (`readlink /run/current-system` == `system-1029-link` == `gwfgxm1vy9`).
6. **Live removal verified:** `pgrep atticd` empty · port 8200 → connection refused (`000`) · `/etc/nix/nix.conf` 0 `cache.home.lan` hits · `/etc/caddy/caddyfile` 0 hits (catch-all 404 owns the name now) · integration-manifest has no attic entry · `/etc/systemd/system` carries no atticd unit files.
7. **One manual heal:** the switch removed atticd's unit file but **never stopped the running process** (see d1) — `sudo systemctl stop atticd.service` → rc 0, process gone, port free, `ActiveState=inactive`.
8. **Docs + queue hygiene:** CHANGELOG entry with the full evidence chain; CI-token row closed MOOT; **3 follow-ups self-harvested** (residue deletion → `docs/todo/storage.md` [blocked:root]; dnsblockd wildcard doctrine → `docs/todo/services.md` [ready]; removed-unit-process-survives-switch trap → `docs/todo/stability.md` [ready]) + matching `TODO_LIST.md` queue one-liners. `/tmp/attic-ro.db` (my 644-mode DB copy with the encrypted signing-key blob) cleaned via sudo.
9. **Foreign-session collision handled per doctrine:** the daemon swept my 23 files as `cc4adb1e5` (verified contents BEFORE any amend idea — foreign commits landed on top, so amend was forbidden anyway); my `post-deploy-check.sh` edits rode foreign commit `4972e397c` (same-file race) — verified present in HEAD.

## b) PARTIALLY DONE

1. **Residue deletion** — documented precisely (empty pool subvol + orphaned btrbk snapshots under `/mnt/pool/.snapshots` that are no longer managed since the row removal + 76 KB `/var/lib/atticd` sqlite), queued `[blocked:root]`, not executed (root-gated; trivially small).
2. **DNS name retirement** — config-side complete (0 cache records in the deployed `dnsblockd-config.yaml`), but the name still resolves → **not a defect**: the deployed config carries a `*.home.lan.` **wildcard** record (`dns_local_records`), so every name under home.lan resolves to the box; cache.home.lan now lands on Caddy's branded catch-all 404 — the same end state as every other retired vHost. The wildcard's existence contradicts the DOMAIN_LANGUAGE "no wildcard support" doctrine → queued as its own reconciliation row.
3. **Deploy-smoke reds classified but not driven to green** — forgejo-runner INACTIVE at settle (ordering-cycle drop class; the 5-min runner-ensure timer converges by design), llama-embeddings :8848 unreachable ×2 (on-demand socket-activation class; the llama.home.lan gateway itself passed 200), 4 failed units at settle (`audiblesync-backup-dir`, `browser-history-agent`, `inboxclean-sync` — known auth_expired, `rust-cache-gc`). Smoke ran under STORM MODE (io avg60 52% → "results unverified under load"). All are foreign-session/known-baseline scope; not probed further this session.

## c) NOT STARTED

- Successor binary-cache decision (attic-on-Samsung + CI push + sunset gate) — deliberately parked; my verdict was "don't bother unless a consumer appears." No row queued for revival; the clickhouse-giants row (`TODO_LIST.md:1310`) is better served by ccache/sccache regardless.
- Re-running post-deploy-check.sh to green after the storm settles (its own run during the deploy already produced the classified reds above).
- SigNoz/Gatus UI spot-check that the two attic checks actually vanished from the live status page (config-side absence is eval-proven; UI render unverified).

## d) TOTALLY FUCKED UP

1. **The switch orphaned atticd and neither the deploy nor my first probe round caught it.** stc removed the unit file (race-detector manifest listed it `[R.]`) but the running process (PID 1372403, started 22:33:43 mid-build — restart trigger unproven, candidates: pre-switch unit churn by the 21:20 foreign deploy window or a pool bounce) was never stopped: no Stopped journal line, systemd still tracked `active/running`, port 8200 bound. I initially read "Caddyfile clean + manifest clean + nix.conf clean" as success while the daemon was still live — only the second probe round (process + port + busctl ActiveState) exposed it. Caught and fixed same session (~15 min later), but the class is systemic: **the deploy's post-deploy smoke had zero coverage for "removed service must be DOWN"** — I had deleted the only probe that would have failed (the Attic probe), and nothing replaced it with a removal-direction check. Queued as a stability row.
2. **Wrong verification instrument, first round:** I probed `getent hosts cache.home.lan` and flagged "DNS resolves (BAD)" — meaningless, because the `*.home.lan.` wildcard resolves every name (including every live service). Name resolution is not a service-liveness probe on this box. Corrected to direct service probes (dig to the resolver for record-level truth + port/process for the service). The wrong reading briefly pointed at a "DNS residue" that doesn't exist.
3. **`/tmp/attic-ro.db` sat world-readable (644) for ~2 hours** with the cache's encrypted signing-key blob inside — created by my sudo cp during DB inspection, forgotten until the report pass. Cleaned. Small, but it's exactly the hygiene class the repo's secret rules exist for.

## e) WHAT WE SHOULD IMPROVE

- **Removal-direction verification is a first-class gap:** post-deploy-check has dozens of "service must be UP" legs and zero "removed service must be DOWN" legs. A generic leg (for a declared removed-list: unit file absent AND process absent AND port free) would have caught d1 automatically.
- **stc stop reliability under load is unproven:** a running unit can lose its file while the process survives a switch. Any deploy that removes a service should end with a process-level probe, not a manifest read.
- **Probe design rule (now learned):** on a wildcard-DNS fleet, name resolution proves nothing — probe records (dig to the resolver) for DNS truth and process/port for service truth.
- **The `dns_local_records` wildcard vs `localSubdomains` doctrine split** needs one owner decision, then DOMAIN_LANGUAGE/dnsblockd.md reconciliation — right now the docs describe a resolver that no longer matches the deployed config.
- **Daemon-sweep discipline held, but only because I checked:** `git show --stat` before ANY amend thought, foreign commits on top forbidding amend entirely, same-file race with a foreign session resolved by reading HEAD instead of assuming. The 2026-11-10/15 rules earned their keep — keep doing all three checks on every sweep.
- **Evidence-reporting rule:** "deploy exited 0" ≠ "decommission complete" — the live-state probe set (process/port/config/manifest/DNS-record) is the actual receipt. This report's §a.6 is the template.

## f) NEXT ITEMS (grouped, most concrete first)

**Attic tail (mine):**
1. Delete the attic residue at the next root window: `/mnt/pool/services/atticd` subvol + its orphaned `/mnt/pool/.snapshots/*atticd*` snapshots + `/var/lib/atticd` (queued [blocked:root]).
2. Spot-check the Gatus UI: "Attic Binary Cache" + "Attic Storage Size" checks gone, no orphaned red alert episodes lingering in PapDashboard/Discord history.
3. Verify the removal commit + report rode clean daemon sweeps (my integration-registry paste landed; TODO rows formatted so `check-todo-system.sh` passes at commit time).

**New findings from this session (queued):**
4. Reconcile the dnsblockd wildcard doctrine (deployed `*.home.lan.` record answers; DOMAIN_LANGUAGE says wildcards unsupported) → decide: retire localSubdomains or document the wildcard as belt-and-suspenders.
5. Pin the removed-unit-process-survives-switch trap + add a "removed service must be DOWN" post-deploy-check leg (unit absent + process absent + port free for a declared removed-list).
6. Explain the 22:33:43 atticd restart (mid-build, unattributed) — check whether the 21:20 foreign deploy window or a pool bounce restarted it; feeds the stc-trap row with a mechanism.

**Deploy-smoke reds observed tonight (foreign/known-baseline scope — listed for their owners):**
7. forgejo-runner-evo-x2 INACTIVE at settle — confirm the 5-min runner-ensure timer converged it post-storm.
8. llama-embeddings :8848 unreachable ×2 — on-demand class vs real outage; one journal read settles it.
9. `audiblesync-backup-dir` failed both pre- and post-deploy — pool leaf creator failing while the pool is up; investigate.
10. `rust-cache-gc` failed — the rust-cache wave's GC; journal read (freeze-60-63 wave is fresh, this may be its first real run).
11. `browser-history-agent` + `inboxclean-sync` failed units at settle — known classes (auth_expired runbook is owner-gated).
12. Pre-deploy §6 showed 6 failed units (`crm-alarm-byphone`, `forgejo-github-sync`, `post-crash-calm-gate`, `service-health-check` included) — confirm post-switch state of the four that vanished from the post-switch list.
13. Null-byte command-substitution WARNs in post-deploy-check (lines 149/968) — already-queued residual-WARN row; still open.
14. Polkit QML "module fusion is not installed" journal lines outside deployed units — foreign session's new observation-style leg; watch it doesn't regress to FAIL.

**Docs/queue hygiene flowing from this session:**
15. Next prune pass: my `[x]` MOOT row (pipeline.md) + the 2026-11-24 done-row batch will unmask pairing WARNs — expect the count to rise, recount into the drift row.
16. FEATURES.md ❌ REMOVED row for Attic should get a sibling ❌ REMOVED row treatment check during the next features-drift sweep (legend says 🚫 for removed; ❌ is the Ollama precedent — one canonical emoji would end the split).
17. docs/DOMAIN_LANGUAGE.md needs the wildcard decision folded in once row #4 lands.
18. `docs/archive/nix-binary-cache-setup.md` still documents attic setup — archive is history, but a one-line "REMOVED 2026-11-24" banner would prevent a future session from following it.
19. Gatus endpoint count stamp (319) is point-in-time — the next foreign endpoint wave must re-stamp as usual (doc-counts will catch).

**Older standing items I touched or confirmed still open:**
20. CI-token/successor-cache: only revisit if a concrete consumer appears (signoz-frontend 122 MiB, hermes uv2nix tree remain unpumped by design).
21. Clickhouse-class rebuild pain across nixpkgs bumps — ccache/sccache direction (`TODO_LIST.md:1310`), NOT a binary cache; needs the owner account decision it's blocked on.
22. Pool-bound MULTI-oneshot classification eval audit (my 2026-11-24 tq sweep follow-up, row `services.md:1271`) — still [ready], unaffected by attic removal (atticd-bootstrap left the classified set cleanly).
23. boot-mirror path-unit fix wave (upstream RemainAfterExit + re-float + deploy + live proof) — pending upstream, unrelated but reminded by tonight's gen-install.
24. Journal-vacuum §15 evidence gate held green tonight — nothing to do, recorded as baseline.

(24 items listed — honest count; padding to 50 would fabricate work.)

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **Residue deletion timing:** delete the empty attic subvol + orphaned snapshots + `/var/lib/atticd` at the next root window, or keep them ~30 days as rollback residue in case the removal needs reverting?
2. **dnsblockd wildcard doctrine:** the deployed config answers `*.home.lan` via a wildcard record while the docs say wildcards are unsupported and `localSubdomains` enumerates names. Is the wildcard an intentional belt (keep + document), or did upstream gain wildcard support (then I should retire localSubdomains doctrine deliberately)?
3. **Deploy-smoke reds:** forgejo-runner INACTIVE at settle and llama-embeddings :8848 down — do you want a follow-up dispatch to drive them to green tonight, or are they accepted baseline (runner-ensure convergence + on-demand llama) until the next session?
