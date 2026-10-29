# Status Report — crush v0.99.0 adoption: NUR float staged, PostToolUse hooks landed, deploy blocked on upstream vendorHash roots

**Session window:** 2026-10-29 ~17:45 – 18:30 CET
**Author:** Crush agent session (trigger: charmbracelet/crush v0.99.0 release notes + "what can we improve")
**Final state at writing:** SystemNix @ float pair committed (nur 23e5769, flake check green, doc-counts re-stamped 251); crush-config master @ `822f897`+`fcf4516` (3 hook improvements, full check suite green); evo-x2 still on crush 0.98.2 — deploy BLOCKED, see §3.

---

## 1. What v0.99.0 gives this estate (research summary)

- **Catwalk v3** provider types (`completions`/`responses`/`messages`); legacy `openai`/`openai-compat`/`anthropic` config + `--can-reason` model flag auto-migrate (verified in 0.99.0 source `internal/shellconfig/model.go:105` — legacy flag translated, no crushrc change forced).
- **Hooks everywhere**: PostToolUse (updated_output/context/feedback), PostToolUseFailure (context), permission/session/turn/compaction lifecycle events; event names validated at load. Full contract: `docs/hooks/README.md` at the tag. **Scope note:** `context` works ONLY on tool events — PostCompact/SessionStart are observe-only, so context-injection ideas on those events are dead per contract.
- **`fix(tools): stop tool failures from ending the agent turn` (#4143)** — the highest-value fix here: the tq-agent-pool and crush-debug headless runs currently lose whole turns to single tool failures.
- **llama.cpp double-`/v1` model-fetch fix (#4137)** — the crushrc llamacpp provider (`--base-url …/v1`) had discovery hitting the wrong URL on ≤0.98.2.
- Server: SIGHUP reload, graceful shutdown, host theming/context, `CRUSH_PERMISSIONS_PIPED=1` — enablers for a future persistent-`crush serve` pool architecture (roadmap, not today).

## 2. Executed

### 2.1 SystemNix — nur float staged (crush 0.99.0)

- `nix flake update nur` → 23e5769 (NUR master carries crush **0.99.0** via charmbracelet/nur fb3e3d33). Lock+registry pair committed (daemon swept mid-proof; re-applied registry row after float-register's revert — the daemon-race dance, no damage).
- **Proof status:** float-register's toplevel proof RED on PRE-EXISTING roots, none touching nur: `kith-crm@c3ed35c2` + `cv@fc0506b` go-modules vendorHash mismatches (both constants across proof runs; `journal@50b4941` was a transient proxy flake — builds green standalone, rc=0). The owner's own 12:09 proof was RED earlier at eval (media-atlas.nix `cfg.group` — since fixed by owner). The crush 0.99.0 package itself builds standalone: `nix build .#nixosConfigurations.evo-x2.pkgs.nur.repos.charmbracelet.crush` → `qzsgp0f9…-crush-0.99.0`, `--version` verified, sandbox HOME (no config mutation).
- Sandbox-verified against the 0.99.0 binary + source: `hook add PostToolUse/PostToolUseFailure` are valid crushrc builtins (events map `internal/hooks/events.go`), matcher allowed on tool events only.
- `nix flake check --no-build` GREEN after fixing a pre-existing doc-counts failure (README stamped 250, eval truth 251 — the parallel session's `nsfw-classifier-provider` endpoint; re-stamped with history note).

### 2.2 crush-config — three hook-layer improvements (master `822f897` + `fcf4516`)

1. **`hooks/redact-argv-output.sh` (PostToolUse, matcher `^bash$`)** — platform-enforces the 2026-10-22/23 argv-secrets rule: pgrep/ps/ss tool output redacted via `updated_output` BEFORE the model sees it. Conservative SystemNix redact-argv sed pair ported in; self-muting on non-probe commands/clean output; defensive `unset DIRENV_DIFF` (hooks inherit crush's env; jq stdin-forms only).
2. **`hooks/bash-trap-remediation.sh` (PostToolUseFailure, matcher `^bash$`)** — failed bash calls matching documented host-trap signatures (direnv jq arg-parse break, mvdan/sh kill builtin incl. `kill -0`, journalctl `-b` short boot id) get the known fix injected as context. Silent on unrelated failures.
3. **`hooks/rg-replace-guard.sh` FP fix** — replace-flag detection now window-scoped to the rg invocation's own argument segment (stops at `;|&`), so other commands' r-bearing short flags (`jq -r`, `grep -r`, `sort -r`) no longer false-deny. Live FP this session: `rg -n …; jq -r …` blocked. Quote-boundary widening also closed a pre-existing blind spot (`bash -c 'rg -rn x'` previously escaped detection).

All pinned by new `scripts/test-{rg-replace-guard,redact-argv-output,bash-trap-remediation}.sh` fixture matrices (24 assertions) wired into a new `hook-fixtures` check + extended `scripts-verify` (hooks/ existence + bash -n) + render assertions in `module-render-defaults` (presence with name/timeout + removal when options false: `redactArgvHook`/`trapRemediationHook`, both default true). Full `nix flake check` green; treefmt clean.

**Not migrated (deliberate):** `--can-reason`→`--thinking` and explicit Catwalk `--type` forms — legacy forms verified still accepted; the glm-5.3-flash declaration is regression-sensitive (2026-08-31 class), so it stays on the proven form until a live post-deploy parity check justifies the churn.

## 3. Blocked — the finish line

Deploy of the nur float (+ the crush-config float to follow, one generation carries both) is blocked by upstream roots OUTSIDE this session's blast radius:

- `kith-crm@c3ed35c2` go-modules vendorHash mismatch (specified `sha256-XDRvpM8/…`, got `sha256-LpMsryrv…`) — the pinned rev is not even present in the local clone; in-flight from another machine.
- `cv@fc0506b` go-modules vendorHash mismatch (specified `sha256-autqYve…`, got `sha256-fyOA12V…`) — same shape; local clone HEAD (34b219f22, 10-28) does not contain fc0506b.

Fix belongs upstream-first (vendorHash bumps in those repos, then re-float + float-register proof). Queue row: docs/todo/pipeline.md (`[blocked:deploy]`).

## 4. Post-deploy verification checklist (when the roots clear)

1. `crush --version` → 0.99.0; anchor check per deploy discipline.
2. Provider/model parity: zai/gemini/synthetic/minimax(disabled)/llamacpp present; **glm-5.3-flash still listed with xhigh effort** (the 2026-08-31 regression class — assert WHICH entity serves it).
3. llamacpp discovery with a live llama-server on 8899 (the double-/v1 fix may make discovery work for the first time).
4. Both new hooks fire: a `pgrep -af` bash call must come back REDACTED; a failed `jq --version` must return the DIRENV_DIFF context.
5. crush-daily still parses the sessions DB (Catwalk v3 storage migration risk — verify before its next run).

## 5. Follow-ups harvested

- docs/todo/pipeline.md `[blocked:deploy]`: finish-line row (float crush-config + deploy + §4 checklist) — done at authoring time.
- Roadmap (not filed): persistent `crush serve` tq-agent-pool architecture (SIGHUP reload + graceful shutdown now make it viable); `CRUSH_PERMISSIONS_PIPED=1` for a crush-debug host UI.
- Upstream idea worth filing later: PostCompact/SessionStart are observe-only — context injection on compaction events would materially help long sessions (the 3h twin-executor class); blocked by contract, not by us.
