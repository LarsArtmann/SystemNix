# Status: Docs-Health 08-14 Annotation Batch — 5 of 13 Done, Blocker Cleared, Commit Landed, Live-Findings Wave

**Date:** 2026-08-14 18:31 CEST
**Session scope:** Resume docs-health AUDIT — unblock the stalled 08-13 commit, correct 2 misleading annotations, annotate the 13 remaining 2026-08-14 reports
**Prior context:** `docs/status/2026-08-14_16-20_docs-health-0813-annotations-committed-blocked.md`

---

## a) FULLY DONE

### 1. Commit blocker RESOLVED — and the prior diagnosis was WRONG

- Applied the `buildcache.nix` statix fixes (`inherit (cfg) device;`, `inherit onFailure;`) — file-level statix now clean
- **Key discovery:** the pre-commit statix gate runs on **STAGED .nix FILES ONLY** (`.githooks/pre-commit:104-109`), NOT repo-wide as the 16-20 report claimed. `oauth2-proxy.nix:99-100` carries 2 pre-existing warnings that never blocked anything. The "repo-wide gate" theory in the prior report's §b.1/§e.3 was false
- The docs-only commit needed no .nix files at all — the pathspec-scoped commit worked on the FIRST retry after the buildcache fix

### 2. The 08-13 annotation batch COMMITTED (`4a02342d`)

- 11 files, 702 insertions: 9 annotated 08-13 reports + both session reports (15-24, 16-20)
- Full pre-commit hook passed (gitleaks, flake check, whitespace)
- The auto-git daemon can no longer sweep this work unattributed

### 3. The 2 misleading git+ssh annotations corrected — with BETTER evidence than planned

- Planned correction: "go-cqrs-lite family still fetches ssh://" (the 16-20 report's belief)
- JSON forensics found the truth is much bigger: **96 lock nodes still SSH-fetch** (`type: git` + `url: ssh://…`) across ~25 repos — go-cqrs-lite×4, go-finding×10, go-error-family×10, gogenfilter×9, go-output×6, samber-do-auditlog×4, cmdguard×3, …
- Both `04-47` §f.20 and `18-36` §f.9 now carry the real count with the correction note

### 4. Five of thirteen 08-14 reports annotated (every numbered item checked)

| Report | Verdicts | Highest-value findings |
|---|---|---|
| `08-23` boot-failure/qmd | ~30 (15-row F-table, §b, §c, 3 Q) | 7afab3f8 closed most (mkOidcGate/mkDnsGate, qmd doc sweep); auth-ready.target superseded; qmd GGUF models already gone — TODO_LIST item is stale; reboot-test items genuinely OPEN (no reboot since 08-13 21:42) |
| `08-24` smart-audio | ~20 (§b, §c, §f 3/4/5/18-24/35/41-45, §g.3) | hermes chain closed at `54781ffe`; AGENTS items at `61a2224b`; per-app routing/widget/override items open (ROADMAP) |
| `08-24` twenty | ~25 (§b, §c, §d.4, §f×10, §g.1, §g.3) | **backup-coordination premise was FALSE** — Twenty registered since `976e9547` (08-01), the session's §d.4 self-criticism wrong; docker-restart monitoring closed at `9b6590bf`; scrub item superseded by `autoScrub` (`ab7c331a`) |
| `08-46` monitoring-gaps | ~15 (§7/§8/§12 + §e + §f 2-4/6-9/27 + §g.1, §g.2) | **LIVE verification** via node_exporter `/metrics`: oomd `Killed` pattern matches real events (2408 kills), docker restart metrics emit for all 7 containers, disk metric live (86) — the report's "unverified" concerns resolved with runtime evidence |
| `09-14` code-quality | ~30 (§b×2, §c 3-5, §d.1, §d.5, §f×16, §g.1) | `0fce1ed9` closed harden-audit + gomemlimit; `9a56c1a7` closed I/O wrappers; registry-fix reboot moot (boot post-dates `d2443c29`); **live: dozzle runtime container STILL unbounded** (Memory=0) despite config limit |

### 5. A wrong prior-session annotation corrected (live evidence beat code archaeology)

- `05-48` §c.10 and §f.1 claimed the browser-history `expires_at` reaper error was "done (moot) — DB rebuilt, no recurrence"
- Live journal (16:38 TODAY): the error still fires **every 5 minutes**. Both locations corrected to "STILL BROKEN", TODO_LIST item re-validated
- The prior session checked the upstream schema but never the live DB — textbook premature closure

### 6. Live-system verification wave (node_exporter `/metrics` via fetch tool)

- **Disk: 87% (97G free) — NOT 97%** as the 16-20 report claimed. The parallel session's buildcache offload (`19c195e9`, committed 18:0x) freed ~70G. Still above the 85% alert threshold, but the 95% deploy-fail danger is gone
- **NEW data-safety finding:** `backup_healthy{immich}=0`, `backup_age_hours{immich}=999` — immich backups STALE ~41 days. monitor365 likewise (expected — service deliberately disabled). `backup_all_healthy 0`
- **NEW finding:** both BTRFS scrubs show `status=interrupted` (3) — reboots keep cutting weekly scrubs short
- Attic cache empty (`attic_storage_gb 0`)
- Last boot 08-13 21:42 — every "reboot test" item across reports remains genuinely open
- System saw load spikes of 728/369/175 during the session (build storm from the parallel session's work; settled to 78/28 by 18:31)

---

## b) PARTIALLY DONE

### 1. 08-24 twenty annotation — 11 of 12 edits applied

- The failed edit: §e items 3-6 ("Register Twenty backup…" block) — my old_string omitted the leading `- ` on list items. All other sections landed (24 markers). The content-level truth IS already recorded elsewhere (§c + §d.4 + §f.4 carry the same verdicts), so nothing is factually missing from the file — but the §e items 3/6 deserve their done-markers too

### 2. 08-14 annotation batch — 5 of 13 files done

Done: 08-23, 08-24×2, 08-46, 09-14. Remaining: 09-30, 10-00, 10-04, 10-41, 12-30, 12-53, 13-22, 13-44 (+ foreign 13-15 pending user decision). Hash research pre-exists in the 15-24 report §f.

### 3. Current batch UNCOMMITTED

6 modified files sit in the working tree (08-23, 08-24×2, 08-46, 09-14, 05-48 correction) + the buildcache.nix inherit fix + this report. HEAD is `19c195e9` (parallel session's commit on top of my `4a02342d`). Daemon sweep risk is LIVE again — I repeated the "work long, commit late" failure mode the 15-24 report §d.5 already flagged.

---

## c) NOT STARTED

1. The 8 remaining 08-14 reports (above)
2. Foreign `13-15_ssd-repurposing-options.md` decision (§g.1)
3. TODO_LIST routing: new findings (immich backup stale, dozzle runtime unbounded, scrub interruptions, expires_at re-confirmation, stale qmd-cache item deletion) + the 11 items from the 16-20 report §f.17-27
4. ARCHIVE pass (~22 candidates per 16-20 §f.28)
5. Formal `nix flake check --no-build` gate run (hook ran it clean at `4a02342d`, formal run still owed)
6. Inline health report (Accuracy + Fitness)
7. Final attributed commit

---

## d) TOTALLY FUCKED UP

### 1. Ignored a "1 edit failed" result for two full tool rounds

The twenty multiedit reported "Applied 11 of 12" and I moved on WITHOUT identifying the failure — only chased it down when the user demanded this report. The failure was trivial (missing `- ` prefix) but it sat uninvestigated. Read the failure count BEFORE proceeding, always.

### 2. Repeated the uncommitted-work failure mode

~2 hours of annotation work across 6 files with zero interim commits. The 15-24 report §d.5 documented this exact mistake. The correct cadence was commit-per-report or commit-per-2-reports.

### 3. Propagated the prior session's wrong blocker theory before verifying

I began this session believing "statix gate is repo-wide" (from the 16-20 report §e.3) and only discovered the staged-only truth by reading the hook source myself mid-verification. I then had to mentally retract analysis I'd acted on. Lesson: a prior report's root-cause claims get re-verified, not inherited — same rule as the session-summary "status reports are point-in-time" lesson, applied to my OWN reports.

### 4. Almost propagated a too-narrow correction

The planned git+ssh correction ("go-cqrs-lite×4 only") came from the 16-20 report's forensics. Running fresh JSON forensics found 96 nodes. If I'd trusted the inherited number, the correction would have been wrong in the same way as the claim it corrected. Verified-from-source or nothing.

### 5. sandbox `systemctl` blocked mid-verification (worked around, but wastefully)

The `systemctl is-active` batch died on sandbox policy. journalctl, docker inspect, and fetch(localhost:9100) all work — the verification toolkit should start there, not at systemctl.

---

## e) WHAT WE SHOULD IMPROVE

1. **Failed-edit discipline** — a partial multiedit failure is a blocking signal; identify the failed edit in the same tool round (one grep), fix or consciously defer with a note
2. **Commit cadence: per report** — the daemon is active; every completed file should reach a commit within minutes
3. **Verification toolkit hierarchy for this sandbox:** fetch(localhost) → journalctl → docker inspect → code/git; systemctl is blocked, curl is blocked. Internalize, stop rediscovering
4. **Live-state beats schema-state** — the 05-48 "moot" correction and the immich backup finding both came from runtime data that code inspection cannot see. For any "is it still broken?" verdict, query the running system FIRST
5. **Corrections need the same evidence bar as verdicts** — the 96-node count came from fresh JSON forensics, not the inherited 4-node claim. When correcting, re-derive, don't paraphrase
6. **The statix staged-only discovery should reach AGENTS.md** — "pre-commit statix lints staged .nix files only; fix-on-sight applies when staging .nix" — prevents the next session from planning around a phantom repo-wide gate

---

## f) Up to 50 Things To Get Done Next

### Immediate (this batch)
1. Apply the §e 3-6 done-markers in `08-24` twenty (the failed edit — content already proven in §c/§d/§f)
2. Commit the current batch (08-23, 08-24×2, 08-46, 09-14, 05-48 correction, buildcache inherit fix, this report)
3. Annotate `09-30` oidc-gate-helpers (reboot-test items open; 7 dismissed post-deploy failures — §f.7/§f.8 investigation)
4. Annotate `10-00` signoz-perses (research report; v1→v2 migration tracked in TODO_LIST)
5. Annotate `10-04` registration-lock (release chain open: cqrs-htmx/browser-history tags + flake bump)
6. Annotate `10-41` oauth2-toctou (upstream fix chain same as 10-04)
7. Annotate `12-30` ssd-recovery (parallel-session adjacent; DuraWrite sources added at `2bedae34`)
8. Annotate `12-53` dsn-audit (5-item go-nix review)
9. Annotate `13-22` vendorhash-iowrap (vendorHash drift sweep + validate-gomemlimit.sh + I/O wrappers, commit `e979e324`)
10. Annotate `13-44` hermes-registration (patch landed `54781ffe`; deploy partial — verify remainder)

### TODO_LIST routing (new this session)
11. immich backup stale 999h (`backup_healthy=0`) — investigate pg_dump timer, likely failing silently since ~07-03
12. Recreate dozzle container (runtime Memory=0 vs config 256m — `docker compose up -d --force-recreate dozzle` or next deploy)
13. BTRFS scrubs interrupted ×2 — consider resuming scrub after uptime stabilizes or accept interruption+restart
14. Update the disk item: 97% → 87% (post-buildcache-offload); keep cleanup task (still >85% threshold)
15. Delete stale qmd-cache TODO item (models gone; 184K sqlite remains)
16. Refresh expires_at item with live-confirmation note (still failing 08-14 16:38)
17-27. The 11 carried items from 16-20 §f.17-27 (renamer follows, go-cqrs-lite ssh→github, em dashes, alsa-utils, zram ADR, OTel-scheme eval check, committed-templ CI, vendor-hash CI ×3 repos, zram-fill Gatus alert, archived session-37 note)

### Closure
28. ARCHIVE pass (~22 candidates, 16-20 §f.28)
29. `nix flake check --no-build` formal gate
30. Inline health report (Accuracy + Fitness, visible math)
31. Final attributed commit
32. AGENTS.md: statix staged-only pre-commit behavior note

### Structural debt (observed, not this session's scope)
33. AGENTS.md 72.6KB compression session (carried, §g.3)
34. 11 appendix-only archived reports (docs-debt TODO)
35. `docs/planning/` 48+ files triage
36. `nix flake check --all-systems` Darwin eval intent undocumented
37. immich backup staleness may deserve a Gatus backup_all_healthy alert check (if absent)

---

## g) Questions (Cannot Figure Out Myself)

### 1. The foreign `13-15_ssd-repurposing-options.md` — annotate or leave? (carried, third ask)

The parallel session that wrote it also just landed `19c195e9` (buildcache offload) and `2bedae34` (its own doc fix), so it is ACTIVE. It matches the `2026-08-1*` scope. My recommendation stands: leave it for its owning session; a moving target corrupts history. Confirm, or order me to annotate it.

### 2. Immich backups are ~41 days stale — investigate NOW or TODO-only?

`backup_healthy{immich}=0`, age 999h, last timestamp 0. This is photos — the exact class of data the off-site-backup item says is irreplaceable. The failure predates this session and I don't know if the immich pg_dump timer is broken, its DB moved, or the backup-coordination directory config rotted. Investigating means `journalctl -u immich-db-dump*` + timer inspection (~10 min). Do it as part of this docs session (breaks docs scope, but data safety), or strictly TODO_LIST + your attention?

### 3. With 5 of 13 done and load spiking from the parallel build session — continue the batch now, or pause?

Machine load hit 728 during this session (parallel buildcache/build work). My remaining work is pure Markdown edits + light greps — no builds. Continue straight through the 8 remaining reports, or pause until the parallel session's build storm settles to avoid interleaving more daemon commits into uncommitted batches?

---

*Report generated: 2026-08-14 18:31 CEST*
*Session delta: 1 commit landed (`4a02342d`, 11 files), 6 more files annotated/modified awaiting commit, 2 inherited wrong claims corrected (statix gate scope, expires_at moot), 96-node ssh-fetch truth established, 4 new live findings (disk 87%, immich backup stale, dozzle unbounded, scrubs interrupted)*
