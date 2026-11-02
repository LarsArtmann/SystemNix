# Status: GLM-5.3-Flash always-thinking + provider auto-disable (crush tooling session)

**Session:** 2026-11-02, ~01:30–02:30 · **Repos:** SystemNix + `~/projects/crush-config` (private) · **Scope:** user asks — (1) "GLM-5.3-Flash should always enable Thinking", (2) "How does this work with the model router? Should we disable providers I do not have?"

**Parallel-session note:** storm-night2 diagnosis sessions were active the whole time (status reports at 01:58 + 02:13 by another instance). My SystemNix `home.nix` edit rode one of their daemon batch commits; content verified intact via `git log --stat`.

---

## a) FULLY DONE

1. **`--thinking always` pinned on glm-5.3-flash** — `crush-config/modules/home-manager/crush.nix:190` (`model add zai/glm-5.3-flash … --thinking always …`). Model-level property: every slot routing to it sends thinking; picker cannot toggle it off. Flag surface **empirically verified** against the deployed crush v0.99.0 binary (see §d for the verification arc).
2. **Router semantics explained + documented** — model-catalog flags (`model add`) vs slot overrides (`model large`/`small`), merge order (project crushrc over global, later statements win), reasoning-effort at both levels (slot wins), ai-meter proxy transparent to thinking/effort payload fields.
3. **Provider auto-disable mechanism** — `crush_key()` in crush.nix now emits `provider add X --disable true` when the key file is absent/empty/`PLACEHOLDER*`; unprovisioned providers vanish from the picker instead of being selectable-then-401. Live inventory taken first: all 4 key files present (gemini/minimax/synthetic/zai), ai-meter key present, minimax statically disabled (billing, 2026-08-31), llamacpp keyless-by-design (untouched — no `apiKeyFile`, `crush_key` never called for it).
4. **ai-meter re-enable guard** — `platforms/nixos/users/home.nix` meter block now passes `--disable false` (meter key = independent auth path; a meter host may lack raw key files). **A/B verified on the deployed binary:** disable-true → 0 models listed; later disable-false → 1 (restored).
5. **Render tests extended** — two new assertions in crush-config `flake.nix` (auto-disable branch present; `--thinking always` present). Both `nix flake check --no-build` runs green (crush-config AND SystemNix full eval).
6. **Commit hygiene** — the two daemon-swept heuristic commits in crush-config (7fb7e92 + 3256f68, both verified mine via `git show --stat`) were amend-forwarded into one properly-messaged commit **c898e16** (`git reset --soft HEAD~2` is the allowed mode; tree preserved; pre-commit hooks passed). crush-config `master ahead 1`, unpushed.

## b) PARTIALLY DONE

1. **Deployment** — everything is committed + eval-green but **NOT activated**: live `~/.config/crush/crushrc` is still the old generation's symlink (no `--thinking`, old `crush_key` body). Needs `nix run .#deploy` (or hm switch) + restart of every running crush session (rc is load-time only).
2. **End-to-end thinking proof** — flag parses and loads cleanly, but "thinking tokens actually sent on every request" (visible as reasoning tokens in `/var/lib/ai-meter/usage.jsonl`) is unproven until activation. Queued as post-deploy legs.

## c) NOT STARTED

1. crush-config FEATURES.md / CHANGELOG.md entries for the new behavior (repo has both; I only touched module + flake).
2. Functional fixture test of `crush_key()` (stubbed `provider` builtin, branch coverage: absent/empty/PLACEHOLDER/valid).
3. `model small` slot audit — what summarization resolves to; whether it also hits glm-5.3-flash WITH thinking (token cost on every summarize call).
4. minimax disposition (dead token plan: keep-disabled vs drop from defaults).
5. Darwin-host crush story (does it consume crush-config? key provisioning shape there?).

## d) TOTALLY FUCKED UP (nothing shipped broken; the honest near-misses)

1. **I asserted `--disable false` semantics BEFORE verifying them.** My router answer claimed "later statements win" from the skill doc alone; the A/B test that proved it came 10 minutes LATER, unprompted by the user. The claim was true — but the answer preceded the evidence, which is exactly the "a 'verified' label must cover every fact asserted" violation this repo documents. Recovered in-session; final state verified.
2. **Trusted the skill doc for `--thinking` flag existence against a binary I never checked.** The crush-config repo's own comment (crush.nix:184-189) documents the house discipline — flag surface verified against crush SOURCE — and I skipped it. Detour to close it: strings-probe on the binary showed 0 hits for "thinking" → alarm → control probe showed 0 hits for known-good `can-reason` too → probe useless (Go reflective flag binding constructs kebab names at runtime; static analysis can never decide) → built the definitive empirical harness (below). ~15 minutes that one `CRUSH_GLOBAL_CONFIG` smoke test up front would have replaced.
3. **Hit the `rg -rn` trap myself** — typed `rg -rn . -l --type go -e 'can-reason'`, blocked by this host's rg-replace guard (the exact third-strike class). Corrected to `rg -n` immediately; zero damage; the guard works.
4. **Cross-repo daemon race rode along silently** — my SystemNix home.nix edit landed inside a parallel session's batch commit; I only noticed when `git status` came back empty mid-session. Content verified intact after the fact, but per the shared-tree rule the flag-to-user should have been immediate.

## e) WHAT WE SHOULD IMPROVE (self-review)

**Forgot:** post-activation verification plan wasn't offered as concrete commands at answer time; no FEATURES/CHANGELOG bump; small-slot cost question unexamined; verification arc ran backwards (assert → verify) instead of (verify → assert).

**Could have done better:** read the repo's flag-verification precedent comment FIRST (it names the method and the file, `shellconfig/model.go`); test rc semantics empirically before explaining them — the throwaway `CRUSH_GLOBAL_CONFIG=<dir>` harness takes ~2 minutes and is reusable (queued for documentation).

**Still improve:**

1. Test depth: render-grep + `bash -n` proves syntax, not behavior. The stubbed-builtin fixture test would have caught a broken branch in my `crush_key` rewrite — I restructured the function (if/case) and shipped it with zero execution coverage.
2. **Split brain left in place:** `--reasoning-effort xhigh` now lives in TWO homes (global `model add` in crush-config + project `.crushrc` tq-managed `model large` line). Pre-existing, same value today, but my explanation cemented it instead of flagging it. Decision queued.
3. The `CRUSH_GLOBAL_CONFIG` harness + the reflective-flag-binding dead-end deserve a doc page — the next session would otherwise re-walk my 4-probe detour (queued).

## f) NEXT (session-scoped; harvested per TODO-system rules — queue lines in TODO_LIST.md, full rows in docs/todo/desktop.md "Crush tooling")

1. [blocked:deploy] Activate the generation; post-deploy verify: rc contains both changes, picker locks thinking, ai-meter usage.jsonl shows reasoning tokens, sessions restarted.
2. [ready] Update crush-config FEATURES.md + CHANGELOG.md (c898e16).
3. [ready] Functional fixture test for `crush_key()` auto-disable branches (stubbed `provider` builtin).
4. [ready] Document the `CRUSH_GLOBAL_CONFIG` throwaway-harness verification pattern + strings-probe unreliability in crush-config docs.
5. [ready] Audit `model small` resolution + always-thinking cost on summarization calls.
6. [decision] Single-home `--reasoning-effort` (kill the global/slot split brain).
7. [decision] minimax: keep disabled entry or drop from provider defaults.
8. [watch] Next deploy must re-run the quiescence protocol (storm-night sessions were live; deploy-vs-executor race doctrine).
9. [ready post-deploy] Confirm ai-meter passes reasoning params opaquely (field-level check in usage.jsonl).
10. [ready] Run crush-config's own `commands/quality-check` (I only ran flake check).
11. [watch] Consider exposing `thinking` as a structured `programs.crush-config` model option instead of a raw rc line (mechanism consistency).
12. [watch] tq-managed `.crushrc` block regeneration — confirm it never clobbers the `model large` line the thinking story depends on.
13. [ready] Verify darwin's crush/consume story for crush-config (behavioral change ships to every consumer host).
14. [watch] Sweep skill-doc flag claims vs deployed binary surface once (reasoning-effort levels list) — same class as the `--thinking` assumption.

## g) QUESTIONS (cannot figure out myself)

1. **Deploy timing:** activate now (`nix run .#deploy`) or wait for the storm-night session to wind down? The deploy-vs-executor race doctrine applies — a parallel session was editing the tree minutes ago.
2. **If `model small` resolves to glm-5.3-flash:** do you WANT thinking on summarization calls (thinking tokens per summarize, ~2-4× output cost on those calls), or should thinking apply to the large slot only? (Determining small's resolution + the preference are two different things — the preference is yours.)
3. **minimax:** keep the disabled entry (valid key, token plan exhausted 2026-08-31, revival-ready) or drop it from the personal provider set entirely?

---

**Deliberately not harvested** (ROADMAP/discussion fuel): structured-options refactor of crush-config model flags (f.11), flag-surface sweep of the crush-config skill doc (f.14).
