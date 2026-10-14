# Status Report — sqlite3 default-binary session (2026-10-14 19:41 CEST)

**Scope:** single task — "Add sqlite3 to NixOS as a default binary" — plus the self-review questions (what was forgotten, what could be better, what to improve next). Per operator instruction: no unrelated research; everything below traces to this session's own runs and observations.

**Session window:** ~19:0x–19:41 CEST, 2026-10-14. Head: `47727869` (auto-commit daemon) at authoring time — the daemon swept this session's AGENTS.md bullet (2 lines) as its own commit at 19:43.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a.1 | `pkgs.sqlite` (the `sqlite3` CLI) added as a default system binary in the shared essential packages list, "Data manipulation" section | `platforms/common/packages/base.nix:168` (one line: `pkgs.sqlite # sqlite3 CLI for inspecting service sqlite DBs`), landed in daemon commit `71c2e275` (verified via `git show 71c2e275 -- platforms/common/packages/base.nix` — exactly the intended one-line diff) |
| a.2 | evo-x2 toplevel evals green | `/nix/store/ivm4shsc7qzsn6j6k6l11lz3wwyq6ids-nixos-system-evo-x2-26.11.20261011.7fd4004` (only pre-existing, unrelated eval warnings: catalog-subdomains, llama-rag freeze-#5 — see §f) |
| a.3 | evo-x2 toplevel BUILD realized; `sqlite3` present in the system path | `.../sw/bin/sqlite3 → /nix/store/iy2zkfn4l0w24xabv6ryi0vh7bpjvqm6-sqlite-3.53.3-bin/bin/sqlite3` (readlink-verified inside the realized toplevel) |
| a.4 | Darwin host (`Lars-MacBook-Air`) evals green with the same shared list | `/nix/store/q0gsf02iac3ib03n5r9anc24sgv642zw-darwin-system-26.11.4cff07d` (closes the gap from my first reply, which asserted Darwin coverage by inference only) |
| a.5 | Post-daemon-sweep lint verification (the daemon commit bypassed the pre-commit filetype legs) | Repo's OWN pinned formatter: `nix fmt . platforms/common/packages/base.nix` → `formatted 19 files (0 changed)` — the committed file including my line is treefmt-clean |
| a.6 | Formatter misfire caught and cleanly reverted (my own action, zero harm landed) | Ad-hoc `nix shell nixpkgs#alejandra --check` false-flagged the clean file; a naive fix produced a ~200-line style-churn diff; reverted via `git restore` back to the `71c2e275` content before any commit |
| a.7 | Gotcha recorded at discovery time (memory maintenance) | New AGENTS.md bullet under Build & Deploy: never run an ad-hoc formatter; `nix fmt` is the only style arbiter; `nix fmt . <path>` for scoped runs; `nix run .#formatter` is a broken invocation |

## b) PARTIALLY DONE

| # | Item | What works | What remains | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| b.1 | sqlite3 as a default binary | Committed (`71c2e275`), evals green on BOTH hosts, toplevel built in the store | NOT deployed — the RUNNING evo-x2 system does not have `sqlite3` at `/run/current-system/sw/bin` yet | Deploy timing is an owner call (see §g.1): this toplevel also carries the parallel session's gate-removal work (`TODO_LIST.md` line 22, `[ready]`) and anything else already committed | S |
| b.2 | Cross-host verification | evo-x2: eval + build + binary-path verified. Darwin: eval verified | Darwin `sw/bin/sqlite3` presence not probed (needs a darwin build, which the 90%-full macOS disk makes deliberately lazy) — the shared-list inference is now backed by a green eval, not a build probe | None (low priority) | S |
| b.3 | Post-deploy live probe | Planned: `sqlite3 --version` on evo-x2 after deploy | Not possible pre-deploy | Rides b.1's deploy | S |

## c) NOT STARTED

| # | Item | Why not started | Still wanted? |
|---|------|-----------------|---------------|
| c.1 | Deploy evo-x2 (carries sqlite3 + gate-removal + all queued committed work) | Waiting on owner answer §g.1 (ship-now vs quiesce-first; shared-tree concern: a deploy activates every other session's committed work too) | Yes — blocked on §g.1 only |
| c.2 | Root-cause the transient first `nix build --no-link -L` exit-2 (error output was truncated by my own `tail -3`; retry with plain flags succeeded immediately) | Non-reproducible in-session; queueing a paid dispatch for a ghost violates the no-vague-queue-item rule | Watch for recurrence; investigate only if it re-fires |
| c.3 | Trash the repo-root `result` symlink when quiescent | Attribution moved DURING the session: at 19:11 it pointed at `lock-audit-selftest` (stale from some earlier check); by 19:41 it points at MY evo-x2 toplevel — a concurrent `nix build` without `--no-link` re-pointed it. It is untracked, harmless, and shared | Only at quiescence, with §g.2's answer |
| c.4 | Catalog-subdomains and llama-rag eval warnings (noticed, NOT researched — outside session scope) | Pre-existing backlog smells; the queue rule requires premise-check/ownership grep before queueing, and the operator forbade that research this session | See §f.5/§f.6 |

## d) TOTALLY FUCKED UP

**Nothing landed broken.** Two process stumbles, both fully self-corrected, named for the record:

1. **Ad-hoc formatter misfire (caught in one tool call, reverted before any commit).** I reached for `nix shell nixpkgs#alejandra --check` to re-run the lint leg the daemon sweep had bypassed. Latest-alejandra's style differs from the repo's pinned treefmt-full-flake alejandra, so the tree-clean file "required formatting"; my `--fix` pass rewrote ~200 lines I did not author (`}: let` collapsing, `[x]` bracket style, if/then/else flattening). Recognized as version drift, `git restore`'d to the committed content, then verified with the repo's OWN formatter instead (0 changed). Damage landed: none. Lesson recorded: AGENTS.md bullet a.7. Severity if it HAD landed: formatter ping-pong on every future `nix fmt` + a noisy diff co-mingled with other sessions' work.
2. **First build attempt exited 2 with the error truncated by my own `tail -3`.** Re-run without `-L` and with proper output handling succeeded immediately (exit 0). Root cause unknown, non-reproducible; suspect a concurrent-session eval race or a `-L` log-mode quirk. No state damage (build is pure).

**Flagged, not mine, untouched (multi-agent shared-tree discipline):**

- The working tree briefly carried an unattributed modification to `.github/workflows/negative-tests.yml` (1 line: the negative-test harness comment list gained `inputpin`). During report authoring (19:39) the daemon swept it into commit `1216beff` together with one more file. Content is a comment-only edit consistent with the parallel session's `lint-static.nix` + flake-input-pin-audit work stream (their 19:30 report covers it). Benign, committed, no action needed — recorded here because I flagged it as foreign the moment I saw it, per the shared-tree rules.
- Daemon commit `71c2e275` batched THREE files: my `base.nix` line + a parallel session's status report (`docs/status/2026-10-14_19-30_geometrikks-fixes-deployed-verified.md`) + their `flake/parts/checks/lint-static.nix` edit. Provenance is co-mingled by the daemon's design; per the shared-tree rules I verified only MY file's hunk and did not co-verify theirs.

## e) WHAT WE SHOULD IMPROVE

| # | Pattern | Impact | Fix |
|---|---------|--------|-----|
| e.1 | **Ad-hoc tooling vs pinned tooling** — reaching for `nixpkgs#alejandra` instead of the repo's formatter is exactly how version-drift churn gets into a shared tree | High (churn diffs, formatter ping-pong, co-mingled blame) | Done: AGENTS.md bullet. Recurrence should now be a hard "no" |
| e.2 | **Verification claims outran evidence** — my first reply asserted Darwin coverage ("which shares this list") from inference, not eval; the repo's own rule is "a 'verified' label must cover every fact asserted" | Medium (a reviewer would have had to catch it) | Closed in this session: darwin toplevel evaled green (a.4). Habit: eval BOTH hosts whenever `platforms/common` files change |
| e.3 | **Lint AFTER edit, not after the daemon sweep** — the daemon committed my file within minutes; had the style actually been off, the violation would already be in history and the fix would be an amend into a heuristic commit | Medium | Run the scoped `nix fmt . <path>` + `statix check <path>` immediately after editing any `.nix` file, before the ~10-min daemon window closes |
| e.4 | **`nix run .#formatter` is a trap** — it errors with `attribute 'formatter.type' does not exist` because `formatter.<system>` is a package, not an app; only `nix fmt` works | Low (one wasted invocation, now documented) | Documented in the AGENTS.md bullet; no code change warranted |
| e.5 | **Truncated error output delayed diagnosis** — piping build failures through `tail` hid the real error message | Low | Pipe stderr to a file first, then show the tail of the FILE |
| e.6 | **`result` symlink lifecycle is invisible** — it flips between sessions' builds without any record; my own §c.3 draft called it "stale" minutes before a parallel build re-pointed it at my own toplevel | Low (confusion cost only) | Treat `result` as always-provisional: never attribute, never clean except at quiescence; never use `result` as evidence (always `--print-out-paths`) |

## f) NEXT — up to 50 (grounded in this session; N kept honest instead of padded)

Ranked by impact. Format: Task — Impact / Effort / Category. Harvest disposition table below.

1. **Deploy evo-x2** (`nix run .#deploy`), which ships sqlite3 AND the pending gate-removal work in one toplevel; then run the deploy-anchor check (`readlink /run/current-system` = latest `system-N-link`) and probe `sqlite3 --version` — Critical / S / Feature
2. **Answer §g.1 (deploy timing)** — the deploy carries other sessions' committed work; ship-now vs quiesce-first is an owner call — Critical / S / Decision
3. **Verify the catalog-subdomains eval warning is owned** — 20 integration subdomains (`catalog, cache, banksync, history, daily, discordsync, renamer, status, immich, inbox, llama, mr-sync, overview, dash, paperless, search, signoz, graph, timers, tq`) "will vanish from derived DNS once platforms/common/dns-local.nix is deleted"; grep `docs/todo/` for the owning row, queue it if unowned — High / S / Bug (pre-existing, noticed this session)
4. **Confirm the llama-rag freeze-#5 decommission gate has a live ai-stack row** — the eval warning says "decommission any manual llama-server process … before … 10 min idle stability"; verify the row exists and matches the module header lesson — Medium / S / Documentation (pre-existing, noticed this session)
5. ~~Attribute or claim the `.github/workflows/negative-tests.yml` working-tree diff~~ — RESOLVED during authoring: daemon commit `1216beff` (19:39) swept it; content is a comment-only edit (`+ inputpin` in the harness comment list) belonging to the parallel session's pin-audit work stream. No action — Low / S / Cleanup (closed)
6. **Probe darwin `sw/bin/sqlite3` at the next natural darwin build** (not a disk-motive standalone build) — Low / S / Quality
7. **Root-cause the transient `nix build -L` exit-2 only on recurrence** — capture full stderr to a file next time — Low / S / Bug
8. **Trash the root `result` symlink at quiescence** (pending §g.2) — Low / S / Cleanup
9. **Document "add a default binary → `platforms/common/packages/base.nix` essentialPackages" in `docs/CONTRIBUTING.md`** — this session had to rediscover the location; one sentence in the contributor docs prevents that — Low / S / Documentation
10. **Consider a `fmt-file`-style documented idiom** — `nix fmt . <path>` works today but is undiscoverable; the AGENTS.md bullet covers it, CONTRIBUTING could carry it too — Low / S / Documentation
11. **Confirm no service module relies on a `services.X.enable=false` sweep to keep sqlite reachable** — sqlite3 now sits in GLOBAL essentialPackages (the sops/age restore lesson); no action expected, one grep of confidence — Low / S / Quality
12. **Watch: does anything in the tree pin sqlite's version explicitly?** — the toplevel resolved `sqlite-3.53.3-bin` from the current lock; nothing to do unless a pin exists that would fork the binary — Low / S / Quality (self-checkable; listed only because it was not checked)

**Deliberately NOT harvested (per the self-harvest rule, recorded here):**

- **f.1 (deploy)** — covered by the EXISTING `[ready]` row `TODO_LIST.md` line 22 ("Deploy the no-heavy-builds `nix` gate removal + post-deploy verify"): any deploy carries my one-line change; a second row would double-queue one deploy event. The sqlite3 live probe (`sqlite3 --version`) folds into that row's post-deploy-verify step.
- **f.3 / f.4 (pre-existing warnings)** — not this session's follow-ups; operator forbade the ownership-research grep this session ("DO NOT RESEARCH OTHER STUFF"); queueing without the premise-check violates the queue-author spot-verify rule. First agent with a services/DNS or ai-stack dispatch should grep-and-queue.
- **f.5 (negative-tests.yml)** — resolved mid-report: swept into daemon commit `1216beff`, content verified benign (comment-only, parallel session's pin-audit stream).
- **f.7 / f.8 (transient + symlink)** — sub-dispatch-threshold noise; watch-only.
- No domain library owns `platforms/common` base packages (`docs/todo/` has storage/stability/monitoring/ai-stack/services/upstream/security/pipeline/desktop/pixel6), so even the deploy-probe refinement has no library home — the report is the record.

## g) QUESTIONS (cannot self-answer)

1. **Deploy now or at quiescence?** The sqlite3 line is committed and both toplevels eval green, but a deploy also activates the parallel session's gate-removal work (and everything else already committed). I cannot decide ship timing without knowing whether other sessions have in-flight work that must NOT ride this toplevel. (Tried: read `TODO_LIST.md` line 22, checked `git status`/recent daemon commits — cannot see uncommitted in-flight intent.)
2. **Is the repo-root `result` symlink safe to trash at quiescence?** It flipped from `lock-audit-selftest` to my evo-x2 toplevel mid-session (some concurrent build without `--no-link`). It is untracked and harmless, but I cannot tell whether any workflow (script, hook, or another live session) dereferences `./result` by habit. (Tried: `git status` — untracked; attribution of the re-pointing build is not recoverable from the symlink alone.)

---

*Point-in-time snapshot; goes stale. §f direct follow-ups dispositioned above per the AGENTS.md self-harvest rule. Awaiting instructions.*
