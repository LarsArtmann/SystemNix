# Session Status Report — dots External-Repo Review + Self-Review (2026-09-10 23:53)

**Session scope:** User asked "What can we learn from https://github.com/taciturnaxolotl/dots?" → full source-level review with claim verification, learnings encoded into AGENTS.md / TODO_LIST / docs/research, then file export, then this self-review. NOTHING else was researched; no deploys, no .nix changes, no secrets touched.
**Format note:** user explicitly requested `.md` — overrides the status-report skill's HTML default (flagged per skill instructions).
**⚠️ Parallel session active:** the tree carries another session's in-flight work (miniflux service module + `flake.nix`/`ports.nix`/`caddy.nix`/`gatus-config.nix`/`homepage.nix` edits + a sibling external-repo study `docs/status/2026-09-10_23-49_external-repo-study-paepckehh-nixos-hardening-adoption.md`, authored ~4 min before this report). This session owns ONLY: `AGENTS.md`, `TODO_LIST.md`, `docs/research/2026-09-10_taciturnaxolotl-dots-review-vs-systemnix.md`, this report. Per Critical Rules, flagged rather than co-verified.

---

## a) FULLY DONE ✅

1. **Full review of `taciturnaxolotl/dots`** (~20 files read at source level, not summaries): README, complete file tree, `mkservice.md`, `lib/services-manifest.nix`, `lib/services.nix`, `modules/lib/mkService.nix` (all 392 lines), `.github/workflows/deploy-service.yml` + `deploy.yaml`, their `AGENTS.md` (complete), `modules/nixos/nix-cache.nix`, `patches/nix-2.34-daemon-no-interrupt-on-client-write.patch`, `crush.json`, `docs/src/{deployment,mkservice,wut,SUMMARY,README}.md`, `install.sh`/`post-install.sh`, prattle facter usage, terebithia nix settings.
2. **nix daemon-abort bug verified against primary sources** (verify-external-claims skill loaded and applied): nix#3768 (open since 2020-07-01, "Crash (SIGABRT) when connecting to substituter times out") + nix#12871 (open since 2025-04-02, stack `ignoreExceptionExceptInterrupt → TunnelLogger::log → enqueueMsg → std::terminate` matching dots' mechanism description verbatim, client error string confirmed).
3. **Our live exposure assessed on evo-x2**: deployed daemon nix 2.34.8 (affected family), `https://cache.home.lan/monitor365` substituter confirmed in `/etc/nix/nix.conf`, journal sweeps (bounded `--grep` form) Jan→Sep 2026 = ZERO abort signatures and ZERO `Main process exited`/`Failed with result` events for nix-daemon. Why we're clean so far: our attic-outage modes fail FAST (NXDOMAIN / Caddy 502) — the abort race needs a hanging connect (IO-storm-starved Caddy accepts is the plausible trigger).
4. **systemd `!` vs `+` prefix semantics verified** from the local systemd.service(5) man page: `!` only bypasses User=/Group=/SupplementaryGroups= (sandbox stays); `+` bypasses everything incl. CapabilityBoundingSet/namespaces. Correctly caveated for our `harden{}` units (empty bounding set ⇒ `+` still required for chown/DAC cases).
5. **AGENTS.md encoded (2 gotchas)**: the nix 2.34 abort class (mechanism, issues, our exposure, known patch shape, "don't debug from scratch when the signature appears") in Nix & Nixpkgs; the `!`/`+` distinction appended to the existing `+`-prefix gotcha.
6. **TODO_LIST Priority 1.5 row added**: service-completeness manifest audit (enabled service ⇒ Gatus + Homepage + backup-coordination + docs/services page) — the inversion of dots' `services-manifest` flake output into an assertion source.
7. **Research report written**: `docs/research/2026-09-10_taciturnaxolotl-dots-review-vs-systemnix.md` — verdict table, per-claim verification-status table, deploy-discipline analysis, what-NOT-to-copy table, actions-taken record. User-requested export of the chat analysis, expanded to be self-contained.
8. **Self-review corrections already applied during this review** (see also §d): the Lix-discrepancy claim in the research doc was corrected after a full-repo code search (atalanta/darwin DOES set `nix.package = lixPackageSets.latest.lix` in `modules/darwin/defaults.nix`; only the "both servers" clause of their AGENTS.md is stale — no lix setting exists for the Linux hosts, which is why their flake patches stock `nixComponents_2_34`); the exposure-sweep row was strengthened from "2026-06→09" to "2026-01→09 + unit-failure grep".
9. **Confirmed existing monitoring covers the abort class**: `nix-daemon` is in `system-health` `monitoredServices` and Gatus (`system_service_active{service="nix-daemon"}` + `start_limit_hit` at gatus-config.nix:1075-1078) — no new monitoring task invented for something already covered.

## b) PARTIALLY DONE 🟡

1. **Crash-sweep completeness**: journalctl-based sweeps are clean, but `systemctl show nix-daemon -p NRestarts` was BLOCKED (session security policy denies systemctl) and `coredumpctl` was inconclusive (blocked/timed out). The zero-hits claim rests on journal evidence only. Labeled as such in the research doc.
2. **"Our outage modes fail fast" chain**: the NXDOMAIN path is live-documented (2026-09-02 incident, AGENTS.md); the Caddy-502 path is REASONED from documented behavior (atticd is mount-gated per AGENTS) but not live-tested this session. Honest label: plausible-from-documented-behavior.
3. **TODO_LIST dedupe**: I read P0/P1/P1.5 in full before adding the new row but NOT P2–P7 (huge file, session kept scope tight) — duplicate risk against P3 Infrastructure/Prevention rows is unverified.
4. **dots tree coverage ~60%**: ghrpc internals, pbnj docs, bore-auth Go source, build-iso.yml, secrets.md, per-machine home configs were skimmed via their AGENTS/README, not read. Enough for the stated conclusions; not exhaustive.
5. **(f)-list routing**: per the status-report skill, section (f) is HARVEST fuel for TODO_LIST/ROADMAP — deliberately NOT bulk-harvested now (user said report-then-wait; most items below are one-liners or user decisions, and blind harvesting risks the same dedupe gap as (3)).

## c) NOT STARTED ⬜

1. **nix 2.34 daemon patch adoption decision** — deliberately deferred: zero observed hits, patching means carrying a nix overlay + from-source build. Encoded as knowledge with a "adopt on first occurrence" stance; proactive adoption is a user risk-appetite call (question g.1).
2. **Service-completeness manifest audit implementation** — TODO row exists; no code (flake check / script / CI step) written.
3. **`!`-prefix narrowing sweep** of our existing `+`-prefixed ExecStartPre uses (crush-daily, clickhouse ownership-heal, browser-history/overview gates) — identified as a least-privilege improvement, not executed.
4. **Line-number → section-anchor citations** in the research doc (fragile as written; see §d.3).
5. **Cross-linking the sibling session's paepckehh-hardening study** — landed 4 min before this report; likely overlapping conclusions (hardening adoption from an external repo), natural to cross-reference both research docs once theirs settles.

## d) TOTALLY FUCKED UP 💥 (all caught and corrected/flagged; nothing shipped broken)

1. **First journal sweep used our OWN documented IO-trap anti-pattern**: `journalctl -u nix-daemon --since | grep -c`-style piped walk with NO timeout — the exact class AGENTS.md documents twice. It backgrounded, I killed it and re-ran the bounded form (`--grep` inside journalctl + `timeout`). Should have written the bounded form FIRST; the repo even has a TODO row about this trap class.
2. **The research doc shipped a WRONG claim for ~2 hours**: "no `nix.package = lix` exists in any machine config" — false; `modules/darwin/defaults.nix` sets it (gated on `nix.enable`). Root cause: I concluded absence from grepping flake.nix + the two Linux machine files instead of running the one-command full-repo code search I eventually ran during this self-review. Classic verify-external-claims failure mode: specificity felt like evidence. Corrected in-file with a "corrected 2026-09-10 23:55" marker.
3. **Cited exact line numbers (`AGENTS.md:651`, `:691`) in a durable doc** — any later edit (parallel session, daemon batches) silently invalidates them. Should cite section/bullet titles.
4. **Added a TODO_LIST row without reading the full file** (only P0–P1.5 read) — violates the docs-health "no duplication" rule in spirit; dedupe check pending (see b.3).
5. **Minor**: first man-page lookup hit the wrong section (`systemd.exec` instead of `systemd.service` for the prefix table) — one wasted command, recovered immediately. Also burned a blocked-command round trip each on `ssh` and `systemctl` before pivoting to allowed read-only forms; the session env's denylist was knowable up front from the error the first time.

**Blast radius:** zero. No deploys, no builds, no .nix edits, no secrets. All damage confined to prose that is now corrected in-place.

## e) WHAT WE SHOULD IMPROVE 🔧

1. **"Does not exist anywhere" claims require a full-repo search** — `gh search code --repo <r> <term>` is one command; grep-of-a-few-files is not existence proof. Fold into personal application of verify-external-claims.
2. **Durable docs cite anchors, not line numbers.**
3. **Read the whole TODO_LIST before adding rows** (or grep it for keywords — `rg -i "manifest|completeness|registry" TODO_LIST.md` would have been the 5-second version).
4. **Apply our own journalctl discipline from command #1** — `--grep` + `--since` + `timeout` should be muscle memory in this repo, not a correction after backgrounding.
5. **Skill-load timing was right this session** (verify-external-claims before encoding; status-report before this report) — keep the discipline; the failure in §d.2 was APPLICATION, not loading.
6. **Session-env restrictions**: internalize the tool denylist (ssh/systemctl/sudo denied) at session start; plan read-only alternatives (local checks, journalctl) before the first blocked round trip.
7. **Fast-flap detection nuance noticed**: gatus 60s cadence + `system_service_restart_churn` may MISS a single fast SIGABRT→socket-restart cycle of nix-daemon. If the abort class ever fires, a dedicated churn/failure-counter sensitivity check may be wanted — noted, not actioned (no observed hits).

## f) Things to get done next (session-scoped; ~30 — the rest is deliberately left to the standing TODO_LIST backlog)

1. **USER DECISION**: adopt the nix 2.34 daemon patch proactively (overlay `appendPatches`, from-source nix build + maintenance) vs on-first-hit (current stance) — see question g.1.
2. Implement the **service-completeness manifest audit** (TODO row added): cross-reference enabled services ⇒ Gatus + Homepage + backup-coordination + docs/services; vehicle: flake check assertion or CI script (start by extending `gatus-config.nix`'s existing endpoint list evaluation).
3. **Dedupe-check** the new TODO row against TODO_LIST P2–P7 (grep "manifest|completeness").
4. Convert research-doc line citations to **section anchors**.
5. Check `nix-daemon` **NRestarts + coredumpctl** via a permitted path (root-run script or next sudo-capable session) to close the sweep gap (b.1).
6. **Live-test the Caddy-502 substituter path** inside `tests/test-attic.nix` (attic down ⇒ fast-fail, not hang) — turns the §b.2 reasoning into a regression test for the abort-precondition.
7. **`!` vs `+` audit**: enumerate all `+`-prefixed ExecStartPre in the repo; narrow to `!` where root identity suffices and the bounding set allows.
8. **stopUnits-equivalent** metadata for multi-unit services in backup-coordination (paperless/cv/immich class) — dots validated the pattern independently.
9. Cross-link the **sibling paepckehh-hardening study** with this review once it settles (shared "external repo adoption verdict" framing).
10. Watch **nix#3768 / nix#12871** for an upstream fix; when released, add a drop-condition to the AGENTS gotcha (it already points at dots' "drop once upstream lands a fix").
11. Revisit dots in ~3-6 months: the nix patch status and their deploy workflow comments (dead-socket keepalives) are the two artifacts worth re-reading.
12. **nixdoc-style doc comments** for `lib/default.nix` helpers (`harden`, `serviceDefaults`, `mkOidcGate`, `ioTier`…) enabling generated reference docs, dots-style.
13. Consider a **`services-manifest` flake output** for SystemNix anyway (machine × service × port × docs-link JSON) — cheap eval, feeds item 2 and possibly Homepage layout derivation.
14. **Restart-churn sensitivity**: verify `system_service_restart_churn` would catch a nix-daemon abort-restart cycle (e.7) — read the churn window in system-health.nix.
15. Add the **research-doc convention** to docs-health VERIFY scope: research docs must carry verification-status tables when they encode external claims (this one does; make it a pattern).
16. If item 1 decides PROACTIVE patching: port dots' patch verbatim (it is self-contained: `FdSink::allowInterrupts` + `processConnection`), pin via overlay in `overlays/linux.nix`, add a VM/eval check that the patched nix builds, and document the drop condition.
17. **Session-env allowlist awareness**: record in memory that this session class denies ssh/systemctl/sudo — future sessions plan accordingly (first-tool-call economy).
18. Sweep OUR AGENTS.md for other claims stated without a verification marker that could get the §d.2 treatment (candidates: any "X does not support Y" one-liners) — spot-check the top 5 most load-bearing ones.
19. The dots **`ExecStartPre`-with-`!` belt-and-suspenders dir creation** pattern vs our mount-gated oneshots: document when each is correct (tmpfiles + `!` for plain dirs; oneshot + RequiresMountsFor for pool-backed ReadWritePaths) — one paragraph in the Adding-a-Service procedure.
20. Their **`concurrency: group: deploy-<x>`** workflow pattern → if SystemNix ever gets CI deploy jobs, serialize per-host the same way; note in the deploy-runbook doc, not code.
21. **mdBook/libdoc evaluation** (P6-grade): is a generated docs book worth it for SystemNix, or does the AGENTS.md+docs/ tree suffice? Lean: suffice — but the decision costs one reading of `nix build .#docs` effort estimates.
22. Confirm the **auto-commit daemon** picked up this session's 4 files cleanly (no interleaving with the miniflux session's staged files — PATHSPEC-commit discipline is theirs to apply; just verify the next batch).
23. **gatus-config.nix:1075-1078** recovery text says "Likely killed by systemd-oomd" — now there is a SECOND known kill cause (the abort bug); update the alert text to mention both (one-line edit, next touch of the file).
24. If/when the attic VM test (item 6) lands green, add a **"substituter fast-fail"** assertion to pre-deploy-check §1's narinfo-error classification (infra-noise filter already exists there).
25. **Do NOT** adopt: git-pull deploys, per-service sudo, Cloudflare-DNS public TLS, Caddy ratelimit plugin — recorded rationale in the research doc §7; revisit only if SystemNix's threat model changes.

## g) Questions I can NOT figure out myself (3 max)

1. **nix daemon patch — proactive or reactive?** We have zero observed hits and fast-fail outage modes, but the trigger shape (IO-storm-starved Caddy accepts during an attic outage) matches this box's repeated freeze conditions. Proactive = overlay patch + from-source nix build + maintenance; reactive = current "adopt on first occurrence" stance. Which risk posture do you want? (This gates f.1/f.16.)
2. **CI-driven remote deploys — hard no, or someday?** dots' Tailscale+deploy-rs pipeline with pre-deploy generation capture and auto-rollback would directly counter our un-anchored-generation class (2026-09-09), but it restructures deploy.sh/pre-deploy assumptions and moves trust to CI+tailnet. Is that a direction you want explored, or stays local-deploy-only?
3. **Priority of the manifest-completeness audit** (f.2): it closes the "new service without Gatus check sails through every layer" gap and is currently sitting in P1.5 behind ~15 older rows. Bump it up, or does the standing backlog order stand?

---

**Attribution:** everything in §a-§f authored this session except where explicitly marked as the parallel session's work. No unrelated research was performed. Waiting for instructions.
