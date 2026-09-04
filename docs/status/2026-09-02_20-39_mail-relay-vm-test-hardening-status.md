# Status — Mail Relay: VM Test Hardening, Domain Wiring, Self-Review

**Date:** 2026-09-02 20:39 CEST
**Scope:** this session only — the mail-relay continuation session (resumed from the 17:34 self-review report, Q1 answered: sending domain `larsartmann.cloud`).
**Format note:** user explicitly requested `.md`; the status-report skill's HTML default is overridden for this report.

---

## a) FULLY DONE (evidence-backed)

1. **Attic red resolved as transient** — `checks.x86_64-linux.attic` builds green (`nix build .#checks.x86_64-linux.attic` → store path, no reproduction of the 17:21 failure). The fa4309ce CV re-lock did NOT break it. Repo unblocked. Honest caveat: root cause of the original red is UNPROVEN (see d4).
2. **Sending domain wired** — `services.mail-relay.fromAddress` default `onboarding@resend.dev` → `noreply@larsartmann.cloud`; description documents the Resend domain-verification gate. Eval-verified: relay option AND `services.paperless.settings.PAPERLESS_EMAIL_FROM` both resolve to the new address (one source of truth). Committed (rode daemon commit 861c3385).
3. **"Mail Relay Queue" Gatus check re-applied** (the silently-failed edit from the previous session) — anchored value-0 conditions on `mail_relay_scrape_errors 0` + `mail_relay_queue_over_threshold 0`, presence conditions for both remaining gauges, placeholder-aware Discord alert. Present in `nix eval` of gatus endpoints. `nix flake check` pattern-lint passes.
4. **NEW: `tests/test-mail-relay.nix` VM test, GREEN** (registered in `tests/default.nix`, final state committed at 449e3d3a). Five verified phases: (1) loopback-only `:25` listener (no 0.0.0.0/[::]) + real 220 banner; (2) null-client postconf contract (empty mydestination, forced-TLS relayhost, SASL map, generic + canonical maps); (3) queue-phase recipient rewrite E2E (`postqueue -j` JSON); (4) collector fail-closed with EXACT-LINE metric asserts; (5) delivery-time E2E against an in-VM fake STARTTLS upstream — STARTTLS handshake, SASL AUTH from the rendered map, envelope-sender AND recipient rewrite, `status=sent`. Deterministically offline (`relayHost=127.0.0.2:1` refuses → defer, no internet dependency).
5. **TWO shipped bugs found by the test and fixed:**
   - `mail-relay-metrics` collector was broken AS COMMITTED: under `harden{}`'s empty `CapabilityBoundingSet`, root has NO DAC bypass → could not read the postfix-owned 0400 SASL map (`-r` failed) nor connect to the showq socket (`Permission denied`). Fix: unit runs as `User = config.services.postfix.user`. VM-proven: collector now logs `queue=1 over=0 placeholder=1 errors=0`.
   - System-mail recipient rewriting NEVER worked as designed: `aliases(5)` applies only in local(8) delivery and a null client never runs local(8) — the nixpkgs `rootAlias` is decorative here; root@/cron mail would have relayed verbatim and died at the provider. Fix: `recipient_canonical_maps` (texthash store map), applied at cleanup BEFORE queuing. VM-proven: `to=<noreply@larsartmann.cloud>, orig_to=<root@testhost.home.lan>`.
6. **post-deploy-check.sh §12 added** — postfix active, `/dev/tcp` SMTP banner read, placeholder-credential WARN (not FAIL), paperless `paperless.conf` wiring grep (conf file, NOT unit env), collector textfile presence; enable-gated per unit file (the `is-enabled` rc=1 trap avoided). `bash -n` clean, helper names verified.
7. **Docs current** — runbook (`docs/services/mail-relay.md`): go-live rewritten for `larsartmann.cloud` (Resend Domains → SPF/DKIM → verified), consumers table corrected (canonical map, not aliases), monitoring section includes queue check + collector, verification section names the VM test + §12. AGENTS.md Mail Relay section updated (3 bullets incl. the aliases-inert gotcha and the phantom-HELP-in-test lesson). TODO_LIST: go-live row rewritten (domain DECIDED), hardening-finish row marked DONE.
8. **Full gates green** — `nix fmt --no-update-lock-file -- --ci`: 1899 files, 0 changed. `nix flake check --no-build`: all checks passed. Working tree clean at 449e3d3a.

## b) PARTIALLY DONE

1. **Relay go-live** — everything deploy-side is code-complete and VM-verified; what remains is (a) user verifies `larsartmann.cloud` in Resend, (b) user pastes the real API key into sops interactively, (c) `nix run .#deploy` (user-run, needs sudo), (d) live E2E tests. Blocker: user actions + sudo. Effort: S once unblocked. NOTHING from this relay has ever run on the real host — all verification is eval + VM level.
2. **Live post-deploy smoke (§12)** — written and syntax-verified, never EXECUTED (no deploy happened). Unproven against the real host.
3. **232-task plan table delivery** — HTML committed (693a88bd) + raw table at `/tmp/plan-table.md` (232 tasks; tier counts surfaced: T0 18 / T1 27 / T2 41 / T3 69 / T4 33 / T5 53). The chat TABLE VIEW the user demanded earlier was never pasted — awaiting their preference (see questions).
4. **Pocket ID email fix** — same new Resend key fixes it (revoked key still in sops → Pocket ID email BROKEN since 2026-08-18). User step, blocked on key rotation.
5. **Immich SMTP** — admin-UI-only config documented (127.0.0.1:25, no auth); not done (needs live host + UI access).
6. **TODO_LIST HARVEST of this report's section (f)** — not run (user instructed WAIT after the report).

## c) NOT STARTED (planned, zero code this session)

1. **Live deployment + §12 run** — blocked on user deploy.
2. **Real-credential E2E sends** (sendmail / paperless share-link / forgejo notification) — blocked on go-live.
3. **Queue-age monitoring** (oldest deferred message age, not just depth) — idea only.
4. **SigNoz dashboard panel for `mail_relay_*` metrics** — idea only.
5. **Negative-testing the new Gatus check via the mutation method** — the repo doctrine (AGENTS.md: never trust exit 0 alone) was applied to the VM test but NOT to the gatus check or §12.
6. **Approved-plan tiers T0–T5** (232 tasks) — standing instruction: only on explicit user GO.
7. **Pre-existing P0s outside this session's scope** (listed for completeness): /data EIO inode corruption repair (blocks btrbk-data), ClickHouse telemetry backup coverage, CV test `virtualisation.fileSystems` fix.

## d) TOTALLY FUCKED UP

1. **The silent-edit-failure class RECURRED — and I repeated it.** Previous session: the Gatus queue-check edit failed on mtime and was never re-applied (ghost collector). This session: my fake-relay STARTTLS edit reported SUCCESS, then the daemon's mid-flight commit clobbered it back to the old script — I did NOT re-verify content after the conflict notice and only caught it because the next test run failed. Twice now the same lesson: after ANY mtime conflict (or daemon sweep), re-read the file and diff INTENT, not just retry.
2. **Two broken components shipped green (previous session, caught this one).** The collector and the system-mail rewriting were committed as "done" without any boot-level verification; both were dead-on-arrival in different ways. The repo's own doctrine says it: never trust output text alone, assert the artifact. The VM test is the fix — but it should have existed BEFORE the first commit.
3. **17:21 attic red — root cause UNKNOWN.** I "resolved" it by re-running the test (green). No log from the failing run exists, the fa4309ce CV re-lock is exonerated only by "it passes now", and "transient VM flake" is a hypothesis, not a diagnosis. If it recurs in pre-commit, every commit aborts again with no forensics.
4. **fa4309ce flake.lock churn (plain-`nix fmt` re-lock trap, daemon-side)** — the CV input moved db30fa6c→7dee7292 as a formatter side effect. Known trap, documented in AGENTS.md, still happening. Not fixed by anyone this session.
5. **I violated the repo's own negative-testing doctrine for the checks I wrote.** The AGENTS.md lesson (2026-08-27): never trust a check's exit 0 without a mutation test through nix. My new Gatus check and §12 have zero negative tests. The phantom-HELP trap then bit ME inside my own test asserts (substring `in prom` matched the HELP comment line) — the exact class documented for Gatus, reproduced in Python.
6. **10 VM-test iterations where ~3 were avoidable.** I wrote the test before researching: postfix's encrypt-level STARTTLS mandate, pre-greeting pipelining rules, generic-maps delivery-time semantics, tmpfiles `f` content semantics, multi-output `openssl.bin`. Each cost a full build+boot cycle (~3-6 min each).

## e) WHAT WE SHOULD IMPROVE

1. **Read-then-write for service VM tests**: nixpkgs ships `nixosTests.<service>` for almost everything — read the upstream test + module BEFORE writing our own. Concrete fix: add it to the VM-test section of docs/CONTRIBUTING.md.
2. **Post-conflict content verification**: after every mtime rejection or daemon commit sweep, `git diff` the file against intent before continuing (habit, plus consider an edit-tool hook that re-shows the region).
3. **"Done" requires boot-level proof**: the two shipped-broken components both passed eval + fmt + review. Rule of thumb going forward: a service module PR ships WITH its VM test in the same commit, not after.
4. **Exact-line metric asserts everywhere**: `metric 1` substring matching is a landmine in ANY consumer of Prometheus text (Gatus, python, shell). The `splitlines()` pattern should be the documented default for test assertions on textfiles.
5. **Pre-commit flake-check flake tolerance**: the pre-commit `nix flake check` runs VM-test EVALS (cheap) — but CI runs full VM tests; a single flaky VM test reds the tree with no forensics. Consider retry-once + preserved log for VM checks in CI, and keep a `tests/*.log` artifact on failure.
6. **Daemon fmt vs lock**: the auto-commit daemon keeps re-locking moving-ref inputs via plain `nix fmt`. The formatter invocation the daemon uses should get `--no-update-lock-file` (the repo already knows; the daemon doesn't).

## f) TOP 50 NEXT TASKS (ranked: impact → effort; HARVEST fuel for TODO_LIST/ROADMAP)

| #  | Task                                                                                                                         | Impact  | Effort | Category      |
| -- | ---------------------------------------------------------------------------------------------------------------------------- | ------- | ------ | ------------- |
| 1  | Verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM records → Verified)                                                  | Critical | S | Go-live (user) |
| 2  | Rotate Resend API key; paste into `mail-relay.yaml` sops interactively + restart postfix                                       | Critical | S | Go-live (user) |
| 3  | Same new key into Pocket ID sops → unbreak Pocket ID email (broken since 2026-08-18)                                           | Critical | S | Bug (user) |
| 4  | `nix run .#deploy` → relay live on evo-x2 → run `post-deploy-check.sh` §12 live                                                | Critical | S | Go-live |
| 5  | Live E2E: sendmail → mailq drains, journal `status=sent`                                                                       | High | S | Verification |
| 6  | Live E2E: paperless share-link email arrives                                                                                   | High | S | Verification |
| 7  | Live E2E: forgejo notification email arrives                                                                                   | High | S | Verification |
| 8  | Configure Immich SMTP in admin UI (127.0.0.1:25, no auth)                                                                      | Medium | S | Feature |
| 9  | Confirm Gatus queue check flips placeholder→green after go-live; verify live .prom values                                      | High | S | Verification |
| 10 | Decide where system mail (root@/cron) should actually LAND — does a real mailbox exist behind `noreply@larsartmann.cloud`?      | High | S | Decision |
| 11 | Flip TODO_LIST/AGENTS relay status to LIVE after §12 green                                                                     | Medium | S | Documentation |
| 12 | Negative-test the Gatus queue check via the mutation method (repo doctrine)                                                    | High | S | Quality |
| 13 | Negative-test §12 smoke branches (placeholder→WARN, paperless-gate skip)                                                        | Medium | S | Quality |
| 14 | Execute T0 tier of the approved 232-task plan (18 tasks) — needs explicit GO                                                    | High | M | Plan |
| 15 | Execute T1 /data repair tier — needs explicit GO (EIO inode blocks btrbk-data)                                                  | Critical | L | Bug |
| 16 | Investigate the 17:21 attic VM-test red root cause; add retry-once + log preservation for flaky VM checks in CI                  | Medium | M | Quality |
| 17 | Stop the daemon's plain-`nix fmt` from re-locking moving-ref inputs (use `--no-update-lock-file` daemon-side)                    | Medium | S | Cleanup |
| 18 | Commit the 232-task table into the repo as markdown (currently /tmp-only)                                                       | Medium | S | Documentation |
| 19 | Queue-AGE textfile metric (oldest deferred message age, not just depth) + Gatus condition                                       | Medium | M | Feature |
| 20 | SPF alignment + DMARC policy review for `larsartmann.cloud` (envelope-from is aligned; DMARC policy is user DNS)                 | Medium | S | Deliverability |
| 21 | Resend rate-limit headroom check (free tier vs cron burst storms)                                                               | Medium | S | Deliverability |
| 22 | Watch postqueue growth under the placeholder era (is unbounded mailq growth possible before go-live?)                            | Medium | S | Verification |
| 23 | Register postfix in `signoz-coverage.expected` semantics (no OTel — document as upstream gap or exempt)                          | Low | S | Monitoring |
| 24 | SigNoz dashboard panel: `mail_relay_queue_messages` / `_over_threshold` / `_credential_placeholder`                              | Low | M | Monitoring |
| 25 | Runbook drill: simulate provider 4xx/5xx storm → verify queue check fires → resolves                                            | Medium | M | Verification |
| 26 | CHANGELOG entry for the relay module + VM test (verify daemon captured it)                                                      | Low | S | Documentation |
| 27 | FEATURES.md entry for the mail relay                                                                                            | Low | S | Documentation |
| 28 | Rotate remaining leaked keys (Synthetic live-assumed, Context7 `ctx7sk-…`) — PERSISTENT NAG                                      | High | S | Security (user) |
| 29 | History-purge push decision (still HELD by user; rotation-first doctrine)                                                        | Medium | S | Security (user) |
| 30 | `systemMailRecipient`: set explicitly in configuration.nix once #10 decided (implicit default is a footgun)                      | Medium | S | Cleanup |
| 31 | paperless-task-queue celery `/tmp` post-fix verification (tmp-cleaner fix shipped — confirm clean)                               | Medium | S | Verification |
| 32 | immich-machine-learning wgunicorn `/tmp` post-fix verification (same class)                                                      | Low | S | Verification |
| 33 | CV test: convert `/mnt/pool` to `virtualisation.fileSystems` and re-verify cv-backup under a real mount                          | Medium | M | Quality |
| 34 | ClickHouse telemetry backup coverage (btrbk excludes it — `clickhouse-backup` follow-up)                                        | High | L | Bug |
| 35 | Verify browser-history registration gate is LIVE in the deployed binary (tag → flake bump → deploy chain)                        | Medium | M | Verification |
| 36 | Gate `importUsers()` CSV path (registration lock hole #3, upstream cqrs-htmx)                                                    | Medium | M | Bug (upstream) |
| 37 | Hermes post-deploy smoke: Discord gateway-ready journal line                                                                     | Low | S | Quality |
| 38 | Verify Paperless AI actually uses llama-rag embeddings E2E (+ reranker wiring)                                                   | Low | M | Verification |
| 39 | Samsung 970 EVO role assignment execution (design doc exists; user decision pending)                                             | High | L | Feature |
| 40 | Confirm no relay consumer depends on inbound/reply mail (PapDashboard insights are Discord-only; nothing waits on an email reply) | Low | S | Verification |
| 41 | Consider `delay_warning_time` on the relay (postfix DSN spam after N hours deferring) — decide OFF or tuned                      | Low | S | Feature |
| 42 | Confirm forgejo FROM rendering (`Forgejo <noreply@larsartmann.cloud>`) passes Resend's sender validation live                     | Medium | S | Verification |
| 43 | Add mail-relay runbook to Homepage tiles/docs index if service docs are linked anywhere                                           | Low | S | Documentation |
| 44 | Post-go-live: watch first cron-burst for SMTP concurrency limits (Resend connection caps)                                        | Medium | S | Verification |
| 45 | Document the `smtp_generic_maps` delivery-time gotcha (invisible in queue) in AGENTS.md Mail Relay section                       | Low | S | Documentation |
| 46 | Add `tests/test-mail-relay.nix` to CI docs listing (CONTRIBUTING test matrix)                                                    | Low | S | Documentation |
| 47 | Split-brain audit: relay defaults in docs vs module (`fromAddress`, threshold) — single source of truth pass                     | Low | S | Cleanup |
| 48 | Consider relay-local rate limiting or `smtp_destination_concurrency_limit` guardrails for burst safety                            | Low | S | Hardening |
| 49 | Review whether noreply@ should be excluded from auto-replies/loop risk (paperless ↔ inbound mailbox interplay, post-Q)           | Low | S | Hardening |
| 50 | Re-run the full self-review checklist against the NEXT relay touchpoint (docs-health ANNOTATE this report when go-live lands)     | Low | S | Process |

HARVEST routing: #1–13 TODO_LIST (go-live chain), #14–15 gated on GO, #16–27 TODO_LIST P1/P2, #28–29 standing nag, #30–50 mostly ROADMAP/P2.

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **Where must system mail actually land?** `systemMailRecipient` defaults to `noreply@larsartmann.cloud` — is there a REAL mailbox (or catch-all) behind that address at the provider, or should cron/root failures go to a real inbox (which address)? I tried: the runbook, sops files, and DNS are all silent on mailbox topology; only you know where you actually read mail.
2. **Placeholder-era alerting preference:** the queue check is GREEN right now and only fires once ~5 sends have deferred (first user-triggered send after deploy). Do you want it LOUD immediately (assert `mail_relay_credential_placeholder 0` so the check is red until go-live — guaranteed Discord noise), or keep the current silent-until-used behavior?
3. **Was the 232-task plan "delivered" for you?** You earlier demanded a TABLE VIEW in chat; the HTML is committed and the raw table sits in `/tmp/plan-table.md`. Chat-paste 232 rows, commit the markdown table into the repo (#18), or is the HTML enough?

---

*Prepared by Crush (glm-5.3-flash). Point-in-time snapshot — will go stale; annotate via docs-health, never rewrite.*
