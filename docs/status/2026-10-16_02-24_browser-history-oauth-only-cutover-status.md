# Status Report — browser-history Passkey-Disable Cutover (SystemNix side)

**Date**: 2026-10-16 02:24 CEST
**Session scope**: "Disable passkey auth for ~/projects/browser-history, I only want OAuth" — the SystemNix deployment half: lock bump, `webauthn.enable = false` wiring, eval verification, deploy join, live smoke, docs close-outs.
**Honesty mode**: brutal self-review folded in (§d/§e). No research beyond this session's observations.

**Concurrency context (attribution, per shared-tree discipline)**: a SIBLING session (crush session `be63c500`, cwd SystemNix) authored the upstream feature in `~/projects/browser-history` (`PASSKEYS_DISABLED` config, typed-nil WebAuthn guard, OAuth-required boot gates, NixOS module option, tests — its report: browser-history repo `docs/status/2026-10-16_01-31_passkeys-oauth-only-config-status.md`, ends "WAIT FOR INSTRUCTIONS"). This session did ZERO upstream edits; all upstream evidence here is verification-only. Five crush sessions were live during this window (3× SystemNix cwd, hardware-identity, erraudit); the auto-commit daemon swept mid-session twice.

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| Upstream tip verification before pinning: build + passkey/config test suites green at the pushed tip | `go build ./api/... ./cmd/browser-history-server/...` OK; `go test ./api/ -run 'TestPasskeysDisabled\|TestConfig_Validate'` ok (run at `87c6d4a`) |
| Push poll (the hard gate): origin/master was 5917bad (feature absent) for the first ~30 min; poll caught the push to `87c6d4a` | background poll loop, "PUSHED" at ~01:44 |
| Lock bump `5917bad` → `87c6d4a` (`nix flake lock --update-input browser-history`) | flake.lock diff; HEAD's flake.lock contains `87c6d4a` (verified via `git show HEAD:flake.lock`) |
| SystemNix wiring: `webauthn.enable = false` + `oauth2.pocketId.clientId = lib.mkDefault "browser-history"` in `modules/nixos/services/browser-history.nix`, gated on `pocketIdEnabled` (see §d.1 for why the gate exists) | committed at HEAD (verified `git show HEAD:modules/...` grep count 2) |
| Eval verification of the REAL host config: rendered unit env shows `PASSKEYS_DISABLED="true"`, `OAUTH2_POCKET_ID_CLIENT_ID="browser-history"`, `OAUTH2_REDIRECT_BASE`, `REQUIRE_AUTH="true"`, AI suite intact (`LLM_*`, `CHAT_DB_PATH` via unit Environment) | `nix eval .#nixosConfigurations.evo-x2.config.systemd.services.browser-history.environment` |
| Full-flake eval green AFTER the §d.1 fix | `nix flake check --no-build` → "all checks passed" (aarch64-darwin omission = expected warning) |
| Deploy: joined the in-flight 01:45:11 deploy (my own `nix run .#deploy` attempt was correctly refused by the deploy lock; holder verified via /proc as a 4-minute-old deploy building THIS working tree — i.e. my changes) | deploy log `/var/log/systemnix-deploys/2026-10-16_01-45-15.log` line 204 "✅ Pre-deploy checks passed" (includes the §11 real-FOD vendorHash preview) |
| Anchor discipline: `/run/current-system` == `system-904-link` post-switch | readlink equality check, "ANCHORED OK" |
| Unit truth: `/etc/systemd/system/browser-history.service` → `PASSKEYS_DISABLED=true` + `ExecStart=…browser-history-server-87c6d4a/bin/browser-history-server` | direct unit-file grep (same live-unit evidence pattern as prior lock-notes) |
| Live smoke, user-visible surface: `/login` renders the Pocket ID button ONLY — zero "passkey" strings | raw HTTPS probe via LAN IP (Caddy binds 443 on 192.168.1.150/.200 only — loopback probes return empty, gotcha noted) |
| Live smoke, ceremony layer: CSRF dance (HEAD /health token+cookie) then valid-body `POST /auth/webauthn/login/begin` → **401 `{"error":"[rejection:usermgmt.webauthn_not_configured]"}`** | probe transcript in session; note the UNDANCED POST answers 403 csrf_invalid (wall, not verdict) and an empty body answers 400 validation — the 401 needs the full dance |
| `/health` → 200 post-restart | probe |
| Docs close-outs, both surfaces (no drift): TODO_LIST lock-bump row closed with full evidence + NEW `[blocked:user]` AI/chat first-use row; `docs/todo/services.md` twin row closed + same new row | TODO_LIST.md ~:455, docs/todo/services.md ~:365 |
| Runbook truth-sync: new `Lock-note 2026-10-16` prepended in `docs/services/browser-history.md` (lock `87c6d4a`, OAuth-only posture, the fail-closed semantic change, the eval-gate rationale, pointer to the sibling's report) | runbook line ~11 |
| CHANGELOG entry under [Unreleased] → Changed (deployed + live-proven, upstream + SystemNix halves credited separately) | CHANGELOG.md |
| Concurrent-session discipline: sibling attribution via crush.db + /proc cwd; zero co-edits of their in-flight files; mid-edit daemon races handled by re-read (TODO_LIST mod-time race caught and retried) | session log |

## b) PARTIALLY DONE

1. **The deploy process was STILL RUNNING at report time** (01:45 deploy, ~40 min in): switch, provisioners, and `browser-history.service` restart all complete, but the process sits in its reclaim tail (`buildcache-gc`, `pool-smart-metrics`, `browser-history-agent-metrics`) and **its own post-deploy-check battery verdict is UNREAD** (§17 memory sweep, §19 backup freshness, auth vHost 500/502 leg, SigNoz impersonation). Every claim above is from MY direct probes, which are stronger per-claim — but the canonical battery output belongs to the deploy log and nobody has read its verdict. → harvested as [ready] row.
2. **VM test: eval-only, never executed.** `nix flake check --no-build` evaluates `tests/test-browser-history.nix` but does not boot it. The lock bump changed the tested binary AND my module change altered the contract the test consumes (it exercises the passkeys-on default shape without Pocket ID — my gate keeps it green at eval, but the VM has not actually run at `87c6d4a`). Risk genuinely low (test's shape unchanged), but "all checks passed" was EVAL evidence and I must not let it masquerade as test evidence. → harvested as [ready] row.
3. **Verification depth of the user surface**: `/login` probed live; `/register` (register-first surface) NOT probed; `/credentials` needs a session (cannot hold one); gatus checks (user-count `browser_history_users 9` baseline, Browser History check) not spot-checked post-deploy. → harvested.
4. **Test provenance wrinkle**: my first "tip green" test run (b22cf2c) executed against a WORKING TREE carrying the sibling's uncommitted island-fix, and the 87c6d4a re-run happened while the daemon was mid-sweep. The DEPLOYED binary builds from the clean locked GitHub rev, so prod is unaffected — but the evidence label "tip green" was stronger than its provenance in at least one run.
5. **Docs close-outs (CHANGELOG, TODO_LIST, runbook) were uncommitted at report time** (daemon sweep pending); the Nix changes (lock + module) were already swept and verified committed.

## c) NOT STARTED

- Full VM test execution at lock `87c6d4a` (queued, [ready]).
- Deploy battery verdict read (queued, [ready]).
- `/register` live probe + legacy WebAuthn credential census via the world-readable pool backup (`/mnt/pool/backups/browser-history`, sqlite — agent-readable without sudo) (queued).
- Everything in the sibling's report §c/§f (their thread, ends "WAIT FOR INSTRUCTIONS"): e2e OAuth-only journey test, env-parsing test for `PASSKEYS_DISABLED`, README/FEATURES upstream docs, their report's docs-health harvest (50 §f items), go-aichat re-pin (blocked on upstream release intent).
- A deploy run end-to-end as MY OWN action (I joined the in-flight one — outcome equivalent, process credit shared with whoever fired 01:45).
- Whether ANY legacy WebAuthn credentials exist in the prod DB (inert under OAuth-only; census not taken).

## d) TOTALLY FUCKED UP

1. **I broke the shared-tree eval for one full edit cycle — and I had PREDICTED the exact failure mode minutes earlier, in writing, and dismissed it as "a hypothetical future host".** The first edit added `webauthn.enable = false` + `oauth2.pocketId.clientId` UNCONDITIONALLY; `tests/test-browser-history.nix` (enable=true, deliberately NO Pocket ID) then failed the upstream redirectBase assertion in `nix flake check`. In a five-session tree, any sibling's eval in that window ate a false red that was MINE. The preventing grep (`grep -rn "browser-history" tests/`) is the same one I ran after the failure — I ran it too late. In a repo whose #1 concurrency rule is "verify evals of shared surfaces only at quiescent moments", editing without enumerating consumers first is the sin, and I knew the rule.
2. **"All checks passed" was an eval-only claim wearing a test-passed costume.** For a change that modified the module contract a VM test consumes, `--no-build` is necessary-but-insufficient; the honest statement at the time was "all checks EVALUATE green; the VM test has not executed at the new lock". I said the first thing, implied the second.
3. **Evidence provenance slop on the upstream "tip green" runs** (§b.4): at least one test run labeled as tip verification actually executed against a dirty working tree mid-daemon-sweep. No prod impact (the binary builds from the clean locked rev), but a verification label must name its surface, and mine didn't.
4. **False-alarm forensics on the deploy lock**: I read a ps column wrong, narrated "holder alive since 09:28 = hung 16-hour deploy", and only got the truth (started 01:45, 4 minutes prior) from /proc on the next command. Corrected BEFORE any destructive action, so the damage was one wrong sentence — but the first forensic command should have been the /proc one, not ps-eyeballing.

## e) WHAT WE SHOULD IMPROVE

- **Consumer enumeration BEFORE first edit on any shared module.** Option-adds to a module imported by hosts AND tests must start with `grep -rn "<module>" tests/ flake/` — one command, prevents the entire §d.1 class. I derived the fix (gate on `pocketIdEnabled`, mirroring the upstream assertion's own logic) quickly, but only after going red in a shared tree.
- **Label evidence with its exact surface**: pinned rev vs working tree; eval vs executed test; my probe vs the deploy battery's leg; live vs fixture. The repo keeps getting burned by label/substrate drift (2026-09-18 gate class, 2026-09-29 count class) — this session produced two fresh instances (§d.2, §d.3) despite knowing both precedents.
- **Riding an in-flight deploy needs a defined tail protocol**: verify holder → let it finish → read ITS battery → then independent probes. I inverted the last two (probed first, battery unread). The probes were sufficient for the auth question but the battery covers legs I never will (§17/§19).
- **The deploy-join pattern worked and is undocumented**: lock refused → /proc forensics on holder → confirm it builds MY tree → stand down and verify outcome instead of queue-jumping. Worth 5 lines in CONTRIBUTING.md's deploy section as the sanctioned behavior (vs. waiting or killing).
- **`s_client` probe target gotcha**: Caddy binds 443 on LAN IPs only — loopback HTTPS probes silently return empty. Cost one wasted probe round; belongs in the AGENTS.md verified-probe list (queued).

## f) NEXT (harvest-state noted; * = harvested into TODO_LIST + docs/todo/services.md with this report)

1. * **Read the 01:45 deploy log's post-deploy battery verdict** once the process exits (§17/§19/auth-vhost/SigNoz legs) — closes §b.1.
2. * **Run the browser-history VM test at lock `87c6d4a`** (full build + boot, not eval) — closes §b.2.
3. * **Live-probe `/register`** renders OAuth-only (register-first surface). Fold into the same probe pass as 1.
4. * **Census legacy WebAuthn credentials** via the pool-backup sqlite (webauthn credential tables; count only) — decides whether an inert-credential cleanup row is ever needed.
5. **Resolve the policy-scope question (§g.1)** → possibly generalize the disable gate past `pocketIdEnabled` (e.g. any-provider) or document Pocket-ID-only intent in the option comment.
6. **Sibling thread dispatch** (§g.2): their report's 50 §f items — e2e OAuth journey test, env-parsing test, upstream README/FEATURES OAuth-only docs, their own report harvest — are unowned.
7. Pin the LIVE 401 `webauthn_not_configured` finding into upstream repo tests (their §f.2 — my probe is the evidence; the repo test is the regression net).
8. go-aichat re-pin after upstream tags the family-preserving change (their §f.3, blocked on release intent).
9. Codify the deploy-join protocol in CONTRIBUTING.md (§e).
10. Add the Caddy LAN-IP-only HTTPS probe gotcha to AGENTS.md's verified-probe list (§e).
11. Spot-check gatus post-deploy: user-count baseline 9 unchanged, Browser History check green.
12. Tonight's 02:15 backup watch row (pre-existing): first hot-mount backup run + no `-journal` remnant — my deploy restarted the unit ~20 min before the window; verify the dump landed clean.
13. SigNoz: confirm the `browser-history` scrape job + render-p99 rule + dashboard survived the switch (part of the unread battery).
14. Sibling §f.5/§g.3: relax `WEBAUTHN_RPID`/`WEBAUTHN_ORIGINS` validation when disabled (raw-env wart; harmless in Nix).
15. Sibling §g.2 product decision: gate/disable `POST /auth/register` under OAuth-only (dormant email-registered accounts) — interacts with `MAX_USERS=1`.
16. Upstream FEATURES.md/README OAuth-only section (their §f.16/17).
17. Consider `loginpage.AutoRedirect` now that exactly ONE provider exists and passkeys are off (their §f.15 — UX change, owner call).
18. `/credentials` page copy when disabled — static subtitle still says "WebAuthn credentials registered to your account" (their §f.12).
19. Env-parsing test: `PASSKEYS_DISABLED=true` → field true via `LoadConfig()` (their §f.6).
20. Property/table test: disable-guard invariant across google/github/pocketId × present/absent (their §f.37/38 — table covers github only).
21. Upstream `docs/api-endpoints.md`: no route changes this feature (their §f.47 verified) — nothing to do; recorded here so nobody re-checks.
22. chat/AI nav gating render assertion under OAuth-only (their §f.48 — free rider on the e2e in 6).
23. Rate-limit bucket semantics: `authRateLimitMiddleware` comment references WebAuthn ceremonies; decide whether OAuth-only changes anything (their §f.49).
24. `docs/agents/` AGENTS.md: the SystemNix browser-history module comment + module header example now document `webauthn.enable = false` — mirror check next docs sweep (module header already shows it; README still missing, see 16).
25. My uncommitted docs close-outs (CHANGELOG/TODO_LIST/runbook) — commit (pathspec) or let the daemon sweep; verify content integrity either way.

(Items 6–23 are the sibling session's thread per its "WAIT FOR INSTRUCTIONS" ending — dispatched here only as inventory, not claimed.)

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Policy scope**: OAuth-only is currently gated on POCKET ID presence (`pocketIdEnabled`) — a future host running browser-history with Google/GitHub OAuth (no Pocket ID) would silently keep PASSKEYS ENABLED. Is OAuth-only a Pocket-ID-of-this-host fact, or a fleet-wide policy that should engage on ANY configured provider (small module change: gate on `hasAnyOAuth2Provider` semantics / unconditional + provider assertion)? I implemented the Pocket-ID-gated version because the VM test constraints forced a choice; the owner intent decides whether that choice is final.
2. **The sibling session's thread**: its report ends "WAIT FOR INSTRUCTIONS" with 50 §f items and 3 open product questions (§g there: go-aichat re-pin timing, register-endpoint gating under OAuth-only, WebAuthn-config-required-when-disabled wart). Do you want THIS session (or a fresh dispatch) to pick up that thread, or is it parked?
3. **AI/chat first-use smoke**: the deploy carries the full AI wiring (eval-verified env) but first real use needs an authenticated browser session. Do you want to do it now (any login → one summary + one chat turn through fastflowlm), or should the new `[blocked:user]` row ride until a natural window?

---

**Queue harvest at authoring time (doctrine compliance)**: items f.1–f.4 land as [ready] rows in TODO_LIST.md + docs/todo/services.md with this report; f.5–f.6 stay in-report pending §g answers (blocked on owner input, not harvestable); the rest are sibling-thread inventory or micro-items without their own ask.

_Point-in-time snapshot. WAIT FOR INSTRUCTIONS._
