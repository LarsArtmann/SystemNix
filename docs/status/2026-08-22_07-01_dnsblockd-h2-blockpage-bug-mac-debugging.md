# Status: dnsblockd HTTPS h2 block-page bug — Mac client debugging session

**Date:** 2026-08-22 07:01 CEST (05:01 UTC)
**Scope:** This session only — user reported `ERR_CERT_DATE_INVALID` testing dnsblockd on a Mac; ended with a production dnsblockd bug found, reproduced, fixed, committed. Includes things noticed along the way, nothing else.
**Actor:** Crush session in `/home/lars/projects/SystemNix` + `/home/lars/projects/dnsblockd`

---

## Executive summary

The Mac's original cert error led through three layers: (1) a real but secondary clock-skew exposure (leaf certs minted with `NotBefore = now`, no backdate), (2) a red herring (`No route to host` caused by evo-x2's **second hard freeze tonight** at 05:49:56, power-cycled 05:55), and (3) the actual production bug: **dnsblockd's TLS-passthrough HTTPS branch closes every HTTP/2 connection immediately after the handshake** — `http.Server.TLSConfig` lacked `h2` in `NextProtos`, so Go's `Serve()` auto-h2 policy (`shouldConfigureHTTP2ForServe`) never installed `TLSNextProto["h2"]` while the listener still advertised h2 via ALPN. Every modern browser (always h2) got `close_notify` + zero response; HTTP/1.1 clients worked fine, which produced a false green on my server-side probes. Fixed in `31cdcae` with a production-wiring regression test; cert backdate fixed in `fa2c5e3`. SystemNix `flake.lock` already pins the fix rev but the **running service is still pre-fix v0.7.0 (`07173f8`)** — one deploy short of done.

---

## Timeline (CEST)

| Time | Event |
|---|---|
| ~03:30 | User hits `ERR_CERT_DATE_INVALID` on pornhub.com block page (Chrome, HSTS, Mac). Pasted cert: leaf notBefore `03:30:28 UTC`, issuer `dnsblockd-CA` |
| 03:39 | Clocks verified in sync (Mac == evo-x2; sntp offset 84 ms after sync; sntp exchange itself timed out — NTP/UDP 123 blocked somewhere, unexplained) |
| ~03:40 | User imports dnsblockd-CA into macOS system keychain. `curl -vk https://pornhub.com` → `No route to host` to 192.168.1.200 |
| 03:41–05:49 | Server-side checks all green (listeners on `.200:80/:443`, eno1 up, no kernel NIC events, no VRRP flap, ARP healthy) — no server-side trace of the Mac's failure |
| 05:49:56 | **Boot `-1` journal stops dead** (buildcache USB device-job timeout, no shutdown sequence) — freeze #2 tonight; power-cycled 05:55 (boot `0`) |
| 05:55+ | Post-reboot: DAS (all 4 external disks incl. buildcache SSD + pool Toshibas) **never enumerates** — `/proc/partitions` shows only NVMe+zram; `/mnt/buildcache` accesses hang/ENODEV (idle autofs + dead device job) |
| ~06:30 | dnsblockd restarted several times by concurrent deploys; healthy |
| 06:40 | Journal: `rendering block page: context canceled` at the exact second of the Mac's request; Chrome `unknown certificate` probes around it |
| ~06:44 | Mac `curl -vk https://www.pornhub.com`: **TLS handshake OK, cert presented, then `close_notify` + `(16) HTTP2 framing layer`** — network resolved itself post-reboot; h2-specific failure isolated |
| 06:45–06:53 | Root cause found in `server.go` + go1.26.6 `net/http` source; regression test written (failed `unexpected EOF` pre-fix), one-line fix applied, full dnsblockd suite green (`GOCACHE=/tmp/...` — buildcache dead) |
| 06:53 | Concurrent session deploys; running dnsblockd = v0.7.0 `07173f8` (**pre-fix**) |
| 06:59:27 | Auto-commit daemon commits my h2 fix as `31cdcae` (backdate rode earlier as `fa2c5e3`; other session's batch_writer fix as `67769ef`) |
| 07:01 | SystemNix `flake.lock` (uncommitted) pins dnsblockd → `31cdcae` (the fix). Deploy pending |

---

## a) FULLY DONE

1. **Root-caused the Mac's HTTPS block-page failure** — h2 ALPN bug in dnsblockd's TLS-passthrough branch (`internal/server/server.go`). Mechanism verified against go1.26.6 stdlib source (`shouldConfigureHTTP2ForServe`: `Serve()` only auto-configures h2 when the `http.Server`'s OWN `TLSConfig` lists `h2`; the bare cert-cache config didn't, while the listener copy did advertise it).
2. **Fixed it**: `TLSConfig: blockPageTLSConfig(s.certCache)` — one line + comment (`31cdcae`).
3. **Regression test against production wiring** (`TestPassthrough_HTTP2BlockedSNIGetsBlockPage`, real `New()` + `startHTTPS` + `ForceAttemptHTTP2` client): pre-fix `unexpected EOF` (server twin of the Mac's curl error), post-fix `HTTP/2.0` + body (`b611568` + fix commit).
4. **Clock-skew hardening**: leaf cert `NotBefore` backdated 1h (`fa2c5e3`) + test asserting backdate and ~1y validity.
5. **Full dnsblockd test suite green** post-fix (`go test ./...`), build + vet green.
6. **Server-side infrastructure ruled out with evidence**: listeners, eno1/ARP, kernel log, VRRP/failover config, s_client handshake + served cert/chain/SANs, HTTP/1.1 block-page 200 + CSP.
7. **Freeze #2 detected and documented** (boot `-1` ends 05:49:56 mid device-wait; corroborates the other session's "second freeze" commits).
8. **DAS-absence diagnosed**: not a zombie mount — whole enclosure electrically invisible on buses 7/8; recovery is physical (enclosure power-cycle), auto-recovery stack (`buildcache-usb-recovery`, udev) will do the rest once hardware returns.
9. **User-side steps delivered and executed**: clock verify, CA import into macOS system keychain, curl probes.
10. **Concurrent sessions flagged, not touched**: SystemNix (memory-emergency-guard/system-health deploys), dnsblockd (batch_writer.go flush fix `67769ef`).

## b) PARTIALLY DONE

1. **End-to-end Mac verification** — server-side fix proven by test; the Mac still runs pre-fix service. Chrome Cmd+Q + retest pending after deploy.
2. **Deployment** — fix committed, `flake.lock` bumped to fix rev (`31cdcae`, uncommitted), but `nix run .#deploy` NOT run; running binary still `07173f8`.
3. **dnsblockd release hygiene** — v0.7.0 tag exists but predates both fixes; no v0.7.1 tag, no CHANGELOG entries for my two fixes (the other session owns the current CHANGELOG roll).

## c) NOT STARTED

1. Tag + push dnsblockd (v0.7.1) — needs explicit user approval.
2. Committing the SystemNix `flake.lock` bump (daemon may batch it).
3. Deploy + post-deploy verification (h2 block page from a LAN client).
4. DAS enclosure power-cycle (physical, user) + pool/buildcache recovery verification.
5. Gatus check covering the **HTTPS h2 block page** (current "DNS Blocker" check probes the stats HTTP surface — the actual user path was unmonitored; the system cert pool already trusts dnsblockd-CA, so it's feasible).
6. `post-deploy-check.sh` block-page smoke with `curl --http2`.
7. AGENTS.md gotcha entries (SystemNix + dnsblockd) for the two lessons below.
8. buildcache cleanup: `/tmp/dnsblockd-go-cache`, restore normal `GOCACHE` once mount returns.

## d) TOTALLY FUCKED UP

1. **False-green verification, twice.** My server-side probes used `openssl s_client` WITHOUT `-alpn h2` — HTTP/1.1 only. I declared "server-side healthy" while the dominant bug was h2-only. This is literally the documented house lesson ("validate smoke-check patterns with the SAME tool the check uses" — the curl `--compressed` / python-redirect gotchas). Cost the user ~2 diagnostic round-trips.
2. **First test wrote against a hand-rolled stack** (`startPassthroughStack`) that silently didn't replicate production wiring — it PASSED pre-fix, testing nothing. Caught it (helper's `http.Server` had `TLSConfig == nil` → auto-h2 on), rewrote against real `startHTTPS`. Nearly shipped a green-but-useless regression test.
3. **Round-1 overconfidence**: clock skew presented as the primary theory on first response without server-side evidence; it was real-but-secondary (no backdate is a genuine defect, but the Mac's clocks turned out synced; the original `ERR_CERT_DATE_INVALID` trigger is now unprovable — most likely brief pre-sync skew).

## e) WHAT WE SHOULD IMPROVE

1. **Mirror the failing client's protocol stack in every probe** — ALPN/h2 for anything browser-facing. `curl --http2` or `s_client -alpn h2`, never bare.
2. **Regression tests must exercise production wiring** — real constructors (`New` + `startHTTPS`), not re-assembled approximations; helpers that re-wire are where regression tests go to lie.
3. **Monitor the user path, not the admin path** — Gatus green on the stats port while browsers got connection-reset is the phantom-green class again (third sighting this week).
4. **Cert hygiene**: any on-the-fly minted cert should backdate `NotBefore` (now done) — consider the same audit for other LarsArtmann TLS code.
5. **Diagnose in evidence order** — request `curl -v` output (protocol-visible) before theorizing about clocks/CAs.
6. **Fleet audit**: grep other LarsArtmann Go services for the `Serve(customListener)` + separate-listener-TLSConfig pattern (same stdlib trap).

## f) Next up to 50 (session-scoped, impact-sorted)

**P0 — close the loop**
1. Deploy: `nix run .#deploy` (flake.lock already pins `31cdcae`) — or wait for the concurrent session's next deploy to carry it.
2. Mac: Cmd+Q Chrome → `https://pornhub.com` → expect dnsblockd block page; confirm h2 in DevTools Protocol column.
3. Verify journal: no more `rendering block page: context canceled` / `unknown certificate` from the Mac.
4. Physical: power-cycle DAS enclosure; watch `journalctl -kf | grep -E "usb [78]-|sd[a-e]"`.
5. After enclosure return: verify `buildcache-usb-recovery` ran, `/mnt/pool` mounted, both Toshibas enumerated.
6. If Toshiba #2 still absent: `mount -o degraded` is a USER decision (never automate).
7. Confirm freeze #2 root-cause work (other session) covers 05:49; if freezes recur tonight, escalate to hardware (PSU/RAM/BIOS).
8. Commit SystemNix flake.lock bump if the daemon hasn't.

**P1 — prevention**
9. Gatus: HTTPS+h2 block-page endpoint check (CA already in system pool) — kills the phantom-green class for this path.
10. `post-deploy-check.sh`: `curl --http2` block-page smoke (DNS-resolved blocked domain or `--resolve` to `.200`).
11. dnsblockd: h2 test for the NON-passthrough `ListenAndServeTLS` branch (belt+braces; believed correct via `setupHTTP2_ServeTLS`).
12. dnsblockd: CHANGELOG entries for `fa2c5e3` + `31cdcae`; tag v0.7.1; push (user approval).
13. SystemNix AGENTS.md gotcha: "server-side TLS probes must negotiate the client's ALPN (h2)".
14. dnsblockd AGENTS.md: "passthrough/h2 tests must use production wiring (`startHTTPS`), not hand-rolled stacks".
15. Fleet grep for `Serve(` + custom TLS listener pattern in other LarsArtmann repos.
16. Investigate the NTP/UDP-123 timeout on the Mac's LAN segment (sntp exchange failed while offset eventually resolved).
17. Investigate dnsblockd forwarder timeouts (`dial tcp 9.9.9.9:853: i/o timeout` — iroh.link TXT query burst at 06:32) — resilience + query-storm angle.
18. Watch `TRACK_METRICS` dispatch errors after the other session's batch_writer fix deploys.
19. VM/e2e test in SystemNix (`tests/`) exercising the h2 block page end-to-end (if a dnsblockd VM test exists, extend; else note as new).
20. Consider a LAN NTP anchor (evo-x2 serving time) to kill the clock-skew class for all clients.

**P2 — hygiene & follow-up**
21. Firefox on the Mac uses its own cert store — import CA there too if it's a test browser.
22. Document Mac-as-dnsblockd-client trust steps in dnsblockd `deploy/` docs.
23. Purge `/tmp/dnsblockd-go-cache` after buildcache returns; confirm no env-less process re-created `~/.cache/go-build` on NVMe.
24. Re-check `dnsblockd-ca.pem` in `~/Downloads` on the Mac (delete after trust is confirmed).
25. Verify the two `chrome-error://chromewebdata/` console lines vanish post-fix (they were symptoms, not a bug).
26. Add served-chain assertion (leaf+CA both sent) to the h2 test — was observed true in the paste, untested.
27. Consider 24h backdate instead of 1h (browsers tolerate; marginal benefit — probably keep 1h).
28. Audit dnsblockd cert-cache eviction under h2 connection reuse (no change expected).
29. Reconcile this report into TODO_LIST via docs-health HARVEST (user instruction pending — see questions).
30. Ask the other dnsblockd session to coordinate on the v0.7.1 tag content (their SSE/dashboard fixes + mine).

## g) Questions I cannot answer myself

1. **Deploy + release authority**: Shall I run `nix run .#deploy` now (flake.lock already pins the fix), and do you want dnsblockd tagged `v0.7.1` + pushed — coordinate-first with the concurrent session that owns the v0.7.0 release state?
2. **DAS recovery window**: When will you physically power-cycle the enclosure (pool + buildcache ride on it), and if Toshiba #2 stays dead after it, do you want the pool mounted `degraded`?
3. **Clock class**: Accept the 1h cert backdate as the whole fix for `ERR_CERT_DATE_INVALID` (original trigger unprovable — Mac clock pre-sync state is gone), or stand up a LAN NTP anchor on evo-x2 so clients can't drift in the first place?

---

## Appendix — key evidence

- Mac curl (06:44): TLS 1.3 OK → request sent → `TLSv1.3 (IN), TLS alert, close notify` → `curl: (16) Error in the HTTP2 framing layer`.
- dnsblockd journal 06:40:28: `level=ERROR msg="rendering block page" error="context canceled"` (client IP 192.168.1.62 = the Mac).
- go1.26.6 `net/http/server.go:3385`: `shouldConfigureHTTP2ForServe` returns `slices.Contains(s.TLSConfig.NextProtos, "h2")` when `TLSConfig != nil`.
- Pre-fix prod-wiring test: `Get "https://blocked.example.net/": unexpected EOF`. Post-fix: `HTTP/2.0` + body.
- Boot `-1` ends 05:49:56 on `dev-disk-by-id-ata-SanDisk...device/start timed out`; boot `0` at 05:55:36; `/proc/partitions` (07:00) = NVMe + zram only.
- Served leaf (04:38:30 mint): `subject=O=dnsblockd, CN=pornhub.com`, SANs `pornhub.com, *.pornhub.com`, chain includes CA (10y, RSA 4096).
