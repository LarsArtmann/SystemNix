# Deploy-unblock session: §16 papdashboard-icons realize fix + HaGeZi-dyndns re-pin + vendorHash treadmill surfaced

**Session:** 2026-11-12 ~04:30–12:05 CET (crush session, tree `/home/lars/projects/SystemNix`)
**Trigger:** owner paste — `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` blocked at §16 (`PAP_ICONS_DIR … does not exist as a directory (and the realize attempt failed)`), deploy aborted pre-build.
**State at authoring time:** deploy still NOT landed — blocker has MOVED (three distinct layers peeled; current blocker is a 9-package go-modules vendorHash wave, §d below). All evidence commands cited inline.

---

## Timeline (this session only)

| Time (CET) | Event |
| --- | --- |
| 04:15–04:23 | Daemon commits b0b2e22/a08ef87 (docs only — not the cause) |
| ~04:30 | Owner's deploy attempt aborts at §16 (log `2026-11-12_05-18-27.log` — timestamped later than the paste; the pasted run is that battery) |
| ~04:40 | Reproduced: `nix build /nix/store/…-papdashboard-icons` → **"don't know how to build these paths"** — the §16 on-the-fly realize was structurally broken for a never-registered drv, NOT a broken icons build |
| ~04:50 | Built the subset via the flake attr (`…config.services.papdashboard.iconsDir`) → GREEN, out path `a2v2ap19r3…-papdashboard-icons` (43 entries) — pack source FOD had been GC'd and re-fetched clean |
| ~05:00 | Root-cause fix in `scripts/pre-deploy-check.sh` §16: realize via flake attrpath instead of bare out-path; shellcheck + `bash -n` green; daemon committed it as `00080450` (verified: 1-file diff, only my change rode it) |
| ~05:10 | `--section-16-only` → **PASS**: "all 45 tiles carry icons (43 pack + 2 URL); all 43 pack icons exist" |
| 05:24 | Deploy #2 (`DEPLOY_FORCE_PRESSURE=2`; PSI 36.8% but disks idle — D-state phantom on a kworker, ghostty scopes 73–79% io.pressure; forced per owner's original intent). **Battery PASSED** (build only runs post-battery), then `nh os switch` build failed: HaGeZi-dyndns-raw FOD hash mismatch (specified yb9EEGbS, got c1sqvguO) |
| ~05:40 | Root-caused: `hagezi` helper is COMMIT-PINNED (`f8c1f9f8`, since 2026-11-06) — immutable URL, so NOT upstream drift. The dyndns pin was stale since the 11-06 commit wave (kept its 2026-10-16 branch-era value; warm store path masked it until GC collected it) |
| ~05:45 | Stability probe ×2, 20 s apart → both `c1sqvguO` (= build's `got:`). Re-pinned `platforms/common/dns-blocklists.nix` + rewrote the stale comment. **Audited ALL 23 pins** against the commit via `nix store prefetch-file`: **23/23 OK** |
| ~05:50 | `nix build --keep-going` toplevel — failed again; **my first output capture was tail-only and lost the root enumeration** (see §d) |
| 12:05 | Re-ran keep-going with `tee` capture: **9 distinct go-modules FOD hash mismatches**. HEAD moved to `152bef10d` "float go-cqrs-lite to tip — cqrs-lint vendorHash re-stale" — a **parallel session** floated the lock during the 6 h gap |

---

## a) FULLY DONE

1. **§16 papdashboard-icons deploy block — root-caused and fixed.** The gate's on-the-fly realize used `nix build <bare out-path>`, which can only work when the drv is already registered in the store DB ("don't know how to build these paths" otherwise — reproduced live). The icons derivation itself was healthy. Fix in `scripts/pre-deploy-check.sh` (§16 realize branch): build `.#nixosConfigurations.evo-x2.config.services.papdashboard.iconsDir` (evaluates + realizes in one step regardless of registration). Comment documents the mechanism (4th occurrence of the derived-but-never-realized class). Committed via daemon as `00080450`, diff verified to contain ONLY this file.
2. **§16 verification green**: `--section-16-only` → 45/45 tiles carry icons, all 43 pack icons exist in the realized subset; the real deploy battery (05:24) subsequently passed §16 and reached the build stage.
3. **HaGeZi-dyndns stale pin — root-caused, probed, re-pinned.** Commit-pinned URL (immutable) + stale SRI hash masked by a warm store path since the 2026-11-06 commit wave; today's GC exposed it mid-deploy. Probed STABLE twice 20 s apart (`c1sqvguO`, equals the build's `got:`). Edit in `platforms/common/dns-blocklists.nix` (uncommitted at authoring; daemon will sweep — attribution: this session).
4. **Whole-class audit**: all 23 blocklist pins (22 HaGeZi + StevenBlack) fetched fresh and compared against the pinned commit — **23/23 match** post-fix. Pin list cached at `~/.cache/hagezi-pins.tsv`.
5. Sudo/NNP + PSI probes before deploy #2 (sudo rc=0 in this session; pressure gate signature: idle-disk D-state phantom, not a real IO storm — forced with =2 per the owner's own invocation pattern).
6. Daemon-commit attribution checks at both commits that touched session work (00080450: only my file).

## b) PARTIALLY DONE

1. **The deploy itself.** Two blockers peeled (§16 realize; HaGeZi-dyndns), battery fully green once, build frontier advanced deep into the closure — but the toplevel does NOT build yet (§d). Nothing was switched; `/run/current-system` untouched; running-vs-pinned nixpkgs MISMATCH advisory (running f9a75f4 / pinned f4a03c0) still open — deploy-forward remains the intended resolution.
2. **`platforms/common/dns-blocklists.nix` edit uncommitted** — content final, awaiting daemon sweep or owner commit.
3. **§16 script fix verified statically** (shellcheck, bash -n) and by an equivalent manual build, but the edited realize branch itself never executed live in this session (the directory already existed post-realize, so the gate took the exists-branch). First live exercise will be the next never-realized occurrence — by design.

## c) NOT STARTED

1. **The 9-package go-modules vendorHash bump wave** (current build blocker, §d).
2. Post-deploy verification battery: anchor check (`readlink /run/current-system` vs newest `system-N-link` by NUMBER), full process-tree drain check, post-deploy smoke.
3. TODO self-harvest of this report's §f (deliberately deferred: owner directive was report-then-wait; each §f item is written to be harvest-ready verbatim).
4. Re-run of the negative-test `tileicons` group after my §16 script edit (see §e-5).

## d) TOTALLY FUCKED UP (session mistakes + current hard blocker)

**Session mistakes (mine):**
1. **First keep-going build output piped through `tail -15` — lost the entire root-failure enumeration** and forced a full re-run of a multi-minute build. This violates the standing capture-once-then-grep discipline (tee to file, then grep). The re-run (with tee) is what surfaced the real current state. Cost: one wasted heavy build on a PSI-sensitive box + 6 h of delayed truth.
2. First diagnosis eval probed the WRONG env surface (`.environment.PAP_ICONS_DIR` — pre-delegation home) and burned a heavy evo-x2 eval on it; the §16 code comment documents both surfaces and would have said so had I read the scanner before eval-ing.
3. Two full pre-deploy batteries (~5 min eval-heavy each) were run on a box the pressure gate itself flagged — the second was arguably necessary (post-fix), but I did not wait for pressure to drain first, I forced (=2) both times.

**Current hard blocker (not a session mistake — surfaced by the peeled layers):**
4. **9 distinct go-modules FOD hash mismatches** block the toplevel: cqrs-lint, go-auto-upgrade, inboxclean, mr-sync, project-dependency-graph, projects-management-automation, samber-linter, signoz, timesheet. All specified/got pairs captured in `~/.cache/kg-toplevel.log`. Attribution: HEAD `152bef10d` is a PARALLEL session's go-cqrs-lite lock float whose own commit message admits "cqrs-lint vendorHash re-stale"; §11 was green on tree a6ed4f7 at 05:24 ("35 uncached FODs built clean") and the tree has since moved 3 commits. At least some of the other 8 are plausibly the SAME masked-stale class as HaGeZi-dyndns (§11 probes only UNCACHED FODs — cached-but-stale pins are invisible to it until GC).

## e) WHAT WE SHOULD IMPROVE (systemic, observed this session)

1. **§11 blind spot — "cache warm" is not "pin correct".** §11 builds only *uncached* go-modules FODs; a stale pin whose store path exists is skipped as "satisfied" and detonates later on GC (HaGeZi-dyndns exact mechanism; likely several of the 9 vendorHash mismatches). The battery needs a cheap pin-vs-actual audit leg (the `prefetch-file` compare I ran for blocklists took ~60 s for 23 URLs) or §11's wording/verdict must stop claiming "vendorHash valid" when it only proved the uncached subset.
2. **Blocklist pins and Go vendorHashes share one failure class with two ad-hoc mechanisms.** The 23-pin audit is currently a hand-rolled loop; make it a script/check so the next masked-stale pin dies in CI, not in a deploy build.
3. **Deploy log did not capture my run's battery output** (`2026-11-12_05-24-33.log` contains zero "PapDashboard" lines; the user's 05-18-27 log has them). Battery-passed evidence for my run exists only in the session transcript (build only starts after battery exit 0). Likely the `exec > >(sudo tee …)` process-substitution interacting with the backgrounded shell — worth a look; deploy forensics doctrine treats that log as first-stop evidence.
4. **capture-once-then-grep must include MY OWN ad-hoc builds** — tee, never tail, on anything whose full output could matter (repeat of §d-1; it keeps being relearned).
5. **Negative-test surface drift**: `scripts/negative-test-lints.sh` line ~422 still builds `config.systemd.services.papdashboard.environment.PAP_ICONS_DIR` (pre-F3-delegation surface) while §16 now scans both surfaces and my realize uses `services.papdashboard.iconsDir`. The control case should be repointed (or asserted equal to iconsDir) so the selftest actually covers the gate I edited.
6. **Shared-tree quiescence**: two deploy batteries + two keep-going builds while parallel sessions floated the lock between them. The 2026-10-25 quiescence pattern (eval-relevant mtimes stable ≥5 min) should also gate MY redeploys, not just be lore.

## f) NEXT (harvest-ready; ordered)

1. Apply the 9 go-modules vendorHash bumps using the specified/got pairs in `~/.cache/kg-toplevel.log` (verify each `got` with the pin-audit mindset — they are nix-measured values from this session's build; cqrs-lint's re-pin belongs to whichever session owns the go-cqrs-lite float).
2. Re-run `nix build --keep-going .#nixosConfigurations.evo-x2.config.system.build.toplevel` (tee!) until zero root failures.
3. Redeploy (`nix run .#deploy`; force-level per pressure at the time) — battery should now pass end-to-end.
4. Post-deploy anchor check: `readlink /nix/var/nix/profiles/system`-style verify — `readlink /run/current-system` == newest `system-N-link` by NUMBER (never `ls -t`); wait for `pgrep -f 'nh os|switch-to-configuration'` to be EMPTY first.
5. Run post-deploy check surface (papdashboard icon probes ride it) and confirm `icons_ok` gauge = 1.
6. Commit/attribute `platforms/common/dns-blocklists.nix` (if the daemon hasn't) — message should name the masked-stale mechanism.
7. Close the running-vs-pinned nixpkgs MISMATCH advisory by confirming the deployed system was built from f4a03c0.
8. Add §11 pin-audit leg (uncached-FOD probe + cached-pin prefetch compare) or reword §11's pass line — file as gate change with negative-test coverage.
9. Script the blocklist pin audit (`scripts/audit-blocklist-pins.sh` style; ~60 s runtime) + wire into CI or the battery.
10. Re-run `scripts/negative-test-lints.sh` tileicons group against the edited §16; repoint its control build to the post-F3 env surface(s).
11. Investigate the deploy-log battery-capture gap (process-substitution tee under backgrounded shells).
12. Extend the 2026-10-25 quiescence gate pattern into a pre-deploy helper (eval-relevant mtime stability + clean tree) so agent deploys stop racing parallel lock floats.
13. Investigate the 05:24 pressure-gate signature (idle-disk D-state phantom, kworker `events_unbound`, ghostty scopes 73–79% io.pressure some avg10) — corpse-pile class, distinct from the real IO storm in the owner's original paste.
14. The 14 failed units from §6 of the battery (bank-sync-qonto-corpus, btrbk-forgejo-clean — new since yesterday's 13 — btrfs-verify-*, forgejo-github-sync, forgejo-ssh-keys, health-dashboard-rediscover, inboxclean-sync, media-atlas-umap, monitor365-pool-copy, …) — pre-existing, untriaged by this session; the +1 delta deserves a look.
15. §8 stale build sandboxes (advisory): `sudo systemctl start nix-build-cleanup.service` — owner-run or next yolo session.
16. Harvest this §f into `TODO_LIST.md` + owning domain libraries on owner go-ahead (items 1–5 deploy-critical; 8–12 pipeline; 13–15 stability/services).
17. Record the §16 realize-branch fix in the papdashboard runbook's §16 paragraph (one line: realize now uses the flake attrpath).

## g) QUESTIONS FOR THE OWNER (cannot be answered from the tree)

1. **Who owns the go-cqrs-lite float wave?** HEAD `152bef10d` (go-cqrs-lite → tip, "cqrs-lint vendorHash re-stale") is a parallel session's work. Should I take the full 9-hash vendorHash bump wave now, or is that session mid-flight on it (in which case me touching the same packages guarantees a mid-edit race)?
2. **Deploy urgency vs quiescence:** the tree moved 3 commits during this session's deploy attempts. Fix-and-deploy immediately (risking another mid-wave battery), or hold until the parallel sessions go quiet (quiescence gate) — the running system is a day+ behind on nixpkgs and carries the MISMATCH advisory?
3. **§11 scope change needs a policy call:** making the battery verify cached pins too (prefetch-compare on every go-modules FOD + blocklist, ~minutes of network per battery) trades deploy latency for killing the masked-stale class that ate today. Approve the latency cost, or keep §11 uncached-only and accept GC-timed detonations?

---

**Evidence files:** `~/.cache/kg-toplevel.log` (full keep-going errors, 111 error lines, 9 root mismatches) · `~/.cache/hagezi-pins.tsv` (audit pin set) · `/var/log/systemnix-deploys/2026-11-12_05-18-27.log` (owner's blocked run) · daemon commits `00080450` (§16 fix), `152bef10d` (parallel float).
**Files changed this session:** `scripts/pre-deploy-check.sh` (§16 realize, committed), `platforms/common/dns-blocklists.nix` (dyndns re-pin, uncommitted at authoring).
