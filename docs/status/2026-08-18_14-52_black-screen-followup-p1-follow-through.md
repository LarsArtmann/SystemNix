# Black-Screen Follow-up: P1 Follow-Through and Status

**Date:** 2026-08-18 14:52 CEST
**Session scope:** Execution of everything in the 13:51 report's §f list that does NOT require deploy/sudo — the P1 hardening leftovers (§f.14-17, §f.21, §f.23), the two §g decisions resolvable autonomously (Qt, btrbk stance), and the §b.3 verification debt. Deploy + reboot + the P0 checklist remain the user's (unchanged from 13:51 §f.1-7).

**Session arc in one line:** Every in-session-executable P1 from the 13:51 report is now done and verified — the guard got canonical-name dedupe AND a permanent CI negative test (neuter-proofed), the sops null-coercion is fixed (assertion introspection works again), Qt moved to `adwaita` (warning wall → zero warnings), the btrbk-data stance is DECIDED and documented with a repair runbook — all while a concurrent agent session shipped papdashboard/fastflowlm work into the same tree, twice racing my edits.

---

## a) FULLY DONE

1. **§b.3 closed — `niri-drm-healthcheck` unit text eval-printed** — `ConditionEnvironment=XDG_SESSION_ID` is verifiably in the generated `[Unit]` section (the house verification standard the prior session set and 13:51 skipped). Receipt: `nix eval --raw .#nixosConfigurations.evo-x2 --apply 'c: c.config.systemd.user.units."niri-drm-healthcheck.service".unit.text'` shows it as line 2 of the unit.
2. **§f.17 FIXED — sops-nix null-owner assertion crash** — root cause confirmed in the pinned upstream `modules/sops/templates/default.nix`: `message = ''…owner: ${cfg.owner}''` interpolates a NULL `owner` (the option default) into every PASSING assertion's message; `nix eval --json …config.assertions` forces all messages → "cannot coerce null". SystemNix fix (semantics-preserving, uid/gid default 0): explicit `owner = "root"; group = "root"; mode = "0400";` on the four null-owner templates — `dns-failover-env`, `dnsblockd-auth-env` (sops.nix; the comment there already CLAIMED "root-owned"), `twenty-env`, `manifest-env`. **Verified:** `config.assertions` evaluates as JSON (2013 entries), `config.warnings` too (1 entry — the Qt one, see #4). Upstream fix remains worth filing (`${toString cfg.owner}`); diagnosis text is in this report for whoever files it.
3. **§f.16 DONE — guard polish: canonical name dedupe + permanent negative test** —
   - **Dedupe:** the graph now canonicalizes unit names (strips `.service`) at collection time, so `foo` (NixOS/HM option key) and `foo.service` (raw units key / dep token) are ONE node. This closes the real false-negative class: a pull token spelled `evil-dup.service` pointing at a unit whose edges live under bare `evil-dup` previously dead-ended the BFS. Merging is monotone for reachability — strictly more sensitive, never blind. Verified: zero session-boot-audit violations on the live evo-x2 config post-dedupe (no false positives).
   - **CI negative test** (`tests/test-session-boot-audit.nix`, new, git-added): pure-eval check forcing minimal `nixosSystem` configs through `config.assertions` — the only assertion-checking CI surface (`toplevel.drvPath` never forces them). Four cases: (1) the exact historical bug (`wantedBy default.target` + `wants graphical-session.target`) MUST fail; (2) the same unit + `allowedUnits` MUST pass (the escape hatch now has its first-ever exercise); (3) a suffix-spelled `.service` dep reference MUST chain (the dedupe proof); (4) a raw-text unit with `[Unit] Wants` + `[Install] WantedBy` MUST fail (parser coverage). Failure-filtering is scoped to `session-boot-audit:`-prefixed messages — a bare nixosSystem carries unrelated failing boilerplate (no fileSystems/bootloader) that must not count. **Negative-negative tested (atomically, one shell):** with `sessionTargets` emptied, the check throws naming exactly the three detection cases; restored, it evaluates to a green derivation.
4. **§f.15 DECIDED + EXECUTED — Qt `platformTheme`: `gnome` → `adwaita`** — research: the HM deprecation warning's successor maps `gnome` → qgnomeplatform (ARCHIVED upstream, "no longer maintained" — a future nixpkgs drop would eval-break us) vs `adwaita` → qadwaitadecorations (maintained, same FedoraQt lineage, honors the GTK dark preference — the property the polkit fix actually needs). Style stays `fusion` (built into qtquickcontrols2, look-neutral; the Adwaita STYLE would fight Catppuccin Mocha). **Verified at eval:** `config.warnings` is now EMPTY (the warning was the config's only one), `qadwaitadecorations-0.1.7` (qt5+qt6 variants) land in the HM environment. The one thing eval cannot prove — that polkit auth dialogs RENDER correctly — rides the deploy settle check (added to TODO §2.5 wording). Reverting is a one-liner if adwaita misbehaves.
5. **§g Q3 DECIDED + DOCUMENTED — btrbk-data stance: keep failing until T04-T08** — reasoning now in the TODO_LIST P0 entry: (1) an older-parent resend CANNOT avoid the EIO (incremental send must read every delta extent; the corrupted file sits under docker/container dirs that churn DAILY — it is in every delta until repaired), killing option (c) with an argument instead of a hunch; (2) suspending trades an INFORMED red (OnFailure Discord + kernel csum receipts) for a LESS informed red (backup_all_healthy staleness fires either way — you lose the attempted-and-failed distinction); (3) churn is bounded (oneshot, no Restart). The failure IS the tripwire that T04-T08 is outstanding. Also appended: the sudo repair runbook (resolve inode → docker/containers likely disposable → delete → `scrub -B /data` → next nightly proves green; monitor365 path = safety-copy first per master plan).
6. **§f.10 partially — inode 1331118 resolution attempted without sudo** — `/data/{docker,containers,monitor365}` are all root-only (0700/0750); resolution genuinely needs the user's `sudo find`. Nothing further reachable from this session.
7. **§f.21 DONE — FEATURES.md entry** for `services.session-boot-audit` (Desktop & System Services table, FULLY_FUNCTIONAL, with the CI negative test noted).
8. **§f.23 DONE — AGENTS.md concurrent-session coordination rule** (Critical Rules): flag foreign tree growth immediately, your green flake check only covers YOUR files, mid-edit races mean re-read-before-edit + atomic neuter/restore cycles, and the tracked-files trap (a new un-added module file breaks every evo-x2 eval with "attribute missing" until its owning session `git add`s it — hit live this session with papdashboard.nix).
9. **Docs harvest** — TODO_LIST (header, P0 stance+runbook, §2.5: sops closed, VM-test entry rewritten around the now-two-layer interim guards, settle check notes the adwaita render check), CHANGELOG (Added ×1, Fixed ×2), FEATURES.md, AGENTS.md. This report closes the loop.

## b) PARTIALLY DONE

1. **Nothing deployed** — as designed; the 13:51 §f.1-7 P0 checklist still governs. This session's changes ride the SAME pending deploy (all eval-verified only; runtime behavior of adwaita + the dedupe's real-graph insensitivity are the two things only a deploy can show).
2. **The sops-nix UPSTREAM filing** — diagnosis is complete and verified (pinned rev `a8627b21`, `modules/sops/templates/default.nix:142` + the group/gid twin at :151 that mislabels fields), but no issue was filed to Mic92/sops-nix from this session. It needs the verify-before-filing discipline + gh auth decision; TODO §2.5 entry carries the pointer.

## c) NOT STARTED

1. **VM test (runtime half)** — TODO §2.5 rewritten: the eval guard + CI negative test now cover the CLASS at eval time; the VM test's remaining unique value is the runtime assertion (lingering boot → no niri process).
2. **§g Q2 (aw-watcher gate silence monitoring)** — unchanged user-preference call, still open in TODO §2.5.
3. **§f.19-20 (helium SIGTRAP, emeet-pixyd WARN)** — post-reboot-verify / upstream items, untouched.

## d) TOTALLY FUCKED UP!

1. **I forgot `networking.hostName` vs `system.hostName` and spent a debug round suspecting the flake.** The eval "flake does not provide attribute" error on a WRONG attr path sent me probing `builtins.attrNames` at three levels and half-suspecting flake-parts output filtering before the penny dropped: hostName lives under `networking`. The nix error for a missing NESTED attr misleadingly claims the whole flake lacks the path — worth remembering.
2. **First negative-test design used an illegal config.** `systemd.user.services.evil-dup` + `systemd.user.units."evil-dup.service".text` for the SAME unit is a hard NixOS definition conflict (nixpkgs guards it) — my "split spelling" case could never eval. Replaced with the actually-occurring hazard (suffixed dep TOKEN vs bare unit key), which is also the better test.
3. **First escape-hatch assertion was too strict.** `failing == []` on a bare nixosSystem counted unrelated boilerplate failures (no fileSystems, no bootloader). Fixed by scoping the filter to `session-boot-audit:`-prefixed messages — the probe that found this ALSO proved the hatch works (only boilerplate remained).
4. **The first neuter attempt was invisible.** My sed-based `lib.optionalAttrs false [...]` neuter produced a TYPE error (attrset where list expected) that my narrow `grep "regression:"` missed entirely — I nearly concluded the check was inert based on a grep that couldn't see the actual failure mode. The redo captured full output and used a clean string-swap neuter. Same lesson as 13:51 §d: match the observation to the claim.

## e) WHAT WE SHOULD IMPROVE!

1. **`nix eval <flake>#<path>` on a missing nested attr reports "flake does not provide attribute"** — verify the OPTION PATH first (attrNames level by level) before suspecting flake wiring. (Now also implied by the AGENTS.md flake-parts-wrapper gotcha.)
2. **Guard tests belong next to the guard, in CI, from day one.** The 13:51 session's manual negative test was one-shot and already fading; `tests/test-session-boot-audit.nix` makes it permanent. Apply this pattern to future eval-time guards (otel-endpoint-audit has VM-test coverage; dynamic-user-audit has none — candidate).
3. **When racing a concurrent session: prefer additive, file-local changes** (new test file > edits to shared flake.nix) and verify only YOUR surfaces mid-race (the check evaluates its own minimal configs, not evo-x2). This session's layout survived two races without conflict.

## f) Up to 50 things to get done next

**P0 — unchanged, user-gated (from 13:51 §f.1-7):** deploy (+ review/accept the concurrent sessions' papdashboard + fastflowlm + smartd + data-to-pool riders), reboot, 08-15 §4 checklist, settle check (now including the adwaita render check), `niri_zombie 0` + `btrfs_health_critical` alert expectations, crush-daily boot, agent cadence.

**P1:**
1. File the sops-nix upstream issue (diagnosis in §a.2; `verify-before-filing` discipline; PR is likely `builtins.toString` on three interpolations).
2. Master plan T04-T08 — /data corruption repair; runbook now in TODO_LIST P0 (stance decided, option (c) eliminated).
3. VM test runtime half (TODO §2.5).
4. aw-watcher gate monitoring preference (§g Q2 — still yours).
5. dynamic-user-audit: consider the same CI negative-test pattern now proven on session-boot-audit.
6. helium SIGTRAP + emeet-pixyd WARN — post-reboot verify / upstream.

## g) Questions I cannot answer myself

1. **(Carried, unchanged) Deploy timing + rider acceptance** — the tree now additionally contains the concurrent sessions' papdashboard service (caddy vHost, ports, sops) and fastflowlm socat rework on top of everything 13:51 §g.1 listed. All eval-green together as of this report; deploy ships all of it.
2. **(Carried) aw-watcher gate monitoring** — 13:51 §g Q2, untouched.

---

*Everything executable without deploy/sudo is done and verified; the tree is deploy-ready pending your call. The guard now fails CI if it ever goes blind — the strongest thing this session shipped.*
