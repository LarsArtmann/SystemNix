# Status: dnsblockd Gateway-Mode Investigation + G3 Issue Filing (session report)

**Date:** 2026-10-25 18:00 CET · **SystemNix HEAD:** `8944f1347` · **Scope:** THIS session only — three user asks (why gateway mode is off; why content-blind; file the angry GitHub issue) + what was noticed in passing. No unrelated research, per instruction.

**Concurrent-session note:** an untracked `docs/planning/2026-10-25_17-57_SUPERB-caddy-edge-pareto-plan.md` appeared mid-session (17:57, another active session) — flagged, untouched.

---

## a) FULLY DONE

1. **"Why is dnsblockd not in Gateway mode?" — answered, every claim live-verified.** Deployed binary `dnsblockd-23924a7` (PID 438296, `/nix/store/3mmf92z6…-dnsblockd-23924a7/bin/dnsblockd`) HAS gateway mode (upstream F151 / ADR-0011, flow core shipped 2026-10-17); the live rendered config `/nix/store/11hp3aw2…-dnsblockd-config.yaml` contains **zero `gateway:` keys** (rg exit 1); SystemNix's own module (`modules/nixos/services/dns-blocker.nix:253` YAML render) has no gateway options at all; enablement is owner-gated upstream (dnsblockd TODO T366 owner question 1 — firewall; T367 — quiet-window bench) and nothing was queued SystemNix-side. Root answer: **never armed — opt-in posture change, deliberately gated, wiring never built.**
2. **"Why content-blind?" — answered from source.** The splice is a relay, not a termination: gateway widening in `shouldPassthroughTLS` (`dnsblockd internal/server/server.go:1465-1471`), `handleTLSPassthrough` dials the real origin and relays encrypted bytes (`server.go:1480`); ADR-0011 Non-goals quote (content-blind; privacy ladder "flows default, URLs opt-in per device, bodies never"); ADR-0009's rejected-MITM reasons; the one content-visible leg is the ADR-0018 filter proxy, hard-excluded from splicing at `server.go:1447`. Client TLS ends at the real origin with the real cert — dnsblockd holds no keys, sees SNI/bytes/duration only.
3. **LarsArtmann/dnsblockd#24 filed and verified landed** — ["Gateway mode built the entire MITM position and refuses to use it — reverse the G3 non-goal"](https://github.com/LarsArtmann/dnsblockd/issues/24). Process: github-voice skill loaded (profile + revision lessons) BEFORE drafting; every premise source-verified first (G3 = `docs/research/2026-09-06_gateway-mode-brainstorm.md:127`; CA already distributed via SystemNix `dnsblockd-cert-trust.nix` Firefox-policy + NSS import; filter proxy already MITMs real browsers on the operator CA `server.go:1447`; `ModeFull` "stores everything including request/response payloads" `internal/tracking/mode.go:30`; `FULL` is the upstream default `internal/config/config.go:59`; zero duplicate issues, issues enabled). check-draft.go: **0 FAIL 0 WARN**; filed with `--body-file <real-file>` (never piped — the silent-no-op trap); verified via `gh issue view` (OPEN, 4,040 chars, table + code fence render intact). Draft kept at dnsblockd `docs/drafts/2026-10-25_gateway-mode-g3-content-inspection.md` — **auto-committed by the daemon already** (tree clean, verified).
4. **§f self-harvest executed at authoring time** (the TODO-system contract): stale `[blocked:deploy]` vendorHash post-deploy-check row premise-refreshed and flipped `[ready]` in `TODO_LIST.md` + `docs/todo/monitoring.md` (live dnsblockd `23924a79` ≫ the row's `b90b306` — the blocking switch long since rode deploys); new adb-listener `[ready]` row in `TODO_LIST.md` + `docs/todo/security.md`; gateway-wiring `[blocked:user]` row in `docs/todo/services.md` (owner-gated, correctly NOT in the queue). `scripts/check-todo-system.sh`: **OK — queue/library structure clean** (the 126-report unharvested WARN is pre-existing global drift, not this session's).

## b) PARTIALLY DONE

1. **Live `/health` API confirmation of gateway state — never obtained.** First probe used `openssl s_client` against the plain-HTTP stats port (wrong protocol → empty output), then `nc` (guard-blocked). The deployed-config evidence (zero gateway keys) is decisive, so the ANSWER stands, but the API-level positive read (`gateway.enabled=false` from `/health` on 127.0.0.1:9090) is missing. Effort S — needs a curl-capable path (repo script or python).
2. **Issue #24 lacks deployment-state context.** It argues the design flip but never states that gateway mode is enabled NOWHERE (SystemNix renders no `gateway:` block) and does not link the upstream enablement gates (T366 owner question 1, T367). A reader can misread #24 as "gateway is live and blind" when the truth is "gateway exists and is off". One comment on #24 closes it. Effort S.
3. **check-draft validation had no negative control.** 0 FAIL 0 WARN was trusted without planting a banned phrase to prove the checker actually read the file (vs. vacuous pass). Effort S.
4. **dnsblockd-side harvest of #24 not done.** The issue is not mirrored into dnsblockd's own TODO_LIST.md — unverified how that repo wants GitHub issues related to its TODO system (split-brain risk between issue tracker and TODO rows). Effort S.

## c) NOT STARTED

1. **SystemNix gateway wiring** (module options + `gateway:` YAML render) — blocked on the owner posture decision (§g.2) + upstream gates (§g.1/§g.3). Library row added (`docs/todo/services.md`).
2. **G3 ADR authoring** (amend ADR-0011's non-goal or supersede) — #24 demands it; no ADR text exists. Owner-gated.
3. **Gateway arm-state runbook section** (`docs/services/dnsblockd.md`: arm state, off-switch drill, B5.1 firewall leg) — deliberately deferred: nothing to document while the feature is off everywhere.
4. **check-draft negative-control selftest** (crush-config repo) — noticed gap, cross-repo, not started.

## d) TOTALLY FUCKED UP

1. **`rg -rn` typed TWICE in one session** — both hook-blocked (the hook message counts this as a repeat-strike trap on this host; it is documented in AGENTS.md and was in my loaded context). No corrupted output escaped (the hook caught both before display), but this is the documented-rule-violated-while-loaded class, twice. Root cause: grep muscle memory. Fix: `rg -n` only; the hook stays the backstop.
2. **`nc 127.0.0.1 9090` attempted** — `nc` is not in the verified live-probe set (AGENTS.md lists it); guard-blocked, one wasted round trip. The correct probe (unit config path from `/proc/<pid>/cmdline` + direct store-path read) was the very next call — it should have been the first.
3. **A silent empty read was accepted without naming its failure mode** — the first `/health` attempt (openssl against plain HTTP) returned empty and I moved on without recording WHY (the "empty read is never evidence" discipline requires the failure mode be named). Same sloppy-probe root cause as #2.

## e) WHAT WE SHOULD IMPROVE

1. **Plain-HTTP loopback probing has no sanctioned agent path.** curl/nc are guard-banned, openssl is TLS-only; every session rediscovers this (this session: 2 wasted calls + the b.1 evidence gap). Fix: document the standard pattern (config path from `/proc/<pid>/cmdline` + store read) or add a tiny `scripts/http-probe.sh` that runs curl internally, post-deploy-check.sh-style. Impact: recurring per-session waste.
2. **Issue filings should carry deployment-state context** when the feature discussed is shipped-but-not-enabled. One line on #24 ("gateway mode is not enabled in any deployment; SystemNix renders no `gateway:` block") would have prevented the misreading risk (b.2). Retroactive fix = the #24 comment; prospective fix = drafting rule.
3. **Voice-checker runs deserve a 30-second negative control** (plant one banned phrase, expect FAIL) before trusting 0 FAIL. Turns a green light into a proven-working check. Candidate selftest: crush-config repo.
4. **Noticed in passing (harvested → `docs/todo/security.md`):** adb mDNS listener on `0.0.0.0:5353` (pid 78854) — all-interfaces Android tooling on a firewall-trusted interface (eno1); same exposure class as the signoz `:6060` pprof finding. Intent unverified; row filed.

## f) Next tasks (12 — harvest state tagged per row)

1. **[dnsblockd-repo, S — NOT harvested into SystemNix: fix belongs to the dnsblockd repo]** Comment on #24: gateway is enabled nowhere (SystemNix renders no `gateway:` block); link T366 owner question 1 + T367 as the enablement gates.
2. **[dnsblockd-repo, S — NOT harvested: same reason]** Mirror #24 into dnsblockd's own TODO_LIST per that repo's conventions; check how it treats GitHub issues vs TODO rows (split-brain risk).
3. **[owner-gated, S]** Answer T366 owner question 1: may the NixOS module touch the host firewall (block external DoH/DoT + outbound UDP 443)? → §g.1.
4. **[owner-gated, S]** Book the T367 quiet-window bench re-take → §g.3.
5. **[owner-gated, M]** Decide the G3 flip: amend ADR-0011's non-goal or supersede with the operator-scoped decryption tier (#24 Design section) → §g.2.
6. **[HARVESTED → `docs/todo/services.md`, blocked:user]** Wire the `gateway:` config surface into `modules/nixos/services/dns-blocker.nix` once enablement is decided (options + render, B5.1 firewall leg, runbook section, deploy gates).
7. **[HARVESTED → `docs/todo/monitoring.md` + queue flip, ready]** Verify the vendorHash-wave post-deploy-check ran on a generation carrying the wave revs (premise refreshed: live dnsblockd `23924a79` ≫ row's `b90b306`).
8. **[HARVESTED → `docs/todo/security.md` + queue, ready]** Verify the adb `0.0.0.0:5353` listener is intentional; loopback-bind or document in the owning runbook.
9. **[SystemNix, S — deliberately NOT harvested: blocked on #6]** Gateway arm-state + off-switch drill runbook section once enablement lands.
10. **[SystemNix, S — deliberately NOT harvested: blocked on #5]** If G3 lands: cert-trust module messaging for decrypted flows + the `tracking_mode` rung decision (owner posture).
11. **[crush-config, S — deliberately NOT harvested: cross-repo]** check-draft negative-control selftest (planted banned phrase must FAIL).
12. **[dnsblockd-repo, XS — DONE by the daemon, listed for auditability]** Issue draft committed (`docs/drafts/2026-10-25_gateway-mode-g3-content-inspection.md`, tree clean — verified this session).

## g) Questions I can NOT figure out myself

1. **T366 owner question 1 (upstream gate, blocks the B5.3 VM test):** May the dnsblockd NixOS module touch the host firewall — blocking outbound external DoH/DoT and UDP 443? Without it, any device-level DoH (Android Private DNS, Firefox) walks straight past the DNS lie; with it, a service module edits firewall rules that SystemNix currently owns centrally. I cannot decide that ownership boundary for you — and it also gates whether gateway enablement is even worth flipping (§g.2).
2. **The posture call — everything hangs on this:** Do you want gateway mode enabled on evo-x2 at all (the sole LAN resolver becomes the SPOF carrying all name-resolved traffic), and if #24's G3 flip lands, at which tier — flows only, URLs, headers, or bodies at `FULL`? ADR-0011 cut the content tier by doctrine; only you can un-cut it. The SystemNix wiring row (`docs/todo/services.md`) is blocked on exactly this answer.
3. **T367 window:** Which quiet window may I book for the gateway bench re-take (the 1000-stream capacity numbers are explicitly directional, measured on a co-tenant machine)? I cannot create load-free windows on this box myself.
