# Gateway-Deploy Night: Completion Session — Status & Self-Review

**Date:** 2026-11-07 06:35 CET · **Instance:** crush-deploy-completion-20261107
**Trigger:** owner's 22:49 deploy (`nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`) aborted float-RED; session tasked to complete it end-to-end.
**Session window:** ~23:15 → 06:35 CET (~7 h20 m, most of it waiting/gating).

## 0. One-paragraph verdict

The deploy **is DONE and anchored**: generation system-985 (`n2kjvp2mpb…`) switched at 04:55→06:00, `/run/current-system` verified equal to the newest `system-N-link`, post-deploy battery 163 PASS / 7 FAIL / 15 WARN / 1 STORM-SUSPECT / exit 3 on exactly one NEW regression (SearXNG, root-caused to the **rpi3 outage**, not to the deploy). It took **six deploy attempts**; the four mid-series blockers (pre-vacuum evidence gate, doc-counts drift on TWO surfaces, buildcache-reaper race) were each fixed at root, two of them with repo changes (`30168ee8a` reaper hardening; README/FEATURES re-stamps). The night's biggest finding is operational, not build-related: **rpi3 (.151) is physically down, keepalived handed .53 to evo-x2, and the gateway lie now serves the whole LAN** — SSH-by-name refuses (documented ADR-0011 consequence) and SearXNG is functionally dead until rpi3 returns or engines are allowlisted. That state is documented and queued; it needs an owner decision.

## a) FULLY DONE (implemented + verified)

1. **Diagnosed the original float-RED correctly and attributed the fix surfaces** — kith-crm vendored the pre-regen docserver + missing `MaxOpenConns` (crm pin b57a94c vs go-cqrs-lite 8500f81), cqrs-lint/meta/papdashboard stale shims, quotaboard upstream vendor/go.mod contradiction; verified every got-hash's embedded rev against the current lock per the 2026-11-06 misattributed-hash rule (all three matched).
2. **Verified the sibling pin-wave's completion before acting on it** — read its four proof logs (22:51→23:07), confirmed the final one GREEN (rc=0) at the then-current tree, confirmed its crm-repo close-out commit, confirmed registry↔lock consistency; did NOT redo its work and did NOT race it (two quiescence poll rounds, ~30 min).
3. **Pre-flight load proof** — `nix build toplevel --dry-run` proved the post-green-proof tail was 22 light assembly drvs (no FODs, no compilations), which is what made deploying during a PSI storm defensible at all; repeated the full `--keep-going` prebuild at the settled tree (04:18, rc=0) so the eventual deploy's build phase was instant.
4. **Build-storm attribution per the runbook** — identified the CV golangci-lint/go-build fleet as the 84-90% PSI writer at 00:0x, followed the agent menu (measure/attribute/report/recommend, no PID touching), ran a 40-min PSI drain watch, re-attributed at cap, and fired the deploy only after devices showed the storm had actually broken (nvme1n1 0 ms/s io-tick).
5. **Exit-129 triage without damage** — verified NO switch processes survived, `/run/current-system` still pointed at the old generation, gen-984 unchanged: proved the SIGHUP killed nh BEFORE stc ran, i.e. zero half-activated state; the anchor discipline held by default and the retry path stayed inside `nix run .#deploy` (no manual activation).
6. **§15 pre-vacuum gate unblock, by the book** — pulled boot `6d2a69e4` via `scripts/boot-evidence-pull.sh` (canonical sections, hex-boundary id8), committed it (daemon-swept into 7410fd903, verified intact), gate re-run PASS. The pull double-serves as the evidence record for the **01:06 reboot**: journal cuts mid-write 01:06:21, no shutdown sequence, no in-journal panic lines, 19 s to next boot (too fast for the 90 s watchdogd era — wedge + manual-reset shape).
7. **doc-counts drift fixed on BOTH surfaces** — `vm-top-metrics.nix` (147→148) re-stamped into README (history line + enforcement count) and FEATURES (row + header, 153 files / 5 `_`-helpers re-derived by `find` after an `ls`-glob miscount was caught and corrected); check verified GREEN with clean rc capture.
8. **Reaper race fixed at root** (`30168ee8a`) — all three buildcache reap loops in `scripts/deploy.sh` now WARN-and-continue on partial reap under `set -euo pipefail` (bash -n verified, hook-validated, PATHSPEC-committed); this was the first repo code change of the session and it rode the successful deploy.
9. **The deploy itself + full post-switch verification** — anchor flip observed live, the 65-min switch verified HEALTHY mid-flight (ListJobs tail showed only the 5 heavy oneshots: llama-embeddings backlog, nsfw-classifier GPU load; 212 real systemd events/4 min — not the wedged-stc class), deploy.sh post-switch orchestration completed, §20 CRM OIDC PASS, Quotaboard 200, storage-history fresh, auth gateways healthy.
10. **The exit-3 regression root-caused, not absorbed** — SearXNG zero-results re-probed by hand at 06:1x (NOT stale smoke), chain proven: engines → lie (.200) → splice bot-wall (202s); the designed rpi3-first protection is moot because **rpi3 is down** (ping 100% loss, dig host-unreachable); keepalived failover of .53 to evo-x2 confirmed (0.05 ms = local); `*:53` wildcard bind confirmed by `ss`.
11. **Close-out documented and queued on all required surfaces** — status report `2026-11-07_06-25_gateway-live-rpi3-outage-searxng-capture-status.md`, 4 services.md rows (one ticked with live `ss` evidence, one annotated with the materialized "armed on ?", two new decision rows), 3 TODO_LIST queue one-liners; all committed (aa45f287d + 1dd0130ef).

## b) PARTIALLY DONE

1. **The 01:06 reboot attribution** — evidence pulled and committed, shape inferred (wedge + manual reset, NOT WDT arithmetic, NOT in-journal panic), but the freeze-ledger entry needs the owner's "was that you?" before it can be written into stability.md's freeze family. Half-done by design: the pull is mine, the ruling is not.
2. **rpi3-dns full-toplevel eval (sibling's §b.4 gap)** — I carried it forward, noted it twice, and still never ran it (`nix eval .#nixosConfigurations.rpi3-dns...drvPath`). The rpi3 host being DOWN makes it academic right now, but the gap is real and still open.
3. **The exit-129 root cause** — mitigated (setsid detach, proven effective across three launches) but never attributed: I have no evidence WHO/WHAT sent the SIGHUP at 00:51, and the ghostty-scope-teardown theory was never validated (my own session survived, which argues against it, but I did not dig).
4. **PSI-wait discipline** — the 40-min drain watch had no decision deadline; at cap I re-attributed and proceeded, which worked, but the watch should have had a bounded fallback plan attached from minute one.
5. **§23 gateway leg verification** — the live battery printed "armed on ?" (empty sed extraction), exactly as the sibling's queued row predicted; I annotated their row with the live confirmation but the fixture-test itself (so the leg captures values) is still open.
6. **Commit-message hygiene under daemon races** — three of my intended commits were lost to daemon sweeps (evidence pull, close-out docs ×1) and one was hook-rejected (82-char subject); content all landed, messages are heuristic. The files are committed; the narrative messages are gone. Partially accepted loss, partially my batching habit (see §e).

## c) NOT STARTED (deliberately, with reasons)

1. **Freeze-ledger entry in stability.md** — awaiting the owner ruling (§b.1); writing a freeze number into the family on an unconfirmed shape would be fabricating provenance.
2. **Any gateway configuration change** (engine-domain allowlist, host exemption, off-switch) — the gateway is the owner's explicit feature ("direct directive to execute"); the capture-vs-usability tradeoff while rpi3 is down is an owner decision, queued as `[decision]`, not mine to preempt.
3. **Any rpi3 remediation** — host unreachable (not even ping); nothing remote can fix power/link. Queued `[blocked:user]`.
4. **Upstream filings** — quotaboard's vendor/modules.txt contradiction (0161f38) and the dnsblockd gateway host-capture semantics are upstream-relevant, but verify-before-filing requires source-level diagnosis at upstream tip that I did not do tonight; not queued as done, not filed.
5. **The sibling's uncommitted bench WIP** (`scripts/bench-cold-load.sh` modified, `scripts/test-bench-cold-load.sh` untracked) — theirs, live in the tree while I deployed; touched nothing, per the never-revert-foreign-work rule.

## d) TOTALLY FUCKED UP (honest list)

1. **I deployed twice onto a machine I did not know had REBOOTED.** The box rebooted at 01:06; I discovered this at 02:11 via `journalctl --list-boots` — 80 minutes after launching the setsid retry at 01:15. After an unexplained process death, boot-state/uptime should have been my FIRST probe (one command, 2 seconds). Everything else in the 129 triage was downstream of missing that.
2. **Pipe-masked exit code on the doc-counts verify** — `nix build … | tail; echo $?` captured tail's rc and told me GREEN while the check had FAILED on the FEATURES surface. This is the EXACT trap nix-flakes.md documents ("a `nix build … | tail` chains mask FOD/eval exit codes"), cited in the very doc I had read hours earlier. Cost one full eval cycle. The fix (redirect-to-file-then-grep) was already house doctrine — capture-once — and I still reached for the pipe.
3. **`ls`-glob miscount nearly stamped wrong numbers** — counted 10 `_`-prefixed helpers via `ls modules/nixos/{services,desktop}/_*` (true count: 5, by find). The stamp would have carried "148 modules / N files" with N inconsistent with M+H. Caught only because I applied the quote-scrutiny rule ("would I quote this number?") before writing. One near-miss, no damage — but the rule fired at the LAST possible moment.
4. **A stray `EOF` inside a commit message heredoc** — I wrote heredoc syntax into a plain quoted string in the evidence-pull commit; the message would have shipped with a literal `EOF` line. Not shipped (the daemon won the race and my commit was a no-op), but the bug was real and only luck kept it out of history.
5. **Two full 660-675 s deploy batteries burned on gate failures that have standalone, seconds-to-minutes pre-flights** — §15 pre-vacuum gate and doc-counts are both runnable standalone (`scripts/pre-vacuum-evidence-gate.sh`; `nix build .#checks.x86_64-linux.doc-counts`). Attempt 3 and attempt 4 each died on one of these AFTER ~7 minutes of battery. I pre-probed the toplevel build (the right instinct) but not the known-gate checks (the missing one). Roughly 12 minutes of battery plus a hermes drain each, avoidable.
6. **The 40-minute PSI watch had no decision deadline** — cap reached with "what then?" unplanned; I improvised re-attribution → proceed. It worked, but the plan was luck, not design.
7. **Batched writes invited daemon sweeps** — I wrote the evidence pull and later the close-out docs, then deferred their commits into larger command batches; the daemon swept two of three batches with heuristic messages, destroying my commit narratives (one of which was also malformed, §d.4). House rule is write→commit-immediately with PATHSPEC; I knew it and batched anyway.
8. **Forced the pressure gate blind twice** — attempts 5 and 6 fired `DEPLOY_FORCE_PRESSURE=1` without a fresh PSI sample first (attempts 1-2 taught me to measure; the habit decayed once the force flag existed). The gates measured for me, so no harm landed, but the discipline lapsed exactly when the flag made it optional.

## e) WHAT WE SHOULD IMPROVE (process, not product)

1. **Boot-state probe first after any unexplained process death**: `journalctl --list-boots | tail` + `uptime` costs seconds and would have re-framed the whole 129 investigation. Make it a reflex step in the deploy-triage sequence (candidates for AGENTS.md deploy-anchor section).
2. **Cheap pre-flight of known-gate checks before every battery**: a tiny `deploy preflight` app (or a documented one-liner) running the standalone gates — pre-vacuum, doc-counts, float drift check — in ~3 minutes so a full battery never dies on a check that could have failed loudly in seconds. Tonight that would have saved two full batteries + two hermes drains.
3. **Write→commit-immediately (PATHSPEC) for every doc/queue artifact** — no batching into later command groups; the daemon races every gap (two tonight).
4. **setsid-detach as the default for ALL long background jobs** on this box after one confirmed SIGHUP loss; the pattern (file-redirected, no inherited stdio) worked flawlessly across three launches.
5. **PSI watches get a decision deadline and a parallel attribution stream** — a cap without a fallback plan is just a slower way to improvise.
6. **Housekeeping steps in deploy.sh should be non-fatal by design** — tonight's reaper fix is one instance; audit the other `set -e`-adjacent steps (DMS backup, failed-unit resets, provisioner restarts) for the same transient-race-fatal pattern.
7. **Doc-counts surfaced a NEW module only at deploy preflight** — a module-creation checklist leg (or a flake-part that diffs `nixosModules` count at `git add` time via the pre-commit hook) would catch re-stamp debt before it reaches a battery.
8. **Verify-before-stamping on all counts** (the `find`-vs-`ls` catch) — every number in a stamp gets one known-value cross-check through a different tool; tonight it fired exactly once and earned its keep.
9. **Status-report pre-read worked** — the session's early greps of docs/status + the sibling's 23:28 report prevented re-diagnosis and a second twin-executor collision; keep feeding that loop (this report is the input to the next session's grep).

## f) NEXT (up to 50, ordered roughly by impact)

**rpi3 / gateway capture cluster (live incident):**
1. [blocked:user] rpi3 (.151) physical triage — power/link/service (the LAN lie persists until this returns).
2. [decision] SearXNG: allowlist engine domains in dnsblockd vs accept the outage until rpi3 returns (row live).
3. [decision] Host-protection design gap: gateway captures the HOST when rpi3 is down — upstream self-exemption vs 9.9.9.9-first order vs allowlist floor for the box's by-name deps.
4. [ready] Verify gateway capture is actually RECORDING (journal.db growth in /var/lib/dnsblockd) — §23 proves armed, nothing proves capture works.
5. [ready] SigNoz/Gatus signal: `gateway_armed AND rpi3-resolver-dead` = degraded posture — tonight's 3+ h unnoticed state must page.
6. [ready] LAN impact audit while capture is live: which household by-name flows break (printers, NAS, consoles, IoT) — splice covers HTTPS only.
7. [ready] Off-switch drill dry-run: `POST /api/gateway/off` + re-arm — the runbook's escape hatch has never been exercised live.
8. [ready] git-by-name stopgap for this box until rpi3 returns (extraHosts github.com via a config knob — owner call on mechanism).
9. [ready] keepalived/.53 failover semantics section for docs/services/dnsblockd.md (who holds .53, what answers it, what the lie means LAN-wide).
10. [ready] QUIC bypass verification (ADR-0011: QUIC never spliced) — confirm LAN QUIC leaks past capture as documented, note in runbook.
11. [decision] dnsblockd journal.db retention/rotation — capture storage growth monitoring before it becomes the next space incident.
12. [ready] Annotate docs/services/dnsblockd.md with tonight's live learnings (wildcard :53 verified; splice pass-through confirmed; armed-on-? leg caveat; rpi3-down host-capture behavior).
13. [ready] Tick the runbook drill legs that tonight's live state already answers (§b.2 :53 wildcard → verified).
14. [ready] rpi3-dns full-toplevel eval (sibling §b.4, carried twice, still open — do it before rpi3's next deploy).
15. [ready] rpi3 return checklist: re-verify asymmetry pin live (loopback-first on rpi3), confirm .53 handback, confirm lie disappears LAN-wide.

**Deploy pipeline (this session's fixes + follow-throughs):**
16. [ready] Cheap pre-flight app/doc for known-gate checks (pre-vacuum standalone + doc-counts + float drift) before any battery — §e.2.
17. [ready] Audit deploy.sh for other transient-race-fatal steps under `set -euo pipefail` (DMS backup, provisioner restarts, unit resets) — same WARN-not-die pattern.
18. [ready] Attribute the 00:51 exit-129 (journal trace of the deploy process-tree kill; ghostty scope churn timing) — the mitigation shipped, the cause is still unknown.
19. [owner] Freeze-ledger ruling for boot 6d2a69e4 (wedge+manual-reset vs crash; evidence committed) → then the stability.md family entry.
20. [ready] Re-run the post-deploy battery now that the storm broke — clear the 1 STORM-SUSPECT downgrade and re-baseline the 7 FAILs against a calm box.
21. [ready] Profile the 660-675 s battery under PSI (which § legs are slow: §19 decrypt smoke, §11 FOD preview) — cache-able or parallelizable legs.
22. [ready] Add a module-creation re-stamp catch earlier in the pipeline (pre-commit leg or flake-part diffing the nixosModules count at stage time) — §e.7.
23. [ready] Verify the sibling's final quotaboard float (579af78) has a registered green proof (my 04:18 prebuild proved the tree; the registry ceremony may have been skipped — check lockfloat logs vs final registry state).
24. [ready] Push hygiene: confirm lock-referenced revs (quotaboard 579af78, crm 0ce5ecc) are on their origins (eval worked tonight, so they are — but the +1-ahead hints from float-register suggest local-only commits above them; flag for the owning sessions).
25. [ready] CHANGELOG entry for generation 985 (the night's wave: crm OIDC, gateway live, quotaboard, vm-top-metrics, doc re-stamps, reaper fix).

**SearXNG:**
26. [decision→ready after #2] Engine set review: which engines CAN function through the splice (bot-wall 202s) even with an allowlist — possibly none; document the honest ceiling.
27. [ready] Make the SearXNG smoke leg diagnose the lie condition explicitly (resolve an engine domain in the leg; FAIL with "engines lied to .200" instead of "no results").

**Failed units / mount debt (pre-deploy §6 + §18, re-surfaced tonight):**
28. [blocked:user] `home-lars-tmp.mount` + `home-lars-.cache-golangci-lint.mount/automount` FAILED — wave-6 hot-tier subvols still missing; run the prepare steps (needs sudo ticket).
29. [ready] Triage the failed-unit baseline: forgejo-github-sync, ci-watchdog, github-auto-assign — failed before AND after the switch; are these known-dead or new?
30. [ready] Run `nix-build-cleanup.service` (8 stale sandboxes flagged by §8 — the deploy itself suggested it).
31. [decision] Root pool 100 % chunk-allocated (722.5/722.5 GiB, 90 % df) — the churn engine behind tonight's PSI floor; a filtered balance is the heavy fix (owner timing; storm-amplifier if run wrong).
32. [ready] Journal vacuum clock 7.8 G/8 G — after the freeze-ledger ruling on 6d2a69e4, decide SystemMaxUse bump vs a pre-emptive vacuum window (the next boot is one boot away from erasure).
33. [ready] btrbk-data /data EIO P0 (T04-T08) — the tripwire failed again tonight by design; the underlying repair is still the real fix (pre-existing row, re-surfaced).

**CRM / cv (the wave this deploy carried):**
34. [ready] CRM by-phone T03 battery post-deploy (crm 0ce5ecc is live; §20 OIDC PASS is the boot-level check, the poller battery is the real acceptance).
35. [ready] Verify the ADDED cv-credentials-store.yaml provisioned correctly live (§smoke covered CV /health + /export/pdf; the store boot path itself is unverified live).
36. [ready] Confirm crm-server restarted cleanly post OIDC-env converge (the post-switch log restarted it at 06:02; check journal for a clean bind + Pocket-ID reachability).

**Docs/bookkeeping:**
37. [ready] Link tonight's report from the dnsblockd runbook's gateway section (it now owns live-behavior facts the runbook should cite).
38. [ready] Retire/annotate the sibling's "deploy prep proven" crm-repo note with the actual deploy result (their TODO entry says "remaining: the OWNER switch" — done at 06:00; both surfaces need the tick).
39. [ready] Harvest this report's §d/§e lessons per the memory rules (AGENTS.md deploy-anchor section: boot-probe-first; pipeline: preflight-before-battery).
40. [ready] The 22:49 float-RED roots file doctrine held (per-log roots extraction) — no fix needed; cite it as the working example in the pipeline doc if not already cited.

**Smaller / hygiene:**
41. [ready] `scripts/bench-cold-load.sh` (modified) + `scripts/test-bench-cold-load.sh` (untracked) — sibling WIP sitting in the tree through two deploys; coordinate landing or park it (owner/sibling call).
42. [ready] The 10 h+ tailwindcss watcher in the owner session — stale-dev-process note; kill only on owner say-so.
43. [ready] golangci-lint-langserver fleet (5+ instances) — harmless idle, but worth a known-process list so storm attribution stops re-triaging them.
44. [ready] AGENTS.md candidate: "after unexplained process death, list-boots first" — one line in the deploy-anchor discipline.
45. [ready] AGENTS.md candidate: "preflight the standalone gates before a battery" — one line beside the --keep-going rule.
46. [decision] SystemMaxUse bump (8 G → 10 G?) as the durable vacuum-clock fix vs keeping 8 G and pulling boots faster — owner cost/benefit.
47. [ready] Verify LAN clients' DHCP still targets .53 (now evo-x2) and capture is actually engaging for them (the whole point of the feature — currently inferred, not observed).
48. [ready] The deploy-log retention saw 5 logs tonight (30-day policy fine) — no action; note that `/var/log/systemnix-deploys/` + lockfloat logs were THE decisive evidence chain tonight (keep both).

49. [decision] Whether deploy attempts should auto-run the standalone gates as phases 0 (my §e.2) — if yes, this supersedes rows 16/22 as one mechanism.
50. [ready] Close-the-loop on tonight's two upstream candidates (quotaboard vendor sync at tip; dnsblockd host-capture semantics) — source-diagnose at upstream tip, then file or document as deliberate non-fix per the buildflow §7 gate.

## g) QUESTIONS (cannot answer myself)

1. **Did you hard-reset/reboot the box at 01:06 tonight?** The boot evidence shows a wedge-shaped cut (no shutdown sequence, no panic, 19 s gap) — I cannot distinguish your manual reset from an unattended crash, and the freeze-ledger entry (or its absence) hinges entirely on your answer.
2. **With rpi3 down, do you want LAN-wide gateway capture to STAY live (current state), or should I exercise the off-switch / prepare the engine-domain allowlist now?** The capture is your feature and SSH-by-name + SearXNG are its current casualties; the tradeoff call is yours.
3. **Whose is the uncommitted bench WIP in the tree** (`scripts/bench-cold-load.sh` modified, `scripts/test-bench-cold-load.sh` untracked, plus the CV golangci-lint fleet that was storming at midnight)? If it is your live work I leave it untouched; if it is an abandoned sibling session, I need to know before coordinating or parking it.
