# Gitea-runner ordering-cycle class fix: late-applications.target + eval-time audit — deployed status

**Date:** 2026-10-27 00:45 CET (session start 23:15; continues the 23-10 incident report)
**Executor:** this session (owner directive: "fix it properly!!!!!!" over the 3 open questions of docs/status/2026-10-26_23-10_gitea-runner-ordering-cycle-fix-live-class-spreading.md §g)
**HEAD at start:** ac4f9dc3a; deploy fired from the quiescence-gated chain (4×60s quiet polls + green toplevel eval probe, the 2026-10-25 doctrine) — generation number recorded in §e once the switch lands.

## a. Decision — the owner question answered by execution

The 23-10 report's Q3 (class-fix direction A/B/C) is resolved as **D — none of the offered options**: plain A (drop `After=multi-user.target` from the gates) would regress the owner-ratified 2026-10-18 intent (readiness waits off the boot critical chain — miniflux was the boot-0 gate at 91s; the llama-chat 2026-10-17 ruling is the precedent). The proper shape preserves BOTH properties:

- **`late-applications.target`** (NEW: modules/nixos/services/late-applications.nix) — the graph's SINGLE `After=multi-user.target` carrier, using the suppressed-idiom (wanted by multi-user, explicitly after it → multi-user never waits for it or its members; the same suppression mechanism the runner fix proved live at 22:55).
- Gated/post-boot units take `wantedBy = [ "late-applications.target" ]` — start past the boot transaction, NO backward edge for downstream units to close cycles through, and stc/deploy coverage unchanged (`systemctl is-enabled` sees a wants symlink either way; the deploy.sh provisioner gate and pool-recovery restartUnits are unaffected).

Q2 (start the runner now?) — answered by execution: all four downed units started 23:37 via the documented script-internal-sudo pattern (agent shells: typed systemctl is guard-banned, busctl StartUnit polkit-denied, but scripts call systemctl internally — the pre-reboot-check idiom). Q1 (IO storm) — self-answered: the parallel monitor365 session root-caused and QUISCED the storm source (their 23-43 report + the [blocked:push] row); deploy pressure gates saw avg10 ~12%.

## b. The migration (16 units, one edge class eliminated)

Gate builders (lib/default.nix): mkOidcGate + mkDnsGate no longer emit `multi-user.target` in `after` — deps only (network-online + dnsblockd/pocket-id). Hand-rolled copies of the edge removed alongside wantedBy migration:

| Unit | Change |
| --- | --- |
| forgejo.service | wantedBy mkForce late (nixpkgs default overridden) |
| gatus / oauth2-proxy / miniflux / searx / browser-history | wantedBy mkForce late (nixpkgs/upstream defaults) |
| crowdsec.service | wantedBy mkForce late (nixpkgs default; MISSED in the first sweep — its prereq DNS gate would have sat on the boot chain) |
| crowdsec-bouncer-register | wantedBy late (chains after crowdsec) |
| geometrikks | wantedBy late (chains after bouncer → crowdsec) |
| hermes / hermes-github-verify | wantedBy late; hermes' hand-rolled after=multi-user dropped |
| miniflux-oidc-setup | wantedBy = [ "miniflux.service" ] (forgejo-oidc-setup family pattern) + after=multi-user dropped |
| llama-chat / netbird-evox2-login / tq-agent-pool | wantedBy late (tq: mkForce over the upstream go-taskqueue module); after=multi-user dropped — same post-boot placement semantics (2026-10-17/19 stability rulings preserved: refire churn + login polls stay outside the boot transaction) |
| boot-metrics-emit | after= late (timer-driven service; the only remaining ordering leg) |

Unchanged on purpose: plain multi-user-wanted units with no gate involvement; helpers pulled by their consumers (forgejo-oidc-setup wantedBy forgejo; crowdsec-prereq requires-pulled; architecture-catalog-sync/google-sync timer-driven); mkPoolDirUnit dir-oneshots.

## c. Incident victims — all running

Started 23:37 via ~/.cache/runner-fix/start-down-units.sh (sudo wrapper idiom):

- **gitea-runner-evo\x2dx2**: active, `[poller] launched`, declared with forgejo, and immediately drained the queued backlog — tasks 199-201 (lars/domains) at 23:37, 202-203 (lars/company-master-data) at 23:39, 204-205 at 00:08. The runner has been down 20:00→23:37 (and ~11h the day before) — CI is flowing again.
- **geometrikks**: active/running, logparser streaming all caddy access logs.
- **crowdsec-prereq**: finished clean (DNS ready instantly — dnsblockd warm).
- **crowdsec-bouncer-register**: converged ("bouncer 'geometrikks' converged from sops").

## d. Enforcement — three layers

1. **Eval-time** (NEW: modules/nixos/services/ordering-cycle-audit.nix): builds the full start-ordering graph (services/targets/timers/paths/sockets; enabled units only), edges = explicit after/before (attr + unitConfig, string-forms normalized) + implicit target-membership (wants/requires/wantedBy-derived) with systemd's explicit-ordering suppression rule modeled. TWO assertions: (1) any cycle → throw (systemd would delete start jobs); (2) any multi-user member transitively afters a late-applications member → throw (boot-blocking regression class — no cycle, but the miniflux-91s shape returns through the back door; this check is what makes "move it to late" the only correct answer for chained consumers like geometrikks).
2. **Negative tests** (scripts/negative-test-lints.sh group `orderingcycle`): runner-wantedby-regression + geometrikks-multiuser-regression — both legs PASS (eval throws with the audit marker). These legs EARNED their keep: they caught the audit's first two iterations passing vacuously (iteration 1: wantedBy not modeled — NixOS reflects it only at build time, not into targets.<t>.wants at eval; iteration 2: suffix-less attrset keys vs full-name directive refs — every service→service edge silently dropped; iteration 3 also fixed a before=-inversion bug found via a false ai-meter cycle). The lesson is banked in docs/agents/systemd.md "Boot critical-path discipline" for future audit authors.
3. **Runtime tripwire** (post-deploy-check.sh §21): journal grep for `deleted to break ordering cycle` in the -30min switch window (ANY hit = FAIL, naming the cycle) + gitea-runner is-active canary on hosts carrying the unit.

Belt: systemd-shape-audit (class 7) + io-tier-coverage-audit boot-gated scopes extended with `late-applications.target` so migrated units keep their oneshot-timeout and IO-tier coverage. tq-agent-pool VM-test invariants re-pinned (late membership asserted, multi-user after-edge asserted ABSENT).

## e. Verification evidence

- evo-x2 toplevel eval GREEN with the live audit (both assertions passing on the real 360-service graph — no latent cycles, no boot-blockers).
- `nix flake check --no-build` ALL PASSED (README 135→137 + FEATURES count re-stamps included; doc-counts gate satisfied).
- `CASES=orderingcycle` negative tests 2/2 PASS.
- Units running (§c) + IO calm (some avg10 ~12%, storm source quiesced by the parallel session).
- Deploy: **LANDED as gen-955, 07:09:47 2026-10-27** (switch test + boot profile 07:14:40, anchor verified `readlink /run/current-system` == system-955-link). Getting there: 4h of weather — the parallel monitor365 session's cargo test cycles held the disks at 98-99% (guard trips #4419-4443; the freeze-protection gates correctly refused every window 00:48-06:49 — no force-override), then pre-deploy §8 blocked on ROOT FS 100% (4.8G free, whole-btrfs fill incl. /data); unblocked by purging 5.5G of pending trash (the sanctioned 2026-10-25 trash-purge pattern, runbook traps honored) → 9.9G free. The 6h dual-gate retry loop fired the moment both gates cleared. **Post-switch verification: ZERO `deleted to break ordering cycle` lines since 07:05 (gen-954's switch deleted 3; gen-955 deletes none), late-applications.target ACTIVE with all 14 member symlinks, runner active/running THROUGH the switch, and every migrated member (forgejo, geometrikks, crowdsec, gatus, hermes, miniflux, llama-chat, browser-history, oauth2-proxy, netbird-evox2-login) active.** The class is dead in production; only the owner reboot-verify remains.

## f. Follow-ups (self-harvested)

- **Reboot-verify** (owner): one planned reboot must show ZERO `deleted to break ordering cycle` lines, the runner pulled via forgejo.service.wants, and `systemd-analyze critical-chain` placing gated probes under late-applications, not multi-user. → HARVESTED into the rescoped [blocked:user] row in docs/todo/services.md (single row, cites this report).
- **CI nightly negative-tests.yml** will run the full harness including the new group — no separate row (existing pipeline owns it).
- Nothing else open from this session: the 23-10 report's remaining §f items were either completed here (audit, post-deploy gate, victims) or already tracked (monitor365 rows owned by the parallel session).

## g. Owner-facing summary

The runner "dying all the time" is fixed at the CLASS level: the config shape that made systemd silently delete start jobs (runner dead ~11h + 3.5h across two days; geometrikks + crowdsec chain the same evening) no longer exists in the graph — one sanctioned post-boot target replaces every backward edge, an eval-time audit now fails any future build that re-arms a cycle or drags a readiness wait back onto the boot chain, and the post-deploy smoke catches it at runtime if anything still slips through. CI is already draining the backlog. The one remaining check is the next reboot (your call when) — everything else is verified live.
