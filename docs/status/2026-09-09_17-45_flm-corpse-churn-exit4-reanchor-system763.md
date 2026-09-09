# 2026-09-09 17:16 — flm corpse-churn exit-4 root cause, deploy.sh corpse guards, re-anchored system-763

Session 4 of the Samsung-migration deploy-anchor arc. Continues
`2026-09-09_05-30_deploy-unblocked-exit4-rootcause-anchored.md` and the
`06-02` self-review. User directive: keep going until everything works.

## Situation at session start (17:12)

The user's paste showed the 16:20 deploy (carrying the parallel session's tq
pool + cv GCP-portal work) exit-4'd on `fastflowlm.service`:

| Anchor        | Path                                              |
| ------------- | ------------------------------------------------- |
| running       | `d20lfcg1…` (tq/cv era, NOT profiled)            |
| profile       | system-762 `pgvbfp20…`                            |
| boot default  | `nixos-04e61773…` → 762 (no tq/cv)                |
| booted-system | `p0ccbqj5…` (Sep-8 flip gen)                      |

A reboot at that point would have silently dropped the tq/cv changes from
the running system.

## Root cause (two stacked mechanisms, both verified live)

1. **The doomed-start-inside-the-transaction class.** flm units were
   byte-identical between 762 and `d20lfcg1` (diffed all three:
   service/socket/`@.service`) — stc never restarted flm. But the
   EADDRINUSE corpse (`Zsl`+`Xsl` `flm-real` pair, pid 443303, pinning
   :52626) means every backend start dies in <1s, and **every :52625 client
   connection re-requests a start** ("Scheduled restart job immediately on
   client request", PMA/enricher ~4-5 min cadence, restart counter hit 11 →
   start-limit-hit at 17:11:42). One of those doomed starts landed inside
   the 16:20 switch transaction → `warning: the following units failed:
   fastflowlm.service` → exit 4 → profile bump skipped. This is the
   complement of the 05-30 lesson: **no unit-file change is needed** — a
   chronically-failing unit that ANYTHING can restart mid-transaction
   exit-4s the activation.
2. **stc's target cascade re-arms stopped sockets.** Manual containment
   (`systemctl stop fastflowlm.socket fastflowlm.service` at 17:13) was
   undone by the SWITCH ITSELF at 17:19:33 — "Listening on FastFlowLM …
   (public socket)" seconds into my 17:16 deploy's activation, amid the
   `Reached target …` burst, with no operator start and no memory-guard
   restore (guard last tripped Sep 3; its restore branch never fired —
   verified via its journal). Reached targets re-pull wanted sockets;
   a stopped-but-enabled socket does not survive a deploy.

## Fixes (all in `scripts/deploy.sh`, both shellcheck-build-verified)

- **Pre-switch guard** (after the memory-pressure gate): if the flm unit
  journal's last 30 lines contain `bind: Address already in use` and either
  unit is not inactive → stop socket+service + reset-failed. Kills the churn
  and the socket before `nh os switch`.
- **Post-switch guard** (after the monitor365 start): same journal gate →
  re-stop whatever the switch's target cascade re-armed. Consumers fail fast
  (ECONNREFUSED; PMA heuristic-commit fallback is wired) instead of churning
  toward start-limit-hit between deploys.
- Residual risk until the reboot clears the corpse: a client connection in
  the seconds-scale window between stc's socket re-arm and its report. On
  exit-4: re-run the deploy (converges — proven twice now).

## Result

- Clean activation → **system-763 (`jdbvg1f1…`) = /run/current-system =
  /nix/var/nix/profiles/system = boot default** (`nixos-19eb4a21…`, built
  2026-09-09). Menu: 4/4 closure-verified entries (763 default, 762, 761,
  prior-era 760).
- Smoke: 89 PASS / 7 FAIL / 6 SKIP — all 7 match the stale baseline exactly
  (flm, llama ×4, bank-sync SCA, signoz gaps); zero new failures.
- `nix run .#pre-reboot-check` (root): **14 PASS, 1 warning, 0 FAIL — SAFE
  TO REBOOT.**
- flm churn stopped post-deploy; failed units down to inboxclean-sync +
  service-health-check (reporter).

## Side diagnoses (from the baseline FAILs)

- **bank-sync**: Wise SCA challenge pending (~90d class) — statements
  paused, transfers fallback active, per-balance OTTs printed in the
  journal. USER STEP: approve in the Wise app, drop the latest OTT per
  `docs/services/bank-sync-sca.md`.
- **inboxclean-sync**: main account `gmail.token_revoked` (`invalid_grant`,
  retryable=false) — work account still syncing (cursor 5163932). USER
  STEP: `inboxclean auth` re-consent runbook. NEW upstream bug noted: the
  Paperless "demote auto tag gmail" PATCH now fails
  (`rejection:paperless.client_error`) on the work account — InboxClean
  repo candidate fix.
- **signoz traces_missing (3 enforced)**: known upstream instrumentation
  gaps (overview/PMA/papdashboard/hermes/gotenberg/renamer
  `signoz_traces_reporting 0`) — already tracked in TODO_LIST, not new.
- **p0ccbqj5**: rooted via `gcroots/booted-system -> /run/booted-system`
  while this boot lasts — tonight's nix-gc cannot delete it; the
  pin-or-release decision moves to AFTER the reboot.

## Open items (user)

1. Reboot whenever convenient (verdict: SAFE). Post-boot: flm :52625
   serving after 2-5 min cold load, llama :8848/:8849 → 200, failed-unit
   count ~0, then remove `/boot/loader/loader.conf.bak-stuckboot`.
2. Samsung p1 ESP mirror fate (keep static / automate / drop) — carried.
3. Wise SCA approval + InboxClean main re-auth (both browser/app steps).
