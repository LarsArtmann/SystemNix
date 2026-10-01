# Status: NetBird P0 fixes, first pbx deploys, dex crash + ACME/DNS recovery

**Session window:** 2026-09-30 ~05:50–07:47 CEST · **Host:** evo-x2 (agent) / pbx (owner deploys)
**Scope:** this session's run only — the pbx-artmann/SystemNix P0 fix batch, the owner's two
pbx deploys (03:44 switch, 05:22 test), the dex + ACME incident diagnosis and DNS repair.
The evo-x2 Phase-1 deploy race + recovery is OWNED by
`2026-09-30_07-19_cert-mint-deploy-race-recovery-status.md` (deployed green 07:00, system-805).

Root docs: `docs/status/2026-09-30_05-42_netbird-cloud-rollout-status-self-review.md` (+ its §h
addendum), pbx `docs/runbooks/netbird-deploy.md`.

---

## a) FULLY DONE (verified this session)

| #  | Item                                                                                                                                                                                                                                                                                                               | Evidence                                                                                                                                                                       |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1  | **dex crash root-caused from module source**: nixpkgs dex unit = DynamicUser + ProtectSystem=strict + NO StateDirectory → sqlite at /var/lib/dex unopenable ("unable to open database file", exit 2 at 03:44 deploy)                                                                                               | pinned module source read; fix `StateDirectory = "dex"` in hosts/pbx/netbird.nix                                                                                               |
| 2  | **All §d/§f P0 items 1–9 fixed**: dex StateDirectory; real UUID `d9022bfd-…`; `/auth/*` glob dropped; relay vhost 1d timeouts + socket keepalive; `pbx-alert@` onFailure on dex/signal/relay; `Relay`/`Stuns` management.json shape VERIFIED against netbird v0.79.0 source (was CORRECT — non-defect, now pinned) | pbx-artmann commits (daemon-swept, owner-pushed); see CHANGELOG 2026-09-30 section 2                                                                                           |
| 3  | **`checks.x86_64-linux.netbird-contract`** — 9 eval invariants pinning every fix above against the evaluated config                                                                                                                                                                                                | eval green; built green; FEATURES/README counts 14→15 (docs-numbers gate green)                                                                                                |
| 4  | **SystemNix mint unit: TWO runtime kills fixed** — absolute store paths AND `RuntimeDirectory` (ReadWritePaths on a dir nothing creates dies at NAMESPACE setup, 226/NAMESPACE, before any script line)                                                                                                            | my edit landed as `d22ccd48`; **validated in production**: the 05:50 evo-x2 deploy (pre-fix rev `10602885`) failed with exactly 226/NAMESPACE; the 07:00 redeploy minted green |
| 5  | **`checks.caddy-mint` VM test** — runs the REAL mint unit → caddy start chain, output modes, dual-zone SANs, CA-chain, key pairing, real TLS handshakes on both zones                                                                                                                                              | failed twice before the fixes (co-import surface, then the NAMESPACE bug), passes green after                                                                                  |
| 6  | oauth2-proxy cloudDomain existence guard (symmetry with caddy.nix)                                                                                                                                                                                                                                                 | `nix flake check --no-build` green; `checks.cloud-domain` rebuilt green                                                                                                        |
| 7  | **Full gates, both repos**: SystemNix flake check + buildflow format green; pbx full buildflow **exit 0** — incl. format-safety after fixing my stale dprint table padding (devShell dprint 0.57.4; buildflow defers dprint to repo treefmt config) and nixfmt drift on my .nix edits                              | buildflow exit 0; pbx toplevel closure green                                                                                                                                   |
| 8  | **`mail.artmann.tech` DNS root cause + fix**: the record NEVER existed → LE validation NXDOMAIN → lego exit 10 → `acme-order-renew-mail` restart loop. A record → 46.62.241.133 added via targeted terraform apply, verified at API (`dns-prune --list`) + registrar NS + 1.1.1.1                                  | domains repo artmann.tech.tf + CHANGELOG                                                                                                                                       |
| 9  | **All three certs now Let's Encrypt** (mail/netbird/relay — verified live, issuer CN=YE2); DNS for all three names resolves publicly                                                                                                                                                                               | openssl s_client from evo-x2, 05:40                                                                                                                                            |
| 10 | Docs: CHANGELOGs (SystemNix/pbx/domains), AGENTS NAMESPACE+absolute-path gotchas, net-vpn runbook exact sops snippet, pbx runbook redeploy + incident section, status §h addendum; push-secrets.sh host hardcode → `root@pbx.artmann.tech`                                                                         | files committed (daemon), pbx+SystemNix pushed by owner                                                                                                                        |
| 11 | dex started manually on pbx (owner ran `systemctl start dex`) — NOT in the failed list afterward                                                                                                                                                                                                                   | owner ssh transcript 05:33                                                                                                                                                     |

## b) PARTIALLY DONE

| # | Item                                                                                                                                                                                                                                                                                                                                                                                                                              | What's missing / why it stopped                                                                                                                                                                                                                                       |
| - | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **pbx redeploy**                                                                                                                                                                                                                                                                                                                                                                                                                  | `nixos-rebuild test` at 05:22 activated the fixes (nginx restarted with relay timeouts; dex unit file updated) but `switch` NOT yet run — boot config unpersisted, and dex needed the manual start (test does not start previously-failed units; now in the runbook). |
| 2 | **netbird-management + stalwart FAILED on the box** as of the owner's last look (05:35), cause UNKNOWN — no journals read yet (agent has no SSH to pbx by policy). Suspicion for stalwart: the mail-cert issuance postRun `try-restart stalwart` hit an untested restart path (LoadCredential snapshot). Management failure unexplained — it ran 03:44→~05:3x; candidates: IdP interaction now dex is up, or nginx reload timing. | needs `journalctl` from the owner (§f1–3).                                                                                                                                                                                                                            |
| 3 | **`pbx-alert@` relay failed on its FIRST real fire** (paged for netbird-management and itself failed) — the alert path has never been exercised end-to-end; journal-only-by-design until its optional webhook exists, but "failed" state means even the logging shape is broken.                                                                                                                                                  | needs journal + a fix; blocks trust in every onFailure wiring done yesterday.                                                                                                                                                                                         |
| 4 | Dashboard login E2E                                                                                                                                                                                                                                                                                                                                                                                                               | dex up (not failed) but `/dex/healthz`, the OIDC round-trip, and the first login are unverified — the path-proxy seam is still runtime-untested.                                                                                                                      |
| 5 | evo-x2 Phase-1 post-deploy ladder                                                                                                                                                                                                                                                                                                                                                                                                 | deploy green + mint verified (parallel session); the net-vpn.md ladder steps (dig @127.0.0.1 for cloud zone, s_client SANs, curl --resolve) not yet re-run as a documented sweep by this thread.                                                                      |

## c) NOT STARTED

- Setup key → sops `netbird.yaml` → `services.netbird-client.enable = true` → evo-x2 enrollment (§f chain from the 05-42 report, items 14–28)
- Dashboard one-time config: route approval (192.168.1.0/24), DNS nameserver group, ACL review
- Client enrollment: MacBook + Motorola (CA import), burn-in, Tailscale retirement
- Gatus checks for netbird surfaces; pbx backup extension (netbird state + dex db); RAM headroom measurement
- Mail go-live phase (port-25 request, MX/SPF/DKIM/DMARC terraform — NB: uncommitted `dmarc_rua` edits appeared in the domains tree from another actor)
- TODO_LIST harvest of the 05-42 report's §f (still open, item 41 there)

## d) TOTALLY FUCKED UP

1. **My "FORMAT-SAFETY-GREEN" was a pipe-status artifact.** `nix build … | grep | tail && echo`
   reported tail's rc=0, not the build's. The check was FAILING (nixfmt arm) while I claimed
   green; only buildflow's persistence exposed it. Severity: process — a false-green claim is
   worse than a red one. Fix applied everywhere: `if nix build …; then` or `set -o pipefail`.
2. **Two rounds of "should work now" handovers that each surfaced a NEW failure**
   (dex crash → ACME NXDOMAIN loop → management/stalwart failures). I verified MY fixes'
   layers, not the system's steady state after them — success paths have blast radius too
   (cert issuance → postRun restarts → stalwart). No whole-system sweep was in my handover.
3. **The mail NXDOMAIN was visible before the first deploy and I missed it.** At 04:20 I
   probed the placeholder issuer and chased only netbird/relay retry; the acme-mail order
   unit was failing the whole time. A one-line `for d in …; dig` preflight over every
   cert name the box orders would have caught it pre-deploy.
4. **The alert relay was wired everywhere but never once test-fired** — its first real
   activation failed. Until fixed+drilled, ALL onFailure wiring from yesterday is decorative.
5. (Carried from 05-42 §d, now closed but worth naming:) the mint unit shipped with TWO
   runtime-fatal defects while being praised as fail-closed — confirmed live at 05:50 by
   the pre-fix deploy failing exactly as the VM test predicted.

## e) WHAT WE SHOULD IMPROVE

1. **Exit-code discipline** — never derive "green" from a pipeline tail; check the command's
   own rc (`if cmd; then` / pipefail). One false-green costs more trust than ten reds.
2. **Deploy handovers need a steady-state sweep**: after any deploy that changes TLS/ACME,
   enumerate what issuance SUCCESS triggers (postRun restarts) and verify those units too.
3. **ACME name preflight**: before a deploy that orders certs, resolve EVERY name at a
   public resolver; one bash loop, prevents the whole NXDOMAIN class.
4. **Alert paths need a drill** — an alerting unit that has never fired is an untested
   feature; add a `systemctl start pbx-alert@test` ritual (or VM test) to the runbook.
5. **`nixos-rebuild test` does not start previously-failed units** — new operator gotcha,
   now in the pbx runbook; consider adding to pbx AGENTS.md too.
6. **Parallel-session awareness**: writing this report required reading sibling reports
   (07:19/07:42) to not contradict deployed reality — status reports should cross-link
   their thread's siblings (done here) so the next session inherits the full picture.

## f) NEXT — ordered

**P0 — live box diagnosis (owner ssh, paste back):**

1. `journalctl -u netbird-management -n 60 --no-pager` (why did it die ~05:3x?)
2. `journalctl -u stalwart -n 60 --no-pager` (postRun try-restart after mail-cert issuance?)
3. `journalctl -u 'pbx-alert@*' -n 30 --no-pager` + fix the relay itself (it must not exit failed)
4. `systemctl status dex --no-pager` + `curl -s https://netbird.larsartmann.cloud/dex/healthz`
5. `nixos-rebuild switch --flake .#pbx --target-host root@pbx.artmann.tech` (persist boot config; dex starts at boot)
6. Re-verify the three certs remain LE + renew timers active (`systemctl list-timers 'acme-*'`)
7. First dashboard login (password in `~/.pbx-prod-secrets/netbird_dex_admin_password`) → password manager

**P1 — enrollment chain (from 05-42 §f 14–28):**
8. Create setup key (reusable, 30d) → 9. sops `netbird.yaml` (exact snippet in net-vpn.md) →
10. `services.netbird-client.enable = true` + evo-x2 deploy → 11. post-deploy ladder
(dig/s_client/curl + gatus) → 12. `netbird status` Connected → 13. route approval →
14. DNS nameserver group → 15. ACL review → 16. MacBook → 17. Motorola + CA import →
18. phone-on-LTE E2E → 19. `rels://relay.larsartmann.cloud` in status → 20. burn-in → 21. Tailscale retire

**P2 — hardening:**
22. Gatus checks (management reachability from evo-x2, relay STUN 3479/udp)
23. pbx backup.nix: netbird state + /var/lib/dex
24. RAM headroom check on pbx (telephony+mail+netbird+dex on 4GB)
25. Alert-drill ritual (e5.4) + wire the alert relay's real channel
26. `onFailure` for dex already wired — verify pbx-alert@ actually pages once fixed
27. Backport relay./vpn. decisions into the brainstorming doc (05-42 b7)
28. TODO_LIST harvest of 05-42 §f + this §f (docs-health)
29. Setup-key rotation reminder (30d)
30. pbx IPv6 pinning (blocks relay AAAA)

**P3 — mail phase (separate window):**
31. Hetzner port-25 request (start the clock) → 32. MX/SPF/DKIM/DMARC terraform (coordinate
with the in-flight dmarc_rua edits) → 33. Stalwart admin-over-VPN once mesh is up →
34. parsedmarc → 35. mail go-live runbook

**P4 — strategic (owner):**
36. Apex story for larsartmann.cloud (still → hetzner-0) · 37. evo-x2 workstation/server split ·
38. Pocket ID HA revisit · 39. VPS consolidation review after burn-in · 40. Dex password keep-or-replace

## g) QUESTION I cannot answer myself

**`journalctl -u netbird-management -n 60 --no-pager` (and stalwart's) — may I have the
output?** The agent has no SSH to pbx by repo policy, and the two failed units are the only
blockers between the pbx box and a working dashboard login. Everything else in §f P0 chains
behind them. (Tried: live probes from evo-x2 — DNS/TLS/HTTP all verify green; the failure
reason lives only in the box's journal.)

---

_Report ends. Waiting for instructions._
