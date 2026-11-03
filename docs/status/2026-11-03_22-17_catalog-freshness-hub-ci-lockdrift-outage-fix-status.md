# Catalog Freshness Outage (hub lock-drift CI gate) + §22 CA Parity — Diagnosis & Fix Status

**Session:** 2026-11-03 ~21:00–22:20 CET · **Agent:** Crush (glm-5.3-flash) · **Trigger:** two WARNs pasted by the owner — (1) `architecture_catalog_fresh 0`, stamp age 579,460 s (6.7 d); (2) §22 dnsblockd CA parity duplicate-WARN.

**TL;DR:** The catalog freshness WARN was a **6-day hub CI outage**: every `eventcatalog-hub` build since Nov 2 15:11 died in ~18 s at the `check-package-lock-sync.sh` gate (package.json bumped to `^5.7.5` without a lock regen — 5th recurrence of the landmine class). Root cause fixed **hub-side** and verified locally (lock regen + pre-commit prevention gate); the fix is **owner-push-gated** — after `git push origin master`, the WARN self-clears within ~2 h with no SystemNix action. The §22 CA WARN was re-verified against the documented 2026-10-30 resolution (nixpkgs buildcatrust double-emission): benign, durable tripwire by design, no action.

---

## §a FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a.1 | **§22a diagnosis — complete causal chain** | Sync leg green (hourly generations, `journalctl -u architecture-catalog-sync` clean, latest `20261103-210000`); served stamp `builtAt 2026-10-28T03:25:46Z`; nightly CI fires (runner task 316 at 04:23); forgejo retained journal: **zero** `git-receive-pack` to the dist repo since Nov 2 14:45 → builds die **pre-publish**; run #176 raw log names the killer: `FAIL: spec drift on '@eventcatalog/core': package.json wants '^5.7.5', lock has '^5.7.4'`; gate re-run at each historic origin/master tip pinned both waves: `3f25f5a` (Oct 28 10:34, ^5.6.0→^5.7.2, no regen — first failed nightly Oct 29 04:23), `4ded736` (Oct 30, ^5.7.4, still failing), `9cd87dd` (Nov 2 04:39, regen landed, gate green), `8b4e7de` (Nov 2 15:11, owner bump ^5.7.5, no regen — current break) |
| a.2 | **§22a fix — lock regenerated, gate green** | Hub commit `278c1b4` "Sync package-lock.json with the core bump (unblocks the CI lock gate)": `npm install --package-lock-only` resolved the range to core **5.8.0** and saved `^5.8.0` in package.json (spec strings agree; rides the hourly `inventory.json` rewrite from the sync timer — daemon had swept the edit, amended per the daemon-race policy) |
| a.3 | **§22a fix — deep verification beyond the gate** | Full cheap-gate battery green at tip (frontmatter, package-lock, dependabot guard, `merge.py --selftest`, all 12 self-tests, gate-agreement, verify-gates, integrations selftest); real `npm ci` with the regenerated lock completed green in a throwaway clone at `278c1b4` (audit advisories = the known 16-moderate hub TODO row, non-blocking) |
| a.4 | **§22a prevention — commit-time gate, live-tested** | Hub commit `ae132bf`: `.githooks/pre-commit` runs `scripts/check-package-lock-sync.sh`; armed in the canonical clone (`git config core.hooksPath .githooks`); AGENTS.md Commands section documents the one-line arm command. **Both hook legs functionally tested** in a throwaway clone at the hook-bearing commit: a `^9.9.9` drift commit was BLOCKED with the house FAIL line; a clean commit passed |
| a.5 | **§22b — WARN verified benign against the documented resolution** | Live: bundle grep count **2**, fingerprints identical (`EE:A9:E1:BE:…:49:88`), `cn=dnsblockd-CA:eea9e1be` p11-kit name line — exactly the nixpkgs buildcatrust plain + `BEGIN TRUSTED CERTIFICATE` double-emission resolved 2026-10-30 (docs/services/dnsblockd.md:113-130). No second writer; the WARN is the designed durable tripwire. Doc stamped "Re-verified live 2026-11-03" |
| a.6 | **Self-harvest at authoring time** | 4 new TODO_LIST.md queue rows + 5 docs/todo/services.md library rows + 2 doc stamps (architecture-catalog.md freshness section, dnsblockd.md) — receipts in §f |

## §b PARTIALLY DONE

1. **§22a end-to-end recovery** — blocked on the owner push (`git -C ~/projects/eventcatalog-hub push origin master`, never `github`). Local master = 3 commits ahead (`278c1b4`, `ae132bf`, `01f64ba` TODO row), tree clean. After push: push-triggered build → dist publish → hourly sync → `architecture_catalog_fresh 1` within ~2 h. **Not yet observed** — the "self-clears" claim is module-logic inference, not a watched run.
2. **Push-triggered CI build green** — `npm ci` + full local battery prove the artifact; the real runner build with the regenerated lock has not executed (needs the push; the 6 h stale-sources auto-rebuild will keep failing until then).
3. **Hub canonical-clone protection is one clone deep** — `core.hooksPath` armed in `~/projects/eventcatalog-hub` only; hermes workspace clones / throwaway clones don't inherit it (documented arm command covers future clones).
4. **ci-log.sh forensics** — worked for this incident, but its `--steps` misclassified run #176 (an 18 s gate-death BUILD run) as "not a build run — probe-style?" (§f.1).
5. **Freshness alert text** — the WARN's only pointer (`journalctl -u architecture-catalog-sync`) was journal-blind this outage; doc updated with the better probe, the alert description itself not yet edited (needs a code edit + deploy, §f.2).

## §c NOT STARTED (new this session, harvested)

1. **ci-log.sh `--steps` pre-phase-banner misclassification** — gate-stage deaths (the cheap-first design's whole point) hide their failing step from the forensics tool → TODO_LIST [ready] + services.md (Source §f.1 of this report).
2. **Freshness alert-text probe pointer** — name `scripts/ci-log.sh` in the architecture-catalog registry alert description (gatus charset rules apply) → [ready], rides a deploy.
3. **CI-forensics retention posture [decision]** — forgejo journald retention measured ~1 day (the Oct 28 window is vacuumed: "No entries"); raise retention vs bless the hub's root-DB `ci-log.sh` as canonical vs both.
4. **ALERT_WEBHOOK_URL channel [decision]** — both hub workflows' notify-on-failure steps are armed but the secret is unset; **6 days of red CI paged nobody**. Pick ntfy / email / Forgejo webhook, provision, send one test page.
5. **Hub push handoff [blocked:user]** — staged, canonical row = hub TODO_LIST.md first `[ready]` entry; SystemNix mirror row in docs/todo/services.md.

## §d TOTALLY FUCKED UP (this session's real mistakes)

1. **Vacuous hook negative test (the phantom-green class, in miniature).** First drift test: the sed pattern (`^5.7.5`) didn't match the tree (spec was `^5.8.0` at that commit) → nothing staged → the hook never even ran → I read "hook-rc=0" as a pass. Caught on output read-back (no commit created, `nothing to commit`); the honest failure is that a test was asserted from before verifying the test could fail. Second test at the hook-bearing commit did it right: mutation confirmed introduced, block confirmed, clean-commit positive leg confirmed. The house has a name for this (mutation testing, `negative-test-lints.sh` discipline) — I should have started there.
2. **"Zero pushes since Oct 20" — an over-conclusion built on a vacuumed journal window.** My receive-pack grep returned 0 lines and I nearly concluded "CI stopped pushing"; the truth was journal retention (~1 day: the Oct 28 window answers "No entries"). monitoring.md literally carries this doctrine ("an empty read is never evidence" — the 2026-10-18 boot-id class); I applied it late, after re-probing the claimed window, not before concluding.
3. **§22b todo phrasing nearly sent me re-researching a solved problem.** My own task list said "find the second writer" — but the second writer was resolved 2026-10-30 in docs/services/dnsblockd.md. The pre-read (knowledge routing) caught it before any wasted work; the task should have been phrased "verify the documented resolution still holds", which is what was actually needed.
4. **Daemon sweeps mixed provenance into my commits.** Both commits were swept mid-flight (`278c1b4` absorbed the sync timer's `inventory.json`; the TODO row commit landed as a heuristic) — handled per the daemon-race policy (verify `git show --stat`, amend), but committing each edit immediately would have kept every commit single-provenance. The sweep window is ~10 min; my edit-to-commit gaps were longer.
5. **Minor: I initially trusted `ci-log.sh --steps`' "probe-style run?" label for #176** instead of reading the raw log first (the tool's heuristic is wrong for pre-banner deaths — now a queued fix, §c.1). A tool label is a claim, not evidence; I re-verified, but the order was backwards.

## §e WHAT WE SHOULD IMPROVE

1. **Empty-result journal reads need a retention probe FIRST** (what window does the journal actually hold?), before any "zero/none/never" conclusion. This bit me once tonight; the doctrine exists; make it reflexive.
2. **Every hand-rolled negative test gets a mutation check** — prove the drift/fault was actually introduced before asserting the guard's verdict on it. (Vaulted rule: "a verification close-out must answer the question the item ASKED" — the hook test initially answered "did the command exit 0", not "did the hook block".)
3. **In daemon-active repos, commit immediately after each finished edit** — the sweep window turns any delay into mixed-provenance commits requiring amends.
4. **Trust-but-verify ordering for docs**: check the service doc's traps/resolutions BEFORE framing the investigation; §22b cost ~0 because of the pre-read, and would have cost a session without it.
5. **Tool labels ≠ evidence** (`ci-log.sh --steps` misclassification): when a summarizer contradicts another surface (`--list`), read the raw artifact before either becomes a finding.
6. **CI failure paging must not depend on a human noticing red** — 6 days silent because one env secret is unset. Any armed-but-inert alert path deserves a "secret set?" assertion at eval/deploy time (hub-side follow-up).
7. **The freshness alert should name its real probes** (stamp + `ci-log.sh`), not a journal path that goes blind in a day.

## §f WHAT WE SHOULD GET DONE NEXT (≤50, grouped; ★ = harvested this session, ✓ = pre-existing row referenced)

**Immediate — this incident's tail (owner-gated):**
1. ★ **Push the hub fix**: `git -C ~/projects/eventcatalog-hub push origin master` — unblocks everything below (hub TODO canonical row + services.md mirror row, [blocked:user]).
2. ★ **Watch the push-triggered build green** via hub `scripts/ci-log.sh --list`, then `--steps <run>`; stamp must refresh to today.
3. ★ **Confirm the freshness WARN self-clears**: `.prom` shows `architecture_catalog_fresh 1`, stamp age < 36 h budget (≤2 h after publish; no SystemNix change needed).
4. ★ **Pick + provision ALERT_WEBHOOK_URL** (ntfy/email/Forgejo webhook) for both hub workflows; send one test page [decision].
5. ★ **Retain the lock-regen commit message's caveat**: the served generator is now core **5.8.0**, not the ^5.7.5 the Nov 2 commit typed — sanity-check the built site once (`npx eventcatalog preview` or the served catalog) for a clean 5.8.0 render.
6. ★ **Decide CI-forensics retention posture** (journald raise vs `ci-log.sh`-as-canonical vs both) [decision].
7. ✓ **rpi3-dns buildcatrust duplicate check** at its next deploy probe (services.md [ready], 2026-11-02 close-out) — same `grep -c` method used tonight confirms the method works.
8. ✓ **Sweep docs/services/*.md for other "second writer unidentified" phrasings** (one rg pass; services.md [ready]).

**Hub pipeline hardening (agent-actionable once pushed):**
9. ★ **Fix `ci-log.sh --steps` pre-phase-banner misclassification** (§c.1).
10. ★ **Name `ci-log.sh` in the freshness alert text** (registry edit + deploy, §c.2).
11. **Hub CHANGELOG entry**: the Oct 28→Nov 3 outage narrative (two drift waves, 6 days dark, gate+hook fix receipts) — append-only file, one entry.
12. **Consider a staleness floor for the served stamp inside the hub** (probe exits OVERDUE at MAX_BUILD_AGE_HOURS — check that constant against the 36 h serving budget; the probe dispatched rebuilds for days without anyone noticing the rebuilds were red).
13. **Hook adoption beyond the canonical clone**: hermes workspace clones + any future clones need the arm command; consider a workspace-doc line (the hermes-workspace-doc ExecStartPre surface) or an `init` script.
14. **Dependabot config relevance**: `.github/dependabot.yml` is guarded by CI, but the hub's GitHub remote is fetch-only (canonical-Forgejo flip) — decide whether Dependabot does anything at all now, else drop the guard with the config.
15. **`mirror-sync-sources.sh` / `check-hub-mirror-lag.sh` cadence**: both exist as sudo tools; nothing schedules them — decide whether mirror-lag belongs in a timer or stays manual.
16. **npm audit 16-moderate row** (hub TODO [ready]): absorb upstream when core/sdk ship fixed transitives — unchanged, still open.
17. **Daemon commit hygiene in the hub**: `inventory.json` rides unrelated commits (tonight: into my lock fix). If the daemon ever grows path grouping, generated-vs-authored separation would keep provenance clean (SystemNix-side daemon question, low priority).
18. **Wave-1 attribution (optional)**: `3f25f5a` bumped core ^5.6.0→^5.7.2 alongside a formatter sweep — confirm which session/tool edits package.json during layout adoption, so the hook isn't the only thing standing between that class and CI.
19. **stale-sources probe verdict history**: probe outcomes live only in the forgejo DB (pruned); consider emitting the last probe verdict as a textfile metric via a small host timer (would have made the 6-day OVERDUE loop visible in monitoring instead of only in CI).
20. **Hub CI run retention**: `--list` showed only ~5 runs — check forgejo's actions-log pruning config so post-mortems keep ≥1 week of logs.

**SystemNix monitoring/observability:**
21. ★ **Deploy the alert-text edit** when it lands (it rides the next evo-x2 deploy; no rush independent of other queued deploy items).
22. **docs/services/architecture-catalog.md**: the freshness section now documents the outage class — fold the same two lines into the module's alert description once §f.10 lands (doc/config must not drift).
23. ✓ **node_exporter duplicate-row self-check** (monitoring.md corollary queued 2026-10-25) — still open.
24. **Gatus "hub CI stale" check?** — the served stamp IS the freshness signal (already checked); a SECOND check on ci-log's latest-run-age would catch "CI dead but dist young" windows (e.g. manual publishes) — evaluate, don't auto-add (check sprawl is its own anti-pattern).
25. ✓ **Forgejo runner start-window false positive in post-deploy §b** (services.md [ready], gen-973 class) — the ensure-timer convergence tolerance; unchanged.

**Prevention/hygiene patterns (cross-repo):**
26. **Bare-bump landmine sweep**: the lock gate + hook cover package.json; check whether OTHER generated-agreement pairs exist in the fleet (e.g. templ `*_templ.go` is already guarded in SystemNix pre-commit; flake `expected-locks.nix` pair — the parallel session's file tonight — look at whether it has a drift gate).
27. **"Armed but inert secret" audit**: enumerate workflow steps gated on secrets that are unset (ALERT_WEBHOOK_URL pattern) across hub repos — one rg pass over `.forgejo/workflows` for `${{ secrets.` names vs the repos' secret lists (needs forgejo admin read; ci-dispatch's mint pattern could read it).
28. **Hook-arm coverage check**: one-liner script asserting `core.hooksPath` is set in the canonical clones that carry `.githooks/` (SystemNix repo could grow the same assertion for its own pre-commit).

**Pre-existing queue rows adjacent to tonight's surfaces (do NOT requeue; listed for the owner's dispatch view):**
29. ✓ Deploy evo-x2: discordsync-immich-verify 403 fix (services.md + TODO_LIST, 2026-11-03) — will also carry §f.10/§f.21's alert-text edit if batched.
30. ✓ OpenCloud IDM upstream filing + first-login verification (services.md, 2026-11-03).
31. ✓ dnsblockd data-growth sanity check (hot/dnsblockd 8.5 G, services.md).
32. ✓ nh `os switch` → `stc test` profile trap (services.md, gen-968 class).
33. ✓ HM fleet timers first-execution soak (services.md).
34. ✓ `notify-failure@.service.service` double-suffix verify (services.md).
35. ✓ Pre-deploy exclude-vs-live-tree audit probe + dormant-gate eval-gap probe (storage.md, offsite-borg session tonight).
36. ✓ Boot-0 storm attribution DONE row + premise-freshness sweep (stability.md) — note for §f planning: forgejo's retention floor means CI-outage forensics rows are ALSO retention-sensitive (§c.3 generalizes).
37. ✓ cv upstream nil-deref fix + go-health-dashboard per-remote evidence (upstream.md).
38. ✓ Pre-commit buildflow 4-min leg + fixture-template pre-land hook-check (pipeline.md).

**Park / explicitly not harvested (reasons recorded):**
39. ★ *Deliberately not harvested:* "keep core at exactly ^5.7.5 instead of npm's 5.8.0 absorption" — owner-intent question (§g.2); the current state is gate-green and semver-legitimate, so no row until the owner answers.
40. ★ *Deliberately not harvested:* "re-verify §22 parity on every deploy" — the smoke already runs every deploy (post-deploy-check §22); tonight's check was a one-off re-stamp, no recurring work created.
41. *Deliberately not harvested:* "investigate who added hermes-agent as collaborator" (seen in the forgejo journal this session) — almost certainly the parallel SystemNix session's sanctioned provisioning; no anomaly signal, and investigating another session's live work violates the concurrent-session courtesy.

## §g QUESTIONS ONLY THE OWNER CAN ANSWER

1. **Push now?** The fix (3 commits: lock regen `278c1b4`, prevention hook `ae132bf`, TODO row `01f64ba`) is verified locally and sits owner-push-gated. On your explicit go, I execute `git -C ~/projects/eventcatalog-hub push origin master`, watch the build to green via `ci-log.sh`, and confirm the freshness WARN self-clears — end to end, tonight.
2. **Core 5.8.0 or exactly 5.7.5?** npm's regen absorbed your `^5.7.5` range to the newest in-range release (5.8.0) and saved `^5.8.0`. Keep the absorption (my default), or pin the lock to exactly 5.7.5 before the push? (The served generator changes minor version either way only if you say 5.7.5-strict.)
3. **Where should CI failures page you?** ALERT_WEBHOOK_URL is unset in both hub workflows — ntfy, email, or a Forgejo webhook? And should the webhook URL live as a Forgejo repo secret pasted by you (sops-style, editor-only), or minted via the existing `ci-dispatch.sh` self-elevating pattern?
