# Forgejo G1 Falsified + Org-Inclusive Mirror Fixes — Session Self-Review

**Session date:** 2026-10-02, ~12:00–13:50 CEST
**Host:** evo-x2 (SystemNix, master; parallel sessions active — one Paperless-AI planner committed `224426ab` mid-session)
**Trigger:** user asked for the status of `docs/status/2026-09-18_16-45_*`, answered 4 owner questions (one with a live `sudo du` that detonated the session's central discovery), then directed "figure it auto and propose fixes".

---

## 0. TL;DR

The user's one-liner `sudo -u forgejo du -sh /var/lib/forgejo` → **16K** falsified today-morning's 11-17 report headline ("G1 storage migration EXECUTED 2026-09-30"): only the flip DEPLOY landed; the subvol mounted at `/var/lib/forgejo` is EMPTY, forgejo has been gated-down by design since ~09-30 21:50, and the real data sits intact-but-shadowed on the QLC beneath the mountpoint. I corrected all poisoned surfaces (queue, library, source-report banner, CHANGELOG), then implemented the user's "full backups incl. ALL orgs" directive end-to-end (org-inclusive mirroring + pair-keyed reconcile + persisted fixtures — the 09-18 session's throwaway fixtures finally became a flake check), collapsed the redundant `forgejo-repos` declarative list, and hard-guarded the migrate script against the exact mount-shadow trap the live system is in. Everything evaluates and every fixture is green; **all of it is UNDEPLOYED and rides the owner's G1-window deploy** (umount-first sequence recorded on the G1 row + script header).

| Owner answer (question tool) | What I did with it |
| ---------------------------- | ------------------ |
| "Full backups, these include ALL my orgs too" | Org-inclusive mirror + reconcile implemented, fixture-tested, queued for live verify |
| "Tell me fucking more" (32 frozen archives) | Listed all 32 from the journal (mostly Minecraft-plugin era); keep-all default stands |
| "explain; not enough context" (ensure-repos) | Explained, then collapsed it as part of the batch |
| du → 16K, "Something is wrong?" | YES — falsified the 11-17 "G1 executed" claim; repaired every surface; guarded the script |

---

## a) FULLY DONE

1. **Status archaeology on the 16-45 report**: all §a items confirmed live-enduring (metrics file, journal, CHANGELOG cross-checks); §f leftovers mapped against current queue/library (commit-graph.lock still blocked:user, du was blocked, natural-tick verification effectively closed by 12 days of clean metrics).
2. **G1 falsification, evidence-first**: owner du 16K + `:3000` connection-refused + reconcile metrics frozen at 09-30 21:40 + `findmnt` (subvol live, empty) + migrate-script read (`prepare()` is mount-blind; `finalize`'s >5-entries guard dies fail-safe). Verdict: flip deploy only (`268289da`), neither `prepare` nor `finalize` ever ran, btrbk "green" = empty-subvol snapshots (phantom-backup class), data safe on the QLC (btrbk-root covered).
3. **Correction of every poisoned surface** (the "a correction claim must NAME the surfaces" rule): banner on the 11-17 report; 3 false-premise TODO_LIST rows rewritten (docs-sync, CHANGELOG-row, G1-gate rows); services.md rows corrected + G1-window row amended with the umount-first repair; CHANGELOG batch row landed (this also discharges the 11-17 §f1/§f2 obligations, re-pointed).
4. **`migrate-forgejo-subvol.sh` state-mount guard**: `state_mount_guard()` in `prepare` AND `finalize` — dies loud with the umount-first repair when `/var/lib/forgejo` is already the subvol mount (as-scripted, `prepare` silently rsynced the empty mount onto itself = no-op "success"); short-circuits "ALREADY COMPLETED" on an existing marker; header ABORT path fixed (umount, not rmdir, when mounted). Fixture extended: `migrate-forgejo-subvol-fixture` now 9 cases, GREEN.
5. **Org-inclusive full-backup mirroring** (owner directive): `forgejo-mirror-github` lists `/user/orgs` → `/orgs/<org>/repos?type=all` (fail-loud non-array guards on EVERY listing, incl. the new org ones), creates same-named forgejo orgs if missing (`ensure_org`, self-healing on transient GET failure via 422-then-re-GET), migrates under the resolved org uid (user uid resolved once via `/api/v1/user` — the old hardcoded `uid 1` is gone), reports `N user + M org` counts.
6. **Pair-keyed org-aware reconcile**: canonical set = owner/name pairs across user + ALL orgs; forgejo mirrors listed as pairs with user-namespace→`$GITHUB_USER` mapping; out-of-scope namespaces (the local `starred` org) skipped + counted, never reconciled; rename/transferred/deleted classification pair-keyed (probe semantics unchanged: exit-code + shape check); `forgejo_mirror_org_mirrors` metric added; `known-stale.txt` stays FLAT-named for the legacy mirror-health consumer with pairs in `known-stale-pairs.txt`; pending-deletes switched to pairs (live file was empty — verified via the metrics `pending_deletes 0`); empty-response hardening on all four listing loops (`-z "$n"` now dies loud).
7. **Persisted mirror+reconcile fixtures** (the 09-18 session shipped them session-local only): `forgejo-scripts-fixture` now covers mirror happy path (existing/new user repo, org mirror under existing org, org create-if-missing + uid-keyed migrate payloads asserted from captured request bodies), rate-limit die, org-listing die, and a full 2-run reconcile scenario (rename confirmed → healed delete, org-namespace archived + transferred classification, out-of-scope skip, prom contents, known-stale flat+pairs). GREEN.
8. **`forgejo-repos` collapsed** (owner §g3, decided autonomously per "figure it auto"): `enable = false` in configuration.nix (module kept, inert), dead `forgejo-ensure-repos.service` restartUnits reference removed from sops.nix, runbook table + sync-works paragraph updated (3 → 2 create-only surfaces).
9. **Verification sweep**: `nix flake check --no-build` ALL PASSED (post-collapse), evo-x2 toplevel eval OK, both fixtures built green, shellcheck (repo wrapper) clean on the migrate script, `check-todo-system.sh` structure OK.
10. **Self-harvest**: 4 new queue one-liners + 4 library rows landed at authoring time (16-45 annotation + inventory persistence, runbook reconcile-section update, btrbk empty-snapshot sanity, per-org counts). Mutation-negative coverage deliberately NOT re-queued — the existing predecessor-debt trio row (services.md, 11-17 §f6-8) already owns it; my new cases extend that row's scope.

## b) PARTIALLY DONE

| Item | What remains |
| ---- | ------------ |
| Org-inclusive mirroring | Code + fixtures DONE; **live verification blocked:deploy** — first post-G1 run must mass-create org mirrors, `forgejo_mirror_org_mirrors > 0`, reconcile clean (queued, blocked:deploy) |
| G1 falsification record | All surfaces corrected; the 16-45 report's own §g1-3 annotations still owed (queued); plan §10 addendum left AS-IS (it was RIGHT — only the 11-17's rewrite impulse was wrong) |
| Runbook sync | Table + sync-works paragraph updated in-session; the deeper "Renames/transfers BREAK the mirror silently" section still describes flat-name semantics (queued — missed mid-session, caught at self-review) |
| Everything in this session | UNDEPLOYED — rides the G1-window deploy; the daemon has been auto-committing the work in parallel batches |

## c) NOT STARTED

1. **The G1 window itself** (owner sudo): umount → du sanity → `prepare` → build → `finalize` → `nix run .#deploy`. Full sequence on the G1 row + script header.
2. **G1 gate re-earning**: F24 restore drill + meaningful 8h-send evidence — both VOID until real data lands on the subvol (queued).
3. **32-archive inventory persistence** — the list lives only in the journal (queued).
4. **btrbk empty-snapshot sanity** (queued).
5. **Dashboard/panel surfacing for `forgejo_mirror_org_mirrors`** — metric ships dark (nothing consumes it yet; informational by design, not a phantom-green class since nothing asserts on it).
6. **First org mass-migration runtime check** — user-repo migration took 27 min for ~200; org repos add an unknown count; `TimeoutStartSec = 2h` is untested against the combined load (watch the first run).

## d) TOTALLY FUCKED UP (all caught in-session, all fixed before the fixtures went green)

| What | Root cause | Lesson |
| ---- | ---------- | ------ |
| First status answer relied on STALE rows without sweeping the freshest reports | I answered "staged, owner window pending" from services.md/pipeline.md rows; the same-day 11-17 report claiming EXECUTED existed and I hadn't seen it until the du forced a re-look. My answer was accidentally correct — the reasoning path was still wrong | Grep the newest docs/status BEFORE asserting live state; a stale row and a fresh row disagreeing IS the investigation |
| Asked the owner to run `du` when `findmnt` + a port probe would have reframed the question first | Verify-before-ask (the 11-17 report's own §d.1 lesson, repeated by me 2 hours later) | Probe the live system's unauthenticated surface (mounts, ports, world-readable prom files) before any owner question |
| 2-chunk multiedit lost to a daemon race → only 1 chunk reapplied → fixture died `MIRROR: unbound variable` | After the "file modified since read" failure I re-applied the section I cared about and forgot the inject-block chunk | After ANY partially-failed multi-part edit, verify EVERY chunk landed (grep the file), not just the one that failed loudly |
| `ensure_org` echoed progress to stdout, captured into the org uid | Command-substitution capture discipline | Any function whose stdout is captured emits progress to stderr, always |
| Fixture asserts `'"uid":1'` vs jq's pretty-printed `'"uid": 1'` | Wrote asserts without reading the sibling assertions in the same fixture (`'"interval": "8h"'` was right there) | Copy the existing assertion conventions of the fixture you are extending |
| Lowercase-vs-mixed-case stub key mismatch (reconcile lowercases org logins → org-repos URL key differs from the mirror's) | Two scripts derive the same URL differently through the same stub | When two code paths share a stub, assert the KEY derivation too — case transformations are part of the contract |
| Wrote "3 user + 3 org" assertion against stubs that produce 2+2 | Authored expectation without reconciling against my own stub data | Derive expected counts FROM the stub bodies, never from memory |
| `rg -rln 'forgejo-ensure-repos'` — the `-r` flag silently made it a REPLACE, mangling displayed matches | Typed `-rln` meaning "recursive-list", got replace-with-"ln" | rg has no `-r` recursion flag; `-r` is replace. Wrong-tool-flag output looks plausible — sanity-check one known match by line |

## e) WHAT WE SHOULD IMPROVE

1. **Report-freshness sweep as a standing first move**: the 11-17 session AND my first answer both reasoned from handoff-era rows while a same-day report existed. `ls -t docs/status/ | head` costs one command and would have caught it twice today.
2. **Live-state probe checklist for "down by design" claims**: findmnt + TCP port + textfile mtime are all unauthenticated and took ~5 seconds combined; both sessions today asserted service state from documentation.
3. **Empty-target backup assertions**: a btrbk leg (or any backup job) green on a zero-content target is this repo's phantom-green class AGAIN — mount+schedule proof is not content proof. Generalize: freshness checks deserve a size/entry floor.
4. **Fixture-stub realism for case transformations**: stubs keyed by sanitized URLs must document (and assert) which side lowercases. The live GitHub API is case-insensitive; the stub is not — the fixture is stricter than reality, which is good, but only if intentional.
5. **Capture-vs-progress discipline** (d): cheap rule, recurring bug class.

## f) Up to 50 things we should get done next

| # | Task | Impact | Effort |
| - | ---- | ------ | ------ |
| 1 | OWNER: run the G1 window (umount → du sanity → prepare → build → finalize → `nix run .#deploy`) — forgejo returns, this session's whole batch activates | High | M |
| 2 | Post-deploy live verification of org mirroring (mass-create run, `forgejo_mirror_org_mirrors > 0`, reconcile clean, gatus green) | High | S |
| 3 | Annotate the 16-45 report §g1-3 resolutions + persist the 32-archive inventory (queued) | Medium | S |
| 4 | Runbook reconcile-detail section → pair-keyed semantics (queued) | Medium | S |
| 5 | btrbk forgejo-subvol snapshot content-floor sanity (queued) | High | S |
| 6 | Mirror script per-org counts in summary (PAT-scope visibility) (queued) | Medium | S |
| 7 | Mutation-negative pass over BOTH extended fixtures (existing predecessor-debt row owns it — scope now includes my new cases) | Medium | M |
| 8 | G1 F24 restore drill re-earn after real data (queued) | High | M |
| 9 | Watch first org mass-migration against `TimeoutStartSec = 2h` | Medium | S |
| 10 | Decide `forgejo-repos.nix` module fate (keep inert vs delete) at next tree cleanup | Low | S |
| 11 | The 11-17 session's still-open rows I did NOT touch: live-verify metrics/Gatus (root-gated), G2 execution, M09+ | Medium | M |
| 12 | KNOWN_NEW_METRICS check after deploy: confirm nothing references `forgejo_mirror_org_mirrors` in config (nothing should — informational metric) | Low | S |

Noticed in passing (NOT re-verified, other sessions' domains): a Paperless-AI planner session committed `224426ab` mid-session; the daemon swept my in-flight edits twice (both verified by content, never amended into foreign commits); `check-todo-system.sh` still WARNs 78 unharvested §f-bearing reports (pre-existing, owned by the harvest-lint work).

## g) Questions I cannot answer myself

1. **G1 window vs fast-restore**: forgejo has been down ~2 days. The full window is ~30–60 min + rsync and completes the storage migration. ALTERNATIVE: flip `dedicatedSubvolume = false` + deploy ≈ forgejo back on the QLC in minutes, migrate later. Which do you want — window now, or fast-restore now and the window another day?
2. **Org exclusions**: "ALL my orgs" — is there any org the token sees that you do NOT want mirrored (huge foreign repos, client orgs with confidentiality constraints)? A yes/names answer is enough; absence of an answer = mirror everything.
3. **The 32 frozen archives**: now that you've seen the list (mostly the Minecraft-plugin era + activitywatch, alexmittler.com, Astride-Website, SpaceCloud, three.js-skybox-world) — keep-all stands, or name any to prune?

---

**Evidence trail:** owner `du` 16K (chat, 2026-10-02 ~12:30); `findmnt /var/lib/forgejo` → `/dev/nvme0n1p2[/hot/forgejo]` subvolid 260; `/dev/tcp/127.0.0.1/3000` refused; `/var/lib/prometheus-node-exporter/textfile_collectors/forgejo_mirror_reconcile.prom` last_run 1790797823 (09-30 21:40 CEST), total 391 / archived 32 / transferred 2 / pending 0; `journalctl -u forgejo-github-sync` 09-30 archived-name list; `nix build .#checks.x86_64-linux.{forgejo-scripts-fixture,migrate-forgejo-subvol-fixture}` green; `nix flake check --no-build` all passed; evo-x2 toplevel eval OK.

**Harvest log:** §f1-6 → TODO_LIST queue + docs/todo/services.md library rows landed at authoring time (4 new pairs); #7 folded into the existing predecessor-debt trio row (no duplicate created); #10-11 deliberately not harvested — owned by the 11-17 report's rows and the Paperless session respectively.

