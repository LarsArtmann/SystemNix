# Session status: second lock-float wave — registry re-derive, keep-going proof, cv root cause, and the float-procedure ORDER fix

**Date:** 2026-10-25 18:11 CET · **Instance:** Crush (this session, DB id `fcdbbbe4-a271-475c-9ac6-0c667aa1c2ec`, title "Fix Properly with Step-by-Step Verification")
**Scope:** the lock-float gate that went RED again at 15:00 during my own session. Work window of record: **15:03–15:20**; this report is written at **18:11** after a ~3 h pause (tree moved underneath me — see §b/§d).
**HEAD trail I observed:** `21e8f4305` (15:01 daemon commit carrying the owner's 15:00 lock float) → `c645392a0` (15:12 daemon commit carrying a *second* lock write) → *(3 h gap)* → `0910cce2a` (current, tree clean).
**Live deploy state at report time:** `/run/current-system` = `f485prqh8ka1zybwzwg47s5f8lhy0c4a-nixos-system-evo-x2-26.11.20261015.fe13242` == `system-948-link` target. Anchor verified by generation NUMBER. **I did not deploy anything.**

---

## Context in one paragraph

The session opened on a tree whose lock-float eval gate was RED again: 7 root inputs had floated past `flake/expected-locks.nix`. I re-derived the registry mechanically (diff = exactly the 7 revs), opened the gate, ran the documented `--keep-going` proof (captured to a file, **not** piped), and reduced 23 error lines to **exactly one root cause**: the cv `go-modules` FOD. An upstream-first probe through our own lock reproduced the same drv path and the same mismatch, proving the stale literal is **upstream-baked**, not our shim. I then removed a dead shim value left over from the earlier session, and — the durable outcome — fixed the float procedure's documented ORDER, which had been impossible to follow since the gate was introduced. While I was reading `cv.nix` to apply the got hash, the run paused for ~3 h; a parallel session resolved cv with a *different* literal and deployed gen 948. The tree is green and anchored, but two of my own leftovers remain open and one diagnosis (my got vs the live literal) is unexplained.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Established the *actor* behind the recurring blanket lock floats** — not an automated daemon. `∅` flake-update in the PMA unit, `∅` in `/etc/projects-management-automation/service.yaml`, `∅` in any systemd timer; instead `~/.local/share/fish/fish_history:59183` records `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` at epoch `1792936683` (≈14:58), matching the 15:00:53 lock mtime | unit + yaml + timer enumeration (`ls /etc/systemd/system/timers.target.wants/`), fish history line, `stat flake.lock` |
| a2 | **Gate failure decoded exactly**: `cv`, `dankMaterialShell`, `go-cqrs-lite`, `go-health-dashboard`, `homebrew-cask`, `nsfw-classifier`, `nur` — 7 drifted revs, no unregistered/stale entries | `nix eval .#nixosConfigurations.evo-x2.…toplevel.drvPath` throw text |
| a3 | **Registry re-derived mechanically** with the header's own command; 94 rows both sides; `diff` = exactly 7 changed lines, nothing else | `~/.cache/lockfloat/regen2.nix` vs live body |
| a4 | **7-line registry edit applied** (`flake/expected-locks.nix`), gate then OPEN: eval returns `y64nrk85…-nixos-system-evo-x2-…drv` | eval rc=0 |
| a5 | **Keep-going proof run with the log CAPTURED** to `~/.cache/lockfloat/build-1515.log` (95 lines, rc written into the file). No `\| tail` this time | `tail -1` → `rc=1` |
| a6 | **23 error lines collapsed to ONE root cause**: `/nix/store/lkqac15j…-cv-29868e0-go-modules.drv` — `specified: sha256-SkTcNXE…`, `got: sha256-1o2UQtLNE63E1evLxzZpvVP+MeNkSeEE2Ko6MNlQHWU=`. Every other error is `dependency failed` cascade (cv → system-path → system-units → dbus/polkit/mandb) | log lines 103–200 |
| a7 | **Upstream-first classification done**: `f.inputs.cv.packages.x86_64-linux.default.goModules` through OUR lock built the **same drv path** and produced the **same mismatch** ⇒ the stale literal `SkTcNXE…` is baked by upstream at `29868e05`, not carried by our service shim ⇒ consumer-side shim is the sanctioned interim (paste-upstream row already exists) | `~/.cache/lockfloat/cv-upstream-probe.log` |
| a8 | **Dead shared-shim registry DELETED**: `lib/vendor-shims.nix` had one value (`projects-management-automation = sha256-xvAVnWu…`) and **zero importers** after both consumers dropped their shims. `git rm` (not `rm`), 20-line dead config gone | `git rm`, `D lib/vendor-shims.nix` |
| a9 | **Stale cross-reference repaired**: the PMA module's history comment said "The VALUE lives in lib/vendor-shims.nix", pointing at a file that no longer exists. Rewritten to record the 2026-10-23 dedup AND the 2026-10-25 deletion | `modules/nixos/services/projects-management-automation.nix:66-72` |
| a10 | **Float-procedure ORDER defect fixed in THREE surfaces** (flake.nix throw message, `flake/expected-locks.nix` header, `lib/lock-float-audit.nix` header): the gate is forced via `builtins.seq`, so it throws **before any evaluation** — the old "step 1 = build" instruction was unfollowable on a stale registry. New order: regenerate (mechanical) → prove → commit; proof RED ⇒ fix upstream-first or revert BOTH the registry row and the lock rev; never commit an unproven float | `git diff` on the 3 files |
| a11 | **"Capture, never pipe" encoded where it will be read** — the registry header and the eval throw now both say `> …/float-proof.log 2>&1; echo rc=$?` and why (`\| tail` exits 0 and hides roots) | same 3 edits |
| a12 | **Formatting canonical** on all 4 edited Nix files via the scoped form `nix fmt -- <paths>` (not the bare `nix fmt . <path>` footgun) | `traversed 4 files … formatted 4 files (1 changed)` |
| a13 | **Concurrent-session preflight actually performed**: `/proc` process enumeration, project `.crush/crush.db` message query, `docs/status` listing, `git log --since`. Detected the monitor365 session and a `nix build .#checks…build` process before touching shared surfaces | session log |
| a14 | **Final state verified at report time**: HEAD `0910cce2a`, tree CLEAN, gate GREEN, gen 948 anchored, cv shim now a third literal | eval rc=0 + `readlink` |

---

## b) PARTIALLY DONE

| # | Item | State |
|---|------|-------|
| b1 | **The cv root cause** — diagnosed to a single drv with both literals named, then NOT fixed by me. The live tree carries a **third** literal (`IzjuTWgnhsRsRhprnBBvlCEkSl4dQtM8gvwu2ELbUAY=`, `modules/nixos/services/cv.nix:78`) written by a parallel session, and gen 948 is green. **My got (`1o2UQtLN…`) ≠ the live literal (`IzjuTWg…`) with no explanation on record** — either their builder graph differed (another input/follow changed in the same window) or they measured a different rev/context. Unverified either way | fixed by someone else; my diagnosis unclosed |
| b2 | **The 7-rev float proof** — I proved the *toplevel evaluation* up to the FOD layer and found one root, but I never re-ran the proof after the root was fixed, so **I cannot claim this wave's registry is proven green from my own run**. The green toplevel at 18:11 is another session's, on a tree that also carries their cv change | not re-proven by me |
| b3 | **Registry commit hygiene** — my 7-row registry edit and header rewrites landed inside `chore: auto-commit N changed file(s) (heuristic)` batches again. The registry's history is supposed to BE the float audit log; it is not, for the second wave in a row | committed, mis-messaged |
| b4 | **`lib/vendor-shims.nix` cleanup** — file deleted and the one stale comment fixed, but the **guard that prevents the class** (a selftest asserting every shared-shim attr has an importer) was proposed in the previous report and is still absent. The file is gone; the failure mode is not fenced | half |
| b5 | **The dedup doctrine itself** (scope rule "only when ≥2 surfaces must agree" + drop protocol) lived ONLY in the deleted file's header. I intended to move it into `docs/agents/nix-flakes.md` (the shim-protocol bullets around lines 132–133) and did not | doc loss risk |
| b6 | **Lock-integrity observation** — the 15:00 float converted 3 lock nodes from `github:` to `git+ssh` (`go-aichat`, `go-credentials-store`, `go-daemon`; +6 `ssh://git@github.com` lines). The lock already carried 32 such nodes, so this is probably harmless, but I never established whether CI can fetch `git+ssh` (no SSH leg checked in `.github/workflows/`) | noticed, unverified |
| b7 | **Report harvesting** — this report's §f is deliberately NOT harvested into `TODO_LIST.md`/domain libraries in this pass: the owner asked for a report-then-wait checkpoint, and a queue edit is exactly the kind of shared-surface write that races parallel sessions. Recorded here per the TODO contract's escape hatch. **f1 is therefore the harvest itself** | deferred by instruction |

---

## c) NOT STARTED (consciously out of this session's scope)

1. **cv shim update** to my first-hand got (`1o2UQtLN…`) — superseded in the tree by `IzjuTWg…`; do not apply blind, re-derive first.
2. **Re-proof after the cv fix** — `--keep-going` toplevel must show rc=0 on a tree that includes the registry + cv change before anyone calls this float landed.
3. **hermes-agent `nixpkgs-unstable` follow test** (the third leftover from the earlier session): throwaway eval of `hermes-agent.inputs.nixpkgs.follows = "nixpkgs-unstable"`, then drop the `0329638c` rev-hold **and** its pin-audit allowlist row in the same change.
4. **`scripts/fod-hash-diff.sh ~/.cache/lockfloat/build-1515.log`** — the repo's documented one-command repair. I hand-extracted the single mismatch instead. Process bypass, never closed.
5. **`nix flake check --no-build`** on the settled tree (my run only did the evo-x2 eval + build).
6. **`checks.x86_64-linux.lock-float-selftest`** and the pin-audit selftest after my header/message edits (text-only, but unrun).
7. **`scripts/negative-test-lints.sh`** groups touching lock/pin audits.
8. **CHANGELOG entry** for this 7-rev float wave (the inboxclean entry above it is a different change).
9. **`scripts/check-todo-system.sh`** after a future harvest.
10. **Commit hygiene attempt** — an amend-forward properly-messaged registry commit (probably impossible now: HEAD moved 5+ commits and several sessions are active).

---

## d) TOTALLY FUCKED UP

1. **I spent ~10 minutes investigating who floated the lock when one `grep` of fish history answered it.** I enumerated systemd timers, read the PMA unit, read the PMA service yaml, grepped modules AND scripts, and queried the agent DB — before checking the shell history, which was the obvious first move and which the repo already documents as the answer (`docs/todo/upstream.md:138`: "the blanket-update source was identified 2026-10-08 as the OWNER's own interactive `nix flake update` runs"). I re-derived a known fact at ~10× the cost.
2. **I re-learned the `\| tail` lesson instead of never repeating it.** The previous session in this same conversation lost a full enumeration cycle to `nix build … | tail -60`. This time I did capture correctly — but the fact that it needed conscious effort, and that the *repo header still didn't warn about it*, is on me: the warning went into the header only at 15:1x, hours after the first occurrence.
3. **I diagnosed cv and then stopped one read short of the fix.** I had the exact got hash, the exact drv, the upstream-first classification, and `cv.nix` open on screen. The single `edit` never happened. Three hours later a different session had fixed it with a **different** literal, and the tree is green for reasons I cannot fully attribute. That is the worst outcome shape available: correct diagnosis, no delivery, and now an unexplained value in the tree.
4. **I left the proof at rc=1 with no written artifact for ~3 h.** A one-root red proof is a 5-line note. Not writing it immediately meant the next actor (another session) had to re-derive the same cv failure from scratch. This is the "record it at the moment of discovery" rule, broken in the one situation where a shared tree makes it most valuable.
5. **I deleted `lib/vendor-shims.nix` without moving its doctrine.** The file's 8-line header was the ONLY place stating the "one value, two consumers" rule and its scope limit (single-consumer shims stay next to the consumer). Deleting the dead value was right; deleting the rule with it was sloppy. The rule now exists only in a CHANGELOG narrative and in this report.
6. **My registry-verification one-liner was positionally brittle.** I compared `sed -n '23,200p' flake/expected-locks.nix` against a regenerated body — and then my own edit lengthened that header, silently shifting the slice. It happened not to matter (I re-ran `diff` after the edit and got a clean match), but a copied version of that command would compare the wrong region and could report MATCH on a stale registry. Marker-based extraction (`sed -n '/^{/,$p'`) is the correct form.
7. **I never closed the loop between my got and the live literal.** `1o2UQtLN…` (mine) vs `IzjuTWg…` (live). Two honest possibilities: a concurrent builder-graph change, or my probe ran against a tree that had already moved. I did not check which, and I am therefore unable to say whether the live shim is first-hand-evidenced or guessed. Given this repo's history with hand-pasted shims, that is exactly the claim that must not be left fuzzy.
8. **Twin-session discipline held only passively.** I detected other active sessions (three crush processes started 15:03–15:07, a monitor365 workload, a `nix build .#checks…build`) and then edited shared surfaces anyway without a coordination note or a plan-marker. Nothing collided; that is luck plus disjoint file choice, not process.

---

## e) WHAT WE SHOULD IMPROVE

1. **Order the diagnostics by cost, not by interestingness.** "Who touched this file?" has a 3-source ladder: shell history → git log → agent DB / `/proc`. I ran it backwards. A 4-line preflight block in the float procedure would make this mechanical.
2. **A red proof must be written down within one tool call.** Rule to adopt: the moment a keep-going enumeration exits non-zero, append `roots + drv paths + specified/got pairs` to the session's cache log **and** to the owning TODO row. Never carry it in conversation state only.
3. **Diagnosis without delivery is not a close-out.** If the fix needs one edit, make the edit in the same breath as the diagnosis — or state explicitly "diagnosed, not fixed, here is the exact edit" in the report section that the next actor reads first.
4. **Deleting a file is a doctrine decision, not just a cleanup.** Before `git rm` on anything under `lib/`, grep documentation for the rule it carried and move the rule to the doc that owns it (here: `docs/agents/nix-flakes.md` shim-protocol block).
5. **Use marker-based parsing for generated-then-hand-maintained files.** `flake/expected-locks.nix` has a growing header and a one-line-attrset body; any verification snippet must key off `^{`, never a line number.
6. **Encode "capture, never pipe" in the gate itself, not only in prose.** The throw message now says it, but the deeper fix is a helper app (`nix run .#float-proof`) that owns log capture + rc + root extraction + `fod-hash-diff.sh`. Then nobody has to remember.
7. **Prove before claiming, then claim the surface.** My report language has to distinguish "I proved the FOD layer" from "the toplevel is green". The second sentence is someone else's evidence; say so.
8. **Treat unexplained-value drift as an incident.** A shim literal that changes three times in one day (`SkTcNXE` → mine `1o2UQtLN` → live `IzjuTWg`) with no shared evidence trail is precisely how hash whack-a-mole starts. The `fod-hash-diff.sh` output should be the only accepted provenance.

---

## f) UP TO 50 THINGS TO GET DONE NEXT

**Harvest + hygiene**
1. **Harvest §f into `TODO_LIST.md` + `docs/todo/{pipeline,upstream}.md`** (queue one-liner + library entry, paired), then run `scripts/check-todo-system.sh`. *Deliberately deferred: owner requested a report-then-wait checkpoint.*
2. Amend-forward / re-message the registry commit so the 7-rev float is auditable (pathspec-scoped; do not sweep foreign files).
3. CHANGELOG entry: "second 2026-10-25 float wave — 7 revs re-registered, cv FOD root cause, float-procedure ORDER corrected".
4. Move the deleted `vendor-shims` doctrine into `docs/agents/nix-flakes.md` (shim-protocol block, lines ~132–133).

**cv**
5. Re-derive cv's `go-modules` hash first-hand on the CURRENT tree; compare to live `IzjuTWg…`; record specified/got + drv path.
6. Explain the `1o2UQtLN` vs `IzjuTWg` delta (builder graph? concurrent nixpkgs follow? different rev?) before trusting either.
7. Update `docs/todo/upstream.md:130` (cv paste-upstream row) with rev `29868e05` + the current live literal + this session's got.
8. Re-run `scripts/fod-hash-diff.sh ~/.cache/lockfloat/build-1515.log` and diff its proposal against the live tree (process-compliance check).

**Proof + gates**
9. `nix build .#nixosConfigurations.evo-x2.…toplevel --keep-going --no-link` on the settled tree; require rc=0; archive the log.
10. `nix flake check --no-build` on the settled tree.
11. `checks.x86_64-linux.lock-float-selftest`.
12. pin-audit selftest (the throw message changed).
13. `scripts/negative-test-lints.sh` groups that touch lock/pin surfaces.
14. Verify the registry still equals a fresh re-derivation after all concurrent sessions settle (marker-based extraction).
15. Add a selftest: every attr in any shared-shim registry has ≥1 live importer (the guard b4 lacks).

**hermes**
16. Throwaway eval: `hermes-agent.inputs.nixpkgs.follows = "nixpkgs-unstable"`.
17. If green: drop the `0329638c` rev-hold + delete the pin-audit allowlist row **in the same change** (a stale allowlist row fails eval).
18. If green: re-run the toplevel proof and check `pm-ripgrep`/`pm-node` patchPhase.
19. If red: record the exact failing hunk + patchelf version evidence on the existing hold row.
20. Update `docs/todo/pipeline.md:572` + `TODO_LIST.md:1506` with whichever outcome.

**Lock integrity**
21. Decide and record: are the 3 `github:` → `git+ssh` node conversions acceptable? Check `.github/workflows/*.yml` for an SSH leg.
22. If not: normalize those 3 nodes back to `github:` (scoped `nix flake lock --update-input <x>` with `GIT_CONFIG_GLOBAL=/dev/null`, per `platforms/common/programs/git.nix:86-89`).
23. Document the `url.<…>.insteadOf` lock-conversion trap next to the float procedure.
24. Confirm `git config --global --get-regexp 'url\.'` on this host and whether the rewrite is intentional here.

**Tooling the procedure needs**
25. Add `nix run .#float-proof`: capture log, print rc, extract `specified/got`, run `fod-hash-diff.sh`, and refuse to print a green verdict without rc=0.
26. Teach the same helper to distinguish "root FOD" from "dependency failed" cascade (23 lines → 1 root automatically).
27. Make the registry re-derive a `nix run .#lock-registry` app so nobody hand-copies the jq loop.
28. Give the registry a guard: `expected-locks.nix` header claims 94 inputs; assert the count matches the re-derivation (drift detector).

**Verification discipline**
29. Write the "actor attribution ladder" (history → git → DB/PROC) into `docs/agents/nix-flakes.md` or CONTRIBUTING.
30. Add "a red keep-going proof is logged to the owning TODO row within one tool call" to the TODO system rules.
31. Add "deleting anything under `lib/` requires moving its doctrine" to CONTRIBUTING.
32. Add the marker-based-parse rule for generated/hand-maintained files.
33. Verify `nix fmt --fail-on-change` on the 4 touched files returns clean (my run formatted 1 file; re-check it is stable).
34. Check whether the registry header's 94-count line is still accurate after all float waves today.

**Deploy + runtime (only if instructed)**
35. Confirm gen 948's anchor again after any further tree change.
36. Confirm no `nh os`/`switch-to-configuration` process is live before any anchor assertion.
37. Post-deploy smoke: cv site (the genesis of the whole FOD chain).
38. Post-deploy smoke: nsfw-classifier, nur (charmbracelet crush), homebrew-cask consumers, dms-shell, go-cqrs-lite consumers, go-health-dashboard.
39. `scripts/post-deploy-check.sh` if a deploy happens.
40. `scripts/pre-deploy-check.sh` §11 (vendorHash preview) before any future deploy of this tree.

**Documentation of state**
41. Update the 14:49 report to point at this one (the cv/pma/hermes leftovers it names are now partly stale).
42. Record in `docs/agents/nix-flakes.md` the "registry-first because builtins.seq" ordering fact (it is a genuine architectural property).
43. Note in AGENTS.md's Prevention Layers table that the float gate now documents the working order.
44. Add this session to the running narrative list in `docs/status/` index if one exists.

**Process / collaboration**
45. Add a plan-marker or lock-file for "float in progress" so two sessions don't re-derive the same 7 revs.
46. Adopt a rule: never `nix flake update` while a deploy/verify session is active; use scoped `--update-input`.
47. Add a "who is writing this tree" note to the float procedure (single-writer assumption is false).
48. Record that the owner's own interactive blanket updates are the observed float source (again) and route it to `docs/todo/upstream.md:138` as a fresh datapoint.
49. Decide whether the 15:00 float wave should have been REVERTED instead of registered (this report's §g q1).
50. Re-run this whole checklist as a scripted verification pass once the harvest lands.

---

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **The 15:00 and 15:10 blanket floats — were those your interactive runs?** Fish history records `nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` at ≈14:58, and the lock was written twice (15:00:53, then 15:10:36) during my session. Do you want those 7 revs **registered as landable** (the documented procedure, which is what I did), or **reverted** to the reviewed set because the update was incidental to a deploy attempt?
2. **cv's live shim is a third literal.** My first-hand probe produced `got: 1o2UQtLN…`; the live tree carries `IzjuTWg…` and gen 948 is green. Was `IzjuTWg…` measured on a different builder graph (e.g. a concurrent follow/input change), or is it unverified? I will not touch cv until I know whether to re-derive it or treat it as first-hand.
3. **Are the 3 `github:` → `git+ssh` lock conversions intentional?** The 15:00 float rewrote `go-aichat`, `go-credentials-store`, and `go-daemon` from `type: github` to `type: git` + `url = ssh://git@github.com/…`. If that is your `insteadOf` rewrite leaking into the lock, I should normalize them and document the trap; if it is deliberate (private-repo fetch), CI needs to be checked for an SSH leg.

---

## Evidence appendix

```bash
# 1. Gate RED on 7 revs (15:09)
nix eval --raw .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath
#   → cv, dankMaterialShell, go-cqrs-lite, go-health-dashboard,
#     homebrew-cask, nsfw-classifier, nur (floated ≠ registry)

# 2. Mechanical re-derivation (header's own command) + diff
{ jq -r '.nodes.root.inputs|to_entries[]|select(.value|type=="string")|"\(.key)\t\(.value)"' < flake.lock; } \
 | while IFS=$'\t' read -r name nk; do \
     rev=$(jq -r --arg nk "$nk" '.nodes[$nk].locked.rev? // empty' < flake.lock); \
     [ -n "$rev" ] && printf '  %s = "%s";\n' "$name" "$rev"; done
#   → 94 rows; diff vs live body = exactly 7 lines

# 3. Proof, CAPTURED (not piped)
nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel \
  --keep-going --no-link > ~/.cache/lockfloat/build-1515.log 2>&1; echo rc=$?
#   → rc=1, 23 `error:` lines, ONE unique FOD mismatch

# 4. The single root
#   /nix/store/lkqac15jgjhgvxmdg13sl0ndq0ml0rpv-cv-29868e0-go-modules.drv
#   specified: sha256-SkTcNXEIkTWok3dAJ5iiwAghXzSCcxywDQ8skoALBTA=
#   got:       sha256-1o2UQtLNE63E1evLxzZpvVP+MeNkSeEE2Ko6MNlQHWU=

# 5. Upstream-first classification (same drv, same mismatch ⇒ upstream-baked stale literal)
nix build --impure --no-link --expr \
 'let f = builtins.getFlake (toString /home/lars/projects/SystemNix); in f.inputs.cv.packages.x86_64-linux.default.goModules'
#   → rc=1, identical drv path + identical specified/got

# 6. Actor attribution (the cheap source I should have checked first)
grep -n 'flake update' ~/.local/share/fish/fish_history
#   → 59183: nix flake update && DEPLOY_FORCE_PRESSURE=1 nix run .#deploy   when: 1792936683
#   no flake-update automation: PMA unit, /etc/projects-management-automation/service.yaml,
#   and /etc/systemd/system/timers.target.wants/ all show none

# 7. Dead shared shim removed
git rm lib/vendor-shims.nix      # only importer-free value in the file

# 8. Float-procedure ORDER corrected in 3 surfaces
#   flake.nix:1306-1312 · flake/expected-locks.nix:11-29 · lib/lock-float-audit.nix:12-23

# 9. Formatting (scoped form)
nix fmt -- flake.nix lib/lock-float-audit.nix flake/expected-locks.nix \
  modules/nixos/services/projects-management-automation.nix

# 10. State at report time (18:11)
git rev-parse --short HEAD            # 0910cce2a · clean
readlink /run/current-system          # f485prqh… == system-948-link target
nix eval --raw .#…toplevel.drvPath    # a7rpxd5q… (gate GREEN)
grep -n 'vendorHash = ' modules/nixos/services/cv.nix   # IzjuTWg… (third literal)
```
