# 2026-10-12 13:38 — crm.home.lan PocketID outage: root cause + two-iteration fix; dnsblockd startup hang discovered

Session window ~11:55 → 13:38 on evo-x2. One agent session among several
(a parallel session was editing discordsync.nix / forgejo.nix / llama-chat.nix /
btrfs-health.nix / configuration.nix and TODO_LIST.md mid-flight — it clobbered
one of my TODO_LIST.md edits, re-applied; an image-generation batch
(`qwen_edit_batch.py`) + multiple `go test` / `nix run .#test` processes drove
the IO storm all session).

Started from the owner question: _"Why does crm.home.lan lost it's PocketID
integration???"_

## a) FULLY DONE

1. **The outage root-caused with journal forensics.** crm-server runs OIDC
   discovery exactly ONCE at startup; a start before `auth.home.lan` resolves
   logs `oidc sign-in disabled: provider init failed … no such host` and is
   NEVER retried — silent passkey-only degrade. Journal shows it fired on
   EVERY boot/deploy since 2026-10-10 13:20 (first live hit 2026-10-10 04:06,
   the §d.4 of the 05-52 report). Restored same-minute via restart (12:03,
   `oidc sign-in enabled`).
2. **The durable fix landed and deployed — two iterations, the first one was
   WRONG and live A/B proved it.** v1 (`/dev/tcp/auth.home.lan:1411` socket
   probe + `TimeoutStartSec=3min`) shipped in the 12:38 deploy and its 120s
   window expired with "not reachable" WHILE discovery succeeded right after
   (12:58:14) — `:1411` is Pocket ID's loopback listener, NOT the served
   surface (Caddy `:443` is). v2 (live, `modules/nixos/services/crm.nix:215-233`):
   bounded fail-open `ExecStartPre` waiting on
   `getent hosts auth.home.lan` (120s) + `TimeoutStartSec=3min`, asserting
   exactly what discovery needs: local DNS answering.
3. **v2 verified BOTH directions live, not just positive:**
   - resolver-up: gate passes in 0s; the 13:24:47 + 13:25:12 deploy restarts
     show NO wait and `oidc sign-in enabled` both times (vs the same-shape
     13:08:10 degrade pre-fix);
   - resolver-down: 6s CONTROLLED dnsblockd stop → `getent` rc=2 immediately,
     DNS restored after. (`pkgs.glibc` does not ship `bin/getent` — it is the
     split `pkgs.getent` package; the dry-fire caught the missing binary
     before the second deploy.)
   - Dry-fire discipline: the exact rendered ExecStartPre (`$$`→`$` as systemd
     expands it) was executed standalone before shipping v2. v1 never was —
     that is why its two defects shipped.
4. **The §d.4 verification gap closed: post-deploy-check §20 "Kith CRM OIDC
   readiness".** Verdicts the LAST `oidc sign-in` line since boot:
   enabled→PASS / disabled→FAIL with the restart hint / flags-deployed-but-no-
   line→WARN / OIDC not provisioned→SKIP. Shellcheck-clean
   (`nix shell nixpkgs#shellcheck`), live-verified PASS in the integrated
   smoke run (`scripts/post-deploy-check.sh:2070-2100`).
5. **dnsblockd startup hang DISCOVERED, triaged, restored, filed.** The
   12:38-deploy's dnsblockd restart (13:06:08, PID 4478) logged startup
   phases 1-3 (config_load, otel_setup, extras_and_validation) then NOTHING —
   no server_init, no listeners_start, no bind error — for 8+ minutes while
   the process stayed up (retention loop + tracking kept running):
   `127.0.0.1:53` dead host-wide, `getent hosts auth.home.lan` empty. Manual
   restart 13:14:05 → all 5 phases in 14s. A healthy-vs-hung discriminator is
   now in the filed row: `journalctl -u dnsblockd | grep 'startup phase
   complete'` — 5 phases = healthy, 3 = hung. Filed [ready] in
   docs/todo/services.md + TODO_LIST.md.
6. **Runbook updated** (docs/services/crm.md): DNS-wait gate semantics, the
   post-gate degrade meaning ("a persisting degrade after a start means
   Pocket ID itself failed discovery — the gate already held for DNS"), §20
   pointer.
7. **Todo system hygiene:** boot-race rows closed on BOTH surfaces with
   post-state + the iteration lesson (TODO_LIST.md:176, docs/todo/services.md:307);
   dnsblockd hang filed on both surfaces (TODO_LIST.md:177,
   docs/todo/services.md:308). One TODO_LIST.md edit was clobbered mid-flight
   by the parallel session and re-applied (verified by grep after, not by
   trusting the tool result).
8. **Deploy smoke final verdict:** re-run post-deploy-check → 140 PASS /
   5 FAIL (ALL match the fail-baseline → advisory exit 1, not regression
   exit 3) / §20 PASS. The 5 are storm-correlated pre-existing classes
   (Pocket ID SQLITE_BUSY restart burst, discordsync hotloop — §18's
   namesake, fastflowlm :52625, bank-sync errors, node-exporter journal
   rate) — none crm-related; nix-daemon 1128% CPU = the parallel sessions'
   builds.

## b) PARTIALLY DONE

1. **dnsblockd hang ROOT CAUSE — hypothesis only.** Correlation: the stuck
   instance's retention cleanup RAN during init ("data retention cleanup
   completed … duration=3m16s" at 13:09:27, started ~13:06:11), and
   server_init plausibly blocks on the same tracking/journal sqlite DB.
   The healthy 13:14 run's cleanup ALSO ran during init (finished 14s total),
   so contention-under-storm remains unproven. No reproduction attempted
   (each attempt risks another host-wide DNS window). Hypothesis + fix
   options filed in the row (systemd startup watchdog / move retention after
   listeners_start / upstream issue).
2. **§20 negative paths — logic-reviewed, not live-exercised.** The FAIL
   branch would have matched the 13:08 journal line, and the WARN/SKIP
   branches are simple, but only the PASS branch was exercised live (a FAIL
   rehearsal would need Pocket ID actually down; skipped as destructive).
3. **Storm-suspect re-run.** Both smoke runs this session executed under IO
   PSI 55-75%; 2-4 checks remained STORM-SUSPECT ("re-run when the box is
   calm"). The box never went calm this session (parallel-session builds +
   image batch). Re-run still owed.

## c) NOT STARTED (observed, not worked)

1. **Was the 13:06→13:14 host-DNS outage visible in Gatus/SigNoz?** Not
   checked. If the monitoring stack resolves through the same dead
   127.0.0.1:53 it should have lit up; if it stayed green, that is an
   observability gap for the most boring failure class there is.
2. **dnsblockd's own OIDC boot behavior.** dnsblockd config carries
   `oidc_issuer: https://auth.home.lan` — does IT one-shot-discover at boot
   and silently degrade like crm-server did? Same for the other Pocket ID
   consumers (browser-history, miniflux, paperless). No audit run.
3. **The OTel spam masking the hang.** dnsblockd logged `OpenTelemetry
   internal error … 4318: connection refused` ~1/min for hours (collector
   down) — the SAME journal held the hang's only symptom (absence of 5
   phase lines) and the spam drowns it. Not investigated, not filed until
   this report's harvest.
4. **`*.home.lan` wildcard — premise CORRECTED at harvest time.** My
   negative-testing discovered that ANY name resolves under home.lan
   (wildcard + `search` suffix). I initially framed this as "intent
   unknown — decision filed"; the harvest-time spot-check FALSIFIED that
   premise: the wildcard is INTENTIONAL and landed TODAY by the co-tenant
   session (dnsblockd `d5a22a4b`, the Caddy catch-all-404 feature,
   docs/status/2026-10-12_07-00_catchall-404-dnsblockd-wildcard-fix-live.md).
   No decision needed. Side-lesson: the crm DNS gate's discriminator
   ("127.0.0.1:53 answering") is unaffected — the wildcard is exactly WHY
   any-name-resolution proves the resolver is up.
5. **crm residuals from 2026-10-10 (pre-existing, untouched):** first
   Pocket-ID-login LINK, CV `/rest` green re-check, Twenty→Kith import,
   opportunity dedupe, api-token off argv.

## d) TOTALLY FUCKED UP

1. **v1 shipped to prod without a dry-fire.** Both of v1's defects (wrong
   probe target `:1411`; nothing else — the `$$` expansion was right) were
   catchable in 10 seconds by executing the rendered ExecStartPre before the
   deploy. The lesson cost one full deploy cycle + a 2-minute 120s stall on
   the production restart. The dry-fire is now in the close-out and queued
   as a CONTRIBUTING/systemd.md convention.
2. **I initially framed the race as BOOT-only.** The first root-cause answer
   ("every boot loses the DNS race") missed that the deploy script's own
   dnsblockd-convergence restarts create the SAME race window mid-day — the
   13:08 degrade happened during a DEPLOY, not a boot. Only the v1-deploy
   telemetry exposed it. The fix (start-time gate) covers both regardless,
   but the diagnosis was incomplete when delivered.
3. **Probe-target assumption never live-verified before shipping.** One
   `ss -ltn | grep 1411` before the v1 deploy would have shown the listener
   is not where I pointed. I checked config (`lib/ports.nix` pocket-id=1411)
   instead of the live socket. Config-claimed ≠ live-served — the same
   session-discipline rule I applied to DNS (`ss -lun` for :53) I skipped
   for :1411.
4. **A status-report rule trap I then corrected:** my first "restored"
   close-out (12:03) asserted the FEATURE was live from one journal line —
   correct in this case, but I verified liveness, not the feature-readiness
   line, exactly the §d.4 failure mode I was re-firing. The readiness line
   IS what I verified the second time.
5. **Two pressure-gate overrides in one session** (12:38 + 13:20), both
   attributed before overriding (18 D-state build/test churn; faceswap
   batch) and both benign — but "override twice in one session while a
   storm is rolling" is exactly the pattern the gate exists to slow down.
   No freeze/corruption occurred; noting the pattern, not hiding it.

## e) WHAT WE SHOULD IMPROVE

1. **Dry-fire every ExecStartPre gate before deploy** — render the unit
   (`nix eval --json`), `$$`→`$`, execute, assert pass/timeout behavior.
   Convention worth encoding in docs/agents/systemd.md + CONTRIBUTING.
2. **Probe the SERVED surface, not the config port.** Config says a port
   exists; only `ss` says who listens where. The gate question is always
   "can the consumer reach what it actually dials".
3. **Readiness-line verification is the post-deploy standard** — §20 should
   become the pattern for every feature that logs an "enabled" line
   (OIDC consumers, auth gates, sync features). A 200 from a proxy is not
   feature verification.
4. **Journal-noise hygiene:** the OTel-refused spam (1/min, hours) is a
   fat-finger detector for exactly the "symptom = absence of lines" class.
   Fix the collector binding or gate the exporter.
5. **Fail-open vs fail-closed should be a conscious, written choice per
   gate** — crm's gate fails open (passkeys keep working) with a loud log +
   §20 FAIL. That combination is the right shape; write it down as the
   reference pattern.
6. **Smoke-baseline hygiene worked as designed** (NEW-vs-baseline exit 3 vs
   advisory exit 1) — worth a sentence in CONTRIBUTING so future sessions
   read exit-3 as "investigate now" not "ignore".

## f) UP TO 50 THINGS WE SHOULD GET DONE NEXT (session-scope only)

Harvested at authoring time into TODO_LIST.md + docs/todo/*.md per the TODO
system (ready/decision/watch tagged). Grouped, numbered:

**This session's direct follow-ups (NEW rows filed):**

1. dnsblockd startup hang — investigate root cause under controlled
   repro/storm correlation, add systemd init watchdog or fix init order
   (filed [ready], services.md:308 + TODO_LIST.md:177).
2. dnsblockd OTel 4318-refused log spam — fix exporter endpoint or silence
   when collector down (filed [ready]).
3. ~~`*.home.lan` wildcard intent — decision~~ **MOOT at harvest time** — intentional, landed today by the co-tenant session (dnsblockd `d5a22a4b`, catch-all-404 feature); see §c.4 correction. NOT filed as a decision row.
4. Audit ALL Pocket ID consumers for the one-shot-discovery degrade class
   (dnsblockd, browser-history, miniflux, paperless, forgejo, immich…)
   (filed [ready]).
5. §20 negative-path fixture test (lib extraction + selftest, house §17/§19
   pattern) (filed [ready]).
6. dnsblockd runbook: document the 5-phase health discriminator + hang
   playbook (filed [ready], docs row).
7. Verify the 13:06→13:14 DNS outage's Gatus/SigNoz visibility; add a
   host-local-resolution check if it stayed green (filed [ready]).
8. Memory reclaim-thrash reviews: bank-sync (5,094 MemoryHigh hits),
   discordsync (31,641), geometrikks (11,548), inboxclean-web (28,978) —
   ceiling bumps or workload fixes (filed [ready], one combined row).
9. Dry-fire convention into docs/agents/systemd.md + CONTRIBUTING (filed
   [ready], docs row).
10. dnsblockd upstream: retention-vs-init contention issue — only after
    verified repro (verify-before-filing gate) (filed [blocked:repro] in
    upstream.md).
11. crm upstream: OIDC init retry option — SystemNix gate covers us; a
    retry helps every downstream (filed [watch], upstream.md).
12. STORM-SUSPECT re-run when the box is calm (owed from both smoke runs)
    (filed [watch]).

**Pre-existing rows this session TOUCHED or corroborated (open, not new):**
13. Pocket ID SQLITE_BUSY restart bursts (corroborated twice today).
14. discordsync hotloop (§18 FAIL: 103-201% CPU, 744-2,346 lines/min).
15. crm-server api-token off ExecStart argv (ps-visible; blocked:user,
bundles with CV rev bump).
16. First Pocket-ID-login LINK on crm.home.lan (blocked:user).
17. CV syncer durable replay checkpoint (the 404-burst stale-external-id
evidence).
18. CRM dedupe ~10,489 opportunities (blocked:deploy, sequences after 17).
19. Twenty→Kith people import, 139 contacts staged (blocked:user).
20. CRM Google Contacts sync enablement ladder (blocked:user).
21. InboxClean→CRM feed go-live (decision).
22. Multi-RPID WebAuthn upstream draft (relevant again with SSO live).
23. Pocket ID auto-rotation deploy window + apply-flip (blocked:deploy /
decision).
24. Fastflowlm :52625 unreachable (in today's baseline fails).
25. Bank-sync sync errors >0 (in today's baseline fails).
26. node-exporter journal rate 315-347/min (in today's baseline fails).
27. `crm.home.lan` cloud-vHost per-domain auth (crm.larsartmann.cloud).
28. Stray crm test servers :18091-95/:18099 ownership+liveness (watch).
29. TODO-harvest pre-commit gate: 96 unharvested reports backlog (bypassed
again by upstream pushes — campaign row pending).
30. Flake check memory: document the targeted-eval alternative
(single-host toplevel eval ~seconds, covers the same host audits) and
when full `nix flake check` is mandatory (filed [ready], docs row).

**Deliberately NOT harvested:** the 20GB flake-check RAM explanation
(knowledge, now in this report; item 30 captures its actionable core); the
faceswap/qwen batch (outside this repo); parallel-session module edits
(discordsync/forgejo/llama-chat/btrfs-health/configuration.nix — not mine,
flagged per shared-tree rule, owners active).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **May I run a controlled dnsblockd restart-repro under the current storm**
   (one bounded host-DNS window, seconds-to-minutes, to capture the hang
   with full debug — the 13:06 instance left zero error lines)? Or wait for
   the next natural occurrence and keep the 5-phase discriminator as the
   tripwire? (Risk: another silent DNS outage window on your workstation;
   benefit: actual root cause instead of the sqlite-contention hypothesis.)
2. **Standing policy on the deploy pressure-gate override?** Today I
   overrode twice after per-instance attribution (benign concurrent-session
   churn, both times). Keep the current "attribute-then-override" autonomy,
   or require an owner ping for override #2+ within one session/storm?
3. **MemoryHigh reclaim-thrash units (bank-sync 5k, discordsync 32k,
   geometrikks 11k, inboxclean-web 29k hits): raise ceilings or fix
   workloads?** Raising ceilings trades swap/page-cache pressure against
   kernel reclaim-thrash; I can analyze each unit, but the capacity
   preference (and which services may grow) is yours.

_Every §f NEW item (1-12) is landed in TODO_LIST.md and/or the matching
docs/todo/*.md at authoring time per the TODO system rules._
