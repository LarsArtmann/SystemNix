# 2026-11-13 14:40 — deploy #3 LANDED: gen-1005 live, fixes re-verified, smoke attributed

## a) Task & verdict

Task: unblock and land the owner-fired `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` (fired 01:29; blocked by the W3b session's flock holder, then by two stale FOD hashes across deploys #1/#2 — see the 09:41 report).

**Verdict: LANDED + ANCHORED + VERIFIED.** Deploy #3 fired 10:25:02 (`/var/log/systemnix-deploys/2026-11-13_10-25-02.log`), switched 10:31, gen **system-1005** (`d825m2l3`) equals `readlink /run/current-system` (verified against the newest generation BY NUMBER), deploy process tree fully drained. nh build clean (store warm from the 10:00–10:23 toplevel `--keep-going` sweep, SWEEP_EXIT=0). The deploy exited 3 on smoke (11 NEW-vs-baseline FAILs during the IO-storm window); the 14:0x re-run shows **170 PASS / 6 FAIL / 0 storm-suspect**, and all 6 are attributed below — **no deploy-caused regression found**.

## b) What the payload carried

- **cv re-lock** `a57378a1e→066f76c79` (upstream re-measured its go-modules vendorHash; FOD probed rc=0 before the deploy).
- **project-meta vendorHash shim** `hmFRcgHq→TQB8jwNI` (`lib/lars-packages.nix` RE-STALE comment with first-hand deploy-#2 log evidence; driver = input float `50770ad5→63fcf0ff`, revCount 906→908, upstream lastModified 2026-11-12 — source churn, not toolchain; the nixpkgs pin f4a03c00 is static).
- **openseo GSC cloud-alias** (`BETTER_AUTH_URL=https://seo.larsartmann.cloud` — the foreign session's complete, report-designated work; live-verified in the rendered unit post-deploy).
- Parallel sessions' work: wifi-failover test arg fix, cvagent AI wave (new unit), tq item-4 rescue (592592293).

Both vendorHash fixes were swept into auto-commit-daemon commits mixed with foreign-session files (14b47131b et al.); content verified committed at HEAD (`git grep TQB8jwNI/066f76c`).

## c) Blockers resolved en route

- **Deploy lock**: W3b holder died on its own; flock free (stale record PID only).
- **10:06 foreign deploy attempt**: died at the memory-pressure gate code=12 (no `=2` override). Its log names the corpse-pile phantom signature (io_uring CQ-waiters in ghostty scopes, IO PSI 37% with IDLE disks, nvme util ≤25%) — that session owns the retry.
- **FOD treadmill**: the §11 battery had **0 mentions** of both stale FODs (cv's FOD = **4th instance** of the pipeline.md row-60 blindness — appended this session); the toplevel `--keep-going` sweep was the working enumerator, per doctrine row 338.

## d) Mistakes owned

1. After the cv fix I skipped the mandated `--keep-going` enumeration → deploy #2 burned a full battery cycle on the next stale FOD (meta). Done late, but done (rc=0 sweep).
2. Fired deploy #3 without pre-committing the two fixes (handoff step); the daemon swept them mid-arc. Worked out; content verified at HEAD.
3. **Runner "orphaned ≥3 days" claim was PHANTOM**: I probed journalctl/busctl with the unit name minus its literal `\x2d` (`escapeSystemdPath("evo-x2")` bakes the backslash INTO the unit name; the dbus object path additionally escapes `\`→`_5c` — `forgejo_2drunner_2devo_5cx2dx2_2eservice`). True state: runner ACTIVE since 11:35:33, ensure timer active and converging every 5 min (keep-alive Finished 14:25:39, 14:30:39). The 10:33 smoke FAIL was a real but transient drop (stopped 11:32:50 by a mount/recovery stop, converged by design 11:35:33). Empty reads are never evidence — re-learned with unit-name escaping.

## e) Verification ledger (live 14:0x–14:3x)

| Surface | Verdict |
| --- | --- |
| Anchor | system-1005-link → `d825m2l3` = `/run/current-system`; newest gen by NUMBER; process tree drained |
| Smoke re-run | 170 PASS / 6 FAIL / 5 SKIP / 0 STORM-SUSPECT (was 11 FAIL at 10:33) |
| cv-server | ACTIVE, uptime 3h39m+, `/health` 200 (45 checks, warn) — the documented SIGSEGV crash-loop class did **NOT** fire (owner Q2 moot); the 10:33 CV smoke trio was settle-time |
| Loaned metrics | psi.prom `node_psi_scrape_errors 0` (file fresh 14:09:36); `system_psi_metrics_fresh 1` |
| SigNoz rules | v3 live: `data.total` = **61**, exact-set; several rules legitimately FIRING (alerts work end-to-end). `/api/v1/rules` serves SPA HTML — provisioner (`RULES_PATH` v1, tracked row) + smoke probe (new row) both stale-surface |
| Payload daemons | cv-server, crm-server (10:33's 502 healed), monitor365, bank-sync, discordsync, openseo all ACTIVE |
| Hub 503 drivers | cvagent `/health` 503 = known row 745 (serve env lacks git; ai+db checks pass) + the W3b read-loop row; nsfw remote 000 = unit inactive, no journal ≥2d (pre-existing idle) |
| Self-healed oneshots | cv-scan, bank-sync-qonto-corpus, post-crash-calm-gate → Result=success via timers |
| Pre-existing reds | forgejo-github-sync (dnsblockd PULL-mirror refusal gate, services.md:1086, 72 refusals/3d); inboxclean-sync (Gmail 429 quota loop, 536/3d — new watch row); service-health-check fails BY DESIGN while those two are red |
| Borg tripwire smoke FAIL | script path-shape bug: the derivation outputs a flat 417-byte executable FILE; the smoke probes `<path>/bin/<name>` → ENOTDIR. `test -x <path>` verified green → false FAIL, new pipeline row |

## f) §f follow-ups — HARVEST LEDGER (all landed this session)

1. post-deploy-check.sh SigNoz v1 probe → **monitoring.md EOF row + TODO_LIST twin** `[ready]` — MINTED.
2. borg tripwire smoke path-shape fix → **pipeline.md EOF row + TODO_LIST twin** `[ready]` — MINTED.
3. inboxclean-sync 429 loop → **services.md EOF row** `[watch]` (domain-library only per TODO system) — MINTED.
4. §11 blindness 4th instance (cv FOD) → **appended to pipeline.md row 60 + TODO_LIST:1223 twin** — DONE.
5. cvagent 503 → row 745 (git-on-PATH) + W3b read-loop row already own it; AI-wave battery = row 747 (its session). No new row.
6. signoz-provisioner v1 RULES_PATH → TODO_LIST jq-parse row already root-caused it. No new row.
7. forgejo-github-sync dnsblockd gate → services.md:1086 already owns it. No new row.
8. bank-sync SCA → existing SCA rows own the owner-gated approval; this deploy's `bank_sync_sync_errors_total > 0` is the degraded-fallback WARN path, not a new failure class. No new row.
9. cv-server crash-loop → did not fire; no row (owner Q2 answered below).
10. Deliberately NOT harvested: the 10:06 foreign deploy pressure-gate death (its session owns the retry; the gate's own log documents the phantom class).

## g) Owner questions from the 09:41 report — status

1. **meta re-pin vs hold** → MOOT: the hash was SystemNix-side (our consumer shim), fixed per the file's protocol with first-hand evidence. No upstream dependency, no ruling needed.
2. **cv-server restart-into-crash-loop** → DID NOT FIRE: 3h39m+ uptime, `/health` 200. cv units stayed in the payload; correct call.
3. **W3b §f.1–3 close-out** → still deferred to the W3b session (unanswered).

**Scope line**: everything in §e was live-verified this session (busctl/journalctl/curl-in-harness/psi.prom reads); nothing above is config-cite-only except where marked as rows owned elsewhere.
