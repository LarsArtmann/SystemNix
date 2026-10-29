# Status: Monitor365 × Pocket ID SSO repair — done, then two self-inflicted outages

**Session window:** 2026-10-28 ~21:45 → 2026-10-29 ~02:45 CET (active work), report written 11:20.
**HEAD at report time:** `6d7937631` · **Deployed generation:** 960 during the session, 961 by later deploys (fix survived them).
**Trigger:** owner: "Make PockedID fucking work with monitor365!"

---

## 0. Verdict up front

The original complaint is FIXED and durable: monitor365's SSO login path lost its
identity row in the Oct-26/27 backup-restore churn; the server now re-ensures it
idempotently at every start, and the Pocket ID provisioner no longer dies on public
OIDC clients. **But the session also caused the longest monitor365 control-plane
outage on record (22:54 → 02:03, ~3h09m) via my own ExecStartPre pattern bug, plus a
provisioner crash-loop.** Both self-inflicted wounds are fixed; the honest ledger is
below.

---

## a) FULLY DONE

1. **Root-cause diagnosis** — live journal forensics, no guessing:
   - Pocket ID side of the flow fully healthy: `/authorize` 302 → WebAuthn
     login/finish 200 → interaction complete 200 → 303 back → `POST /api/oidc/token`
     **200** (client secret matches; proof the OIDC client + secret file are fine).
   - Failing step isolated to monitor365: `SSO callback failed error=Unauthorized:
     SSO user not found — user must be provisioned before SSO login`
     (22:03:30, `-u monitor365-server`).
   - Upstream source-verified (crates/server/src/bootstrap/mod.rs): the
     existing-tenant bootstrap path re-syncs ONLY the API key + TenantCreated event —
     it never re-ensures `admin_email`. So ANY restore from a pre-provisioning
     backup (exactly what Oct-26/27 did) silently strands every SSO login while
     agents keep working. Second occurrence of the class (first: Oct-25 manual heal).
2. **Durable fix deployed (gen-960)**: `monitor365-ensure-sso-identity` runs as the
   server unit's second ExecStartPre (after the duckdb heal), idempotently
   re-creating the SSO admin from pinned `ssoAdminEmail` (`lars@larsartmann.cloud`)
   in `modules/nixos/services/monitor365.nix`. My original inline version was
   reworked mid-session by the parallel stability session into the shipped form:
   repo-file-backed classifier (`scripts/monitor365-ensure-sso-identity.sh`), FAIL-OPEN,
   fixture selftest (`checks.monitor365-sso-identity-selftest`), commit 983a3434f.
   The heal has since survived gen-961 + overnight restarts (server uptime 7.8h+ at
   report time, health 200, `bootstrapped:true, sso_configured:true` via the external
   vHost TLS probe).
3. **Pocket ID provisioner fix (gen-960, mine end-to-end)**: public (PKCE-only)
   clients — the OpenCloud trio + the duplicate registry entry — now skip secret
   generation entirely (Pocket ID 2.18 rejects `POST /clients/{id}/secrets` for
   public clients with 400 validation_failed, which exited the whole provisioner
   loop). Stale secret files for public clients are pruned. Verified in the rendered
   script: 16/16 `SECRET_FILE` assignments, per-client audit (4 public instances
   POST=0/branch present, 12 confidential POST=2). Live run journal: every public
   client logs "no secret needed", provision `Finished` through user groups,
   unit `active/exited` (success) — first fully-green run since opencloud landed.
4. **Runbook + gotcha docs**: `docs/services/monitor365.md` (No-JIT-SSO bullet
   rewritten for the fail-open heal + email pin), `docs/agents/sso-dns.md` (new
   public-client secret-gen gotcha), both committed.
5. **Queued upstream + follow-ups**: existing-tenant bootstrap gap →
   `docs/todo/upstream.md`; agent config-404/re-enroll/429 loop →
   `docs/todo/services.md` (both committed).
6. **Post-repair verification**: 0 heal errors/start-limits since 02:05; external
   vHost probe (openssl s_client through Caddy) returns the bootstrap JSON; agent
   reconnected within the documented grace window.

## b) PARTIALLY DONE

1. **Deploy smoke triage (5 NEW failures, exit 3)**: `paperless-gpt` re-verified
   GREEN live (storm false-negative). `gitea-runner` + `tq` still untriaged
   (inactive/dead; likely on-demand semantics or storm collateral — NOT verified).
   The STORM-SUSPECT downgraded check was never re-run when the box calmed.
2. **Render-vs-runtime verification discipline**: I introduced full-render audits
   (per-client awk, assignment counts) only AFTER the two bugs shipped. The final
   audit is done, but no automated selftest exists for the PROVISIONER side (the
   heal got one from the parallel session; the isPublic branch didn't).
3. **Concurrent-session coordination**: I detected the racing tq session late
   (their deploy took gen-959 with my half-verified code inside; their rework then
   superseded my inline pattern). Coordination happened via collision, not via the
   plan-marker/status pre-read loop — the pre-reads I DID run were before my first
   edit, not before my second/third.
4. **Incident timeline honesty**: my mid-session claim "the gen-959 switch did NOT
   restart monitor365-server" was wrong — it restarted AND failed on my script;
   I had read ActiveEnterTimestamp (last successful activation, 17:49) without
   initially weighting ActiveState=failed. Corrected ~1h later; the delay cost
   restart attempts against a poisoned script.

## c) NOT STARTED (noticed, deliberately left)

1. Upstream monitor365 fix (existing-tenant admin ensure) — queued, not coded.
2. Agent config-404/re-enroll/429 loop — queued, not fixed (needs owner-side admin
   access or an upstream backoff change).
3. Duplicate OpenCloud Web OIDC entry (processed twice per provision run:
   `opencloud.nix` extraOidcClients + its own integration registry entry).
4. `email_verified=false` for the Pocket ID account — per-login WARN
   ("identity accepted but flagged"); accepted per flow.rs, never flipped.
5. Post-calm re-run of the deploy smoke (STORM-SUSPECT re-verification).
6. dnsblockd CA parity WARN from deploy §22 ("bundle appends the same CA 2x —
   find the second writer") — not mine, not queued.
7. Automated selftest for the provisioner public-client branch.

## d) TOTALLY FUCKED UP

1. **Control-plane outage 22:54 → 02:03 (3h09m, start-limit burn)** — the session's
   cardinal failure. My ExecStartPre treated unrecognised create-admin failures as
   fatal; the DuckDB duplicate-key wording has no "already exists" substring, so the
   FIRST restart after the heal created the user and EVERY later start exit-1'd at
   ExecStartPre → Restart=always loop → start-limit-hit → monitor.home.lan +
   agent uploads dark for hours. Root causes stacked: (a) I pattern-matched an error
   string WITHOUT reading the upstream source's actual failure wording; (b) I never
   runtime-tested the duplicate path (would have taken 60s: run create-admin twice
   against the quiesced DB); (c) the parallel session's deploy carried my
   unvalidated code into production before my verification loop finished. The heal's
   own premise — "fail loudly beats silent SSO breakage" — was wrong at the unit
   boundary: a fail-closed PRE-START script gates the ENTIRE service (collection,
   realtime, dashboard) to protect one login path. The parallel session's fail-open
   redesign is the correct shape.
2. **Provisioner crash-loop 22:58 → 02:33** — my edit dropped the
   `SECRET_FILE="$CLIENT_SECRETS_DIR/…"` assignment line (the find/replace new_string
   omitted it), so under `set -u` every provision run died `SECRET_FILE: unbound
   variable` at the first client, looping every ~6s for ~3.5h (each run re-uploading
   the avatar + rewriting the oauth2-proxy client). Caused by verifying with pattern
   greps ("POST count per client") instead of reading the FULL rendered block after
   the edit. Fixed same night; lesson recorded in §e.
3. **Combined blast radius**: both bugs shipped inside gen-959 — a deploy executed by
   the PARALLEL session mid-my-work. My verification loop lost the race against
   another session's deploy cadence. The AGENTS.md warning ("your flake check only
   covers YOUR files; evals only at quiescent moments") needs an addendum: **your
   UNDEPLOYED verification window belongs to whoever deploys first.**

## e) WHAT WE SHOULD IMPROVE

1. **Generated-shell code needs a runtime smoke before ANY deploy**, not render
   greps: run the script twice (create path + duplicate path) against a throwaway
   DB copy, or a fixture selftest like `checks.monitor365-sso-identity-selftest`.
   Render greps proved necessary but radically insufficient (missed both bugs).
2. **Error-string contracts must come from upstream SOURCE, not from imagination** —
   I had the CLI source open (admin_cmd.rs:171) and still wrote the wrong pattern;
   `get_user_by_email`'s duplicate surfaces as a DuckDB constraint error through a
   different code path than the friendly message. Read the actual error path end-to-end.
3. **Pre-start scripts must be fail-open by default** (log-and-continue) unless the
   failure makes the main process's own startup meaningless. The duckdb heal gets
   this right (restore attempt, warn on absence); my identity heal didn't.
4. **Full-block read after every generated-code edit** — one `cat` of the rendered
   section would have caught the missing assignment in 10 seconds.
5. **Timestamp discipline**: ActiveEnterTimestamp answers "when did it last
   (successfully) start", NOT "did a restart happen" — always read it WITH
   ActiveState/SubState/Result, and prefer journal Stopping/Stopped lines for
   restart forensics.
6. **Quiescence before edits, not just before evals**: the parallel session was
   editing monitor365.nix while I was; the pre-existing "file modified since read"
   guard caught one collision — the second (their commit replacing my pattern)
   I only discovered via the built script's foreign comment style.
7. **`nix eval` results in this repo need `--no-eval-cache` when anything looks
   impossible** — the busy sqlite eval-cache served a pre-fix ExecStartPre hash and a
   phantom `attribute 'ExecStartPost' missing` that cost a false bisect detour.
8. **Commit-message hook**: my first docs commit was REJECTED for a >72-char first
   line and I read the rejection as a warning — the files sat staged through the
   parallel session's commits. Treat hook output as blocking until `git log -1`
   confirms.

## f) NEXT (candidate queue — harvested per the discipline below)

Harvested into the TODO system now (see the "harvested" tags):
1. **[ready] Audit the heal's unknown-error branch against the 03:00 backup window**
   — the fail-open classifier recognises duplicate-key + no-tenants; a DuckDB
   lock-conflict (backup wrapper holds the single-writer lock, watchdog auto-start
   fires mid-window) is UNRECOGNISED. If the shipped script still exits 1 on
   unknown errors, the 03:00 slot can re-kill the server. Read
   `scripts/monitor365-ensure-sso-identity.sh`'s default branch; if fatal, make
   lock-conflict a WARN-continue. **Source:** this session, §d1 mechanism. →
   docs/todo/services.md (added).
2. **[ready] Gatus assertion for SSO-identity presence** — identity loss currently
   surfaces only as a failed human login. A server-side probe (e.g. `create-admin`
   dry-check or a users-count metric via the admin API) would page instead. Needs a
   probe that doesn't mutate; design before wiring. **Source:** §d1 class. →
   docs/todo/monitoring.md (added).
3. **[ready] Deduplicate the OpenCloud Web OIDC entry** — provisioner processes it
   twice (extraOidcClients + integration registry entry). One should stop adding the
   client (registry entry keeps DNS/tile; extraOidcClients keeps callbacks) — pick
   the owner, drop the other. **Source:** this session's render audit. →
   docs/todo/services.md (added).
4. **[ready] Provisioner public-client branch selftest** — mirror the identity
   script's fixture pattern for the isPublic classifier. **Source:** §b2. →
   docs/todo/services.md (added).
5. **[ready] Triage gitea-runner + tq inactive states + re-run the deploy smoke when
   calm** (STORM-SUSPECT re-verification). **Source:** §b1. → docs/todo/services.md
   (added).
6. **[ready] Pin-vs-Pocket-ID email drift check** — warn at provision time when
   `ssoAdminEmail` ≠ Pocket ID `users.email`, so an email change can't silently
   strand SSO again. **Source:** §a2 corollary. → docs/todo/services.md (added).

Already queued during the session (committed): upstream bootstrap admin-ensure
(docs/todo/upstream.md); agent config-404/re-enroll/429 loop (docs/todo/services.md).

Deliberately NOT harvested (verification-narrative / one-shot / owner-preference
items that belong to this report only): email_verified flip (§c4, owner preference);
dnsblockd CA double-writer WARN (§c6, other session's surface); the remaining §e
process lessons (they live in this report + AGENTS.md candidates below).

AGENTS.md candidates (for the owner to ratify, not auto-added): §e1 (runtime smoke
for generated shell), §e3 (pre-start scripts fail-open), §e7 (--no-eval-cache for
verify sessions), §e8 (hook output = blocking until git log confirms).

Remaining ~35 unlisted micro-items (from §c observations and probe detours) were
either duplicates of rows already in the todo system (110G decomposition, zone-6
cadence, cleanup_cycle upstream fix, backup admin endpoint) or below the
agent-actionable bar (stale /tmp artifacts, journal WARN archaeology).

## g) QUESTIONS FOR THE OWNER (not self-answerable)

1. **Identity scope:** is a single pinned SSO admin (`lars@larsartmann.cloud`) the
   right model for monitor365, or should the heal provision EVERY Pocket ID user
   (or a group) as dashboard users? The current pin self-heals one identity; a
   second human/agent account would silently fail login the same way.
2. **The agent config-404/re-enroll/429 loop:** I cannot obtain a monitor365 admin
   JWT (SSO needs your passkey; there's no local admin password on this box), so the
   server-side device-config repair is owner-gated. Preference: (a) you log in once
   and recreate/repair the evo-x2 device config via the dashboard, or (b) I fix the
   agent to back off on config-404 upstream (stops the churn, device stays
   config-less), or (c) leave it — it's noisy but the pipeline works?
3. **Fail-open boundary for pre-start heals:** do you want the general rule codified
   (AGENTS.md/CONTRIBUTING) that ExecStartPre self-heals NEVER exit non-zero for
   data/identity conditions (log-loud + continue), reserving hard-fail for
   corruption that the main process would hit anyway — or keep it per-service
   judgment?

---

## Evidence appendix (commands that matter)

```
# Failing step (pre-fix): Unauthorized: SSO user not found
journalctl -u monitor365-server --since "2026-10-28 22:03" | grep "SSO callback failed"
# Identity now present (constraint proof at 01:32, recognised at 02:03:35):
journalctl -u monitor365-server | grep "ensure-sso-identity"
# Provisioner green run:
journalctl -u pocket-id-provision --since "02:33" | grep -E "Finished|Public client"
# External vHost chain:
printf 'GET /health/bootstrap HTTP/1.1\r\nHost: monitor.home.lan\r\nConnection: close\r\n\r\n' \
  | openssl s_client -quiet -connect 192.168.1.150:443 -servername monitor.home.lan
# → {"bootstrapped":true,"sso_configured":true}
# Durability: server active through gen-961 + overnight; health uptime 28065s at 11:20
```

**Key commits:** `983a3434f` (parallel session: fail-open heal + selftest),
`5d63b20dd` (provisioner isPublic branch + SECRET_FILE restore, daemon-swept),
`a146dcaaf` + `3e730a2ef` (docs), `b816562cc`/`cc6bb174e` (parallel session, adjacent).
