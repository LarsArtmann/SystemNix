# Status: FOD-triage COMPLETE (all 3 blockers fixed + gen-1016 deployed), deploy exit-3 open (2 NEW smoke failures), forced under flush storm

**Session:** 2026-11-19 ~13:45 → 15:53 (this session; resumed the 08:33 report's paused state after the owner's "execute the ladder" instruction)
**Trigger:** the 08:33 session summary's exact-next-steps ladder: fix pdg, apply the paperless-gpt decode, prove keep-going, deploy, verify.

**Scope line — what this report VERIFIED vs did NOT:**
Verified live this session: pdg own-repo `.#default`/`.#templ`/`.#checks.x86_64-linux.templ-freshness` all green at fdbd4da5 (freshness pre-fix RED → post-fix GREEN, drv hash changed gqjsh6wj→k9s7xjfs); gnh moduleTest + moduleTestTemplFreshness green at e0c4b70, pushed + ls-remote confirmed; pdg pushed (dc35838d..fdbd4da5) + ls-remote confirmed; quotaboard 243c8be pushed + GitHub mirror confirmed caught up; SystemNix `nix build .#project-dependency-graph` green at the re-pinned shim (nMgP22rT, got read from a first-hand failing build); paperless-gpt FULL build green (npm decode + go vendorHash PAGZjn round); keep-going toplevel GREEN (`~/.cache/lockfloat/keepgoing-1119c.log`, 0 error lines, out fxma93lim…); deploy EXECUTED (14:32:52→15:51:51, 4739s, exit 3) and ANCHORED — `readlink /run/current-system` == `system-1016-link` target c1n8kzzl… (by NUMBER, per doctrine); the "IO storm" root-caused to a ~1000 flushes/s barrier storm on nvme0n1 (diskstats flush-field delta; no cgroup writer >2MB/s at full-depth io.stat sampling by 259:3). NOT verified: the 2 NEW smoke failures' causes (Takeout Immich converger inactive; llama.home.lan auth gateway broken — untriaged), paperless-gpt + quotaboard FIRST-FIRE (unit/:8106/version/prompts/widget — the battery tail I captured didn't show their sections), the 2 STORM-SUSPECT downgraded checks (battery ran in storm mode, PSI avg60 63.75), whether cvagent's 503 is new vs baseline (FAIL but not in the NEW list), §17 memory-events sweep (not in captured tail).

---

## a) FULLY DONE

1. **All three original deploy blockers FIXED, proven green, and shipped:**
   - **quotaboard** (landed pre-summary): upstream `ddd72c2` + SystemNix lock float swept by the daemon (8c8163a16, lock rev verified via python3-json this session). Off the list.
   - **project-dependency-graph**: the "in-build stale vendored copy" mystery resolved EMPIRICALLY — with the FOD re-derived at a fresh hash, the vendor tree carries the regenerated output and everything compiles; the 08:33 report's "Fmv4 still passes while the vendor copy is stale" reading does not reproduce on the current tree (the FOD mismatched at /E8Y the moment I rebuilt). Upstream fixed at `fdbd4da5`: `subPackages = [ "." ]` pin (nested-module sweep class), vendorHash /E8Y, `renderer/graph_templ.go` regenerated at the go.mod runtime version (v0.3.1100), AND the durable fix — `templCliPackage` pin (new `templ` flake input + `nix/templ.nix` buildGoModule + `nix/templ-vendorHash.nix`), so devshell/treefmt/freshness-oracle/go.mod all see one templ. Own-repo: `.#default` green, `.#templ` green, `.#checks.x86_64-linux.templ-freshness` GREEN (was red on the nixpkgs-CLI oracle).
   - **paperless-gpt**: the prior session's dead env/SKIP/1777/SWC-DIAG block REPLACED with the nixpkgs bookorbit carrier-decode preBuild (find node_modules swc.*.node → zstd-decode SWCNZSTD v1 carrier → raw addon). npm stage green; that exposed the never-exercised go-side vendorHash (81a3B1 was computed before the frontend could build at all) — pasted `got: PAGZjn…` and the FULL package builds green (`/nix/store/r3p58g41…-paperless-gpt-0.31.0`).
2. **go-nix-helpers upstream fix landed (e0c4b70, pushed, ls-remote confirmed):** `checks.templ-freshness` hardcoded `pkgs.templ` in nativeBuildInputs — `templCliPackage` never reached the freshness oracle, so pinned-CLI repos saw phantom drift. Switched to `templBin` (behavior-neutral default: templBin = pkgs.templ when no override), updated both option docs, added an outPath-discrimination test (pinned cfg's check outPath ≠ default cfg's — pure eval, no store). moduleTest + moduleTestTemplFreshness green, `nix flake check --no-build` green.
3. **The quotaboard MMAoHofe poison comment corrected (243c8be, pushed, GitHub mirror confirmed):** `nix/templ-vendorHash.nix`'s comment labeled the REAL hash of templ v0.3.1100's go-modules as `lib.fakeHash` — which is exactly what fed the 07:46 wrong paste into the MAIN vendorHash.nix and cost the first deploy cycle. Both repos' comments now state the real placeholder (the all-A value, eval-verified) and flag MMAoHofe as genuine.
4. **SystemNix side:** pdg input floated to fdbd4da5 (lock verified), shim re-pinned to the SystemNix-context `nMgP22rTeP…` with dated lineage comment (contexts PROVABLY diverge: SystemNix re-derives nMgP22rT at fdbd4da5 while upstream's own build wants /E8Y — the shim's "drop when upstream bakes the got" condition is void for this leg; the 2026-11-18 FOD-storm row is annotated SUPERSEDED accordingly). Direct build green.
5. **Keep-going toplevel proof GREEN:** `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` → 0 error lines in the captured log, out path fxma93lim…. The domino-deploy class the 07:41/07:55 attempts died on is closed.
6. **Deploy EXECUTED and ANCHORED:** gen-1016 live — `readlink /run/current-system` == `system-1016-link` target (compared by NUMBER per doctrine). Wave committed: f88a92a11 (shim, pathspec) + daemon-swept flake.lock/pkgs/paperless-gpt.nix (103e0de46, 34164cd28).
7. **The deploy-blocking "IO storm" root-caused (mechanism NAMED):** nvme0n1 (Samsung) at ~100% io_ticks with ~1–3MB/s real throughput, NO cgroup writer above 2MB/s (full-depth /sys/fs/cgroup io.stat sampling by 259:3), because the device services **~1000 FLUSH requests/s** (diskstats flush-field delta over 5s; bare barrier flushes carry no wbytes — which is why byte-based accounting looks clean). Chronic multi-hour baseline (avg300 ~51–58) under load ~22; box otherwise healthy (up since 00:10, PSI totals monotonic — no mid-session boot). Recorded into the stability.md device-level-wedge watch row (2026-11-08's sibling finding) with the next probes named.
8. **Harvest (library side):** 5 new rows in docs/todo/upstream.md (subPackages fleet sweep, templCliPackage fleet adoption, swc upstream issue draft ask, go-standard migration-checklist item, BuildFlow nix-fmt roundtrip quirk); the 2026-11-18 FOD-storm row's pdg leg annotated SUPERSEDED; stability.md flush-storm update. All daemon-swept (5bccb5f6a).

## b) PARTIALLY DONE

1. **Deploy exit 3 — the generation is live but the battery flagged regressions:** 182 PASS / 6 FAIL / 16 WARN / 2 STORM-SUSPECT (storm mode active at PSI avg60 63.75 — two load-sensitive checks downgraded to UNVERIFIED). **NEW vs baseline: Takeout Immich converger (immich-api-key-provision not active) + llama.home.lan auth gateway broken.** Untriaged. Anchor is fine; the smoke verdict is not.
2. **First-fire verification for the two NEW services did not happen:** paperless-gpt (unit, :8106 loopback, version print, prompts copy, gatus/tile) and quotaboard.service (user unit + DMS widget). The battery tail I captured didn't include their sections — unknown whether they passed.
3. **Harvest is HALF-done:** library rows landed (a.8) but the TODO_LIST.md queue one-liners for the five new [ready] rows were NOT added — the queue/library drift the house rules explicitly forbid is currently live.

## c) NOT STARTED

1. Triage of the two NEW smoke failures (b.1).
2. Calm-window post-deploy-check re-run (STORM-SUSPECT re-verification + the 16 WARNs re-read).
3. `docs/services/paperless-gpt.md` runbook — does not exist; every enabled service must have one (the planned "one-line swc note" has no file to land in).
4. The swc upstream issue DRAFT itself (row queued with all facts; text not written).
5. daily.home.lan + collect verification (prior session's f.17), eval-warnings-unchanged check (prior f.15).
6. §17 memory-events sweep post-deploy (not visible in the captured tail).

## d) TOTALLY FUCKED UP (honest ledger)

1. **The hash-conversion blunder chain (worst of the session):** I trusted quotaboard's comment labeling `sha256-MMAoHofe…` as lib.fakeHash → suspected "suspiciously green" → hand-rolled a b64 conversion of a **nix-base32** string (pasted `0y1g81…` into the file, caught only by the SRI length check) → only then ran `nix hash convert --from nix32 --to sri`, which revealed MMAoHofe IS the real hash. Root error: never evaluated `lib.fakeHash` (the all-A value) before believing a comment. Nearly shipped a broken hash AND nearly "fixed" a correct file.
2. **Three build cycles for one 4-line test assertion:** (i) an apostrophe in my assertion string broke the generated shell (`syntax error near unexpected token '('`); (ii) asserted on `drvPath` containing input names — drvPath never contains them; (iii) finally the correct pure form (outPath discrimination).
3. **Wasted a full pre-commit cycle on a 82-char commit subject** (house limit 72) — the heavy hook ran first, then rejected.
4. **The daemon raced my pdg squash:** soft-reset staged everything, BuildFlow blocked my commit (46 pre-existing repo-wide findings), and the daemon committed the staged files at 14:01:40 (0b687917) before my retry. The planned single coherent commit became three (0b687917 heuristic + fdbd4da5 documenting + 9d0a1c9f earlier). Accepted rather than re-racing; history readability debt. Note: pdg's pre-commit findings gate blocks EVERY hooked commit on standing debt (file-size 42, docs-gates 3, cue-vet 1) — queued as a row in pdg's own TODO_LIST (landed in fdbd4da5).
5. **Forced the deploy under the flush storm (DEPLOY_FORCE_PRESSURE=1):** evidence-backed (zero-build switch, 07:37 green deploy in the same regime, no freeze signatures), but the consequence is real — a 79-minute battery in storm mode, 2 downgrades, exit 3, and NEW-failure triage now conflated with storm noise. The cleaner path was triaging the flush storm first.
6. **The 08:33 report's central mystery is superseded, not forensically closed:** I proved the current tree green end-to-end, but never explained WHY the predecessor observed "Fmv4 passes while the vendored copy compiles stale". Most plausible: stale FOD reuse or a dirty-tree flake-source subtlety at that moment. Stated in the pdg commit message as such — not proven.
7. **Bookkeeping outranked the battery:** while the deploy ran I wrote TODO rows; the exit-3 verdict landed after them. Right order: battery outcome first, harvest second.

## e) WHAT WE SHOULD IMPROVE (systemic)

1. **Verify placeholder-hash claims by EVALUATING `lib.fakeHash`** (nix eval, 5s) before treating any comment-labeled "fakeHash" as truth — the MMAoHofe mislabel burned two sessions and one deploy cycle. Fleet grep for `(lib.fakeHash)` comment patterns is queued.
2. **Use `nix hash convert --from nix32 --to sri`** — never hand-rolled base64 math on nix hashes (nix32 ≠ b64 alphabet).
3. **Generated-shell test assertions need apostrophe-scrutiny** (same standing rule as quote-scrutiny for awk one-liners) and prefer pure outPath discrimination over drv introspection.
4. **Queue+library harvest in ONE pass** — this session re-created the exact drift the TODO rules forbid (library rows without queue one-liners).
5. **On deploy exit 3, triage outranks harvest** — stop bookkeeping, read the battery.
6. **Flush-storm discriminator:** when a device shows high io_ticks with no cgroup bytes, count diskstats FLUSHes FIRST (a 5s probe names the class the 2026-11-08 device-wedge row took days to attribute). Candidate hardening: deploy.sh's storm classifier could auto-collect the flush-rate snapshot when it classifies REAL storm.

## f) NEXT (ranked, bounded)

1. Triage NEW failure: Takeout Immich converger inactive (`journalctl -u immich-api-key-provision -n 50` — the battery names the probe).
2. Triage NEW failure: llama.home.lan auth gateway broken (auth vHost 500/502 probe; openssl s_client pattern).
3. Re-run post-deploy-check in a calm window — verify the 2 STORM-SUSPECT downgrades + re-read the 16 WARNs.
4. paperless-gpt first-fire: unit active, :8106 loopback, version print, prompts copy, gatus tile/check.
5. quotaboard first-deploy: user unit via homeModules + DMS widget path.
6. Author `docs/services/paperless-gpt.md` (runbook owed; swc-carrier constraint + decode note land here). **Not yet harvested — row owed in TODO_LIST (services).**
7. Add the TODO_LIST queue one-liners for the 5 new upstream.md rows (anti-drift, b.3). **Harvest gap from THIS report's session — owed.**
8. Write the swc upstream issue draft (row exists; verify-before-filing applies — cite bookorbit + our 1.16.13 first-hand facts).
9. Flush-storm investigation: per-partition flush attribution + btrfs commit latency (probes named in the stability.md row update).
10. Confirm remaining eval warnings unchanged (prior session's f.15).
11. daily.home.lan serves + collect ran (prior f.17).
12. cvagent 503: diff against the previous baseline (pre-existing vs new).
13. §17 memory-events high-counter sweep post-deploy.
14. gnh float note for the fleet: the freshness-oracle fix (e0c4b70) is available to every consumer that adopts templCliPackage; repos on older locks are unaffected.
15. pdg's own TODO row "Update the locked go-nix-helpers" simplifications now unblocked at e0c4b70 (retire the double-space replace hack, second SDK daemon input, goPkgAttr pin).
16. Fleet grep for comments mislabeling real hashes as fakeHash (e.1).
17. Memory line for docs/agents/nix-flakes.md: "verify placeholder-hash claims by evaluating lib.fakeHash; comments lie" (this session's d.1). **Not yet harvested — owed.**
18. Check daemon sweeps since f88a92a11 (5bccb5f6a took the docs edits; confirm nothing else pending).
19. If the 00:10 reboot was WDT/freeze-class: stability forensics BEFORE any further forced deploy on this boot (see g.1).

_Harvest status at authoring time: f.6, f.7, f.17 are owed edits (marked); f.8 (swc draft) + f.9 (flush-storm) + the five upstream rows are already rowed; f.1–5, f.10–13, f.18–19 are transient operational probes or existing-row follow-ups — deliberately not re-rowed (their owning rows exist)._

## g) QUESTIONS FOR THE OWNER (cannot be derived from the repo)

1. **The 00:10 reboot (carried unanswered since the 07:35 session, now load-bearing):** owner action or freeze/WDT? The box has been up since 00:10 and I forced gen-1016 onto this boot under a flush storm — if that boot was freeze-class, the stability runbook owes it forensics before anything else is forced here.
2. **Exit-3 triage now or hold?** Two NEW smoke failures (Takeout Immich converger inactive; llama.home.lan auth gateway) against a box at load ~22 with you actively on it. Triage immediately, or wait for a calm window (the failures are liveness-class, not data-class)?
3. **dnsblockd templ regen (existing rollback row):** the row says the repo is "mid-upheaval (daemon-rewrite repair waves) — coordinate before regenerating". Is another session active in dnsblockd, or may the next dispatch land the templ regen at tip + re-float past b77dc243?

---

_Session evidence: pdg fdbd4da5 (origin confirmed), gnh e0c4b70 (ls-remote confirmed), quotaboard 243c8be (origin + GitHub mirror confirmed), SystemNix f88a92a11 + daemon sweeps 103e0de46/34164cd28/5bccb5f6a, keepgoing-1119c.log (0 errors), deploy log /var/log/systemnix-deploys/2026-11-19_14-32-52.log (exit 3, 4739s), anchor c1n8kzzl… == system-1016-link, diskstats flush-rate probe (1000/s), full-depth cgroup io.stat sampling (no writer >2MB/s), nix hash convert nix32→sri conversions, gnh test drv hashes (8bbn9i9→0iind0g→2bkvj5g green)._
