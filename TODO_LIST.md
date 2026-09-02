# SystemNix TODO List

**Updated:** 2026-08-31 (docs-health AUDIT: full 2026-08 harvest from the 08-26→08-31 reports; ~45 completed items removed to CHANGELOG; DAS-recovery sweep collapsed post-recovery; new rows: Samsung migration, freeze-#3 follow-ups, docker-prune rework, niri-session-manager upstream, KNOWN_NEW_METRICS retirement, prevention-layer gaps)

---

## Priority 0: Critical (Data Loss / System Risk)

- [ ] **/data corruption repair (1.3MB, 22 extents, 3 windows ~595G + ~627-639G) — the ONLY backup tier that has NEVER completed pool-side** — Weekly scrub 2026-08-17 found 1,351,271 uncorrectable csum errors; aborts `btrfs send` → btrbk-data dead since 2026-07 (re-confirmed 2026-08-31 17:02: full re-send failed EIO again, `btrbk-pool-clean` correctly removed both incomplete receives). **User decisions:** aggressive posture (minimal fix + read-only `btrfs check --mode=low-risk` in a docker-down window), monitor365 DuckDB on /data NOT disposable (safety-copy 54G to pool archive first), reserve after triage. Plan: `docs/planning/2026-08-17_14-41_data-corruption-recovery-pool-completion-master-plan.md` (T04-T08). **Stance:** keep btrbk-data failing until T04-T08 executes — the failure IS the tripwire.
- [ ] **BTRFS root chunk-unalloc — gate CLEARED 2026-09-02: `btrfs filesystem usage /` shows 222.41 GiB unallocated, meta 81.6% (<90% block)** — both scheduled balance jobs self-skipped correctly during the DAS/freeze era; the 2026-08-31 gawk fix (exit-127 class, dead for a week) restored them; the run-and-recheck evidently completed since. Remaining from old item: the reserve file's extents are snapshot-pinned — either a periodic rewrite timer or a documented pinning caveat in AGENTS.md (plan T14). Re-check unalloc >10G stays the safety gate before any space-hungry op. **Source:** `docs/status/2026-08-31_20-02_disk-review-samsung-assignment-nix-fs-research.md` §f.3/7
- [ ] **Google Sync go-live (user steps; module built 2026-08-17, ships disabled) or mark it DORMANT in AGENTS** — `services.google-sync` mirrors ALL THREE remotes every 5 min (30d deletion-grace): `gdrive` (~1.9 TB), `gdrive-shared`, `gwork`. Blocked on: (1) Google Cloud OAuth client (Drive API, publishing status "In production"), (2) `rclone authorize "drive"` once per account, (3) fill the sops scaffold (`platforms/nixos/secrets/google-sync.yaml`, 3-remote placeholder), (4) flip enable + deploy, (5) verify the 1.9 TB seed. The AGENTS procedure text currently reads as if live — either go-live or annotate dormant (2026-08-31 finding: no units deployed at all). **Source:** `docs/status/2026-08-31_16-29_das-pool-recovery-backup-catchup-self-review.md` §e.6
- [ ] **Off-site backup decision (3rd copy)** — pool safety net live; the copy never leaves the house. Decide: 3-2-1 satisfied via Google Photos/Drive, periodic sdf (WOOACME) vault rotation, or Hetzner StorageBox + Borg (`docs/research/hetzner-storagebox-borgbackup.md`). Flagged since 2026-06-25.
- [ ] **🔑 PERSISTENT NAG: rotate leaked/stale API keys** — (1) **Resend key in sops is REVOKED → Pocket ID email BROKEN** (rotate at resend.com, `sops --set` per AGENTS Sops section, redeploy; the SAME new key also completes the Mail Relay go-live, P1 below); (2) Synthetic key live-assumed; (3) Context7 `ctx7sk-…` VERIFIED LIVE 2026-08-18 — rotate + update MCP config. Rotation is the entire fix (history-purge push HELD by user decision). **Source:** AGENTS.md "Secret Leak Incident"
- [ ] **Reboot into kernel 7.2.2 + FastFlowLM v1.0.3 retry (USER-gated; kills all sessions)** — `/run/booted-system` (7.2.0) ≠ `/run/current-system` (7.2.2) until reboot. After reboot: verify booted==current (rollback-generation class), retry flm v1.0.3 (wrapper LD_LIBRARY_PATH fix landed for the XRT 2.25 dlopen path; diff 7.2.0→7.2.2 amdxdna ABI first), expect one-time 21.6 GB `flm pull` (Q4_K weights), live `flm serve` validation, revert if enumeration still fails; file the XRT-2.25/kernel-7.2.0 upstream issue (verify-before-filing). Also: flm module retune for v1.0.3 (MemoryMax 40G/32G sized for Q4_1; Q4_K size unverified; smoke timeout assumptions). **Source:** `docs/status/2026-08-31_18-44_startup-error-review-boot-fixes-self-review.md` §f.1-5, `18-45_cv-vendorhash` §b.1
- [ ] **Turso plan decision — DiscordSync cloud sync DOWN since 2026-08-16** — quota exhausted; local SQLite healthy, the CLOUD OFFSITE copy is stale. Keep sqlite-only (remove sync env/keys), re-auth, or upgrade. The journal still logs `quota_exceeded` hourly. **Source:** `docs/status/2026-08-26_06-06_*` §g.1
- [ ] **Add `ManagedOOMPreference=omit` to dnsblockd** — sole DNS resolver on :53, was killed 730x/day pre-mitigation. Mitigations live (MemoryMax 4G, GOMEMLIMIT 3GiB); exemption is the proper fix.

## Priority 1: High (Service Outages / Security)

- [ ] **SigNoz upstream trace-instrumentation gaps — flip `wiring = "upstream"` → enforced as each lands (6 binaries)** — (1) **dnsblockd**: scheme-aware OTLP fix APPLIED in the checkout (builds + tests green); REMAINING: push + tag + relock (+ vendorHash), flip wiring to `"config"`. (2) **bank-sync**: OTLP added upstream 2026-08-31; REMAINING: push + tag + relock, flip to `"env"`. (3) **overview** + (4) **projects-management-automation**: TracerProvider wired, ZERO span sites. (5) **papdashboard**: metrics only. (6) **hermes**: Python SDK not wired. Live via `signoz_traces_upstream_gaps` (:9100/metrics). **Source:** 2026-08-31 coverage audit
- [ ] **website-deploy-monitor + the 4 other long-failed units: per-unit triage (never done)** — the "known DAS class" group-label was never verified per-unit; `website-deploy-monitor` (larsartmann.com freshness) could be a REAL staleness signal, `disk-growth-check` (/data, NVMe) and `btrfs-verify-snapshots` (root chain) are NOT pool-dependent. Group-labeling without triage is the phantom-green thinking the repo documents. **Source:** `docs/status/2026-08-30_11-15_deploy-unblocked-narhash-vendorhash-email-state.md` §d.3/§f.6
- [ ] **KNOWN_NEW_METRICS retirement sweep — now actionable post-DAS-return (11 entries, each masking phantom-metric regressions)** — `bank_sync_sync_errors_total` + `bank_sync_last_sync_timestamp_seconds` (were "blocked on first post-DAS deploy" — that deploy HAPPENED 2026-08-31, 83 PASS/0 FAIL incl. bank-sync vHosts), `system_dnsblockd_metrics_fresh` (confirmed PRESENT in §10 on 08-30 while still allowlisted), `discordsync_projection_dlq_legacy_unchanged` (check :8085/metrics, then retire). Plus the structural fix: self-cleaning allowlist (flag entries already present in /metrics) + auto-derive new-metrics from the gatus-config diff instead of the manual list. **Source:** `docs/status/2026-08-30_11-15_*` §c.2/§f.3-5, `2026-08-26_06-06_*` §f.2
- [ ] **niri-session-manager upstream fixes + tag + flake input bump (LarsArtmann repo)** — the 2026-08-31 terminal-storm root cause is upstream (v0.3.0): (1) restore re-runs on EVERY process start under `Restart=always`; (2) save does not dedupe same-pid single-instance surfaces; (3) `terminal_state: null` terminals restored as empty shells (the growth loop); plus: sanity cap on restore count, skip transient/dialog app-ids at save, capture shell cwd, warn when restoring N>10 same-app windows. SystemNix config mitigation (ghostty in `single_instance_apps`) is deployed; upstream is the cure. Interim until the restore-once gate lands: consider `Restart=on-failure` + tight burst on the manager unit. **Source:** `docs/status/2026-08-31_15-11_niri-login-terminal-storm-root-cause-and-fix.md` §7/§f.3-10
- [ ] **Rogue git-identity audit across all repos + declarative global identity** — foreign author identities in PMA-managed histories; 162 Crush-authored commits under an ad-hoc identity. (1) audit `~/projects`; (2) declarative identity everywhere; (3) user decision: rewrite history or leave. **Source:** `docs/status/2026-08-18_13-53_*` §b/§f
- [ ] **Sweep ALL LarsArtmann Go repos for `InvokeNamed[interface]` on concrete `do` registrations** — the samber/do trap that took DiscordSync down 2 days. **Source:** `docs/status/2026-08-18_02-27_*` §f.28
- [ ] **IO-PSI is phantom-saturated by D-state tasks on dead automounts — deploy gate + gatus can lie (crash3)** — correlate PSI with disk %util in deploy.sh's pressure read + gatus PSI conditions; the deploy pressure gate should ALSO check IO PSI some avg10 ≥20% (memory-only gate let an 78-80% IO-PSI deploy through on 2026-08-31 — got lucky); fail-fast/timeout-bound remaining automount probing. **Source:** `docs/status/2026-08-24_08-00_crash3-*` §e1/§f.12-14, `2026-08-31_18-44_*` §d.2/§f.11
- [ ] **IO-PSI emergency guard tier (freeze #3 class is un-prevented)** — Zones 4/5 cover memory-PSI; crash #3's sustained IO-PSI-with-healthy-memory needs a Zone that stops churn sources (balance, flm cold loads, clickhouse merges) before the kernel dies. **Source:** crash3 report §c6/§f.15
- [ ] **Niri gatus endpoints false-negative during hard-down (sddm incident)** — niri liveness stayed GREEN while the compositor was down through the whole 2026-08-24 window. Verify which conditions went stale, fix fail-closed. **Source:** `docs/status/2026-08-24_08-00_sddm-*` §b5/§f P1
- [ ] **Post-DAS-recovery convergence watch (final leg)** — verified done 2026-08-31: pool mounted by-label both members zero device errors, dump backups green at boot catch-up, post-deploy-check 83 PASS / 0 FAIL, btrbk-data correctly re-failing (EIO P0 above). REMAINING: confirm tonight's 23:00 root incremental received pool-side + `btrfs-verify-pool-backups` + `backup_all_healthy` flip green; check bank-sync's 9-day Wise gap backfilled (journal sync-failure count → 0); no lingering outage-era reds in Gatus. **Source:** `docs/status/2026-08-31_16-29_*` §f.2/21-22
- [ ] **btrbk-data oom-kill containment (2nd failure mode beside the EIO)** — nightly send died `oom-kill` (page cache charged to the unit cgroup, 20.6G peak). `MemoryHigh` + `OOMScoreAdjust` sizing, or split the send. **Source:** `docs/status/2026-08-21_23-35_*` §e1/§f.9
- [ ] **dnsblockd `/health` wedges on SQLite starvation while DNS :53 stays fine** — move `/health` off the DB (lock-free path) so a wedged dashboard doesn't fail the wrong signal. Related: the :9090 wedge root cause is STILL UNKNOWN (instance healed 2026-08-27 by restart; GOTRACEBACK=all + `scripts/dnsblockd-goroutine-dump.sh` runbook armed — SIGQUIT the NEXT wedged instance before any restart). **Source:** 23-35 report §c/§e.4, AGENTS dnsblockd section
- [ ] **BuildFlow fallback caches: 11.3 GB on the QLC root + reap-list gap (user decision + code half)** — USER: keep vs quarantine. CODE: extend the `buildcache-usb-recovery` reap list once decided. **Source:** `docs/status/2026-08-22_17-31_*` §c2/c3
- [ ] **Attic-class follow-ups from the exit-4 fix** — (1) sweep OTHER `wantedBy=multi-user.target` oneshots with mount-gated deps for the `ConditionPathIsDirectory` skip treatment; (2) collapse dependency-cascade FAILs in post-deploy-check into one root-cause SKIP; (3) VM test for pool-mounted-but-atticd-wedged. [(4) python3 probe dedupe DONE 2026-08-26] **Source:** attic 08-04 report §e/f.18-22
- [ ] **Boot-generation-freshness gatus/sev1 check** — `system_current_system_profiled` metric exists (system-health); still missing: the Gatus/sev1-side check that the BOOTED system matches the newest profile (deploy.sh print can't cover the reboot-into-stale case — live again with the pending 7.2.2 reboot). **Source:** crash3 report §f.8
- [ ] **Forgejo upstream: file the 3 verified mirror-outage issues** — dead-queue silence, TouchMirror masking failures, ENOENT aborts of clone credential helpers (verify against CURRENT upstream main first). **Source:** `docs/status/2026-08-22_08-52_*` §b2/§c
- [ ] **Mail Relay go-live (user steps; module built + enabled with PLACEHOLDER credential 2026-09-02)** — central Postfix null client on 127.0.0.1:25 → Resend submission (`services.mail-relay`); paperless + forgejo + system mail wired and relay-gated. Sending domain DECIDED 2026-09-02: `noreply@larsartmann.cloud` (already the module default). Until go-live every send defers in the mailq (inert, nothing crashes) and the Gatus "Mail Relay Queue" check fires as the pending signal (by design). Steps (runbook `docs/services/mail-relay.md`): (1) new Resend API key (same key fixes Pocket ID, see PERSISTENT NAG), (2) verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM), (3) `sudo sops platforms/nixos/secrets/mail-relay.yaml` (replace `mail_relay_password` PLACEHOLDER) + restart postfix, (4) sendmail E2E test + paperless share-link test, (5) optionally set Immich SMTP in its admin UI (127.0.0.1:25, no auth), (6) ~~decide the Paperless INBOUND mailbox~~ ANSWERED 2026-09-02 for Gmail: attachment archiving rides InboxClean (OAuth, no app passwords — see the InboxClean→Paperless go-live item); native mail rules stay reserved for a future scanner/forwarding mailbox. **Source:** mail-relay session 2026-09-02
- [x] **InboxClean → Paperless archiving go-live — DONE 2026-09-02** — token provisioned (`paperless-manage drf_create_token admin`), pasted into `platforms/nixos/secrets/inboxclean-paperless.yaml`, `paperless.enable = true` flipped + deployed. NOTE for future rotations: `sudo sops` must run FROM the repo root (`.sops.yaml` discovery is CWD-based); rotate via `sudo sops platforms/nixos/secrets/inboxclean-paperless.yaml` + redeploy (the sops template's `restartUnits` restarts both inboxclean units). **Source:** inboxclean-paperless session 2026-09-02
- [x] **Mail relay hardening finish (DONE 2026-09-02 evening)** — "Mail Relay Queue" Gatus check re-applied (anchored value-0 + presence conditions, placeholder-aware alert); `tests/test-mail-relay.nix` shipped + registered (loopback-only :25, 220 banner, null-client postconf asserts, sendmail E2E proving sender AND recipient canonical rewrite before queuing, collector fail-closed); post-deploy §12 (active/banner/placeholder-WARN/paperless.conf/collector); docs updated. Bonus fix found by the test work: system-mail recipients need `recipient_canonical_maps` — aliases(5) is inert on a null client. **Source:** mail-relay session 2026-09-02
- [ ] **Verify Paperless AI actually USES the llama-rag embeddings end-to-end** — UI-saved values override env; check the effective embedding endpoint; wire `PAPERLESS_AI_LLM_RERANKER_*` if supported. **Source:** `docs/status/2026-08-20_08-06_*` §g.1/§f.2
- [ ] **Hermes post-deploy smoke: Discord gateway connectivity line** — journal assertion for the gateway-ready line within N minutes. **Source:** hermes 08-21 §f.7
- [ ] **Verify the browser-history registration gate is LIVE in the deployed binary** — verify `POST /auth/register` 403s logged-out + second Pocket ID first-login rejected LIVE; finish the chain (tag → flake bump → deploy) if still a no-op. **Source:** archived 08-15 01-44 §b.1
- [ ] **Gate `import_export.go` user-import path (registration lock hole #3)** — cqrs-htmx `importUsers()` bypasses MaxUsers + the mutex. ~15-min upstream fix. **Source:** archived 08-14 10-41
- [ ] **PMA discovery daemon starvation — upstream root cause** — SystemNix mitigations deployed; the fix belongs upstream. Also unquoted `GIT_AUTHOR_NAME` env entries upstream. **Source:** 2026-08-14 buildcache session
- [ ] **Monitor365 re-enable decision (G7)** — publish crate / make repo public / vendor / or remove the module. **Source:** archived 08-15 01-44 §g G7

## Priority 1.5: Prevention-Layer Gaps (2026-08-26→31 harvest)

- [ ] **CI must EXECUTE the trap-lint derivations (gatus-pattern-lint, signoz-query-lint)** — CI runs `nix flake check --no-build` (eval-only); a `--no-verify` or foreign-machine commit passes with a dead-at-runtime lint. Add a CI step `nix build .#checks.x86_64-linux.gatus-pattern-lint signoz-query-lint …`. **Source:** `docs/status/2026-08-27_18-58_*` §b.3/§f.1
- [ ] **shellcheck pre-commit for `scripts/*.sh` + unit-script binary-coverage lint** — the awk/gawk exit-127 phantom class has now bitten TWICE (btrfs-verify 08-18, BOTH balance services 08-25→31 dead a week). Static check: every binary a unit script execs must be in `path`/`runtimeInputs`. **Source:** `docs/status/2026-08-28_04-51_*` §e.4/§f.10-11, AGENTS 2026-08-31 recurrence note
- [ ] **Pre-deploy batch build of mkLarsPackages + cv + hermes inputs** — the 2026-08-10 suggestion, still unwired; would have surfaced both 08-29 failures in seconds instead of a 12-min aborted deploy (recurring monthly class). Add a fast flake output (e.g. `.#quick-go`). **Source:** `docs/status/2026-08-29_17-29_*` §e.1/§f.18/46
- [ ] **Known-outage classification in post-deploy-check** — FAILs whose units are down from a documented absent dependency (pool detached) → WARN with reason; keep FAIL for true regressions (alarm-fatigue protection — 9 days of identical red desensitized everything). **Source:** `docs/status/2026-08-29_17-29_*` §e.3/§f.19
- [ ] **Eval-time audits for unit-shape contracts (the cv-226 class)** — (1) `ReadWritePaths` under `/mnt/pool` ⇒ `RequiresMountsFor` + a declared creator; (2) backup-related timers MUST set `Persistent=true` (flake check); precedent: `otel-endpoint-audit.nix`, `udev-block-letter-audit.nix`, `gate-timeout-audit.nix`. **Source:** `docs/status/2026-08-31_16-29_*` §e.1-2/§f.5-6, `17-22` §c.2-3
- [ ] **`backup_ever_succeeded` metric + backup-catchup report** — a never-worked backup is indistinguishable from a stale one (cv rode "all red" outage noise its whole life); emit MTIME≠0-gated gauge; `scripts/backup-catchup-report.sh` (stamps vs OnCalendar + prom diff + btrbk dry-run) to make the next outage a one-command review. **Source:** `docs/status/2026-08-31_16-29_*` §e.3-4/§f.15-16
- [ ] **btrbk receive-freshness + pool-snapshot-freshness monitoring** — `/mnt/pool/.snapshots/services/*` and the received root/data trees have no freshness gauges in `backups.prom` (only the daily 3d-threshold verify guard covers them). **Source:** `docs/status/2026-08-31_16-29_*` §f.17-18
- [ ] **Deferred-scrub observability + scrub-guard VM test** — the new scrub deferral guard is eval-verified only; a perpetually deferred scrub shows as never-finished red with no way to distinguish policy-deferral from breakage. Add `btrfs_scrub_deferred_total` + the VM test (fake btrbk in `activating` → defer). **Source:** `docs/status/2026-08-31_17-48_*` §b.4/§c.1-2
- [ ] **journald `SystemMaxUse` cap (2-3G) + repo-wide `journalctl` bounds audit** — the 7.2G journal fed the collector-stall sev1 page (11-28 min runs under a 128M cgroup); every journal counting query needs `--since` + `timeout`; audit monitor365-watchdog, niri-health-metrics, watchdogs, deploy scripts. Also: SIGPIPE/pipefail audit of collector pipelines. **Source:** `docs/status/2026-08-31_18-45_system-health-collector-stall-*` §f.4-8, AGENTS 08-31 gotcha
- [ ] **Surprise bulk `nix flake update` validation gate** — an unattended full lock update moved ~12 inputs at once and broke deploys (2026-08-29); gate bulk updates behind a validation build (wrapper or CI). **Source:** `docs/status/2026-08-29_17-29_*` §f.37-38
- [ ] **Zero-series sweep automation + provisioner-Result assertion generalization + GOTRACEBACK=all sweep** — (1) script diffing every metric name in rules/dashboards vs the ClickHouse time-series table (self-maintaining blocklist); (2) generalize the signoz-provision Result assertion to ALL deploy.sh provisioners (pocket-id, forgejo-oidc, …); (3) `GOTRACEBACK=all` on the remaining Go daemons (discordsync, browser-history). **Source:** `docs/status/2026-08-27_18-58_*` §e.1-4/8-9
- [ ] **Structural §10 fix: URL-aware phantom-metric extraction** — only `pat()` conditions on `/metrics` URLs should feed the metric-presence validator (the `email_state`/`connected` exclusion regex grows otherwise); plus regression tests: convergence-guard prefix comparison + JSON-field body-pattern case in `tests/test-gatus-patterns.nix`. **Source:** `docs/status/2026-08-30_11-15_*` §c.1/§e.3/§f.7/10-11
- [ ] **§11 vendorHash freshness: wire real FOD dry-run checks** — 6/6 Go pkgs report "unable to determine status" in pre-deploy-check §11; the class broke deploys twice in August. **Source:** `docs/status/2026-08-30_11-15_*` §f.19

## Priority 2: Manual Steps (Blocked on Human)

- [ ] **Post-BIOS memory re-baseline (rides the kernel-7.2.2/flm-v1.0.3 reboot, P0)** — user will "up the RAM - UMA Frame in the BIOS" (2026-09-02). AMBIGUITY to resolve at the BIOS screen: adding physical RAM (+total) vs raising the UMA carveout (−CPU-visible RAM, tightens zram margins — the OPPOSITE direction for the 97% zram problem). After reboot, re-measure and re-tune: `MemTotal` (baseline 98,363,656 kB ≈ 93.8 GB visible), zram disksize (28.2 GiB, sized to visible RAM — resize proportionally if MemTotal shifts materially), `system_zram_swap_fill_percent` steady state, MemAvailable baseline, memory-emergency-guard zone thresholds (percent semantics change with total), `system_crush_sessions` (was 26-27 all evening; decide monitor-only vs workload-admission cap if zram still >90% steady). Disposition context: `docs/planning/2026-09-02_19-13_*` T02 annotation (holders: flm 28 GB shmem + 26-27 crush sessions + clickhouse 3.8 GB + ~50 GB page cache; memory PSI 0.00% all evening — full-but-stable, episodic class covered by guard Zone 5).
- [ ] **Hermes PAT go-live (user)** — scaffold shipped 2026-08-20 (sops placeholder + `hermes-git-credential` + verify canary); REMAINING: create the fine-grained PAT (Contents: Read-only) and `sops --set` it — block in `docs/services/hermes.md`
- [ ] **Twenty: ENCRYPTION_KEY rotation decision + digest-pin `twenty-postgres`/`twenty-redis`** — v2.32.0 stable since 2026-08-31 → pinning now actionable. **Source:** 08-18 20-38 §c/§f
- [ ] **Hermes workspace strategy: revisit trigger** — DEFER decision (2026-08-20) stands; reopen when root >90% or workspace clones >20G
- [ ] **Paperless admin password handover** — change in UI (`paperless.home.lan`, admin/sops). **Source:** 08-17 00-59 §g.3
- [ ] **Browser-test the SigNoz UI + eyeball the 5 `systemnix-*` dashboards** — API-verified only; never rendered in a browser. **Source:** 08-16 23-27 §B.1
- [ ] **Runtime-verify wf-recorder screen recording on niri** — build-proven only. **Source:** 08-16 22-00 §c.1
- [ ] **Boot-resilience test: DAS powered off** — failed-but-contained btrbk units, NO root-fs contamination. (Largely proven live by the 9-day outage; the controlled test remains.) **Source:** 08-17 00-59 §f.11
- [ ] **`e2fsck -f /dev/sdc1` (buildcache) during the next unplug window** — fs took write errors in the 08-16 storm; mounted RW again since. **Source:** 08-16 18-39 §b
- [ ] **Satellite GOEXPERIMENT sweep (21 repos)** — `scripts/report-goexperiment-gaps.sh`; fix pattern: dnsblockd devShell. **Source:** SMART-BUILDCACHE-OVERHAUL §8
- [ ] **go-nix-helpers: default `GOEXPERIMENT=jsonv2` in template/devShell** + retire the direnv `use_go_env` sniffer once all satellites self-carry the flag
- [ ] **btrfs+zstd buildcache conversion (maintenance window)** — `scripts/buildcache-btrfs-convert.sh` (~2x capacity + checksums); decide keep-or-trash
- [ ] **Verify go-codec floor vs nixpkgs go (1.26.7)** — the loud-fail premise resolved with the nixpkgs bump; confirm and close
- [ ] **Smart-audio: verify audible output + reverse direction (incl. DP-2 cross-output path, never tested)** — test-tone tooling is on PATH since 08-22. **Source:** archived 08-14 08-24
- [ ] **Hermes: set fallback model** (`sudo -u hermes hermes config set fallback_model`)
- [ ] **Test browser-history OAuth2 login end-to-end** — `history.home.lan` → "Login with Pocket ID" → dashboard
- [ ] **Verify dnsblockd dashboard auth** — `dnsblock.home.lan/dashboard` with the sops token
- [ ] **WebAuthn `.lan` RP ID browser validation** — passkey registration on `history.home.lan`
- [ ] **MiniMax quota decision (carried ×5)** — upgrade / PAYG / wait for reset
- [ ] **Deploy to macOS** — darwin registry override written, NOT deployed
- [ ] **Clean up orphaned dnsblockd tracking DB** — `sudo trash /var/lib/dnsblockd/dnsblockd_tracking.db` (724 MB, Jul 15)
- [ ] **BIOS fix for DAS boot hang** — disable USB boot, Fast Boot, NVMe-only priority
- [ ] **Hermes upstream: propose `projectsDir` RO-bind pattern for the NixOS module** (verify-before-filing first)
- [ ] **Hermes: migrate `TERMINAL_CWD` → generated config.yaml when upstream supports it** (weak motivation since v0.20.4; blocked on upstream declarative config)
- [ ] **Promote `chown-vs-bind-audit` WARNING → FAILING** — shipped 08-20 with "after one clean CI cycle"; cycles have passed — flip `exit 0` → `exit 1` on `$warn`
- [ ] **Docker data-root relocation → folded into the Samsung migration** — old SanDisk-2 plan superseded by the ratified Samsung 1TB layout (`docs/planning/2026-08-31_samsung-role-assignment-first-principles.md` Rev 2); docker data-root moves with Phase 2
- [x] **profileProbe enable decision — RESOLVED 2026-08-30** (`profileProbe.enable = true` in configuration.nix, chromium closure accepted; weekly Mon 09:41 probe live, exit-3 → onFailure alert)
- [ ] **CV `evaluation.min_day_rate` value decision (user)** — upstream 2026-09-02 rate floor is wired and documented (docs/services/cv.md "Evaluation knobs") but UNSET in production settings. CV repo proposes 600 €/day (owner's 75 €/h goal × 8); its Q1 asks 600 vs 700. Once decided: set `settings.pipeline.evaluation.min_day_rate` in `cv.nix`, redeploy, then run the forced re-eval pass (paste-ready command in cv.md) to re-stamp ~755 stored apps. **Source:** CV 2026-09-02_20-40 rate-floor session
- [ ] **btop privileges + terminal-restore policy (user, niri-storm session)** — sudoers NOPASSWD vs unprivileged btop; restore ONE ghostty per login (current) vs ZERO (`skip_apps`). **Source:** `2026-08-31_15-11_*` §Q1-2
- [ ] **Docker volume prune policy (user)** — 126/130 orphan volumes (3.57 GB, 95% reclaimable); `docker volume prune` has NO age filter — enumerate + allowlist decision. **Source:** `2026-08-31_20-46_*` §g Q2
- [ ] **snapshot_preserve widening (user decision)** — 3d→7d local: the outage showed the NVMe rollback window collapses to zero while the pool is down (QLC space tradeoff). **Source:** `2026-08-31_16-29_*` §f.19
- [ ] **Deploy policy for foreign undeployed tree changes (user/team contract)** — (a) ship-as-is + smoke checks, (b) halt until owner deploys, or (c) ship + require diffstat acknowledgment (the flm-1.0.3 50-min NPU outage was case (a) going wrong). **Source:** `2026-08-31_18-44_*` §g.2
- [ ] **Immich/paperless DB integrity checks post-pool-return** — history of unclean USB removals; run before trusting the migrated DBs long-term. **Source:** `2026-08-29_17-29_*` §f.42

## Priority 2.5: Black-screen / Desktop follow-ups

- [x] **VM test: linger + SDDM login → exactly one niri, none pre-login** — done 2026-09-02: `tests/test-niri-session.nix` boots linger + SDDM + nixpkgs niri + a gate-canary user unit in the exact aw-watcher shape, asserts NO niri pre-login (OCR-driven greeter), exactly one after real login
- [x] **Polkit dialogs render check (adwaita/fusion switch)** — done 2026-09-02: found + removed a stale `QT_STYLE_OVERRIDE = mkForce "kvantum"` (2026-04-28) that silently beat the fusion switch at every layer with an UNRESOLVABLE style (kvantum never deployed); post-deploy-check now asserts every deployed Qt style env var RESOLVES + no QQC2 `module ... is not installed` aborts in 24h
- [x] **aw-watcher gate monitoring preference (user)** — done 2026-09-02 (N=10 min): `niri_aw_watcher_attached` + `niri_aw_watcher_late` metrics (niri-health collector) + Gatus "AW Watcher Attached" — validated live: the watcher was in start-limit-hit (exit 101 ×3) at implementation time with zero alerting
- [x] **emeet-pixyd: rate-limit the absent-device probe WARN** — done 2026-09-02 in the upstream repo (`ratelimit.go`, once per path per hour, unit + integration tests green); PENDING: push upstream + `nix flake lock --update-input emeet-pixyd`
- [x] **niri-session-manager config hardening (interim while upstream is pending)** — done 2026-09-02: `gcr-prompter` + `xdg-desktop-portal-gtk` into `[skip_apps]`; app lists extracted to `platforms/nixos/users/niri-session-manager-apps.nix` (single source of truth) with `mkInvariantViolations` asserted at HM eval time AND by `tests/test-niri-session-config.nix` (incl. negative cases); emacs audited (NOT installed — dormant Mod+Shift+E keybind only; "emacs" pinned in single_instance_apps preemptively for the daemon class); restartTriggers DELIBERATELY not wired (upstream restore-on-every-start bug = mid-session restart replays the spawn storm) — replaced by the `niri_session_manager_config_stale` tripwire metric, revisit when the upstream restore-once gate lands. **Source:** `2026-08-31_15-11_*` §f.11-16
- [x] **smart-audio: bump RestartSec 5s→30s + widen StartLimitBurst window** — done 2026-09-02: RestartSec 30s + StartLimitBurst 5/600s (was 5/120s). **Source:** `2026-08-31_18-44_*` §f.17/47

## Priority 2.6: Pixel 6 Phone Recovery follow-ups

_Extraction DONE: ~62.7 GB / 17.5k files verified on `/mnt/pool/backups/pixel6/2026-08-20/`. **Source:** `docs/status/2026-08-20_09-46_*` + `2026-08-21_05-19_*`_

- [ ] **Udev rule for Google USB vendor 18d1 (adb access)** — durable fix for the expiring per-node ACLs; single blocker for every phone-side pull. Also add `pkgs.android-tools` to system packages
- [ ] **User: install "SMS Backup & Restore" → export SMS/call logs/contacts XML** (resolves the 428 anonymous-number WAVs)
- [ ] **User: WhatsApp "Back up now" → re-pull fresh msgstore**
- [ ] **Enrich `universal-call-recorder/index.csv` with call-log contact names** (depends on the XML pull)
- [ ] **SHA256SUMS for Signal + WhatsApp + Cube ACR sets** (only UCR WAVs have a manifest)
- [ ] **Full ffprobe sweep over all 591 UCR WAVs** (5 spot-checked)
- [ ] **Add `backups/pixel6` to btrbk-pool snapshot set + backup-coordination freshness**
- [ ] **Manual `btrfs scrub` on the pool** (~66 GB of new data since last scrub)
- [ ] **`SIGNAL_RECOVERY_KEY.txt` placement decision (USER)** — plaintext beside the encrypted backup; password manager + delete recommended
- [ ] **Recover `/tmp/pixel6-*.sh` transfer scripts into `scripts/`** (or reconstruct from the status reports)
- [ ] **WAV→FLAC mirror of UCR archive** (54 GB → ~18 GB; tag during conversion)
- [ ] **Navidrome audio-archive server (DECIDED over Jellyfin)** — plan: FLAC conversion + tags (mandatory, Navidrome is tags-only) → `modules/nixos/services/navidrome.nix` (port registry, harden + ioTier.background, pool MusicFolder + RequiresMountsFor, `protectedVHost "music"`, homepage tile, Gatus login-body check) → clients (Tempo/Symfonium, Feishin). Later: whisper transcripts → custom tags → search over what was said
- [ ] **Whisper transcription batch (GPU) over the 591 calls** — feeds RAG (`:8848`/`:8849` already run) + full-text search
- [ ] **Call analytics + prefix decode** (0/1/3/5 = direction?)
- [ ] **Immich ingestion of DCIM + WhatsApp media**
- [ ] **Human-friendly renamed mirror tree** (hardlink mirror, no extra space)
- [ ] **Phone care while primary** (95% full, ≥50% charge)
- [ ] **Pool README day-2 update** (signal key, pending XMLs, Navidrome/FLAC plans)

## Priority 3: Infrastructure

### Samsung 1TB migration (ratified 2026-08-31, Rev 2: 4 G reserved ESP + single BTRFS pool ~927.5 G zstd; hot DBs → nodatacow subvol)

- [ ] **Phase 1: `/nix` → Samsung BTRFS** — step 1 DONE 2026-09-02 (`scripts/samsung-prepare.sh`: 4G ESP `SAMSUNG-EFI` unmounted + BTRFS pool `tlc` UUID `ca83e15b-9a8b-43ae-a2ce-330c38c650d3` on ~927.5G p2, subvol `nix` ID 256; mkfs enabled block-group-tree — needs kernel ≥6.1). REMAINING: initial rsync -aH live, quiesce builds → final rsync --delete, `fileSystems."/nix"` by-label + neededForBoot, deploy, reboot window (USER)); post-migration: readlink current-system, dry-run rebuild, fio sanity, exec-latency-under-buildstorm acceptance (the actual point); delete old `@nix` contents after 3-day soak; btrbk topology unchanged (document); add Samsung to btrfs-health metrics + smartd + Gatus mount/space checks; attic store-rebuild story verified before deleting the old subvol. **Source:** `docs/status/2026-08-31_20-02_*` §f.8-15, `docs/planning/2026-08-31_samsung-role-assignment-first-principles.md`
- [ ] **Phase 2: hot DBs off the QLC root** — pocket-id + postgres (immich/paperless) + forgejo dataDirs → nodatacow `hot` subvol per the ratified layout; measure the fsync pain of gatus/discordsync/browser-history/inboxclean/bank-sync first (maybe they stay); docker data-root moves here too. **Source:** 20-02 §f.16-19
- [ ] **Docker image retention follow-through (post-rework)** — (1) verify the granular prune unit is DEPLOYED (committed dd3479e9 after a NOT-deployed report; the live unit may still run the old false-green command); (2) `/data/docker` usage metric + Gatus check >80% (pileup was invisible ~5 months); (3) false-green detector: alert when a prune run reclaims 0B ≥2 consecutive runs; (4) post-deploy smoke asserting the deployed ExecStart = the 4-command list; (5) root-cause `system prune --filter until` 0B on docker 29.7.2 (moby source; then upstream filing via verify-before-filing); (6) SOURCE_DATE_EPOCH trap: epoch-built images pass ANY until filter (AGENTS + policy); (7) move the timer out of the Mon 03:00 backup window; (8) `runCommand` check: no bare `docker system prune` without `-a`; (9) builder-prune policy (age-only vs `--keep-storage`); (10) document rebuild paths for the deleted local-only images; (11) identify the 4 stopped containers deleted 14:47; (12) track build-cache decay over coming Mondays + verify /data frees as snapshots expire. **Source:** `docs/status/2026-08-31_20-46_docker-prune-granular-rework-status.md` §f
- [ ] **mkDockerService hardening follow-ups** — (1) VM test (docker blip at boot → compose units converge — the wants-change is reasoned + negative-proven, never positive-tested); (2) dozzle detached-flavor conversion (attach-flavor units DIE on daemon restart); (3) restart-policy audit (any container with RestartPolicy != always); (4) Gatus check for "compose unit inactive while its containers run" split-brain. **Source:** `2026-08-31_18-44_*` §b.1/§f.6-7/33, `20-30_*` §3
- [ ] **Extend the user-unit monitoring pattern to remaining blind spots** — user-unit failure alerting is LIVE (2026-08-31: `system_user_units_failed{user}` + Gatus check); remaining: flm smoke PSI-skip (cold loads stretch 27-43 min under contention; smoke will false-fail), alert-noise convention for self-healing boot races (alert-after-N-retries), dnsblockd blocklist-load profiling (79s mapping.json), hermes 1.1GB state-check decoupled from the boot critical path, discordsync 5-11 min API-gap deploy wait-or-skip, imagetoraster/libcups segfault investigation. **Source:** `2026-08-31_18-44_*` §e.4-6/§f.22-25/28-30
- [x] **test-cv latent `fileSystems` bug — FIXED 2026-09-02** — converted to `virtualisation.fileSystems` + a REAL btrfs pool disk (pool-fmt oneshot before mnt-pool.mount, `findmnt -o FSTYPE` assertion pins the mount) — cv-backup now exercises the mount-gated path against a genuine btrfs mount; also removed the stale tmpfiles rule for `/mnt/pool/backups/cv` (shadow-dir creator, contradicted the module's own doctrine) and added the "CV Pipeline Store Health" Gatus check (CV repo f.4 ask, ships with the a03ff09e input bump)

- [ ] **Pool + disk-domain quality (2026-08-28 review)** — (1) add `/mnt/pool` (mount-gated) to the btrfs-health scrub metrics loop; (2) eval-time assertion: every btrfs `fileSystems` entry carries `commit=300` + `nodiscard`; (3) trash/mark-RETIRED the p8/p9-era disk scripts (`disk-common.sh`, `disk-fix.sh`, `disk-diagnose.sh`, `disk-create-p9.sh`); (4) consolidate device constants into one lib file (pool by-ids live in 3 places); (5) `pool-subvols-ensure` declarative oneshot; (6) shadow-dir cleanup under `/mnt/pool`, `/data`, `/var/lib/clickhouse`; (7) `btrbk-root` boot/deploy catch-up trigger (`--no-block` like pool-clean — closes multi-day gaps hours earlier; USER Q); (8) paperless-exporter `RandomizedDelaySec` or fix the lying configuration.nix comment; (9) `docs/services/das-recovery.md` runbook + `das-link-recovery-check.sh` per-section exit codes + built-in last-seen lookup; (10) verify "Pool Mounted" actually DELIVERED to Discord on Aug 22 (alert-path proof); (11) `docs/services/docker.md`. **Source:** `docs/status/2026-08-28_04-51_*` §e/§f.4-9/17-18, `2026-08-27_11-48_*` §f.14-18, `2026-08-31_16-29_*` §f.11-12
- [ ] **fish startup profiling** — 908-1211 ms under deploy IO (threshold 200 ms, 60 ms when calm); profile or make the check pressure-aware. **Source:** `2026-08-29_17-29_*` §f.26, `2026-08-30_11-15_*` §f.20
- [ ] **ClickHouse telemetry backup coverage (XFS move follow-up)** — decide accept (derived/rebuildable) vs `clickhouse-backup`/FREEZE→pool job. **Source:** XFS migration plan
- [ ] **Remove stray `/var/lib/paperless` remnants** (verify pool instance healthy first)
- [ ] **restic repo on pool for app dumps (dedup)** — forgejo zips share ~0 extents; plan T17
- [ ] **Own-tools NVMe→pool migrations: discordsync + browser-history remain** (atticd + monitor365 done 2026-08-18); browser-history DB backup (`sqlite3 .backup` + backup-coordination) folds in naturally
- [ ] **Commit the dashboard generator + eval-time dashboard JSON lint** — `/tmp/gen_dashboards.py` was ephemeral; schema lint so a v1 regression fails CI. **Source:** 08-16 23-27 §C.4
- [ ] **Test-fire "Telemetry Export Failures" → Discord** — synthetic export failure in a maintenance window. **Source:** 08-16 23-27 §B.3
- [ ] **SigNoz migrator-gap guard** — assert applied-migration IDs ⊆ known list per DB (the 1010 squash-gap class). **Source:** 08-16 23-27 §E.2
- [ ] **Recreate remaining json-file Docker containers** — one `--force-recreate` per stack. **Source:** 08-16 23-27 §B.2
- [ ] **`file_storage` cursor persistence for the journald receiver** — `start_at=end` loses logs during collector downtime. **Source:** 08-16 23-27 §C.2
- [ ] **Caddy access.log ingestion (filelog receiver)** + **log-ingestion-volume anomaly alert** (>10min silence = pipeline dead). **Source:** 08-16 23-27 §C.1/§C.5
- [ ] **deploy.sh: lock-wait on activation contention** — poll/serialize instead of aborting after the expensive build; consider `nix run .#update` app. **Source:** 08-16 21-25 §d.2
- [ ] **Flake-check guard: HTML `pat()` needles must start with `<`**. **Source:** 08-16 21-25 §e
- [ ] **Derive AUTH_VHOSTS from caddy.nix (or eval-time assert)** — 5/7 probes used hostnames that never existed. **Source:** 08-16 22-00 §c.2
- [ ] **Centralize curl in `scripts/lib.sh` `fetch()` helper**. **Source:** 08-16 22-00 §c.3
- [ ] **Investigate Pocket ID SQLITE_BUSY restart bursts** — recurring across deploys, never root-caused. **Source:** 08-16 22-00 §c.4
- [ ] **Identify residual post-deploy WARNs** (null-byte line ~233; quickshell 1-error-line largely triaged transient 08-26; File Renamer "0 operations"). **Source:** 08-16 22-00 §b.2/§c.5
- [ ] **USB flap-counter metric + pre-deploy zombie-mount detector**. **Source:** 08-16 19-12 §f.12-13
- [ ] **buildcache-gc observability** — `buildcache_gc_last_success_timestamp` + `_prune_ok` metrics; Discord alert on watermark nukes; `--no-block` semantics decision. **Source:** 08-16 19-12 §f
- [ ] **post-deploy-check: poll browser-history /health + drop deploy.sh explicit restart** — startup fast since v4.7.0; the 4.5-min false-FAIL window is obsolete. **Source:** 08-16 03-44 §e
- [ ] **Browser-history DB backup** (folds into the pool migration above)
- [ ] **BTRFS `/data` subvolume migration** (`@data`) — requires ~1h downtime
- [ ] **Create Attic cache + CI token** — `atticadm make-token`; push `signoz-frontend` (122 MiB) + the hermes uv2nix tree (daily CI rebuilds it from scratch). **Source:** hermes 08-21 §f.18
- [ ] **Enable niri blur** — transparent terminals without blur are hard to read
- [ ] **Caddy reload root-cause fix** — `PrivateTmp=true` blocks `systemctl reload` (exit 4); currently band-aided with restart
- [ ] **Declarative health-check** — `criticalSystemServices` is a hand-maintained list of 4
- [ ] **Verify `audio.nix` WirePlumber priority rules don't fight smart-audio**
- [ ] **Extend mkOidcGate with optional diagnostic output** (lost TLS fingerprint diagnostic)
- [ ] **Post-deploy-check failure semantics + escalation** — warn-vs-fail; failure-streak file
- [ ] **System-health collector hardening** — `timeout 5` on docker inspect/ps; NRestarts single-read; MemoryMax headroom after the 08-31 stall (128M→256M if not yet raised)
- [ ] **VM tests for the 2026-08-14 Gatus patterns** + `tests/test-buildcache.nix` + provisioner-idempotency VM test. **Source:** monitoring-gap report §C.9, 08-14 18-29 §f.18, 08-16 06-38 §b.4
- [ ] **Hermes periodic bump workflow** — pin policy decision, scheduled bump or documented cadence + v0.21.0 release-notes re-read. **Source:** hermes 08-21 §f.23/26
- [ ] **Hermes: classify live `tools.registry` journal warnings**. **Source:** hermes 08-21 §f.21
- [ ] **Hermes build-time import smoke test** (`hermes --version` exec in the VM test). **Source:** hermes 08-14 §e.6 + 08-21 §f.13
- [ ] **ClickHouse backup before the next SigNoz upgrade**
- [ ] **Standardize Docker container hardening helper** (`mkDockerService` + `extraOptions`)
- [ ] **Verify vendorHash pre-deploy check patterns at runtime** (§11 greps untested against real output)
- [ ] **Add `--force` flag to deploy.sh for phantom metrics** (documented escape hatch)
- [ ] **Refactor discordsync to use a shared HTTP gate helper** (`mkHttpGate`) or extend mkDnsGate; move gate helpers to `lib/gates.nix`; add eval-time asserts
- [ ] **SearXNG streaming exploration**
- [ ] **Pin go-cqrs-lite benchstat `rev = "master"`** (floating rev, hash drift)
- [ ] **Switch root `go-cqrs-lite` flake input from `git+ssh://` to `github:`** (last ssh root input; NAR-divergence vector)
- [ ] **ADR: zram-only swap decision** + **zram recompression study** (T3.3 — kernel `recompress` could reclaim chunks of the 98.6%-pinned episodes). **Source:** 16-20 §f.22, stability plan T3.3
- [ ] **Scoped polkit rule: service restarts without interactive auth**. **Source:** 20-35 §e
- [ ] **Migrate `dns-blocker.nix` to the upstream dnsblockd module** (split-brain convergence). **Source:** 08-16 00-01 §f.6-10
- [ ] **Retire stale ZFS-VM scripts/workflow remnants** (`scripts/zfs-vm-*.sh`, `systems/zfs-vm.nix`)
- [ ] **sops manifest check-mode in pre-deploy-check** (`sops-install-secrets -check-mode` — secrets drift fails BEFORE switch). **Source:** 08-18 20-38 §e.1
- [ ] **PMA: commit-failure + journald-staleness Gatus checks** (`pma_commits_failed_total` upstream + journal-mtime probe). **Source:** 08-18 13-53 §e.2-3
- [ ] **Gatus lint residuals + synthetic ingest probe + smoke enable-gate sweep** — method-uppercase lint DONE 08-26; remaining: authenticated POST-to-ingest probe (401-only can't catch method/body bugs), `test -e` enable-gate sweep, papdashboard ingest success-count metric. **Source:** 08-18 20-52 §e.3
- [ ] **FastFlowLM smoke: assert model NAME in `/v1/models` + idle-check unit test**. **Source:** 08-18 19-56 §e.3/§f.21-22
- [ ] **deploy-window journal anchoring + retry/backoff on external HTTP checks**. **Source:** 08-18 20-38 §e.6-7
- [ ] **visionreviewd: inject `rocmEnv` into the upstream llama-server unit** (latent gap, service disabled). **Source:** 08-18 17-42 §F.6
- [ ] **hermes: verify ROCm env + runtime llama-server VRAM verify**. **Source:** 08-18 17-42 §F.2/5
- [ ] **Add 3 gotcha entries from the fastflowlm 203-fix session** (missed by two harvests). **Source:** 08-17 22-55 §f.10
- [ ] **dns-blocker: link the OIDC recovery runbook from the docs index** + consider a `dnsblockd-oidc-secret` healthcheck. **Source:** dnsblockd 08-21 sessions (harvested 08-22)
- [ ] **Consider a second USB path for the two pool Toshibas** (one bridge flap takes out everything; USER question decides actionable vs documentation). **Source:** 08-22 01-46 §e.2
- [ ] **Consider gatus `alerting` dedup** (N endpoints, one root cause, one message). **Source:** 08-22 01-46 §f.14
- [ ] **USER: powered USB hub / enclosure swap + UPS evaluation** (one JMS567 link = the shared failure domain; 58 unsafe shutdowns are a power story). **Source:** stability plan T3.5
- [ ] **Boot-time catch-up stampede control** — after multi-day outages, Persistent timers + scrub + dumps all fire in the same minute (freeze #3's backbone); consider staggering or an IO-admission gate at boot. **Source:** `2026-08-31_17-48_*` §e.4
- [ ] **DiscordSync: rebase the `nix/aa56b582-vendorhash` branch into master now that nixpkgs ships go 1.26.7** — the input sits on a side branch pinned below master; rebase + relock (master requires ≥1.26.6). Also: file the `TestIOBaseline_DiskWriteBytes` environmental flake upstream. **Source:** `docs/status/2026-08-26_06-06_*` §c/§f.4-5
- [ ] **flm upstream release watch (T3.4)** — v1.0.2 SIGABRT heap bug recurrence watch (20:17 coredump 08-31); v1.0.3 retry gated on the 7.2.2 reboot. **Source:** stability plan T3.4

## Priority 4: Code Quality

_(all three 2026-09-02 batch items shipped: `audit-go-deps.sh` wired into CI via `.github/workflows/go-deps-audit.yml` — nightly + flake.lock-push triggers, WARN-DIVERGED stays advisory, lookup failures downgrade to WARN-UNKNOWN instead of false ERROR-MISSING, Q1-Q3 safe defaults documented in the workflow; nullglob audit clean (22 runCommand occurrences across 9 files, 0 command-position-var hits) + persisted as `scripts/audit-shell-nullglob.sh` (negative-tested against the signoz-v1 incident shape, wired into pre-commit + CI) + empty-blocklist guard on signoz-query-lint; nix-native negative-test harness persisted as `scripts/negative-test-lints.sh` — 15 cases, first run CAUGHT a real lint weakness (module-shape-lint's `\b` accepted renamed wrappers `caddy-mutant`, fixed with a `=`-anchored grep))_

## Priority 5: Desktop

_(all 2026-08-22 batch items shipped: monitor cycling, named workspaces, idle DPMS, zero-copy test, audio tooling)_

## Priority 6: Upstream Contributions

### nixpkgs

- [ ] **`aw-watcher-utilization` poetry-core migration** — `pkgs/aw-watcher-utilization.nix:19-24`
- [ ] **`valkey` / `aiocache` / `timm` / `xformers` broken tests** — 4 packages with `doCheck = false`
- [ ] **`taskwarrior3` build flags** — `SYSTEM_CORROSION=on` + `ENABLE_TLS_NATIVE_ROOTS=on`
- [ ] **Kitty GC resilience patch**; **KeePassXC Chromium manifests**

### Home Manager

- [ ] **Darwin user definition requirement** (issue #6036)

### Third-Party

- [ ] **`jscpd` lockfile** PR; **XRT boost 1.87+ compat** (`nix-amd-npu`); **upstream direnv caching pattern**; **btop io_mode issue** (verify-then-file); **moby `system prune --filter until` 0B root-cause → issue** (after the local repro)

### LarsArtmann Apps

- [ ] **niri-session-manager: restore-storm fixes** (see P1 — the headline upstream item)
- [ ] **CV: CI `nix build .#cv` gate** — vendorHash staleness has bitten the ecosystem twice from the same root cause (source churn without a Nix gate); CV master was simultaneously unbuildable AND go-vet-failing with nothing catching either. Also: CV AGENTS.md lessons (vendorHash-from-source-churn + templ worktree trap). **Source:** `docs/status/2026-08-29_17-29_*` §e.2/§f.16/20
- [ ] **cqrs-htmx/browser-history: registration-lock polish** — friendly 403 UI, `browser_history_user_count` metric, mutex-limitation docs
- [ ] **dnsblockd: fix OTEL cardinality leak** (label bucketing)
- [ ] **DiscordSync: fix chattr ExecStartPre upstream**; **IO-baseline test flake**
- [ ] **PMA daemon: stop committing broken flake.lock**
- [ ] **`golangci-lint-auto-configure`: fix incomplete vendoring** (or remove the input)
- [ ] **hermes**: auto-create dirs on first run; own state migration; sane OLLAMA defaults; PID-file locking
- [ ] **vendor-hash drift CI for crush-daily, PMA, erraudit**
- [ ] **BuildFlow: pre-commit needs missing devShell binaries**
- [ ] **picoclaw: modernc.org/sqlite v1.48.0 → v1.56.0**
- [ ] **Tag CreditReformBilanzampel + Kernovia DSN fixes**
- [ ] **Roll out go-nix-helpers `eca72e1` across ~20 go-standard consumers**

### SystemNix docs debt

- [ ] **Annotate appendix-only ARCHIVED reports** — 11 archived 2026-08-1x files (authoritative list in archived `2026-08-12_20-52` §b.1/§b.2)
- [ ] **AGENTS.md compression session** — ~263KB now (grew ~180KB in August); dedicated session: move incident narratives to gotchas-archive, keep enduring rules
- [ ] **Triage `docs/planning/` remaining files** (living → ROADMAP/TODO, historical → annotate + archive, dead)
- [ ] **gotchas-archive narratives missing** — foreign-NixOS `/etc` symlink escape, tar `--one-file-system` ZFS, WDT 08-11 chain, nix-daemon oomd chain, hermes outage, HaGeZi GitHub-lock
- [ ] **Verify docs/CONTRIBUTING + docs/DOMAIN_LANGUAGE freshness** (README + FEATURES updated by the 2026-08-31 docs-health audit)

## Priority 7: Long-Term

- [ ] **Provision Pi 3** for DNS failover (VRRP) — hardware required
- [ ] **Auditd enablement** — blocked on NixOS 26.05 bug #483085
- [ ] **AppArmor enablement** — commented out in security-hardening.nix
- [ ] **Darwin HM parity** — disk constrained
- [ ] **Disabled service triage** — voice-agents, minecraft, monitor365 (G7)
- [ ] **Overview upstream: retry discovery** (one-shot at startup → 503 when PMA is slow)
- [ ] **NVMe drive replacement evaluation** — 58+ unsafe shutdowns; TLC replacement / RAID1 `/data` / UPS
- [ ] **Deploy.sh backup retention** — timestamped `.bak` files; keep last 3
- [ ] **Re-evaluate oomd thresholds** — watch `system_oomd_kills_total` + Twenty worker restarts
- [ ] **HaGeZi blocklist refresh workflow** — SRI-hash refresh cadence
- [ ] **disko config for the already-deferred reinstall** — draft alongside the reinstall plan (research done 2026-08-28: provisioning-time tool, adopt at reinstall). **Source:** `docs/status/2026-08-28_04-51_*` §a.7
- [ ] **Proper `@home` subvolume layout** — one day; migration window + hardware-configuration + btrbk together

---

## Deploy Verification Checklist

**All 11 items below are automated in `scripts/post-deploy-check.sh`.** Run `nix run .#post-deploy-check` after every deploy.

| #  | Item                                     | Automated Check                                                         |
| -- | ---------------------------------------- | ----------------------------------------------------------------------- |
| 1  | Post-deploy check                        | Self (the script itself)                                                |
| 2  | Pocket ID — SQLITE_BUSY/panic scan       | `journalctl -u pocket-id --since -30min` grep                           |
| 3  | SearXNG — functional search              | `curl --compressed /search?q=test` grep for `<article\|result-default`  |
| 4  | Attic cache                              | `check_local 8200`                                                      |
| 5  | BTRFS — commit=300 + fstrim              | `grep commit=300 /proc/mounts` + `systemctl is-enabled fstrim.timer`    |
| 6  | Shell — fish startup + direnv            | `date +%s%N` around `fish -i -c exit` + direnv lib check                |
| 7  | Desktop — DMS wallpaper + quickshell     | `dms ipc call wallpaper get` + `journalctl --user -u quickshell -p err` |
| 8  | Registry — nixpkgs github vs tarball     | `nix registry list \| grep nixpkgs`                                     |
| 9  | Monitor365 — auto-SKIP when disabled     | `systemctl list-unit-files 'monitor365*'` presence gate                 |
| 10 | DNS — resolution + memory                | `getent hosts` + `systemctl show -p MemoryCurrent dnsblockd`            |
| 11 | Browser History — liveness + agent timer | `check_local 8087` + `systemctl is-active browser-history-agent.timer`  |

---

_Completed work is tracked in [CHANGELOG.md](./CHANGELOG.md)._
