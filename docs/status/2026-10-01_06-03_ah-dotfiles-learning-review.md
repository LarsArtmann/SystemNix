# Status Report — a-h/dotfiles Learning Review

**Date:** 2026-10-01 06:03 CEST
**Session scope:** Single-question research session: analyzed https://github.com/a-h/dotfiles (Adrian Hesketh's flake) and extracted transferable ideas for SystemNix. No code was changed in this repo.
**Format note:** Canonical status-report format is a styled HTML dashboard; the user explicitly requested `.md`, so this report is Markdown (one-off override, not a spec change).

---

## a) FULLY DONE

1. **Full analysis of a-h/dotfiles** — README, complete file tree (41 files), `flake.nix` (read in full), and `neovim/default.nix` (read in full). Evidence: fetched via `gh repo view` + `gh api contents` in this session.
2. **Delivered a transferable-ideas verdict** with per-item relevance to SystemNix:
   - Self-contained neovim as flake package (`wrapNeovimUnstable` + baked LSP servers via `symlinkJoin`/`wrapProgram`) — the repo's best trick.
   - `xc` markdown-embedded task runner as a complement to flake apps (no justfile needed).
   - `unstableGoFor` pattern: nixpkgs-unstable imported for ONE package (Go/gopls) while system stays on stable 26.05.
   - `getPkgsForSystem system extraConfig` — per-machine nixpkgs config injection (desktop opts into CUDA/ROCm without polluting others).
   - Exceptional in-place pin rationale comments (naersk/tuicr 403 User-Agent regression, revision-pinned "so it cannot break a build unannounced").
   - Surgical overlay fix with root-cause comment (i686 libcap `withGo = false` for Steam/pipewire).
   - Disko declarative disk layout.
3. **Honest comparison against SystemNix** — confirmed our CI/audit/deploy pipeline and secrets doctrine are far ahead of the reference repo; identified the two lowest-effort wins (neovim package, `xc`).

**No files in this repo were created or modified** (besides this report). Working tree untouched by this session.

## b) PARTIALLY DONE

1. **Idea adoption** — the analysis is complete, but zero of the seven extracted ideas have been evaluated against our actual constraints (e.g. does the self-contained neovim conflict with our Helium/editor setup? does `xc` overlap with existing flake apps?). Nothing is queued in TODO_LIST.md yet. Blocker: awaiting user's pick from the ideas list.

## c) NOT STARTED

1. **Any implementation** of the adopted ideas — nothing built, no spike of the portable-neovim package, no `xc` trial.
2. **Reading the rest of the repo's configs** — I read `flake.nix` and the neovim packaging in full, but only skimmed the tree listing for `desktop-linux/*.nix`, `.macos`, `.tmux.conf`, `.zshrc`. The disko layout, GPU/Steam config, and hardware modules may hold further ideas (user directed no unrelated research, so this was deliberately deferred).

## d) TOTALLY FUCKED UP

1. **First fetch of the GitHub URL returned only GitHub's nav chrome** (SPA page, zero repo content) — wasted one round trip; recovered immediately with `gh` CLI. Minor, but the lesson stands: GitHub HTML fetches are unreliable, default to `gh api` first.
2. **`gh api .../git/trees/main` 404** before checking the default branch — guessed `main` instead of querying `default_branch` first. Trivial, self-corrected in the next call.
Nothing in the SystemNix repo itself is broken by this session.

## e) WHAT WE SHOULD IMPROVE

1. **GitHub research entry point** — use `gh repo view` / `gh api` as the FIRST tool for GitHub repos; the `fetch` tool only works for raw-file URLs. (Small process fix, saves a wasted call every time.)
2. **Pin-rationale colocating** — a-h's best practice is putting the full WHY (upstream issue, fix date, release-gap analysis) directly in the `flake.nix` input comment next to the pin. Our gotchas-archive is excellent but separated from the pins; for flake inputs with scary pins, a one-paragraph comment AT the pin citing the archive entry would merge both worlds.
3. **Per-host nixpkgs config injection** — our host configs carry their own `nixpkgs.config` blocks; a shared `getPkgsForSystem system extraConfig` helper in `lib/` would make ROCm/CUDA/unfree opt-ins explicit and diffable per host.
4. **Portable tool packages** — we package LarsArtmann Go tools via `mkLarsPackages`, but have no "self-contained interactive tool" pattern (neovim with baked LSPs is the exemplar). A `pkgs/portable/` convention could make any machine instantly productive.

## f) Up to 50 things we should get done next

Ranked by impact. **Harvest status: deliberately NOT harvested into TODO_LIST.md at authoring time** — the user explicitly said "report, then wait for instructions"; every item below is a *proposal* derived from one reference repo and needs the user's pick before queueing (queueing all 50 against an undecided idea-set would poison the dispatch queue). Items 1–5 are the ones I would harvest immediately on approval; the rest are ROADMAP fuel.

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Build a self-contained portable neovim flake package (baked treesitter + LSP servers, `nix run .#neovim`) | High | L | Feature |
| 2 | Spike `xc` (markdown-embedded tasks) alongside flake apps for rebuild/deploy documentation-as-tasks | Medium | S | Feature |
| 3 | Add `unstableGoFor`-style single-package-unstable helper to `lib/` so gopls/tooling can track unstable Go while systems stay on stable | Medium | M | Feature |
| 4 | Extract a `getPkgsForSystem system extraConfig` helper for per-host nixpkgs config (ROCm/CUDA/unfree opt-ins) | Medium | M | Quality |
| 5 | Adopt colocated pin-rationale comments for every scary flake input pin (linking gotchas-archive entries) | Medium | M | Documentation |
| 6 | Evaluate Disko for documenting evo-x2's current partition layout declaratively (documentation artifact, not re-partitioning) | Medium | M | Documentation |
| 7 | Study a-h's `desktop-linux/hardware/*.nix` + `network.nix` for further patterns (not yet read) | Low | S | Research |
| 8 | Study a-h's `.macos` script for macOS de-cruft settings we may be missing on `Lars-MacBook-Air` | Low | S | Research |
| 9 | Audit our overlays for missing root-cause comments on override fixes (libcap-class fixes should explain WHY at the fix site) | Low | M | Quality |
| 10 | Consider a `pkgs/portable/` convention for self-contained interactive tools (editors, shells, debuggers) | Low | M | Feature |

(Items 11–50 were not fabricated as filler: the session's genuine output surfaces ~10 actionable follow-ups. Padding to 50 with invented work would violate the "queue authors spot-verify config claims" discipline. If the user wants a 50-item brainstorm, run pareto-planning against the full repo — that is a separate task.)

## g) Questions I can NOT figure out myself

1. **Which of the seven extracted ideas do you actually want adopted?** (My recommendation: #1 portable neovim + #5 pin-rationale comments. #2 `xc` only if you miss README-executable tasks.)
2. **Do you want me to also read the rest of a-h/dotfiles** (desktop-linux hardware/Steam/ghostty configs, `.macos`, tmux/zsh) for a second extraction pass, or was the flake-level review the entire intent?
3. **Should the portable-neovim package coexist with your current editor setup** (Helium on NixOS, minimal HM on Darwin), or would it replace/conflict with an existing daily driver I should not touch?

---

*Report is a point-in-time snapshot. Section (f) harvest deliberately deferred pending user instruction (reason recorded above per the self-harvest rule). No commits made (harness rule); auto-commit daemon will pick this file up.*
