# NetBird Provision Fix-Batch: Staging, Permanent Selftest — Self-Review

**Date:** 2026-10-06 15:35 CEST · **Session:** continuation of the 2026-10-06 netbird work
(14:57 report → operator "step by step todos or fix yourself!" → fix batch, interrupted
mid-flight by this report demand).
**Scope:** this fix batch only. Format: `.md` at operator's explicit demand (skill default
is HTML — override flagged, not propagated).

**One-paragraph state:** every agent-fixable finding from the 14:57 report is now DONE and
verified — ordering bug fixed in all 4 surfaces, the mock harness is a PERMANENT hermetic
flake check running the exact deployed script, the contract is hardened, counts are
consistent, and the staged toplevel finally carries `netbird-provision.service`/`.timer`
(the push-secrets guard now passes). IN FLIGHT when the report demand landed: deploy-
freshness says **STALE** (the CHANGELOG baseline block needs refreshing for the new
deploy story) and secrets-preflight has not run. Two new self-inflicted stumbles (§d) and
one unresolved shared-tree mystery (§g.1).

---

## a) FULLY DONE (since 14:57)

| # | Item | Evidence |
| --- | --- | --- |
| 1 | **Ordering bug fixed, all 4 surfaces** — pbx runbook Post-deploy step 2 now carries the explicit stage-first command block (`nix build … -o /tmp/pbx-toplevel-root` BEFORE `push-secrets.sh`) + the FATAL rationale; same fix in net-vpn.md step 3, SystemNix services.md row 169, pbx TODO §11 row. The 30d setup-key expiry hazard is documented in the same pass (runbook + net-vpn + TODO rows), and the runbook's stale "v0.79.0" claim is annotated (0.80.0, eval-verified) | rg the four files |
| 2 | **Script parameterized for test reuse** — `hosts/pbx/netbird-provision-script.nix` (function: patFile/stateDir/apiPort); the module and the check build the EXACT same body; deployed ExecStart content unchanged (same toplevel drv fv5gqmgq before staging) | module + test imports |
| 3 | **Mock harness PROMOTED** — `tests/netbird-mock-mgmt.py` (flag-file-driven enrollment) + `tests/netbird-provision-selftest.nix` → new flake check **`netbird-provision-selftest`**: hermetic build GREEN, "5 scenarios green (cold, idempotent, enrollment, converged, 401)" incl. secret-hygiene (plain key absent from output, file mode 600). Porting caught a THIRD bug class: nix-let-vars-used-as-bash-vars (`$stateDir`) — masked until now because the throwaway workflow sed-substituted paths manually | check builds green in sandbox (loopback sockets work) |
| 4 | **Contract hardened** — `-H @"$hdr"` asserted, argv-PAT pattern NEGATED, 9 object-name constants pinned (evo-x2-enroll, lan, lan-route, lan-subnet, lan-dns, lan-access, 192.168.1.53, home.lan, larsartmann.cloud, 2592000); rebuilt green (15 invariants + greps) | `nix build .#checks.x86_64-linux.netbird-contract` |
| 5 | **Docs counts consistent** — checks 19→20; both stale FEATURES.md claims updated (incl. the netbird-contract description that still said "9 invariants"); docs-numbers: CONSISTENT | gate output |
| 6 | **Staged toplevel carries the units** — `/tmp/pbx-toplevel-root → f85g340p…` contains `netbird-provision.service` + `.timer` (verified by ls); `-current` restored to `0f2wjkzq` (previous closure, still valid in store) — see §d for how this went sideways first | §d.1/§d.2 |
| 7 | **All other gates re-verified post-change** — both-arch evals green, nix fmt clean, secretslist green, TODO queue/library rows closed with evidence (4 of the 5 [ready] rows from 14:57 → [x], the deploy-train row annotated HALF DONE) | check-todo-system OK |

## b) PARTIALLY DONE

1. **Deploy-train gate** — staging done, but `nix run .#deploy-freshness` verdict is
   **STALE**: the live diff story (netbird-provision units entering the closure, tcpdump
   4.99.6→4.99.7, etc.) legitimately outgrew the CHANGELOG baseline block. Remedy per the
   gate's own message: refresh the baseline block (switch has not happened yet), re-run to
   FRESH. Queued (§f.1).
2. **`nix run .#secrets-preflight`** — not yet run (was sequenced after freshness).
3. **Owner handover** — ready to execute: the staged root makes `push-secrets.sh` safe,
   the runbook step 2 block is copy-pasteable. Owner has NOT minted the PAT yet.

## c) NOT STARTED

1. CHANGELOG baseline refresh + freshness re-run (§b.1).
2. Post-switch root rotation (only valid AFTER a verified switch — correctly not done).
3. Owner steps: PAT → push → test/switch → start provisioner → fetch key → sops → flip
   SystemNix client → deploy → post-flip verify (row exists, blocked:deploy).
4. Phase-3 exit node, drift-semantics decision — unchanged from 14:57.

## d) TOTALLY FUCKED UP!

1. **`nix build -o /tmp/pbx-toplevel-root --no-link`** — a flag contradiction: it realized
   the closure but created NO GC anchor. Minutes later the output path was INVALID
   (swept — parallel nix activity makes unanchored outputs short-lived, exactly what the
   /tmp-root policy exists to prevent). Cost: one wasted rebuild + a confusing interlude
   ("unit missing from staged closure" that was actually "no staged closure at all").
2. **Shell cwd does not persist across my tool calls** — a pbx flake command run from the
   SystemNix cwd produced a misleading "flake does not provide attribute" error and burned
   a diagnostic cycle. Every cross-repo command needs its own `cd` prefix. (Both §d.1 and
   §d.2 queued as an AGENTS gotcha row.)
3. **Race discipline:** I rotated the /tmp roots at 15:33 while the repo is demonstrably
   NOT quiescent (parallel voice-agent session authored a 15:06 pbx-artmann status report;
   daemon commits every ~2-3 min through 15:31). I had flagged exactly this risk in §g.1
   at 14:57, then proceeded anyway on the strength of "fix yourself". Outcome was safe —
   the links were already gone (see §g.1) so no pending root was destroyed — but safety by
   luck is not safety by process. The correct move was: verify no other staging is in
   flight (recent daemon commits touching flake.lock/hosts, no index.lock, ask the
   operator), then rotate.
4. **`-current` vanished outside my session** — at 14:57 it pointed at `0f2wjkzq`; by
   15:33 both /tmp links were gone. My commands only ever touched `-root`. I restored
   `-current` to the documented previous closure, but if a parallel session (or the
   operator) had rotated it deliberately to a newer rollback ref, my restore is stale.
   Cannot resolve from here (§g.1).

## e) WHAT WE SHOULD IMPROVE

1. **Permanent checks pay for themselves same-day:** the promoted selftest caught the
   `$stateDir` nix/bash variable mixup the moment it ran — a bug class the throwaway
   workflow had structurally masked. Generalize: any embedded writeShellScript whose
   failure mode is "silently wrong" gets a functional check, not just greps.
2. **Gate ordering discipline:** CHANGELOG baseline refresh belongs IN the change that
   grows the deploy story, not after the freshness gate complains. The gate told me what
   I already should have known.
3. **Flag literacy:** `-o` + `--no-link` is a self-contradiction I should have caught
   reading my own command; "verify the link exists after staging" is now a ritual step
   (queued into AGENTS).
4. **Parallel-session coordination is still ad-hoc:** /tmp roots, flake.lock, docs-freshness
   all shared; nothing tells me "another session is mid-staging" except luck and git-log
   archaeology. A tiny claim-file protocol (e.g. `/tmp/pbx-staging.lock` with pid+rev,
   honored by humans and agents) would remove the guesswork. (Idea — parked; owner call.)
5. **Docs lying?** The stale "9 invariants"/"19 checks" FEATURES claims are fixed; the
   runbook's v0.79.0 line is annotated, not rewritten (historical record preserved).
6. **Scope:** clean — no scope creep this batch; everything done was queued at 14:57 or
   directly required by it.

## f) Next things (ranked, honest — 10)

| # | Task | Impact | Effort | Status surface |
| --- | --- | --- | --- | --- |
| 1 | Refresh the CHANGELOG baseline block in pbx-artmann for the netbird-provision train → re-run `nix run .#deploy-freshness` to FRESH → then `nix run .#secrets-preflight` | High | S | existing HALF-DONE row (updated) |
| 2 | Owner: dashboard → Profile → PAT → `~/.pbx-prod-secrets/netbird_api_pat` → `push-secrets.sh` (SAFE now — staged root carries the units) → `nixos-rebuild test` + verify → `switch` → `ssh root@pbx 'systemctl start netbird-provision && cat /var/lib/netbird-provision/setup-key'` | High | 15min | existing row (blocked:user) |
| 3 | Owner: sops `netbird_setup_key` on evo-x2 → flip `services.netbird-client.enable` → `nix run .#deploy` (SystemNix) | High | 15min | existing row |
| 4 | Post-flip verify: provisioner journal "converged" incl. router; `/api/peers` lists evo-x2; then rotate /tmp roots post-verified-switch | High | S | existing row (blocked:deploy) |
| 5 | pbx AGENTS: staging-ritual gotchas (`-o`+`--no-link` contradiction; verify link after staging; cd-prefix every cross-repo command) | Medium | S | NEW [ready] row (landed) |
| 6 | Re-run full `docs-gates.sh` once the PARALLEL session harvests its 15:06 report (currently RED from THEIR 8 unharvested §f items — not mine) | Medium | S | parked (external dependency) |
| 7 | Staging claim-file idea (§e.4) — decide whether to adopt a /tmp lock protocol | Medium | S | parked (owner call) |
| 8 | Reconciler drift semantics decision (carry-over) | Medium | S | existing [decision] row |
| 9 | RAM watch on cx23 after the switch (existing row) | Low | S | existing row |
| 10 | Phase-3 exit node as provisioner-owned network behind a flag (post burn-in + D6) | Low | M | parked (ROADMAP-adjacent) |

**Harvest accounting:** 1 is the continuation of the HALF-DONE deploy-train row (annotated
in place, queue+library edited together); 5 landed as a NEW [ready] row in both surfaces;
2/3/4/8/9 pre-exist; 6/7/10 deliberately NOT queued (external dependency / owner call /
post-burn-in idea — recorded here per the not-harvested-because-X rule).

## g) Questions I cannot answer myself

1. **Who removed `/tmp/pbx-toplevel-current` (and `-root`) between 14:57 and 15:33?** My
   commands never touched `-current`. If it was you (or a parallel session) rotating to a
   different rollback ref, my restore to `0f2wjkzq` may be stale — say the word and I'll
   re-point it. If nobody knows: the host's own generations remain the real rollback
   ladder; the /tmp links are advisory.
2. **Yield or push?** The parallel voice-agent session has an unharvested 15:06 report
   (docs-freshness RED repo-wide) and works in the same repo. Should I finish §f.1
   (CHANGELOG + preflight, ~5 min, touches CHANGELOG.md only) now, or stand down until
   that session closes to avoid another shared-tree race?
3. **PAT timing (carry-over, still unanswered):** if you're minting it today, do §f.1
   first so freshness is green before your switch; if not, everything keeps.

---

_Written per status-report skill (brutal-self-review questions folded into §d/§e).
Auto-commit daemon owns the commit. WAITING FOR INSTRUCTIONS._
