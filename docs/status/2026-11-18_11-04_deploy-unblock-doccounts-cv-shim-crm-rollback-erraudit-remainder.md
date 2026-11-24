# 2026-11-18 11:04 — Deploy-unblock arc: doc-counts stamp, cv vendorHash shim (22nd re-stale), crm lock rollback — STILL BLOCKED on erraudit FOD

Session start: owner pasted the 2026-11-17 22:37 deploy log (exit 1, blocked at §1
flake check: `doc-counts: FEATURES packages asserts 53, eval truth is 54`) with "fix?".
Later ordered: "deploy now no matter the I/O pressure!" (DEPLOY_FORCE_PRESSURE=2 class).
Session end state: **three deploy attempts, all build-phase failures, deploy still
blocked** — the blocker moved 3 times (doc-counts → cv FOD → crm compile → erraudit FOD).
Report written on owner request; work stopped at the erraudit failure, NOT fixed.

## Timeline (all first-hand this session)

| Time                  | Event                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 11:0x-1x (pre-deploy) | Diagnosed doc-counts drift: `pkgs/qmd-gpu.nix` **added** in HEAD daemon commit `98dfd86` (package count 53→54, FEATURES.md unstamped). Re-stamped FEATURES.md line 33 (54 + history entry per the established pattern). Verified `nix build .#checks.x86_64-linux.doc-counts` green + full `nix flake check --no-build` green (log `~/.cache/fc-doccounts-fix.log`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| 07:29-07:31           | Deploy #1 (`DEPLOY_FORCE_PRESSURE=2`; PSI gate showed real storm: io some avg10 47-72%, sda/sdb/sdc/sdd 87-101% busy — owner override active). Doc-counts PASSED; **failed**: `cv-ffb48b7-go-modules` FOD hash mismatch — specified `sha256-voTiN7nblBUIg89J/8kpG32xU/jPpLSA9tzWBa49vlQ=`, got `sha256-H+R596Cn+10IbFUCujrdJk7l9Nf/ptMXz4fsyGpRLng=`. Log `/var/log/systemnix-deploys/` (22:37 + 22:24 logs from owner's own attempts precede).                                                                                                                                                                                                                                                                                                                                                                                                                               |
| 07:3x-07:5x           | cv forensics: SystemNix consumes `inputs.cv.packages…default` directly (`modules/nixos/services/cv.nix:238`); lock at `ffb48b7`; upstream bakes `voTiN7…` at that rev (CV repo `nix/packages.nix:123`); `cv.nix` carries a 21-entry vendorHash-shim ledger with doctrine "re-add ONLY via first-hand nix-hash-fix evidence, never by hand". Second proof: `nix build '/nix/store/6lx7jpl2f09ll0bwr48f2wh9fllw1w4d-cv-ffb48b7-go-modules.drv^*'` → same got hash (two proofs agree; log `~/.cache/lockfloat/proof2.log`). Wrote shim: `cvPkg = …default.overrideAttrs { vendorHash = "sha256-H+R596Cn+10IbFUCujrdJk7l9Nf/ptMXz4fsyGpRLng="; }` + TWENTY-SECOND ledger entry. Eval probe: new derivation `w6y0jjf1…-cv-ffb48b7` ≠ old `vyqhizqy…` (shim effective).                                                                                                             |
| 07:52-07:54           | Deploy #2: **cv FOD green** (package reached buildPhase) — **failed**: `kith-crm-4bdc3c2…` compile break: `undefined: templ.ResolveAttributeValue` / `templ.JoinURLErrs` in `internal/httpapi/*_templ.go` (APIs deleted in templ 0.3.1100).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| 07:5x-08:1x           | crm forensics (local checkout `~/projects/crm`): locked rev `4bdc3c2` (2026-11-17 "enable templ-freshness gate" C9 wave) has **3 dead-API calls** in `companies_templ.go`; go.mod requires `templ v0.3.1100` since `13ae851` (2026-11-04); **green rev `b7f8615`** (2026-11-15 — the RUNNING system's binary `yflwdr0bvkjd9w2l5b4g384mb5n4ljpb-kith-crm-b7f8615…`) has **0** dead calls; tip `b3b1382` (+2 pin-convergence commits, == origin/master) is equally broken (no templ file changes at tip). **Rolled `flake.lock` crm node back to `b7f8615`** verbatim from lock history (commit `0f6af1a46`: narHash `sha256-h0DL96…`, revCount 1344, lastModified 1794736791; url/ref untouched — no pin-audit exposure). Documented the rollback in `flake.nix`'s crm comment block. Eval probe: crm ExecStart = **byte-identical** to the running store path (zero rebuild). |
| 08:10-08:12           | Deploy #3: **failed**: `erraudit-d7e0f79-go-modules` FOD mismatch — specified `sha256-POIy8+72rjYmP+FMhXim8MbV8tu6NetX9M0m4BsEGWM=`, got `sha256-YZ3Wmtfwt5XFbI+Syvfaewp6XCQYyZ1AZO03noGYAsQ=` (14s installPhase; cv again mid-build fine). **NOT fixed — stopped here on owner request.**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 11:04                 | This report.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |

## Key finding: the module-serving truth FLAPPED between 22:37 and 08:12

Last night's §11 preview (owner's paste, tree `98dfd86*` — same tree as today) built
**12 uncached go-modules FODs clean**; today the SAME erraudit drv (no erraudit-relevant
change in my edits: FEATURES.md, cv.nix, flake.lock crm node, flake.nix comment)
mismatched at 08:12, and cv re-staled in the same window. This is the documented
re-serve event class (2026-10-25 pma RE-STALE precedent: "a re-served upstream
dependency moved BOTH revs' module graph"). Consequence: stamping erraudit to
`YZ3Wmtfw…` may itself flap back — **re-probe immediately before fixing** and expect
the cv shim + erraudit hash to be one treadmill wave, not two independent fixes.

## a) FULLY DONE

1. **doc-counts drift root-caused + fixed** — qmd-gpu package addition (`98dfd86`) unstamped; FEATURES.md re-stamped 53→54 with ledger entry; `checks.doc-counts` builds green; full `nix flake check --no-build` green.
2. **cv vendorHash re-stale root-caused + shimmed with first-hand evidence** — two agreeing proofs (`H+R596…`), shim written in the exact historical shape (`overrideAttrs`), TWENTY-SECOND ledger entry added, proof log kept at `~/.cache/lockfloat/proof2.log`. Proven effective: deploy #2/#3 pushed cv past the FOD into buildPhase.
3. **kith-crm compile break root-caused + lock rolled back to the running-green rev** — templ 0.3.1100 vs stale generated files at `4bdc3c2`+tip; lock at `b7f8615` (running binary's rev, byte-identical store path = zero rebuild); rollback documented in `flake.nix`; upstream repair path identified (templ regen, blocked on push).
4. Pre-reads done per session discipline (docs/status grep, git state, foreign-diff review — the staged `pkgs/qmd-gpu.nix` wrapper fix + CHANGELOG entry identified as a parallel session's in-flight work and left untouched).

## b) PARTIALLY DONE

1. **The deploy itself** — 3 attempts, each unblocked one layer further (doc-counts → cv FOD → crm compile), now blocked on erraudit FOD. All battery sections that ran were green except the moving target.
2. **flake.lock crm rollback** — lock + comment done; the _re-float_ (post-upstream-fix) is queued upstream-side.
3. Working tree carries uncommitted session edits (FEATURES.md, cv.nix, flake.nix, flake.lock) + foreign staged files; daemon will sweep — the tree is NOT the deployed system yet.

## c) NOT STARTED

1. erraudit vendorHash fix (the current blocker — `lib/lars-packages.nix`).
2. A `--keep-going` toplevel enumeration (the step that SHOULD have run first — see §d).
3. Post-deploy verifications (anchor check, cv-server smoke incl. the rev-independent boot-rehydration SIGSEGV watch, qmd-gpu CLI/`qmd mcp` verify for the foreign wrapper fix, textfile-collector/monitor365 recovery checks).
4. Upstream legs: cv hash paste-upstream; crm templ regeneration (both push-gated).

## d) TOTALLY FUCKED UP (honest)

1. **MISSED the `--keep-going` critical rule — the session's defining mistake.** AGENTS.md: "when the toplevel build fails, run `nix build …toplevel --keep-going` BEFORE fixing anything: one pass enumerates ALL root failures." I instead fixed one failure per deploy cycle and paid 3 sequential build/eval ramps (~40 min wall-clock, storm load on top). One keep-going pass after deploy #1 would have surfaced cv FOD + erraudit FOD (+ likely the crm compile break) simultaneously.
2. **False-evidence near-miss on the "second proof"**: `nix build /nix/store/…drv` (no `^*`) treats the .drv FILE as the installable — rc=0, zero output, builds NOTHING. I briefly read empty output as ambiguous, then nearly mistook a follow-up rc=0 as "FOD green"; rescued only by `nix path-info` (output invalid) and the corrected `'^*'` form. Also `${PIPESTATUS[0]}` silently printed empty in this shell (unsupported) and I didn't flag it.
3. **Accepted an empty proof log momentarily** — the first background proof job's log (`float-proof-20261118-073517.log`) was empty; convention demands the proof log BE the evidence. Kept as-is (evidence lives in `proof2.log` + deploy logs) but the hygiene slip is real.
4. **Probe detour**: spent a cycle discovering `checks.x86_64-linux.cv` is a VM test (heavy, unusable as a cheap FOD probe) instead of checking its nature first.
5. **Two `rg -r` hook trips** in one session (the documented third-strike class) — hook caught both, zero damage, but the reflex is apparently not installed.
6. Net outcome: **no successful deploy at session end** — the owner's "deploy now" order is unfulfilled after 3 attempts.

## e) WHAT TO IMPROVE

1. **keep-going FIRST, always** — on the very next blocked deploy, before ANY fix: `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link 2>&1 | tee ~/.cache/<topic>/keepgoing.log`.
2. **Document the `nix build <drv>` silent-no-op trap** (`^*` needed to build outputs; bare .drv path = rc=0 no-op) in the AGENTS.md shell-trap list — queued below (§f).
3. **Never cite a probe without verifying its log content** — an empty log is a failed probe, not a pass (sibling of the "empty read is never evidence" rule).
4. **FOD-storm playbook**: when ≥2 module-graph hashes move in one window (cv + erraudit today), assume an active re-serve event; enumerate with keep-going, re-probe each hash immediately before stamping, and consider batching all hash fixes into ONE deploy wave.
5. **§11 blind spot**: the pre-deploy FOD preview excludes cv (documented) — today showed the excluded surface is exactly where storms bite; a keep-going toplevel complement when §11 passes but suspicion remains is cheap insurance.

## f) NEXT (this arc, roughly in order; not padded to 50)

1. `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link` — enumerate ALL remaining root failures in ONE pass (erraudit at minimum; expect possible further FODs).
2. Re-probe erraudit FOD (`nix build '<drv>^*'` form) immediately before stamping — flap risk is live; if it flapped BACK to `POIy8…`, skip the edit entirely.
3. Stamp erraudit vendorHash in `lib/lars-packages.nix` (`POIy8…` → `YZ3Wmtfw…`) with first-hand proof logged under `~/.cache/lockfloat/`-style paths.
4. Re-fire `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` (owner override stands per directive this arc).
5. Post-switch: anchor discipline — wait for FULL process tree (`pgrep -f 'nh os|switch-to-configuration'` empty), compare `readlink /run/current-system` vs newest `system-N-link` BY NUMBER (never mtime).
6. Post-switch: cv-server smoke — `journalctl -u cv-server` boot-rehydration watch (SIGSEGV class is rev-independent per ledger; nil-guard fix is upstream's), `/health/live` via gatus or openssl probe.
7. Post-switch: verify qmd-gpu (foreign wrapper fix rides this deploy): `qmd --version`-class CLI check + `qmd mcp` spawn per the qmd pin LIFT note.
8. Post-switch: `nix run .#post-deploy-check` — expect the textfile-collector/monitor365 warnings to clear only if the deploy restarts those units; triage what remains.
9. Triage the 17 failed units from the pre-deploy battery (bank-sync-qonto-corpus, inboxclean-sync, forgejo-github-sync, health-dashboard-rediscover, monitor365-server, post-crash-calm-gate, service-health-check, system-health-metrics, crm-alarm-byphone…) — deploy may fix some; the rest need per-unit journal pulls.
10. Upstream (push-gated): paste cv `H+R596…` vendorHash into the CV repo, push, re-lock, DROP the SystemNix shim (22nd cycle's close-out).
11. Upstream (push-gated): regenerate crm `*_templ.go` for templ 0.3.1100 (or make their templ-freshness gate block the commit), push, re-float the crm lock off `b7f8615`.
12. CHANGELOG entry for the wave once it actually lands (rollback + shim + stamp — the CHANGELOG already carries the parallel sessions' "deploy pending" entries; add mine at deploy time).
13. Investigate the flap source when calm: which dependency re-served (cv + erraudit share first-party graphs — `go mod` graph diff between a green and mismatched build of the same drv would name it).
14. `rsend`/`send` "Auto-derived new-metric loan" WARN from the battery — looks like the loan heuristic parsing the gatus DNS value-match endpoint names ("Resend DKIM / send CNAME / rsend CNAME"); verify it's not a misparse.
15. `check-contact-registry-drift.sh` missing (§21 advisory WARN, degrade contract honored) — create the script or remove the reference.
16. 12 stale build sandboxes — `sudo systemctl start nix-build-cleanup.service` (owner/sudo).
17. Document the `nix build <drv>` no-op trap + `${PIPESTATUS}` unavailability in AGENTS.md shell-trap list (queued, pipeline).
18. Watch journal vacuum clock (7.4G vs SystemMaxUse 8G — §15 was green but the margin is thin).
19. DAS storm triage (sda/sdb/sdd ~100% busy through the session; sdc idle) — likely the rust-cache/monitor365 archiving arcs; the 07-04 rustcache status doc owns context.
20. After deploy green and before ANY reboot: `nix run .#pre-reboot-check`.

## g) QUESTIONS FOR THE OWNER (cannot be resolved from the repo alone)

1. **Push authorization standing?** The repo doctrine says LarsArtmann inputs are "repaired in their own repo, pushed, and the SystemNix input re-floated" (2026-11-14 directive), but `cv.nix`'s 2026-11-14 ledger entry records "fix committed in CV 9e3687b97, unpushed, **owner-push gated**". Which stands as the default: may sessions push owner-repo fixes (cv hash paste, crm templ regen) when ready, or is every push individually gated?
2. **Flap policy for erraudit-class re-stales**: same drv built clean 22:37, mismatched 08:12 (active re-serve event). Restamp to today's truth (`YZ3Wmtfw…`) accepting possible flap-back thrash (the cv-shim treadmill doctrine), or hold the deploy until the module-serving state settles — and if hold: what signal counts as "settled"?
3. **Foreign in-flight work riding deploys**: the staged `pkgs/qmd-gpu.nix` wrapper fix + rust-cache-gc v2 (CHANGELOG says "deploy pending") belong to parallel sessions. My deploy attempts carried them via working-tree eval. Carry-and-deploy on the next attempt too, or pause for those sessions to land/verify theirs first?

## Harvest note (self-harvest §f at authoring time)

- §f.1-3 (keep-going + erraudit wave) → queued `[ready]` in `TODO_LIST.md` → pipeline + full entry in `docs/todo/pipeline.md`.
- §f.10-11 (cv paste-upstream, crm templ regen) → `[blocked:push]` library entries in `docs/todo/upstream.md` (NOT queued — pushes are banned for agents pending g.1).
- §f.17 (AGENTS shell-trap doc) → queued `[ready]` in `TODO_LIST.md` → pipeline.
- Everything else §f is deploy-gated follow-through of this arc's own rows or pre-existing runtime state owned by other status docs (rustcache/07-04) — deliberately not duplicated.
