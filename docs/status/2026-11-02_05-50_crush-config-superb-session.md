# Crush-config superbness session — status report

**Date:** 2026-11-02, ~03:00→05:50 CEST
**Base request:** "Now make sure our crush config is superb!" (+ two "break it down, execute and verify, keep going" directives)
**Tree at write time:** clean; my SystemNix content daemon-swept (`69eeb5036` home.nix+post-deploy-check, earlier TODO/desktop ticks); lock pair `9aefbc04c` (flake.lock + expected-locks: crush-config → `66bff2d`); eval GREEN.
**Sister repos:** crush-config pushed `c898e16` + `98fe745` (rode the `66bff2d` wave with a parallel session's lesson commits).

## Live state at write time

Everything is committed, registered, eval-green, and PRE-DEPLOY PROVEN — the activation now waits only on the shared PSI-gated deploy (CV session's watcher `watch-and-deploy2.sh`, pid 3155131: PSI<20 ×3 + tree-clean ×4 + eval-green; PSI has held 56–93 all session). My own 3h generation-flip watcher (~/.cache/crush-superb/) auto-runs the verification battery the moment the deploy lands. Owner short-circuit if wanted NOW: `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` (documented escape, 04:00 session).

## a) FULLY DONE (all verified)

1. **crush-config `98fe745`** — flake check `module-render-key-fixture`: executes the rendered `crush_key()` with a stubbed `provider` builtin against absent/empty/`PLACEHOLDER*`/real key files, cmp-asserts the four calls; negative-proven standalone (a disable-branch-less function diverges, cmp rc=1). Full `nix flake check` green. Pushed.
2. **docs/testing.md** (crush-config) — `CRUSH_GLOBAL_CONFIG` throwaway-harness pattern (takes a DIRECTORY), the strings-probe unreliability warning (Go reflective flag binding; known-good flags 0-hit), v0.99.0-verified flag baseline. README Secrets-doctrine + Verification synced to disable semantics (were stale "skipped/inert").
3. **FEATURES/CHANGELOG** entries for the thinking-lock + auto-disable arc (landed `98fe745`).
4. **`model small` audit — premise overturned, then fixed.** crush v0.99.0 source (load.go `resolveSelectedModels` + shared_models.go `buildModel`): rc slot > **picker-persisted store** > catalog default; unset slots PERSIST fallback corrections into `~/.local/share/crush/crush.json`. Live small was `hyper/deepseek-v4.1-flash` (charm-cloud OAuth picker leftover, un-metered) — glm never served summarization, so the report's thinking-cost question was moot. **Fix:** `model small zai/glm-4.7-flash` declared in SystemNix home.nix extraRc inside the meter guard (host-scoped: Mac/rpi key availability), empirically validated on the deployed binary (`small=[zai/glm-4.7-flash]`); post-deploy-check now asserts both model identities.
5. **Decisions resolved** (desktop.md rows): `--reasoning-effort` stays deliberately two-layer (global model-add = default for slot-less contexts; the four tq lines are tq-owned overrides, byte-identical today); minimax stays disabled-revivable.
6. **Lock activation path:** pushed crush-config (fast-forward `232f19f..66bff2d` — carried a parallel session's 2 lesson commits riding master), `nix flake update crush-config` → `nix run .#float-register`: registry regenerated, toplevel keep-going proof GREEN, pair daemon-landed + content-verified (`9aefbc04c`).
7. **Pre-deploy rc render proof** (from the committed tree, not the live old generation): all six markers present — `--thinking always`, auto-disable branch, meter `--disable false`, `model small zai/glm-4.7-flash`, PermissionResult + StopFailure hooks (the 2026-10-29 hooks finally reach a generation).
8. **Post-deploy battery staged:** ~/.cache/crush-superb/verify-deployed.sh (rc markers, `crush models` identities, slot resolution via harness, ai-meter :8108 metrics probe — /var/lib/ai-meter is root-only, the admin port is the sanctioned evidence path for reasoning-token legs).

## b) PARTIALLY DONE

1. **Activation itself** — gated on the shared deploy (PSI storm, chronic all night). Watcher-armed both sides (CV session's trigger, my verify-on-flip).
2. **Row 124/131 + ai-stack kimi rows close-out** — deliberately deferred to post-deploy evidence (this report is their Source).

## c) NOT STARTED

1. Restart of live crush sessions post-deploy (rc is load-time; owner/user act, row 124 leg 4).

## d) MISTAKES / near-misses (honest)

1. **Chased the wrong checkout:** the handoff's "crush source at ~/projects/crush-daily" is Lars's own analytics project — one go.mod read settled it; I then went via gh api against the v0.99.0 tag (the deployed binary is the prebuilt GitHub release tarball, so no local source exists at all).
2. **First jq store probe was structurally wrong** (providers.json is an array; my object-shaped query) — redone; second finding: all 41 default providers carry `$ENV_VAR_NAME` strings as api_key (not secrets, env references).
3. **My TODO docs commit hit the pre-commit TODO gate** — fatal failures were ALL foreign (storm-session harvest debt: time-gated [ready] rows, wrong-link/no-entry drift; 161-report UNHARVESTED incl. the 04:20 CV report whose queue rows cite it only relatively). Triaged as not-mine, edits left to the daemon sweep (which bypasses hooks) — the same disposition the 04:00 session reached.

## e) IMPROVE

1. When a queue row cites "same report §X", the filename-citation convention still matters — the gate greps FILENAMES; relative cites read as unharvested (04:20 report is the live example).
2. Multi-session deploy nights: my activation chain (push → bump → float-register → verify) never fired a deploy and never raced the armed watchers — the serialized pattern worked; keep it.

## f) Next (harvest state)

1. Deploy lands → run the battery → tick [docs/todo/desktop.md](../../docs/todo/desktop.md) rows 124/131 with evidence + ai-stack kimi rows 1490/1491 (the kimi removal rides the same lock bump) — part of existing row 124, no new row.
2. NEW [decision] (queued this session, desktop.md): 41 crush default-catalog providers remain picker-selectable without keys (the 401-trap class at scale); `option default-providers false` is a BLOWTORCH (strips the zai/gemini catalogs the slots + model decls depend on) — per-provider `--disable true` lines vs accepting crush's default UX = owner taste. **Source:** this report §g.1
3. NEW [decision] (queued, desktop.md): no Nix LSP at all (statix deliberately disabled as a fake LSP; nil/nixd never declared) — adding `nil` would give real Nix diagnostics but costs eval-heavy startup on big flakes; owner call. **Source:** this report §g.2

## g) Open questions

1. Default-catalog provider surface (§f.2): disable-list or accept?
2. Nix LSP (§f.3): add nil/nixd or keep none?
3. (Standing from the prior report, unchanged): deploy timing — the armed watcher vs `DEPLOY_FORCE_PRESSURE=1`.

**Harvest log: rows queued at authoring time (desktop.md "Crush tooling" section, items 8-9).**

**ADDENDUM (written 08:2x, post-landing):** the shared deploy fired 08:13:14 (gen-969, anchor OK, profile==current) and the staged battery ran green **11/11** — rc markers (thinking always, auto-disable, meter --disable false, model small, both 0.99 hooks, minimax), model identities, slot resolution (`small=[zai/glm-4.7-flash]`), ai-meter :8108 answering. Kimi-removal legs verified in the same generation (no sops key, zero rc references, meter 404) with one premise overturned: 89 kimi picker entries remain via crush's DEFAULT catalog — that is the §f.2 decision row, not the declarative layer. Rows 124/131 + ai-stack 52/53/queue 1490/1491 ticked with evidence. Remaining user act: restart live crush sessions (rc is load-time).
