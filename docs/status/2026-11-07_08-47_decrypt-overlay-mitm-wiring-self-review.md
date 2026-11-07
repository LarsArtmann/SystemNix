# Decrypt Overlay (ADR-0021) Wiring, Upstream Gateway Fixes, Session Self-Review

**Date:** 2026-11-07 08:47 CET · **Instance:** crush session (github-assets PNA report → MITM directive)
**Thread:** owner pasted emeet-pixyd console CORS/PNA spam → gateway-mode root cause → "MITM myself via dnsblockd properly" → decrypt overlay wired + two upstream dnsblockd bugs fixed.

## 0. Verdict

Decrypt overlay (ADR-0021) is WIRED IN-TREE and render-verified in a throwaway worktree (`checks.dns-blocker-render` GREEN including new item 10); deploy-gated. Two dnsblockd upstream bugs found + fixed + tested (L7 pure-relay 10 MB truncation; gateway hard-off nil-conn panic stranding the lie armed). The SHARED SystemNix tree remains eval-RED from a sibling session's orphan float-registry regen (their wave, unpushed local commits in crush-config/emeet-pixyd, proof build dying) — my verification ran in a worktree with the consistent 07:52 registry restored, touching nothing shared.

## a) Root cause chain (the original console spam)

`github.com` et al. resolve to **192.168.1.200** (gateway lie, live-probed: A-records of github.com/api.github.com/github.githubassets.com/avatars.githubusercontent.com all answer the block IP) → Chromium PNA/LNA blocks public-origin → private-IP subresources ("local address space" denial) → unstyled pages. Rpi3-first resolver exemption had voided (rpi3 down) so the host rode the lie. NOT a repo problem (page serves fine).

## b) What landed — SystemNix (all daemon-swept; tree clean at 08:47)

- `dns-blocker.nix`: 3 `gatewayDecrypt*` options + optionalAttrs render (all-empty = no key) + assertions mirroring upstream `validateGatewayDecryptRules` (requires-gateway, requires-tls, devices-known vs registry, caps 256/64/256).
- `dns-blocker-config.nix`: posture = devices `[evo-x2, macbook]` (CA-enrolled only; Pixel6 deliberately spliced — Android Chrome ignores user CA certs), domains = 23 single-label TLD suffixes (filterdomain walks parent labels → all general browsing), excludes `[]` (documented pinning/bot-wall hatch).
- `dnsblockd-cert-trust.nix`: new `localNetworkAccessOverrides` option → managed-policy JSONs in `/etc/chromium/policies/managed/` + `/etc/helium/…` (`LocalNetworkAccessIpAddressSpaceOverrides = ["192.168.1.200=public"]`) — the PNA half the CA alone cannot fix. Policy verified live (Chrome 130+; **CGNAT dodge is DEAD** — Chromium unit-tests 100.64.0.0/10 as kLocal).
- `tests/test-dns-blocker-render.nix` item 10: posture pins, anti-phantom OFF variant (`decryptOffExec`), 5 assertion-fire legs, LNA-policy presence pins, python content legs.
- Docs/lifecycle: runbook decrypt section (dnsblockd.md), TODO_LIST:1817 ticked, services.md decision row ticked + 2 new rows (deploy-gated verify battery w/ input-float precondition + >10 MB download leg; MacBook-Chrome-LNA [blocked:user]), CHANGELOG entry.
- **Verified in worktree** (`/tmp/systemnix-verify`, consistent registry restored, dirty files overlaid): `gatewayDecryptDevices` evals `["evo-x2","macbook"]`; `nix build .#checks.x86_64-linux.dns-blocker-render` → GREEN (store path `l170q4rlr0nz9a…`).

## c) What landed — dnsblockd upstream

- **L7 pure-relay 10 MB truncation** (found wiring ADR-0021): `modifyProxyResponse` capped EVERY L7 response; decrypt flows ride L7 → all large downloads through decrypted suffixes would die at exactly 10 MB. Fix: cap only on the inject path (which self-caps HTML anyway); pure relay streams unlimited. Regression test `TestModifyResponsePureRelayStreamsUnlimited`. Full `test-race` GREEN (72.7s, then 45.5s re-run).
- **Gateway hard-off nil-conn panic**: L7 rows register `startConn(nil, …)` (proxy.go:275); `killConn`/`killAllConns` closed `row.conn` unguarded → nil-interface panic; `gatewayHardOffHandler` killed BEFORE the runtime flip → recovered panic left `setGatewayRunning(false)` unreached → **the emergency off-switch could fail stranded-armed mid-incident**. Fix: nil-guards (L7 rows unregister without close) + switch-before-kill reorder. Regression tests `TestGatewayKillHandler_NilConnL7Row` + `TestGatewayHardOff_NilConnL7Row` (incl. stranded-armed assertion). Targeted `-race` PASS + full suite green.
- `claims.cue` limitProxyResponseBody claim updated to the new truth (inject-only cap).
- T560 filed: off-transition honesty (drain/kill close-reason labels + `gatewayRejectionDraining` never recorded at rejection sites) — close-reason premise NOT source-verified, filed as investigation.

## d) Subagent-review verification scorecard (the discipline that mattered)

Gateway-code review claimed 5 top findings; source-verification: **#3 truncation REAL (fixed), #1 panic REAL (fixed after I first mis-dismissed it), #2 recursion FALSE (L7 transport closes over the truth-resolver seam, proxy.go:204-206), #4 blocklist bypass FALSE (gatewayGrantDenied gates the splice, server.go:1517), #5 filed as T560 investigation.** io-surface gate failure: PRE-EXISTING since its own landing 3d61ac24 (2026-11-02; the repo's known 44-of-45), tracked by their T522 — an earlier "passes at parent" worktree read was a 40 ms cache hit and briefly misled me.

## e) Blocked / not mine

- **Float wave**: 07:52 (e6ed47b06) lock+registry consistent → 07:55 (af063e4a5) registry regen alone swept WITH my files, describing a lock that never landed → every host-config eval RED since. `nix run .#float-register` (the gate's designed absorber) dies in proof: `Cannot build` on mandb/dbus unit drvs + unpushed local commits (crush-config +1, emeet-pixyd +3). Sibling's wave — not landed by me; flagged to owner.
- rpi3 still DOWN (physical/owner); host keeps falling into the lie in its windows.
- dnsblockd io-surface parity debt (T522) — theirs.
- Helium's actual policy-dir uptake unverified (both /etc/chromium + /etc/helium shipped; deploy-gated browser leg proves uptake).

## f) Self-review (what I did badly, honestly)

1. Tripped the `rg -rn` hook TWICE (host strikes 4+5) — documented trap, repeated.
2. Published "scorecard: #1/#2/#4 hallucinated" after testing the WRONG nil (`s.proxy` guards instead of `row.conn`) — the user's re-think prompt forced re-verification that found #1 real. Verdict-first, evidence-second: backwards.
3. A multiedit clipped an existing test's body (TestGatewayKillHandler_KillsAndAudits) — caught + restored immediately, but a destructive near-miss on code I didn't author.
4. Cache-poisoned worktree comparison almost pinned io-surface on me (uncached decisive run fixed the conclusion).
5. Framed the 5-day-old io-surface landing as a "live parallel session's in-flight work" while the "44-of-45" clue sat in the repo's own recent commit message.
6. Left the starve-retry background job unread for 10 minutes (result: green) while proceeding on partial evidence.
7. No pathspec commits: all my work rode heuristic daemon sweeps (shared-tree batching — attribution via this report + file contents).

## g) Self-harvested follow-ups (TODO discipline)

Harvested at authoring time: verify battery + MacBook-Chrome rows (services.md), T560 (dnsblockd). Deliberately NOT harvested: float-wave recovery (owner call — unpushed foreign commits), rpi3 revival (physical), io-surface T522 (foreign repo owner), the "flip evo-x2 to dnsblockd-first for full self-capture" scope decision (§h.2 below — owner trade-off, not queueable as ready).

## h) Owner decisions surfaced

1. Ratify the decrypt scope (23 TLDs, both devices, empty excludes) or narrow — it is owner-tunable data, not doctrine.
2. Full self-capture ("MITM myself" including evo-x2's own browser while rpi3 lives) requires flipping the host resolver to dnsblockd-first — trading SSH-by-name (needs a github.com local-zone escape) and SearXNG engines (needs the DNS-allowlist decision). Currently NOT done; host decrypts only in rpi3-down windows.
3. Float wave: investigate the `Cannot build` unit drvs or confirm the sibling session is alive to finish it.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** DONE h.1 · already-tracked §g-1 §g-2 §g-3(leg) · OBSOLETE h.3 · NEW rowed: h.2 → services [decision] full self-capture
