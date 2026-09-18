# Miniflux OIDC Link: VM Regression Root-Caused (NSS-via-nsncd), 4 Provisioner Bugs Fixed, VM GREEN — Deploy BLOCKED by Pressure Gate

**Session:** 2026-09-17 ~15:14 → 2026-09-18 07:55 CEST (resumed from the
`2026-09-17_15-13` mid-bisect summary)
**Verdict:** The VM regression is fully understood and fixed. The test is
GREEN end-to-end. All gates green. All docs updated. **The deploy did NOT
happen** — blocked twice by the pre-deploy IO-PSI gate (exit 12); production
still runs the pre-change generation and the user-facing SSO 400 still exists.

---

## The one-paragraph story

The link unit's mere DECLARATION made miniflux's boot break with
`pq: Peer authentication failed` — and the mechanism had nothing to do with
the link unit's logic. Reading nixpkgs source found it: **NixOS's NSS support
for DynamicUser is documented "Only works with nscd!"** — `libnss_systemd` is
loadable ONLY inside the nscd/nsncd process (its unit carries
`LD_LIBRARY_PATH = nssModulesPath`). In every other process (including
postgres), the module dlopen fails silently, `getpwuid(dynamic-uid)` falls
through to files-only, and postgres answers `could not look up local user ID
64274: user does not exist` → peer auth dies. nsncd lost an (upstream,
pre-existing) EROFS boot race in every failing run (3× `Error: Read-only file
system` → start-limit-hit) and won it in the baseline — **the baseline's green
was partly luck**. Fix: give miniflux a static system user
(`DynamicUser = mkForce false`), making peer auth a pure /etc/passwd lookup.
Along the way the VM test caught **three more bugs in my provisioner SQL**
(missing `-d miniflux`, psql-17 not interpolating `:'var'` inside `-c`, no
bounded wait in auto mode) — all fixed. Final VM run: GREEN **with nsncd
still dead**, proving the dependency is gone entirely.

---

## a) FULLY DONE

1. **VM regression root-caused** — DynamicUser+peer-auth depends on nsncd
   being alive; proven across 5 VM runs (nsncd dead ⟺ peer auth fails; alive
   ⟺ works) plus the nixpkgs module documentation (`system.nssModules`
   "Only works with nscd!", `"systemd" is appended if nscd is enabled`).
2. **The nsncd EROFS race exonerated as "caused by my diff"** — it kills
   nsncd ~7s into boot, before any of my units exist; my diff only perturbs
   boot timing. It is an upstream/pre-existing VM flake. The final GREEN run
   still had nsncd dead (`start-limit-hit`, 3× EROFS in its log).
3. **Static-user fix shipped in the module**
   (`modules/nixos/services/miniflux.nix`): `users.users.miniflux`
   (isSystemUser, group miniflux) + `DynamicUser = lib.mkForce false`.
   Peer auth no longer touches NSS-at-all beyond `files`. This ALSO removes a
   real production fragility: a wedged nsncd on evo-x2 would crash-loop prod
   miniflux with exactly this error (miniflux was the fleet's only
   DynamicUser+peer-auth service).
4. **Provisioner bug #1: auto-mode bounded wait** — the auto branch did a
   single `count(*)` and exited on first error; now retries 15×2s while the
   DB is empty/unready, fails immediately on 2+ users (auto refuses to
   guess).
5. **Provisioner bug #2: missing `-d miniflux`** — bare psql connects to the
   database named after the invoking USER (as postgres you land in the
   `postgres` DB → `relation "users" does not exist` while the table is fine
   in `miniflux`). Upstream's own dbsetup runs `psql "miniflux"` for the same
   reason. Fixed in the unit AND in the test's verification query.
6. **Provisioner bug #3: psql 17 does NOT interpolate `:'var'` inside `-c`**
   — the literal hit the server (`syntax error at or near ":"`). Replaced
   with charset-guarded inline SQL literals (sub `[A-Za-z0-9-]`, username
   `[A-Za-z0-9@._-]`) — injection-safe by construction, no psql variables.
7. **VM test GREEN end-to-end** (`nix build
   .#checks.x86_64-linux.miniflux` → exit 0): miniflux boots on the static
   user, migrations + CREATE_ADMIN run, `/healthcheck` = OK, admin API auth
   works, `miniflux-oidc-setup` auto-resolves fixture Pocket ID user
   `vmadmin` (deliberately ≠ miniflux admin `admin` — proves resolution by
   uniqueness), converges `openid_connect_id` (UPDATE 1 + SELECT proof in
   journal), idempotent re-run logs "already linked", backup chain intact.
8. **All static gates green**: `nix fmt` (0 changed), `statix` clean on all
   three files, `deadnix` clean, `nix flake check --no-build` → "all checks
   passed!".
9. **Rendered production script verified before deploy** (context-leak →
   build → `bash -n` OK; contains `username="lars"`, `-d miniflux`, psql
   17.11 store path).
10. **`oidcLink.username = "lars"` set explicitly** in configuration.nix
    (auto mode requires exactly ONE Pocket ID user — prod count unverifiable
    without root; `lars` matches both the Pocket ID username and the
    break-glass miniflux admin, with `LIKE 'lars@%'` email fallback).
11. **AGENTS.md Miniflux section rewritten**: new first bullet = the
    static-user/nsncd lesson (class documentation); link provisioner bullet
    now PRIMARY fix with both SQL traps recorded; stale "DynamicUser service"
    phrase fixed; VM-test bullet covers step 5.
12. **`docs/services/miniflux.md` runbook updated**: architecture table
    (static user + provisioner), new static-user section, declarative link
    flow as primary with journal-check line, manual SQL fallback (both
    commands), upstream interactive alternative kept, psql traps recorded,
    VM-test paragraph updated.
13. **All work committed by the daemon** (working tree clean at `b9705b09`).

## b) PARTIALLY DONE

1. **DEPLOY** — attempted 2026-09-17 ~20:50 via `heavy-job nix run .#deploy`;
   the pre-deploy pressure gate BLOCKED it (exit 12): IO PSI some avg10 =
   44.18% with near-idle disks (2.2% busy) — the gate itself flagged the
   D-state corpse-pile signature (one kworker/u130:3+events_unbound in D).
   Nothing was switched; production is untouched. Re-check 2026-09-18 07:53:
   PSI is WORSE (some avg10=49.6, avg60=47.4, avg300=48.0; full avg10=38.7),
   11 D-state threads — consistent with the permanent corpse-pile +
   monitor-amplifier class documented 2026-09-16 (only the owed reboot
   reclaims the phantom component), possibly plus real morning activity.
2. **Cleanup** — worktree `/tmp/mf-bisect` (detached at `52e44d4e`, contains
   the discarded debug instrumentation) still present. All background shells
   from the session have completed. `git worktree remove --force /tmp/mf-bisect`
   is the pending one-liner. (Two other worktrees, `/tmp/pre-mig` and
   `/tmp/sysnix-base`, belong to other sessions — not touching.)
3. **Production verification** — journal proof (`linked miniflux user 'lars'
   -> Pocket ID sub …` or `already linked`), post-deploy-check, and the live
   SSO login all await the deploy.

## c) NOT STARTED

1. **`disableLocalAuth` flip** — owner-gated; requires one proven live SSO
   login first (unchanged gate from the previous session).
2. **nsncd EROFS boot race upstream** — the race still kills nsncd in VM
   boots (and would kill it on prod too, statistically); only MINIFLUX is now
   immune. Filing upstream (nixpkgs or twosigma/nsncd) not started.
3. **Generalizing the NSS lesson** — a global AGENTS.md note ("any new
   DynamicUser + unix-socket peer-auth service needs a static user or it
   will flake in VMs / die when nsncd wedges") is only in the Miniflux
   section, not the gotchas main list.

## d) TOTALLY FUCKED UP

Nothing this session rises to that level — but honest failures, in order of
severity:

1. **I shipped a provisioner with three latent SQL bugs** (no `-d`, psql-var
   interpolation assumption, no auto-branch wait). The VM test caught all of
   them — that is the system working — but each one cost a full ~4-minute VM
   round trip. The `:'u'` interpolation trap was testable in 30 seconds with
   a local `psql -c` probe before ever writing the unit; I wrote against
   documented behavior instead of verifying against the real psql 17.
2. **The previous session's "verified-clean baseline" was luck** — the nsncd
   EROFS race is a coin flip per boot, so "baseline green, HEAD red" was a
   biased experiment. I trusted N=1. A second baseline run would have shown
   the flake and saved the entire unit-facet bisect plan (the summary's
   step-2 branch) — roughly two VM runs wasted on a false premise.
3. **The first deploy attempt started a full build without checking PSI
   first** — the gate then blocked at exit 12. Cheap pre-flight (`cat
   /proc/pressure/io`) before invoking deploy would have routed straight to
   the force-or-wait decision.

## e) WHAT WE SHOULD IMPROVE

1. **Pressure gate needs the corpse-pile discriminator** (guard Zone 6
   pattern: only block when disk-busy corroborates PSI). A gate that
   permanently blocks on a phantom class trains the operator to use
   `DEPLOY_FORCE_PRESSURE=1` — which then also bypasses REAL storms. The
   2026-09-16 note already describes the false-positive mechanism; the gate
   predates Zone 6's disk-busy corroboration fix.
2. **VM tests should fail LOUDLY (or at least annotate) when nsncd dies** —
   every future DynamicUser service VM test will hit this class. A
   test-helpers assertion ("nsncd active or the config declares no
   DynamicUser+peer service") would turn the mystery into a named failure.
3. **The deploy flow could pre-check pressure before building** (gate order),
   saving a toplevel build when blocked.
4. **`pocket-id` user-count introspection** — the provisioner's loud failure
   prints the user table on mismatch, but a root-runbook one-liner to LIST
   Pocket ID users (for choosing `oidcLink.username`) would remove the
   guesswork I worked around by pinning `username = "lars"`.
5. **Consider an eval-time audit** mirroring `dynamic-user-audit.nix`:
   "DynamicUser unit whose Exec talks to a local postgres over peer auth"
   → warning (the miniflux class).

## f) NEXT TASKS (prioritized)

**This feature (in order):**
1. Decide deploy: force now (`DEPLOY_FORCE_PRESSURE=1` — evidence says
   phantom) vs wait for reboot/quiet window.
2. Deploy → verify `journalctl -u miniflux-oidc-setup` (expect `linked …
   'lars' -> Pocket ID sub <uuid>` or `already linked`) + `getent passwd
   miniflux` (static user present) + miniflux healthy on :8101.
3. `nix run .#post-deploy-check` (miniflux §smoke is enable-gated and will
   run).
4. User performs ONE live SSO login at `https://rss.home.lan` (journal proof
   `User authenticated successfully using OAuth2 … username=lars`).
5. Owner decision: flip `services.miniflux.disableLocalAuth = true` (SSO-only
   posture) after 4.
6. `git worktree remove --force /tmp/mf-bisect && git worktree prune`.
7. If the user DID run the manual paste with a wrong sub: confirm the
   provisioner converged it (its converge-on-different-sub branch rewrites).
8. Update the 2026-09-17_15-13 status report with a "RESOLVED" pointer to
   this doc (the old doc's open questions 1-3 are answered here).

**VM/infra class (from this session's findings):**
9. Global AGENTS.md gotcha: "DynamicUser + peer auth only resolves while
   nsncd lives — use a static user" (currently only in the Miniflux section).
10. Add the nsncd-activity annotation to `tests/test-helpers.nix` (task e2).
11. Pressure-gate corpse-pile discriminator (task e1) + fixture test.
12. Investigate/file the nsncd EROFS boot race upstream (nixpkgs `nscd`
    module / twosigma/nsncd): Type=notify unit racing its RuntimeDirectory —
    reproducible ~50% in NixOS VMs.
13. Eval-time audit for DynamicUser+peer-auth combos (task e5).
14. Verify no OTHER fleet service silently depends on nsncd (samba? systemd
    DynamicUser units doing name lookups of dynamic peers) — one audit sweep.

**Standing items I touched or re-confirmed this session (from AGENTS.md, not
re-researched):**
15. The OWED REBOOT — clears the D-state corpse pile, the flm corpse pinning
    :52626, and the PSI phantom that keeps blocking deploys; run
    `nix run .#pre-reboot-check` first (it exists for exactly the
    stuck-boot class).
16. flm staged v1.0.3 go-live (post-reboot candidate fix for the corpse
    class) — live-serve validation + no re-pull needed (v1.0.3 died
    pre-model-load; weights intact).
17. llama-rag mid-load CPU-spin regression (config-disabled 2026-09-16) — pin
    llama-cpp back or bisect gfx1150 upstream, then re-enable.
18. crush-hot-db first migration never ran (no `/mnt/hot/crush` yet) —
    verify post-reboot when no crush session holds the pgrep guard.
19. Mail relay go-live: verify `larsartmann.cloud` in Resend (SPF/DKIM), then
    re-test send; Pocket ID needs its own new Resend key.
20. Turso decision for DiscordSync (upgrade plan vs permanent local-only;
    currently encoded local-first with the standing red check).
21. Hetzner StorageBox + BorgBackup offsite leg (decided, not implemented).
22. Pocket ID groq key decision (ChatService warn on `/health`).
23. Signoz dashboard overlap lint / provisioner convergence checks are green
    — keep the "read FAILED lines, not the final count" doctrine in mind for
    the next dashboard edit.
24. Gatus "DiscordSync Turso Sync Active" red check is BY DESIGN — do not
    silence.
25. Monitor365 re-enable needs the private wireguard-collector decision
    (publish crate / public repo / vendor).
26. CV: defense-search portals funnel is live; CI still dead (hosted
    minutes) — keep probing CV revs locally before lock moves.
27. Per-service BTRFS subvolume doctrine (Phase 2 `services.hot-db` fold-in
    for crush-hot-db when ratified).
28. Retire the stale `KNOWN_NEW_METRICS` loan entries flagged by
    metrics-gate.sh WARNs, if any are active.
29. sops-nix overlay shim (`buildGo125Module` aliases) — drop when sops-nix
    > 13616fff lands upstream.
30. Playwright/d2 overlay shims — drop when nixpkgs repairs playwright
    (re-check on next nixpkgs bump).

(Stopped at 30 honest items rather than padding to 50.)

## g) QUESTIONS (I cannot answer these myself)

1. **Did you already run the manual sudo paste** (deriving the sub from
   Pocket ID's SQLite and `UPDATE users SET openid_connect_id=… WHERE
   username='lars'`)? If yes with the CORRECT sub, the provisioner will
   report `already linked`; if with a WRONG value, it will converge (rewrite)
   — either outcome is safe, I just want to predict the journal for
   verification.
2. **Deploy decision:** the PSI looks like the permanent corpse-pile phantom
   (disks near-idle, D-state corpses, avg300 sustained ~48% this morning).
   Force now (`DEPLOY_FORCE_PRESSURE=1`), wait for a quiet window, or fold
   the deploy into the owed reboot? Until deployed, `rss.home.lan` SSO keeps
   400ing.
3. **Is your Pocket ID username exactly `lars`** (email prefix `lars@…`)? If
   it differs, tell me the actual username — I'll change the one
   `oidcLink.username` line before deploying. (I cannot read Pocket ID's DB
   without root, and the provisioner's loud-failure journal would only show
   it after a failed deploy.)

---

*Verification trail: 5 VM runs (drv logs referenced in-session:
`5n37i2vx…` bisect-disabled, debug-instrumented, `4yw5aqy7…` static-user,
`xs4xcjh0…` -d fix, `yx6302l5…` guarded SQL, final GREEN out
`7bg3nxb4…-vm-test-run-miniflux`); nsncd-dead-yet-green proof in the final
run's log (`nscd.service: Failed with result 'start-limit-hit'` present,
test exit 0).*
