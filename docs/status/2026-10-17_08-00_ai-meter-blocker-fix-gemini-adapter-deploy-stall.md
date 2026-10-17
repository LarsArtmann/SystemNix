# ai-meter Blocker Fix + Gemini Native Adapter + Deploy Stall — Session Status

**Session:** 2026-10-17 00:20 → 08:00 (resumed from docs/status/2026-10-17_00-17_ai-meter-build-session-status.html)
**Author:** Crush agent session (glm-5.3-flash)
**Tree state at close:** all my work committed (daemon commits through 2685f780); deploy NOT executed — blocked by a live parallel session's moving flake.lock, not by ai-meter.

---

## Executive summary

The ai-meter build's single open bug (daemon cannot read runtime-minted client keys) is FIXED and VM-proven 7/7 subtests. On owner answers (Q1 two-copy mint, Q2 single deploy, Q3 gemini now) I additionally VERIFIED gemini's protocol (crush speaks google-genai NATIVE, not OpenAI-compat — probe evidence below) and BUILT+TESTED a native-genai adapter in the proxy, wired crush's gemini provider through it. The deploy itself fired 6 times and never completed: one real IO storm (your btrbk-root run), one phantom-metric gate (parallel session's signoz metric — loaned per protocol), one upstream build break (art-dupl `*_templ.go` vs `templ generate`), and a 14-FOD vendorHash fleet wave caused by a parallel session's lock bumps that is STILL MOVING as of 07:22 (last lock touch 07:14). Everything I own is green; the deploy is the only remaining step and needs a quiet tree.

---

## a) FULLY DONE (this session, all verified)

1. **Two-copy mint** (modules/nixos/services/ai-meter.nix): consumer copies stay user-owned 0400; daemon reads ai-meter-owned 0400 mirrors at `/run/ai-meter-keys/config/<name>`; `install` re-syncs every mint run so the pair can never diverge. VM asserts root/nobody consumer chowns, `root:ai-meter 750` config dir, mirror ownership, and byte-equality.
2. **Capability fix for the mint oneshot**: `harden{}`'s empty `CapabilityBoundingSet` made every chown-to-non-root EPERM — masked until now because the VM's only client was root (chown-to-root is a kernel no-op). Granted exactly `CAP_CHOWN` + `CAP_DAC_OVERRIDE` + `CAP_FOWNER` (install runs chown before fchmod; consumer loop chmods after chown). Documented in-unit.
3. **ai-meter-vm 7/7 subtests green** (key mint incl. non-root path, daemon boots both ports, 401, 404, 502+metered, ledger, exposition) — rebuilt green again after the gemini adapter and again on the post-02:55 lock.
4. **Gemini protocol verdict (probe, throwaway XDG crushrc + logging listener)**: crush v0.98.1's `gemini` provider = google-genai-sdk NATIVE even with custom `--base-url`: `POST {base}/v1beta/models/<model>:streamGenerateContent?alt=sse`, `X-Goog-Api-Key` auth, genai bodies. A blind extraRc override would have 401'd and metered nothing. Recorded in docs/todo/ai-stack.md + runbook.
5. **Native-genai adapter** (pkgs/ai-meter/genai.go + proxy.go/usage.go/config.go changes): X-Goog-Api-Key client-auth channel (constant-time), per-upstream `auth_style = "x-goog-api-key"`, model-from-URL metering, `usageMetadata` extraction (thoughtsTokenCount folds into completion), include_usage injection exempt for genai, and — latent general bug fixed by the same work — **query strings were previously dropped on ALL upstream requests** (`?alt=sse` is mandatory for native streaming). Tests: genai_test.go unit + e2e vs a fake native upstream (auth header shape, no Bearer leak, body untouched, query preserved, cost math). `buildflow -s test-race` and `-s golangci-lint` green.
6. **Module + wiring**: gemini upstream → bare host + auth_style; home.nix extraRc now overrides zai + kimi-coding + gemini; runbook + todo rows updated with probe evidence; ai-stack gemini row rewritten (verification DONE, adapter LANDED, remaining = live smoke + cost entries).
7. **Cross-session eval break fixed (root cause)**: new display-manager-heal.nix (parallel session, 00:56) gated on phantom `services.display-manager` option — broke EVERY evo-x2 eval once daemon-committed (your 01:26 `nh os switch` failure). Now gates on the real `services.display-manager-config.enable`. Eval green same minute.
8. **Phantom-metric gate unblocked per designed protocol**: `signoz_logs_pipeline_stale` (parallel session's new emission in the already-deployed signoz-coverage collector) registered in `KNOWN_NEW_METRICS` with dated comment — the version-skew class the manual loan exists for; self-cleaning nag will retire it.
9. **art-dupl build break root-caused + shimmed**: locked fork rev commits a hand-written `actionability_templ.go`; upstream preBuild's bare `templ generate` claims the `*_templ.go` namespace → clean build loses `isTemplChildrenIdiom`. SystemNix-side postPatch rename shim (semantics-identical), builds green first-hand. Upstream fix (rename + push) stays an owner action.
10. **FOD fleet re-pin (14 surfaces, first-hand got-hashes)**: buildflow ×2 surfaces, golangci-lint-auto-configure, library-policy, mr-sync ×2, project-meta, projects-management-automation ×2, tq, kith-crm, cv, inboxclean, overview, signoz-frontend-pnpm — one atomic sweep, zero stale values remaining. NOTE: measured under the 06:19 graph; the 07:14 lock move likely re-stales some again (see d).
11. **Heavy-gate diagnosis**: the running system still carries the removed nix heavy-gate; its kill signature is **exit 1, empty stdout+stderr** — it silently broke pre-deploy §13's eval (fixed by `export NIX_HEAVY_GATE_FORCE=1`; battery then 100/0).
12. Owner Q1–Q3 answered and implemented (Q3's "wire gemini now" became the adapter after verification refuted the cheap path).

## b) PARTIALLY DONE

1. **The deploy** — fired 6×: blocked successively by btrbk IO storm (real), phantom-metric gate (fixed), art-dupl compile (fixed), cqrs-lint+go-humanize+12 more FOD mismatches (fixed), then the lock moved again at 06:35/07:14 under me (tq shim measured on the old graph already re-staled once). Quiescence watcher ran 45 min: tree never quiet (nix procs + lock touches throughout 02:55–07:14). NOT deployed; nothing activated; running system untouched.
2. **Post-deploy verification chain** — defined, not runnable: anchor check, key mint live, /health :8107/:8108, ai_meter_* in ClickHouse, gatus green, crush/paperless-gpt/inboxclean smokes.
3. **Gemini live routing** — adapter+wiring complete; crushrc declares zero gemini models, so nothing routes until one is `model add`-ed (cost entries deliberately absent — no invented prices).

## c) NOT STARTED

1. hermes wiring through the proxy (needs hermes-repo change — queued row).
2. SigNoz ai-meter dashboard + spend alert (queued row; one query per panel, pre-verified PromQL).
3. Live smokes for paperless-gpt (doc tagging) and inboxclean (chat turn) — owner-in-the-loop surfaces.
4. gemini cost-table entries (blocked on model declaration).
5. Ledger rotation/growth policy for /var/lib/ai-meter/usage.jsonl.

## d) TOTALLY FUCKED UP (honest ledger)

1. **~3h of passive PSI polling before forensics.** The stability docs describe per-cgroup/per-process IO attribution; I ran 50+ minutes of blind waiting (0:39–2:27) before asking WHO was generating IO. The btrbk answer took one `pgrep`.
2. **Wrong "same drv path" reasoning twice on art-dupl** — the drv DID change with the lock (ldflags embedded the new rev); I chased a phantom eval-cache theory instead of reading `nix derivation show` first. The derivation dump solved it in one step.
3. **`rg -rn` flag slip** — `-r` is rg's `--replace`; my "metric produced nowhere" display was self-corrupted output. Caught on the next command, but on a grep-output-forensics session that's embarrassing.
4. **Considered rewriting the metrics-gate scanner before reading it** — the designed KNOWN_NEW_METRICS loan already covered the class. Read-the-code-first would have saved a design detour.
5. **python3-heredoc edit for the tq shim** after two edit-tool mtime races — the previous session's own handoff warned exactly this. Should have re-read + edit tool.
6. **DEPLOY_FORCE_PRESSURE=1 used on my own verification** (disks 3%, zero D-state, no corpse, mem PSI 0.1% — the gate's own verify-then-force instruction). Defensible, but a safety-gate override at night without your ratification deserves the flag; Q1 below.
7. **The 14-hash sweep has a shelf life** — measured on the 06:19 graph; the 07:14 lock move likely re-stales several (tq already re-mismatched once mid-sweep). Deploying the sweep as-is may need one more enumeration pass in the quiet window. I knew the lock was live and swept anyway — the alternative (wait) was also wrong; the miss was not re-enumerating immediately before the final build.
8. **display-manager-heal.nix edited mid-flight of another session** — necessary (it broke everyone's eval) and minimal (two references), but their intent for the gate condition is unverified. Flagged for follow-up, not silently assumed done.

## e) WHAT WE SHOULD IMPROVE (systemic, observed tonight)

1. **Pre-deploy §13 (and §14) cannot distinguish a heavy-gate silent kill from a real eval error** — empty-stderr exit-1 was classified "NOT the known disabled shape" and blocked deploys. Classify the shim-kill signature explicitly.
2. **The IO PSI gate's phantom branch false-positives on zram steady-state** — 50% io PSI with idle disks, zero D-state, 13 zram IO/s is this box's NORMAL multi-session state; the gate treats it as corpse-pile. Needs the same verify-the-phantom step it already demands, automated.
3. **The vendorHash treadmill has no mechanical guard** — every root-nixpkgs move re-stales ~14 FODs and the fix is manual got-hash archaeology at 06:00. Candidate: a `nix-hash-fix` sweep command that enumerates keep-going mismatches and rewrites shim values in one pass (the repo lore references nix-hash-fix; it exists as protocol, not as tooling here).
4. **Deploy-time ownership of a shared moving tree is undefined** — two sessions both ready to deploy, one moving the lock every 20 min. Cheap fix: a deploy-intent lockfile (whoever holds it owns the window; the daemon already serializes commits).
5. **KNOWN_NEW_METRICS auto-loan gap**: a metric newly emitted by an ALREADY-DEPLOYED collector (no gatus-config delta) can't be auto-loaned — tonight needed the manual entry. The static tree scan (credit `# HELP <m>` in modules/) I sketched would close the class; fixture-test it first.
6. **Upstream hygiene (art-dupl)**: hand-written files in templ's generated namespace (`*_templ.go`) break every clean build. A repo lint (forbid non-generated `*_templ.go`) prevents the class.
7. **flake pin-consistency preflight FAIL (20 inputs) has been red all night** in every buildflow run — visible, ignored. Either fix or downgrade it; a permanently red gate trains blindness.

## f) NEXT (prioritized, ~50)

**Deploy chain (the moment the tree is quiet):**
1. Re-enumerate `nix build toplevel --keep-going` under the CURRENT lock; one final mismatch sweep if the 07:14 move re-staled shims.
2. `export DEPLOY_FORCE_PRESSURE=1 NIX_HEAVY_GATE_FORCE=1; nix run .#deploy` (both documented bypasses; §13 needs the gate var).
3. Anchor verify: `readlink /run/current-system` == newest system-N-link; repair per the exit-14 protocol if not.
4. Live keys: `/run/ai-meter-keys/{crush,paperless-gpt*,inboxclean*}` + `config/` mirrors, ownership/modes.
5. `:8107/health` + `:8108/health` + `:8108/metrics` families present.
6. `journalctl -u ai-meter -u ai-meter-keys` clean start, no restart loops.
7. Crush smoke: NEW shell (fresh crushrc), `crush run -m zai/glm-5.3-flash "Reply OK"` → `ai_meter_requests_total{client="crush",upstream="zai"...}` + tokens + ledger line.
8. paperless-gpt: unit env shows OPENAI_BASE_URL→/v1/fastflowlm + key env file loaded; tag one doc.
9. inboxclean: unit restarted with base URL + env; one chat turn.
10. Gatus "ai-meter" + "ai-meter metrics" green within 2 intervals.
11. SigNoz: `ai_meter_*` series in ClickHouse via the ai-meter scrape job.
12. Retire `signoz_logs_pipeline_stale` from KNOWN_NEW_METRICS once its textfile shows it.

**Gemini follow-through:**
13. `model add` a gemini model in crushrc (owner choice which) → live native smoke through /v1/gemini.
14. Add gemini per-model cost entries from Google's pricing page when 13 lands.
15. Optional VM leg for the native path (Go e2e already covers; only if the module wiring deserves its own test).

**Shim retirement (each per the standing drop protocol):**
16–27. Retire the 2026-10-17 fleet re-pins as upstreams bake hashes: buildflow ×2, golangci-lint-auto-configure, library-policy, mr-sync ×2, project-meta, projects-management-automation ×2, tq, kith-crm, cv, inboxclean, overview, signoz-pnpm (14 surfaces).
28. Drop the art-dupl postPatch rename once upstream renames + pushes (owner action — Q2).

**Cross-session / repo health:**
29. Verify display-manager-heal gate intent with its authoring session.
30. Identify the 02:55/06:35/07:14 lock-bumping session's goal; confirm it's converged before anyone deploys.
31. Investigate the 5 pre-existing failed units seen in §6 (clickhouse-db-backup, forgejo-github-sync, geometrikks-log-pull-pbx, inboxclean-sync, service-health-check).
32. The `flake.nix/flake.lock disagree on 20 inputs` preflight FAIL — reconcile or downgrade.
33. `--update-input` deprecation → new `nix flake update` syntax sweep.
34. AGENTS.md: two-copy mint + capability doctrine + genai adapter lore (one paragraph each).
35. docs/gotchas-archive.md: (a) heavy-gate silent-kill signature (exit 1, empty stderr, NIX_HEAVY_GATE_FORCE=1), (b) `*_templ.go` vs `templ generate` naming trap, (c) chown-to-root no-op masking empty CapabilityBoundingSet.
36. docs/agents/nix-flakes.md: 2026-10-17 fleet-wave entry.
37. CHANGELOG entry (ai-meter go-live prep + heal-module fix + shims).
38. TODO_LIST.md + ai-stack.md blocker rows: close with evidence AFTER deploy (surfaces: queue + library + this report's follow-ups self-harvest — this report deliberately leaves them open until the deploy evidence exists).

**ai-meter hardening/next features:**
39. hermes wiring (repo change + clients.hermes entry).
40. SigNoz dashboard (one query per panel, PromQL pre-verified).
41. Monthly-spend alert rule.
42. Ledger rotation policy (usage.jsonl grows unbounded).
43. Latency-overhead bench (TTFT through proxy vs direct).
44. MemoryMax 256M observation under real crush load.
45. openrouter upstream: unused — keep or drop decision.
46. llama-embeddings route: embeddings metering sanity check.
47. X-Session-* header passthrough: harmless today; consider stripping client-identifying headers at the proxy.
48. Go 1.26+ modernizer hints from gopls (strings.Cut, SplitSeq, max) — cosmetic, next touch.

**Pipeline/systemic:**
49. Implement the §13/§14 shim-kill classification (e).
50. Deploy-intent lockfile convention for shared-tree deploys (e.4).

## g) QUESTIONS (cannot resolve myself)

1. **Ratify the pressure-gate override?** I used `DEPLOY_FORCE_PRESSURE=1` on verified evidence (disks idle, zero D-state, no corpse, mem PSI ~0.1% — pure zram steady-state). OK to keep deploying through the phantom-PSI state when the disk crosscheck is clean, or do you want deploys held for true PSI<20 regardless?
2. **art-dupl upstream push:** the real fix is renaming `printer/actionability/actionability_templ.go` in the art-dupl repo and pushing to `fork` (drops my SystemNix shim). I don't push without your explicit OK — say the word and I'll do the rename + push + re-lock + shim-drop as one cycle.
3. **The parallel session** (stalwart wiring, input bumps, lock moves 02:55–07:14): do you know if it's converged? Should I take the next quiet window and deploy everything (its work rides along, evals+checks green), or do you want to drive that deploy yourself?

---

**Awaiting instructions.** The watcher confirmed the tree was still active at 07:22; nothing further will be executed until you answer.
