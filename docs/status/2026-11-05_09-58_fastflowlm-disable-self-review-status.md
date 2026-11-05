# FastFlowLM disable + 100%-I/O diagnosis — status & brutal self-review

**Scope.** This report covers ONLY this session's work: the live I/O diagnosis (07:2x), the fastflowlm disable + MemoryMax raise in SystemNix (07:3x–09:5x), and its verification battery. VERIFIED live in this session: pidstat/iostat/PSI/cgroup/fd forensics on flm-real; evo-x2 toplevel eval (drvPath green, twice); `nix flake check --no-build` exit 0; three restructured checks BUILT green with skip-line content read from store outputs; treefmt on my 5 nix files (2 changed, derivations byte-identical after — same store paths). NOT VERIFIED: the deploy itself (sudo-gated — not started); post-deploy behavior of ANY kind; the system-health collector's flm metric rows (file not located — see d/e); deploy.sh's flm-guard full condition (reasoned from a partial read); whether the 07:26 deploy carried any of my edits (it evaluated before them — reasoned, not proven from its log).

---

## Self-review (the questions, answered honestly)

**1. What did you forget?**
- **The queue twin.** I resolved the `[decision]` row in `docs/todo/services.md` but missed its TODO_LIST.md:1454 twin — a direct violation of the repo's "queue one-liners and their library entries must not drift — edit both" rule. CAUGHT while writing this report (grep for the twin), fixed at authoring time (both rows now `[x]`).
- **That `systemctl stop fastflowlm` is not containment on this box.** The user's stop (07:2x) left `fastflowlm.socket` accepting; the documented re-arm class fired AGAIN: flm-real was observed RUNNING at 09:56:14 under a new PID (367525), D-state, PSI io 42.6% — the storm is live while I write this. Likely vector: the PMA auto-commit daemon's go-commit LLM calls against the still-listening :52625 — i.e. **my own tree edits, committed by the daemon, re-armed the model I was disabling.** I gave the correct 3-unit stop command in my hand-off but never verified the stop HELD; the deploy is the only real containment and it has not run.
- **The gatus-coverage audit break.** My first disable edit broke evo-x2 eval (PMA's env still names :52625, exemption vanished with the module). I did not predict it — the eval gate caught it. Good gate, sloppy anticipation; the flm module's `allowPorts` was visible in my own first read of the module.

**2. What is something that's stupid that we do anyway?**
- The box runs TWO AI stacks that keep killing it (flm, llama-chat, llama-rag disabled/re-enabled in waves; 48 documented freezes) while a 3rd copy of similar models sits in `/data/ai/models/jan` (114 GB) and a 4th in `image` (259 GB). The disable treats the symptom of the week, not the fleet-level "how many multi-GB cold-load LLMs does one 128 GB box with one shared system disk deserve" question.

**3. What could you have done better?**
- Anticipate dependent surfaces BEFORE the first eval: the gatus-exemption miss and the queue-twin miss were both visible in files I had already read.
- Verify hand-off claims: I wrote "instant relief" for the user's stop without re-checking PSI minutes later — the re-arm proved that claim time-boxed at best.
- Tool hygiene: three edit-before-read rejections (FEATURES.md, selftests.nix, fastflowlm.md), one `rg -rn` hook block, one `rg --include` misuse, one lost `PIPESTATUS` on a backgrounded check. ~6 wasted round-trips; each was avoidable by reading first / knowing the tool.

**4. What could you still improve?**
- The `'''` Nix-closing typo in test-fastflowlm-idle.nix (caught by immediate re-read, never reached an eval — but a syntax slip in a moved string block is exactly where indented-string pitfalls live; the formatter-then-rebuild dance that proved content-identity was the right instinct, keep it).
- Cite line numbers only where stable; my final hand-off cited `fastflowlm.nix:489` for ceilings that had already drifted past my own comment insertion.

**5. Did I lie to you?** No claims were fabricated. Two claims were TIME-BOXED more than stated ("instant relief" — true for minutes, false at 09:56) and one line citation drifted. Both corrected above.

**6. How can we be less stupid?** Deploy the disable; stop hand-stopping socket-activated units (the doctrine is written down and we keep re-learning it); make the PMA daemon's LLM endpoint a config-derived value that fails CLOSED when its target unit is disabled (today it points at a dead port by design).

**7. Ghost systems?** No new ones; found the flm module's `refusalReason` option still SHIPS DARK and undocumented at the host layer (pre-existing; irrelevant while disabled). The `psi-wait-gate` + `post-crash-calm-gate` wave (wired 2026-11-05 by another session) is now partially moot for flm — it gates a backend that will not start; harmless (wait-gates never refuse).

**8. Scope creep?** One instance: raising MemoryHigh alongside MemoryMax was within the ask's spirit (the user said "set the MemoryMax up" — the thrash is driven by `high`, raising only `max` would have been cosmetic). Documented in-module; flagged as an interpretation, not silently done.

**9. Did we remove something useful?** The memory-guard's DEFAULT sacrifice/socket lists now sit EMPTY at the host override — the guard keeps observing but stops nothing. That is the designed observe-only mode, but it means the 2026-08-22-class freeze protection lost its sacrificial lamb. With flm gone the king sacrifice is gone; whether llama-chat/llama-vlm should inherit the role is un-decided (see f).

**10. Split brains created?** One, caught and fixed: the queue/library decision-row drift (§1). A second, smaller one REMAINS by design: PMA's env still advertises an OpenAI endpoint that is dead (configuration.nix comment + runbook + TODO [decision] row all say so — three surfaces telling one truth, but the CONFIG itself still carries the stale value).

**11. Tests?** Strong for what changed: 3 checks restructured to be state-tracking, built green, skip-behavior proven from outputs. Gaps: no NEW test asserts "fastflowlm disabled on evo-x2 renders zero flm units" (my verification was a live one-shot eval, not a pinned check); the memory-guard empty-list mode is fixture-tested only for its own VM world, not for the host override shape.

**12. Inherited claims re-verified?** The claims I leaned on (restore-cap semantics, stc re-arm class, PMA graceful fallback) were taken from repo docs without source-level re-verification — except the re-arm class, which the live 09:56 re-arm empirically re-proved mid-session.

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Root-cause diagnosis of the 100% I/O storm (flm cgroup thrash, not buildflow/pre-deploy-check) | pidstat/iostat/PSI/cgroup/fd forensics, 07:22–07:35; findings baked into configuration.nix evidence ledger |
| `fastflowlm.enable = false` + evidence-ledger comment | configuration.nix; eval green |
| MemoryMax 40G→56G, MemoryHigh 32G→48G + rationale | fastflowlm.nix (the "set the MemoryMax up" ask) |
| memory-guard sacrifice/socket lists → observe-only | configuration.nix; asserted live: `[]`/`[]` |
| gatus-coverage exemption for :52625 (PMA env reference) | configuration.nix; eval gate caught the need |
| 3 eval-dependent surfaces made state-tracking (port-guard legs, idle test, bridge contract) | all three BUILT green; SKIP lines read from store outputs |
| Docs: FEATURES 🔧 DISABLED row, runbook banner, CHANGELOG entry, [decision] resolved (library) | all four surfaces edited |
| Queue-twin drift fix (TODO_LIST.md:1454) | fixed while authoring this report |
| Self-harvest of this report's §f | 2 rows added to docs/todo/services.md (1× [ready], 1× [decision]) |
| Verification battery | toplevel eval ×2 green; flake check --no-build exit 0; buildflow fast run (only pre-existing dprint/lock drift failing); treefmt on my files with content-identity proof |

## b) PARTIALLY DONE

- **The disable is IN TREE, NOT DEPLOYED.** sudo/deploy are outside my shell's permissions. Until `nix run .#deploy` runs, flm keeps re-arming from the still-listening socket (observed 09:56:14, PID 367525, PSI io 42.6%).
- **PMA env re-point**: documented everywhere, value unchanged (no live target exists to point at — llama-chat also dark).
- **Post-disable dead-reference audit**: swept eval-time references fully (all safe), runtime references only partially (gatus: none; system-health collector: file not located; deploy.sh guard: reasoned, not read to the end).

## c) NOT STARTED

- The deploy itself (user-gated; see d for why it is now urgent).
- Post-deploy verification battery (PSI <20, `pidstat -d` quiet, smoke prints `SKIP: FastFlowLM - service disabled`).
- Local-LLM strategy for the now-LLM-less consumer fleet (PMA/paperless/browser-history/ai-meter).
- `/data` → nvme1n1 isolation (structural recommendation from the diagnosis; un-actioned).

## d) TOTALLY FUCKED UP

- **The box is being hammered RIGHT NOW because containment failed twice in one session.** (1) The user's `sudo systemctl stop fastflowlm` left the socket accepting — the documented freeze-#38 class, predictable from the repo's own docs. (2) My hand-off then said "instant relief" without a follow-up check; at 09:56:14 flm re-armed (new PID, D-state, nvme0n1 ~96% util, PSI io 42.6%) — plausibly triggered by the PMA daemon's LLM commit-message calls on my own edits. The durable fix is one deploy away and has not happened. **First action after this report: stop socket+instances+backend (3-unit command), then deploy.**
- In-session (both caught before anything shipped): the `'''` delimiter typo in test-fastflowlm-idle.nix; the initial gatus-exemption miss. The prevention layers (re-read, eval gate) worked as designed.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy discipline for config-disables**: a disable sitting in tree while its unit keeps socket-activating is the worst of both worlds — every daemon LLM call re-pays a 22.6 GB cold load. Disable + deploy should be one motion.
2. **Fail-closed consumer config**: PMA's OPENAI_BASE_URL should derive from the target service's enable state (or a shared `localLlm` option) instead of hardcoding a port that outlives its service.
3. **The eval gate is the hero of this session** — it caught the one real break. Keep refusing to "verify" by reasoning alone.
4. **TODO queue/library twins**: my drift was found by grep-at-authoring-time; the repo's prune script could assert twin-parity on [decision] rows mechanically.
5. **Session hygiene**: read-before-edit consistently; the 6 wasted round-trips were all avoidable.

## f) Next things (session-derived; honest count, not padded to 50)

1. **[owner, NOW]** Stop the re-arm: `sudo systemctl stop fastflowlm.socket 'fastflowlm@*.service' fastflowlm.service`
2. **[owner, NOW]** Deploy: `nix run .#deploy` (PSI gate passes ~1 min after the stop; else `DEPLOY_FORCE_PRESSURE=1`)
3. [owner] Post-deploy: `cat /proc/pressure/io` <20; `pidstat -d 5 3` — no flm reads
4. [owner] Post-deploy smoke: expect `SKIP: FastFlowLM - service disabled (units absent from systemd)`
5. [agent, ready] Dead-reference audit post-deploy (system-health flm rows, deploy.sh guard vs historical journal, polkit rows) — TODO row queued
6. [decision, queued] Local-LLM story (llama-chat vs flm-re-enable vs external API) — TODO row queued
7. [agent] Pin a regression check: "flm disabled ⇒ zero flm units in evo-x2 config" (my live eval was one-shot)
8. [agent] PMA OPENAI_BASE_URL → derive from target enable state / fail closed
9. [decision] Successor sacrifice for the memory guard (empty lists = observe-only; llama-chat/llama-vlm candidates if re-enabled)
10. [decision] agent-unit-control polkit list: prune flm rows or keep as re-enable furniture
11. [agent] Verify the 07:26 deploy's log carried NONE of this session's edits (reasoned, not proven)
12. [owner] flm re-enable trial under 56G/48G ceilings in a calm window, if intended at all
13. [agent] If re-enabled: verify PSI io stays <20 warm and the shmem staging fits under the new high
14. [decision] MemorySwapMax=20G adequacy under the new ceilings (kept unchanged this session)
15. [agent] The 9.4 GB zram swap + 25–45 MB/s si/so churn with 60+ GB available — unexplained by the flm work; granian holds 1.5 GB, top holders sum to ~4.5 GB; worth its own diagnosis (pre-existing, noticed during the storm triage)
16. [agent] Re-measure baseline I/O after the deploy (buildflow/pre-deploy-check were secondary readers; quantify the delta)
17. [decision] `/data` on nvme1n1 vs root-disk isolation (the structural fix for "model streaming shares a disk with rootfs")
18. [agent] FEATURES row's "watch continues" (v1.0.2 heap bug) — now moot while disabled; annotate at next FEATURES pass
19. [owner] `/data/ai/models/fastflowlm` (23 GB) becomes owner-reclaim residue if the disable sticks (ollama-precedent)
20. [agent] Confirm memory-guard observe-only metrics still emit (empty-list branch reports restored=1 by design — verify the textfile rows post-deploy)

## g) Questions I cannot answer myself

1. **Is the disable final (Ollama-style module/package removal next) or a pause pending the 56G/48G re-enable trial?** It decides whether the next session strips the module, package, tests, and docs or maintains them dark.
2. **What is the intended local-LLM end-state for the consumer fleet?** flm and llama-chat are both dark: PMA commit messages, paperless enrichment, browser-history, and ai-meter are all on fallback paths today. Re-enable llama-chat, re-enable flm, or accept external-API/heuristic permanently?
3. **Deploy now?** The disable is verified in tree, and the box is being hammered by the re-arm as of 09:56. I cannot run sudo or the deploy; do you want to run the stop+deploy pair yourself (§f.1–2), or should I keep staging more work first?

---

*Report self-harvested per the TODO system rule: §f direct follow-ups landed as 2 rows in docs/todo/services.md (dead-reference audit [ready], local-LLM story [decision]); items 7, 8, 11 are report-internal candidates deliberately NOT harvested (each needs the deploy or an owner decision first — harvesting them now would queue work that cannot start). No manual commit: the auto-commit daemon owns this tree.*
