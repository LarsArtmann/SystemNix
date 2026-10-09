# dnsblockd lg-tv misattribution resolved — MacBook registry fix (session status)

**Date:** 2026-10-04 11:08 CEST
**Scope:** this session only — investigate the live "LG-TV" dashboard row, resolve the identity, fix the registry. Trigger: owner statement "192.168.1.62 is my Mac" after seeing "LG TV (SSCR2)" in the live Top Clients.
**Commits (daemon-absorbed):** config `b66dc65e` (+13/−4, verified byte-mine), render-test fixtures `05985259` (7 refs), docs/CHANGELOG `d7f637cc`+; tree clean at close.

## a) FULLY DONE

1. **Diagnosed the "LG-TV is using us" observation end-to-end:** Top Clients names come ONLY from the config-declared `devices:` registry (`internal/device.Registry`, exact-IP); `lg-tv`/.62 was a 2026-09-30 ARP-inventory guess ("Realtek NIC 00:e0:4c:… — LG TV SSCR2 by elimination"). The queries from .62 were real; the name was a hypothesis with an open owner-confirm marker.
2. **Root-caused the guess:** the actual LG TV SSCR2 is evo-x2's DP-2 _monitor_ (niri outputs, `niri-wrapped.nix`); the Realtek NIC at .62 is the MacBook Air's USB ethernet adapter. The inventory's "by elimination" eliminated itself once the owner spoke.
3. **Config fix (`platforms/nixos/system/dns-blocker-config.nix:89-101`):** entry renamed `lg-tv` → `macbook` (name "MacBook Air"), identity-confirmed comment recorded, **`macbook` added to `users.Lars.devices`** (owner chip now attributes its traffic to Lars).
4. **Test fixtures fixed (`tests/test-dns-blocker-render.nix`):** 7 `lg-tv` policy-fixture refs → `macbook`. Load-bearing: the check `extendModules` over the REAL evo-x2 config (line 23), so fixture device ids MUST stay declared — the dangling-device assertion would have failed `checks.x86_64-linux.dns-blocker-render` otherwise.
5. **Docs reconciled:** runbook `docs/services/dnsblockd.md` (both owner-confirm markers closed — pixel6 was the other; stale pixel6 removed from the live-list sentence), `TODO_LIST.md:301` + `docs/todo/services.md:81` ("lg-tv identity confirm open" → RESOLVED, Q1 closed), CHANGELOG `### Changed` entry with verification evidence.
6. **Verification (all green):** `services.dns-blocker.devices`/`users` eval JSON correct; **evo-x2 full toplevel eval green**; **`checks.x86_64-linux.dns-blocker-render` built green ("content OK")**; treefmt check confirms my two nix files conforming.
7. **Live posture correction:** confirmed prod runs `tracking_mode = "METADATA_ONLY"` (wrapper `dns-blocker.nix:281`) — `IncludesDNS()` false, domains not persisted.
8. Cleaned up formatter collateral: `nix fmt -- --ci` unexpectedly WROTE 4 untouched drifted files (pool-recovery.nix, thermal-pstate-guard.nix×2, test-pre-deploy-vendor.sh) — reverted them; my tree-touch footprint is exactly the intended files.

## b) PARTIALLY DONE

1. **"What does the Mac request?" — answered, but only to the depth METADATA_ONLY allows.** Live truth today: per-IP counters + device_id yes, per-domain NO. The full answer rides the owner-gated flip (see e) and the deploy.
2. **SSH access to evo-x2 failed** (`lars@192.168.1.150: Permission denied (publickey)`) — live-data pull (Top Clients raw rows, actual query volume from .62) was impossible from this session; all live statements rest on config + repo knowledge, not a live read.

## c) NOT STARTED (deliberately, this session)

1. The deploy itself (owner sudo window) — the rename rides it.
2. Wi-Fi coverage for the MacBook (Apple OUI, different IP) — unverified whether the Mac ever appears on Wi-Fi.
3. Any DHCP reservation for .62 (attribution is exact-IP; stability is assumed, not enforced).

## d) TOTALLY FUCKED UP (owned, with lessons)

1. **Turn-1 false claim: "tracking mode is default FULL, 30d retention."** I read dnsblockd's _default_ and stated it as the _deployed_ fact. The wrapper sets METADATA_ONLY — discoverable in one grep I didn't run until later. Exactly the verify-external-claims violation class: encoded an unverified claim into an answer.
2. **Turn-1 recommended data-starved surfaces as the answer to "what do they request"** (Query Log, day weather map, weekly digest, /api/devices/new-domains). At METADATA_ONLY those are ALL dark. Materially misleading until corrected in a later turn.
3. **Declared the render test "synthetic fixtures" without reading it** — it extends the REAL evo-x2 config. Had I stopped after the config edit (no second pass), the gate would have gone red on the next check. The disciplined breakdown pass (user-prompted!) is what caught it, not my initial diligence.
4. **Minor:** `echo FMT_EXIT=$?` after a pipeline captured `tail`'s exit, not `nix fmt`'s — reported "FMT_EXIT=0" while the formatter had actually errored (fail-on-change). Shell footgun; the Error line was still read correctly.

## e) WHAT WE SHOULD IMPROVE (process, from d)

1. **Deployed-state claims need a deployed-state source:** before asserting any live runtime fact (mode, version, config), grep the SystemNix wrapper/render — never infer from upstream defaults.
2. **Read test dependencies before declaring them decoupled.** A grep hit dismissed with a narrative ("synthetic fixtures") is not verification.
3. **Careful with tree-wide formatters in daemon-territory:** `nix fmt -- --ci` wrote files here despite the check-only intent of `--ci`; scope formatters to changed files (`treefmt <paths>`) or accept + own the churn.
4. **Attribution hygiene product-side:** this incident is the second identity miss in this registry (pixel6 decommissioned, lg-tv falsified). The registry guesses from ARP + repo knowledge; nothing in the UX marks an entry "unconfirmed". A dnsblockd-side "identity confidence" field or an operational rule "no name until owner confirms" would prevent the next mislabel.

## f) NEXT (session-scoped follow-ups, rough priority)

1. **Deploy evo-x2** — carries the macbook rename + the T332-era tree.
2. Post-deploy verify: Top Clients row reads "MacBook Air" with the Lars owner chip; `/api/temp-allowlist` device-scoped rows carry `device=macbook`.
3. Owner decision (open, memo `docs/services/dnsblockd-tracking-dial.md`): flip `tracking_mode` METADATA_ONLY → METADATA_AND_DNS — unlocks Top Domains / Query Log / Likely-Broken / device×domain / weather map / weekly digest (the actual answer to "what does my Mac request").
4. If flipped: same-commit render-test `tracking_mode` assertion update (the gate requires it).
5. Determine the MacBook's Wi-Fi IP (if it roams) — `ip neigh` on evo-x2 post-deploy or the Top Clients raw-IP rows; add to the `macbook` entry (ips list, up to 16).
6. Router-side DHCP reservation for .62 — pin the attribution permanently.
7. Fix the STALE FALSE comment in `dns-blocker-config.nix` (~line 106): "The sdns embedded resolver's root recursion is broken in dnsblockd (middleware pipeline not wired up)" — falsified 2026-09-30 (upstream 8e598c01/T299; the runbook's own next sentence says root recursion WORKS). Noticed this session, not touched (unrelated rider).
8. Check rpi3-dns parity: does the failover instance carry a device registry? If the Mac's queries land on rpi3 during failover, its Top Clients shows raw IPs only.
9. Fix evo-x2 SSH access for this key (`lars@` publickey denied) — blocked all live verification this session.
10. Normalize the 4 formatting-drifted files (pool-recovery.nix, thermal-pstate-guard.nix/.sh, test-pre-deploy-vendor.sh) in an OWNED treefmt commit — the drift I reverted still exists; root cause is the daemon committing past failing pre-commit.
11. dnsblockd product idea: `/api/devices` (30d SQL view) excludes unconfigured clients (`WHERE device_id <> ''`) while Top Clients includes them — parity option (surface with `configured:false`) would have made "why is my MacBook not listed?" self-answerable.
12. dnsblockd product idea: Query Log device filter (rows carry DeviceID; no filter control exists).
13. Consider wiring `dhcp_lease_file` if any LAN DHCP lease source is reachable — the candidates surface would have flagged the Realtek NIC as "not covered by devices:" before the mislabel.
14. dnsblockd product idea (from e4): optional "unconfirmed" marker for device entries awaiting owner verification.
15. Post-deploy: re-read the daemon commits that absorbed this session's files (SystemNix daemon made semantic rewrites historically per dnsblockd AGENTS culture; my two were verified intact, future ones ride the same rule).

## g) QUESTIONS FOR THE OWNER (cannot be determined from here)

1. **Does the MacBook ever join the LAN over Wi-Fi** (different IP, Apple OUI)? If yes, I need that IP for the registry entry — otherwise it surfaces as an anonymous raw-IP row and your earlier "why is my MacBook not listed?" recurs for the Wi-Fi leg.
2. **Sanction the METADATA_AND_DNS flip?** Everything per-domain (what the Mac requests, query log, weather map, digests) is data-starved at METADATA_ONLY by your earlier privacy stance — memo `docs/services/dnsblockd-tracking-dial.md`, one-line flip + one test-assertion edit. Without it, question 3 from this session's start stays unanswerable.
3. **Is the physical LG TV (the DP-2 monitor) also network-connected** (webOS/Wi-Fi)? If it phones home it currently does so as an anonymous raw-IP client; if you want it tracked, it needs its own entry once identified.
