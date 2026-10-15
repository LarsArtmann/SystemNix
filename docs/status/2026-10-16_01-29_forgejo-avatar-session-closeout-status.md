# Forgejo Avatar Sync — Session Closeout (incl. OIDC decision flip) — Status + Self-Review

**Session:** 2026-10-16 ~00:10–01:29 CEST, two waves · **Supersedes:** `docs/status/2026-10-16_01-04_forgejo-avatar-sync-github-parity-status.md` (kept as the W1 deep-dive: contract details, fixture analysis, first battery)
**Owner ask (W1):** "sync all my Avatars on forgeo <> at least for Orgs!" · **Owner decision (W2):** "OIDC > GitHub for Forgeo"
**State at write time:** both waves implemented, fixture-proven, eval-green, **in the committed tree** (flip verified at `_forgejo-scripts.nix:652`, landed in daemon commit `2462d648`) — **deploy pending**, org-avatar live verify queued.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **W1 — avatar-sync phase** (4th ExecStart of `forgejo-github-sync`, org listing with phantom-green guard, stateless byte-compare converge, binary-safe base64 payload, 1 MiB cap, warn+count-then-exit-1-after-full-pass, `forgejo_avatar_*` textfile metrics) | full detail: 01-04 report §a; `forgejo-scripts-fixture` green |
| a2 | **W1 — API contract verified against the DEPLOYED forgejo** (swagger.v1.json pulled live, v15.0.10: `POST /orgs/{org}/avatar` + `/user/avatar`, `{"image": base64}` → 204; org/user GET carry `avatar_url`) | 01-04 report §a2 |
| a3 | **W2 — owner decision implemented**: `FORGEJO_AVATAR_SYNC_USER` **defaults to false** — Pocket ID owns the user avatar via the OIDC picture claim (`oauth2_client.UPDATE_AVATAR`); `=true` opts back into GitHub sync. Orgs are the phase's payload. Header carries the decision + date; skip message reworded ("User avatar sync skipped … OIDC (Pocket ID) owns it") | `_forgejo-scripts.nix:645-652,797`; unit phases comment in `forgejo.nix` corrected to org-only default |
| a4 | **W2 — fixture re-based on the new default**: run 1 = user upload **only with explicit `FORGEJO_AVATAR_SYNC_USER=true`** (opt-in path coverage retained, payload round-trip assert intact); run 2 = **env-unset default** asserts the user is skipped (no POST, count stays 1, `targets=1 updated=0 in-sync=1`) while the org converges; run 3 = POST-500 opt-in failure path unchanged | `nix build .#checks.x86_64-linux.forgejo-scripts-fixture` → exit 0 |
| a5 | **W2 — verification battery**: fixture green; **definitive** `nix flake check --no-build` → "all checks passed!" (grep-confirmed, not tail-inferred); `nix fmt` scoped → 0 changed | session log |
| a6 | **W2 — zero drift across 6 surfaces**: runbook sync-model row (orgs-only + decision), CHANGELOG bullet retitled "orgs (user stays OIDC-owned)", `docs/todo/services.md` row + `TODO_LIST.md` one-liner both updated (edit-both rule), 01-04 report annotated with a dated ADDENDUM | grep-verified post-edit |
| a7 | **Tree-truth check**: flip confirmed IN the committed tree (`_forgejo-scripts.nix:652` `:-false`, commit `2462d648`); W1 report committed (`202def65`); only foreign diff in tree = `modules/nixos/desktop/offline-banner.nix` (parallel session, untouched, flagged) | git at 01:29 |

## b) PARTIALLY DONE

| # | Item | Missing half |
| - | ---- | ------------ |
| b1 | **Live verification** — everything agent-verifiable is done; the RUN is deploy-gated (owner deploys). Expectations now **org-only**: first sync run uploads every org avatar, `forgejo_avatar_failed 0`, second run `updated=0` | deploy + 2 hourly runs (queued `services.md:63` + `TODO_LIST:207`) |
| b2 | **Verbatim-storage assumption** — byte-compare converge rests on forgejo storing uploads verbatim (Gitea-source inference, never live-probed). Discriminator = the second run's `updated=0`; remedy if falsified = state-file hashing. Labelled UNVERIFIED everywhere it's claimed | same deploy |
| b3 | **Observability** — metrics publish, unit OnFailure → Discord covers phase failure; **no Gatus check** on `forgejo_avatar_failed` (deliberate, decision documented; §g Q3) | optional check |
| b4 | **Commit attribution** — the flip is buried in heuristic daemon commits (`2462d648`); only `4b63032b` (base64 fix) carries a real message. W1's `d45ced6b` mixed my hunk with a FOREIGN boot-speed report (parallel session) — flagged, untouched | nothing actionable now |

## c) NOT STARTED (noticed, deliberately out of scope)

1. **Org metadata parity** (`full_name`/`description`/`website` via `PUT /orgs/{org}`) — same create-if-missing bare-org gap as avatars; sibling-sized session (§g Q1)
2. **Gatus "Forgejo Avatar Sync" check** consuming `forgejo_avatar_failed`/stale `last_run` (§g Q3)
3. **Module-level options** (`services.forgejo.avatarSync.{enable,syncUser}`) — the user-sync toggle is env-only; flipping it today needs a module edit + deploy
4. **Create-time avatar** in mirror-github's org-create POST (no default-avatar first hour)
5. **Runbook break-glass recipe** (force re-sync: `DELETE /orgs/{org}/avatar` → next run re-uploads)
6. **Unit/timer description truth-sync** — still says "Sync all GitHub repos to Forgejo" (avatars are phase 4)
7. Repo-level avatar API (`/repos/{owner}/{repo}/avatar` in the deployed swagger) — GitHub has no repo avatars; permanently N/A, recorded

## d) TOTALLY FUCKED UP

**Nothing live** — nothing deployed, no service state touched, `nix flake check` green at close. Honest near-miss ledger, this round included:

1. **A destructive one-liner I should never have typed** (W2, CHANGELOG): `python3 - <<EOF … EOF || sed -i '15s/.*/REPLACED/' CHANGELOG.md` — an empty python program as the "safe" side and a **whole-line clobber as the fallback**. It didn't fire (python exits 0 on empty input, so the `||` never ran) and the subsequent view confirmed line 15 intact — but had python3 hiccuped, I would have destroyed my own CHANGELOG entry. Chaining a destructive sed/rm behind `||` as a "placeholder" is banned for me going forward; if a command is a no-op, send a no-op, not a loaded gun.
2. **A bash-syntax hazard shipped into a Nix string**: my skip-message edit initially ended with a stray `; \`, which would have broken the script (line-continuation into `else`). Self-caught ~60s later by a follow-up grep — but that was luck-adjacent, not process: the edit tool does not syntax-check shell inside Nix strings. The reflex that caught it (grep the exact line right after editing shell-in-Nix) should be unconditional, not occasional.
3. **Three payload/URL bugs in the W1 first build** (POST missing `/avatar`; compare-fetch overwrote the upload buffer → would re-upload the OLD avatar forever and never converge; `jq -Rs` embeds RAW bytes, not base64 — violating the contract I had copied into the same file's header). All caught by the fixture pre-deploy; density embarrassing, pipeline vindicated.
4. **Wasted calls**: a no-op placeholder command (the same one as #1), two edit-refusals from stale file reads under daemon churn (content-pin BEFORE editing was the doctrine I re-learned mid-session), and one local debug cycle on the documented PATH-shadowing trap (`inject()` exists precisely for that).

## e) WHAT WE SHOULD IMPROVE

1. **Never chain destructive fallbacks** — see d1; one-line commands must be inert by construction.
2. **Contract-first asserts** — the wire round-trip assert caught the W1 bugs; writing it before behavior tests would have collapsed three fixture builds into one.
3. **Assumption labels live in the claim sentence** — "forgejo stores uploads verbatim" was stated as fact in comments/CHANGELOG before being probed; the UNVERIFIED label now travels with it (b2).
4. **Post-edit grep as a hard rule for shell-in-Nix edits** — the `; \` catch was a grep afterthought; make it unconditional (d2).
5. **Daemon-churn discipline**: re-read (not recall) immediately before every edit on shared surfaces — two refusals this round prove recall decayed within minutes.
6. **Fixture hygiene**: code-file-without-body stub responses cat a nonexistent path to stderr (papered with `: > .body`); a one-line stub fix cleans all sections.
7. **Did I lie?** No. One overclaim (verbatim storage) is now labelled everywhere it appears; "verified against the deployed swagger" is probe-backed, not memory-backed; the flip's "fixture green" claim in the 01-04 addendum was annotated as in-flight and the definitive green arrived before this report.

## f) NEXT — 30 items, impact-sorted (honest cap: a padded 50 would be noise)

**H** = harvested/queued · **C** = CLOSED this session · **R** = roadmap (deliberately not harvested — no owner signal)

| # | Item | Tag |
| - | ---- | --- |
| 1 | Deploy; first sync run uploads all ORG avatars | H (services.md:63, TODO_LIST:207) |
| 2 | Second-run `updated=0` → settles verbatim-storage; if re-encode seen, switch to state-file hashing | H (same row) |
| 3 | ~~User-avatar source decision~~ **CLOSED: OIDC > GitHub, default false** | C (W2) |
| 4 | Org metadata parity (description/website/full_name) — sibling session | R (§g Q1) |
| 5 | Gatus "Forgejo Avatar Sync" check (`forgejo_avatar_failed` / stale `last_run`) | R (§g Q3) |
| 6 | Module options `services.forgejo.avatarSync.{enable,syncUser}` (kill the env-only toggle) | R |
| 7 | Create-time avatar in the org-create POST (no default-avatar hour) | R |
| 8 | Runbook break-glass: force avatar re-sync recipe (`DELETE /orgs/{org}/avatar`) | R |
| 9 | Unit + timer description truth-sync ("repos" → "repos + org avatars") | R |
| 10 | Fixture stub: auto-touch body file on code-only responses (kills `cat` stderr noise) | R |
| 11 | statix/deadnix standalone re-run at next push window (daemon-amend bypassed the hook legs; treefmt covered format only) | R |
| 12 | `curl --max-filesize` instead of post-download `wc -c` cap | R |
| 13 | GH_AVATAR_TMP.b64 leak window on SIGKILL (tmpreaper absorbs; note) | R |
| 14 | Cross-link shared PATH-stub scaffolding row (TODO_LIST:142) with the avatar fixture's counter-reset/slot-ownership pattern | R |
| 15 | Post-deploy: confirm real org count N + `forgejo_avatar_*` visible in node_exporter scrape | R (folds into #1) |
| 16 | Runbook sync-model row: per-run cost note (~1 listing + N+2 downloads, seconds) | R |
| 17 | Watch: GitHub org whose login collides with a local-only forgejo org (`starred`) → 403/404 warn+count (acceptable; document if it fires) | R |
| 18 | Re-verify Catppuccin theme assets on live v15.0.10 (runbook cites v15.0.9-era verification) | R |
| 19 | Close the sibling `[decision]`: Pocket ID `avatarFile` 4MB master vs 54KB `avatar-dms.png` (services.md:61) — avatar surfaces are being touched NOW, this is the same face one layer up | R |
| 20 | `forgejo_avatar_last_success_timestamp_seconds` if #5 lands | R |
| 21 | Pathspec-commit future avatar follow-ups out of shared daemon sweeps | standing |
| 22 | post-deploy-check §-leg for avatars? (probably overkill — unit + metrics coverage; decide with #5) | R |
| 23 | One-week journal noise check (per-run GitHub GET budget across 4 phases; still <20 calls/run) | R |
| 24 | Revisit only on slowness: avatar phase adds N forgejo GETs per run | R |
| 25 | Document the 1 MiB cap rationale in the runbook (GitHub avatars ≤460px; cap is abuse-guard) | R |
| 26 | Sweep `_forgejo-scripts.nix` for other metadata-less create calls (org create is the known one) | R |
| 27 | Fixture header: note the stub `--data-binary` capture extension | R |
| 28 | No upstream filing — all endpoints used as documented; no Forgejo bug found | note |
| 29 | §f items 4–30 stay R until you signal; only 1–2 are harvest commitments | note |
| 30 | Old W1 report (01-04) + this closeout = the pair to cite; ANNOTATE, never rewrite, if later work touches avatars | standing |

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **Org metadata too?** Avatars only was the ask; the mirror creates orgs bare (no `description`/`website`/`full_name`). Want the sibling parity session, or stop at avatars?
2. **Deploy timing** — ride the next co-tenant deploy train (parallel sessions are actively landing work), or a dedicated `nix run .#deploy` now to close the live-verify row today? (Owner-run; I cannot deploy.)
3. **Gatus check on `forgejo_avatar_failed`** — yes (fail-loud within 30s of a failed pass) or rely on the unit's OnFailure Discord page (fires only when the whole phase exits 1 — which it does after ANY per-target failure, so marginal value is low)? Your alert-budget call.

---

*Verification chain at close: fixture (behavior + wire round-trip, default-off user) → `nix flake check --no-build` "all checks passed!" → evo-x2 ExecStart eval → `nix fmt` 0-changed → tree-truth grep (`:-false` committed). Remaining gap to "done": one deploy.*
