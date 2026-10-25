# InboxClean rev-pin lift via floating nixpkgs-unstable follow

**Date:** 2026-10-25 ~13:20–14:1x UTC+1 · **Instance:** Crush (glm-5.3-flash) · **HEAD at start:** `56f108149` (later `c50ba89c7`; core surfaces landed in daemon batch `d2759f5cd`)

**Owner directive (verbatim):** "inboxclean should never be pinned" — quoted on top of the pin-audit row the 2026-10-25 exec-3 lock-float session landed (~12:55).

## a. The problem

- exec-3 pinned `inboxclean` at `b6f15e71` because upstream `c63bf289` (master HEAD, daemon auto-commit 08:43Z today) raised go.mod to `go 1.27.3` while the REV-PINNED root nixpkgs (`fe13242`) ships `go_1_27` **1.27.2**, and buildGoModule sets GOTOOLCHAIN=local → the FOD dies `go.mod requires go >= 1.27.3 (running go 1.27.2)`.
- The audit row's LIFT condition — root nixpkgs ships go ≥ 1.27.3, or the nixpkgs pin lifts — was **unmet live**: eval of the pinned instance gave `go = 1.26.8`, `go_1_27 = 1.27.2`, and **no `go_1_28` attr exists** in the pinned nixpkgs.
- The consumer surface has no root-side override hook: `inputs.inboxclean.packages.default` is a closed upstream buildGoModule; the audit note's "no local overlay can close the gap" holds (consumer flakes import their nixpkgs overlay-less).

## b. What was considered and rejected

1. **Lift the nixpkgs rev-pin** (the audit row's parenthetical path): its own LIFT gate (green toplevel with aw-core + linux-7.3-modules on the float) plus the five-breakage 02c087f3 rollback history — a fleet-wide operation, out of scope for this directive. Not attempted.
2. **Un-follow inboxclean's nixpkgs** (the journal.nixpkgs deliberate-table pattern): would have worked TODAY by luck — upstream InboxClean's own flake.lock resolves nixpkgs to `3ec63636`, which ships go_1_27 1.27.3 — but at the mercy of upstream's lock-freshness schedule with zero local control and no local float lever. The dedicated follow is strictly better: we own the freshness (`nix flake lock --update-input nixpkgs-unstable`), the weekly flake-update floats it, and the drop condition is documented.
3. **Upstream goTarball fix** (browser-history/PMA pattern): correct long-term but requires upstream flake surgery (go-nix-helpers input adoption; upstream's flake hand-wires `goPkg = unfreePkgs.go_1_27`), plus a vendorHash re-hash cycle. Deferred as unnecessary once the follow gave a green build today.

## c. The fix (four surfaces + lock, all in daemon batch `d2759f5cd`)

1. **flake.nix**: new FLOATING input `nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"` (bare branch — pin-audit explicitly allows branch refs, no allowlist row needed; `nixpkgs-llama-rag` precedent for a second nixpkgs instance). `inboxclean.inputs.nixpkgs.follows = "nixpkgs-unstable"` (follow-path form → no lock-audit deliberate entry needed — the audit only flags own-node locks). InboxClean URL reverted to the pre-pin form `github:LarsArtmann/InboxClean?ref=refs/heads/master`.
2. **lib/flake-input-pin-audit.nix**: `inboxclean` allowlist row removed (no stale-row violation); header comment rewritten hermes-only + records the lift mechanism.
3. **flake.lock**: `nix flake lock --update-input inboxclean` → inboxclean floats to master HEAD `c63bf289`; `nixpkgs-unstable` node added at `3ec63636` (nixos-unstable tip, 2026-10-23) — **which ships go_1_27 1.27.3** (verified by eval of the locked rev).
4. **flake/expected-locks.nix**: regenerated per the file's documented float procedure (jq body-splice; header preserved): `inboxclean → c63bf289…`, `+ nixpkgs-unstable → 3ec63636…`, seed-count note updated. First splice attempt duplicated two body rows (head -25 vs the `{` living on line 23) — caught by diff, rebuilt from `git show HEAD:`.

**The alignment property that makes this safe without a hash chase:** upstream's OWN flake.lock nixpkgs node is the SAME `3ec63636` our follow resolved to — upstream's committed vendorHash was validated under exactly this nixpkgs/toolchain context. The FOD confirmed it (§e.1).

## d. Verification evidence

- **e.1 Scoped FOD proof:** `nix build --no-link github:LarsArtmann/InboxClean/c63bf289…#packages.x86_64-linux.default` → **rc=0**, store path `/nix/store/a0aghv75zhgq516a52827y34axxig08g-inboxclean-c63bf28` (rev-named). Upstream's committed vendorHash held — no hash paste needed anywhere.
- **e.2 Pin-audit trace:** eval now lists hermes-agent/nixpkgs/llama-rag/paperless-gpt/qmd/signoz pins; **inboxclean absent**; no stale-allowlist throw; rc=0.
- **e.3 Full eval gate:** `nix flake check --no-build` → **rc=0**, zero error lines (only the pre-existing stalwart/zfs/stray-unit/catalog advisories), with the parallel session's committed selftests.nix in-tree.
- **e.4 Toplevel proof:** `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link` → §e.4 result recorded below.
- **e.5 Graph spot-checks:** lock `inboxclean.nixpkgs → ["nixpkgs-unstable"]` (follow path), root nixpkgs still `nixpkgs_5 → fe13242` (pin untouched); `nixpkgs-unstable` needs ≥ 1.27.3 — 1.27.3 exact.

## e.4 toplevel result

- **rc=0** (`~/.cache/lockfloat/inboxclean-lift-toplevel-proof.log`): toplevel `nixos-system-evo-x2-26.11.20261015.fe13242.drv` (root pin intact in the name) built through `activate.drv` with `--keep-going`; the log carries 6 inboxclean references, all realized — `inboxclean-c63bf28_fish-completions.drv`, `unit-inboxclean-web.service.drv`, `unit-inboxclean-sync.service.drv` (the main package store path `a0aghv75zhgq…inboxclean-c63bf28` was cache-hit from the §e.1 scoped build). Zero errors in-log. Run under a sustained io storm (some avg60 ~58%) — build verdicts unaffected, only slower.

## f. Follow-ups

- **[watch] Collapse `nixpkgs-unstable` back to the root follow** when the `fe13242` pin lifts and ships go ≥ 1.27.3 — one root nixpkgs instance is the goal; drop condition lives in the flake.nix comment. Harvested to TODO_LIST + docs/todo/pipeline.md.
- **[ready] hermes-agent same-pattern lift candidate** — point `hermes-agent.inputs.nixpkgs` at `nixpkgs-unstable` (unstable patchelf carries #672 → the patchelfFixed patch should apply), verify the hermes-python-source IFD + pm-ripgrep/pm-node builds, then drop the pin + allowlist row. Harvested with the wholesale-instance caveat baked in.
- **[note] The new input has NO daily nixpkgs-compat coverage** (that workflow `--override-input`s the root pin only) — the inboxclean go-modules FOD is its only compatibility test. Recorded in flake.nix + CHANGELOG; a compat-workflow extension is an owner decision, not queued.
- **[note] Upstream master remains nix-broken for ITS OWN rev-pin followers** only in the sense that its go.mod floor (1.27.3) now requires a ≥ 1.27.3 context — its own lock already satisfies it (3ec63636), so no upstream action needed. Its `goPkg = unfreePkgs.go_1_27` comment ("drop the override when nixpkgs' default go >= 1.27.1") is upstream's to maintain.
- **[note] Daemon raced my four core surfaces into `d2759f5cd` (heuristic message)** — verified contents = exactly flake.lock + flake.nix + expected-locks.nix + pin-audit.nix; lock+registry landed TOGETHER as the float procedure demands. HEAD had moved on top (parallel session active all session — memory-emergency-guard io-gate work in `9576bc435`/`15d8849ea`), so no amend-forward; the narrative lives here + CHANGELOG.

*Session evidence: scoped FOD build rc=0 (`/tmp/ic-fod.log`, store path above); flake check log `/tmp/flakecheck.log` (rc=0); toplevel proof log `~/.cache/lockfloat/inboxclean-lift-toplevel-proof.log`; lock diff = {inboxclean→c63bf289, +nixpkgs-unstable→3ec63636}.*
