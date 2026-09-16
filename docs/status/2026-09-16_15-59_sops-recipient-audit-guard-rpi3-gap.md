# SOPS Recipient-Coverage Guard + rpi3 Gap — Session Status

**Date:** 2026-09-16 15:59
**Scope:** nixpkgs crush package analysis → SystemNix SOPS review → new eval-time guard (IN PROGRESS, gate currently RED)
**CWD session:** `/home/lars/projects/crush-config` (untouched); all work landed in `/home/lars/projects/SystemNix`

---

## Context (what triggered this)

Session began as a nixpkgs question (`pkgs/by-name/cr/crush`), expanded into a comparison against this host's Charm-NUR crush install, then into a SOPS config review that found real gaps, then into implementing the systematic fix. The implementation is mid-debug and **the repo's `nix flake check` is currently RED because of it** (see d).

---

## a) FULLY DONE (verified this session)

1. **nixpkgs crush package analysis (verified against master + nixos-unstable):**
   - nixpkgs ships `0.92.0` with `buildGo126Module`; upstream latest is `v0.94.2` (2026-09-14), whose `go.mod` requires `go 1.27.0` (verified at the tag).
   - `buildGo127Module` exists in nixpkgs master (`qui`, `jjui`, `sesh`, `evcc` already use it).
   - **Zero open bump PRs** (three query strategies). r-ryantm updated crush every 1–4 weeks for months, stopped exactly at `0.91.2 -> 0.92.0` (merged 2026-09-09) — i.e., the bot's next run hits the Go 1.27 builder wall and fails silently. A human PR is genuinely needed.
   - The package expression itself is already at nixpkgs best-practice standard (`finalAttrs`, `versionCheckHook`, cross-guarded `installShellCompletion`, `__darwinAllowLocalNetworking`, `nix-update-script`, complete `meta`). Nothing structural to improve; the only real gap is the version + builder switch.
2. **NixOS AI-agents policy extracted verbatim** (CONTRIBUTING.md master): `Assisted-by:` commit trailer with tool + model name/version required for LLM-assisted commits (`Co-authored-by:` explicitly insufficient); PR descriptions disclosed separately; human accountable, vibe-coding-not-permitted; r-ryantm/nix-update exempt.
3. **This host's crush install traced:** `SystemNix/platforms/common/packages/base.nix:340` uses `nur.repos.charmbracelet.crush` (prebuilt v0.94.2 tarball) wrapped in `ionice -c 2 -n 3 nice -n 5` — day-one freshness + I/O priority over nixpkgs source purity. Consequence: a nixpkgs bump PR is purely altruistic; this fleet gains nothing directly.
4. **SOPS review findings (all verified at source):**
   - **Gap 1 (P0):** ALL 32 encrypted files carry exactly ONE recipient (`age133ck…` = evo-x2). ADR-004's mandated 3-2-1 backup of the master decryption key (`/etc/ssh/ssh_host_ed25519_key`) has been "NOT YET IMPLEMENTED" since 2026-03-29 — no contradicting evidence anywhere. Lose that key → ALL secrets unrecoverable.
   - **Gap 2:** `systems/rpi3-dns.nix` consumes `dns-failover.yaml` (and the dnsblockd files) but the rpi3 age key is commented out in `.sops.yaml`; every file lacks the recipient. Activation-time death on the Pi, invisible to every current gate. Known since 2026-06 (git `1a6e612d`) and flagged in an archived 2026-07-13 report.
   - **Gap 3:** `systems/rpi3-dns.nix` listed modules explicitly and did NOT import `sops-key-audit` — the Pi evaluated its sops config with no guards at all.
   - Strengths confirmed: eval-time key-audit (live-fired successfully 2026-09-16 on cv.yaml), conditional materialization, documented permission exceptions, PLACEHOLDER-inert doctrine, per-file blast-radius splits.
5. **Candidate rpi3 recipient derived from public material:** `192.168.1.150` converts to exactly the evo-x2 recipient already in `.sops.yaml` (validates the known_hosts→ssh-to-age pipeline); `192.168.1.151` → `age1q95uejqxe9zmtphjl58ra3wa6dl5sp8jq3h3whs6jwr5zg4v652s84c4kg` — **candidate** rpi3-dns key, MUST be verified on the Pi before use (known_hosts could be stale or that IP could be another host).
6. **SystemNix wiring landed (committed by the daemon):**
   - `modules/nixos/services/sops-recipient-audit.nix` — NEW guard module: parses `.sops.yaml` creation_rules (anchors + first-match-wins semantics), scans every `platforms/nixos/secrets/*.yaml` recipient list at eval time, asserts exact expected-set coverage (missing = host can't decrypt until activation; stale = rotated key keeps decrypt rights; no-rule files flagged; unparseable regex → guard goes inert rather than false-positives; unresolved anchors flagged separately). Options `sopsYaml`/`secretsDir` are documented test-injection points.
   - `tests/fixtures/sops-recipients/` — 6-fixture corpus (two-forms recipient syntax, missing/stale/unmatched/happy shapes).
   - `tests/test-sops-recipient-audit.nix` — 5-case negative test incl. a real-repo-drift case (CI-forced live enforcement).
   - `tests/default.nix` — test registered.
   - `systems/rpi3-dns.nix` — now imports BOTH `sops-key-audit` and `sops-recipient-audit` (closes Gap 3; the Pi's eval now runs the guards).

## b) PARTIALLY DONE

- **The guard module debugs but does not EVAL yet.** Fixed en route: (1) rewrote bare module into the required `{ flake.nixosModules.<name> = …; }` wrapper after catching the module-shape-lint requirement (the documented 2026-08-31 silent-contribution class); (2) replaced PCRE `\S` with POSIX `[[:space:]]` classes for Nix's regex engine.
- **Bisection state:** variant A (assertions = `[]`) evals clean → options layer is good. Variant B (unresolvedAnchorAssertions only) and C (file checks only) both fail with `error: cannot coerce the built-in function 'head' to a string: «primop head»` → the defect lives in the shared parse/resolution pipeline (anchors | foldState | rawRules | resolvedRules), root cause NOT yet identified. B's error text was counted-not-printed (see d-3) and must be re-read unmasked before further guessing.
- **Known logic bug (found via fixture probe, fix NOT yet applied):** the `      - age:` YAML line inside `key_groups` matches the bare `- <token>` ref pattern, so `age:` enters the rule's recipient set — every real file would false-positive as "missing recipient age:" once eval passes. Fix: only accept refs shaped `*anchor` or `age1…`; ignore all other bare list items.

## c) NOT STARTED

- AGENTS.md updates: eval-time guard table row (recipient drift), "Sops + Age" section (updatekeys doctrine + the new guard).
- TODO_LIST.md entries: rpi3 recipient-completion runbook (verify-on-Pi one-liner, `sops updatekeys` commands, creation-rule flip order) and the 3-2-1 host-key backup item (P0).
- `.sops.yaml` comment refresh pointing at the candidate recipient + runbook.
- Formatting pass (alejandra) on the new files; `module-shape-lint` check run; `sops-key-audit` test regression run; full `nix flake check`.
- `rpi3-dns` toplevel/assertions eval verification with the new imports.
- The nixpkgs `crush: 0.92.0 -> 0.94.2` PR itself (case fully built, execution awaits the word — needs fork push, local build, `Assisted-by:` trailer per policy).
- Unresolved-anchor fixture case in the negative test.

## d) TOTALLY FUCKED UP (own goals this session)

1. **`nix flake check` on SystemNix master is RED right now.** I registered the failing test into `tests/default.nix` BEFORE the module evaluated clean, and the auto-commit daemon has already committed the whole set (`ff8d8926`, `0bb85c6e`). Fail-closed beats silent, and nothing deploys through a red gate — but I left master red mid-debug. Interim option if a deploy is needed before the fix: comment the one `tests/default.nix` line, restore after.
2. **Wrote ~200 lines of parsing Nix and went straight to full-eval instead of probing stages against the fixture first.** The probe that exposed the `age:` bug took 30 seconds — after the fact.
3. **Committed the exact pipeline-masking sin AGENTS.md warns about:** bisected variant B with `grep -cE "^error"` — counted the error instead of READING it, so B's real error text is still unknown.
4. First module draft violated module-shape-lint (caught pre-lint, but only by luck of reading flake.nix comments late) and used PCRE-isms — both desk-checkable beforehand.
5. Registered the test + rpi3 imports in the same working set as the unproven module instead of landing the module green first, then wiring.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

- **Probe-before-wiring for pure-eval guards:** any new eval-time scan should have its parse stages verified against fixtures (one `nix eval --file` probe per stage) BEFORE registration in the shared gate.
- **Never land a red check to make a point:** register the test in the same commit that first evals green; until then keep it un-registered.
- **Bisect discipline:** print full error text every step; counters hide the message (the repo's own AGENTS lesson, violated within the hour).
- **Read the lints first:** module-shape-lint's requirement is one grep away and codifies a real past incident.
- **Cross-host guard parity:** evo-x2 auto-discovers modules, rpi3-dns lists them by hand — consider a flake check asserting every NixOS host imports the audit modules (the Gap-3 class can silently regress).

## f) NEXT UP TO 50 (rough order)

1. Print variant B's full error text (no filters) — identify where «primop head» becomes a value.
2. Deeper bisect: force-print `anchors` / `foldState.rules` / `resolvedRules` via a debug assertion or nix repl against the fixture.
3. Fix the `age:` ref-pollution (accept only `*anchor` / `age1…` refs).
4. Re-run `nix build .#checks.x86_64-linux.sops-recipient-audit` to green.
5. Run `checks.x86_64-linux.module-shape-lint` + `checks.x86_64-linux.sops-key-audit` (regression).
6. Full `nix flake check` (or `--no-build`) — confirm repo-wide green again.
7. Verify `nixosConfigurations.rpi3-dns` evals with both new audit imports (and its assertions pass).
8. alejandra-format the new/edited files; confirm no unrelated reformat.
9. Add the unresolved-anchor fixture case to the negative test.
10. Update AGENTS.md guard table (eval-time row: add recipient-drift class + file).
11. Update AGENTS.md "Sops + Age" section: updatekeys doctrine, guard reference, candidate-key caveat.
12. TODO_LIST.md: rpi3 recipient-completion runbook entry (verify candidate on-Pi → add key to `.sops.yaml` → `sops updatekeys` the 3 rpi3 files → flip creation rule → guard enforces).
13. TODO_LIST.md: P0 3-2-1 host-key backup entry (ADR-004 mandate, 6 months overdue).
14. Refresh `.sops.yaml` rpi3 comment with the candidate recipient + runbook pointer.
15. USER (on-Pi, 30s): `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` — confirm/deny `age1q95uej…`.
16. USER (sudo, in-session): the `sops updatekeys` one-liners for dns-failover.yaml + dnsblockd-certs.yaml + dnsblockd-auth.yaml.
17. Consider a per-file recipient design: second creation_rule for the rpi3-consumed trio only (blast-radius: Pi key should NOT decrypt github/hermes/bank secrets).
18. Consider extending the audit: warn when a rule has zero age recipients (pgp-only/inert).
19. Consider a host-imports-the-audits assertion (Gap-3 regression guard).
20. nixpkgs PR (if green-lit): fork, branch `crush-0.94.2`, version+hashes+`buildGo127Module`, local `nix-build -A crush`, `nixpkgs-review`, commit with `Assisted-by: Crush <glm-5.3>` trailer + PR-body disclosure.
21. Post-PR: watch ofborg, respond to review, `backport` labels only if maintainers ask.
22. Long-term: revisit whether Charm-NUR freshness + a source-built nixpkgs fallback can coexist (overlay fallback when NUR lags).
23. Sweep: are there OTHER hosts (zfs-vm) importing `nixosModules.sops` without the audits? (zfs-vm had no sops imports found this session — verify intentionally.)
24. Long-term: revisit ADR-004 "no rotation" — the stale-recipient half of the new guard makes rotation enforcement cheap now.

## g) QUESTIONS (cannot resolve myself)

1. **Is `192.168.1.151` actually rpi3-dns?** SSH is banned in my sessions, so the candidate recipient is unverified. On-Pi one-liner decides: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub` (compare to `age1q95uejqxe9zmtphjl58ra3wa6dl5sp8jq3h3whs6jwr5zg4v652s84c4kg`).
2. **Green-light the nixpkgs PR?** It needs a push to your GitHub fork + local nixpkgs build time; policy-wise it ships with `Assisted-by:` disclosure. Purely altruistic (your fleet runs Charm NUR).
3. **3-2-1 backup destination for the evo-x2 host key** (ADR-004 names USB + Backblaze B2/S3, none implemented): which target do you want, and do you want the backup job engineered in SystemNix or handled manually?

---

**Bottom line:** analysis phase delivered (nixpkgs PR case built; three real SOPS gaps found, one already closed by wiring); the systematic fix for the recipient-coverage class is mid-debug with a red gate on master — root cause narrowed to the parse pipeline, two own-goal process lessons recorded, next actions ordered.
