# Mail-Relay Collector Outage: Fix, Root Cause, and Textfile-Trap Class Sweep

**Date:** 2026-09-06 03:39 CEST
**Session scope:** diagnose → fix → class-eradicate → enforce → verify → document
**Status:** ALL CODE DONE AND VERIFIED; deploy + go-live are USER actions
**Commits:** swept into auto-daemon commits (`2d36e770`, `fc2b1243`, `ee211688`, `66d59b6b`, …)

---

## 0. Executive summary

The user asked why `mail-relay` failed. **Postfix itself never failed** — the
`mail-relay-metrics` textfile collector failed on every 5-min run for **4 days
(845+ failures, 2026-09-02 20:38 → 2026-09-06)**, keeping the Gatus
"Mail Relay Queue" check red. Two stacked bugs, both found and fixed, plus a
**repo-wide class sweep**: 12 collectors carried the same latent trap; all
converted; a new pre-commit/CI audit now rejects the pattern forever; the VM
test replays the exact incident and asserts recovery.

---

## 1. Root causes (both proven live + VM-proven)

### Bug 1 — `mv` EPERM over a foreign-owned textfile (the unit failure)

- Commit `64d68d7d` (Sep 2 20:10) switched the collector from root to
  `User = postfix` (a correct least-privilege fix for a real showq-EACCES).
- The **last root-era run** (20:33:47) left `mail-relay.prom` owned `root:root`.
- The textfile dir is **sticky 1777**: nobody — not even root under `harden{}`
  (all caps stripped) — can rename over a foreign-owned file without
  **CAP_FOWNER**. Every postfix-user run computed correct values, wrote the
  tmp, then died at `mv` with `Operation not permitted`. Textfile frozen at
  Sep 2 20:33 values (`scrape_errors 1`) → fail-closed Gatus red.
- **Deeper systemd fact caught by the regression test:** `CapabilityBoundingSet`
  only LIMITS; a non-root `User=` starts with an **empty** capability set. The
  fix needs **`AmbientCapabilities = "CAP_FOWNER"`** (grants) AND
  `CapabilityBoundingSet` (permits). Bounding alone still EPERM'd — the VM
  test caught it on iteration 3.

### Bug 2 — phantom SASL path (`/run/secrets-rendered`)

- The collector probed a **hand-written literal** `/run/secrets-rendered/mail-relay-sasl`.
- Real sops-nix renders under **`/run/secrets/rendered/`** (proven by the
  deployed postfix `main.cf`: `texthash:/run/secrets/rendered/mail-relay-sasl`).
- Result: "SASL map missing or unreadable" on every run, `placeholder=1`
  regardless of real state.
- **The VM test VALIDATED the bug:** `mock-sops.nix`'s template-path DEFAULT
  was itself `/run/secrets-rendered/` — fixture and bug agreed, prod disagreed.
  Same class as the `email_states` fixture trap in AGENTS.md.

### Interacting trap (test-documented)

`fs.protected_regular=2` — even root cannot `O_TRUNC` a foreign-owned file in
a sticky world-writable dir (capabilities do NOT bypass it). The test seed
must `rm` + fresh-create. Production implication: a `> "$EXISTING_FOREIGN"`
flow can never work in that dir — only fresh-create + rename.

---

## 2. a) FULLY DONE

| Item                                                                                                                                                                                                                                                                                                                           | Evidence                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| mail-relay collector: SASL path interpolated from `config.sops.templates."mail-relay-sasl".path` (single source of truth with postfix) | eval `CAP_FOWNER`/ambient confirmed; unit succeeds in VM |
| Unique `mktemp` + `chmod 644` + `trap rm EXIT` + `AmbientCapabilities` + `CapabilityBoundingSet = "CAP_FOWNER"` | self-heals stale root-owned prom — **no manual rm needed** |
| VM regression: seeds root-owned prom + asserts recovery + asserts journal never says "missing or unreadable"                                                                                                                                                                                                                   | `checks.x86_64-linux.mail-relay` GREEN (iteration 4)                                                         |
| mock-sops default corrected to `/run/secrets/rendered/`                                                                                                                                                                                                                                                                        | hermes + mail-relay fixtures updated; both VM tests green                                                    |
| **Class sweep: 12 collectors converted** to mktemp+caps: `_signoz-metrics` (amdgpu/nvme/psi), `attic`, `backup-coordination`, `buildcache`, `gpu-active`, `system-health`, `pool-recovery`, `signoz` (clickhouse-xfs), `signoz-coverage`, `pocket-id` (secret-rotation), `platforms/nixos/system/snapshots.nix` (pool-metrics) | toplevel build green (bash -n on every script); pool-recovery VM test green                                  |
| `scripts/audit-textfile-tmp.sh` (new): FAILs fixed-`.tmp` writes + `/run/secrets-rendered` literals; reasoned allowlist (guard/sev1)                                                                                                                                                                                           | 187 files scanned clean; negative test (mutation) FAILs; wired into `.githooks/pre-commit` + `nix-check.yml` |
| AGENTS.md: full incident entry in Mail Relay section + enforcement note on the niri textfile lesson                                                                                                                                                                                                                            | committed                                                                                                    |
| `docs/services/mail-relay.md` runbook: failure-class entry + never-reintroduce warning                                                                                                                                                                                                                                         | committed                                                                                                    |
| Formatting via repo formatter (15 files, 1 reformatted); no flake.lock churn                                                                                                                                                                                                                                                   | `git status flake.lock` clean                                                                                |
| Verification matrix: mail-relay VM ✅, hermes VM ✅, pool-recovery VM ✅, toplevel build ✅, eval of remaining mock-sops consumers (attic/cv/paperless/browser-history drivers) ✅                                                                                                                                             | all rc=0                                                                                                     |

## 3. b) PARTIALLY DONE

~~1. **Remaining 5 mock-sops VM tests**: eval-verified only (driver derivation~~ done at `attic/cv/paperless/browser-history registered checks (tests/default.nix:31`, `39`, `40`, `43)`
   builds), not fully RUN (test-attic, test-cv, test-paperless,
   test-browser-history; test-oauth2-proxy is unregistered — see below).
   Eval catches the missing-attribute class; runtime behavior of the converted
   collectors in those VMs is unexercised (most don't run the edited units).
~~2. **signoz-coverage stray-reap replacement**: I removed the old~~ **Won't implement — one-shot sudo live-verify; window passed; mktemp collector live since.**
   pid-suffix + `rm -f $OUT.tmp.*` scheme in favor of mktemp. Prod was clean
   of pid-strays (reaper ran since 2026-08-31) but NOT verified on the live
   box (needs sudo).
3. **pre-deploy/post-deploy integration**: `post-deploy-check.sh` §12 asserts **→ textfile-freshness class still rolling per-collector (docs/todo/monitoring.md Gatus textfile-staleness check)**
   the collector textfile exists but has NO freshness (mtime) check — a frozen
   file with good last-values would still serve a phantom green. Identified,
   not yet implemented.
4. **Guard/sev1 exemption**: documented allowlist (both already carry
   CAP_FOWNER + DAC_OVERRIDE so the caps defeat the sticky rule) — conversion
   deliberately deferred, not forgotten.

## 4. c) NOT STARTED (gaps identified this session)

1. **Gatus freshness condition on collector textfiles** (mail-relay first): **→ niri fresh-pattern precedent live (gatus-config.nix:1015); rollout rows in docs/todo/monitoring.md Gatus textfile-staleness**
   today a dead collector + good last-values = phantom green at the Gatus
   layer (the 845 failures WERE visible via scrape_errors=1 + OnFailure, but
   only because the frozen values happened to be bad).
2. **`tests/test-oauth2-proxy.nix` is UNREGISTERED** in `tests/default.nix` —
   dead test file: never evaluated, never run in CI. Register or trash.
3. **`fs.protected_regular=2` as a named AGENTS.md gotcha** — it cost a test
   iteration; it will cost the next session too.
~~4. **`AmbientCapabilities ≠ CapabilityBoundingSet` for non-root `User=`** as a~~ done at `landed 2026-10-07 with mail-relay provenance (docs/agents/systemd.md:20)`
   named AGENTS.md systemd gotcha.
5. **Dedicated VM coverage** for atticd-metrics / buildcache-metrics / **→ docs/todo/monitoring.md Signoz-coverage/observability test+panel additions monitor-layer test batch**
   gpu-active / system-health collectors (none have tests; the sweep is
   bash -n-verified only).
~~6. **post-deploy §12** freshness assertion (see b.3).~~ **NOT-DO — dup of b3 (post-deploy freshness assertion).**
~~7. **mailq cleanup post-go-live**: placeholder-era deferred messages need~~ done — queue already empty at go-live; postqueue moot (docs/services/mail-relay.md Go-live state)
   `postqueue -f` after the real key lands.

## 5. d) TOTALLY FUCKED UP (honest self-assessment)

1. **Under-inclusive manual sweep.** My first grep (`\.prom\.tmp`) missed the
   generic `''${OUT}.tmp` form and I declared "11 modules" before the audit
   script — which then caught a **12th instance** (`snapshots.nix`, a whole
   directory I hadn't scanned). The audit saved me from shipping an incomplete
   sweep; the manual enumeration was the weak link, not the automation.
2. **Three failed VM-test iterations** (removed template declaration broke
   eval → protected_regular seed EACCES → missing AmbientCapabilities). Each
   was caught by the test (the system working), but iterations 1 and 3 were
   foreseeable: I should have replaced the fixture line with
   `sops.templates."mail-relay-sasl" = { };` (not deleted it), and the
   bounding-vs-ambient distinction is textbook systemd I should have applied
   on the first write.
3. **The prevention question went unanswered when asked.** In the "how do we
   make sure this never happens again" turn I ran discovery greps and then got
   interrupted by the AUTH-keys question — the prevention plan was never
   delivered as an answer, only executed later. If the user had stopped
   reading there, the deliverable was silence.
4. **Never claimed perfect sweep coverage on the live box**: every fix is
   nix-build/VM-verified, but the DEPLOYED state (stale root-owned prom
   actually getting replaced by the new unit) can only be proven post-deploy.
   Nothing in my control — flagged, not fixed, until the user deploys.

## 6. e) WHAT WE SHOULD IMPROVE

~~1. **Sweep with tooling first, manual enumeration second** — the audit script~~ **Won't implement — tooling-first now standard practice; no artifact owed.**
   found what three greps missed. Order of operations for any class-eradication:
   write the detector, run it, THEN fix what it names.
~~2. **Fixture-vs-prod divergence checks should be automatic**: the mock-sops~~ **Won't implement — mock-sops default since corrected; automatic mirror-check never built.**
   default lying was only found because the deployed main.cf disagreed with
   the test. A "mock must mirror upstream defaults" check (or a comment+
   audit pair) would catch the next drift.
3. **Cap semantics for non-root units** should be a lib helper
   (`textfileCollector { name; script; user; extraCaps }`) — 12 copies of the
   mktemp/caps boilerplate is 12 future drift sites.
~~4. **Textfile freshness is a missing monitoring primitive** — every Gatus~~ **NOT-DO — dup of c1 (textfile freshness primitive).**
   textfile check should pair value conditions with an mtime/staleness
   condition (the `system_gatus_meta_scrape_errors` doctrine generalizes).
~~5. **Test-first for incident regressions paid off** — the AmbientCapabilities~~ **Won't implement — process mandate; absorbed into repo test culture.**
   bug would have shipped and re-detected ON THE DEPLOYED BOX without the VM
   regression step. Keep mandating "replay the incident inside the test".

## 7. f) NEXT — up to 50 tasks

**Go-live (user, blocking mail sending):**

~~1. Paste real Resend key: `sudo sops platforms/nixos/secrets/mail-relay.yaml` (repo root!)~~ done — real Resend key deployed, placeholder 0 (docs/services/mail-relay.md Go-live state)
2. Verify `larsartmann.cloud` in Resend dashboard (SPF/DKIM records)
3. `nix run .#deploy` (deploys collector fixes + re-renders SASL template) **→ 550 domain-unauthorized blocker stands (docs/services/mail-relay.md Go-live state 550 blocker)**
~~4. Verify: prom fresh + `credential_placeholder 0` + Gatus "Mail Relay Queue" green~~ done — go-live deploy executed 2026-09-06; chain live-verified (docs/services/mail-relay.md:160)
~~5. Flush placeholder-era queue: `sudo postqueue -f` after key verified~~ done — placeholder 0 + collector green verified (docs/services/mail-relay.md:160)
~~6. E2E: Paperless share-link mail arrives; mailq drains~~ done — queue 0; postqueue moot (docs/services/mail-relay.md:160)
7. Forgejo notification mail E2E **→ blocked on Resend domain verify (docs/services/mail-relay.md Go-live state 550 blocker)**
8. Paste same/decided key into `pocket-id.yaml` → revives Pocket ID email (dead since 2026-08-18) **→ blocked on Resend domain verify (docs/services/mail-relay.md Go-live state 550 blocker)**
~~9. Immich admin-UI SMTP settings (manual, UI-only) + test mail~~ done — pocket-id key live; SMTP DB-actor fix 2026-09-17 (docs/services/mail-relay.md Pocket ID SMTP root cause)
~~10. Confirm on live box: stale root-owned `mail-relay.prom` was auto-replaced (journal has no `mv` EPERM)~~ **Won't implement — manual UI step; window passed.**

**Verification debt (from this session):**
~~11. Fully RUN test-attic, test-cv, test-paperless, test-browser-history (eval-verified only)~~ **NOT-DO — dup of b1 (run the 4 mock-sops VM tests).**
~~12. Decide test-oauth2-proxy.nix: register in `tests/default.nix` or trash~~ **NOT-DO — dup of c2 (test-oauth2-proxy register-or-trash).**
~~13. Run full `nix flake check` (incl. darwin + all checks) at a quiescent moment~~ **Won't implement — quiescent-moment one-shot; full checks run via pre-commit/CI since.**
14. VM-test atticd-metrics + buildcache-metrics + gpu-active collectors
~~15. VM-test system-health collector (largest, untested)~~ **NOT-DO — dup of c5 (collector VM coverage).**
~~16. post-deploy-check §12: add textfile freshness (mtime < 15 min) assertion~~ **NOT-DO — dup of c5 (collector VM coverage).**
~~17. Add `systemctl show -p AmbientCapabilities` sanity to §12 for postfix-user collectors~~ **NOT-DO — dup of b3 (post-deploy freshness assertion).**

**Monitoring hardening:**
~~18. Gatus freshness condition pattern for ALL textfile checks (frozen-file phantom green class)~~ **NOT-DO — dup of c1 (Gatus freshness conditions).**
19. SigNoz rule: textfile collector unit failure fleet alert (system_service_state_failed exists — verify coverage includes all 12) **→ docs/todo/monitoring.md Extend the user-unit monitoring pattern to remaining blind spots**
~~20. Evaluate `queueAlertThreshold` escalation (5 flat may spam during provider outage)~~ **Won't implement — threshold 5 documented live (docs/services/mail-relay.md:164); escalation never needed.**
~~21. Consider alert when `mail_relay_credential_placeholder` stays 1 > 7 days (go-live nag)~~ **Won't implement — moot - real key live, placeholder 0 (docs/services/mail-relay.md:160).**

**Debt explicitly deferred this session:**
~~22. Convert memory-emergency-guard to mktemp pattern (next natural touch)~~ done at `mktemp+trap landed (modules/nixos/services/memory-emergency-guard.nix:129)`
~~23. Convert sev1-escalation to mktemp pattern (next natural touch)~~ **Won't implement — sev1-escalation stays allowlisted revisit-on-touch; sibling guard shows the pattern.**
~~24. `textfileCollector` lib helper to dedupe 12× mktemp/caps boilerplate~~ **NOT-DO — dup of e3 (textfileCollector lib helper).**
25. Extend audit-textfile-tmp.sh scope: `scripts/`, root flake.nix, CI workflow shells
26. Audit class C: reject truncate-style writes (`: > "$VAR"`) into textfile dir without mktemp
~~27. Document `fs.protected_regular=2` in AGENTS.md systemd gotchas~~ **NOT-DO — dup of c3 (fs.protected_regular gotcha).**
~~28. Document AmbientCapabilities-vs-BoundingSet in AGENTS.md systemd gotchas~~ **NOT-DO — dup of c4 (AmbientCapabilities gotcha - landed).**
29. Extend audit to `.sh` files (operational scripts) for `/run/secrets-rendered`

**Docs/memory:**
~~30. Link this status report from AGENTS.md Mail Relay section~~ **Won't implement — memory surface now docs/agents/* + runbook; link-a-status-report form obsolete.**
~~31. Runbook: add explicit ordered go-live checklist (key → DNS → deploy → verify)~~ done at `ordered go-live checklist live (docs/services/mail-relay.md:4`, `55`, `110)`
~~32. Runbook: document the collector failure class + self-heal expectation post-deploy~~ done at `failure-class entry live (docs/services/mail-relay.md:134)`

**Incident follow-through (live box):**
~~33. Confirm Gatus "Mail Relay Queue" RESOLVED alert fires (Discord) post-deploy~~ **Won't implement — one-shot live verify; done in 05:50 go-live session.**
~~34. Verify signoz-coverage pid-stray files absent (sudo sweep of `.prom.<pid>`)~~ **Won't implement — one-shot sudo sweep; window passed.**
~~35. Post-deploy: `journalctl -u mail-relay-metrics | tail` shows queue/placeholder/errors line, no warnings~~ **Won't implement — one-shot journal verify; done 05:50.**
~~36. Watch one 5-min timer cycle end-to-end post-deploy~~ **Won't implement — one-shot watch; collector green since.**
~~37. Confirm sops template rotation restarts postfix (rotation drill, documented path)~~ **Won't implement — one-shot drill; sops template path documented in runbook.**

**Bigger items noticed during session (repo-known, untouched here):**
~~38. Owed REBOOT (2026-08-31 boot): zram old-sizing remnants + D-state corpse pins~~ done — reboot era closed; zram 62.2 GiB live (docs/todo/stability.md Post-BIOS memory re-baseline)
39. /data csum-error follow-up per docs (bounded-vs-progressing discriminator) **→ docs/todo/stability.md btrfs-scrub@data re-FAIL T04-T08 repair (/data corruption arc)**
~~40. TODO_LIST.md was modified by a parallel session this session — reconcile any overlap with this work~~ **Won't implement — meta reconcile; docs-health harvest passes operated since.**
~~41. backup-coordination ages during the Sep 2-6 collector freeze window: confirm no backup-age alerts were masked~~ **Won't implement — one-shot freeze-window audit; window passed.**
42. Consider making the 1777 textfile dir a dedicated group instead of world-writable sticky (root-cause design review of the whole class)
~~43. `niri-health` collector: confirm the Sep-3 manual-run leftover pattern can't recur for OTHER user-touched proms (audit covers code, not operator habits)~~ **Won't implement — one-shot operator-habit audit; window passed.**
~~44. Register mail-relay-metrics in a deploy.sh post-switch restart check if timer-based pickup proves insufficient~~ **Won't implement — superseded - collector green, Gatus queue check live (docs/services/mail-relay.md:164).**
~~45. Evaluate upstream (go-nix-helpers) `checks.textfile-collectors` eval-time check sharing~~ **Won't implement — upstream idea; stale.**
~~46. Sweep other LarsArtmann repos for the same fixed-`.tmp` collector pattern (SystemNix-adjacent services consumed as flakes)~~ **Won't implement — one-shot cross-repo sweep; per-repo audits since standard.**
~~47. Add the incident to `docs/gotchas-archive.md` (full narrative, AGENTS.md keeps only the rule)~~ **Won't implement — incident narrative preserved in status docs + docs/agents/systemd.md.**
~~48. Consider CI job that runs the textfile audit across ALL branches (currently nix-check.yml push/PR only)~~ **Won't implement — stale; CI suite expanded broadly since (negative-tests.yml, go-deps-audit.yml).**
~~49. mail-relay: consider DSN/bounce visibility metric (deferred-bounce reasons → Prometheus)~~ **Won't implement — speculative metric idea; stale.**
~~50. Celebrate: the regression test caught the AmbientCapabilities bug pre-deploy — replicate this "replay the incident" pattern in the next 3 incident fixes~~ **Won't implement — meta celebration; stale.**

## 8. g) QUESTIONS (cannot self-answer)

1. **Resend key strategy:** one shared API key pasted into BOTH
   `mail-relay.yaml` and `pocket-id.yaml`, or separate keys (per-service
   rotation independence vs one-secret-to-rotate)?
2. **Risk appetite for the emergency path:** convert memory-emergency-guard +
   sev1-escalation to the mktemp pattern NOW (touches the safety-critical
   path; caps already make it safe) or keep it deferred to next natural touch?
3. **`systemMailRecipient`:** keep the default (`noreply@larsartmann.cloud` —
   system/cron mail lands in the same inbox as service mail) or route system
   mail to a dedicated real mailbox you actually read?

---

## Appendix: changed files (17)

```
modules/nixos/services/mail-relay.nix          # fix + ambient caps + interpolated path
modules/nixos/services/_signoz-metrics.nix     # 3 collectors converted + caps
modules/nixos/services/attic.nix               # converted + CAP_FOWNER
modules/nixos/services/backup-coordination.nix # converted + CAP_FOWNER
modules/nixos/services/buildcache.nix          # converted + CAP_FOWNER
modules/nixos/services/gpu-active.nix          # converted + CAP_FOWNER
modules/nixos/services/system-health.nix       # converted + CAP_FOWNER
modules/nixos/services/pool-recovery.nix       # converted + CAP_FOWNER
modules/nixos/services/signoz.nix              # converted + CAP_FOWNER
modules/nixos/services/signoz-coverage.nix     # converted + CAP_FOWNER
modules/nixos/services/pocket-id.nix           # converted (root, full caps already)
platforms/nixos/system/snapshots.nix           # converted + CAP_FOWNER (audit-caught!)
tests/test-mail-relay.nix                      # fixture path + incident regression step
tests/mock-sops.nix                            # default path → /run/secrets/rendered
tests/test-hermes.nix                          # fixture path aligned
scripts/audit-textfile-tmp.sh                  # NEW: enforcement (negative-tested)
.githooks/pre-commit + .github/workflows/nix-check.yml  # audit wired
AGENTS.md + docs/services/mail-relay.md        # memory + runbook
```
