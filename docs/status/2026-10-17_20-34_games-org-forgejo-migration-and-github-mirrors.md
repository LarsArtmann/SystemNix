# Status Report: games-org Forgejo migration + GitHub backup mirrors

**Date:** 2026-10-17 20:34 CEST
**Scope:** This session only — git remote survey, Artmann-Games org migration to Forgejo, outbound GitHub push mirrors, SystemNix name-leak audit. Org repo names are private; only names ALREADY committed to this public repo are spelled out below (leak inventory in §d/e). The other 14 names are enumerated nowhere in tracked files — deliberately.

---

## a) FULLY DONE

1. **Full remote survey of `~/projects/`** (top level + `games/` subdir): ~240 repos catalogued — GitHub `LarsArtmann/*` (~230), `Artmann-Technologies/*` (5), `Artmann-Games/*` (17, all in `~/projects/games/`), `typespec-community/typespec-go` (user's org), 3 foreign clones (deer-flow, hermes-agent, activitywatch), 2 Forgejo-hosted (`domains`, `eventcatalog-hub`), 1 remoteless (`fine-tune`).
2. **motivation duplicate resolved**: top-level `~/projects/motivation` (removed externally mid-session; its HEAD `aa147e1` verified as ancestor of the kept checkout — zero data loss) and `games/motivation` consolidated; org GitHub repo verified in sync (0/0 divergence) before remote flip, no push needed.
3. **All 17 org repos migrated to Forgejo as NATIVE repos** (`lars/<name>`, SSH push-to-create): all branches + tags pushed from local checkouts, branch/tag parity verified per repo, HEAD resolves on all 17, all local origins flipped to `forgejo@evo-x2.home.lan:lars/<name>.git`.
4. **GitHub backup mirrors attached**: push mirror per repo (`interval 8h`, `sync_on_commit true`, PAT stored as push credential — same secret class forgejo already holds for pull migrations), initial sync triggered, **verified live**: all 17 GitHub HEADs equal forgejo HEADs. Forgejo is primary; GitHub is the backup.
5. **Durable, leak-free home for the attach mechanism**: `scripts/forgejo-attach-org-push-mirrors.sh` — generic org-namespace mirror attacher that enumerates repos at RUNTIME (GitHub org API + forgejo API); zero repo/org names hardcoded, so it lives in this public repo safely. Tested idempotent (17/17 "already attached" on re-run). Replaces the ephemeral `/tmp` script (trashed).
6. **Runbook updated**: `docs/services/forgejo.md` gained the "Org-namespace push mirrors" section documenting the gap (declarative `canonicalRepos` hardcodes `$GITHUB_USER/<name>`), the script, and live state.
7. **Name-leak audit of this repo delivered**: public-history exposure inventoried (see §d).

## b) PARTIALLY DONE

1. **Mirror verification depth**: HEAD-vs-HEAD compared on all 17 (synced), but GitHub-side full branch/tag parity after the initial mirror push was not re-verified (was verified forgejo-side before attach).
2. **`sync_on_commit` round-trip**: mechanism attached + initial sync proven, but no live commit→forgejo-push→auto-mirror→GitHub observation yet (declined to fabricate test commits in real repos).
3. **Leak remediation**: exposure fully identified and options presented (scrub-tracked-files / history rewrite / accept) — owner decision pending, nothing executed.
4. **Forgejo-side repo visibility**: push-to-create repos assumed private (forgejo default); flagged for UI confirmation instead of verifying via API myself — the root script had the access to check. Since verified? **No — still unverified** (see §f).

## c) NOT STARTED

1. Scrubbing the leaked names from tracked files (`scripts/update-vendor-hash.sh` lines 45+56, `docs/todo/services.md` line 578, status reports incl. archived) — blocked on owner choice.
2. History rewrite for already-committed names — blocked on owner choice (needs full rewrite checklist, force-push approval).
3. ~~Deleting the orphaned `LarsArtmann/motivation` GitHub duplicate~~ **RETRACTED in §h — no duplicate exists; the old name is a native-transfer redirect.**
4. Declarative org-namespace support in `forgejo-github-sync` (would subsume the new script; the 2026-09-18 audit already flagged this gap).
5. Forgejo CI/Actions for the games repos (never requested; noted for completeness).

## d) TOTALLY FUCKED UP

1. **Migration-target misread (recovered)**: "just do the Migration" was answered as a GitHub-org remote consolidation while BOTH forgejo-hosted repos were visible in my own first-turn survey. User correction ("Where is forgeo?!") cost a full round-trip. Root cause: I anchored on the previous turn's `games/` directory framing instead of the standing infra signal (forgejo = the self-hosted primary; SystemNix's own staged-primary plan).
2. **First survey blind spot**: scanned `~/projects/*/` non-recursively, then confidently claimed "only motivation is cloned locally" for the org — wrong (all 17 were in `games/`). Cascaded into the duplicate-repos confusion.
3. **Unattributed external change**: top-level `~/projects/motivation` vanished between turns (user or parallel session). Data-loss was correctly ruled out (ancestor check) but the actor was never identified — I flagged it inline only, no forensics, no persistence of the question.
4. **Pre-existing leak I reported as news is PUBLIC since May**: names of org repos (BDSM-World, KeyCountdown, SwettySwipperWeb) + the org name are committed to this PUBLIC repo (update-vendor-hash.sh commit 57c3e422; status reports 251c697b et al.; docs/todo/services.md line 578). Every additional session that spells them out (including this report, where unavoidable for the scrubbing inventory) marginally re-exposes them.

## e) WHAT WE SHOULD IMPROVE

1. **Infer the target from standing infra before acting on ambiguous one-liners**: forgejo-primary is this repo's own doctrine (staged-primary plan M05/M06); the default assumption for "migrate repos" here should have been forgejo.
2. **Recursive remote scans** — directory-shape assumptions (`~/projects/*/`) produce confidently wrong inventories; one `-maxdepth 2` loop avoids it.
3. **Verify via API what the API can answer** — repo visibility was checkable by the same root script that attached mirrors; "check the UI" delegated verification the agent could have owned.
4. **Operational scripts get a durable home at AUTHORING time** — the /tmp script was a leak-avoidance overcorrection; the generic-runtime-enumeration pattern (zero hardcoded names) satisfies both constraints and should be the default shape for name-sensitive tooling in a public repo.
5. **Round-trip test on first real push**: the first commit pushed to any of the 17 should be watched end-to-end (push → sync_on_commit → GitHub ref moved) to close the b)2 gap empirically.

## f) NEXT (harvested to TODO_LIST.md + domain libraries)

1. Verify forgejo-side visibility=private for the 17 games-org repos via API (root one-liner or generic script flag). [ready]
2. Verify full branch/tag parity on the GitHub mirror side for all 17 (HEAD-only checked so far). [ready]
3. Observe the first real `sync_on_commit` round-trip on a games repo push. [ready — rides the next natural push]
4. Owner decision: scrub leaked names from tracked files (3 files named in §d.4) — cheap, keeps history. [blocked:user]
5. Owner decision: history rewrite vs accept for the committed names (public repo; needs rewrite checklist + force-push approval). [blocked:user]
6. ~~Owner decision: delete orphaned `LarsArtmann/motivation` on GitHub~~ **RETRACTED — see §h: the name is a transfer redirect; deleting through it would destroy the live org repo.**
7. Design declarative org-namespace push-mirror support in forgejo-github-sync (subsumes the new script; audit-flagged since 2026-09-18). [decision]
8. Consider a forgejo dump restore drill covering push-mirror re-attach (the generic script is the recovery path — prove it on a scratch repo). [ready]
9. The 17 repos ride the forgejo subvol btrbk leg + weekly forgejo dump automatically — verify the next dump includes them (size delta check). [ready]
10. `fine-tune` repo has no origin — assign one or archive it. [ready]

## g) QUESTIONS (cannot figure out myself)

1. **Leak disposition**: scrub tracked files only, full history rewrite, or accept? (Rewrite on a public repo with clones/CI is irreversible-ish and breaks the auto-commit daemon's assumptions — my recommendation: scrub files now, accept history, rotate nothing since no secrets are in the leaked set.)
2. ~~**Delete `LarsArtmann/motivation` on GitHub?**~~ **RETRACTED (§h): the old name redirects to the live org repo — nothing to delete, and deleting through the redirect would be catastrophic.**
3. **Do the games repos need CI on forgejo** (Actions/runner, like eventcatalog-hub) or are they mirror-only? This decides whether the runner needs org-repo grants (the auto-assign phase's org gap).

---

**Verification evidence:** remote survey outputs (this session); forgejo↔GitHub HEAD parity table 17/17 SYNCED; idempotent re-run of `scripts/forgejo-attach-org-push-mirrors.sh` 17/17 already-attached; ancestor check `aa147e1` ⊂ games/motivation history.

---

## h) Correction addendum (same day, post-report)

**The "duplicate LarsArtmann/motivation repo" never existed — it is a GitHub native-transfer REDIRECT.** Owner question ("did we use the GitHub native transfer?") triggered the check: `gh api repos/LarsArtmann/motivation` returns `full_name: "Artmann-Games/motivation"` (gh follows the 302; a bare `200 OK` header check is NOT sufficient to prove a repo exists — the final hop after redirect returns 200). Consequences:

1. Every "both repos" comparison in the session (identical issues/PRs/pushed_at/created_at, 0/0 divergence) was the SAME repo observed twice through the redirect. The transfer predates this session (actor/date unknown — consistent with today's parallel cleanup: dependabot PR closes 17:33Z, top-level `~/projects/motivation` checkout removed between turns).
2. The §c.3/§f.6/§g.2 delete suggestions were a live hazard: `gh repo delete LarsArtmann/motivation` follows the redirect and would destroy the org repo — the canonical mirror target. All three surfaces retracted inline; the library row flipped to a [x]-RETRACTED state in docs/todo/services.md.
3. New lesson (generalizes): before claiming a GitHub repo "exists as a duplicate," check `.full_name` of the API response — name redirects (transfer/rename) are silent through gh and git (ls-remote follows them server-side too; the "LarsArtmann" remote on games/motivation was pushing to the org repo all along — which is also why it was always in sync).

