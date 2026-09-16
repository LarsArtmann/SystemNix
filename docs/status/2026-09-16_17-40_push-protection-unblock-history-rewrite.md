# Status Report — Push-Protection Unblock via Range Rewrite

**Date:** 2026-09-16 17:40 CEST
**Session scope:** ONLY this session's work — the GH013 push block on SystemNix master, its root causes, the fix, and what was noticed along the way. No project-wide sweep was performed (per instruction).
**Format note:** user explicitly requested `.md`; the status-report skill's HTML-canonical default was overridden per its own escape clause. Sections (f)/(g) sized per user instruction (up to 50 / up to 3) — the skill default is 25/1.

---

## Executive Summary

The push of `master` was rejected by GitHub Push Protection (GH013) with two flagged secrets. Both were **fake test fixtures — zero real credentials, nothing to rotate, no unblock URL needed**. The deeper finding: the literals lived in **multiple historical file versions** inside the local-only push range, and the repo's own push-protection audit script was itself the repeat offender across three of its own iterations. Fix: redact at the tip, then **three `git filter-repo --refs origin/master..HEAD --replace-text` passes** with verification against the complete new-blob set until `flagged-hits=0`. Push succeeded: `53308f07..200fbec7` (108 commits), git town sync completed, working tree clean, selftest green. The playbook is now recorded in `AGENTS.md` and — critically — it **invalidates this morning's unblock-URL recommendation for go-taskqueue** (its 4 flagged commits are also local-only, so the same rewrite applies there without any allowlist).

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| A1 | **Diagnosed both GH013 flags at the source** — Slack flag = documented-FAKE `xoxb-…` from go-taskqueue's `redact_test.go`, quoted verbatim into the 08-27 status report (2 locations); Sourcegraph flag = hardcoded fixture components in `scripts/audit-push-protection-literals.sh`'s own history | `git show`/`sed` of the flagged (commit, path, line) triples; `.crush/crush.db` copies confirmed untracked+ignored (no repo concern) |
| A2 | **Redacted the status report** — fake token shape-described as `xoxb-<12 digits>-<16 letters>` (counts verified against the original literal), both occurrences | commit `73fedf0c` (final pushed SHA of "redact push-protection fixture literals, cover Slack shape"); pre-commit hooks green (gitleaks, shellcheck, flake-check eval) |
| A3 | **Fixed the audit script at the tip** — `mixed` literal now runtime-derived (`sha256sum` seed + `tr 'acef' 'ACEF'`, deterministic, verified mixed-case); **Slack token shape added** to `PATTERNS` + header doctrine (today's class had ZERO local coverage); selftest extended with a runtime-composed Slack fixture (digits/letters segments derived from seeds) | selftest: `selftest: all literal shapes flagged` + `SELFTEST PASS`; main scan over 2250 tracked files: rc=0 |
| A4 | **Purged ALL rule-matching literals from the push range** — 3 filter-repo passes (exact + `regex:` lines) over `origin/master..HEAD` | final verification: **278 new blobs scanned (`git rev-list --objects` → `cat-file --batch-check` → grep), flagged-hits=0**; 16 keyword+40-hex WARN candidates sampled → gitleaks.toml override citing a commit SHA (not a secret; GitHub had already scanned those blobs at the failed push without flagging) |
| A5 | **Push landed, sync finished** | `53308f07..200fbec7 master -> master` + `git push --tags` up-to-date; `git town status`: "previous sync finished successfully"; `origin/master == HEAD`; tree clean |
| A6 | **Boundary-blob semantics discovered + handled** — `filter-repo --refs A..B --replace-text` does NOT rewrite blobs shared with pre-range history (they pass through unreplaced). Verified harmless: the surviving `negative-test-lints.sh` literal blob was introduced in **pushed** history (`d1f8126c ∈ origin/master`), so the remote already has it, never rescans it, and it cannot block | blob-ancestry check (`git log --all --find-object` + `merge-base --is-ancestor`) |
| A7 | **Playbook recorded** — AGENTS.md push-protection bullet extended with the 2026-09-16 recurrence (fake ≠ exemption; keyword + 40-char component in one file suffices; shape-describe in docs; multi-pass rewrite + new-blob-set verification; boundary-blob caveat; `git town continue` finish) | `7cd8eb8e`, pushed |
| A8 | **Rollback safety** — backup branch `push-fix-backup` held the old lineage until push success, then deleted (was `316b8ce6`) | command log; deletion confirmed |

## b) PARTIALLY DONE

| # | Item | What works | What remains | Blocker |
|---|------|-----------|--------------|---------|
| B1 | **go-taskqueue unblock (carries this morning's B1/Q2)** | This session PROVED the alternative path: its 4 flagged commits are local-only, so the same range rewrite purges the fake `xoxb-…` with no allowlist and no unblock URL — the playbook is written down and battle-tested as of today | Rewrite not executed; tq input still pinned `git+file://…?rev=1a4eb48`; AGENTS.md tq section still describes the pre-09-11 era; morning F41 (allowlist-silencing risk) moot under this path but unverified | Your repo-owner go-ahead (see Q1) |
| B2 | **Push-protection coverage is now correct at the tip but not structural** | Audit script covers sgp_/sq0atp_/xox shapes; selftest proves it scans | No pre-push scanner exists — the class is caught only at PUSH ATTEMPT (GitHub) or by manual diligence. Today's incident would recur for any new shape | None — design done, implementation not started (see F1/F2) |
| B3 | **Gate-integrity question opened, not answered** | Known: 3 successive literal-carrying script iterations were committed (8647c15b-era → 63fd5a83 → 84c47e67) and pre-commit gitleaks stopped none of them | WHY unresolved: suspicion is the `.gitleaks.toml` OVERRIDE of the sourcegraph rule (the one citing commit `49749626…`) narrowed keyword+hex matching to prefix-required — needs reading + a decision whether narrowed semantics are canonical; ALSO unknown whether the PMA auto-commit daemon runs pre-commit hooks at all | Investigation time (F6/F7) |
| B4 | **Slack shape propagation** | Added to the audit script (tracked-tree scan) | NOT propagated to `scripts/scan-history-secrets.sh` (unchecked whether it already has an xox pattern); gitleaks-coverage-selftest has no Slack fixture (unknown whether the repo gitleaks config even has a slack rule) | 5-minute check (F8/F13) |
| B5 | **Morning report HARVEST (C4/F39)** | Both of today's reports now carry (f) sections | Still no user go-ahead to harvest into TODO_LIST/ROADMAP | Your call (see Q2-adjacent) |

## c) NOT STARTED

| # | Item | Why |
|---|------|-----|
| C1 | Pre-push new-blob scanner (hook + `--range` mode) — the structural fix for this entire incident class | Design only; needs hook ergonomics decision (Q2) |
| C2 | go-taskqueue rewrite execution + input flip-back | Waiting on Q1 |
| C3 | gitleaks override / daemon-hooks investigation (B3) | Not started; self-contained session of ~30-60 min |
| C4 | One-off review of the 16 WARN blobs + `# not-a-secret:` annotation convention | Low priority; sampled 1 of 16 |
| C5 | macOS-clone resync after today's rewrite (if a clone exists there — I cannot see that machine) | Waiting on Q3 |
| C6 | gotchas-archive entry merging morning's deploy-block narrative with today's push-protection chapter | Morning item 50 + today's; blocked on B1 direction |
| C7 | Verify the CI leg of the audit script actually executes in nix-check.yml (Files>0 doctrine — I verified pre-commit wiring exists from `84c47e67`'s stat but never proved the workflow leg fires) | Not started; 10 min |

## d) TOTALLY FUCKED UP

| # | What is fucked | Severity | Root cause | Mitigation |
|---|---------------|----------|------------|------------|
| D1 | **The guard was the bug.** `audit-push-protection-literals.sh` — written specifically to prevent this incident class — shipped THREE successive versions each carrying a new tracked fixture component (`sgp_0123…` at line 48 in 63fd5a83, `mixed='aB3dEf…'` in the next iteration, bare `hex40='0123…'` in the earliest), directly violating its own "assembled literals must never appear in this file" comment | High — this exact class blocks every push until rewritten | Doctrine stated in a comment but not enforced by construction; every "fix" iteration ADDED a new literal while removing the old one | Tip is now fully runtime-derived AND the selftest proves the scanner works; structural fix = F1 |
| D2 | **The pre-commit secret gate did not stop any of the three iterations.** Commits `8647c15b`→`63fd5a83` landed literal-carrying blobs while (presumably) gitleaks ran on staged trees | High — a standing hole in the primary secret gate | Unresolved: either the `.gitleaks.toml` sourcegraph-rule OVERRIDE narrowed matching below the historical shapes, or daemon commits bypass hooks. Both are gate-integrity questions, not cosmetics | F6/F7; until answered, treat pre-commit green as necessary-not-sufficient for push safety |
| D3 | **This morning's doctrine sent you down the wrong path for go-taskqueue.** "history rewrite is forbidden" is true for PUSHED history; B1's commits are LOCAL-ONLY, where a 5-minute range rewrite is the strictly better resolution (no allowlist fingerprint that could silence a future REAL `xoxb-` leak — the exact risk F41 flagged) | Medium — wasted user-decision surface + a permanent allowlist almost created | The rewrite playbook did not exist until this session proved it | AGENTS.md now records it; apply to tq via F4 |
| D4 | **Status reports remain a secret-literal exfiltration surface.** This morning's report quoted a FAKE token verbatim and GitHub blocked on it — the report was 4 hours old. Any REAL token quoted the same way sails through if the pattern is unknown to gitleaks (the Resend-leak class) | Medium | "Fake is safe to quote" intuition; nothing scans reports for secret SHAPES before commit | The audit script now catches the 3 known shapes in tracked files — but only sgp_/sq0atp_/xox; the pattern-coverage rule (add shapes as they enter the ecosystem) is doctrine, not enforcement |

Nothing from this session left the tree broken: tip pushed, selftest green, tree clean, no active breakage.

## e) WHAT WE SHOULD IMPROVE

1. **Scan new blobs, not tracked files.** Tracked-file scans (and tip greps, and single `-S` sweeps) are structurally blind to historical file versions — today's blocker survived TWO green scans. The push-range new-blob set is the only surface that mirrors what GitHub actually judges. (→ F1/F2)
2. **Anchor verification on the flagged (commit, path, line) triple against THAT commit's blob.** My first rewrite pass missed the real literal because I grepped the TIP; `git show 63fd5a83:<path> | sed -n 48p` finds it instantly. One command, zero extra passes. (→ F12)
3. **Fixture components must be runtime-derived BY CONSTRUCTION, not by comment.** Every derived value in the selftest is now `printf seed | sha256sum …`; the doctrine should be a lint (the audit script's own main scan already rejects its own file — keep it that way). (→ F9)
4. **Status reports: shape-describe, never quote — even fakes.** Fake ≠ exemption; GitHub pattern-matches raw blobs. Already in AGENTS.md; needs to stay in every report-writing session's habits.
5. **History-rewrite verification must include the new-blob rescan**, not just ancestry/-S/refs checks — the existing AGENTS.md checklist has three of the four legs; today added the fourth. (→ F13)
6. **Pre-commit green ≠ push-safe.** Two independent scanners disagreeing (gitleaks narrowed vs GitHub prefix-required) means the gates must be re-aligned deliberately, not discovered via GH013. (→ F6)
7. **When a session's conclusion is "user must click an unblock URL", check whether the flagged commits are local-only first** — the cheap path may make the question unnecessary. (→ F4)

---

## Self-Review (the three questions, answered brutally)

**What did I forget?**
- **The single most costly miss:** I never ran `git show <flagged-commit>:<path> | sed -n '<flagged-line>p'`. The GitHub error HANDED me the (commit, path, line) triple, and I pattern-matched from the AGENTS.md lesson (`mixed` hardcoded) instead of reading the flagged line in the flagged commit. The real literal (`sgp_0123…`, line 48) was one command away; missing it cost two extra full rewrite passes (~10 min, 3× tip-SHA churn).
- **My scan patterns were narrower than the threat.** Passes 1–2 scanned prefix-required shapes (`sgp_`, `sq0atp-`, `xox`); the bare `hex40='0123…'` iterations matched none. GitHub's rule is file-level keyword + component. I knew this from the AGENTS.md gitleaks lesson and still built the narrower scanner first.
- I did not check whether `scan-history-secrets.sh` covers the Slack shape before declaring the audit script "the" coverage fix (B4).
- I did not ask WHY pre-commit gitleaks passed the earlier iterations before declaring victory (D2) — the gate that should have caught this stayed silent and I only noticed in passing.

**What could I have done better?**
- Read the flagged blob FIRST, build the replacements file from flagged content, THEN rewrite — one pass instead of three.
- Run the comprehensive new-blob scan (which I eventually built) as the FIRST verification, not the last: it found in seconds what `-S` archaeology fumbled through.
- Smaller command batches during verification: I ran two `-S` searches in one command and misread the combined output as one result set (cost one confused round trip); same class with `git log --find-object … | head -1` feeding `ls-tree` at a REMOVAL commit instead of the INTRODUCING commit.
- Tested the `-S`-still-hits states calmly as "count-changes vs surviving content" from the start — I burned a theory loop before the decisive blob-ancestry check.

**What could I still improve?**
- Automate what I did manually: the pre-push new-blob scanner (F1) turns today's entire playbook into a gate that fires before GitHub ever sees a blob.
- Align the two scanners (repo gitleaks config vs audit script shapes vs GitHub's actual rules) into one documented rule-shape table (→ F26), so "covered" is a claim with one source of truth.
- The playbook currently lives in prose (AGENTS.md); its mechanical core (replacements file + rescan loop) is a 20-line script waiting to exist (→ F2).
- Reflog hygiene after verified rewrites (old lineage still sits in local reflogs until gc) — document as an optional explicit step, never automatic (→ F14).

**Did I lie to you?** No. Two claims deserve precision, though: (1) "flagged-hits=0" is against the KNOWN shapes (sgp_/sq0atp_/xox + today's exact literals) — GitHub has thousands of patterns no local scan mirrors; the definitive proof is that the push itself succeeded. (2) "No real secrets" is verified for the two flagged literals; I did NOT run a full-repo secret taxonomy scan this session (out of scope per your instruction).

---

## f) Things We Should Get Done Next

> 28 substantive items (of the requested "up to 50" — the remaining slots would be vague filler; the morning report's 50-item pool is the wider brainstorm). **This section is the HARVEST input for `docs-health` → TODO_LIST/ROADMAP.** Items marked [carry] come from the 08-27 report and remain open; they are listed because this session touched or invalidated them.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| F1 | Add a pre-push hook scanning the new-blob set (`git rev-list --objects @{push}..HEAD` → `cat-file --batch-check` → shape grep, fail-closed on zero blobs scanned) — the structural fix that would have caught all 4 literals pre-push | High | M | Quality |
| F2 | Add `--range <range>` mode to `audit-push-protection-literals.sh` sharing `PATTERNS` with F1 so hook + manual scans never drift | High | S | Quality |
| F3 | Escape-hatch env (`PUSH_SCAN_ALLOW=1`-style) + blocking-vs-warn decision for F1 (Q2) | Medium | S | Quality |
| F4 | Apply the proven rewrite playbook to go-taskqueue's 4 local-only commits (fake `xoxb-…`) → push clean WITHOUT the unblock URL/allowlist | High | M | Bug |
| F5 | After F4: flip the SystemNix tq input from `git+file://…?rev=1a4eb48` to `github:?ref=master` (narHash-identical check per playbook) + update AGENTS.md tq section [carry: morning B3/F5] | High | S | Cleanup |
| F6 | Read the `.gitleaks.toml` sourcegraph-rule OVERRIDE (cites commit `49749626…`); decide whether its narrowed semantics are canonical or blinded the gate for `63fd5a83`'s `sgp_0123…` | High | S-M | Bug |
| F7 | Determine whether the PMA auto-commit daemon runs pre-commit hooks; if not, add a daemon-side gitleaks sweep or post-commit scanner (daemon commits are a standing secret-gate hole) | High | M | Quality |
| F8 | Propagate the `xox` shape to `scripts/scan-history-secrets.sh` if absent + full-history re-run | Medium | S | Quality |
| F9 | Add the keyword+40-char WARN heuristic to the audit script (file-level GitHub semantics; would have flagged today's bare-hex iterations) | Medium | S | Quality |
| F10 | Human-review the 16 WARN blobs one-off; adopt a `# not-a-secret: <reason>` annotation convention for allowlist/comment SHAs | Low | S | Quality |
| F11 | Add a Slack fixture to gitleaks-coverage-selftest (check first whether the repo gitleaks config has ANY slack rule — if not, a real `xoxb-` leak is invisible repo-side) | Medium | S | Quality |
| F12 | Add "anchor on the flagged (commit,path,line) triple against THAT commit's blob" to the AGENTS.md history-rewrite checklist | Low | S | Docs |
| F13 | Cross-link the new-blob rescan step into the AGENTS.md history-rewrite verification checklist (a)/(b)/(c) as leg (d) | Low | S | Docs |
| F14 | Document optional reflog-expiry (`git reflog expire --expire=now --all && git gc --prune=now`) as an explicit post-verified-rewrite step when purged content must leave local objects (manual only; never automatic) | Low | S | Cleanup |
| F15 | Verify the audit script's CI leg in nix-check.yml actually executes (Files>0 doctrine; gosec Files:0 false-green class) | Medium | S | Quality |
| F16 | Document the daemon-tip-mid-rewrite interaction in the playbook (HEAD moved under filter-repo twice today; range+rescan makes it safe; note it so nobody panics) | Low | S | Docs |
| F17 | Rule-shape table in the audit script header: which partner pattern needs which shape (sgp_ 40hex, sq0atp- 40alnum, xox 2–3 segments) + why fakes of each passed/failed which scanner [carry: morning item 31] | Low | S | Docs |
| F18 | Verify NO secret-scanning allowlist was created on GitHub for the tq token (if you already clicked the morning URL, remove it — F41's silencing risk); otherwise close F41 as moot under F4 | Medium | S | Ops |
| F19 | Decision rule in the playbook: REAL secret → rotate FIRST, rewrite second; FAKE → rewrite suffices (today's case) — one sentence, prevents future order-of-operations mistakes | Low | S | Docs |
| F20 | Annotate the 08-27 report (docs-health ANNOTATE): B1/Q2 superseded by the local-rewrite playbook | Low | S | Docs |
| F21 | HARVEST both of today's (f) sections into TODO_LIST/ROADMAP (morning C4/F39 still pending your go-ahead) [carry] | Medium | S | Docs |
| F22 | gotchas-archive entry: deploy-block incident (morning) + push-protection chapter (today) as one narrative [carry: morning item 50] | Low | M | Docs |
| F23 | VendorHash drift-gate sweep across ~15 LarsArtmann Go inputs (today's deploy died on exactly this class) [carry: morning F8] | High | L | Quality |
| F24 | Closure diet decision for mr-sync / hierarchical-errors on the system PATH (each is one vendorHash landmine) [carry: morning Q3] | Medium | S | Cleanup |
| F25 | macOS-clone resync after today's rewrite (old lineage diverges there until pulled) — pending Q3 | Medium | S | Ops |
| F26 | Consider a `commit-msg`-stage shape check for docs/status files specifically (reports are the observed exfiltration surface; D4) — cheapest point to catch report-quoted tokens | Medium | S | Quality |
| F27 | After F4 lands upstream: tq `vendor-hash` drift-gate check replication to sibling repos (morning B4 tail) [carry] | Low | M | Quality |
| F28 | Verify the redacted 08-27 report renders sanely (backticked shape strings inside table cells) — trivial visual check next time that file is touched | Low | S | Docs |

## g) Questions I Cannot Figure Out Myself

**Q1 — go-taskqueue path:** This session proved its 4 flagged commits (local-only) can be rewritten clean in minutes with NO allowlist and NO unblock URL — making this morning's B1/Q2 recommendation obsolete. Do you want me to apply the rewrite playbook to go-taskqueue (and then flip the SystemNix input back to `github:?ref=master`), or did you already click the morning unblock URL (in which case I'd instead verify + remove the allowlist to keep future real-`xoxb-` detection alive — morning F41)?

**Q2 — Pre-push scanner posture:** Should the F1 pre-push new-blob scan BLOCK the push (reject with the flagged blob list + a `PUSH_SCAN_ALLOW=1` escape hatch), or only WARN? Blocking catches the class at the right moment but adds a gate you can hit mid-flow (today's 3-pass session would have been 1 pass with it); warn-only keeps pushes frictionless but relies on you reading output.

**Q3 — MacBook clone:** Does a SystemNix clone exist on `Lars-MacBook-Air`? Today's rewrite means any stale clone now sits on the orphaned pre-rewrite lineage (diverged from origin; a careless forced push from there would resurrect the flagged blobs). I cannot see that machine from here; if it exists it needs a hard resync (`git fetch && git reset --hard origin/master` is NOT allowed per critical rules — I'd use `git pull --ff-only` after verifying local-only divergence, or re-clone).

---

*HARVEST pending: section (f) → `docs-health` HARVEST into `TODO_LIST.md`/`ROADMAP.md` once you say go (F21).*
*Waiting for instructions.*
