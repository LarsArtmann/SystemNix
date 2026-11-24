# Statix-LSP upstream-filing question — full verification status

**Session:** 2026-11-24 ~21:30–23:37 CET · agent session on `master`
**HEAD at report time:** `8e3d7dafc` (this report is the only uncommitted tree change)
**Question asked:** "statix has no LSP mode; crush's auto-LSP burns its init timeout every session (the `.crushrc` workaround comment). Do we need to file a GitHub Issue upstream?"

**Verdict: NO. Nothing to file — the upstream bug is already gone at crush v0.102.0 (verified live, not inferred).** Filing would report a fixed bug: pure maintainer noise, and a verify-before-filing Gate-2 stop.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Loaded `verify-before-filing` skill BEFORE the filing decision | Skill read in first tool batch |
| 2 | Located the workaround on both surfaces | `~/.config/crush/crushrc:74` (`--command statix --disabled true`) + project `.crushrc` (duplicate, no `--command`) |
| 3 | Verified the premise "statix has no LSP mode" live | `statix --help`: check/fix/single/explain/dump/list only — no `lsp` subcommand, no `--version` |
| 4 | Verified the workaround works | 0 statix failures in `~/.crush/logs/crush.log`, `~/.config/crush/.crush/logs/crush.log`, and all 4 rotated project logs (2026-11-03/09/13/24); only benign `LSP server defined` INFO lines |
| 5 | Confirmed `~/.local/share/crush/crush.json` has empty `lsp: {}` — the "auto entry" is not user-config; it comes from crush's built-in catalog path | python3 json read |
| 6 | Upstream hygiene (Gate 5) | `charmbracelet/crush` public, active (pushed 2026-11-24), issues enabled; zero existing statix/auto-lsp reports (open+closed searched) |
| 7 | Upstream source read (not guessed) | `internal/config/load.go` `applyLSPDefaults` only fills defaults for DECLARED LSPs; `internal/lsp/manager.go` `startServer`/`canAutoStart`: auto-start gated by `skipAutoStartCommands` blocklist (statix absent) → filetype match → `recentlyUnavailable` backoff → PATH. `"statix"` string appears nowhere in the public repo (code-search ×2 forms); the catalog itself lives in the PRIVATE `charmbracelet/powernap` repo |
| 8 | **Decisive live probe: no reproduction on v0.102.0** | Isolated session — fake `$HOME` (fresh config dir WITHOUT the statix override, WITH zai provider via the ai-meter proxy), fresh data dirs (no backoff memory), cwd with `test.nix`, auto-LSP armed by default (nil = allowed per manager.go logic), statix on PATH. Prompt forced a view of `test.nix`; the probe DB `read_files` table contains the `test.nix` row (the view really executed — no lazy-model false negative). **Zero statix attempts, zero LSP failure lines** — re-grepped again ~20s+ later to catch late-landing init-timeout burns: still 0 |
| 9 | Verdict delivered with scope caveat | Probe covers the view-triggered auto-start surface (the original 2026-09 symptom class) on v0.102.0 |
| 10 | Local residue fixed | Project `.crushrc` rationale comment refreshed (old text claimed failures "still" ongoing — stale); the `--disabled` line KEPT as inert insurance against a catalog re-introduction. Rode daemon commit `9e0f4de08` (1 file, exclusively mine) |
| 11 | Probe teardown | `trash ~/.cache/statix-probe` (whole tree, incl. `crush.db` with probe session data) |
| 12 | Byproduct discovery reported | **crush ignores `XDG_CONFIG_HOME`** — config isolation requires a `HOME` override (two failed XDG-based probe attempts prove it: probe crushrc never loaded, session fell to default huggingface pool) |

## b) PARTIALLY DONE

- **Version-bisection of the fix**: I proved "gone at v0.102.0" but never pinned WHICH release dropped statix auto-start (release-notes/changelog walk not done — the "~v0.99 era" phrasing in the refreshed comment is an estimate from the 2026-09-11 failure date, not a bisect).
- **Methodological closure of the absence proof**: the "zero LSP lines" verdict relies on LSP init failures logging at WARN+ (true for the historical 900+ signature, same log format), but I did NOT run a positive control (a deliberately-broken LSP entry failing init in the probe env) to prove the probe log would have captured a failure had one occurred. Reasoned around it via source reading + delayed re-grep; not positively proven.

## c) NOT STARTED

- Global `~/.config/crush/crushrc:74` comment refresh — the file is a **store symlink** (read-only in-session; source of truth = the crush-config repo, deployed by home-manager). Deliberately left for owner/dispatch.
- Recording the `XDG_CONFIG_HOME`-ignored gotcha anywhere durable (belongs in crush-config repo, not SystemNix).
- Any evaluation of the XDG finding as its OWN potential upstream issue (crush not honoring the XDG basedir spec is a plausible separate bug — unverified).

## d) TOTALLY FUCKED UP (honest ledger)

1. **`rm -rf` on the probe path** — violated the NEVER-rm rule reflexively (should be `trash`). Zero damage (path created seconds earlier by me, nothing pre-existing), self-caught one turn later and stated in-band; the final teardown used `trash`. The rule is absolute; "fresh path" is not an exemption.
2. **`env` guard trip aborted a whole typed line** — put `env | grep -c ZAI` at the end of a chained command; v0.101+ yolo aborts the ENTIRE script on a blocked name, so the earlier python output in that same call was swallowed too. This exact trap is documented in AGENTS.md ("probe guarded names one per call") and I still tripped it.
3. **Two blind probe iterations before checking the load path**: attempt 1 failed (defaulted to dead huggingface pool). The log already showed `provider:huggingface` — "probe crushrc never loaded" was the top hypothesis at that point (the rc pinned `model large`). Instead I first went down the "zai not declared" path (providers.json archaeology) and only re-ran with the provider line added — attempt 2 failed identically. Only then tested whether `XDG_CONFIG_HOME` is honored at all (it isn't). Cost: 1 wasted probe run + ~4 tool calls. Lesson: when a config pin demonstrably has no effect, verify the config LOAD path before adjusting config CONTENT.
4. **Unverified decode pipelines**: two `contents API → base64 -d` fetches (`lsp_defaults.go` 404; `lsp_events.go`/`lsp_helpers.go` pair) produced empty/absent `/tmp` files and I grep'd them as if valid ("no match" could have been "no file"). Conclusion survived via the independent code-search API, but the sloppiness is the same class AGENTS.md already bans (validate one known value through the pipeline).
5. **`strings` dead-end**: two binary-string greps that couldn't even find `charmbracelet` (extraction evidently broken on this Go binary) — I kept pulling before conceding and going empirical. The fake-HOME test was always the decisive instrument.

## e) WHAT WE SHOULD IMPROVE

- **Positive controls for absence claims**: "zero LSP lines" is an absence claim built on format inference. A 30-second positive control (bogus LSP entry → confirm the failure line lands in the probe log) would have made it airtight. This is the existing "absence claims need exhaustive captures + a known-value check" rule applied one level up — I applied it to the delayed re-grep but not to the log-capture channel itself.
- **Diagnose the harness before the payload**: when an isolated-environment experiment misbehaves, verify the isolation mechanism FIRST (was the config even loaded?), not the experiment's content. Half this session's waste was payload-tuning a harness that wasn't plugged in.
- **Guarded-name discipline is memorized but not reflexive**: the `env` trip is the second documented instance class. Rule for me: scan every typed line for the dangerous-list names BEFORE submitting, not after the abort.
- **`rm` muscle memory**: type `trash` by default; `rm` should feel like `git checkout`.

## f) NEXT (session-scoped; nothing here is SystemNix-domain — see harvest note)

1. **[crush-config repo]** Refresh the global `crushrc` statix comment (same rewrite as the project one; store-symlinked, edit at source). Optional: drop the `--disabled` line entirely if the owner prefers cleanliness over insurance.
2. **[crush-config repo]** Record the gotcha: crush ignores `XDG_CONFIG_HOME`; config isolation = `HOME` override (evidence: this session's two failed XDG probes). Candidate for its AGENTS.md or lessons file.
3. **[upstream, optional]** Verify + potentially file the XDG basedir non-compliance as its OWN issue (check docs first — may be deliberate; needs its own verify-before-filing pass).
4. **[upstream, optional]** Pin the release that dropped statix auto-start (release-notes walk) — turns the comment's "~v0.99 era" estimate into a fact.
5. **[optional rigor]** One more probe run with a deliberately-broken LSP entry as positive control, closing the log-capture gap in the absence proof.
6. **[hygiene, me]** Pre-submit scan for dangerous-list command names in every typed bash line (§d-2 recurrence prevention).

**Self-harvest note (TODO-system rule):** items 1–5 are crush-config-repo / upstream work, deliberately NOT harvested into SystemNix `TODO_LIST.md` (foreign repos — the queue is SystemNix-scoped; harvesting them here would mis-route them). Item 6 is a self-discipline note, not a queueable ask. No SystemNix-domain follow-up exists: the only SystemNix-side item (project `.crushrc` comment) is done and committed (`9e0f4de08`).

## g) QUESTIONS FOR THE OWNER (cannot be resolved from here)

1. **crush-config repo edits**: want me to apply §f-1 and §f-2 directly in `~/projects/crush-config` (and if so, commit there), or do you handle your global-config repo yourself?
2. **XDG non-compliance**: worth spending a session on the verify-and-maybe-file pass for `XDG_CONFIG_HOME` being ignored (§f-3), or is crush's HOME-based resolution acceptable as-is?
3. **Insurance vs cleanliness**: keep the inert `lsp add statix --disabled true` lines (both surfaces) as protection against a powernap-catalog re-introduction, or delete now that auto-start is proven gone?

---

*Report scope: this session only. No unrelated research performed. Parallel-session note: daemon commit `8e3d7dafc` swept another session's four files (TODO_LIST, two status reports, desktop.md) between my `.crushrc` commit (`9e0f4de08`) and this report — flagged per shared-tree discipline, contents reviewed via `git show --stat`, no interference with my work.*
