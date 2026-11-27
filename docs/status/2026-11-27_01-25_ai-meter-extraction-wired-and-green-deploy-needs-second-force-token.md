# Status 2026-11-27 01:25: ai-meter is built from its own repository and every gate is green; the deploy that makes it live is refused at force level 1

**Written:** 2026-11-27 01:25 CET, SystemNix HEAD `2ad010ee8`, ai-meter `f2a21aa` on both remotes. Live system: still generation 1032 (`zm83sr97…`), the 30 s budget.

## What is done

| Task | State | Evidence |
| ---- | ----- | -------- |
| Budget 270 s | committed (`0792bfa75`), **not live** | `modules/nixos/services/ai-meter.nix` |
| Repository lint | 0 findings | `golangci-lint run ./...`; `buildflow --build-mode dev` rc 0 |
| Repository flake, CI | green | `nix build`, `nix flake check`, `nix fmt`; README quick start run against a fake upstream |
| Pushed | `f2a21aa` on Forgejo and GitHub | `git ls-remote origin master`, `git ls-remote github master` |
| Input and lock | `708573735`, floats on `master` | hook: all-systems flake check and toplevel gate passed |
| Call sites moved, in-tree copy removed | `23ed59f99` | toplevel eval, guards, `aimeter` negative group 13/13 |
| Go suite as a flake check here | `2ad010ee8` | `nix build .#checks.x86_64-linux.ai-meter-go-suite` rc 0 |
| VM test with the input-built binary | green | `nix build .#checks.x86_64-linux.ai-meter-vm -L` rc 0, 31.7 s |
| Runbook, changelog, domain terms, data ownership, plan progress | `551f11b54`, `2ad010ee8` | `docs/services/ai-meter.md` "Admission control" |

## What is not done, and why

1. **The deploy.** Two forced attempts (`DEPLOY_FORCE_PRESSURE=1`, 23:28 and 00:44). The first passed the whole battery until `nixosConfigurations.evo-x2 evaluation failed` while another session had `flake/parts/apps.nix` open; the same eval passes on the clean tree (38 s). The second was refused at entry: the memory guard tripped 7 times in the hour before, which the gate answers with exit 12 and the demand for `DEPLOY_FORCE_PRESSURE=2`. That token exists because two forced deploys at level 1 into this state ended in watchdog deaths (freeze #40, #49). I did not give it myself. The trips are the phantom ones (zone 6, disks 2.4% busy, the stalled cgroup is a ghostty window): the fix ships with this deploy and needs every ghostty window restarted afterwards.
2. **The 24 h ledger measurement** waits for the deploy.
3. **The side effects of this deploy, which the owner should know.** The tree also carries the mic-monitor recording shim (`867e7ad0a`) that the owner cancelled in another session: once deployed the monitoring agent records 10 s of the default microphone every 5 minutes. The live memory guard still freezes bystander processes; its fix sits in another session's worktree.
4. **`encoding/json/v2` contradicts STACK.md.** Commit `25e31e7` in ai-meter (not mine) moved every JSON surface to v2; STACK.md excludes it until the injected request body is byte-compared. Tests and the quick start pass; the comparison was not run. Queued in the repository's TODO_LIST.
5. **Not run:** the ai-meter flake check on `aarch64-darwin` and `aarch64-linux`; the new Forgejo CI (first run is on the next push); the `[decision]` row for the quota circuit (T07).

## Follow-ups (harvested where this repository owns them)

- The deploy itself: owner decision on `DEPLOY_FORCE_PRESSURE=2` or a quiet hour.
- Restart every ghostty window after the deploy (owner action; it ends the sessions in them).
- 24 h after the deploy: budget-answer share and failed turns from the ledger.
