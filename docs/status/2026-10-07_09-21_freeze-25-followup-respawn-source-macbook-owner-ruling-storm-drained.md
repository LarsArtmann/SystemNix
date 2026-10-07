# Freeze-25 Follow-Up: Respawn Source = Owner's MacBook Fleet · tq Pool Journal-Cleared · Storm Drained · Owner Ruling Captured

**Session:** 2026-10-07 09:11–09:21 CEST (post-autopsy verification + live monitoring + respawn-source resolution)
**Scope:** THIS session only — verification of the 09:00 freeze-25 autopsy's open live items. The autopsy itself: [2026-10-07_09-00_freeze-25-autopsy-guard-action-executed-ineffective-tq-864gb-recovery-storm-contained.md](./2026-10-07_09-00_freeze-25-autopsy-guard-action-executed-ineffective-tq-864gb-recovery-storm-contained.md)
*(Format: .md per explicit user instruction + repo status convention; the status-report skill is HTML-canonical — divergence flagged in-file, same as the 09:00 report.)*

**Headline:** The respawning `crush -y` fleet — freeze-25's open "respawn source unidentified" item — is **the owner's own MacBook Air (192.168.1.62) SSH'ing in and launching crush sessions across projects**. The owner confirmed live at ~09:19: *"I am working so yeah I need my ssh connections to crush"* — the fleet stays, the SIGSTOP license gains an owner-session carve-out, and PSI drained to a ~34 some-avg10 plateau without further containment.

---

## a) FULLY DONE

1. **Prior-session artifacts verified landed.** Freeze-25 autopsy + both harvest surfaces committed by the daemon (`1af15f78`: report +90, TODO_LIST +4, stability +11); the time-gate regression fix ("tonight" → "in the 2026-10-07 overnight sequence") swept separately (`fe7d455b`, exactly 1 line per file). Tree clean at 09:21 (a concurrent session's `flake.lock` bump rode `a79d3163` — flagged, untouched).
2. **Live PSI decay tracked to plateau, no re-climb.** some avg10: 83.4 (08:38 peak, prior session) → 64.4 (09:11) → 36 (09:14) → 34.3 (09:21); full avg10 54.3 → 24.4; at 09:21 avg60 (32.5) fell BELOW avg10 (34.3) — still draining. 5 samples, monotone after 09:11.
3. **All 13 SIGSTOPped pids verified gone — 0/13 alive at 09:21.** 597049/602404 were still alive (T-state) at 09:11, gone by 09:21 — terminated externally, not by this session. No SIGCONT is owed; freeze-25 §g.2/f.10's resume choreography is MOOT.
4. **Respawn source IDENTIFIED** (the autopsy's open item): every new battery chain is `sshd-session: lars@pts/N ← 192.168.1.62` → login `-fish` → `crush -y` → `golangci-lint-langserver`. 208 accepted-publickey logins 08:35→09:12 (~5.7/min, one ED25519 key, PTY-allocated sessions); observed cwds: `browser-history`, `BuildFlow`, `hardware-identity` — a BROADER set than the local pool's `repos = CV,SystemNix,go-taskqueue`. Parent-chain walk verified to master sshd (pid 2018); no fish-config autostart (both configs grep-clean).
5. **192.168.1.62 resolved to the OWNER'S MACBOOK AIR.** Owner-confirmed identity 2026-10-04 (CHANGELOG:184-185, dnsblockd registry `macbook`): Realtek 00:e0:4c = the MacBook's USB-ethernet adapter; live ARP agrees (00:e0:4c:68:04:00). Not a third machine, not the Pi, not the TV (that guess was already falsified once).
6. **tq-agent-pool journal-CLEARED as the respawner.** Its own journal shows ONLY `budget: skipping harvest tick reason="daily budget exhausted: 30/30…"` every 5 min 08:35→09:15 — harvest idle; the inherited "budget-exhausted ⇒ idle" belief was CORRECT. Its only socket is 127.0.0.1:8088 (alert-url); its config (concurrency=3, max-per-tick=3, interval=5m, task-timeout=45m) cannot produce 5.7 logins/min. The 864 GB pre-crash attribution (guard io.stat, pool's own service cgroup) is a SEPARATE actor and STANDS — two actors, not one.
7. **Plateau pressure CLASS determined: latency, not throughput.** Python 12 s /proc/io sampler (the freeze-24 §d3-approved method, reads+writes, tree-aggregated) found no reader >8 MB/12 s. The ~34 some-avg10 floor is carried by the wedged sdb1: ~4 MB/s effective reads (diskstats decode: 22.9 min read-time over a 38.6 min boot), `flush-8:16` + `usb-storage` D-state since boot, 225 MB Dirty. Containment correctly withheld — license band (>60) never met after 09:11.
8. **Owner ruling captured and encoded.** The .62 sessions are the owner's active work; they stay running. Carve-out lands in the SIGSTOP-license policy rows (TODO_LIST.md:94, stability.md:171) with this report's harvest: **owner-origin interactive sessions are never sweep targets**; the license covers foreign/headless batteries only.

## b) PARTIALLY DONE

1. **Freeze-25 autopsy Update section — gathered, not appended.** All follow-up facts (a3–a7) were in hand at the status-report interrupt; the append to the 09:00 file did not happen. THIS report now carries them and cites back; the autopsy stays as-authored (a docs-health ANNOTATE pass can add the pointer later — not done mid-storm). Effort S.
2. **SIGSTOP-license rows amendment — drafted, landing now** (owner carve-out + journal-clear-first attribution check, e1/e2). Not yet gate-verified (`scripts/check-todo-system.sh`) at writing — verified immediately after landing (see Evidence). Effort S.
3. **Battery master rows UPDATE — drafted, landing now** (TODO_LIST.md:93 + stability.md:142: respawn source resolved, pool cleared, 13 pids gone, owner ruling). Same gate verification as b2. Effort S.
4. **PSI monitoring — 10 min held, no long-run watch.** Below-threshold discipline held (no action, no oversampling of CONTAINMENT, see d4 for the sampling overkill), but the plateau's stability under the owner fleet is observed for ~10 min only. Current 17 crush + 14 langservers churning (sessions live minutes) is the expected steady state. Effort S per spot-check.

## c) NOT STARTED (deliberately)

1. **Zone-6 guard split implementation** — owner go still pending (freeze-25 §g.1; stability.md:170 `[blocked:user]`). The ruling question was queued for the question tool when the status-report interrupt arrived.
2. **Freeze numbering ratification** — carried owner question (freeze-24 §g.3; #21–#25 inferred).
3. **sdb1 /mnt/buildcache wedge remediation** — the USB enclosure disk serves ~4 MB/s reads, discarded its ext4 journal at every dirty boot (`JBD2: journal reset failed`, boots −1 AND 0), and now forms the latency floor under every PSI reading on the box. Keep/migrate/retire is an owner decision — promoted to §g.2.
4. **No further containment runs** — deliberate: license band not met after 09:11; the owner ruling would have forbidden the obvious target anyway.

## d) TOTALLY FUCKED UP

1. **I nearly mis-attributed the respawn source — the exact failure class the autopsy had just codified.** First conclusion from `ps` (tq agent-pool pid 2056 alive since boot + the login flood) was "the pool is the spawner; the budget-idle belief is falsified." The pool's OWN journal falsified MY claim minutes later: harvest skipping every tick. I pattern-matched "pool spawns agents" without checking the pool was actually spawning anything. Freeze-25 §b3's discipline (read the actor's own journal before naming it) existed IN THE REPORT I WAS VERIFYING. Root cause: cheapest-evidence-first, again.
2. **Search-order miss on .62's identity.** I grepped `docs/services/` + `modules/` for an agent-runner architecture BEFORE grepping the repo for the IP literal; the answer (CHANGELOG 2026-10-04, owner-confirmed) was one `rg '192\.168\.1\.62'` away and I ran it second. ~5 wasted minutes mid-storm, on a box where every read counts.
3. **Drafted-but-unflushed follow-up at the interrupt.** The autopsy-Update append + both row edits existed only in-session when the user's message landed. A session death there would have lost the respawn-source resolution entirely — the daemon only sweeps FILES, not intentions. Mitigated by folding everything into this report + landing the rows before the final message, but the near-miss is the lesson: land findings as they solidify, not at "the end."
4. **Oversampling below threshold.** 5 PSI reads + 2 full per-pid samplers while some avg10 sat 34–40 and drained monotonically. The license says act at >60; nothing required proving the drain five times. Freeze-25 §d5 flagged report-writing IO as load — my verification reads were the same class at smaller scale.

## e) WHAT WE SHOULD IMPROVE

1. **Attribution protocol, codified: the actor's own journal FIRST, ps topology second.** d1 (this session) and freeze-24 §d3 (garbage bash sampler) are one meta-failure: trusting the cheapest evidence during a storm. Encoding it as a pre-action check inside the SIGSTOP-license policy row (landing with this report): journal-clear the obvious suspect before sweeping a class.
2. **The SIGSTOP license needs the owner-activity carve-out AS WRITTEN POLICY, not memory.** Today's near-miss: pid 84341 (owner's fish, ~600 MB/8 s reads at 09:0x) sat squarely in license-literal SIGSTOP territory at avg10 64 — a rule-literal future session could have frozen the owner's terminal mid-work. The ruling (.62-origin interactive sessions = owner = never sweep) goes into both policy rows now.
3. **PSI-gate keying cannot ride avg10 alone while sdb1 lives.** A wedged ~4 MB/s disk produces 30–45 some-avg10 FOREVER at near-zero throughput: every >60 trip threshold is one busy afternoon from permanent fire, every <20 resume bar from being unreachable. Gates (license + the proposed Z6 IO-class action) need a diskstats-throughput cross-check — or the wedge dies first (§g.2).
4. **Handoff summaries must flag one-command falsifiable beliefs.** The inherited summary carried "pool budget-exhausted so idle" but framed it as possibly stale; one `journalctl -u tq-agent-pool --since boot` line settles it. I spent the falsification effort in the wrong order (d1) because the belief's cheapness wasn't marked.
5. **Harvest-before-final-message as hard sequencing.** The standing self-harvest rule was nearly violated by interruption (b2/b3). The rows land BEFORE this report's final chat message — discipline, not a promise for later.

## f) NEXT (ranked; `[ROW]` = existing row · `[NEW]` = born this session)

1. `[ROW]` **Zone-6 guard split implementation** (stability.md:170, `[blocked:user]`) — Critical / M — two structural proofs, three deaths, working manual prototype (fleet SIGSTOP). Still the top ask; needs owner go + window call.
2. `[ROW]` **SIGSTOP-license policy amendment: owner-session carve-out + journal-clear-first attribution check** (TODO_LIST.md:94, stability.md:171) — High / S — landing with this report (b2).
3. `[ROW]` **Battery master row UPDATE: respawn-source resolution + owner ruling** (TODO_LIST.md:93, stability.md:142) — High / S — landing with this report (b3).
4. `[NEW]` **sdb1 /mnt/buildcache wedge disposition** — retire the USB enclosure, migrate `go-mod` to NVMe, or replace the disk; it is the latency floor under every PSI number, the `JBD2: journal reset failed` recurrence (boots −1 and 0), and freeze-24 §c5's open mount-state question — High / M → storage.md.
5. `[NEW]` **PSI-gate throughput cross-check** — pair any avg10 gate (license, Z6 IO-class action) with a diskstats Δ check so a wedged-low-throughput disk can't false-fire/false-hold gates — High / S → stability.md (rides the license row + row 170 fix shape).
6. `[ROW]` **Freeze numbering ratification #21–#25** (freeze-24 §g.3) — Low / S → §g.3 below.
7. `[ROW]` **Taxonomy entries #23/#24/#25** (stability.md row 106) — Medium / S — third dispatch cycle carrying it.
8. `[ROW]` **Recovery-boot pause automation** (row 169; six re-arm proofs) — Critical / M.
9. `[ROW]` **tq-agent-pool IO discipline** (row 172) — unchanged by this session: pre-crash 864 GB attribution stands; harvest idle since 08:35 — High / M.
10. `[ROW]` **SEV1/Discord 08:32 delivery audit** (monitoring) — Medium / S.
11. `[ROW]` **Post-crash integrity sweep** — docker data-root, btrfs scrub root+pool, mid-flight writers, truncated `.journal~` — Medium / M → storage.md + services.md.
12. `[ROW]` **deploy.sh entry gates before the validation battery** (pipeline) — Critical / S.
13. `[NEW]` **Mark the "13 frozen sessions resume choreography" (freeze-25 §f.10) MOOT in any surface that cites it** — 0/13 alive, terminated externally — Low / S (annotate, don't rewrite).

## g) Questions I CANNOT figure out myself (max 3)

1. **Zone-6 split: implement now?** (f.1) The fix shape has two structural proofs (#24 muzzled-cooldown, #25 executed-and-died-anyway) and today's manual fleet-freeze as the working action prototype. Deploy consideration changed shape: your MacBook fleet holds the box at some avg10 ~34 — is that an acceptable window for the guard-fix deploy's own eval battery, or should the deploy wait for a natural gap? I cannot judge your fleet's priority against the deploy window.
2. **sdb1 /mnt/buildcache: keep, migrate, or retire?** (f.4) The USB enclosure disk wedges to ~4 MB/s under load and discards its ext4 journal at every dirty boot. It is now the standing latency floor under EVERY PSI measurement — which also means every pressure-gated mechanism on this box is partially gated on a $30 enclosure. Whether its buildcache value outweighs that is an owner economics call, not an agent inference.
3. **Freeze numbering ratification** (carried, freeze-24 §g.3): I count the 2026-10-07 overnight sequence as #21–#25 by autopsy-title↔boot mapping. If your count differs, the taxonomy entries (f.7) should carry yours.

---

*Evidence (this session, all commands run 09:11–09:21): `/proc/pressure/io` ×5 (64.44→36.27→37.95→34.44→34.31 some avg10; full 54.32→24.42); 13-pid survival sweep ×2 (2 alive 09:11 → 0/13 09:21); `ps` fleet census (18→17 `crush -y`, 15→14 langservers); parent-chain walk 1247138←fish 1216280←sshd-session 1216279←sshd 2018; fish configs grep-clean of crush autostart; `journalctl -u sshd --since 08:35` (208 accepted logins from 192.168.1.62, key SHA256:PCt1vyHm…); `ss -tnp` (15+ ESTAB 192.168.1.150:22←192.168.1.62:*; tq pid 2056 → 127.0.0.1:8088 only); `/proc/net/arp` (.62 = 00:e0:4c:68:04:00) + CHANGELOG:184-185 (.62 = owner's MacBook Air, 2026-10-04); `tq-pool.conf` (/nix/store/lpr1kkwdv26ax5bcvzp6vsq0x0sk6w5v: concurrency=3 max-per-tick=3 interval=5m daily-budget=30); `journalctl -u tq-agent-pool` (budget-skip only, 08:35→09:15); python 12 s /proc/io tree sampler (max 7.9 MB/12 s single tree); D-state census (`flush-8:16`, `usb-storage`); `/proc/meminfo` (Dirty 225 MB); `/proc/diskstats` sdb decode (~4 MB/s reads); `readlink /proc/*/cwd` (browser-history, BuildFlow, hardware-identity); git: `1af15f78` (autopsy+rows), `fe7d455b` (regression fix), `a79d3163` (concurrent session's flake.lock bump — flagged, untouched); `rg '192\.168\.1\.62'` → CHANGELOG + dns-blocker-config.nix:98. Self-harvest: f.2/f.3 land in TODO_LIST.md + stability.md (both surfaces) at authoring per the standing rule; f.4/f.5 land as new rows in storage.md/stability.md respectively; f.13 is an annotation note for the next docs-health pass, deliberately not edited mid-storm.*

*Owner ruling (live ~09:19, verbatim): "I am working so yeah I need my ssh connections to crush" — the 192.168.1.62 fleet is active owner work; never sweep it.*
