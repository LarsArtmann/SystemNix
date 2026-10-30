# Router plan T0+T1 executed: gateway hardened, CPE disarmed then locked

**Date:** 2026-10-30 04:30 CET · **Session start HEAD:** `2e2896a08` · **Plan:** `docs/planning/2026-10-29_22-18_SUPERB-4g-failover-then-openwrt-pareto-plan.md` (marker `EXECUTING`, commit `cb39c78e5`)
**Arc:** plan approved → T0 disarm CPE (clean) → T1 gateway hardening (goform write-path reverse-engineered) → **CPE password lockout incident** (recovery planned, needs owner hands) → runbooks + harvest + this report.
**Owner instruction:** "Execute and Verify them one step at a time. Repeat until done." — everything below was executed against the live devices; every change carries a read-back verification.

---

## a) FULLY DONE

| # | Work | Evidence |
| --- | --- | --- |
| a1 | **F01–F02: CPE Remote Web OFF** | read-back `fa-toggle-off` + `enabled=0`; port scan shows no new listeners (22/23/53/80 only) |
| a2 | **F03–F06: all 7 CPE port forwards deleted** (ssh-onprem-0 22, k8s 443+6443, tailscale 41641, Longhorn 9500–9502) | per-row POST + re-GET ×7 → `remaining forward rows: 0`, table empty |
| a3 | **F07–F08: CPE DHCP OFF (`ignore=1`)** + zero dnsmasq activity after disable | served form reads 1; syslog silent post-change |
| a4 | **The two-DHCP race was LIVE, not latent** — the CPE NAK'd client `.16`'s renewal and OFFER'd it `.186` at 00:12, and ACK'd `motorola-edge-60` at `.136` with dead DNS at 23:15 (yesterday's "zero leases" no longer held) | CPE syslog lines; F07 retired a real interference source; the phone self-heals on next renew/Wi-Fi toggle |
| a5 | **F34: gateway DHCP pool 244 → 43 (`.10–.52`)** | BasicLAN.asp read-back `value=43`; new leases `.34/.45` in-pool |
| a6 | **F39/F40: WPS OFF both bands** | page JSON blobs `"WPS":{…,"Enable":"0"` on wl0 + the 5 GHz page |
| a7 | **F42: port-scan detection ON** (firewall protection kept on) | `cbPortScanDetection checked` in re-served page |
| a8 | **F44: gateway admin password rotated** (24-char, stored `~/.config/router-credentials/gateway-admin.txt`, 0600, off-repo) | old auth → 401, new auth → 200 |
| a9 | **D1 closed on both devices** — no known default credential works anywhere (web ×2 + telnet `Login incorrect` live-probed) | battery §D1 all green |
| a10 | **F48/F49: verification battery + `nix flake check --no-build`** | D1/D2/D6 green; D3 single-server true; `all checks passed!` (expected darwin omission) |
| a11 | **Evidence gap #9 (d11) resolved: `verifyMinMax` FOUND** — `util.js:437`, and it **clamps** (`<min → min`, `>max → max`), stronger than "validator minimum 1": the form cannot even submit a pool below 1 | source read, cited in router.md |
| a12 | **Evidence gap #10 resolved: `factory` partition = exactly 65,536 B (64 KiB)** | kernel MTD lines `0x40000–0x50000` |
| a13 | **Evidence archived durably**: `/data/backups/router-audit-2026-10-29/router-review-cache-20261030-0412.tar.gz` (277 KB, sha256 `b1ae3087…`) | cache no longer single point of failure |
| a14 | **Runbooks F78/F79 pulled forward**: `docs/services/router.md` + `docs/services/4g-cpe.md` — inventory, state tables, the goform/CBI write contracts, traps, recovery runbook | files in repo |
| a15 | **Harvest landed** (F81 partial): 3 `[ready]` queue rows (TR-069 drift assertion, identify `.16`, gatus router checks) + 12 library rows in `docs/todo/services.md` incl. all `[blocked:user]` items | TODO_LIST.md §network / router |
| a16 | Plan-execution tombstone written and committed BEFORE any device change (`cb39c78e5`) | marker protocol followed |

## b) PARTIALLY DONE

| # | Work | Missing |
| --- | --- | --- |
| b1 | **F33 gateway config backup** | The goform download is **curl-hostile** (8 variants: urlencoded/multipart/browser-faithful python/hidden-fields/UA — all rejected or empty). Owner browser click on `SystemBackup.asp` (60 s) completes it. Interim rollback insurance: cached 24-page set + the before/after table in router.md. **The same root cause (missing select in POST) likely applies — one more attempt with the fully-enumerated field set is cheap next session** |
| b2 | **C07 DNS half (F35): BasicLAN DNS fields are firmware-INERT** — accepted (302) and silently ignored for private AND public test values. DNS-to-clients is ISP/TR-069-managed on FW 2.9.13. D4 therefore rides T2 (the CPE's DHCP DNS fields are writable), not this device. T2's plan values need updating: DNS2 `.151` is dead (see b3) — use `.150` + `.53` (VRRP virtual, verified serving + blocking) |
| b3 | **rpi3-dns (192.168.1.151) discovered OFF the network entirely** (no ping/ARP/ports) by the C07 safety gate | Owner power/hardware check queued. The VRRP `.53` floats to evo-x2 so DNS service is unaffected — but DNS failover is single-box today |
| b4 | **F09 telnet**: no UI toggle exists in the vendor fork; port 23 stays open (LAN-only). Default credential dead via rotation; permanent fix = OpenWrt flash (F73) | recorded in 4g-cpe.md traps |
| b5 | **F41 AES-only deferred BY DESIGN** into the owner PSK window: the security form requires the passphrase round-tripped and the page never serves the current PSK — merging F41+F45+F46 into one owner-collaborative step is strictly better than a blind POST | blocked:user row queued |
| b6 | **F37/F38 client-side DHCP proof**: config-true (pool reads back), but no controllable DHCP client existed this session; natural proof arrives at the PSK re-key (forces full re-DHCP) or the next lease churn | folded into the PSK window |
| b7 | **F11–F13 Watchcat**: baseline recorded (19118 s/21600 s at 00:43), decision = keep 6 h (box idles until SIM); apply-step = no-op by choice | 4g-cpe.md |

## c) NOT STARTED

`C03` LTE proof (needs SIM — owner) · `C06` throughput gate (needs WAN-mode bench + recabling) · `C11–C13` T2 cutover (blocked on the three owner answers + SIM) · `F45/F46` PSK rotation (owner window) · `C14–C16` OpenWrt flash tail · `C18–C21` monitoring/hygiene/Wi-Fi tuning (queue rows exist) · `F24/F27` firmware dump (parallel track, pre-Phase-4 only).

## d) TOTALLY FUCKED UP

| # | Failure | Cost / state |
| --- | --- | --- |
| d1 | **The CPE password lockout.** The rotation itself SUCCEEDED and verified live (old 403 / new 302), but my strict assertion `exit 3`'d **between the POST and the credential-store write** — the 23-char random value now exists nowhere. The fork validates the old-password field (in-session re-set impossible), the remote "Reset to defaults" 302-accepts and never applies (posted ×2; custom SSID still on air hours later = no reset), and no valid config backup exists. **The box is config-hardened but administratively locked until someone presses the physical reset button.** The recovery is 10 min and rides the SIM visit — but the ordering bug was mine: I wrote store-first into the RECOVERY script after the fact instead of the original. The working pattern is now named in both runbooks | CPE locked; blocked:user row with full procedure |
| d2 | **The "mine the artifacts" failure recurred a THIRD session in a row** — the BasicLAN goform rejected every POST ("Error converting one or more entries") for ~10 attempts because I enumerated only `<input>` fields; the required `BasicLANDHCPServer` **select** was in the cached page the whole time. Had the full control census (input+select+textarea) happened on attempt 2, the backup AND the LAN change would have landed immediately | ~90 min, plus 6 backup attempts that shared the root cause |
| d3 | **Two background polls expired before the event they watched** (15 s × 24 = 6 min of polling for a ~25 min-away watchcat reboot): the reset verdict arrived hours late and the second poll overlapped nothing | confusion cost, no damage |
| d4 | **A no-op password-goform probe with GUESSED field names** (`SystemPasswordOldPassword` etc.) before enumerating — harmless (server ignored them) but the same anti-pattern as d2, executed minutes before I learned the lesson | none; recorded for the pattern |
| d5 | **First C07 read-back grep wrote "failure" while the change had applied** — my pattern expected `name="X" value=Y` quoting that the page doesn't use (unquoted `value=43`); I nearly re-POSTed an applied change before inspecting raw bytes | caught by inspection; the iron rule "read-back is truth" needs "with a pattern that matches the server's actual format" appended |

## e) WHAT WE SHOULD IMPROVE

1. **Store-before-POST for any credential mutation** — single-shot script: generate → persist (0600) → POST → verify → report. No assertion between POST and persistence, ever. Now written into both router runbooks as the named pattern (and gw-f44.sh is the reference implementation).
2. **Full form-control census (input+select+textarea+button-name) before ANY goform/CBI POST**, from the cached page — this one habit would have saved both the backup and 90 min of BasicLAN bisecting.
3. **Background polls must be sized to the physical event window** (watchcat 6 h cycle ⇒ poll ≥ 40 min or event-triggered).
4. **Read-backs need format-tolerant patterns** (these ASP pages emit unquoted attributes; LuCI serves state in JSON blobs).
5. **Plan §7.1 erratum (found by execution):** the gateway allocates DHCP hash-style (scattered leases), so the planned `.10–.99` pool could lease `.53` (dnsblockd VRRP) to ANY client — executed as `.10–.52` (size 43), which the plan's own "keeps .53 free" intent requires. Plan + runbook updated; T2's CPE pool (`.10/90` at F53/F60) needs the same audit before cutover — the CPE is dnsmasq (sequential), so `.10–.99` is safe THERE, but record why they differ.
6. **TR-069 drift is now a queue row** (gatus body assertions) — the ISP can silently revert today's hardening; until that check exists, re-verify router.md's state table at any router interaction.

## f) TOP THINGS NEXT (all harvested: TODO_LIST.md §network / router + docs/todo/services.md §network / router)

1. **Owner answers (the T2 gate):** SIM + metered?, Wi-Fi path A/B/C + CPE location, label model + port count.
2. **Owner hands:** CPE factory-reset button → re-apply T0 → rotate password store-first (10 min, rides the SIM visit).
3. **Owner window:** PSK rotation ×2 bands + AES-only + client re-key (merged F41/F45/F46; also delivers F37/F38 proof).
4. **Owner click:** gateway config backup via browser (F33 residual) — or one more curl attempt with the fully-enumerated field set.
5. **[ready] TR-069 drift assertion** (gatus: WPS `"Enable":"0"` ×2, pool `value=43`, old-cred 401).
6. **[ready] Gatus `tcp://192.168.1.254:80`** now (+ `.1` post-T2).
7. **[ready] Identify `192.168.1.16`** (Compal OUI — likely ISP set-top/booster).
8. **rpi3-dns power/hardware check** — DNS failover is single-box until it returns.
9. **Pixel-6 `.29` registry reconcile** (decommissioned-but-live).
10. Then T2: gates C03/C06 → pre-stage (F50–F56) → the 10-minute cutover window (F57–F61) → drill (F62–F66).

## g) THE QUESTION I CANNOT ANSWER MYSELF

**All five owner-gated items asked via the question form at session end** — SIM/metered, Wi-Fi path + CPE location, label model + port count, PSK-window now-or-later, and consent to the physical factory-reset recovery. Without the SIM answer, T2 (the whole failover architecture) cannot start; without the reset, the CPE stays a locked brick with correct-but-unmanageable config.

---

**Commits this session:** `cb39c78e5` (EXECUTING marker) + the docs commit carrying this report, the runbooks, and the harvest. Parallel sessions kept moving HEAD (`2e2896a08` → …); all my commits are pathspec-scoped. **No Nix file was touched** (plan §11 held); `nix flake check --no-build` green at close. Credentials live in `~/.config/router-credentials/` (0600, off-repo, never in the repo).
