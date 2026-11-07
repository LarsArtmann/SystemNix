# Storm Night 2 — Full Diagnosis + Monitoring Cross-Check: Session Status & Brutal Self-Review

**Date:** 2026-11-02, session ran ~01:52–02:14 CEST
**Tree at write time:** HEAD `9cb8bc84e` (daemon-swept, clean; my harvest batch rode `8aa08f030` "5 changed files")
**Scope:** THIS SESSION ONLY (owner directive: report on the current run, then WAIT FOR INSTRUCTIONS; no external research)
**Trigger:** owner, live: "Why are fucking slow!??!?! Why is our I/O like 100% all the time!?" → follow-up challenge: "Did you check the actual I/O pressure? What do our storage monitoring tools say?"

---

## Verdict (one line)

Kernel PSI, the textfile collectors, gatus, SEV1, and the thermal guard ALL agree the box sat at genuine IO saturation (~96–97% some-avg300, phantom=0) driven by three deploy-re-armed model cold-loads + a 105+‑min weekly fstrim + a build battery — attribution landed with a measured-window pipeline on the third attempt, the monitoring stack was only consulted AFTER the owner explicitly asked for it (the session's biggest process failure), and at write time containment is STILL unexecuted (fstrim running, llama-chat cold-loading attempt #3, flm active) while PSI eases to ~85–90% on its own.

---

## a) FULLY DONE

1. **Live storm attribution (round 1), measured window, verified fields** — 20 s cgroup `io.stat` + `/proc/diskstats` delta: llama-chat 129.3 MB/s (cold-load #3), fastflowlm 43.2 (start #3 tonight), llama-embeddings 30.2, user.slice 17.2 (build battery), QLC nvme0n1 rd 170.9 MB/s; known-value check against raw llama-chat io.stat (4.99 GB @ 259:3) before quoting.
2. **Full causal chain reconstructed, journal-verified** — 00:08:57 fstrim onset → 01:04:21 gen-968 stc (sudo from pts/61) re-arming owner-stopped units (nsfw-classifier 01:04:26, flm 01:04:27) → 01:26:52 kernel OOM kills llama-chat → `Restart=on-failure`+10 s cold-load loop (attempt#1 failed 13m34s exit 22 → attempt#2 since 01:40:40) → PSI ~97%, load 196–252, thermal 98–99 °C.
3. **Doctrine compliance** — measure/attribute/report/recommend only; NO agent kills; containment delivered as owner commands with the durable-fix path + pressure-gate caveat.
4. **Owning module read before lifecycle advice** (night-1 §e4 lesson applied) — `llama-rag.nix` Restart/RestartSec confirmed at source.
5. **Monitoring-stack cross-check (round 2, after owner challenge)** — psi.prom (`io_some_avg300 96.14`, `io_alert 1`, `phantom 0`, `disk_busy_max 104.3`), gatus config + live journal (I/O Stall Rate red by design; CPU Thermal ≥95 °C; MediaAtlas/tq/PapDashboard down), SEV1 file + prom (2 active: opencloud crash-loop — 30 restarts since 01:00, start-limit-hit 01:38 — + ZRAM CRITICAL), thermal-pstate-guard (throttled=1, k10temp 99 °C, 191 trips this boot), nvme-health (Lexar QLC HEALTHY: 60 °C, 0 warnings, 100% spare, 18% endurance — load, not hardware), storage-collector (capacity fine, Samsung 64%).
6. **Status report 1 written** (`2026-11-02_01-58_qlc-storm-triple-coldload-fstrim-weekly-deploy-rearm-live-attribution.md`), content-pinned before write.
7. **5 TODO rows harvested at authoring time** — TODO_LIST.md ×4 [ready] (re-arm sweep, llama-chat restart gating, io-attribution.sh, guard-disarmed condition) + domain edits: stability.md ×4 new rows + fstrim row evidence append, services.md re-arm row, ai-stack.md flm watch-row append + NEW llama-chat disable-or-pin [decision] row (2-night evidence).
8. **Probe hygiene** — redact-argv.sh on every pgrep display; intermediates under `~/.cache/io-attribution/` (not /tmp); check-todo-system.sh run and its FAIL triaged as pre-existing (none of the FAIL lines implicate my rows; my report is cited = not unharvested).
9. **State-at-write-time probe** — PSI 85.15/86.95/90.12 (easing), load 90.9, SwapFree 9.2 GB (recovered from 5.6), fstrim STILL running, llama-chat STILL activating, flm active, tree clean (daemon swept my edits).

## b) PARTIALLY DONE

1. **flm's 01:50:22→01:51:23 cycle cause** — 3 starts named (01:04 deploy, 01:25, 01:51) but whether the last was crash-restart or restartTrigger is un-pulled. Effort: S.
2. **The ~01:25 second activation** (profile system-968-link mtime 01:25:31) — evidenced by mtime + flm restart bracket, not journaled out. Effort: S.
3. **pts/61 deploy-session owner** — sudo-layer capture done (journal verbatim); the session itself not attributed via /proc cwd/tty forensics (the AGENTS.md method exists and is cheap). Effort: S.
4. **SEV1 "MemAvailable=9.1%" vs my 30% fresh read** — discrepancy NOTICED and reported, but the alert file's generated-at epoch (1793581511) was never decoded to pin WHICH window the bridge evaluated; hand-waved as "that eval's window". Effort: S.
5. **nvme-health Samsung coverage** — Lexar verified; whether the Samsung line exists in the prom unchecked (head-cut). Effort: S.
6. **Post-edit daemon-sweep verification** — edits landed and checker-clean, tree now clean at `9cb8bc84e`; `git show --stat` on the sweeping commits not run (my batch presumed intact in `8aa08f030`). Effort: S.

## c) NOT STARTED

| Planned                                                                              | Why not started                                                                                          | Priority               |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- | ---------------------- |
| Containment execution (fstrim / llama-chat+ensure / flm / nsfw-classifier stop+mask) | Owner-gated; unexecuted as of 02:13 — PSI easing on its own but the llama-chat OOM→reload loop is intact | Critical (owner hands) |
| Config-disable edits (llama-rag chat enable=false etc.)                              | Deploy-gated: pressure gate blocks; owner ruling pending (2nd night)                                     | Critical               |
| /proc attribution of the pts/61 deploy session                                       | deprioritized behind live diagnosis                                                                      | Medium                 |
| SEV1 epoch decode + bridge sampling-semantics check                                  | same                                                                                                     | Low                    |
| opencloud crash-loop cause triage (30 restarts; which OnFailure chain fired)         | SEV1 named it; cause untriaged (hermes-patchelf class? paperless class? unknown)                         | Medium                 |
| MediaAtlas/tq/PapDashboard casualty-vs-real-outage triage                            | must wait for post-storm re-probe (all three may self-resolve)                                           | Medium                 |

## d) TOTALLY FUCKED UP

1. **THE BIG ONE: diagnosed round 1 from the kernel + cgroups ALONE and never opened the monitoring stack until the owner asked.** The box has a dedicated "I/O Stall Rate" gatus check that has been red all night with an alert text that LITERALLY says "a continuously red check means the box is genuinely IO-starved — do not mute it, fix the readers" — and psi.prom already carried `io_alert 1 / phantom 0`. I re-derived by hand, over three mangled pipelines, what the stack already knew. The monitoring.md routing table was in the pre-read set and I still went kernel-first. The owner's follow-up question was the tell that I'd skipped a layer. Severity: one full diagnostic round wasted; the answer would have been identical 10 minutes earlier.
2. **Three delta pipelines mangled before one clean number** — (1) wrong diskstats fields (ms counters read as sectors) + unsorted join → busy 286,559%; (2) join output offset slip crossing read/write between files → negative IOPS, busy 12M%; (3) grepped io.stat for device NAMES when it keys `major:minor` → empty result. All caught by impossible values before any verdict quoted them, but this is the SECOND consecutive storm session to hit the class (night-1 §d1 window mismatch) — the lesson does not stick without tooling.
3. **The FINAL pipeline's busy% formula shipped ×10-inflated** (`/10/W*100` vs `/W/10`) — stdout transcript carries 9,671%/12,365,649% figures; the verdict deliberately quoted only MB/s + IOPS + PSI, but I never re-ran the corrected busy number, just footnoted it in report 1 §d4.
4. **Containment command batch had a doctrine slip of the night-1 §d3 shape**: `systemctl stop llama-chat-ensure.timer` without `mask` on the TIMER (only the service got masked) — the 01:04 deploy already demonstrated stc re-arm; a stopped-but-unmasked ensure timer comes back on the next deploy and resumes hammering start on the masked unit. Ladder should be: stop → mask service AND timer → config-disable.
5. **A self-answerable question leaked into report 1's §g** — "whose deploy was 01:04 (pts/61)?" is answerable by /proc forensics per AGENTS.md session discipline; asking the owner violates the "questions you CANNOT figure out yourself" bar. (Fix is §f — attribute, don't ask.)
6. **SEV1 numeric disagreement left unpinned** — 9.1% vs 30% MemAvailable: I reported both with a shrug instead of decoding the epoch sitting in the file I had already read. Same family as the quote-scrutiny rule: a number that disagrees with another number is a finding, not a footnote.

## e) WHAT WE SHOULD IMPROVE

1. **Monitoring-stack-FIRST diagnosis order** — for any "why slow" report: read gatus reds + psi.prom + SEV1 state BEFORE hand attribution; hand attribution then CONFIRMS drivers instead of discovering pressure. Cheap, permanent, kills §d1.
2. **Ship `scripts/io-attribution.sh`** (queued) — with a built-in busy% unit check so the /10-vs-W*10 class cannot ship; two sessions have now proven habit alone doesn't fix it.
3. **Containment ladders as doctrine snippets** — stop+mask pairs (service AND its ensure-timer), config-disable path, deploy-caveat; one canonical wording to copy under pressure instead of hand-composing at 2 AM.
4. **Decode every timestamp you already hold** — generated-at epochs, boot IDs, sample windows: the SEV1 9.1% pin cost one `date -d @…`.
5. **Attribute before asking** — /proc cwd/tty/forensics for any "who ran this" before it reaches §g.

## f) Up to 50 things to get done next (session-grounded; Impact / Effort / Category)

> **HARVEST NOTE — deliberately NOT harvested (owner directive: report then WAIT):** items already landed in the 01:58 report's harvest are marked (landed); the rest await owner triage/authorization per the night-1 precedent.

1. Owner executes/authorizes containment — fstrim, llama-chat+ensure (mask BOTH units), flm, nsfw-classifier. — Critical / S / Bug (owner)
2. Post-containment verification probe — PSI<20%, no cold-load reads, zram stable. — High / S / verify [landed: blocked:user row]
3. Re-arm sweep of the 10-31 stop batch vs gen-968. — High / S / Quality [landed: ready row]
4. llama-chat restart storm-gating (RestartSec storm-scale / PSI-gated Condition). — High / M / Feature [landed: ready row]
5. `scripts/io-attribution.sh` with busy% unit check + measured-window stamp. — High / M / Feature [landed: ready row]
6. Guard "disarmed" distinct SEV1 condition (587 lines, all no-match, escalation hollow). — Critical / M / Feature [landed: ready row]
7. flm disable-or-pin OWNER ruling — 2 nights stale, deploy re-arm now proven. — Critical / S / Decision [landed: decision row evidence]
8. llama-chat disable-or-pin OWNER ruling + placement (QLC vs Samsung) — 2nd consecutive night. — Critical / S / Decision [landed: decision row]
9. fstrim PSI-gating / window move (QLC leg now evidenced; extends the standing sdb decision row). — High / S / Decision [landed: evidence append]
10. flm 01:50 cycle cause pull (crash vs restartTrigger). — Medium / S / Bug
11. Identify the ~01:25 second activation (journal sweep 01:24–01:27). — Medium / S / verify
12. /proc attribution of the pts/61 deploy session (cwd/tty of the sudo caller). — Medium / S / verify (self-answerable — do BEFORE any owner question)
13. Decode SEV1 generated-at epochs + document the bridge's sampling window semantics (the 9.1% pin). — Low / S / verify
14. Verify Samsung line present + healthy in nvme-health prom (collector coverage). — Low / S / verify
15. opencloud crash-loop triage (30 restarts, start-limit-hit 01:38; which failure class — hermes-patchelf SIGSYS? config? DB?). — High / S / Bug
16. Post-storm re-probe of MediaAtlas/tq/PapDashboard (casualties expected to self-resolve; anything still down is real). — Medium / S / verify
17. zram trajectory watch (88→91→86% observed this session) until containment or refill. — Medium / S / watch
18. Monitoring-first diagnosis doctrine line (stability.md or monitoring.md: "gatus/psi.prom/SEV1 before hand attribution"). — High / S / Documentation
19. Containment-ladder doctrine snippet (mask service AND ensure-timer + config-disable + deploy caveat). — High / S / Documentation
20. Verify the daemon-swept commits (`8aa08f030`, `9cb8bc84e`) contain my harvest intact (git show --stat). — Medium / S / verify
21. busy% correction one-liner into the 01:58 report §d4 (corrected formula + correct final values). — Low / S / Documentation
22. Mask the ensure TIMER (not just service) in the standing containment advice if not yet executed. — High / S / Bug (owner)

## g) Three questions I cannot figure out myself

1. **Did you run the containment batch (or decide to ride the storm out)?** As of 02:13 fstrim is STILL running, llama-chat is STILL on cold-load attempt #3, flm active — yet PSI eased to ~85–90% and swap freed 5.6→9.2 GB on its own. If you're deliberately letting it drain, I stop recommending; if not, the four stop+mask commands stand (plus the ensure-TIMER mask per §d4).
2. **The two standing rulings, now with two nights of evidence:** disable-or-pin for llama-chat and for fastflowlm (and the QLC-vs-Samsung placement question for the hot chat GGUF). Every hour without a ruling is another possible night-3.
3. **The build battery (httputil + ChastityAPI go builds, golangci, clippy, qemu VM test, ≥5 crush sessions): yours or parallel agent sessions'?** I can attribute the _sessions_ via /proc, but not the _intent_ — if it's precious in-flight work I'll treat it as an untouchable storm leg; if it's disposable, it's the third-biggest lever after the model loads.

---

**Cross-references:** night-1 report (`2026-10-31_20-32_…`) and this session's report 1 (`2026-11-02_01-58_…`); `docs/agents/stability.md` (storm action menu, freeze-4 stc re-arm, family-C); `docs/agents/monitoring.md` (textfile/gatus doctrine — the layer I skipped first); harvested rows in TODO_LIST.md + docs/todo/{stability,services,ai-stack}.md.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE f.7 f.15 · already-tracked f.1-6 f.8 f.9 f.17 f.22 · OBSOLETE f.10 f.20 (flm world + supersession) · NEW rowed: f.11(+12+13+14) → stability, f.16(+13-17 §f.5) f.18(+19) f.21 → monitoring
