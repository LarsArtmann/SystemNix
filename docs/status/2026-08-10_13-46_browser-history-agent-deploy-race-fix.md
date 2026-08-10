# Browser History Agent Deploy Race Fix

**Date:** 2026-08-10 13:46
**Trigger:** Deploy failure — `browser-history-agent.service` exit 1, `nh os switch` exit code 4

---

## What Happened

During `nix run .#deploy` (nh os switch), systemd stopped and started `browser-history.service` and `browser-history-agent.service` simultaneously. The agent (Type=oneshot, 4 retries per batch over ~7s) extracted browser profiles and pushed them to the server before the server (Type=simple — Go binary hadn't bound the port yet) was ready. Caddy returned 502 for all 4 retry attempts. The agent exited 1, which blocked the deploy with "Activation (test) failed: exit status 4".

## Root Cause

- **Agent:** `Type=oneshot`, `Restart=on-failure`, `StartLimitBurst=3`, only `after = [ "network-online.target" ]` — NO ordering dependency on the server
- **Server:** `Type=simple` — systemd marks it "active" the moment the process starts, before Go's HTTP listener binds
- **No health gate:** Agent immediately starts pushing ~8,065 visits in 17 batches of 500 — no readiness check before first batch
- **Co-located on evo-x2:** Both server and agent run on the same machine, so they restart together during deploy

## Fix Applied

**File:** `modules/nixos/services/browser-history.nix`

1. **`waitServerReady` health-gate script** — `writeShellApplication` that polls `http://127.0.0.1:8087/health` with `curl --retry 30 --retry-delay 2 --retry-all-errors` (60s max timeout)
2. **Co-located ordering block** — `mkIf (agent.enable && server.enable)` that adds:
   - `after = ["browser-history.service"]`
   - `wants = ["browser-history.service"]`
   - `ExecStartPre = "+${lib.getExe waitServerReady}"`
   - `TimeoutStartSec = "2min"`
3. **AGENTS.md gotcha** — Documented the race condition, root cause, and fix pattern

## Verification Done

- `nix eval` confirmed: agent now has correct `after`, `wants`, `ExecStartPre`, `TimeoutStartSec`
- `nix flake check --no-build` — all checks passed
- Pattern consistency confirmed: matches existing `waitDnsReady` (discordsync) and `signoz-wait-ready` patterns

## Verification NOT Done (Honest Gaps)

- **Did NOT run `nix run .#deploy`** — only eval-checked. The fix is not verified at runtime.
- **Did NOT test the `/health` endpoint manually** — assumed it exists based on the Gatus config. Gatus checks it at `http://localhost:8087/health` with `[STATUS] == 200`, so it should exist, but was not curl'd live.
- **Did NOT check whether the agent timer (`browser-history-agent.timer`, `OnBootSec=1min`, `OnUnitActiveSec=5min`) also needs ordering.** During deploy, `switch-to-configuration` restarts the service (not the timer), so the timer isn't the deploy problem. But the timer could fire on boot while the server is still starting — same race, different trigger.

---

## a) FULLY DONE

1. Diagnosed root cause of deploy failure (502 race, not a code bug)
2. Added `waitServerReady` health-gate script using `writeShellApplication` + `curl`
3. Added co-located agent→server ordering `mkIf` block (`after`, `wants`, `ExecStartPre`, `TimeoutStartSec`)
4. Verified all ordering attributes via `nix eval`
5. `nix flake check --no-build` passes
6. Updated `AGENTS.md` with new gotcha entry
7. Pattern consistency — matches `waitDnsReady` (discordsync) and `signoz-wait-ready` conventions

## b) PARTIALLY DONE

- **Runtime verification:** Eval-only, not deploy-verified. The fix SHOULD work (identical pattern to discordsync/signoz), but has not been proven on the live system.

## c) NOT STARTED

1. Actual deploy (`nix run .#deploy`) to confirm the agent no longer fails
2. Checking whether other co-located server+agent pairs on evo-x2 have similar races
3. Evaluating whether the agent timer needs a similar `after` dependency for boot-time scenarios

## d) TOTALLY FUCKED UP

Nothing. The fix is clean, consistent with existing patterns, and eval-verified. No regressions introduced.

---

## e) WHAT WE SHOULD IMPROVE

### Brutal Self-Review of This Session

1. **I did not deploy.** I diagnosed, fixed, eval-checked, and walked away. The user said "FIX!" — a fix that isn't deployed is a hypothesis, not a fix. I should have run `nix run .#deploy` and confirmed the agent starts cleanly. I stopped at eval because the user didn't explicitly say "deploy", but "FIX!" implies "make it work on the actual system."

2. **I didn't check the agent timer.** The `browser-history-agent.timer` fires every 5 minutes (`OnUnitActiveSec=5min`) and 1 minute after boot (`OnBootSec=1min`). The timer has NO ordering dependency on the server either. My fix only addresses the deploy-time restart (service-level `after`). If the server is slow to start on boot, the timer fires at 1min, the agent fails the same way, and systemd's `Restart=on-failure` retries with 10s delay — eventually succeeding after the server comes up, but producing error noise. This is a secondary issue I didn't investigate.

3. **I didn't test the `/health` endpoint.** I assumed it exists because Gatus checks it. But what if the endpoint requires authentication, or returns a non-200 status during startup? The Gatus check might be tolerant in a way my health-gate isn't. A quick `curl -sf http://localhost:8087/health` would have confirmed.

4. **I should have scanned for similar race conditions across the codebase.** The co-located client+server pattern isn't unique to browser-history. If there are other services where a client/agent and its backend restart together during deploy, they could have the same problem. I only fixed the one that crashed.

5. **The `+` prefix on ExecStartPre may be unnecessary.** The `+` prefix makes the script run as root with full privileges. The agent already has `RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ]` (can make TCP connections), so a plain `ExecStartPre` (without `+`) running as the service user `lars` should be able to curl localhost. The `+` prefix is used by discordsync's `waitDnsReady` because that service has tighter sandboxing. For browser-history-agent, it might work without `+`. This isn't wrong (it works either way), but it's less precise than it could be.

6. **No status report was written proactively.** The user had to explicitly ask for one. For a deploy-blocking fix, I should have documented it immediately.

---

## f) Up to 50 Things to Do Next

| # | Priority | Task |
|---|----------|------|
| 1 | **CRITICAL** | Run `nix run .#deploy` and verify `browser-history-agent.service` starts cleanly |
| 2 | **HIGH** | Manually `curl -sf http://localhost:8087/health` to confirm the health endpoint returns 200 |
| 3 | **HIGH** | Add `after = ["browser-history.service"]` to `browser-history-agent.timer` to prevent boot-time race |
| 4 | **HIGH** | Audit all co-located client+server pairs on evo-x2 for similar startup races (monitor365, discordsync, etc.) |
| 5 | **MEDIUM** | Consider whether the `+` prefix on `waitServerReady` ExecStartPre is needed (agent already has AF_INET) |
| 6 | **MEDIUM** | Add the browser-health-agent to `deploy.sh` explicit restart list if it's not already there |
| 7 | **MEDIUM** | Check if Gatus health check for Browser History should also cover the agent (currently only server is monitored) |
| 8 | **LOW** | Consider extracting a reusable `mkHealthGate` helper in `lib/default.nix` for the repeated curl-poll pattern (discordsync, signoz, browser-history all do the same thing) |
| 9 | **LOW** | Review whether `StartLimitBurst=3` on the agent is too aggressive — with the health gate, legitimate failures should retry more |
| 10 | **LOW** | Document the co-located ordering pattern in `docs/CONTRIBUTING.md` as a module-authoring guideline |

---

## g) Questions I Cannot Answer Myself

1. **Should I deploy now?** The user said "FIX!" — I interpreted that as "fix the code" but did not deploy. Should I run `nix run .#deploy` to verify the fix works on the live system? (The deploy takes ~48s and restarts 7 services including SigNoz and DiscordSync.)

2. **Is the agent timer (`OnUnitActiveSec=5min`) intentional?** The agent syncs every 5 minutes. This seems aggressive for browser history — is this the intended frequency, or should it be less frequent (e.g., every 30min)?

3. **Should the health-gate poll the local server (`127.0.0.1:8087`) or the Caddy-proxied URL (`https://history.home.lan`)?** I chose local (bypasses Caddy, tests the server directly). The agent itself connects via Caddy (`https://history.home.lan`). If Caddy is the bottleneck (not the server), the health gate would give a false green. Should I poll both?
