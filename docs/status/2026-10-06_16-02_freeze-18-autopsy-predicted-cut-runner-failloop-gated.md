# Freeze #18 Autopsy — the 15:30 Report's Own Prediction, Landed 11 Minutes Later; gitea-runner Fail-Loop Diagnosed + Gated (2026-10-06)

**Session:** 2026-10-06 ~15:46 → ~16:05 — trigger: user asked "We just crashed again: root cause / what else broke / fix suggestions" after the 15:42 boot. Read-only forensics + one deploy-gated module fix (forgejo.nix). Autopsy of the 10-06 15:41:14 cut (#18 = boot -1, the post-#17 recovery boot).

**Sibling context:** freeze #16/#17 autopsy (`15-30`, predicted this cut at authoring: "Freeze #18 conditions are forming"), bank-sync vendorHash (`15-35`, deploy-gated), netbird provision batch (`15-35`). This is the FOURTH consecutive cut predicted by its predecessor's autopsy (#14→#15, #15→#16, #16/17-report→#18) with zero owner-leg execution between.

## Verdict

**Freeze #18 = the thermal-ceiling instant-cut family, sixth consecutive cut on the standing physical cooling deficit (#8/#9/#11–#18), and the second cut with thermal-pstate-guard throttling live.** Boot -1 (15:14:39 → 15:41:14, 26 min 35 s — the shortest crash boot of the family; the post-#17 recovery boot NEVER settled) rode the chronic Zone-6 IO storm from minute 3 (trips #2073/#2074/#2075 at the ~10-min cadence, whole-boot), SEV1 latched `MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED` every 10 s for the final ≥3 min (15:37:55 → 15:41:07 — #16's latch signature), thermal-pstate-guard cycling to the last second (15:41:07), journal cut mid-traffic at 15:41:14 (pma WARN batch-queue lines; healthy ms-latency traffic to the end — cv `/health` 200 @ 15:41:08), zero shutdown ceremony, zero OOM/MCE/BTRFS kernel events, no deploy in flight. Guard counter continuity held across the cut (#2075 → #2076). The 15:30 report measured the forming conditions live (trip #2073 at 15:17:38, Tctl 83.8 °C, load 34) — the cut landed 11 minutes after that report's authoring window.

The storm's writer class was named live this session (the documented 5 s `/proc/<pid>/io` attribution pass): **sibling agent-session build load** — `buildflow` 478.7 MB/5 s writes + `sccache` 149.7 MB/5 s + its `go` child 31.8 MB/5 s, alongside a parallel `nix flake check --no-build` at 172 % CPU / 10 GB RSS and 4+ concurrent crush sessions. The #2076 post-crash re-trip rode the freeze-6 recovery-reader class instead (hermes +2,234 MB, systemd-fsck +625 MB, signoz-collector +253 MB since last trip).

## Evidence

| #  | Finding                                  | Evidence                                                                                                                                                                                                                                                                                                |
| -- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | #18 hard cut, no ceremony                | boot -1 (15:14:39 → 15:41:14, 26 m 35 s) ends on pma `batch queue full` WARNs at .xxx precision; healthy 200s to the end (cv /health 264 µs @ 15:41:08, openseo GET 200 @ 15:41:01); boot 0 starts 15:42:46                                                                                             |
| 2  | Whole-boot Zone-6 storm                  | trips #2073 (15:17:38 — 3 min in), #2074 (15:27:39), #2075 (15:37:43); slice attribution #2074: system +17,737 MB / user-1000 +15,456 MB; #2075: user-1000 +9,996 MB / system +9,162 MB                                                                                                                 |
| 3  | SEV1 latch = #16's death signature       | `SEV1 active (2 condition(s)): MEMORY EMERGENCY GUARD TRIPPED; FLM RESTORE CAPPED` every 10 s from 15:37:55 through 15:41:07 (≥3 min); severities notify (memory never overlays — policy held)                                                                                                          |
| 4  | Thermal mitigation live through the cut  | thermal-pstate-guard start lines every 10 s to 15:41:07 (last systemd start before the cut); guard held guided since the 13:30 ENTER per the 15:30 report's series — throttled THROUGH death, again                                                                                                     |
| 5  | Not OOM/MCE/storage                      | boot -1 kernel scan: 0 OOM, 0 MCE events (the lone `MCE:` line is the boot-time "decoding enabled" init), 0 BTRFS error lines; the 3 bdev-counter lines are boot inits with STANDING values corrupt 12/1/386583438 — byte-identical to the freeze-#12/#13 baselines → zero new events across the cutoff |
| 6  | No deploy at death                       | 0 switch-to-configuration/activation lines in boot -1 — excludes the #4/#5 mid-deploy class                                                                                                                                                                                                             |
| 7  | Guard counter continuity held            | #2075 (boot -1) → #2076 (boot 0, 15:47:45) — third consecutive clean carry                                                                                                                                                                                                                              |
| 8  | Prediction→cut interval ~11 min          | 15:30 report authored during trip-#2073 conditions ("Freeze #18 conditions are forming at authoring"); cut 15:41:14                                                                                                                                                                                     |
| 9  | Live writer attribution (boot 0, ~15:52) | 5 s /proc/io delta: buildflow 478.7 MB/5 s, sccache 149.7, go 31.8 (buildflow child), mr-sync 8.4, crush 3.2, tq 2.8, nix 1.9 — the sibling-session verification/build battery class, not hardware                                                                                                      |
| 10 | #2076 = recovery-reader class            | trip attribution: hermes.service +2,234 MB, systemd-fsck.slice +625 MB, signoz-collector +253 MB — the freeze-6 crash-recovery readers, NOT yet the build storm                                                                                                                                         |
| 11 | Post-crash peripheral class did NOT fire | eno1 present, /mnt/pool + /mnt/buildcache + /mnt/hot + forgejo subvol all mounted on boot 0 (checked live) — no NIC-vanish, no DAS drop                                                                                                                                                                 |
| 12 | Live regime at authoring (16:00)         | trip #2077 in; Tctl/acpitz 93 °C sustained; IO PSI some avg10 79.4 %/avg60 76.7 % and RISING; freeze #19 conditions forming — the fourth consecutive autopsy to say so while writing itself                                                                                                             |

## Collateral ("did anything else break?")

| Item                                                                                                    | Verdict                                           | State                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| gitea-runner-evo-x2 fail-loop (token-gen ERROR + runner FAILURE every ~63 s, boots ≥ -3)                | **NEWLY DIAGNOSED, FIXED in tree (deploy-gated)** | forgejo family is INTENTIONALLY inert (`dedicatedSubvolume` staged since 09-30, `finalize` never run → `.subvol-migrated` absent → forgejo.service skips by design); but gitea-runner's `+forgejo-gen-runner-token` ExecStartPre lacked the marker gate and hammered a skipped forgejo. Fix: family condition added (eval-verified) |
| discordsync Turso quota (`SQL read operations are forbidden… upgrade your plan?`, breaker, 1 h backoff) | pre-existing, standing row                        | services.md :91/:94 — the known [decision] plan call                                                                                                                                                                                                                                                                                |
| hermes duplicate `provider` key (edge/zai, line 476/477) breaking terminal-policy parse                 | pre-existing, standing row                        | services.md :20 (since freeze-12); runtime-owned config, sandbox-unreadable                                                                                                                                                                                                                                                         |
| bank-sync `[corruption] wise.exchange_rate` FX total failure                                            | pre-existing                                      | present at boot -2's final lines (15:12:57) — before the cut                                                                                                                                                                                                                                                                        |
| pma `batch queue full` (hardware-identity)                                                              | load symptom                                      | self-heals when the storm drains                                                                                                                                                                                                                                                                                                    |
| paperless postgres collation version mismatch (2.42 → 2.44)                                             | benign, needs one SQL                             | queued [ready] (services.md) this session                                                                                                                                                                                                                                                                                           |
| journal file `system@00065cc9ec260c9d….journal~` truncated                                              | crash artifact                                    | journald ages it out; noted, no action                                                                                                                                                                                                                                                                                              |

## a) FULLY DONE

1. Full #18 autopsy, all portable discriminators answered (table above); classified thermal instant-cut family, mitigation-insufficient class — the 6th cut on the deficit, 2nd with the guard throttling.
2. Guard counter continuity verified (#2075→#2076); kernel OOM/MCE/BTRFS scans clean; standing bdev counters byte-identical to #12/#13 baselines (zero new events).
3. Writer attribution executed live per the documented protocol — the storm is sibling-session build load (buildflow/sccache/go + a parallel flake check), named with numbers, not vibes.
4. gitea-runner fail-loop root-caused to the missing family gate and FIXED in `modules/nixos/services/forgejo.nix` (marker condition + RequiresMountsFor, matching the family pattern); toplevel eval green post-edit.
5. Collateral triaged into new-vs-standing with row pointers (table) — nothing ELSE newly broke; the post-crash peripheral class (NIC/DAS/pool) did not fire.

## b) NOTICED, NOT DIAGNOSED

1. The 63 s fail-loop cadence vs startLimitBurst 5/300 s — presumed deploy/switch re-triggers from parallel sessions restarting the unit between limit windows; not re-derived (the gate makes it moot).
2. cv health `overall_status=warn` (41 checks) — not decomposed; likely the standing forgejo-red + turso-red conditions.
3. Two identical `/mnt/pool` lines in /proc/mounts — expected multi-device btrfs enumeration, not verified against the zombie-mount runbook.

## c) DELIBERATELY NOT DONE

1. No stability.md freeze-entry writing beyond the standing row extension — the #8–#13 entry backlog row owns the full write-up; #18 draft material appended there instead.
2. No deploy of the forgejo fix — the deploy pressure gate + storm rule (Zone-6 trips within the last hour → queue, don't race dips) applies; it joins the bank-sync 15:35 deploy-gated batch.
3. No live load-shed of sibling sessions (buildflow/sccache/flake-check at 93 °C) — their work is not mine to kill; surfaced to the owner instead (§g).
4. pstore/btrfs-sysfs reads — standing owner-gated rows (sandbox).

## d) SELF-CRITICISM

1. My own verification evals (2× toplevel/unit eval) ran INTO the 93 °C / 79 % PSI storm — same class the enforcement row targets. Justified (read-only, backgrounded, single-pass) but it belongs in the honest ledger: verification load is still load.
2. `nix fmt` normalized 3 unrelated unformatted files (browser-policies/bank-sync/configuration — other sessions' committed-unformatted work) into my working tree; caught via `diff --stat`, left for the daemon (pre-commit would reformat them anyway). Watch the batch commit.
3. First unit-inspection eval used a wrong option path (`systemd.units.<n>.unitConfig` — not a real suboption; rendered `text` is the ground truth) and the `or null` swallowed the error into a plausible-looking `null`. Retried against unit text + a known-conditioned control unit. Lesson: never let `or null` dress a probe failure as a finding.

## e) WHAT WE SHOULD IMPROVE

1. The prediction-to-cut loop is now 4 autopsies long with the enforcement leg still prose — the no-heavy-builds admission gate ([ready] row) would have blocked today's buildflow/sccache battery at trip-#2073 conditions.
2. A condition-gated family should gate ALL its members in one place — the runner gap survived because the gate was copy-pasted per-unit; a shared `subvolMigratedCondition` attrset merge (or an assertion that every unit named `forgejo*`/`gitea*` in the family carries it) would make the class structurally closed. Candidate follow-up.
3. Recovery boots keep re-storming via the freeze-6 reader class (hermes/fsck/signoz on #2076) — the "stop resumable readers at next boot" rule (stability.md freeze-6) still has no automation.

## f) NEXT THINGS (self-harvested at authoring; routed per TODO rules)

1. **[blocked:user] physical cooling inspection** — standing row EXTENDED: BAIT TAKEN a 6th TIME (#18, 26-min recovery-boot cut, guard throttling live, prediction→cut 11 min). **Source:** this report Verdict.
2. **[ready] no-heavy-builds enforcement leg + scope-level trip attribution** — standing row EXTENDED: #18's whole-boot storm + live boot-0 writers named (buildflow 478.7 MB/5 s, sccache 149.7, parallel flake check 172 % CPU at 93 °C). **Source:** this report findings 9/12.
3. **[ready] Write the missing freeze #8–#13 entries** — standing row EXTENDED with #18 draft material (Verdict + Evidence table). **Source:** this report.
4. **[ready] paperless collation refresh** — NEW row (services.md): `ALTER DATABASE paperless REFRESH COLLATION VERSION` after the glibc 2.42→2.44 jump (warning-level, prevents silent index-corruption drift). **Source:** this report Collateral table.
5. **[ready] Condition-gate assertion for the forgejo stateful family** — NEW row (services.md): every family unit carries `subvolMigratedCondition` by construction, not copy-paste (the gitea-runner gap class). **Source:** this report §e.2.
6. Deploy of the forgejo runner-gate fix — rides the standing deploy-gated batch (with bank-sync 15:35); not a new row (deploy queue owns it), noted here for the batch manifest.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. Cooling inspection scheduling — EIGHT crashes on one deficit; every software layer (guard, sev1, gate, autopsies) is now proven unable to substitute.
2. Shed the live build sessions NOW (buildflow/sccache battery + parallel flake check at 93 °C / IO PSI ~80 %) or accept freeze #19 as a timed event — same call as freeze-15 §g, one more corpse later.
3. Turso plan ([decision] row :94) — the discordsync cloud-sync breaker recurs every boot until answered.

**Standing state at report close:** freeze #18 autopsied (thermal family, mitigation-insufficient, prediction→cut 11 min); guard counter continuity intact (#2075→#2076); gitea-runner fail-loop fixed in tree (deploy-gated, eval-verified); no other NEW breakage (collateral all standing rows); boot 0 storming at 93 °C / IO PSI ~80 % with sibling build load — freeze #19 conditions live at close.

_Arte in Aeternum_
