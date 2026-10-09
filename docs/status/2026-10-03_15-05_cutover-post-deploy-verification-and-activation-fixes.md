# Cutover post-deploy verification + activation-failure fixes — 2026-10-03 14:37–15:05

**Session type:** direct continuation of the cutover-verification resume session
(report `crm/docs/status/2026-10-03_13-55_cutover-verification-resume-toplevel-chase.md`).
Trigger: owner ran `nh os switch . -v --show-activation-logs --keep-going` at 14:36
(pasted output) — the combined generation (cutover spine + paperless wave + 13-shim
fleet) **switched with exit 4** (some units failed). This session verified the CRM
cutover legs, root-caused every activation failure and every new post-deploy
regression, and landed 4 module fixes.

**Deploy identity:** `/run/current-system` → `6r368pda…-nixos-system-evo-x2-26.11.20261001.c59305b`
(previous: `r6fcay8x…-…20260928.7a0f122`, Oct 2 10:59). SystemNix tree at switch ≈ `37d62b19`;
my fixes later swept by daemon into `06e26904` (see §d1).

---

## a) FULLY DONE (verified this session)

**CRM cutover legs — ALL GREEN in prod:**

1. **crm-server.service live**: cgroup active (PID 498894), journal
   `ledger crm listening addr=127.0.0.1:8091 driver=sqlite db=/home/lars/.local/share/crm/ledger.db auth=true`,
   WebAuthn `rpid=crm.home.lan origin=https://crm.home.lan secure=true`, machine API
   enabled (`/api/contacts/{by-phone,calls}`, `/api/email-sync/people`, `/rest/{companies,opportunities}`).
2. **Public vHost**: `https://crm.home.lan/healthz` → `200 {"status":"ok",…}`, SPA root 200
   through Caddy TLS (resolves to 192.168.1.150). Loopback `/healthz` → `200 ok`.
3. **Gatus "Ledger CRM" check**: present in live config
   (`/nix/store/iisvnnxv…-gatus.yaml`: interval 5m, `http://127.0.0.1:8091/healthz`,
   conditions `[STATUS]==200` + `<1000ms`, Discord+custom alerts, group Productivity);
   crm journal shows the 5m probes passing (14:37:25, 14:42:25 …).
4. **Secrets rendered at activation**: `crm_api_token` added, `crm-server-env` rendered,
   `cv-env` modified (sops-install-secrets log in the owner's paste).
5. **Twenty coexistence intact**: unit running, workers healthy on port **3200**
   (ports.nix), no regression.
6. **Ledger CRM package identity**: diff ADDED `ledger-crm 6164ecb67048…` — exactly the
   locked rev proven green in isolation last session.

**Root-caused + module fixes LANDED (tree, not yet deployed):**

7. **sops+age vanishing root-caused**: they rode `forgejo-repos.nix`'s
   `lib.mkIf cfg.enable` systemPackages; `forgejo-repos.enable = false`
   (configuration.nix:1346) silently dropped BOTH CLIs from the closure —
   `command -v sops` failed on the live host. **Fix**: `sops` + `age` added to
   `platforms/common/packages/base.nix` security tools with the lesson comment.
   Confirmed via `nix why-depends` on the old profile (`system-812-link` →
   `rqrz84xj…system-path` → `zw19f75h…sops-3.13.3` / `p404bfl…age-1.3.2`).
8. **geometrikks-db-provision failure root-caused**: nixpkgs bumped timescaledb
   2.30.1→2.30.2; the DB catalog still points at `$libdir/timescaledb-2.30.1` →
   `CREATE EXTENSION IF NOT EXISTS` died ("could not access file"), plus glibc
   2.42→2.44 collation-version warnings. **Fix**: tolerant `ALTER EXTENSION …
   UPDATE` pre-pass (`|| true` for first-bootstrap), both collation
   REFRESHes appended.
9. **geometrikks.service ExecStartPre EPERM root-caused**: stale
   `/var/lib/geometrikks/alembic.ini` is mode 444 (cp reuses store-file perms);
   the new pkg's cp O_TRUNCs it → EPERM as service user. **Fix**:
   `rm -f alembic.ini` before copy + included in the `chmod -R u+w`.
10. **paperless-sqlite-to-pg-migration start-limit root-caused**: `wantedBy =
    paperless-scheduler.service` (a service, not a target) re-pulls the oneshot on
    every scheduler restart; activation churn fired it 3× in 1s → start-limit-hit →
    exit-4. **Fix**: `RemainAfterExit = true` (script is once-per-boot by design;
    paperless-scheduler itself started clean at 14:37:16 and its celery beat is
    scheduling mail checks).
11. **CV→CRM startup race root-caused + mitigated**: cv-server's syncer replays the
    full event log at Start (~1k REST calls/s, NO retry, in-memory idempotency);
    crm-server binds ~4s after ExecStart. At the 14:36 joint restart the whole
    backfill hit a refused port: **10,489 `crm sync: create company failed` in 11s,
    zero retries after** (journal count). **Fix** in cv.nix: `after`/`wants`
    `crm-server.service` (gated on `services.crm-server.enable`) + bounded fail-open
    ExecStartPre `/dev/tcp` socket wait (120s, `$$`-escaped for systemd, port derived
    from `ports.crm`; verified rendering via `nix eval` → `bash -c 'deadline=$$((SECONDS + 120));
    until (exec 3<>"/dev/tcp/127.0.0.1/8091")…'`). The unit change means the next
    deploy restarts cv-server → the full backfill re-runs against a live CRM
    (idempotent find-before-create).

**Diagnosed to evidence level (fix belongs elsewhere, correctly not bypassed):**

12. **Forgejo 5× FAIL = deliberate migration gate**: `ConditionPathExists=
    /var/lib/forgejo/.subvol-migrated` unsatisfied; marker is only written by
    `scripts/migrate-forgejo-subvol.sh finalize` (forgejo.nix:79-87);
    `forgejo-subvol-bootstrap` finished OK (subvol exists) but the DATA MOVE is an
    owner script step. Old baseline (down before this deploy). NOT bypassed —
    mounting the empty subvol over live data would split-brain (storage doctrine).
13. **Bank-Sync 2× FAIL root-caused to app bump 51b24dc**: (a) HTTPS 403 = the app's
    DNS-rebinding guard rejects `Host: banksync.home.lan` (journal: "host header
    rejected (dns rebinding guard)"); (b) sync cycles failing with
    `[conflict:event.version_conflict] failed to save events` (provider=wise,
    flight-recorder snapshots landing). App-repo fixes, queued (§f).
14. **InboxClean /health 503 root-caused**: body shows `gmail.main: auth_expired`
    (work: connected), `corpus root missing at /var/lib/inboxclean/corpus — run a
    sync`, database/event_store/projections all ok. Owner/app action, queued (§f).
15. **post-deploy battery run twice** (122 PASS / 12 FAIL / 8 SKIP / 4 WARN on
    re-run): all 12 FAILs enumerated with baseline classification; 3 were NEW
    regressions from this deploy (Bank-Sync HTTPS, Desktop polkit, InboxClean).
16. gitea-runner-evo-x2 recovered post-switch (failed at 14:36, cgroup active now).
17. Auth-gateway battery fully green (10 vHosts PASS); mail relay, SMART, crush
    config, BTRFS, zram, memory all PASS. I/O PSI avg10 50.72% (WARN — deploy gate
    blocks new deploys at this level).

## b) PARTIALLY DONE

1. **The 4 module fixes are landed + eval-verified individually but NOT deployed**
   (deploy is owner-gated; PSI elevated anyway). `nix flake check --no-build`
   running at report time (bg `/tmp/flakecheck-postfix.log`).
2. **CV→CRM backfill still missing in prod** (10,489 companies unmirrored) —
   re-runs at the next cv-server restart, which the landed unit change guarantees
   on the next deploy. Watch task open (§f).
3. **Remaining post-deploy FAILs not root-caused**: FastFlowLM `:52625` socket dead
   (socket-activated design; slice has no active units), SigNoz coverage
   `traces_missing 1` (one service dark; grep `signoz_traces_reporting :9100/metrics`),
   Desktop polkit 24–28 QQC2 "module … is not installed" aborts (2026-08-18 class;
   check names the surface: `qt.platformTheme/style in home.nix vs deployed Qt
   plugins` — Qt bumped in this deploy). quickshell-family 290 error lines (WARN).
4. **templ-components v1.19.5** still blocked on owner answer (prior session Q3).

## c) NOT STARTED

1. Post-deploy cutover battery chain: T32 passkey ceremony, T33–T35 imports/reconciliation, T40/41 syncer watch (beyond this session's race findings), T42 freeze.
2. Bank-sync app fixes (rebinding-guard host allowlist; wise version-conflict) — bank-sync repo.
3. InboxClean gmail-main re-auth + corpus sync run.
4. Forgejo subvol migration finalize (owner script) + forgejo-repos re-enable decision.
5. CV syncer durable retry (bounded backoff in career-pipeline/crm client) — the
   systemic fix for the race class; requires CV rev bump + lock/vendorHash cycle.
6. paperless `db.sqlite3` removal (owner verification step per module design comment).
7. vHost Layer-2 ratification (prior session Q2) — shipped `plain` WebAuthn-only.

## d) TOTALLY FUCKED UP (honest ledger)

1. **I syntax-broke the flake mid-session.** My cv.nix ExecStartPre inline string
   used JSON-escaping where Nix-escaping was needed: bare `"` inside a Nix
   double-quoted string → `syntax error, unexpected invalid token` → the ENTIRE
   flake unevaluable in a SHARED tree (every parallel session's `nix fmt`/eval
   breaks). Caught by my own `nix fmt` gate within a minute and fixed (eval now
   renders the ExecStartPre correctly). Compounding: the daemon swept the BROKEN
   intermediate into heuristic commit `06e26904` at 14:57:55 — HEAD carries the
   broken cv.nix; the corrected version sits uncommitted on top (daemon re-sweeps
   within ~10 min; do NOT deploy from `06e26904` as-is). Root cause: I reasoned
   about the 4 quoting layers (JSON → Nix → systemd `$$` → bash) only AFTER the
   first write instead of using the house `writeShellApplication` pattern
   (fastflowlm proxy-conn) which sidesteps the entire trap.
2. **The corrective edit re-inserted the same bug**: when my first fix-up edit
   failed to match, I copied the text from the tool's "closest match" display —
   which showed the file's broken literal — and re-applied it, instead of
   re-deriving the correctly escaped line. Two rounds to fix one character class.
3. **rg misuse burned rounds**: twice used `-rn`/`-rln` where `-r` = `--replace`
   (mangled output: `*lner`, `services.ln`, `${stateDir}/.n`), plus a
   `sops\|age` grep whose matches were mostly the substring "Package". Chased
   ghosts for ~4 tool rounds before noticing.
4. **Wrong-port/wrong-interface probes before reading config**: Twenty probed on
   3000 (real: 3200), Caddy probed on 127.0.0.1:443 (not loopback-bound; real
   probe via `crm.home.lan` DNS). ports.nix was one grep away the whole time.
5. **Ran the full post-deploy battery twice** solely to capture a complete log
   (first run was tail-truncated in background capture) — doubled 120+ HTTP probes
   during an already PSI-elevated window for logging discipline.

## e) WHAT WE SHOULD IMPROVE (structural)

1. __Ban inline Exec_ shell strings in this repo_* — the JSON→Nix→systemd→bash
   quoting stack is where this session's worst error happened AND where the
   `$SECONDS` systemd-substitution bug almost shipped. House pattern exists
   (`writeShellApplication`, fastflowlm.nix:77-100). Convert my cv.nix wait to it
   (queued §f) and consider a lint leg (grep for `ExecStart.*bash -c` in modules/).
2. **Global CLI packages must never ride a service module's `mkIf`** — forgejo-repos
   carrying sops/age made a service-disable silently break the secrets workflow
   host-wide. base.nix comment documents it; an eval-audit flagging
   `environment.systemPackages` inside `mkIf cfg.enable` that contains
   workflow-global tools would prevent recurrence.
3. **Event-replay consumers need startup-dependency + retry discipline** — cv's
   no-retry replay with in-memory idempotency lost 10k records to an 11s race.
   The SystemNix-side wait is mitigation; the durable fix is a bounded retry in
   the CV syncer client. Same class likely applies to any other replay-at-boot
   projection (dashboard projection shares the shape).
4. **Post-deploy baseline semantics swallow regressions**: the 3 NEW deploy
   regressions (Bank-Sync HTTPS, Desktop, InboxClean) were folded into the
   baseline by the second run, turning exit-3 into exit-1. Persist the
   first-run-per-deploy NEW-failure list separately from the rolling baseline.
5. **Pre-deploy static lint for stamp-gated asset copies** (stale read-only target
   files) and **wantedBy-on-service oneshots without RemainAfterExit** — both
   activation failures were statically detectable shapes.
6. **ports.nix first**: every probe should start from the registry, not from
   recollection (3000/443 misses).
7. **Heuristic daemon commits are unfit as fix carriers** — `06e26904` now contains
   a known-broken intermediate of MY work; anyone deploying from HEAD between
   sweeps would hit it. Policy reminder: after daemon sweep of in-flight work,
   amend-forward with a proper message (unpushed check first) rather than leaving
   broken intermediates as HEAD.

## f) Next — prioritized (impact-ordered)

**Deploy & verify the landed fixes:**

1. Re-run `nix flake check --no-build` verdict (`/tmp/flakecheck-postfix.log`) — must be green before deploy.
2. Deploy the 4 fixes (`nix run .#deploy`, owner-gated; PSI must drop below the gate first — was avg10 50.7%).
3. Post-deploy: verify `sops --version` + `age --version` answer on the new generation.
4. Post-deploy: verify geometrikks-db-provision + geometrikks.service go green (exit-4 class cleared).
5. Post-deploy: verify paperless-sqlite-to-pg-migration runs ONCE and stays `active (exited)` — no start-limit.
6. Post-deploy: cv-server restarts (unit changed) → watch journal for `crm sync` SUCCESS lines replacing the 10,489 failures; confirm companies landed in CRM (`/rest/companies` count or ledger.db).
7. Confirm activation exit code drops 4 → 0 on the next switch.

**Cutover battery chain (owner-participation items):**
8. T32 passkey ceremony for crm.home.lan (WebAuthn enroll).
9. T33–T35 data imports + reconciliation (Twenty → Ledger parity checks).
10. T40/T41 syncer watch: 24h of Gatus "Ledger CRM" green + cv CRM-status endpoint healthy.
11. T42 freeze decision (Twenty decommission gate) once parity holds.
12. Ratify vHost layer: `plain` (WebAuthn-only) vs oauth2-proxy Layer 2 (prior session Q2 — one-line + redeploy if ordered).

**Open regressions (this deploy's NEW failures):**
13. Bank-Sync app: allowlist `banksync.home.lan` in the DNS-rebinding guard (or make guard configurable) — kills the HTTPS 403.
14. Bank-Sync app: root-cause wise `[conflict:event.version_conflict] failed to save events` (flight-recorder traces in `/mnt/pool/services/bank-sync/traces/`).
15. InboxClean: gmail `main` re-auth (owner interactive) + corpus sync run; then /health → 200.
16. Desktop polkit: fix `qt.platformTheme`/style in home.nix vs the bumped Qt (2026-08-18 crash-loop class, 24–28 aborts/24h).
17. FastFlowLM: why the :52625 socket is dead (socket-activation unit state) — old baseline but user-visible.
18. SigNoz coverage: identify the one dark service (`grep signoz_traces_reporting :9100/metrics`).

**Structural improvements (from §e):**
19. Convert cv.nix ExecStartPre inline script → `writeShellApplication` (quoting-trap removal).
20. Add eval-audit: flag workflow-global packages inside conditional service-module systemPackages.
21. Add pre-deploy lint legs: stamp-gated asset copies with un-removed stale targets; wantedBy-on-service oneshots without RemainAfterExit.
22. Split post-deploy-check NEW-failure persistence from the rolling baseline.
23. CV repo: bounded retry-on-connection-refused in career-pipeline/crm client (+ tests), then rev bump through mkLarsPackages + FOD verification.

**Hygiene & follow-through:**
24. Do NOT deploy from `06e26904`; confirm the daemon re-swept the corrected cv.nix (or amend-forward) before any deploy.
25. Verify openssl 3.6.4→3.5.8 DOWNGRADE in the deploy diff is intentional (nixpkgs branch drift?) — security-relevant oddity I noticed but did not chase.
26. Owner: run `scripts/migrate-forgejo-subvol.sh finalize` (restores Forgejo, un-gates 5 checks), then decide forgejo-repos re-enable.
27. Owner: verify Paperless-on-PG then trash `/var/lib/paperless/db.sqlite3` (design says Condition skips forever after).
28. xdg-desktop-portal-gtk user unit failed at switch — minor, verify next login.
29. Watch closure oddities from the diff: qemu-user-static-musl +263 MiB, llvm +564 MiB, 34 catalog subdomains without catalog entries (warning list) — confirm intentional.
30. crm repo: 3+1 docs commits unpushed (incl. 4378d62); push cadence owner decision.
31. templ-components v1.19.5 release decision (prior session Q3: push 5 commits + cut from clean worktree?).
32. Harvest this report's §f into TODO_LIST.md + domain libraries per the TODO-system rules (monitoring.md/services.md/pipeline.md as appropriate).

## g) Questions I cannot answer myself

1. **Deploy authorization for the 4 landed fixes**: the 14:36 switch was yours and
   the session rule says deploy is owner-gated — but you've now seen exit-4 and
   said "keep going until everything works". May I run `nix run .#deploy` myself
   once PSI drops below the gate and flake check is green, or do you want to run
   it (it also restarts cv-server → re-runs the 10k-company backfill)?
2. **Bank-Sync regression handling**: fix forward in the bank-sync repo (rebinding
   allowlist + version-conflict root cause) or pin/rollback the 51b24dc bump in
   mkLarsPackages until fixed? (Both app failures are live since the deploy.)
3. **Forgejo downtime budget**: Forgejo (5 checks red) is gated behind
   `migrate-forgejo-subvol.sh finalize`, an owner-run script moving live data —
   is that scheduled today, or should I prepare anything (dry-run, backup
   verification) to make the finalize safe/soon?

---

_Verification evidence: crm journal (systemd unit logs via journalctl), live gatus
config `/nix/store/iisvnnxv…-gatus.yaml`, `nix why-depends` on
`/nix/var/nix/profiles/system-812-link`, post-deploy logs
`/tmp/pdc-full.log`, `/tmp/flakecheck-postfix.log` (in flight), deploy paste
(owner terminal, 14:36)._
