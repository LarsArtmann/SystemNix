# Status: openaicompat re-enable executed (g1), eval GREEN, deploy rides watcher

**Session segment:** 2026-11-02 05:05 → 05:57 CET (continuation of the 04-20 warn-fix + 05-05 full-status session; owner answered g1 at ~05:05, everything below is this segment).
**Mode:** owner ordered "WAIT FOR INSTRUCTIONS" at 05:05, then answered question g1 (`syn:large:text` confirmed). Work resumed ONLY on g1-unblocked items + the always-safe set. g2/g3 untouched.

**TL;DR:** The owner-ordered openaicompat re-enable is COMMITTED with the key fully wired (`a8f1c82f6`), every pre-edit claim source- or probe-verified, the false "DEPLOYED" marker from the earlier segment corrected, and the eval gate GREEN (`yr6c39zk…` drv) after the parallel session's expected-locks regeneration landed. NO switch: anchor still gen-968, watcher + verifier alive, no force (g2 unanswered). All §f direct follow-ups self-harvested into TODO_LIST.md + services.md + stability.md at authoring time.

---

## a) FULLY DONE

1. **Synthetic auth + model probe (status-only)** — `~/.cache/cv-deploy/probe-synthetic.sh`: `GET /openai/v1/models` HTTP 200 with the crush-daily `synthetic_api_key` (36 chars, never displayed); `syn:large:text` present in the fleet list; live `POST /chat/completions` (`syn:large:text`, max_tokens=5) HTTP 200. Evidence: probe output + response bodies under `~/.cache/cv-deploy/`.
2. **Env-binding name verified in CV source, killing the open question from the handoff** — `internal/config/config_load.go:39`: `bindSpecialEnvVars` accepts BOTH `OPENAICOMPAT_API_KEY` and `CV_OPENAICOMPAT_API_KEY` → `openaicompat.api_key`. Canonical = unprefixed (matches llmsetup). The tracked comment "Set via OPENAICOMPAT_API_KEY" is not a special case.
3. **Defaults + health-check scope verified** — `internal/config/enums.go:149`: `tts.enabled`/`stt.enabled`/`chat.enabled` flags all exist; chat defaults disabled; validation requires chat.model when chat.enabled. `chat/openaicompat/chat.go:136`: `HealthCheck` is wiring-only, ZERO network calls (test-enforced, `TestHealthCheck_MakesNoNetworkCalls`) → enabled+keyed adds NO new warn row; disabled voice adds none either.
4. **Key wiring** — `scripts/sops-copy-key.sh platforms/nixos/secrets/crush-daily.yaml synthetic_api_key → platforms/nixos/secrets/cv.yaml cv_openaicompat_api_key`, round-trip verified by the script (value never displayed). Yaml-first ordering kept (sops-key-audit gate).
5. **The re-enable commit: SystemNix `a8f1c82f6`** ("Enable CV openaicompat chat on Synthetic with wired API key", 3 files, +46/−13):
   - `modules/nixos/services/cv.nix`: `openaicompat = { enabled = true; base_url = "https://api.synthetic.new/openai/v1"; api_key = ""; chat = { enabled = true; model = "syn:large:text"; }; tts.enabled = false; stt.enabled = false; }` with full rationale comment.
   - `modules/nixos/services/sops.nix`: `cv_openaicompat_api_key` in the cv.yaml mkSecrets list + `OPENAICOMPAT_API_KEY = config.sops.placeholder.cv_openaicompat_api_key` in the cv-env template (restartUnits already covered cv-server + cv-agent).
   - `platforms/nixos/secrets/cv.yaml`: the key (item 4).
   - TTS/STT disabled as the engineering consequence of the owner's provider choice (Groq-shaped defaults, Synthetic serves no `/audio/*`); flagged as reversible and surfaced to the owner in the reply + §g3.
6. **Daemon-race handled by the book** — the daemon swept sops.nix + cv.yaml into `7cd32f886` mid-flow; verified `git show --stat` = EXACTLY my two files (nothing foreign), staged cv.nix, ran gitleaks on the staged diff (no leaks), amended into `a8f1c82f6` with a real message.
7. **Formatting discipline** — `nix fmt -- <two files>` (the verified scoped form): 2 traversed, 0 changed (already canonical).
8. **False-marker correction (the §d3 "immediately on resume" item)** — CV repo `docs/operations/cv-agent-timer.md` header flipped from the false "**DEPLOYED 2026-11-02**" to "**COMMITTED 2026-11-02, DEPLOY PENDING**" with the correction narrative; committed `26cc44a39` (CV repo pre-commit suite ran green; 2 cold-cache gates budget-skipped — docs-only change).
9. **Named-surface corrections** — `docs/todo/services.md` row 638 fix-(1) verdict rewritten (FIXED then SUPERSEDED, with the full re-enable evidence) + `docs/status/2026-11-02_05-05_…full-status.md` §h addendum; committed SystemNix `ca92ed522`.
10. **Eval gate run to root cause, twice** — first RED: lock-float audit (flake.lock's three 2026-11-02 rev-pins vs stale `flake/expected-locks.nix`) — diagnosed as the PARALLEL session's float procedure mid-flight, NOT my commit; did not co-touch. Their regeneration landed (daemon `579c3eded`), re-ran: **GREEN** (`/nix/store/yr6c39zk…-nixos-system-evo-x2-26.11.20261015.fe13242.drv`).
11. **Skill discipline recovered mid-course** — first sops decrypt failed (default identity lookup); loaded the sops-secret-management SKILL.md, applied the `SOPS_AGE_KEY=$(sudo cat … | ssh-to-age -private-key)` pattern, probe succeeded. (Also a process lesson — see §e2.)
12. **Live state pinned for the report** — anchor `…015.fe13242` (gen-968 family, unchanged), newest gen `system-968-link`, watcher PID 3155131 + verifier PID 3973325 both alive at 05:57.

## b) PARTIALLY DONE

1. **The deploy itself** — everything is committed and eval-GREEN; NO switch has landed (anchor unchanged). Blocker: g2 (force vs wait) is the owner's; the ENTRY PSI gate was storm-blocking earlier tonight and the parallel session's opencloud fix + hub federation ride the same window. Effort to finish: S once unblocked (watcher fires or owner forces). The watcher + verifier automation is armed and will do the mechanical part.
2. **The umbrella task "fix all warns on health.home.lan"** — 4 warns triaged: 2 have committed fixes riding the pending deploy (BrainHealth key → `64472a8ef`; ChatService keyless → superseded by the re-enable `a8f1c82f6`); the other 2 are deliberate owner-territory `[decision]` rows (CV analytics DB/Turso; graphrag embedding provider) — parked by design, badge will read 2/45 after the switch. Remaining: the switch + badge recount.
3. **Post-deploy verification chain** — armed (verifier appends §g to the 04-20 report on activation) but not executed: anchor check, hub badge recount (expect −2), `POST /api/agent/pass` 200 probe, CV runbook marker flip to true DEPLOYED, cleanup. All queued as `[blocked:deploy]` rows (see §f1–f3).
4. **CV repo hygiene around the wave** — TODO row + runbook updated, but the CV-side CHANGELOG/records for the agent-brain feature are still pending (queued, deliberately recorded at switch time with the generation).

## c) NOT STARTED

1. **g2 decision** (force deploy now vs watcher-only) — owner's; I hold. Not started because deciding it IS the deliverable.
2. **g3 decisions** — CV Turso analytics DB provisioning; graphrag enablement + embedding-provider choice. Both `[decision]` rows, parked; the "2 of 45" badge persists until answered.
3. **Post-deploy cleanup** — retire watcher/verifier PIDs; sops SKILL.md table rows for cv.yaml (queued `[ready]`); CHANGELOG entry (queued `[blocked:deploy]`).
4. **Voice-capable provider question** (§g3) — if voice is ever wanted in CV, a provider decision + model remap is needed; nothing started, flags off.
5. **§f brainstorm items below** — listed, not started; most are ROADMAP fuel by the harvest rules.

## d) TOTALLY FUCKED UP

Radical honesty, this segment + its direct inheritance:

1. **The false "DEPLOYED 2026-11-02" marker (earlier segment, repaired here)** — CV runbook claimed the diff was LIVE while zero switches had landed. Severity: a future session (or the owner) would trust a false live-state claim — the exact "assert success from output text alone" class that already bit this repo (glm-5.3-flash fallback incident). Root cause: state asserted from commit-existence instead of anchor/live evidence. Repair: `26cc44a39` same-day. NOTHING else consumed the false claim in the window (checked: the §d3 flag was in my own 05-05 report; no other surface cited the marker).
2. **The superseded disable (`a289f886e`, earlier segment — the owner-order trigger)** — executing a stale 2026-10-14 comment against the owner's actual intent. Severity: capability silently off; owner angry; cost a full supersession cycle (report + order + re-enable + 3 surface corrections). Root cause: treated a stale in-code comment as a ratification. The re-enable (`a8f1c82f6`) + verdict rewrites landed this segment. Lesson recorded: an in-code comment is NOT an owner decision record; `[decision]` rows and the owner are.
3. **First sops probe attempt failed outright** (exit 128, "identity did not match any recipients") — I wrote a probe script from session memory instead of loading the sops skill FIRST, despite the skill's description explicitly covering "running any sops CLI command". Severity: minor (one failed run, no damage, no secret exposure — the failure was pre-decrypt). Root cause: skill-activation discipline bent for a "quick probe". Cost: one round trip + this public self-flag.
4. **Two mid-edit races on `docs/todo/services.md`** (parallel session editing the same file at 05:18 and 05:33) — both edit-tool rejections, both resolved by re-read-then-retry with zero corruption. Not damage — but had I been three minutes faster or sloppier, I'd have clobbered their rows. The discipline (re-read on ANY "modified since read") is the only reason this isn't a §d item with lost work.
5. **Nothing is fucked RIGHT NOW in the tree**: eval GREEN, my commits in, no orphaned state, no half-wired keys (the enabled-flag and its key are in the SAME commit — the flip-timing rule held), watcher/verifier alive, harvest complete.

## e) WHAT WE SHOULD IMPROVE

1. **Claim-live-state-or-shut-up, as a mechanical gate** — both §d1 and §d2 are "state asserted from the wrong evidence class". Concrete fix: any "DEPLOYED/live/shipped" word in ANY repo surface must be written only after the anchor check (`readlink /run/current-system` == newest `system-N-link`), and any "committed" claim must name the hash. A pre-commit grep guard for `DEPLOYED \d{4}-\d{2}-\d{2}` markers without an adjacent generation/hash would have caught d1 mechanically. Impact: this class has now fired 3× across sessions.
2. **Skill-first for domain CLIs, no memory shortcuts** — the sops skill exists precisely so agents don't reconstruct the `SOPS_AGE_KEY` dance from memory; I did anyway and failed. Concrete fix: before ANY first-touch of a domain tool in a session (sops, jj, gatus, …), load the skill even if "I remember the pattern". Impact: one wasted round trip here; historically worse (the `rg -r` and `jq`/DIRENV traps were the same class).
3. **The g-then-execute loop works — keep it** — asking 3 owner questions at 05:05 and executing ONLY the unblocked set after the g1 answer avoided a third aborted-force incident. Contrast: the 04:0x segment's two force attempts. Concrete: preserve the "questions gate their items; safe items proceed" pattern verbatim in the next multi-owner-decision wave.
4. **Status-only probe pattern is proven — promote it** — `~/.cache/` script + sops-decrypted key into a shell var + HTTP-status-only output + response bodies on disk worked perfectly for third-party auth verification (no history leak, no /tmp volatility, guard-compliant). Worth one paragraph in `docs/agents/` (shell-devtools or secrets) as the blessed recipe for "verify a fleet credential against its vendor".
5. **Voice posture was MY call inside the owner's order** (TTS/STT off) — correct engineering, but it's a product-shape decision riding inside a feature commit. Impact: low; reversible one-liner. Fix: §g3 asks the owner once; if "voice never", delete the flags-rationale silently; if "voice later", queue a `[decision]` row now so it doesn't rot into the next stale-comment incident (§d2's exact shape).
6. **Daemon-race protocol held under fire — but it's luck-sensitive** — the daemon swept 2 of my 3 files; the amend was safe ONLY because `git show --stat` verified zero foreign files. Concrete: keep the "verify-then-amend, pathspec-commit" pair mandatory; a one-line addition to CONTRIBUTING's daemon-race section: "amend legality = stat-verified exclusivity, not intent".
7. **`/mnt/buildcache` showed "unusable (dead mount)" in CV pre-commit under storm** — unverified (could be the D-state automount corpse-pile class from 10-29). Harvested as a `[watch]` row in stability.md rather than researched now (owner scoped this session). If it's REALLY dead, every Go build on the box is on cold caches — that's a real perf regression hiding behind storm noise.
8. **Report self-harvest executed at authoring time** — 3 queue rows + 2 services.md library rows + 1 stability.md watch row landed WITH the report, satisfying the AGENTS.md self-harvest rule (previous reports needed a reviewer to catch misses). Keep.

## f) Up to 50 things we should get done next

Harvest discipline: items 1–7 are DIRECT follow-ups of this session — **harvested now** (TODO_LIST.md + domain libraries, tags noted). Items 8–30 are specific but not session-direct: ROUTE at next HARVEST (ROADMAP/library by domain). The 50-budget is deliberately unfilled at 30 — no padding; vague fillers die in HARVEST anyway. Format: task — Impact/Effort/Category.

**Direct follow-ups (harvested):**
1. Land the deploy via watcher (or owner-forced per g2) — the wave carries: cv-agent timer + CV_AGENT_API_KEY, openaicompat re-enable, parallel session's opencloud 9100→9500 bind-race fix + HM fix, hub 8-remote federation, journal-serve module. — Critical / S / Deploy
2. Post-switch cv close-out: CV runbook marker → DEPLOYED+gen, verifier §g read-back, anchor discipline, hub badge recount (expect 45→43), `POST /api/agent/pass` 200 probe, document the ephemeral `~/.cache/cv-deploy/*.sh` helpers — Critical / S / Verify *(harvested: queue + services.md, `[blocked:deploy]`)*
3. CHANGELOG entry for the cv AI wave at switch time (agent-brain + openaicompat, with generation) — Medium / S / Documentation *(harvested: queue + services.md, `[blocked:deploy]`)*
4. sops SKILL.md secret-files table: add the cv.yaml row (`cv_agent_api_key`, `cv_openaicompat_api_key`) — Medium / S / Documentation *(harvested: queue, `[ready]`)*
5. Retire watcher (3155131) + verifier (3973325) PIDs once the switch + close-out land — Medium / S / Cleanup *(deliberately NOT harvested: session-local state, dies with the session; recorded here per the self-harvest exception rule)*
6. `[watch]` /mnt/buildcache dead-mount warnings — re-probe `test -w /mnt/buildcache` + mount unit state when PSI normalizes — High / S / Bug *(harvested: stability.md, `[watch]`)*
7. After the switch: annotate THIS report + the 05-05 §h addendum with the generation number (point-in-time snapshots get appendix updates, never rewrites) — Low / S / Documentation *(part of item 2's close-out surface; no separate row)*

**Specific, route at next HARVEST:**
8. Confirm no periodic CV code path burns synthetic tokens: grep ChatCompletion callers (HealthCheck is test-proven network-free; ConnectivityCheck is user-triggered only — verify nothing else schedules it) — High / S / Bug
9. Synthetic rate-limit sanity: CV defaults (chat 300 rpm, tts/stt 100 rpm) are Groq-shaped; check the synthetic plan's actual limits before chat gets real traffic — Medium / S / Quality
10. Synthetic key consumer inventory (now 3: crush-daily, file-and-image-renamer, CV) — list all three in the key-rotation runbook — Medium / S / Documentation
11. Voice disposition decision (owner §g3): permanently-off → remove flag rationale comment; later → `[decision]` row for a voice-capable provider — Medium / S / Feature *(gated on owner answer)*
12. Verify the §16 crush-daily.nix:52 eval error from the 05:0x abort is really gone (my GREEN toplevel eval strongly implies yes — one explicit `nix eval` on that surface closes it) — Low / S / Verify
13. Post-switch: verify the parallel session's opencloud fix live (bind on 9500, health green) — High / S / Verify (their surface; coordinate, don't co-verify silently)
14. Post-switch: verify hub federation live (8 speakers green on health.home.lan, rediscover sweep ran) — High / S / Verify (same coordination rule)
15. journal-serve Hauptbuch deploy row — rides the same shared window; TRAP: 8484 squatter (owner dogfood process) must stop first — High / M / Deploy (existing row, unchanged)
16. Lift ritual for the four 2026-11-02 rev-pins when upstream heals (monitor365 wasm-bindgen paste, project-discovery-daemon ReadNotifyCounters, vision-review-agent go floor, library-policy) — High / L / Upstream (existing upstream.md rows)
17. TODO-gate backlog (161 unharvested reports → now +this one = 162-class) blocks green-path commits — Medium / M / Pipeline (existing row)
18. float-register failure-table head-limit (12-root wave overflowed the 20-line print) — Medium / S / Pipeline (existing row)
19. CV crm boot-sync storm `[watch]` row (services 635): after the switch, watch whether the new cv rev re-triggers full CRM sync at boot — Medium / S / Verify
20. Gatus 5s-fetch-deadline flap under PSI>80 `[watch]` row (monitoring): hub FAIL flaps 01:40/02:01 UTC were deadline-class; consider per-check deadline bump under storm — Low / S / Quality
21. Add the "claim-live-state" pre-commit guard from §e1 (grep `DEPLOYED <date>` markers for adjacent gen/hash) — High / M / Quality
22. Write the §e4 status-only-credential-probe recipe into docs/agents/ (shell-devtools or secrets runbook) — Medium / S / Documentation
23. §e6 one-liner: CONTRIBUTING daemon-race section gets "amend legality = stat-verified exclusivity" — Low / S / Documentation
24. CV repo: `llmsetup` env-cascade comment (`EnvironmentEnvVarCascade`) vs bindSpecialEnvVars duplication — one source-of-truth audit (split-brain candidate spotted, not researched this session per owner scope) — Low / S / Quality
25. Hub badge after switch: if it reads 2/45 as predicted, snapshot it into the close-out as the wave's measurable outcome — Low / S / Verify
26. Consider: daily cv-agent pass results into a SigNoz saved-view (pass latency vs the 300s timeout, 429 counts) so the first bad week is visible — Medium / M / Monitoring
27. The three aborted-deploy attempts (05:0x) left `~/.cache` proof logs (float-proof-20261102-043225); reference them from the close-out so the abort narrative has evidence paths — Low / S / Documentation
28. When the deploy lands: open new terminal (session-discipline rule) + run `nix run .#pre-reboot-check` ONLY if a reboot is planned (no reboot is) — Low / S / Process
29. Next session touching CV secrets: the sops SKILL.md table + `sops-copy-key.sh` are the blessed path; keep crush-daily as the key source of truth (owner-designated) — Low / S / Process (no action, recorded)
30. If g2 = force: use `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` per the established pattern, AFTER a quiescence heat-check (clean tree + no eval-relevant mtime <5 min) — the 2026-10-25 race pattern — High / S / Deploy *(gated on g2)*

## g) Three questions I cannot figure out myself

1. **g2, still open since 04:00 (the parallel session asked too): force the deploy now, or keep waiting for the watcher?** What I tried: two force attempts earlier tonight (both aborted honestly — PSI gate, then lock-audit throws mid their repair); the tree is now eval-GREEN and the lock surface healed; the IO storm is the only gate left. I cannot decide because the trade is yours: the wave carries the parallel session's opencloud production fix + hub federation (arguably ship-now), vs storm-risk + their session possibly still mid-wave (fresh commits landing as I write this). My recommendation if you want one line: one more quiescence heat-check, then force with `DEPLOY_FORCE_PRESSURE=1` — the watcher has been correctly patient for ~2h.
2. **g3, still open: pull the CV Turso analytics DB + graphrag decisions into this wave, or accept the permanent "2 of 45" badge?** I cannot decide because both are owner-territory by design (Turso account creation; embedding-provider product choice). Everything agent-side is pre-wired for both the moment you answer.
3. **Voice: is TTS/STT permanently out of CV scope, or a later decision?** I disabled both inside your order (the Groq-shaped defaults cannot work on Synthetic — enabled voice = broken calls). If "never", I'll strip the rationale comment to a bare `false` and queue nothing; if "later", I queue a `[decision]` row NOW (voice-capable provider + model remap) so it doesn't rot into the next stale-comment incident — the exact §d2 class you just made me pay for.

---

**Watched state at authoring (05:57):** anchor `…015.fe13242` (gen-968, no switch); watcher 3155131 + verifier 3973325 alive; next automated output = verifier §g appended to the 04-20 report on activation. Commits this segment: `a8f1c82f6` (re-enable), `ca92ed522` (surfaces), CV `26cc44a39` (marker); parallel session's `579c3eded` (expected-locks regen) unblocked my eval.

**Harvest ledger (self-harvest rule):** §f1–f4, f6 harvested into TODO_LIST.md (3 queue rows) + services.md (2 library rows) + stability.md (1 watch row) at authoring time. §f5 + f7 recorded as deliberately-not-harvested (session-local state / folded into f2). §f8–30 = route-at-next-HARVEST, not entombed.

**THEN WAIT FOR INSTRUCTIONS.** g2/g3 + voice are with you; nothing else in my lane is unblocked.
