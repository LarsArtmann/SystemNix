# Freeze #41-#44 containment session — llama-chat retired, crash chain broken in config

**Session:** 2026-11-03 17:42–(ongoing) CET, triggered by owner: "It's the fucking 3rd time we crashed today"
**Boot:** 0 (`49e157e0`), the freeze-#44 recovery boot
**Deliverable:** stop the crash loop — the llama-chat re-arm class is config-retired, five WDT cuts registered, deploy queued on a calm window.

## a) What this session verified live

- `journalctl --list-boots` + reset reasons: **five consecutive WDT cuts** (`0x02000800`) — Nov 2 14:42 (#40, known), **15:16 (`705a6fcd`) and 22:07 (`db565285`) — previously UNREGISTERED**, Nov 3 16:16 (`deed9c84`, triaged 16:34 as "freeze #41" — numbering corrected here to #43) and 17:39 (`6e75c5e7`, #44). Ceremony-less tails on all four; counter continuity #6077→#6194 across every boot; every trip of the era "NO eligible headless tree matched".
- `scripts/crash-triage.sh --boots 5`: #41 trips=11/ENTER=24/OOM=0; #42 67/335/0; #43 11/**746**/1 (llama-server 41.7 GB VM, our own adj-300 sacrifice ranking, llama-chat.nix:230); #44 29/64/0 (21.3 trips/h, ties the record). All Branch C.
- Boot-0 live state: k10temp peaked **98.5 °C at 17:47** (6 min post-boot) riding deep-throttle; IO PSI some avg10 72-79 through 18:0x; 6-second pid-join attribution named the storm: **crush 61.9 MB/s** (executor battery) + **three fresh llama-server cold-loads** (a llama-chat RESTART re-loading the 23.4 GB GGUF — pid 1464→376703 — plus llama-vlm caption/verdict on-demand pairs). llama-vlm confirmed socket-activated + idle-TTL-unload (self-stopped 18:01:26) — the designed on-demand pattern, not runaway.
- Owner containment at 17:41:59 (pts/0 sudo): 9 re-arm units stopped (llama-chat-ensure.timer, tq-agent-pool, monitor365×3, nsfw-classifier, mr-sync-dashboard, inboxclean-web) — **strike 6 of the freeze-4 rule**: llama-chat.service itself stayed resident and re-cold-loaded; manual stops survive neither deploys nor reboots.

## b) Changes landed (committed, full `nix flake check --no-build --all-systems` green)

1. **`llama-chat.enable = false`** (configuration.nix, evidence-ledger comment inline) — the only containment that survives boots AND deploys. Kills: boot-second-8 ensure.timer re-arm, the 23.4 GB QLC cold-load storm seed, the 41.7 GB VM adj-300 preferred OOM victim (kills #34/#38/#43), the restart-into-pressure loop. ai-meter llama-chat upstream 502s meanwhile; InboxClean /chat degrades gracefully.
2. **`paperless-gpt.enable = false`** — the evo-x2 eval caught the hard consumer: extraction requires the always-on 32k server (FastFlowLM hangs + core-dumps ≥1k tokens, audit 2026-10-29; the module assertion is correct). Documents queue un-enriched; paperless + ai-meter-backed triage gate unaffected. FEATURES row → 🔧 paused, README gatus stamp 255→253 (doc-counts + features-drift catches worked as designed).
3. **Guard ioPause `cgroupPatterns` += `llama-chat.service`** (memory-emergency-guard.nix) — the 5-boots-terminal no-match fix; re-enable-day defense so a future enablement can never cold-load into a storm uncontested.
4. **Freezes #41-#44 registered**: stability.md census rows + narrative bullet with numbering correction; four evidence pulls committed (were ALL untracked — including the Nov-2 pulls that earlier sessions never committed, leaving the §15 pre-vacuum gate blocking); todo rows resolved ([blocked:user] re-arm policy row → RESOLVED by owner directive; restart storm-gating row → resolved-by-disable; TODO_LIST 187 ticked) + one new follow-up cluster row harvesting the deferred 16:34 §f items.
5. **Commit pipeline unwedged**: a daemon sweep (17f14463b) landed `tests/fixtures/gitleaks/positive-slack.txt` unscanned; its `xoxb-` numeric body tripped every subsequent commit's staged-tree scan (including the daemon's own path). Allowlisted the FIXED numeric body in .gitleaks.toml (a real token carries different numerics — cannot mask one).

## c) The deploy (queued, deliberately)

IO PSI some avg10 sat at 72-79% through the session — the deploy pressure gate would (correctly) refuse, and freeze #40 died from `DEPLOY_FORCE_PRESSURE=1` into a 98.88% storm 9 minutes after a switch. Per the freeze-#5 rule (guard trips within the hour → queue, don't race dips) the deploy waits on a genuine calm window (watcher running; fire `nix run .#deploy` unforced, letting its own battery own the gates). The tree is committed — if the box cuts again first, the next boot's deploy carries the fix regardless of this session.

## d) What I could NOT do (owner levers)

- No sudo in agent shells; the SIGSTOP license is REVOKED (2026-10-07 doctrine). The storm's session leg (parallel executor build battery: qemu VM test + nix build + go test at 61.9 MB/s) is untouchable by agents — if crashes must stop NOW, the owner's levers are: pausing the executor sessions, and the standing physical cooling inspection ([blocked:user] since freeze #8 — the thermal ceiling participated in every one of the five cuts).
- k10temp hit 98.5 °C six minutes into a cold boot AGAIN: the standing cooling deficit remains the un-fixed physical leg of Branch C.

## e) Follow-ups

Harvested into `docs/todo/stability.md` (freeze #41-#44 cluster row): tq-agent-pool exit-1 stderr; systemd memory-peak validation; guard "escalation arms after 3 trips" existence; post-reboot re-arm check at T+10 min; cv↔crm re-link→404 loop; machine-learning shutdown provenance; boot-evidence-pull crash-loop section; the IO-PAUSE no-match message printing its unmatched top-io cgroups (the attribution gap this session closed live by hand); llama-embeddings/llama-vlm swap bounds.

## f) Verdict

The crash chain's service leg (llama-chat: boot re-arm → 23 GB cold-load → 41.7 GB resident victim → OOM kill → restart into pressure → five WDT cuts) is config-dead as of the next switch. What remains: the session/build leg (owner policy, rows exist), the cooling deficit (owner hands), and the storm attribution gaps (harvested). No forced deploys, no unverified gates, every claim above carries a command or a file path.
