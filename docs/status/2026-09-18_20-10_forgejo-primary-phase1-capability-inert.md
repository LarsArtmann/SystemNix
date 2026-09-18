# Forgejo Staged-Primary: Phase-1 Capability Shipped Inert + Session Debts Closed

**Session date:** 2026-09-18, ~17:30-20:10 CEST (continuation of the 17-28 Phase-0 handoff)
**Host:** evo-x2 (SystemNix, master; daemon-committed — see (d))
**Trigger:** user directive "keep going" on the Phase-0 handoff's pre-M05 debt list + M05-M08.

---

## 0. TL;DR

All four Phase-1 capability tasks (M05 push-mirror, M06 flip mechanics, M07 dead-mirror monitoring, M08 census) are **code-complete, fixture-tested, and shipped INERT** — `canonicalRepos = []` keeps the sync unit at 2 phases (eval-proven), and nothing flips until the G1/G2 owner gates. Every session debt from the Phase-0 handoff is closed except the dump-zip layout verification (still G1-gated — needs the restore drill's first live run). The biggest find: **the plan's M07 detection heuristic was falsified by live data before it was built** — replaced with a notice-table design verified against v15.0.8 source.

---

## a) FULLY DONE

1. **M05 push-mirror capability (F27-F30):** `services.forgejo.canonicalRepos` option (default `[]` = phase absent, eval-verified: 2 vs 3 ExecStarts), `forgejo-push-mirror` script as gated 3rd phase of `forgejo-github-sync`. Schema verified against the LIVE deployed swagger (v15.0.8): `CreatePushMirrorOption` = `{remote_address, remote_username, remote_password, interval, sync_on_commit, branch_filter, use_ssh}` — no auth_token field, auth = PAT as `remote_password`. The fixture ASSERTS the POST payload carries `"interval": "8h"` — the exact field whose absence 400'd all 18 historical attempts.
2. **M06 flip mechanics (F31-F35):** `forgejo-flip-repo` (preconditions: pull-mirror-only, GitHub-exists, no pending reconcile verdict, owner-scope; `--dry-run`; DELETE → `mirror:false` full migrate (issues/PRs/labels/milestones/releases/wiki/LFS) → post-verify (native flag, default branch, issue count) → push-mirror attach → listed-verify; mid-flip recovery documented in-output) + `forgejo-flip@` / `forgejo-flip-check@` TEMPLATE units so the operator path gets the sync unit's env + OnFailure with zero secrets on any command line: `sudo systemctl start forgejo-flip@<name>`. F35 lossiness doc in the runbook.
3. **M07 dead-mirror monitoring (F36-F38) — REDESIGNED, see (d)/lessons:** `forgejo-mirror-health` 5-min collector + timer reading forgejo's `notice` table (`sqlite3 -readonly`, Type=1 rows in 24h), parsing repo names, subtracting the reconcile script's newly-persisted `known-stale.txt`; `forgejo_mirror_health.prom` (mktemp/644/trap/mv, CAP_FOWNER, fail-closed ABSENCE of `dead_candidates` on scrape error) + Gatus **"Forgejo Dead Mirror Candidates"** (4th registry check, unconditional — the dead-mirror class is live TODAY with 385 mirrors).
4. **M08 census (F39):** `forgejo-census` manual oneshot (jq-side counting, no grep), run at G2; runbook section.
5. **M02 debt — migrate-script fixture:** `migrate-forgejo-subvol-fixture` flake check runs the REAL script against stubbed btrfs/systemctl/chown with env-overridden dirs (overrides added, defaults unchanged): 7 branches green (mount-down refuse, prepare + idempotent, no-prepare refuse, family-active refuse, dry-run no-mutation, happy finalize with full verify+swap+diff, checksum-tamper refusal with source intact).
6. **M03 debt — calendar proof:** `systemd-analyze calendar '*-*-* 05,13,21:40:00'` normalizes cleanly; next elapse verified; 3 slots/day exactly 8h apart.
7. **F76:** 2026-08-31 plan header now carries the SUPERSEDED annotation with the falsified-premise explanation.
8. **Plan-doc sync:** M05/M06/M07/M08/F36-F38/F19/F05 rows updated + a §10 status addendum (task table, deploy-order note, fixture-authoring lessons). F16 recorded as partial (btrbk dry-run gate not added — no ExecStartPre hook in the nixpkgs unit shape; stays a G1 checklist row).
9. **Runbook + AGENTS.md:** staged-primary section (canonical semantics, flip procedure, dead-mirror semantics + notices-table growth note, census, G1 storage pointer); AGENTS forgejo section bullet with the falsification evidence.
10. **Full verification:** `nix flake check --no-build` green (twice); both fixture checks BUILD-green; extendModules evals prove the gating (2→3 phases, env, flip `%i`, 5-min timer) and the live-host shape (2 phases inert, 4 Gatus checks incl. the new one).

## b) PARTIALLY DONE

| Item | What remains |
| --- | --- |
| Dump-zip layout verification (restore drill's `*db*.sql` assumption) | Still owner-gated: first `systemctl start forgejo-restore-drill` at G1 answers it (drill fails LOUD in the safe direction if the layout differs) |
| F16 btrbk in-unit dry-run | Not implemented (see above); first-live-run verification stays on the G1 checklist |
| M08 census numbers | Script done; the census RUN is a G2 gate step (needs owner env) |

## c) NOT STARTED (by design — owner-gated or later phases)

- **G1 gate** (deploy inert batch → migrate → flip `dedicatedSubvolume` → verify): owner, 4 steps in the migrate script header.
- **G2 gate** (deploy this P1 batch + live push-mirror 201 probe + census): owner.
- M09-M11 (shim, pilot, rollout), M12-M15 (CI/Renovate), M16 (VM test), M18-M23 — per plan sequencing.
- Open owner questions Q1-Q3 from the 17-28 report remain UNANSWERED (G1 window, GitHub-issues policy, off-LAN stance) — they gate G1 timing, M06 usage, and VPN planning respectively.

## d) TOTALLY FUCKED UP (all caught in-session, all fixed before ship)

| What | Root cause | Lesson |
| --- | --- | --- |
| **Built M07 on a falsified premise** (would have shipped a permanently-blind detector) | The plan's "mirror_updated vs updated_at divergence" heuristic was plausible but WRONG: TouchMirror advances `mirror_updated` on FAILED syncs too (v15.0.8 `SyncPullMirror`→`TouchMirror` writes the same column), so all 385 live mirrors incl. the frozen ones carry FRESH mirror_updated; idle-healthy mirrors carry frozen updated_at — indistinguishable from dead | VERIFY detection heuristics against the ACTUAL data before building the detector — the anonymous API made this a 30-second check that saved a whole phantom-green monitoring layer. (The plan itself said "TouchMirror-proof" — the label was aspirational, not verified.) |
| Fixture `out` var shadowed nix's `$out` | My `run()` capture variable was named `out`; the final `echo PASS > "$out"` redirected into a multi-line garbage filename → "No such file or directory" attributed to a phantom line 110 | In nix build scripts, `out` is RESERVED. Name capture vars anything else. Cost: ~40 min of misdirected log archaeology |
| sed PATH-injection dropped the opening quote | `s#^export PATH="#export PATH=$stub:#` — the matched text included `"` but the replacement didn't re-add it → unterminated string → syntax error at line 30 of the corrupted wrapper | When sed-matching text containing quotes, the replacement must reproduce them; `bash -n` the result immediately |
| `printf ''` in a nix `''`-string | `''` is the escape for two quotes — broke the whole derivation parse | Use `: > file` for truncation in nix-indented strings |
| `/usr/bin/env` shebangs in stubs | The nix sandbox has no /usr/bin | Stub shebangs must point at the store bash (`#!${pkgs.bash}/bin/bash`) |
| btrfs stub arg-index bug ($2 vs $3) | Wrote the stub from memory of the call shape | The parallel session's lesson, repeated: stub bugs look like script bugs — read the first weird fixture failure as a STUB hypothesis too |
| Corrupt-scenario tamper would have been healed by the delta rsync | A plain tamper differs in size/mtime → rsync re-copies it BEFORE verification | To reach the verification branch, the tamper must preserve size AND mtime (rsync quick-check then skips it) — this is exactly the class of subtlety the guard exists for |

## e) WHAT WE SHOULD IMPROVE

1. **Heuristic verification as a gate:** any new monitoring DETECTOR should cite live evidence that its signal separates the healthy from the broken case BEFORE implementation (the M07 falsification is the template: source-read + anonymous-API spot-check).
2. **Fixture checks for writeShellApplication scripts should be committed, not ad-hoc:** the parallel session's ad-hoc /tmp fixtures verified the same scripts once; the committed `forgejo-scripts-fixture` derivation now runs on EVERY flake check (pre-commit + CI) forever. The PATH-injection technique is documented in the check itself.
3. **The daemon race is manageable:** 3 daemon commits swept this session's work (one mid-edit). Pathspec commits + post-hoc `git show --stat` verification kept history sane; no amends into foreign batches (one daemon commit also carried a parallel session's Samsung files — left untouched).

## f) Next actions (priority order)

| # | Task | Owner | Blocks |
| - | ---- | ----- | ----- |
| 1 | G1 gate: deploy Phase-0 batch → `migrate-forgejo-subvol.sh prepare` → build toplevel → `finalize` → flip `dedicatedSubvolume` → deploy → verify (2 btrbk legs + drill + Gatus green) | user (sudo) | everything storage-side |
| 2 | G2 gate: deploy this P1 batch → scratch-repo push-mirror 201 probe → first reconcile publishes known-stale.txt → dead-mirror check green → census run into runbook | user (sudo) | M09-M11 |
| 3 | Answer Q1-Q3 (G1 window / issues policy / off-LAN) | user | G1 timing, M06 usage, VPN |
| 4 | M09: `forgejo-remote-audit.sh` + flag-gated insteadOf shim (SHIPS DISABLED — redirecting PMA/tq/daemon pushes into Forgejo before the pilot would break commits) | next session | G2 |

## g) Evidence trail

- Fixture checks green: `nix build .#checks.x86_64-linux.forgejo-scripts-fixture` → "PASS: all forgejo staged-primary script fixtures"; `...migrate-forgejo-subvol-fixture` → "PASS: migrate-forgejo-subvol guard branches" (each failed 3-4 times during authoring — they demonstrably CAN fail).
- Gating evals: inert 2 phases / canonical 3 phases + `FORGEJO_CANONICAL_REPOS=pilot`; flip `%i` ExecStarts; live-host: 2 phases, 4 Gatus checks incl. "Forgejo Dead Mirror Candidates".
- Falsification evidence: `jq` over anonymous `/api/v1/repos/search?mirror=true` (all mirror_updated fresh incl. DarkBlocks/transferred; updated_at spans 2019-2026); v15.0.8 source `services/mirror/mirror_pull.go:526` (TouchMirror on failure) + `models/repo/mirror.go:167` (writes the same `updated_unix` column); `mirror_pull.go:379` (`CreateRepositoryNotice` per failed sync).
- `systemd-analyze calendar '*-*-* 05,13,21:40:00'` → Normalized + next elapse printed.
- Commits: carried by daemon batch commits (8a999bcb..969ddc1b era) — verified by content: fixture checks build from the committed tree.

