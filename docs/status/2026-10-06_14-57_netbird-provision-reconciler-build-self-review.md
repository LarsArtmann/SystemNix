# NetBird Phase-2 Provisioning Reconciler — Build, Verification & Brutal Self-Review

**Date:** 2026-10-06 14:57 CEST · **Session:** netbird status → "why not nix?" → "shouldn't
pbx-artmann set things up?" → "just do what you can" → reconciler built + verified
**Scope:** this session's work only. Format: `.md` at operator's explicit demand (skill
default is HTML — override flagged, not propagated back into the skill).

**One-paragraph state:** pbx-artmann now carries a `netbird-provision.service` + timer that
idempotently provisions the ENTIRE NetBird Phase-2 surface (setup key, `lan` network +
`192.168.1.0/24` route with evo-x2 as masquerading routing peer, `lan-dns` nameserver
group, `lan-access` policy) via the management API on loopback, gated on a runtime PAT
secret, pinned by contract invariants, and functionally proven against a mock management
API that caught two real bugs before they could ship. NOT deployed (owner-run SSH only),
and this review found one real ordering bug in my own handover instructions (§d.1).

---

## a) FULLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Evidence                                           |
| - | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| 1 | **API shapes verified from source, not vibes** — deployed netbird is **0.80.0** (eval of the pinned nixpkgs `a7868a72`; the runbook's "v0.79.0" claim was stale). Auth `Authorization: Token nbp_…`; setup-keys (`expires_in` in SECONDS, plain key returned once); networks/resources/routers; `/api/dns/nameservers` (UDP-only enum); policies; peers — all read from the tagged OpenAPI spec (`shared/management/http/api/openapi.yml` @ v0.80.0), not docs prose                                                 | spec fetched + parsed in-session                   |
| 2 | **`hosts/pbx/netbird-provision.nix`** — oneshot + 30-min timer reconciler; `ConditionPathExists` on the PAT (inert until pushed); talks to `127.0.0.1:<management.port>` (port derived from config, never hardcoded — contract-pinned); PAT passed via `curl -H @file` (never argv/ps-visible); plain setup key stored 0600 root-only at `/var/lib/netbird-provision/setup-key`, NEVER logged; `OnFailure → pbx-alert@`; router creation deferred until evo-x2 enrolls (chicken-egg by design, exit 0 while waiting) | file + mock runs below                             |
| 3 | **Secrets plumbing** — `netbird_api_pat` added to `generate.sh` fake_secrets (single source of truth) with rationale comment; `push-secrets.sh` restart list gained `netbird-provision` (immediate reconcile after PAT push); derivation verified by the `internal/secretslist` Go test (green)                                                                                                                                                                                                                      | `go test ./internal/secretslist/` ok               |
| 4 | **Contract extended** — 10 → **15 eval invariants** + **3 build-time script-content greps** (loopback-target, no-public-vhost, header-file auth). Check builds green and prints "15 invariants hold"                                                                                                                                                                                                                                                                                                                 | `nix build .#checks.x86_64-linux.netbird-contract` |
| 5 | **Functional proof via mock management API** — a throwaway Python mock of the v0.80 endpoints; scenarios: cold start w/o evo-x2 (creates everything, defers router), idempotent re-run (all "already present"), enrollment transition (router lands, "converged"), converged re-run, bad PAT (FATAL rc=1 → would fire pbx-alert). Setup-key file mode verified 600; key value confirmed absent from stdout                                                                                                           | run logs in session                                |
| 6 | **Static gates** — shellcheck clean (`-S warning`) on the extracted script body AND `scripts/push-secrets.sh`; `bash -n` clean; **both-arch toplevel evals green** (pbx + pbx-aarch64 — the repo's own hard rule); `nix fmt` clean; docs-gates ritual PASS (tests=57/checks=19/apps=7 unchanged — I added zero checks, only invariants inside an existing one)                                                                                                                                                       | session outputs                                    |
| 7 | **Docs updated, all surfaces** — pbx `docs/runbooks/netbird-deploy.md` Post-deploy rewritten (automated flow), stale "9 invariants" → 15; pbx `TODO_LIST.md` §11 row rewritten; pbx `AGENTS.md` gained the provisioning bullet; SystemNix `docs/services/net-vpn.md` Phase 2 rewritten (steps 3/6 replaced: PAT + fetch-key instead of dashboard clicking); SystemNix `docs/todo/services.md` row 169 rewritten to the new flow                                                                                      | rg-diffable in tree                                |
| 8 | **Hygiene** — mock server killed, all /tmp scratch trashed (trash, not rm); daemon commits inspected (`git show --stat`) — my files landed intact; SystemNix tree clean after daemon sweep                                                                                                                                                                                                                                                                                                                           | `ss`/`ls` post-checks                              |

## b) PARTIALLY DONE

1. **Deployment readiness is asserted, not proven.** I ran evals + the contract check, but
   NOT the repo's own deploy-train gates: `nix build …toplevel -o /tmp/pbx-toplevel-root`
   (staging), `nix run .#deploy-freshness`, `nix run .#secrets-preflight`. The repo AGENTS
   explicitly demands deploy-freshness after ANY host edit. The staged root currently on
   /tmp is the Oct-5 22:33 train — which does NOT contain `netbird-provision.service`.
2. **Handover instructions** — delivered, but with the ordering bug in §d.1.
3. **SystemNix client flip** — correctly untouched (sops file absent by design; enabling
   now would fail activation — that gate is intentional and verified previously).

## c) NOT STARTED

1. Repo-permanent automated coverage for the provisioner script (the mock harness was
   throwaway — see §e.6, the session's biggest gap).
2. Drift correction (reconciler is create-if-missing only — §e.7).
3. Phase-3 exit node — out of scope, correctly.
4. Any live pbx verification — impossible for me (no-SSH rule), owner steps pending.

## d) TOTALLY FUCKED UP!

1. **My handover ordering is WRONG and I shipped it into three doc surfaces.** I wrote
   "save PAT → `push-secrets.sh` → deploy". With the Oct-5 staged root still at
   `/tmp/pbx-toplevel-root` (verified present, lacks `netbird-provision.service`), the
   push-secrets dead-unit guard I myself extended will **FATAL** ("netbird-provision not
   in the staged closure") — the guard working exactly as designed, against MY
   instructions. Correct order: **build + stage the new toplevel FIRST, then push, then
   switch.** Surfaces carrying the bug: pbx runbook Post-deploy step 2, SystemNix
   net-vpn.md Phase 2 step 3, both TODO rows. Not yet fixed (you said report + wait);
   queued as §f.1.
2. **"All gates green" in my closing summary was an overclaim.** True: evals, contract,
   shellcheck, fmt, docs-gates, secretslist. Untouched/unknown: deploy-freshness,
   secrets-preflight, full toplevel build. I said "all gates green" for the gates I had
   run — the honest phrasing was "all gates I ran." Exactly the count-claim class this
   repo already has a correction rule for (2026-09-29): name WHICH surface the claim
   covers.
3. **Predictable stumbles burned roundtrips:** the untracked-new-module eval failure
   (documented VERBATIM as the tracked-files trap in SystemNix AGENTS — I hit it anyway);
   `rg -rn` misused twice (the `-r n` flag rewrote match text to "n", mangling two
   outputs); two failed attempts to `nix build` an outPath string; a sed over-capture
   (`'';` semicolon) that shellchecked garbage. All recoverable, all avoidable.
4. **First contract invariant tested the wrong thing** — `builtins.toString ExecStart`
   yields the store PATH NAME, not script content; my "loopback" boolean was vacuous.
   Caught because I built the check (it failed), fixed with build-time greps. The process
   worked; the first draft was wrong-headed.

## e) WHAT WE SHOULD IMPROVE (brutal-honesty pass)

1. **What did you forget?** The deploy-train gates (§b.1) and the push-secrets/staged-root
   interaction (§d.1) — both consequences of stopping at "evals green" instead of walking
   the repo's OWN documented deploy ritual end-to-end before writing handover text.
2. **Stupid things we do anyway:** embedded `writeShellScript` bodies had ZERO automated
   coverage until I hand-built a throwaway mock — and that mock caught 2 real bugs
   (`$3` unbound under `set -u`; doubled `/api` prefix) in its first minutes. The testing
   value was proven and then thrown in the trash. That is the stupidest outcome of this
   session: verified-once, reproducible-never.
3. **Ghost systems:** none — every piece is wired (import, units, timer, secret list,
   restart list, contract, docs). Verified by the daemon-commit `git show --stat` + evals.
4. **Split brains (small, real):** the reconciler's object names/constants
   (`evo-x2-enroll`, `lan`, `lan-dns`, `lan-access`, `192.168.1.53`, matched domains) now
   live in the script AND in four prose surfaces (runbook, net-vpn.md, two TODO rows). The
   script is truth; prose can drift silently. Contract pins behavior, not these constants.
5. **Did I lie?** One overclaim (§d.2), self-caught here. Everything else in the closing
   summary is grep/verifiable. The "mock-API tested" phrasing in TODO rows is accurate but
   must not imply permanent coverage (§e.2).
6. **Testing:** promote the mock harness to a real check. Also: my `Authorization: Token
   %s` grep is a weak proxy — assert `-H @` usage directly.
7. **Reconciler semantics decision owed:** create-if-missing (current, minimal) vs full
   reconcile (dashboard edits get reverted). Undocumented tradeoff = future confusion.
8. **Edge nobody owns yet:** setup key expires in 30d; if the SystemNix flip happens later
   than that, the sops'd key is dead, the provisioner silently mints a NEW key (file
   overwritten), and the only failure signal is evo-x2's login oneshot failing.
9. **Parallel-session discipline (late flag):** `nix fmt` realigned TODO_LIST.md + a
   2026-10-06 status doc mid-session — reviewed as formatting-only, but per the shared-tree
   rule I should have flagged it to you IMMEDIATELY, not in a report. Flagging now.
10. **Scope creep:** resisted — no exit-node, no drift-correction, no Gatus additions
    smuggled in. Good.

## f) Next things (ranked, honest — 14, not padded to 50)

| #  | Task                                                                                                                                                                                                                                          | Impact | Effort | Status surface                |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ----------------------------- |
| 1  | Fix the handover ordering in all 4 surfaces: stage new toplevel BEFORE push-secrets (runbook Post-deploy, net-vpn.md step 3, TODO row 169, TODO §11 row) — and add the one-line rationale (guard FATALs on units absent from the staged root) | High   | S      | NEW rows below (§d.1)         |
| 2  | Build + stage the new pbx toplevel to `/tmp/pbx-toplevel-root`, run `nix run .#deploy-freshness` + `.#secrets-preflight` — close §b.1                                                                                                         | High   | S      | NEW row                       |
| 3  | Promote the mock-API harness to a permanent pbx-artmann check (tests/ + checks.nix); the throwaway caught 2 bugs pre-ship                                                                                                                     | High   | M      | NEW row                       |
| 4  | Owner: dashboard login → mint PAT → (stage first!) → push-secrets → test/switch → `systemctl start netbird-provision.service`                                                                                                                 | High   | 15min  | existing row (updated)        |
| 5  | Owner: `ssh root@pbx cat /var/lib/netbird-provision/setup-key` → SystemNix sops `netbird_setup_key` → flip `services.netbird-client.enable` → `nix run .#deploy`                                                                              | High   | 15min  | existing row (updated)        |
| 6  | Post-flip verify: provisioner journal shows "converged" incl. router; `/api/peers` lists evo-x2                                                                                                                                               | High   | S      | NEW row (blocked:deploy)      |
| 7  | Contract hardening: grep for `-H @` (real header-file assertion) + negated `Token $pat`-in-argv pattern                                                                                                                                       | Medium | S      | NEW row                       |
| 8  | Decide reconciler drift semantics (create-if-missing vs full reconcile) and document in the module header                                                                                                                                     | Medium | S      | NEW [decision] row            |
| 9  | Setup-key expiry edge: document the 30d-vs-delayed-flip hazard in net-vpn.md step 4 (or alert on provisioner re-minting)                                                                                                                      | Medium | S      | NEW row                       |
| 10 | Annotate the runbook's stale "v0.79.0" line (truth: 0.80.0 via pinned nixpkgs)                                                                                                                                                                | Low    | S      | NEW row                       |
| 11 | Pin the reconciler's object-name constants in the contract (kill the §e.4 prose-drift split brain)                                                                                                                                            | Low    | S      | NEW row                       |
| 12 | RAM watch on cx23 — one more timer-driven unit (trivial load; existing watch row stands)                                                                                                                                                      | Low    | S      | existing row                  |
| 13 | Phase-3 idea: exit-node network could ALSO be provisioner-owned (behind a flag) once burn-in + D6 land                                                                                                                                        | Low    | M      | ROADMAP-adjacent; parked here |
| 14 | Cross-project lesson (crush-config `references/lessons.md`, needs commit — outside this session's authority): "embedded writeShellScript bodies: extract + mock-test before claiming tested; the extraction needs the `'';`-semicolon fix"    | Medium | S      | parked (needs repo commit)    |

**Harvest accounting:** 1, 2, 3, 7, 8, 9, 10, 11 are NEW → landed as rows in
`docs/todo/services.md` + [ready] one-liners in `TODO_LIST.md` (1+2 marked do-first); 4/5
pre-exist (updated this session); 6 NEW (blocked:deploy); 12 pre-exists; 13/14 deliberately
NOT queued (13 awaits burn-in + is an owner-intent question; 14 requires a commit to a
different repo — recorded here per the "deliberately not harvested because X" rule).

## g) Questions I cannot answer myself

1. **Is another session currently owning the pbx staging area?** `/tmp/pbx-toplevel-root`
   is the Oct-5 22:33 build. Replacing it is routine per the /tmp GC-root policy ("rotate
   roots only after a VERIFIED switch, never mid-staging from another session") — but I
   cannot know whether a parallel session is mid-staging. Answer decides whether §f.2 runs
   now or waits.
2. **Reconciler drift semantics (§e.7):** create-if-missing (dashboard edits win — current
   behavior) or full reconcile (repo intent wins, dashboard edits get reverted)? Both are
   defensible; it's an ownership philosophy call.
3. **When do you plan the login + PAT mint?** If it's not within ~a few days, I'd rather
   re-order §f so the doc fixes + permanent mock test land first and the handover stays
   fresh; if it's today, §f.1/§f.2 should land before you touch anything.

---

_Report written per status-report skill with brutal-self-review questions folded into §d/§e.
Auto-commit daemon owns the commit. WAITING FOR INSTRUCTIONS._
