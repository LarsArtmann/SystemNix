# Session Status: Deploy Unblock — go 1.26.7 Floor + CV vendorHash (Both Fixed Upstream) — 2026-08-29 17:29

> **Session scope:** Rescue the blocked `nix run .#deploy` (2 build failures), fix both upstream, redeploy, verify.
> **Outcome:** Deploy GREEN. Both failures were upstream bugs, both fixed at the source and pushed. 8 post-deploy smoke FAILs are the pre-existing DAS/pool outage, untouched by this session.
> **Method note:** Both local upstream checkouts carried another session's dirty WIP — all fixes were made in clean `git worktree`s on origin/master, committed there, pushed fast-forward.

---

## Direct answers first (the questions asked)

**What did I forget?**
- The repo's own pre-deploy advice: **batch-build the Go packages before the full deploy**. I let the deploy discover the second failure (cv) — it worked out, but that's luck of the lock, not method.
- That a **fresh worktree lacks generated `*_templ.go` files** — CV's pre-commit `go vet` hook caught it, not me. I should have anticipated the templ-generate-at-build design before the first commit attempt.
- `curl` and `systemctl` are blocked in this environment — I attempted both and burned two roundtrips that `fetch`/journald alternatives cover.
- Rule #1 (View before Edit) on the first worktree edit — the tool rejected it; sloppy.

**What could I have done better?**
- **Separate commit → verify → push.** My first CV attempt bundled commit + fetch + push; when the hook failed, the output ("Everything up-to-date") was misleading. A real upstream bug (broken import) was caught by the hook — the gate worked, my command hygiene didn't.
- **Capture the full deploy log** (`tee` to a file). I piped `tail -40`, so the first view of smoke results was truncated and I had to re-run the entire post-deploy-check for the complete FAIL list.
- **Pre-verify the other ~22 pending builds** from the failed deploy instead of relying on the deploy itself to enumerate breakage.
- Fix my own tooling friction: two failed Python parses of flake.lock (root-node structure) and one deprecated `nix hash to-sri` before landing on the right invocations.

**What could I still improve (systemically)?**
- The **vendorHash mental model** was wrong in the ecosystem docs: I proved the FOD's module set is resolved from *actual source imports*, so "go.mod/go.sum unchanged" does NOT mean "hash unchanged". Documented in SystemNix AGENTS.md — but CV's own docs and CI still encode the wrong model.
- **Upstream CI gaps are the real root cause.** CV master was simultaneously (1) unbuildable via Nix (stale vendorHash) and (2) failing `go vet` on a missing generated package — and no upstream gate caught either. go-cqrs-lite learned this lesson 2026-08-16; CV still hasn't.
- **Known-outage noise:** post-deploy-check reports the 8 pool-down FAILs identically to true regressions — alarm fatigue is how the 43-minute pre-freeze Discord warning went unactioned.

---

## a) FULLY DONE

| # | What | Evidence |
|---|------|----------|
| 1 | Diagnosed `cqrs-lint` failure: go-cqrs-lite's flake pinned tarball Go 1.26.6 while its own floors moved to 1.26.7 (`go: module ./_local_deps/samber-do-auditlog requires go >= 1.26.7`) | FOD error in deploy log; `nix eval nixpkgs#go_1_26.version` → `1.26.7`; go-cqrs-lite `go.mod:4 → go 1.26.7` |
| 2 | Diagnosed `cv` failure: stale `vendorHash` upstream, **reproduced standalone** in a clean worktree | `specified: sha256-3wfBqj…aSbs=` / `got: sha256-pzxfHX…8+VQ=`; root cause: 117 files of source-only churn (imports reshaped, package deleted) with ZERO go.mod/go.sum/flake.lock changes |
| 3 | go-cqrs-lite fixed upstream: dropped the go-tarball override (doctrine drop-day — nixpkgs 1.26.7 ≥ every floor), vendorHash untouched (FOD proved toolchain-independent) | commit `684f93dcf` pushed fast-forward to `LarsArtmann/go-cqrs-lite@master`; `nix build .#cqrs-lint` green in worktree |
| 4 | CV fixed upstream: vendorHash refreshed to the got-hash | commit `4004de64` pushed fast-forward to `LarsArtmann/CV@master`; `nix build .#cv` green (full build incl. templ/tailwind) |
| 5 | Passed CV's `go vet` pre-commit gate by running `templ generate` in the worktree (generated files are deliberately gitignored; Nix regenerates at build) | "All pre-commit checks passed!" on second commit attempt |
| 6 | SystemNix relocked: `go-cqrs-lite → 684f93dcf`, `cv → 4004de64` | `nix flake lock --update-input` ×2 (GIT_CONFIG_GLOBAL=/dev/null); revs verified in flake.lock |
| 7 | `nix flake check --no-build` — all checks passed | aarch64-darwin omission = expected per AGENTS |
| 8 | **Deploy completed**: `nix run .#deploy` — build + switch + post-deploy checks ran | 68 PASS / 8 FAIL / 5 SKIP / 5 WARN; all 8 FAILs classified (see #9) |
| 9 | Verified the 8 FAILs are the pre-existing DAS/pool outage, not this deploy: Immich (×2), Attic cache, Paperless, Bank-Sync (×4) — all pool-dependent | `findmnt /mnt/pool` rc=1, zero pool mounts; AGENTS documents this exact failure mode since 2026-08-22 |
| 10 | Live verification of both fixes on the running system | `/run/current-system/sw/bin/cqrs-lint version` → `4.7.0 (commit: 684f93d, built: 20260829144726)`; `https://cv.home.lan/` serves the rendered CV app |
| 11 | AGENTS.md updated: drop-day paragraph, CV bullet corrected, two new durable lessons (source-only-churn vendorHash staleness; templ-generate worktree trap) | 2 edits applied to `/home/lars/projects/SystemNix/AGENTS.md` |
| 12 | Cleanup: both worktrees removed, go1.26.7 src SRI recorded (`sha256-DtJOrHVRBQhbif6cq8J0K5GgrXuUtZ0602SRjryJVq0=`) for any future re-pin | `git worktree list` shows none |

## b) PARTIALLY DONE

| # | Item | Works | Open | Blocker / Effort |
|---|------|-------|------|------------------|
| 1 | Override-drop doctrine | go-cqrs-lite dropped | browser-history, papdashboard, crush-daily, PMA, CV-inline still carry now-droppable Go overrides (none break today) | None; S each |
| 2 | Post-deploy verification breadth | Fixed packages + smoke gate + pool classification verified | No full `nix flake check` (VM tests) — deliberately skipped under memory-pressure doctrine; no Go test suites run; no upstream `nix flake check` for either repo | Time + pressure budget; M |
| 3 | go-cqrs-lite other packages | cqrs-lint verified | `benchstat` (separate buildGoModule, default pkgs.go) not rebuilt/verified under nixpkgs 1.26.7; not consumed by SystemNix | None; S |
| 4 | SystemNix tree state | flake.lock + AGENTS.md edits in working tree, deployed from them | NOT committed by me (no explicit commit instruction) — the auto-commit daemon owns message/attribution | Policy; S |
| 5 | Deploy observability | Smoke summary captured | Full deploy + first smoke run logs not archived (tail -40 only); second smoke run re-derived the list | None; S |

## c) NOT STARTED

*(noticed this session, zero work done — pre-existing incident items included for completeness, clearly marked)*

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| 1 | **DAS physical recovery** (front USB4-C replug: cable + VBUS + enclosure power, 60+s) | Hardware is user-only | YES — gates 8 services |
| 2 | Post-DAS-return checklist: by-label/pool verify, pool-service recovery, btrbk catch-up monitoring, uas-at-attach confirmation, record outcome in AGENTS | Blocked on #1 | YES |
| 3 | CV upstream CI: Nix-build / vendor-hash gate (would have caught BOTH of today's bugs) | Out of session scope per instructions | YES — High |
| 4 | CV repo's own AGENTS.md: vendorHash-from-source-churn + templ lessons | Only SystemNix AGENTS updated | YES; S |
| 5 | go-cqrs-lite `.go-version` mirror check (flake comment demands go.work + .go-version stay in sync with floor) | Not inspected | Probably; S |
| 6 | TODO_LIST.md harvest from this report | Report first | YES |
| 7 | Pre-existing security incidents (NOT touched this session): Context7 key rotation (still LIVE), Resend key + pocket-id SMTP repair, history-purge push decision, Gemini GCP key deletion, crush plaintext provider-key migration | Out of scope | Per standing decisions |

## d) TOTALLY FUCKED UP

**My process failures this session (radical honesty):**

1. **Edit-before-Read violation** — first edit to the worktree flake.nix rejected; I had only `sed`-viewed it. One wasted roundtrip on a rule I enforce on every session.
2. **Two banned-tool attempts** — `systemctl` (security-blocked) and `curl` (banned; `fetch` tool exists) during verification. Two roundtrips burned on things the environment contract already told me.
3. **Bundled commit+push command produced misleading output** — CV commit #1 failed the hook; the chained push then printed "Everything up-to-date". If I hadn't cross-checked, the vendorHash fix would silently NOT be on master. The hook was right; my command hygiene was wrong.
4. **Deploy log truncation** — `tail -40` cost a full second smoke cycle to recover the complete FAIL list.
5. **flake.lock parsing fumbles** — two Python TypeErrors before resolving the root-node indirection correctly.
6. **Deprecated `nix hash to-sri`** instead of `nix hash convert` — cosmetic, but it warned.
7. **Luck ≠ method:** deploying with only the two KNOWN failures fixed worked, but I never batch-verified the other pending builds first. The repo's own AGENTS advice (2026-08-10, still unwired) exists precisely for this.

**Observed broken (pre-existing, NOT caused by this session):**

8. **CV upstream master had TWO uncaught quality gates down simultaneously** — Nix-unbuildable (stale vendorHash) AND `go vet` failing on `internal/ui/components/common` (only `.templ` sources committed, generated Go gitignored by design, nothing generates it in dev/CI context). Nothing in CV's pipeline catches either. Severity: every fresh clone/CI/consumer breaks; mitigation: my push fixes the FOD, the vet gap remains open.
9. **8 services down ~7 days (Immich, Attic, Paperless, Bank-Sync, backups tier)** — DAS JMS567 outage, physically pending. Post-deploy-check cannot distinguish this known outage from a fresh regression → alarm fatigue. Mitigation exists (classification idea, section e).
10. **`cache.home.lan/monitor365` binary cache 502'd throughout builds** — atticd is pool-dependent; every nix build pays retry latency while the DAS is out. Known; self-heals on DAS return.

## e) WHAT WE SHOULD IMPROVE

1. **Wire the 2026-08-10 suggestion for real:** pre-deploy batch `nix build` of all `mkLarsPackages` + cv + hermes inputs in `pre-deploy-check.sh`. Today's deploy would have surfaced BOTH failures in seconds without a 12-minute aborted deploy. (Impact: high; the failure class recurs monthly.)
2. **CV CI needs the go-cqrs-lite lesson** (2026-08-16 → recurred today 2026-08-29): a `nix build .#cv` (or at least go-modules FOD) gate. VendorHash staleness has now bitten this ecosystem twice from the same root cause — source churn without a Nix gate.
3. **Known-outage classification in post-deploy-check:** FAILs whose units are down due to a documented absent dependency (e.g. `RequiresMountsFor` on unmounted pool) → WARN with reason, keep FAIL for true regressions. Protects the alert signal that matters.
4. **Worktree-fix pattern should be the documented standard** for upstream fixes when local checkouts are dirty with other sessions' WIP — it worked flawlessly today and is nowhere written down.
5. **Promote the corrected vendorHash model** into every LarsArtmann repo's docs: the FOD resolves from actual imports, so vendorHash staleness is caused by SOURCE churn too, not just go.mod/go.sum/lock changes.
6. **Always `tee` deploy/smoke logs** to a timestamped file — post-hoc log archaeology from a truncated tail is how diagnosis time doubles.
7. **Commit → verify → push as separate steps** with output checks between, whenever hooks or remotes are involved.
8. **Keep toolchain pin mirrors in one greppable place per repo** (go.work / .go-version / flake comment) — go-cqrs-lite's flake comment promises a mirror discipline nobody enforced.

## f) NEXT: 50 things to get done (HARVEST input — route to TODO_LIST/ROADMAP)

*Impact / Effort (S<30min, M 30min–2h, L>2h) / Category*

**Critical**
1. DAS physical replug on front USB4-C (cable + VBUS + enclosure power, 60+s); record outcome — User / S / Ops
2. Post-DAS: verify `/dev/disk/by-label/pool`, mount health, `btrfs device stats` — S / Ops
3. Post-DAS: recover pool services (atticd+bootstrap, immich, bank-sync, paperless); re-run post-deploy-check for full green — M / Ops
4. Post-DAS: confirm `uas` loads at attach (pre-load shipped 2026-08-29); update AGENTS DAS bullet with the replug outcome — S / Documentation
5. Verify Gatus + SigNoz are actively FIRING for the 8 down services (no phantom greens) — S / Bug
6. Rotate the still-LIVE Context7 key; update MCP config — S / Security
7. Generate new Resend key → `sops --set` into pocket-id.yaml → redeploy (Pocket ID email is broken) — S / Security
8. Re-confirm the held decision on the secret-history purge push — User decision / S / Security

**High**
9. Drop Go tarball override upstream: browser-history (+ relock) — S / Cleanup
10. Drop: papdashboard — S / Cleanup
11. Drop: crush-daily — S / Cleanup
12. Drop: PMA — S / Cleanup
13. Drop: CV inline override (+ refresh vendorHash if the FOD shifts) — M / Cleanup
14. go-cqrs-lite: verify `benchstat` + run its full `nix flake check` under nixpkgs 1.26.7 — M / Quality
15. go-cqrs-lite: verify `.go-version`/go.work mirror consistency now that the pin is gone — S / Documentation
16. CV CI: add `nix build .#cv` gate (catches vendorHash + FOD breakage pre-merge) — M / Quality
17. Sweep LarsArtmann repos WITHOUT a vendor-hash/Nix CI gate; produce the list — M / Quality
18. pre-deploy-check: add batch build of mkLarsPackages + cv + hermes (the 2026-08-10 suggestion) — M / Quality
19. post-deploy-check: known-outage classification (pool-down → WARN) — M / Quality
20. Update CV repo AGENTS.md with both lessons from today — S / Documentation
21. HARVEST this report into TODO_LIST.md / ROADMAP.md — S / Documentation
22. Verify the daemon's commit of flake.lock + AGENTS.md carries a sane message/attribution — S / Quality
23. Verify `/run/booted-system == /run/current-system` + review generation delta (nvd) — S / Ops
24. Check root-fs headroom post-deploy; GC if tight — S / Ops

**Medium**
25. Investigate the quickshell journal error lines (smoke WARN) — S / Bug
26. Profile fish startup 908 ms (smoke WARN, threshold 200) — M / Bug
27. Migrate remaining plaintext crush provider keys (zai, gemini, minimax, kimi-coding, mimo, hyper) to the sops→crushrc pattern — M / Security
28. Purge rotated synthetic-key remnants from `crush.json` + fish_history — S / Security
29. Paperless /data EIO inode repair decision (standing P0; blocked on DAS return) — L / Bug
30. Confirm attic binary cache recovers post-DAS; note build-latency impact while absent — S / Ops
31. CV functional smoke beyond HTTP 200 (e.g. PDF render probe) in post-deploy-check — M / Quality
32. Document CV's templ-generate-at-build divergence explicitly (it conflicts with the ecosystem's commit-generated-files rule by design) — S / Documentation
33. Pin/verify the templ version used by CV's generate-at-build vs go.mod (version-matched claim) — S / Quality
34. Sweep for anything else consuming `go-cqrs-lite.packages.<x>` besides cqrs-lint — S / Quality
35. Replace deprecated `nix hash to-sri` usages in scripts/docs with `nix hash convert` — S / Cleanup
36. Codify the worktree-fix pattern in SystemNix AGENTS as the standard for dirty upstream checkouts — S / Documentation
37. Identify what ran the unattended bulk flake update that started this session (see question 3) — S / Quality
38. Gate surprise bulk `nix flake update` behind a validation build (wrapper or CI) — M / Quality
39. Watch-item: go 1.27.0 is out; when ecosystem floors move to 1.27, re-pin deliberately (AGENTS note exists) — S / Documentation
40. AGENTS.md: the 1.26.6 floor narrative keeps growing — compress history into a rule + link — S / Documentation
41. Verify backup-coordination freshness signals (cv-backup etc.) resume after pool return — S / Ops
42. Immich/paperless DB integrity checks after pool return (history of unclean USB removals) — M / Bug
43. Run `scripts/das-link-recovery-check.sh` immediately after the replug — S / Ops
44. SigNoz: confirm the 8 down services alert with post-2026-08-27 rule patterns (unit_state / service_name), not legacy — S / Bug
45. Plan btrbk pool catch-up after DAS return (multi-day backlog; stagger vs IO pressure) — M / Ops

**Low / hygiene**
46. Add a fast flake output (e.g. `.#quick-go`) building the mkLarsPackages batch for one-command verification — S / Feature
47. Delete local fix branches `nix/go-1.26.7-toolchain` + `nix/vendorhash-refresh` (pushed; merged) — S / Cleanup
48. Record go1.26.7 src SRI (`sha256-DtJOrHVRBQhbif6cq8J0K5GgrXuUtZ0602SRjryJVq0=`) in AGENTS next to 1.26.6's — S / Documentation
49. Follow-up status cycle after DAS recovery (this report's FAIL classification will change) — S / Documentation
50. Post-DAS: re-check `system_gatus_meta_scrape_errors` / monitoring-of-monitor health after atticd + pool services return — S / Quality

## g) QUESTIONS I CANNOT ANSWER MYSELF

**Q1 — DAS replug:** Has the front USB4-C replug (pull USB cable AND enclosure power, 60+ seconds, replug) been attempted since the 2026-08-29 fixes (uas pre-load + controllers pinned awake)? If not: do you want to do it now while I watch journals and record the wedged-vs-dead verdict? I cannot touch the hardware, and the outcome decides whether the enclosure is dead or was only ever software-strangled.

**Q2 — The bulk lock update:** The uncommitted `flake.lock` update that started this session moved ~12 inputs at once (go-cqrs-lite, cv, bank-sync, helium, hermes-agent, homebrew-cask, nix-ssh-config, nur, signoz-src, inboxclean, …). Did you or a concurrent agent session run that `nix flake update` deliberately, or does an automated job do it? I deliberately did not research it per your scope instruction — but the answer decides whether surprise lock bumps need a validation gate before they can break deploys.

**Q3 — Override sweep:** Drop the 5 remaining Go tarball overrides upstream now (browser-history, papdashboard, crush-daily, PMA, CV — each: worktree build-verify + push + SystemNix relock), or leave them "drop on next touch"? Both are defensible; touching 5 repos at once during post-crash stability recovery is a risk-appetite call I won't make unilaterally.

---

**Handoff note:** Section (f) is HARVEST input for TODO_LIST.md/ROADMAP.md (docs-health). Report written as **.md** per explicit user instruction (skill default is HTML — override honored, flagged here). Report NOT committed (no explicit commit instruction; the auto-commit daemon owns the tree).
