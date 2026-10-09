# Status — dnsblockd Scoped Filter Proxy Wiring Session

**Date:** 2026-10-08 13:41 CEST · **Scope:** this session only (SystemNix + the dnsblockd product repo) · **Author:** Crush agent session

**Session in one paragraph:** Started as a question ("how did we configure DNS proxies for dnsblockd?") that I answered WRONG (reported the DoT forwarders + temp-allow reverse proxy; the ask was the ADR-0018 **scoped filter proxy**). After the owner's correction I researched the product repo, answered correctly, and — on "fix?" — wired the full filter-proxy capability into SystemNix: 4 module options, YAML/env rendering, an eval assertion mirroring upstream `ErrFilterNeedsAddressResponse`, a render-test contract (item 7) with a negative test, the runbook entry, and a post-deploy probe queue. All checks green. The feature itself stays **off** (owner opt-in by doctrine).

---

## Self-Review (asked first: what did I forget / do worse / still improve?)

**What I forgot:**

- **The vocabulary lives in the product repo.** I answered "DNS proxies" from the consumer repo (SystemNix) and never checked `/home/lars/projects/dnsblockd`, where ADR-0018 defines the term. The owner had to spend a correction round on me. The corrected answer even required reading the upstream ADR I could have grepped in the first minute.
- **Supply-side verification came late.** I verified the live config YAML but not which dnsblockd binary runs, until after the wiring was done. Had the lock predated the filter-proxy feature (ADR dated 2026-10-03, last-known lock 2026-09-30), everything would have been a silent no-op. It turned out fine (lock `8c35ccd` == live binary), but by luck of a parallel deploy, not by my ordering.
- **Formatter not run before verification.** My hand-edits deviated from alejandra; the scoped treefmt reformatted 2 files _after_ the render check had passed, forcing a rebuild cycle.
- **Banned tool on first try.** I reached for `systemctl show` (tool-blocked) before reading the unit file from `/etc/systemd/system` — the working probe set is even documented in the TODO library.

**What I could have done better:**

- Asked/checked "which repo owns this term?" before answering instead of after being corrected.
- Run buildflow first (this repo is BuildFlow-covered; I ran raw `nix build`/`nix flake check` before loading the buildflow skill and only found the 5 pre-existing findings later).
- Verified the deploy-parity (lock rev ↔ live binary ↔ feature presence) as step one of any upstream-feature wiring, not as an afterthought.

**What I could still improve (open, not done this session):**

- The wrapper now defines options upstream's own NixOS module also defines (split-brain risk — see (e) item 1).
- No rpi3-dns render-contract coverage (module is shared; render test only extends evo-x2).
- Did not formally prove the 5 buildflow findings pre-date this session (triaged from content, not from a pre-session run).

---

## a) FULLY DONE

| #  | Work                                                                                                                                                                                                                                                                                                                                                                                                  | Evidence                                                                                                                                                                                                  | Scope                                           |
| -- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| a1 | Scoped filter proxy wired into the dns-blocker module: `proxyFilterDomains`, `proxyInjectScriptURL`, `proxyInjectStripCSP`, `proxyTLSPassthrough` options; filter domains render into YAML only when set; inject URL rides `DNSBLOCKD_PROXY_INJECT_SCRIPT_URL` systemd env (never the store YAML); eval assertion mirrors upstream `ErrFilterNeedsAddressResponse` (filter domains require `zero_ip`) | daemon commit `6d7ef905` (dns-blocker.nix +77); `checks.x86_64-linux.dns-blocker-render` green ("content OK", store `azrbdmxrl1qa84c38cjb3dbaikvr61bh`); `nix flake check --no-build` = all checks passed | `modules/nixos/services/dns-blocker.nix`        |
| a2 | Render-test contract item 7: host renders NO filter key (inert), variant renders verbatim, inject URL pinned env-only in BOTH directions, negative test proves the nxdomain assertion fires                                                                                                                                                                                                           | same commit `6d7ef905` (test +49); render check green incl. negative tests                                                                                                                                | `tests/test-dns-blocker-render.nix`             |
| a3 | Stale comment corrected: "sdns root recursion is broken" falsified (recursion works since upstream `8e598c01`/T299; forwarders are a deliberate owner choice)                                                                                                                                                                                                                                         | daemon commit `30194cb2`; parse-checked                                                                                                                                                                   | `platforms/nixos/system/dns-blocker-config.nix` |
| a4 | Runbook entry: scoped filter proxy constraints (zero_ip requirement, never-splice TLS, CA trust, startup-only filter set, fail-open classifier)                                                                                                                                                                                                                                                       | daemon commit `99c10a98`                                                                                                                                                                                  | `docs/services/dnsblockd.md`                    |
| a5 | Supply-side parity verified: locked dnsblockd rev `8c35ccd` == local repo HEAD, `internal/filterdomain` exists at that rev, live unit already runs `dnsblockd-8c35ccd`                                                                                                                                                                                                                                | merge-base ancestry check + `git cat-file -e` at lock rev + live unit ExecStart read                                                                                                                      | flake.lock / live system                        |
| a6 | Scoped formatting + TODO-system validation                                                                                                                                                                                                                                                                                                                                                            | `nix fmt` scoped (3 files, 2 reflowed → daemon commit `052888fb`); `check-todo-system.sh` = "queue/library structure clean" (exit 0)                                                                      | session files                                   |
| a7 | Post-deploy probe + 6 direct follow-ups self-harvested into `TODO_LIST.md` + `docs/todo/services.md` (+1 upstream row) at authoring time                                                                                                                                                                                                                                                              | same checker run, structure clean                                                                                                                                                                         | TODO surfaces                                   |

## b) PARTIALLY DONE

| #  | Work                                        | Works now                                                                                                                                                                                                                 | Remains open                                                                                                                             | Blocker                                                             | Effort |
| -- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ------ |
| b1 | Filter-proxy capability end-to-end          | Eval-time wiring, render contract, assertion, docs all green                                                                                                                                                              | Nothing runs at runtime until the owner picks domains + inject URL; no post-deploy probe yet (queued)                                    | Next deploy (currently blocked by bank-sync FOD, tracked elsewhere) | S      |
| b2 | Upstream-consumption readiness              | Confirmed lock rev + live binary carry `filterdomain`; koanf env mapping verified from source (`DNSBLOCKD_` prefix, flat keys)                                                                                            | `/inject/filter.js` endpoint existence on nsfw-classifier never verified; inject-URL validation surface upstream unchecked (both queued) | none                                                                | S      |
| b3 | buildflow quality gate                      | Triaged: 5 error findings (nix-checker 4, flake-meta-checker 1) all name transitive flake.lock inputs — the skill's documented false-positive class; preflight warns (24 fetch-scheme mismatches, stale buildflow binary) | Formal pre-session proof + AGENTS.md known-tool-bug record (queued); gate stays red at HEAD regardless                                   | none                                                                | M      |
| b4 | CA-trust claim for filter-domain enablement | Runbook documents the precondition; configuration.nix:133 comment asserts evo-x2 trusts the dnsblockd CA                                                                                                                  | Byte-compare pki store entry vs the sops `dnsblockd_ca_cert` never done (queued)                                                         | none                                                                | S      |

## c) NOT STARTED

| #  | Work                                                                                                                 | Why not started                                                                                                                   | Priority      |
| -- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------- |
| c1 | **Filter-proxy enablement** (domain list + inject URL + device CA rollout)                                           | Owner-gated by doctrine (ADR-0018 opt-in; the max-adoption/tracking precedents require owner sanction for behavioral DNS changes) | owner decides |
| c2 | nsfw-classifier as the inject consumer (wiring `nsfw.home.lan:8104/inject/filter.js` into the module)                | Depends on c1 + b2 verification                                                                                                   | after c1      |
| c3 | Filter-proxy observability (SigNoz rule / Gatus check / metric audit for filter-path labels)                         | Feature off; monitoring without a feature is phantom-metric class                                                                 | with c1       |
| c4 | rpi3-dns render variant in the render test                                                                           | Queued this session, not dispatched                                                                                               | Medium        |
| c5 | Client-device CA trust rollout doc (macbook etc.)                                                                    | Owner-domain knowledge; ADR says rollout runbook documents it — SystemNix side has nothing                                        | with c1       |
| c6 | Wrapper-vs-upstream-module migration decision (consume upstream `nix/modules/nixos` options instead of forking them) | Architecture call, owner input needed (see g2)                                                                                    | decision      |

## d) TOTALLY FUCKED UP

Nothing this session **built** is broken — every check is green and nothing touches runtime until a deploy. The honest failures:

1. **The first answer was confidently wrong.** I reported the wrong concept as the answer to "DNS proxies" and would have enshrined the misread if the owner hadn't corrected me. Severity: wasted owner attention, one full correction round. Root cause: answered from the consumer repo without consulting the repo that owns the vocabulary. Workaround/fix: disambiguation note queued (c-item, services queue).
2. **The tree's quality gate is RED at HEAD.** buildflow exits non-zero: 5 error findings (nix-checker ×4, flake-meta-checker ×1 — all the transitive-input class). Pre-existing (none name my files, I added no inputs), but "the gate fails" is the state of the tree. No workaround applied; formal proof queued.
3. **Next deploy is BLOCKED (unrelated, tracked).** bank-sync FOD vendorHash mismatch — the toplevel does not build; the concurrently-running `buildflow -s nix-hash-fix` session owns the repair (per the 08-22 report chain). My work rides whatever deploy lands after that.
4. **Parallel-session exposure (awareness, not damage).** The daemon batched my module+test into a commit (`6d7ef905`) that ALSO carries another session's `TODO_LIST.md`, cv status report, and `docs/todo/pipeline.md` edits; a later daemon commit (`f5feb77d`) deleted the voice-agent plugin (15 files, −1487 lines) and 6 foreign files sat dirty at session end. I verified my fragments, touched nothing foreign, and flag it here for owner awareness — I can't vouch for the other session's work.

## e) WHAT WE SHOULD IMPROVE

1. **Wrapper option duplication is a split brain.** SystemNix `dns-blocker.nix` now defines option surfaces that upstream dnsblockd's own NixOS module (`nix/modules/nixos/options/proxy-tls.nix`) also defines — two sources of truth for defaults/wording that WILL drift. Mitigation today: the render test pins the YAML contract. Real fix: decide whether the wrapper consumes upstream's module (owner call, g2). Impact: every upstream option addition currently costs a wrapper + test change.
2. **Terminology routing.** "Check the repo that owns the term" should be a reflex, not a correction away. Cheap fix: the 3-concept disambiguation paragraph in `docs/agents/sso-dns.md` (queued).
3. **Supply-side parity as a first step.** "Lock rev contains the feature, live binary runs it" should precede any config wiring for upstream features — this session did it backwards and got lucky. Candidate: one line in `docs/agents/nix-flakes.md` (not yet queued — fold into the disambiguation row's edit or a pipeline row).
4. **Format-as-you-go.** Run the scoped formatter immediately after editing .nix files, before burning a build cycle on verification.
5. **Render-test eval cost.** Seven `extendModules` evals of the full evo-x2 config per check run and grows with every feature; a shared-base eval pattern would keep the contract cheap. Impact: minutes per CI run; Effort M; category Quality.
6. **buildflow-known-bugs documentation.** The transitive-input findings get re-triaged by every session that runs the gate; one AGENTS.md paragraph ends that tax (queued).

## f) 50 things to get done next

_Brainstorm per the skill's rule: items 1-8 are session-owned follow-ups (harvested); 9-15 are tracked-elsewhere pointers (deliberately not re-queued); 16+ are ROADMAP fuel — docs-health HARVEST must apply routing rigor, most are NOT queue-ready. Impact/Effort/Category per item._

**Session-owned (harvested this session):**

1. Owner decision: enable the filter proxy (domains + inject URL) — Impact Critical (unlocks the whole feature) · Effort S (owner time) · Decision
2. Post-deploy probe: filter-proxy keys + clean restart after next deploy — High · S · Verification
3. Add rpi3-dns render variant to the render test — Medium · S · Quality
4. Verify nsfw-classifier serves `/inject/filter.js` (correct runbook if not) — High · S · Verification
5. Byte-compare dnsblockd CA: pki store vs sops secret — High · S · Verification
6. Sweep dns-blocker comments for other pre-T299 falsified claims — Medium · S · Cleanup
7. 3-concept "proxy" disambiguation in docs/agents/sso-dns.md — Medium · S · Documentation
8. Prove buildflow's 5 findings pre-date the session + record known-tool-bug in AGENTS.md — Medium · M · Quality
9. Check upstream inject-URL validation; mirror or request — Medium · S · Upstream (queued in upstream.md)
10. Monitor-side: add filter-proxy observability only together with enablement (anti-phantom ordering) — High · M · Feature
11. Client-device CA rollout doc for filter domains — Medium · S · Documentation
12. Eval assertion: filter domains require CA cert/key present (after verifying upstream's actual requirement) — Medium · S · Quality
13. Fold "supply-side parity first" into docs/agents/nix-flakes.md — Low · S · Documentation
14. Enforce deploy-parity probe in the runbook's next dnsblockd entry (lock rev == live binary == feature present) — Medium · S · Verification
15. CHANGELOG entry for the filter-proxy wiring (repo convention check first) — Low · S · Documentation

**Already tracked (pointers, no new rows):**
16. bank-sync FOD deploy blocker + fix-locus verification (owns the next-deploy gate) — Critical · — · Bug
17. 89 unharvested §f status reports (todo checker WARN) — Medium · L · Documentation (docs-health HARVEST backlog)
18. UNANCHORED first-switch root cause + deploy.sh anchor loop — High · M · Bug
19. I/O-pressure gate: per-device %util signals (PSI multi-session noise blocks deploys) — High · M · Quality
20. post-deploy smoke: stop silent re-baselining of the 14 known FAILs — High · S · Process
21. Voice-agent deletion (`f5feb77d`, −1487 lines) + 6 dirty foreign files: owner review of the parallel session's work — Medium · S · Review
22. ExtendModules assertion-forcing gotcha documentation (nix-flakes.md) — Low · S · Documentation
23. systemctl-banned probe-set documentation (already queued pre-session) — Low · S · Documentation
24. Capability-audit 4-leg matrix as a selftest check — Medium · M · Quality
25. Geometrikks v0.20.0 bump + #301/#302 re-verification — Medium · M · Feature

**ROADMAP fuel (not queue-ready):**
26. Wrapper→upstream-module option migration (kill the option split brain) — High · L · Refactor (owner call)
27. VM test: boot dnsblockd with a filter domain + assert the lie answers and injection happens — High · L · Quality
28. Shared-base eval pattern for the render test (7 extendModules → 1 + cheap variants) — Medium · M · Quality
29. Filter-proxy load test (injection latency on HTML ≤2MB bodies under LAN load) — Medium · M · Quality
30. SigNoz dashboard row for filter-domain query outcomes (with c1) — Medium · S · Feature
31. DNS failover interplay: rpi3 serves the same YAML — confirm filter domains fail over coherently (both hosts lie identically) — Medium · S · Verification
32. Inventory other dnsblockd config keys the wrapper doesn't yet expose (dhcp_lease_file discovery, doh3, unbound_control, …) and mark each expose/skip deliberately — Medium · M · Cleanup
33. Render test: assert the OIDC env file pattern still excludes secrets from the YAML (guard against future leaks) — Medium · S · Security
34. Gatus check for the block-page listener on the block IP (today only unit state + stats are covered) — Medium · S · Quality
35. Document the dnsblockd restart budget (blocklist reload ~2min) in the enablement runbook step — Low · S · Documentation
36. Nightly drift check: locked dnsblockd rev vs local repo HEAD (the parity this session verified manually) — Medium · S · Quality
37. Upstream: propose startup log line when filter domains are set but CA files are missing — Low · S · Upstream
38. Upstream: inject-URL scheme validation (dup of 9's upstream half; close one) — Low · S · Upstream
39. Evaluate `dns_block_response` type: enum only allows zero_ip/nxdomain — upstream also has custom-IP modes? verify and expose if real — Low · S · Feature
40. DMS widget: surface filter-proxy state once enabled (deferred — scope creep guard) — Low · M · Feature
41. Consider `proxyFilterDomains` eval-time suffix validation (registrable-domain shape) mirroring upstream `filterdomain` parsing — Medium · S · Quality
42. dms-plugins/quickshell: confirm the voice-agent removal (d) didn't orphan widget references — Medium · S · Cleanup (parallel session's debris)
43. Retire the `result` symlink from manual `nix build` runs into trash after use (tree hygiene) — Low · S · Cleanup
44. Run `buildflow doctor` binary-freshness fix (advisory warn: binary behind BuildFlow HEAD) — Low · S · Tooling
45. Flake input fetch-scheme alignment (24 `github:` vs private repos) — Medium · M · Security (owner call: lock churn)
46. go-cqrs-lite fetch-scheme flip (public repo on git+ssh — opposite direction) — Low · S · Cleanup
47. Add the render test to the pre-commit fast path (currently CI/check-only) — Low · S · Tooling
48. Write the "dnsblockd option surface" table into the runbook (option → YAML key → default → test pin) — Medium · M · Documentation
49. ADR pointer: add ADR-0018 link to the runbook bullet's upstream contract line — Low · S · Documentation
50. Re-run the full verification battery after the bank-sync FOD lands (toplevel build + render check + probe) — Critical · M · Verification

## g) Questions I cannot answer myself

1. **Do you want the scoped filter proxy ENABLED now — and if so, which domain families and is nsfw-classifier's `/inject/filter.js` the intended script?** Everything else is wired; this is the owner-gated behavioral-DNS decision (precedent: tracking-dial memo). I cannot pick filtering domains for the household.
2. **Should the SystemNix wrapper migrate to consuming upstream dnsblockd's own NixOS module options instead of forking them?** It's an L-effort refactor that kills the option split brain but couples SystemNix to upstream's module layout; I can argue both sides but the coupling appetite is yours.
3. **Do the client devices (macbook, and any future filter-domain target) trust the dnsblockd CA?** evo-x2's trust is a config comment I've queued for byte-verification; device-side trust state is invisible from this host and gates every filter-domain rollout.

---

_Harvest status: items 1-9 self-harvested at authoring time into `TODO_LIST.md` + `docs/todo/services.md` (+ `docs/todo/upstream.md`); 15-25 already tracked elsewhere; the rest deliberately not harvested (ROADMAP fuel / owner-gated / duplicate pointers) per the TODO-system doctrine. Checker: structure clean, exit 0._

_Format note: skill default is a styled HTML dashboard; this report is `.md` because the prompt explicitly named the `.md` path — honored as the standing dispatch-report shape, not propagated as a new default._

_No commit made (harness rule: never commit without explicit instruction) — the auto-commit daemon owns this file._
