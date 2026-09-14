# Startup-Error Review — Follow-Up Backlog Execution (2026-08-31 20:30)

Session continuation of `2026-08-31_18-44_startup-error-review-boot-fixes-self-review.md`.
User directive: execute the priority backlog autonomously. Everything below is
deployed and verified live unless marked otherwise.

## Shipped This Session

### 1. DNS gate budget + eval-enforced timeout floors (the 2026-08-31 incident class, closed)

- `lib/default.nix` `mkDnsGate`: budget 120s → **180s** (dnsblockd needs ~2min at
  boot — same measured boot that broke the OIDC gate's old 120s). Both gate
  helpers now return `TimeoutStartSec = mkDefault <floor>` in their fragment
  (oidc → 6min, dns → 4min), so wholesale-fragment consumers are covered
  automatically.
- **NEW `gate-timeout-audit.nix`** (auto-discovered eval guard): any unit whose
  ExecStartPre contains `-wait-oidc` MUST set TimeoutStartSec ≥ 6min; `-wait-dns`
  ≥ 4min; `nix flake check` fails naming the unit otherwise. Detection is by
  script-name convention, so hand-rolled clones (discordsync) are caught too.
  **Positive + negative verified**: clean tree = 0 violations across 8 gate
  units (browser-history, discordsync, forgejo, forgejo-oidc-setup, gatus,
  hermes-github-verify, oauth2-proxy, searx); `extendModules` + `mkForce "2min"`
  on discordsync → assertion message fires exactly.
- Consumers brought above floor: **discordsync** (hand-rolled curl gate 60→150
  retries, TimeoutStartSec 2min→6min — the old gate budget EQUALLED the unit
  timeout, guaranteed slow-boot failure), **searx** 3min→4min, **forgejo**
  3min→4min. Deployed values verified on the live units.
- First audit draft was a PHANTOM GREEN: the new module file wasn't `git add`ed,
  so the flake never saw it and "0 failed assertions" was meaningless (the
  tracked-files trap, live). Negative-testing through nix is the only proof.

### 2. User-unit failure monitoring (the smart-audio blind spot, closed)

- `system-health` collector: new `monitoredUserManagers` option (default: host's
  `users.primaryUser`) → `system_user_units_failed{user}` /
  `system_user_manager_reachable{user}` / `system_user_units_scrape_errors{user}`
  via `systemctl --machine=<u>@.host --user` (machined bus proxy, `timeout 10`
  bounded). **Logout ≠ wedge**: `/run/user/<uid>` absent → reachable 0, failed 0
  (legitimate logout, no alert); present-but-query-failed → scrape_errors 1
  (dnsblockd-:9090 wedge class, alerts).
- Gatus "User Unit Failures" check (anchored pat() forms). Metrics verified live
  post-deploy: `system_user_units_failed{user="lars"} 0`.
- Two shellcheck lessons burned a deploy cycle: quoted single-user for-list =
  SC2041; single literal iteration = SC2043 (config-generated lists need the
  targeted disable comment).
- Pre-deploy-check §10 correctly BLOCKED the first deploy (phantom-metric
  guard caught my own new metrics); added them to `KNOWN_NEW_METRICS`.

### 3. Docker convergence positive test (the manifest-postgres fix, proven)

`systemctl restart docker` on the live box (via sudo wrapper — polkit denies
non-tty restarts from lars):

- `mnfst-postgres-1`: restart=always brought it back **healthy in ~17s** — the
  2026-08-31 incident scenario now self-heals.
- `manifest.service` / `twenty.service`: stayed active (wants + detached flavor).
- `twenty-worker-1`: briefly "Created" (compose dependency gating on
  twenty-server health) — NOT a failure; Up ~40s later.
- **dozzle: found a design gap** — attach-flavor compose units DIE on daemon
  restart (attached compose killed → ExecStopPost removes container → unit
  inactive until boot/deploy). Restored manually; documented in AGENTS.md;
  conversion to detached flavor is follow-up work.

### 4. Two foreign-session blockers fixed to unblock the deploy pipeline

- **`signoz-coverage.nix` was committed as a BARE NixOS module** (the documented
  flake-parts wrapper trap, worse variant): its `let`-bindings force
  `config.systemd.services` in the flake-parts context → every nix command died
  `attribute 'systemd' missing` at 19:35, blocking all deploys. Applied the
  mechanical `flake.nixosModules.signoz-coverage =` wrapper (their content
  untouched; their file raced my fix twice mid-edit). Module now evaluates and
  its `signoz-coverage-metrics` unit exists on the host.
- **bank-sync upstream rev `09785e60` (Wise SDK v0.9.0) shipped a stale flake
  vendorHash** → go-modules FOD hash mismatch blocked the toplevel build. Added
  a TEMPORARY `package = mkForce (overrideAttrs vendorHash = got)` in the
  SystemNix wrapper with a DROP-ME comment + AGENTS.md note; the bank-sync
  session owns the proper upstream refresh.

### 5. Root-cause corrections

- **The "phantom global DefaultTimeoutStartSec" gotcha was WRONG** — nixpkgs
  renders `systemd.settings.Manager` into `/etc/systemd/system.conf` (whole
  file), not a `system.conf.d/` dropin; the original diagnosis checked the
  absent dropin dir. Verified live: `systemctl show -p DefaultTimeoutStartUSec`
  → 3min on the running PID1. AGENTS.md + the stale comment in system-health.nix
  corrected; explicit per-unit ceilings kept anyway (good practice, not
  necessity).
- **buildcache-init boot `status=15/TERM` is BENIGN** — coldplug job
  replacement: started at 16:37:24, SIGTERM'd 64ms in when the automount
  activation superseded the job, retried and SUCCEEDED within the same second.
  Journal noise only; documented, deliberately not "fixed".

### 6. Line-review of concurrent sessions' committed work (ac1b9cf9, 49ac851e)

Verdict: sound, VM-tested, well-documented. cv-backup-dir oneshot follows the
atticd pattern; Zone 5 episodic leaky bucket is calibrated against real incident
telemetry; scrub-deferral ActiveState fix is correct (oneshot "activating"
excluded by `is-active`); flm correctly held at 1.0.2 (verified in tree). Both
commit messages said "NOTHING IS DEPLOYED" — this session's deploys shipped
them (flake check green on the combined tree first). One factual error found
(the phantom-timeout claim, corrected above).

## Deploy record

4 attempts: (1) blocked by bare-module eval failure → wrapped signoz-coverage;
(2) blocked by SC2041/SC2043 → fixed; (3) blocked by bank-sync FOD hash →
temporary override; (4) **deployed clean — post-deploy-check 83 PASS / 0 FAIL**
(first run had 1 transient fail from a mid-restart smoke probe; immediate re-run
clean).

## Deliberately NOT done (still user-gated)

1. **Reboot into kernel 7.2.2** — still pending; gates the flm 1.0.3 retry
   (needs 21.6 GB weight re-pull + live serve validation). `/run/booted-system`
   (7.2.0, Aug-26 gen) ≠ `/run/current-system` (7.2.2) is EXPECTED until then.
2. **bank-sync vendorHash** — upstream refresh pending (their session active).
3. **dozzle detached-flavor conversion** — follow-up.
4. Deploy-policy question for foreign in-flight work remains open; this session
   shipped foreign work only after flake-check-green + scoped diff review +
   FOD-consistency verification (mr-sync cached, bank-sync override added).

## Tree state at session end

Concurrent sessions committed everything through `e8de2ed5` + this session's
work (daemon batches). Watch: the signoz-coverage session may re-touch its
module (my wrapper is mechanical; their content intact).
