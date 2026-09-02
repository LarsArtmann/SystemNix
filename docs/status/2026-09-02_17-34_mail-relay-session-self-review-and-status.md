# Self-Review & Status — Mail Relay / Pareto-Plan Session

**Date:** 2026-09-02 17:34 · **Scope:** this session only (mail relay research→implementation→hardening→user Q&A→232-task pareto plan)
**Honesty rule:** brutal, no lies. Skill: brutal-self-review questions folded into sections d/e.

---

## a) FULLY DONE

| Item | Proof |
|---|---|
| Email inventory across ALL services (grep + module reads + upstream research) | pocket-id (Resend :465, dead key, TLS fail-closed via go-kit), forgejo (no mailer), immich (UI-only, verified zero nixpkgs options), twenty (nothing found), system/cron mail (nowhere); paperless 3.1.0 settings.py ground truth read from the store package (`EMAIL_ENABLED` flips on host≠"localhost", `PAPERLESS_EMAIL_FROM`, USE_TLS/SSL bools, mail task `PAPERLESS_EMAIL_TASK_CRON` */10) |
| `modules/nixos/services/mail-relay.nix` — Postfix null client, COMMITTED | loopback-only `:25` (`ports.mail-relay=25`), `mydestination=""`, relay `[smtp.resend.com]:587`, mandatory TLS, sasl `texthash:` from sops template, generic-map sender rewrite, root/postmaster aliases, `systemMailRecipient` + `queueAlertThreshold` options, ioTier + onFailure, `restartTriggers` config stamp (nixpkgs module has none), `mail-relay-metrics` collector (queue depth / over-threshold / placeholder / scrape_errors, fail-closed, timeout-bounded) |
| sops wiring COMMITTED | `platforms/nixos/secrets/mail-relay.yaml` (placeholder, public-key encrypted, gitleaks-clean) + `mail-relay-sasl` template (postfix:postfix 0400, restartUnits postfix) |
| Consumers COMMITTED | paperless `PAPERLESS_EMAIL_*` relay-gated block; forgejo `[mailer]` plain SMTP relay-gated; configuration.nix enable |
| Monitoring COMMITTED | Gatus "Mail Relay (SMTP)" TCP + "Mail Relay Service" state checks; `postfix` in system-health defaults (index 22 verified) |
| Verification at commit time | targeted evals of postfix main.cf / paperless env / forgejo mailer / sops template / gatus endpoints (JSON) all correct; `nix flake check --no-build` green ×2; formatter clean; pre-commit hook green (837541ce) |
| Docs | `docs/services/mail-relay.md` runbook; AGENTS.md "Mail Relay" section + Paperless bullet; TODO_LIST go-live item + PERSISTENT-NAG cross-ref |
| User Q&A | postfix explainer; why-standard + alternatives table; relation to `reports/open-source-email-monitoring-tools-report.md` + `selfhosted-email-guide.md` (both READ; conclusion: what we built IS the report's hybrid-relay recommendation; Layer-2 gap = optional postfix_exporter fork) |
| Pareto plan (user-ordered) | 232 tasks ≤12min, 6 tiers, sorted impact/effort — `docs/planning/2026-09-02_17_20-mail-relay-completion-full-backlog-pareto-plan.html` (91KB, D2 graph) + `/tmp/plan-table.md`; new TODO row for the relay-finish gap |

## b) PARTIALLY DONE

1. **Relay hardening ("MAKE IT PERFECT")** — collector ✅ committed; the consuming **Gatus "Mail Relay Queue" check is MISSING** (edit failed silently, caught ~1h later, TODO row added); VM test, post-deploy §12, collector docs: not started (planned tasks #3–#6).
2. **Plan artifact commit** — HTML + TODO row generated and staged, but the commit was **ABORTED by a pre-commit `nix flake check` failure in `vm-test-run-attic`** (`/var/lib/atticd/storage` missing in VM; green at 15:19, red by 17:21). NOT my files (mine: markdown + HTML only). Diff 837541ce..4c5c556b shows NO attic.nix/test-attic changes; suspects: `flake.lock` churn inside daemon commit fa4309ce (the `nix fmt` re-lock trap!) or VM timing flake — **root cause UNRESOLVED**.
3. **Pocket ID fix** — fully designed (stays direct :465; one new Resend key fixes both), blocked on user key creation.
4. **Twenty claim** — "no SMTP need" is based on module grep only, NOT upstream-docs-verified. Hedged in the answer, but it is a weaker claim than the rest of the inventory.
5. **Deployed-version check for pocket-id TLS** — research was upstream main; the locked input's version was not diffed. Low risk (the `tls=auto` fail-closed behavior is why we did NOT rewire it), but unverified against the pin.

## c) NOT STARTED (at all)

- `tests/test-mail-relay.nix` (loopback-only bind, 220 banner, submit+defer under placeholder, metrics file asserts)
- post-deploy-check §12 (banner / placeholder WARN / paperless env / queue file)
- AGENTS.md + runbook documentation of the collector/queue check (docs lag = mild split brain)
- Go-live chain (user-gated: Resend key, sops fill, domain verify, fromAddress, E2E, Immich UI, paperless inbound mailbox)
- Everything in plan tiers T1–T5 (by design — plan first, awaiting approval)

## d) TOTALLY FUCKED UP / what I really don't like

1. **The silently-failed Gatus edit** — edit tool returned an mtime-conflict error mid-session; I moved on (postfix Q&A) and did not re-apply. Result: a shipped collector with NO consumer check for ~2h — a textbook ghost system, the exact concurrent-session trap AGENTS.md documents, which I had applied correctly 20 minutes earlier for paperless.nix (re-read + re-apply) and then dropped for gatus. Discipline must be: every edit failure gets an immediate re-read + re-apply + verify, no exceptions.
2. **The plan HTML vanished from disk** (written 17:20, gone by 17:26, cause unknown — concurrent session). Regenerated, but the whole class of "generate artifact in shared tree → commit immediately" was violated by batching it with the TODO edit + a 4-minute pre-commit flake check.
3. **The relay commit path was sloppier than my standard**: 3 eval-fix cycles (relayhost/mynetworks list types, `or` misuse, deadnix unused `ports`) that one careful read of the postfix module option types BEFORE writing would have avoided; the hook caught deadnix at full-flake-check cost.
4. **Runbook defects shipped in v1** (self-caught, but should never have landed): a test command using `mail` (binary absent on this box), and a nonsense `secrets-edit-README` line. Rule reinforced: never write commands from memory — verify the binary exists first.
5. **The repo is RED right now** (attic VM test) and my work rides on it uncommitted — a session should never leave its artifact hostage to an unrelated failure it hasn't diagnosed.

Lies told: none found on re-read. Scope creep: none (collector was phantom-green doctrine, plan was user-ordered). Removed anything useful: no (one dead import).

## e) Improvements (process, for me)

1. Edit-failure protocol: re-read → re-apply → verify, same minute. No exceptions, regardless of interruption.
2. Commit each finished unit immediately via pathspec instead of batching (the daemon races shared trees; 3 daemon commits interleaved with my work this session).
3. Read option TYPES before writing config against unfamiliar nixpkgs modules.
4. Verify every binary/command referenced in docs against the live system (`mail` lesson).
5. After generating any artifact: `ls` it, then commit it, before anything else.
6. Ghost-system check at every "done": every emitter needs its consumer in the same commit (collector/check split happened).
7. Keep the session todo list truthful in real time — the gatus task didn't silently vanish from the list, it silently vanished from the DISK while marked planned; the list can't fix that, verification can.
8. Testing: the relay got eval-level verification only; mechanism claims (loopback-only, texthash readability) need the VM test before calling the module done — same standard as test-cv/test-hermes.

## f) Next tasks (top 50, ordered — full 232 in the plan file)

| # | Task | Owner |
|---|---|---|
| 1 | Diagnose attic VM test failure (`/var/lib/atticd/storage` missing; suspect fa4309ce flake.lock churn or timing) — repo is RED, blocks all commits | A |
| 2 | Re-add Gatus "Mail Relay Queue" check (anchored forms) + eval | A |
| 3 | Investigate/justify flake.lock churn in fa4309ce (plain-nix-fmt re-lock trap) | A |
| 4 | Commit staged plan HTML + TODO row once hook green | A |
| 5 | Write tests/test-mail-relay.nix | A |
| 6 | Run + fix mail-relay VM test | A |
| 7 | post-deploy-check §12 (banner, placeholder WARN, paperless env) | A |
| 8 | Document collector + queue check in AGENTS.md + runbook | A |
| 9 | U: create NEW Resend API key | U |
| 10 | U: `sudo sops` mail-relay.yaml + pocket-id.yaml, restart postfix | U |
| 11 | U: verify sending domain in Resend | U |
| 12 | A: set fromAddress + deploy | A |
| 13 | A: E2E (sendmail, paperless share link, mailq drain, Pocket ID email) | A |
| 14 | U: Immich SMTP in admin UI (127.0.0.1:25) | U |
| 15 | U: Paperless inbound mailbox + Mail rules | U |
| 16 | A: post-go-live TODO/AGENTS status flip | A |
| 17 | A: present /data repair T04-T08 runbook | A |
| 18 | U: /data docker-down window decision | U |
| 19 | A: DuckDB 54G safety copy → pool archive | A |
| 20 | A: read-only `btrfs check --mode=low-risk` in window | A |
| 21 | A/U: /data minimal fix + scrub verify | A/U |
| 22 | A: resume btrbk-data, confirm first full receive | A |
| 23 | A: btrbk-data oom containment (MemoryHigh/OOMScoreAdjust) | A |
| 24 | A: dnsblockd `ManagedOOMPreference=omit` | A |
| 25 | A: deploy pressure gate + IO PSI/disk %util | A |
| 26 | A: IO-PSI emergency guard zone | A |
| 27 | A: boot-generation freshness Gatus check | A |
| 28 | A: journald SystemMaxUse=2G + bounds audit | A |
| 29 | A: SIGPIPE/pipefail collector audit | A |
| 30 | A: Post-DAS convergence final-leg verify | A |
| 31 | U: reboot into kernel 7.2.2 | U |
| 32 | A: amdxdna ABI diff + booted==current verify | A |
| 33 | A: flm v1.0.3 pull + validate + retune (or revert) | A |
| 34 | A: XRT/kernel upstream issue (verify-before-filing) | A |
| 35 | U: off-site backup decision (StorageBox/vault/Photos) | U |
| 36 | A/U: Context7 rotation + MCP config update | A/U |
| 37 | U: Turso decision (DiscordSync offsite) | U |
| 38 | A: boot-catch-up stampede staggering | A |
| 39 | A: CI executes lint derivations | A |
| 40 | A: shellcheck + unit binary-coverage pre-commit | A |
| 41 | A: eval audits (ReadWritePaths⇒RequiresMountsFor, Persistent timers) | A |
| 42 | A: backup_ever_succeeded + catchup report | A |
| 43 | A: dnsblockd upstream OTLP push+tag+relock+flip | A |
| 44 | A: bank-sync upstream OTLP push+tag+relock+flip | A |
| 45 | A: niri-session-manager restore-once gate upstream | A |
| 46 | A: Samsung P1 rsync → fileSystems swap → acceptance | A |
| 47 | A: test-cv `virtualisation.fileSystems` fix + re-verify | A |
| 48 | A: browser-history registration-gate LIVE verify | A |
| 49 | A: import_export.go registration gate (cqrs-htmx) | A |
| 50 | A: samber/do InvokeNamed sweep (2-day-outage class) | A |

## g) Questions I cannot answer myself

1. **Resend sending domain**: which domain should `fromAddress` use (`noreply@lars.software`? `@helpless.ai`?), and can you add the DNS verification records? Everything else in go-live is mechanical; the from-domain is the one decision I cannot make or verify.
2. **Concurrent-session forensics**: the plan HTML vanished from disk and the attic VM test went red between 15:19 and 17:21 while daemon commits touched `flake.lock` (the plain-`nix fmt` re-lock trap), gpu-active, system-health, cv.nix and samsung scripts. Was another session mid-refactor there (and will fix/claim it), or do you want me to treat the fa4309ce lock churn as prime suspect and investigate/revert it? Per house rules I don't touch changes I didn't author without your call.
3. **Paperless inbound mailbox**: which mailbox should the mail consumer poll (Gmail app password on which account?), or should inbound stay unplanned for now? Pure user decision — blocks the last go-live step.

---

*Point-in-time snapshot. Living source: TODO_LIST.md. Full task explosion: `docs/planning/2026-09-02_17_20-mail-relay-completion-full-backlog-pareto-plan.html`.*
