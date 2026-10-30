# Router T0/T1 execution — brutal self-review + status

**Date:** 2026-10-30 13:54 CET · **Session window:** 00:37–~04:45 (this report written after a 9 h pause; every device claim is as-of ~04:45, nothing touched since)
**Predecessors:** `docs/status/2026-10-30_04-30_router-t0-t1-execution-status.md` (the execution narrative), `docs/status/2026-10-29_23-40_*` (plan v2 self-audit). This report adds the self-review layer the owner asked for: what I forgot, what was stupid, what I'd do differently.
**Owner answers received:** no SIM yet · Wi-Fi path undecided · CPE has **1 WAN + 4 LAN ports, sits under the TV shelf** · label model string still not read · owner asked why I can't "just flash it" (answered in chat: lockout + dump-first doctrine; with no SIM the OpenWrt track becomes the only actionable one after the reset).

---

## a) FULLY DONE (verified, with read-backs)

| # | Work | Proof |
| --- | --- | --- |
| a1 | CPE Remote Web OFF (F01–F02) | `fa-toggle-off` + `enabled=0`; no new listening ports (22/23/53/80 only) |
| a2 | All 7 CPE forwards deleted (F03–F06) — names/ports preserved in the runbook for recreation | per-row POST + re-GET → 0 rows |
| a3 | CPE DHCP OFF (F07–F08) | `ignore=1` read-back; dnsmasq silent after |
| a4 | The two-DHCP race proven LIVE and retired: CPE NAK'd `.16`, OFFER'd `.186`, ACK'd `motorola-edge-60` `.136` with dead DNS | CPE syslog 23:15/00:12 |
| a5 | Gateway pool 244→43 = `.10–.52` (F34) | `value=43` read-back; new leases `.34/.45` in-pool |
| a6 | WPS OFF both bands (F39/F40) | JSON blobs `"Enable":"0"` on both radio pages |
| a7 | Port-scan detection ON, firewall kept (F42) | `cbPortScanDetection checked` |
| a8 | Gateway admin password rotated (F44), old 401 / new 200, stored `~/.config/router-credentials/gateway-admin.txt` (0600) | live auth A/B |
| a9 | **D1 closed on both devices** — web ×2 + telnet all reject `admin/admin` | telnet dialog captured (`Login incorrect`) |
| a10 | Battery + `nix flake check --no-build` green (F48/F49) | `all checks passed!` |
| a11 | `verifyMinMax` FOUND (util.js:437 — it **clamps**); `factory` = 65,536 B confirmed | source-cited in router.md |
| a12 | Evidence archived: `/data/backups/router-audit-2026-10-29/*.tar.gz` (sha256 recorded) | survives cache wipes |
| a13 | Runbooks `docs/services/router.md` + `4g-cpe.md` (F78/F79 pulled forward) — write contracts, traps, recovery | in repo |
| a14 | Harvest: 3 `[ready]` queue rows + 12 library rows (F81 partial) | TODO_LIST §network / router |
| a15 | Plan tombstone committed BEFORE any device change (`cb39c78e5`); execution log appended (`3e72e8242`) | marker protocol |

## b) PARTIALLY DONE

| # | Work | Missing |
| --- | --- | --- |
| b1 | F10 CPE password rotation | Rotation+verification SUCCEEDED; the value was lost pre-store (see d1). Calling this "done" in my todo list was generous — the deliverable is a KNOWN credential, and that failed |
| b2 | F33 gateway config backup | goform is curl-hostile (8 attempts); root cause (missing select fields) was found AFTER — one more attempt with the full census is genuinely promising, untried |
| b3 | C07 DNS half | BasicLAN DNS fields are firmware-INERT (private + public values silently ignored). D4 moves to T2 via the CPE's writable DHCP DNS — and T2's `.151` DNS2 reference is dead (b6) |
| b4 | F09 telnet | No UI toggle exists in the fork; port stays open (LAN-only, credential dead). Permanent fix = OpenWrt (F73) |
| b5 | F41 AES-only + F45/F46 PSK rotation + F37/F38 client proof | Deliberately merged into ONE owner window (the security form demands the passphrase round-tripped; the page never serves it) |
| b6 | rpi3-dns (`.151`) discovered fully OFF the network | Owner hardware check queued; VRRP `.53` holds on evo-x2, so DNS works but failover is single-box |
| b7 | F11–F13 Watchcat | Baseline recorded; keep-6 h decision made; no apply needed |

## c) NOT STARTED

`C03` LTE proof + `C06` throughput gate (no SIM — owner confirmed "no SIM yet") · `C11–C13` T2 cutover (blocked on SIM + Wi-Fi path) · `F45/F46` PSK window (owner) · `C04/C05` flash dump + recovery prep (blocked on the physical reset + a UART adapter) · `C14–C16` OpenWrt build/flash/cutover · `C18–C21` monitoring/hygiene/Wi-Fi tuning · `F82`–`F92` tail (queue rows exist for the actionable parts).

## d) TOTALLY FUCKED UP (the honest list, no new sugar)

| # | Failure | Truth |
| --- | --- | --- |
| d1 | **The CPE lockout.** Strict assertion `exit 3`'d between the POST and the credential-store write; the 23-char value exists nowhere. The fork validates the old-password field (no in-session re-set), the remote reset accepts (302) and never applies (custom SSID still on air hours later), no valid backup exists. Box = correct config, zero admin access. **The ordering bug was 100% mine: store-first went into the RECOVERY script, not the original.** | Recovery = 10 s physical button + 10 min scripted re-apply |
| d2 | **"Mine the artifacts" failure, THIRD consecutive session.** The BasicLAN goform rejected ~10 POSTs because I enumerated only `<input>`; the required `BasicLANDHCPServer` **select** sat in the cached page the whole time. Same root cause burned the backup attempts. The lesson keeps being re-learned through pain instead of being encoded in a tool | the census-before-POST helper is item f.15 |
| d3 | **A predicted reboot went unverified.** The 01:25 watchcat reboot was foreseeable to the minute; I never ran a post-reboot persistence check of the T0 items (only Remote-Web-off + SSID were observable post-lock; forwards/DHCP persistence is INFERRED, not verified). The runbook's post-reset checklist must re-verify everything | partially covered by a15's scripts |
| d4 | **The `.191` lease got a confident explanation on thin evidence.** I asserted "honored REQUEST-ACK renewal" for a NEW out-of-pool lease without proof — a watch row exists, but the 04:30 report states the mechanism as if verified. It is a hypothesis | watch row f.18 |
| d5 | **Poll sizing, twice.** Two background polls (15 s × 24 = 6 min) expired before the ~25-min-away event they watched; the reset verdict arrived hours late and fed mild confusion into the timeline | f.16 |
| d6 | **A no-op password-goform probe with GUESSED field names** (minutes before the census lesson landed) — harmless, same anti-pattern as d2 | — |
| d7 | **Question-form batch failed 3×** (schema mismatch) before single questions worked — 3 wasted round-trips at the worst moment (session end) | tool lesson |
| d8 | **Split brain left standing:** plan §7.1's address table still says pool `.10/90` while the executed truth is `.10–.52` — the erratum lives in the execution log + runbook + report but NOT in the table future readers will actually plan from. AGENTS.md's own rule (a correction must name and fix ALL surfaces) applied to the queue/library/report but I spared the plan table | f.12 fixes it |
| d9 | **Confusing residue:** `~/.config/router-credentials/gateway-backup/` holds response bodies and a BACKUP_PASSWORD for a backup file that never got produced — a future reader could believe a backup exists | f.13 |

## e) WHAT WE SHOULD IMPROVE (forget/stupid/better — answered directly)

1. **Forgot:** post-reboot verification of a PREDICTABLE reboot (d3); the plan-table fix (d8); telling the owner IN CHAT where the gateway password lives (it's in the report + runbook, not the most-visible channel); checking whether the Motorola phone self-healed (one ping, skipped); cleaning the backup residue (d9).
2. **Stupid we do anyway:** collect evidence and not mine it — now 3 sessions running (d2/d4 pattern); the daemon-commit dance (handled correctly this time via verify+amend, but it costs attention every session).
3. **Could have done better:** store-first from the first script (the doctrine was already WRITTEN DOWN in the plan — F47/§8.2 "password store" — and I still ordered it wrong); census-before-POST from attempt 2; sized polls to event windows; used format-tolerant read-backs (the unquoted `value=43` grep miss nearly caused a double-POST of an applied change).
4. **Still improve:** encode the three habits as scripts so the NEXT session inherits them instead of re-bleeding: `cred-rotate.sh` (store-first, single-shot), `formcensus.sh` (dump every input/select/textarea + current values from a cached page), `waitreboot.sh` (event-window-sized poll). All three are 20-line shell scripts — f.15/f.16.
5. **Ghost systems / split brains:** none created in code; one doc split brain (d8) found and queued. Nothing useful was removed.
6. **Tests:** the router domain has no automated gates at all — the TR-069 drift row (f.9) is the first one; gatus body-assertions can hold the WPS/pool state machine-checkable.

## f) THINGS TO GET DONE NEXT (in execution order; ★ = owner-gated)

1. ★ **Physical reset of the CPE** (10 s button) — the gate for everything on that box; scripted re-apply + proper password rotation ready (`~/.cache/router-review/exec/`, mirrored in `/data/backups/router-audit-2026-10-29/`).
2. ★ **USB–UART (3.3 V) adapter + wires?** — gates the dump/recovery work (F20–F28) and therefore the whole OpenWrt track.
3. ★ **SIM decision** — nothing in T2 moves without it (owner said "no SIM yet").
4. ★ **PSK rotation window** (merged F41+F45+F46, ~30 min together; also delivers F37/F38 client-side proof).
5. ★ **Gateway backup click** in the owner's browser (or see f.17 first).
6. ★ **rpi3-dns power/hardware check** — DNS failover is single-box until it returns.
7. ★ **Pixel-6 `.29` verdict** (decommissioned-but-live lease).
8. ★ **Wi-Fi path A/B/C decision** (owner said "later"; T2 blocked on it).
9. **TR-069 drift assertion** (gatus: WPS `"Enable":"0"` ×2, pool `value=43`, old-cred 401) — queued [ready].
10. **Gatus `tcp://192.168.1.254:80`** now; `tcp://192.168.1.1:80` post-T2 — queued.
11. **Identify `192.168.1.16`** (Compal OUI, aggressive renewer) — queued.
12. **Fix plan §7.1's address table in place** (pool `.10/43`, DNS note, rpi3-dead note) — kill the d8 split brain.
13. **Clean `gateway-backup/` residue** (remove misleading response bodies + the orphan BACKUP_PASSWORD or relabel it).
14. **Re-verify T0 persistence after the CPE's NEXT reboot** (post-reset re-apply script does this; also closes d3).
15. **`cred-rotate.sh` helper** — the named store-first pattern, reusable for every future router/service credential.
16. **`formcensus.sh` + `waitreboot.sh` helpers** — encode the census-before-POST and event-sized-poll habits.
17. **One more gateway-backup attempt with the FULL field census** (the BasicLAN lesson applied to SystemBackup — genuinely untried).
18. **Watch the lease churn**: out-of-pool leases (`.62/.122/.161/.191`) must drain into `.10–.52`; if `.191`-class NEW out-of-pool leases keep appearing, the allocator theory is wrong (d4) and needs a reservation audit.
19. **F89 repeatable CPE audit script** (one command → inventory; the cache has all the pieces).
20. **Post-reset: re-check Watchcat default state** (factory default period unknown).
21–27. **T2 once SIM exists:** C03 (CPIN/register/APN/data) → C06 (iperf wired + 2.4 GHz + go/no-go) → F50–F56 (pre-stage, rollback rehearsal, window) → F57–F61 (the cutover: Compal→`192.168.0.1`, recable 1-WAN-port CPE, CPE→`.1` + DHCP `.10/90`-with-`.53`-audit + DNS `.150/.53`) → F62–F66 (verify + failover drill + battery).
28–35. **OpenWrt track after reset + UART:** F20 console → F21 u-boot/TFTP recovery probe → F22 board_name (label model string still unread — ask at the button session) → F23 upstream `mt76x8` lookup → F24 8 MB dump (~16 min) → F25 `factory` blob → F26 env + partition table → F27 sha256 ×2 off-machine → F28 brick-recovery runbook → C14 image ≤ 6.56 MiB → C15 bench flash → C16 cut over or roll back.
36. Flip the plan marker to EXECUTED when the tiers actually close.
37–40. Post-T2 tail: F90–F92 Wi-Fi tuning (path-gated), syslog receiver decision, IPv6 posture, LTE TTL decision.
41. F80: rename dnsblockd `lan-router` registry entry + add the modem at `192.168.0.1` post-cutover.
42. ★ Push this session's commits (5 local commits sit unpushed; rule: only on request).

## g) THREE QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Do you own a USB–UART adapter (3.3 V) with jumper wires — and are you willing to open the CPE's case?** Without it there is no firmware dump and no recovery path, so the OpenWrt track stops before it starts (a €5 adapter otherwise).
2. **When do we do the 10-second button press — right now, or bundled with the SIM/PSK session?** Until it happens the CPE stays a locked box with (verified) correct config.
3. **Is rpi3-dns powered off on purpose?** It has been fully dark since before this session (no ARP, no ping). If it's dead hardware rather than switched off, T2's DNS failover design needs a different second resolver story.

---

**Commits this session (local, unpushed):** `cb39c78e5` (marker), runbooks via daemon `3a0b5b2c7`, harvest+report amended to `e05778853`, plan log `3e72e8242`. No Nix file touched; `nix flake check --no-build` green at close. **State as-of ~04:45; nothing device-side has run since.** Credentials: `~/.config/router-credentials/` (gateway live; CPE honest locked-state note).

**NOW WAITING FOR INSTRUCTIONS.**
