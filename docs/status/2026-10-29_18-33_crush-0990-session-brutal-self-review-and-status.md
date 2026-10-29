# Status Report + Brutal Self-Review — crush v0.99.0 adoption session (float staged, hooks landed, deploy blocked)

**Session window:** 2026-10-29 ~17:45 – 18:32 CET
**Author:** Crush agent session (SystemNix, branch `media-atlas-hub-service`)
**Scope:** triggered by the charmbracelet/crush v0.99.0 release + "what can we improve / deep brainstorm", then a catwalk-endpoint decision question, then this self-review. Covers ONLY this session's work.

**Final state at writing:**
- SystemNix: nur float (crush 0.99.0) committed in lock+registry; flake check green; evo-x2 still RUNNING 0.98.2 — deploy blocked on upstream roots.
- crush-config (private sibling repo) master @ `822f897` + `fcf4516`: three hook-layer improvements + fixture checks, full flake check green — **not yet floated into SystemNix's lock**.
- evo-x2 toplevel build: blocked by `kith-crm@c3ed35c2` + `cv@fc0506b` upstream vendorHash mismatches (owner in-flight, other machine).

---

## a) FULLY DONE

1. **v0.99.0 research, source-verified** — release notes, Catwalk v3 provider types, full hooks contract (`docs/hooks/README.md` at the tag): events, control fields, stdin payloads, exit codes. Key contract finding: `context`/`updated_output` work ONLY on tool events — killed my PostCompact-context idea before building it (verify-before-build held).
2. **crush 0.99.0 package built + sandbox-verified** — `qzsgp0f9…-crush-0.99.0`; `--version`, `hook add PostToolUse/PostToolUseFailure` validity (events map in `internal/hooks/events.go`), legacy `--can-reason` acceptance (`internal/shellconfig/model.go:105`), provider `--type` free-string. Sandbox HOME — live config untouched.
3. **NUR float staged** — `nix flake update nur` → 23e5769 (NUR master carries 0.99.0); lock + `flake/expected-locks.nix` pair committed; lock-float gate eval green (drvPath probe); `nix flake check --no-build` green.
4. **rg-replace-guard FP fix** (crush-config `hooks/rg-replace-guard.sh`) — replace-flag detection window-scoped to the rg invocation's own argument segment; quote-boundary widening also closed a pre-existing blind spot (`bash -c 'rg -rn x'` escaped detection before). Live-validated: the session's own first blocked command was exactly this FP.
5. **redact-argv-output hook** (PostToolUse) — pgrep/ps/ss tool output redacted via `updated_output` before the model sees it; conservative SystemNix redact-argv sed pair; self-muting on non-probe/clean; defensive `unset DIRENV_DIFF`; jq stdin-forms only.
6. **bash-trap-remediation hook** (PostToolUseFailure) — known-fix context injection for the direnv-jq, mvdan/sh kill-builtin (incl. `kill -0`), and journalctl `-b` short-boot-id traps. Silent on unrelated failures.
7. **Fixture matrices + checks** — 3 new test scripts (24 assertions), new `hook-fixtures` check, `scripts-verify` extended (hooks existence + bash -n), render assertions (event/matcher/name/timeout + removal when `redactArgvHook`/`trapRemediationHook` false). Full crush-config `nix flake check` green; treefmt clean.
8. **Pre-existing doc-counts failure fixed on sight** — README stamp 250→251 (the parallel session's `nsfw-classifier-provider` endpoint), history note appended.
9. **Status report + queue harvest** — `docs/status/2026-10-29_18-30_crush-0990-adoption-hooks-and-staged-float.md` + `docs/todo/pipeline.md` `[blocked:deploy]` finish-line row; row amended this pass (media-atlas root note).
10. **Catwalk decision question answered** (no implementation, correctly): catwalk = model-metadata catalog, one `GET /v3/providers` ETag endpoint; `CATWALK_URL`/`provider-auto-update`/`update-providers` mechanisms verified in source; estate verified override-free; recommendation = don't run one, keep two cheap levers; Agent-Router-verdict lineage applied.
11. **Proper commits under daemon races** — daemon swept my in-flight files twice; verified swept contents both times (`git show --stat`), amended HEAD into a real message only when it carried exclusively my files; pathspec discipline held; never touched the parallel session's nsfw-classifier/journal/lars-packages changes.

## b) PARTIALLY DONE

1. **The 0.99.0 rollout itself** — binary + config both landed in their repos, but NOT deployed: evo-x2 still runs 0.98.2. Blocked by kith-crm/cv upstream vendorHash (see d).
2. **crush-config float** — deliberately not floated into SystemNix's lock (float-register gate demands a green toplevel proof; committing an unproven float is banned). The finish line is queued, not lost.
3. **Flag migration (`--can-reason`→`--thinking`, explicit Catwalk types)** — feasibility verified, deliberately deferred until post-deploy live parity check (glm-5.3-flash is the 2026-08-31 regression class; churn only with evidence).
4. **llamacpp `--type llamacpp` on 0.99.0** — inferred valid (free-string `--type` + #4137 fix touching llama.cpp), not live-verified against a running server.
5. **Root enumeration of the 18:00 proof** — kith-crm/cv verified-constant; media-atlas-key-provision failed at 18:00 but rebuilds green standalone at 18:32 (parallel-session-resolved or transient) — noted in the queue row, re-verify at next proof. Not fully attributed (see d.4).

## c) NOT STARTED (deliberate or queued)

1. Post-deploy verification battery (§4 of the 18:30 report): version, anchor, provider/model parity incl. glm-5.3-flash xhigh, live hook-fire (pgrep REDACT + jq DIRENV_DIFF context), llamacpp discovery on 8899, crush-daily schema compat.
2. TurnEnd/StopFailure observe hooks → tq-agent-pool provider-error telemetry (gatus/SigNoz). Roadmap-class; requires deployed 0.99.0.
3. `crush serve` persistent-pool architecture spike; `CRUSH_PERMISSIONS_PIPED` for a crush-debug host UI. Roadmap.
4. Upstream filing: PostCompact/SessionStart context-injection support (observe-only today). Needs verify-before-filing protocol first.
5. Catwalk levers (`option provider-auto-update false` / self-hosted `/v3/providers`) — parked by decision, nothing landed.
6. crush-config AGENTS.md update documenting the hook layer + fixture pattern (forgot during execution — listed in e).

## d) TOTALLY FUCKED UP (honest ledger — all caught same-session, none shipped broken)

1. **Pipeline-masking rc prints (twice):** `nix flake check | tail; echo rc=$?` printed the rc of `tail`, not the check — I printed "check rc=0" while the check had FAILED (doc-counts error in the same output!). Caught only because I read the error text. This is exactly the repo's documented pipeline-masking class; I walked into it live.
2. **multiedit misattribution → duplicated block:** "Applied 2 of 3" — I assumed the wrong edit had failed, re-applied it, and duplicated a 19-line assertion block in crush-config's flake.nix. Found via duplicate-grep during verification, deduped.
3. **Two syntax/logic fumbles in Nix edits:** lost `];` semicolon on hookLines close (caught by eval); first rcText-gating attempt used the pipe-operator experimental syntax in a module (over-clever; rewritten to plain optionals).
4. **Incomplete root attribution in the shipped queue row:** the first pipeline.md row named only kith-crm/cv as proof roots; the 18:00 log actually had media-atlas-key-provision as a third failing drv. Caught during THIS self-review's accuracy pass; row amended. (Root cause: I extracted "roots" from the wrong log — my rg globbed all proof logs and the output I eyeballed was the 11:44 run's.)
5. **Self-inflicted guard blocks (2):** one genuine `rg -rn` typo (guard earned), one commit blocked because the heredoc message quoted `rg -rn`-shaped prose (guard by design scans raw command text). Worked around by rewording; design note filed in e.
6. **Fixture self-contradiction:** first test-redact-argv-output "keep" case asserted output-presence for clean input, which the hook correctly answers with silence. Fixture design error, fixed.

## e) WHAT WE SHOULD IMPROVE (session-derived)

1. **rc-reporting hygiene:** never `cmd | tail; echo rc=$?` — use `PIPESTATUS[0]`, `set -o pipefail`, or run unpiped. Twice this session. Candidate for references/lessons.md (cross-project) via crush-config repo commit.
2. **Log-attribution discipline:** when aggregating failure roots across timestamped logs, scope every extraction to ONE named log file (globbed rg mixed 11:44 output into my 18:00 analysis). The "would I quote this number in a report?" sanity check exists; extend it to "would I quote this log line — from WHICH file?"
3. **Guard ergonomics:** the rg-replace-guard denies quoted prose (commit messages, heredocs) containing trap shapes. Options: document `ALLOW_RG_REPLACE=1` prefix for prose-bearing commits, or teach the guard to skip single-quoted/heredoc regions (harder, riskier). Low priority — the trap it guards is real (I typo'd `rg -rn` THIS session).
4. **crush-config AGENTS.md:** document the PostToolUse hook layer, the fixture-matrix pattern, and the "hooks inherit crush env ⇒ unset DIRENV_DIFF + jq stdin-forms" rule for future hook authors.
5. **float-register could record a roots-extraction summary file** next to the proof log (named per-run), so post-hoc root attribution never mixes runs — mechanical, matches the script's existing log discipline.
6. **Hook robustness follow-ups:** redact hook on multi-MB outputs (early-exit above a size cap?); trap-remediation's jq signature could first capture DIRENV_DIFF presence BEFORE unsetting it, narrowing to the real direnv class.
7. **kith-crm has no local clone** while SystemNix pins it — consider cloning it (owner call; the tq pool repos list may want it) so vendorHash incidents are diagnosable without remote round-trips.

## f) Next things (grouped, ≤50; [r]=[ready] once unblocked, [o]=owner, [R]=roadmap)

Rollout finish line:
1. [o] Fix kith-crm@c3ed35c2 go-modules vendorHash upstream (got-hash evidence in proof log: `sha256-LpMsryrv…`) and push.
2. [o] Fix cv@fc0506b go-modules vendorHash upstream (got: `sha256-fyOA12V…`) and push.
3. [r] Re-run `scripts/float-register.sh` after roots clear (watch media-atlas-key-provision + journal FOD for recurrence).
4. [r] `nix flake update crush-config` in SystemNix (picks up 822f897+), registry row via float ceremony.
5. [r] Deploy via `nix run .#deploy` (quiescence heat-check + green-eval probe + §11 owned by the battery; 2026-10-25 pattern).
6. [r] Post-deploy: `crush --version` = 0.99.0 + `readlink /run/current-system` anchor check.
7. [r] Post-deploy: provider/model parity — zai/gemini/synthetic/minimax(disabled)/llamacpp; **glm-5.3-flash present with xhigh** (assert WHICH entity serves it).
8. [r] Post-deploy: live hook-fire — `pgrep -af` output comes back REDACTED; a failed `jq --version` returns DIRENV_DIFF context.
9. [r] Post-deploy: llamacpp discovery against a live 8899 llama-server (double-/v1 fix effect).
10. [r] Post-deploy: crush-daily still parses sessions DB (Catwalk v3 storage migration risk).
11. [r] Post-deploy: `crush provider add --help` — confirm `llamacpp` type still canonical vs `completions`.
12. [r] Post-deploy: tq-agent-pool sanity (one dispatch through 0.99.0 — tool-failure resilience should show).
13. [r] Optional polish: migrate glm-5.3-flash declaration to `--thinking toggleable` + `--max-attachments`, update render fixtures — only after 7 is green.

Hardening + docs:
14. [r] crush-config AGENTS.md: hook layer + fixture pattern + DIRENV_DIFF rule (e.4).
15. [r] references/lessons.md (crush-config repo, committed): pipeline-masking rc print + log-attribution lessons (e.1/e.2).
16. [r] redact-argv-output: size cap / early-exit for huge outputs (e.6).
17. [r] bash-trap-remediation: capture DIRENV_DIFF presence before unset; gate jq-context on it (e.6).
18. [r] Guard prose problem: document ALLOW_RG_REPLACE for prose-bearing commits, or prototype heredoc-region skip behind an option (e.3).
19. [r] float-register: per-run roots-extraction summary file (e.5).
20. [r] Verify daemon commit 2dd4a77ba's expected-locks.nix passed alejandra (scoped `nix fmt -- --fail-on-change` on the file) — daemon commits can skip filetype legs.
21. [r] kith-crm local clone decision (e.7) — also check tq pool `repos` list coverage.

Telemetry + pool (post-0.99.0):
22. [R] StopFailure observe hook → SigNoz rule + gatus endpoint for provider errors during pool runs.
23. [R] TurnEnd hook → per-turn ai-meter attribution join (session→repo→cost).
24. [R] `crush serve` persistent pool spike (SIGHUP reload + graceful shutdown make it viable) — decision doc first.
25. [R] `CRUSH_PERMISSIONS_PIPED=1` crush-debug host-UI experiment.
26. [R] PermissionRequest/Result hooks → permission-decision audit log (who approved what).

Catwalk (parked by decision, revisit on triggers):
27. [R] Land `option provider-auto-update false` in crush-config IF charm-catalog drift bites (trigger b of the decision).
28. [R] Self-hosted `/v3/providers` behind Caddy (charm catalog + glm-5.3-flash overlay, gatus-checked) IF second-host/trigger fires; note CATWALK_URL must ride sessionVariables, NOT crushrc (embedded-shell exports don't reach crush's process env).
29. [R] File upstream: PostCompact/SessionStart context-injection support request — via verify-before-filing + github-voice.

Housekeeping:
30. [r] Amend the 18:30 report's §3 root list with the media-atlas-key-provision note (report is point-in-time; ANNOTATE-style appendix only).
31. [R] Consider `crush update-providers` cron/manual cadence if auto-update ever disabled (27's sibling).
32. [r] Clean ~/.cache/crush099 sandbox dirs once 0.99.0 is deployed (cosmetic; they're in the right place per /tmp-volatility rule).

## g) Questions I cannot answer myself

1. **kith-crm/cv upstream state:** both pinned revs are absent from local clones (in-flight from another machine). Should the next session prepare local vendorHash-fix commits in those repos for YOU to push, or is another machine mid-flight on exactly that? (I can't see the other machine's state, and agents never push.)
2. **Deploy authority on this branch:** when roots clear, should the 0.99.0 + hooks generation deploy immediately on `media-atlas-hub-service` (it's your active branch), or wait for its merge? (Your call on branch/deploy coupling; both are queued as one float.)
3. **Catwalk verdict:** accept the "no endpoint, two levers parked" recommendation as final (nothing landed), or do you want the `provider-auto-update false` pin landed NOW as a hermeticity statement? (Preference, not derivable.)

---

**Session honesty note:** nothing in this session shipped broken — every landing was check-green at commit time — but items d.1–d.4 are process failures I committed against the repo's OWN documented lesson classes. The two biggest risks left open: (1) the rollout is staged-not-live, so TODAY's crush sessions still run the old trap-prone 0.98.2 surface the new hooks would mitigate; (2) the blocked finish line depends on upstream work I cannot push.

**WAITING FOR INSTRUCTIONS.**
