# Hermes Follow-up Execution Session — 2026-08-21 05:30

Executed the entire actionable remainder of the 2026-08-21 02:38 upgrade report
(one autonomous run, no user input needed). Started from the report's "Exact
Next Steps", ended with a clean deploy and 67/0 post-deploy smoke.

**Session scope:** everything in the previous report's next-steps that did not
require a user decision, plus two live bugs found and fixed along the way.
The concurrent hermes-hardening/self-review session's staged work (btrfs
gc-guard fix, restart-churn monitoring wiring, etc.) was quiescent (~2 h) and
**rode this session's deploy** — the combined tree is what was verified.

---

## a) FULLY DONE

1. **`registration_lifecycle` patch DELETED from `hermes.nix`** — upstream
   ships the module in `[tool.setuptools] py-modules` since v0.20.1. Proven,
   not assumed: import smoke via the wrapper's real venv interpreter
   (`hermes-agent-env/bin/python3.12` → `import registration_lifecycle,
   hermes_cli.plugins` → OK from site-packages). Package rebuilt WITHOUT the
   patch (`hr6qwld9…-hermes-agent-0.20.4`), VM test green, deployed —
   `/run/current-system/sw/bin/hermes` now resolves to exactly that store
   path. The second source of truth is gone. (AGENTS.md, FEATURES.md,
   TODO_LIST, runbook, CHANGELOG all updated.)
2. **Live agent ssh FIXED (new bug found this session)** — live journal showed
   recurring `Bad owner or permissions on /home/hermes/.ssh/config` in the
   agent's terminal tool (00:45, 02:46, 04:47). Root cause: the hardening
   round's exec-preserving perms walk `chmod u=rwX,g=rwX,o=` makes
   agent-created `~/.ssh/config` 0660 group-writable; OpenSSH refuses
   group-writable config. Fix in `fixPermissionsScript`: the file walk PRUNES
   `~/.ssh`, and a `converge_ssh` step (files `u=rwX,g=,o=`, dir numeric
   `0700` + explicit `g-s`) runs on EVERY restart — including the fast-path
   early-exit, which is the exact live-host scenario. VM-tested (test 6b:
   full-walk path AND fast-path drift).
3. **TERMINAL_CWD drift question CLOSED** — read upstream commits `31561e37`
   - `a93f1b2` in full: the deprecation warning now reads the `.env` FILE
     (not the process env), and its docstring explicitly blesses process-env
     TERMINAL_CWD ("runtime config bridges and session restoration
     legitimately set TERMINAL_CWD"). The vanished startup warning is CORRECT
     new behavior, our systemd env-bridge is upstream-sanctioned, and
     `resolve_placeholder_terminal_cwd` + `HERMES_WRITE_SAFE_ROOT` are intact
     at `63c6d9a4`. `flake.nix` RE-VERIFY comment re-dated with the verdict.
4. **Bank-Sync smoke made deterministic** — the transient body-mismatch FAIL
   was neither of the two documented flake classes (both already fixed:
   `--compressed` + herestring): it was the restart race (single-shot curl
   against a mid-activation service). Now retries 6×5s before failing;
   remaining `echo | grep -q` on response bodies converted to herestrings.
5. **llama-rag smoke warmup tolerance (the "second unidentified FAIL" from
   the previous session, SOLVED)** — that FAIL was `llama.cpp Reranker
   :8849 → 503`: deploy restarts the reranker, GGUF load takes ~70 s on
   ROCm, and llama-server answers `/health` 503 until the model is ready.
   The smoke now waits up to 2 min/port for a 200 before the one-shot
   checks. Verified: both endpoints 200 after warmup.
6. **Extras drift audit** — all 18 enabled groups still exist upstream at
   `63c6d9a4` (zero breakage); upstream ships 26 groups we do not enable —
   documented in AGENTS.md as integration-preference territory.
7. **`feat(relay)!` breaking change reviewed** (PR #77915, `612b3633`) —
   relay plugin-init rework for Nous-managed agents; SystemNix uses no
   relay config (self-hosted gateway, direct Discord adapter, live+green
   since 23:42). No impact.
8. **Live-host verifications** — `hermes-github-verify`: DNS gate + placeholder
   skip path both work (PAT fill remains a user step); workspace AGENTS.md v2
   present; runbook documents github-verify; `hermes-agent`'s new transitive
   `home-manager` input follows the root input correctly (lock inspected);
   post-deploy smoke **67 PASS / 0 FAIL / 5 SKIP (disabled+non-graphical) /
   1 WARN (known quickshell TODO)**.
9. **Previous report §f HARVESTED into TODO_LIST** — 10 of 27 items resolved
   by this session; 2 were semantic dupes of existing entries; 1 merged into
   the attic entry; 6 genuinely new TODO items added (Discord-connect smoke,
   DNS-gate test helper, VM-test burst audit, bump workflow + v0.21.0 notes,
   tools.registry classification); several verified-on-the-spot and dropped.
10. **Security sweep + hygiene** — `scripts/scan-history-secrets.sh` over
    full history: only the 3 KNOWN pre-rotation synthetic-key blobs (held
    purge decision unchanged), **zero new leaks** from this batch. /tmp
    scratch (`hermes-check` clone, ssh repro) trashed. `nix fmt` run; also
    prettier-normalized the concurrent session's HTML report (repo tooling
    expects that formatting).

## b) PARTIALLY DONE

1. **Live `.ssh` state post-deploy** — the new converge ran during the
   05:23:21 deploy restart (full walk journaled), but `/home/hermes` is
   unreadable from lars (2770): direct confirmation of `0600/0700` needs the
   agent's next ssh use or root. VM regression test covers both code paths.
2. **Restart-race hardening is per-section, not systemic** — third instance
   of the same pattern now (browser-history health gate, bank-sync retry,
   llama warmup wait). A shared `wait_for_200` helper would stop the
   re-implementation; not done.
3. **Hermes Discord connectivity this boot** — gateway process tree is
   healthy (main PID alive, MCP children spawned, 214 MB RSS), but post-
   restart stdout is journal-quiet (buffering; previous boots only surfaced
   stderr lines promptly). No positive "Discord connected" assertion exists
   yet — that's the new smoke TODO.

## c) NOT STARTED

- Discord-gateway "connected" post-deploy smoke (TODO added, P1)
- `tests/test-helpers.nix` DNS-gate `/etc/hosts` helper (TODO added, P4)
- VM-test restart-count vs `startLimitBurst` audit (TODO added, P4)
- VM-test real-binary exec / build-time venv import smoke (merged into
  existing TODO, P4)
- Attic cache creation + hermes 0.20.4 build push (merged into existing
  attic TODO — cache does not exist yet, so the huge Python build re-runs in
  daily nixpkgs-compat CI until then)
- Hermes periodic bump workflow (TODO added; blocked on pin-policy decision)
- v0.21.0 release-notes re-read when it ships (folded into the bump TODO)

## d) TOTALLY FUCKED UP

1. **False-negative venv probe (nearly un-did the patch deletion!)** — after
   deleting the patch I "verified" the module was MISSING from the venv:
   first probed the wrapper derivation (no `lib/`), then ran `nix shell … --
   python3 -c import` which resolved a DIFFERENT system python (3.14 env,
   not the venv). Correct method: read `HERMES_PYTHON` from the wrapper and
   use that interpreter. A lazier run would have reverted a correct change.
2. **Edit-tool whitespace damage** — the big `hermesPkg` block edit landed
   flush-left with tabs; caught by inspection and fixed with `nix fmt`.
   Structural Nix edits need an immediate `nix fmt` hereafter.
3. **setgid subtlety cost a VM test round** — first converge used symbolic
   `chmod u=rwx,g=,o=` → dir stayed `2700` (setgid preserved); local probing
   showed numeric `chmod 0700` ALSO doesn't clear it (unprivileged, this
   kernel) — only an explicit `g-s` symbol clears it. Fixed + documented
   in-module; VM test now green.
4. **TODO_LIST multiedit replaced an unrelated entry** — my "insert after"
   was actually an "insert instead of" (old_string consumed the Gatus-patterns
   item). Noticed immediately and restored. Multiedit inserts must include
   the anchor line in BOTH old and new strings.
5. **shellcheck SC2034 broke the smoke script inside the deploy** — the
   unused `attempt` loop variable failed the `writeShellApplication` build
   of post-deploy-check, so the 05:23 deploy completed but ran NO smoke on
   that pass. Fixed (`_attempt`), then ran the smoke directly: 67/0. Build
   the check app BEFORE deploying next time.
6. **Context burn on the GitHub commit-search API** — returned a giant
   unrelated merge-commit body (~30 KB) after I already knew the
   `.patch`-URL lesson from the previous session. Re-lessoned.

## e) WHAT WE SHOULD IMPROVE

1. **Sealed-venv probes**: always resolve the interpreter from the wrapper
   (`HERMES_PYTHON` / the `exec` line), never `nix shell` + bare `python3`.
2. **`nix fmt` immediately after every structural Nix edit** — the edit
   tool's whitespace normalization is unreliable for large blocks.
3. **Pre-build smoke-tooling before deploy**: `nix build .#post-deploy-check`
   is cheap; a shellcheck failure inside `nix run .#deploy` costs a deploy
   cycle with zero smoke coverage.
4. **Extract a shared `wait_for_200` helper** in post-deploy-check (3 copies
   of the pattern now) — also pre-answers the next slow-warmup service.
5. **Concurrent-session discipline worked** — quiescence check (mtimes,
   2 h quiet) before touching shared files, no reverts, combined-tree
   verification before deploy. Keep doing exactly this.
6. **driverInteractive-first** for non-obvious VM failures (held from last
   session; the local `/tmp` repro was this session's variant and got the
   setgid answer in seconds).

## f) Top things next

| #  | Task                                                                                                                                                                         | Impact | Effort |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ |
| 1  | USER: PAT go-live — create fine-grained read-only PAT + `sops --set` into `hermes-github-token.yaml`, then confirm `hermes-github-verify` prints `private-repo read auth OK` | High   | S      |
| 2  | USER: pin policy for hermes-agent (track main vs `?ref=` release tags) — unblocks the bump-workflow TODO                                                                     | High   | S      |
| 3  | USER: history-purge push decision (held since 08-18; rotation already made residues inert)                                                                                   | Med    | S      |
| 4  | Discord "connected" post-deploy smoke for hermes (journal assert; mind 429 noise) — TODO added                                                                               | Med    | S      |
| 5  | Verify tonight's `nix-gc` actually runs post gc-guard fix (root at 96%, 44 generations — the concurrent session's fix rode this deploy)                                      | High   | S      |
| 6  | BTRFS `/data` EIO inode repair (carried P0 — nightly `btrbk-data` still aborting on it)                                                                                      | High   | M      |
| 7  | Forgejo mirror `AddAuthCredentialHelperForRemote` 2.4k errors/day (concurrent session's P1)                                                                                  | Med    | M      |
| 8  | Create attic cache + push hermes 0.20.4 tree (CI rebuild cost until then)                                                                                                    | Med    | S      |
| 9  | Shared `wait_for_200` helper in post-deploy-check; audit remaining one-shot checks for warmup races                                                                          | Med    | S      |
| 10 | VM-test helpers: DNS-gate `/etc/hosts` + restart-burst audit (TODOs added)                                                                                                   | Med    | S      |
| 11 | VM test: real-binary exec instead of `sleep infinity` (venv import proof in CI)                                                                                              | Med    | M      |
| 12 | Classify live `tools.registry` warnings (`check_bfl_requirements`, kanban-mode False)                                                                                        | Low    | S      |
| 13 | Re-read curated notes when upstream v0.21.0 ships (TERMINAL_CWD/write-path watch)                                                                                            | Med    | S      |
| 14 | Confirm the 05:23:19 deploy-stop OnFailure didn't spam Discord (known benign stop path)                                                                                      | Low    | S      |
| 15 | Consider deleting `scripts/hermes-state-audit.sh` (58G claim was stale; script purpose gone)                                                                                 | Low    | S      |

## g) Questions I cannot answer myself

1. **Pin policy (carried):** keep tracking upstream `main` (current state,
   ~250 commits/day rot) or pin release tags (`?ref=v2026.8.18`)? Recommendation:
   pin tags for deploys, bump on a cadence — but it's your stability/feature
   tradeoff to set.
2. **PAT scope (carried):** org-wide vs per-repo read-only on the GitHub UI —
   only you can see the fine-grained PAT options; the verify URL defaults to
   `LarsArtmann/go-cqrs-lite`.
3. **May I delete `scripts/hermes-state-audit.sh`?** The `/home/hermes` 58G
   claim was re-measured at 3.2M (stale); the audit script's purpose is gone.
   User call per the closed TODO entry.

---

**Repo state at write time:** working tree carries this session's changes +
the concurrent session's staged work; the auto-commit daemon batches commits
(no manual commit made, per repo convention). Deploy generation switched at
05:23 (0 failed units). Report written as `.md` per the user's explicit
instruction (overriding the status-report skill's HTML default).
