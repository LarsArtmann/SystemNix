# NetBird evo-x2↔pbx: enrollment NEVER ran — root cause found, fix staged, deploy gate-blocked

**Session:** 2026-10-10 ~12:50–13:45 CEST · **Repo:** SystemNix (evo-x2 side; pbx-artmann read-only research)
**Trigger:** owner asked "how are we doing on connecting them via netbird?"
**Headline:** The mesh is NOT connected and never was. The control plane (pbx) is fully live; the
evo-x2 daemon runs but has been sitting credential-less since the 2026-10-06 phase-2 flip, because
the enrollment oneshot `netbird-evox2-login.service` has **never executed once** — systemd 261.3
never queues it from `netbird-evox2.service.wants/`, and the failure is **silent** (manager-level
skips are debug-logged). Root cause diagnosed live; fix landed in the tree and the module half is
already active; the final step (starting the oneshot) is blocked behind the memory-guard deploy
gate, not behind anything technical.

---

## The actual live state (all probed this session, nothing from docs alone)

| Surface | State | Evidence |
| --- | --- | --- |
| pbx control plane | **LIVE** (management/signal/relay/dex/nginx, LE certs) | runbooks + Gatus group "NetBird Control Plane" checks green (dashboard 200, /api/peers 401, /dex/healthz 200, relay 404) |
| evo-x2 daemon | **RUNNING but NOT logged in** | PID 2065 since Oct 7 11:05 boot, netbird 0.80.0; every login attempt: `PermissionDenied: no peer auth method provided, please use a setup key or interactive SSO login` (journal, all boots since Oct 7) |
| WireGuard/VPN interface | **ABSENT** | `/sys/class/net`: docker0, eno1, lo, wlan0 only |
| Enrollment oneshot | **NEVER RAN — zero journal entries, ever** | `journalctl -u netbird-evox2-login` → "No entries" across all 5 retained boots; ActiveState=inactive, LoadState=loaded |
| Setup key | minted 2026-10-06 14:48 on pbx (30d ⇒ valid to ~2026-11-05), sops file tracked + rendered at boot | `git ls-files platforms/nixos/secrets/netbird.yaml` OK; unit LoadCredential points at `/run/secrets/netbird_setup_key` |
| DNS prereqs | OK | `dig @127.0.0.1 netbird/relay.larsartmann.cloud` → 46.62.241.133 |

**So the honest answer to "how are we doing": pbx side done for 10 days; evo-x2 side has been
silently dead-on-arrival since the flip, and every doc/TODO that implies enrollment succeeded or
was "automatic" is describing intent, not state.**

---

## a) FULLY DONE (this session)

1. **End-to-end live-state verification of both sides** — daemon, ports, DNS, unit files, booted
   generation contents, sops file tracking, journal forensics across all retained boots.
2. **Root cause isolation (the session's core find):**
   - The oneshot is correctly *wired*: present in the booted generation (gen 834 `w230ajy8…`
     verified by direct store listing), symlinked in `netbird-evox2.service.wants/`, unit loads,
     `CanStart=true`, zero Conditions (`Conditions a(sbbsi) 0`), and the running systemd's
     `Wants` property on the parent **includes** `netbird-evox2-login.service`.
   - And yet systemd 261.3 never enqueued it — across 4+ boots where the parent started cleanly.
     Sibling units enabled the same way but shaped `Before=<parent>` (cv-oidc-env,
     dnsblockd-oidc-secret, cv-state-perms) all start fine at boot
     (journal-proven 11:05:47–51). The distinguishing feature of the login unit: it is wanted by
     the parent AND `Requires=`+`After=` the parent back (nixpkgs netbird module's own shape).
   - **Silence mechanism:** in systemd 261 manager-level skip/queue decisions for this path are
     debug-level → zero journal footprint → nobody noticed for 4 days. `ConditionResult=false`
     with 0 conditions = "never evaluated", a red herring until probed.
   - Ruled out: stale generation (booted gen had everything), masking/runtime overrides
     (`/run/systemd/system` clean), polkit/permissions, conditions, start-limit.
3. **Fix #1 (module):** `modules/nixos/services/netbird.nix` now sets
   `systemd.services."netbird-evox2-login".wantedBy = [ "multi-user.target" ]` — direct
   boot-time enqueue, semantics-preserving (its own Requires/After still order it behind the
   daemon; script is NeedsLogin-guarded/idempotent). **Already ACTIVE on the live system** — the
   parallel session's 13:14 deploy carried it (verified: symlink now present in
   `multi-user.target.wants/`).
4. **Fix #2 (deploy converger):** `scripts/deploy.sh` restarts the oneshot at every deploy.
   v1 (gated loop) was empirically skipped mid-switch — `systemctl is-enabled --quiet` returned
   rc=1 during the switch window while the identical query returns `enabled`/rc=0 once settled
   (both directions journal/log-proven today). v2 moved it to the **unconditional explicit
   restart block** (exact crush-hot-db-migrate precedent, whose comment already documented this
   is-enabled flake class for indirectly-pulled units).
5. **Verification pipeline:** `nix flake check --no-build` all green; eval-probed
   `wantedBy = ["netbird-evox2.service","multi-user.target"]`; `bash -n` on deploy.sh.
6. Tree state pinned throughout (multi-agent discipline): my two edits are now daemon-committed
   (`84cd8a45`, `638270cc`); the 13:37 deploy log confirms it evaluated tree `84cd8a4`.

## b) PARTIALLY DONE

1. **The deploy that starts enrollment** — my 13:37 run passed ALL pre-deploy checks
   (77 pass / 0 fail) but **aborted at the guard-trip-recency gate**:
   `memory-emergency-guard tripped 1× in the last 60 min — episodic IO-storm window
   (freeze #5 class)`. Deploy exited before switching ⇒ the explicit netbird restart in
   deploy.sh has **never executed**. Fix is staged, not fired.
2. **Docs/TODO truth-up** — NOT started before the interrupt (see c): net-vpn.md's
   "enrollment is automatic / DONE" claims and three stale `blocked:deploy` rows in
   docs/todo/services.md + TODO_LIST.md queue rows all predate this finding.

## c) NOT STARTED

1. Actual enrollment execution (oneshot first-ever run) + its verification battery:
   `: Connected` in daemon journal, VPN interface appears, tunnel DNS via 192.168.1.53.
2. pbx-side post-enrollment convergence: provisioner's next ≤30-min run must create the network
   router (evo-x2 routing peer, masquerade) and print "converged" — the 2026-10-06 run ended
   "router deferred" because no peer existed.
3. `/api/peers` listing evo-x2 (owner-ssh on pbx).
4. MacBook + phone enrollment, Tailscale retirement, exit-node option (owner steps, phase-2 §7-9).
5. Docs/TODO surface corrections (§b.2 above + this report's self-harvest, §f).

## d) TOTALLY FUCKED UP

- Nothing destructive; no wrong switch, no data touched, both repos intact.
- Honest misses, self-caught: (1) my first journal pass used `-u` filtering, which cannot see
  manager-level messages — the "zero entries" conclusion was right but I nearly missed *why*;
  (2) I watched the wrong deploy PID twice (nix-run wrapper vs bash child) burning ~10 min of
  poll loops; (3) deploy.sh v1 put the unit in the **gated** loop although the file's own
  crush-hot-db-migrate comment already documented the is-enabled mid-switch flake for exactly
  this indirect-pull shape — I should have read the precedent comment before choosing the wiring,
  not after empirically losing a 21-minute deploy cycle to it; (4) I launched a deploy without
  pre-checking the memory-guard trip window (the deploy caught it, as designed, but I could have
  pre-read it).

## e) WHAT WE SHOULD IMPROVE (systemic, observed this session)

1. **"Automatic enrollment" was never instrumented.** For 4 days the only failure signal would
   have been the daemon's PermissionDenied line — nothing watches `netbird-evox2-login.service`
   state. The integration registry entry monitors the *daemon*, not *enrollment*. A gatus/unit
   check or post-deploy assert on login-unit result would have caught this on day one.
2. **systemd 261 silent-skip class:** any unit whose only pull-in is
   `<parent>.wants/` + `Requires=/After=` back on the parent is a potential silent never-runs.
   We have a lint for unit *shapes* (systemd-shape-audit); this is a new eval-time check
   candidate: flag oneshots enqueued solely via a parent's wants with a Requires-back edge, or
   force the multi-user enqueue in the wrapper.
3. **Close-out honesty rule already on the books was violated by the 2026-10-06 close-outs**:
   "assert WHICH entity served it" / "a verification close-out must answer the question the item
   ASKED". The phase-2 flip was closed as done off daemon-starts, not off an enrollment probe.
4. **Deploy converger `is-enabled` gate** silently skips indirect-pull units mid-switch — the
   crush-hot-db-migrate comment documented it in prose; it should be lint-enforced (explicit
   block required for units not `WantedBy=` a target) or the loop should tolerate rc=1 with a
   logged reason.
5. **Parallel-session visibility:** three deploys contended on the lock in 20 min; a foreign
   `M scripts/post-deploy-check.sh` sat uncommitted in the tree during my deploy. The lock
   handled it correctly, but the 13:14 deploy (not mine) shipped MY uncommitted edits — correct
   by shared-tree policy, worth remembering when reading its exit-3 report.

## f) NEXT (up to 50, ordered; owner = needs you, agent = dispatchable)

**Enrollment closure (P0):**
1. [owner-choice] Fire enrollment: EITHER `sudo systemctl restart netbird-evox2-login.service`
   in your terminal (5 seconds, no deploy — my polkit blocks it) OR wait out the 60-min
   trip-free window and `nix run .#deploy` (also exercises the new explicit converger block).
2. [agent] Watch the oneshot journal: Expect `netbird up` → daemon `: Connected` (or a clean
   key-rejection if the sops key went stale — the journal names it).
3. [agent] Verify VPN interface appears (`/sys/class/net`), tunnel DNS
   `dig @100.x/192.168.1.53 home.lan` per net-vpn.md §verification.
4. [owner-ssh] pbx: confirm `/api/peers` lists evo-x2; `systemctl start netbird-provision.service`
   rather than waiting ≤30 min; expect "converged" + network router created (masquerade on).
5. [agent] Gatus "NetBird Control Plane" group eyeball post-enrollment.

**Truth-up (P1, mine, pending):**
6. [agent] net-vpn.md: correct "DONE 2026-10-06 … enrollment is automatic" with the real
   timeline (daemon-fixed ≠ enrolled) + add the systemd-261 wants-never-queues gotcha + the
   is-enabled converger flake.
7. [agent] docs/todo/services.md: close/rewrite the three stale rows
   ("DEPLOY the ManagementUrl fix…verify enrollment", "Deploy evo-x2 (netbird client flip) once
   IO PSI…", "Post-flip verify: provisioner converged incl. router") — enrollment verification
   still open, deploy/flip themselves done.
8. [agent] TODO_LIST.md queue: prune/align the mirrored rows (§7) so queue and library don't
   drift (surface-rule).
9. [agent] docs/agents/systemd.md: add the "wants-dir + Requires-back never queues (systemd
   261, silent/debug-logged)" lesson next to the boot-mirror/journal forensics material.
10. [agent] This report's §f self-harvest into TODO_LIST.md once items 6-9 land.

**Hardening the class (P2):**
11. [agent] Eval-time or pre-deploy check: enrollment-critical oneshots must have a success
    witness (unit result probed post-deploy; post-deploy-check.sh already has a §-structure to
    hang it on — coordinate: that file is currently dirty from a parallel session).
12. [agent] systemd-shape-audit extension: warn on `wantedBy = [<service>]` +
    `Requires=<same service>` oneshots (the never-queued shape) — negative-test per repo doctrine.
13. [agent] Consider upstream nixpkgs issue: netbird module login unit shape vs systemd 261
    queue behavior (gate through verify-before-filing + github-voice; the upstream todo row for
    the ManagementUrl bug already exists as a model).
14. [agent] deploy.sh: emit a WARN line when a converger-list name is skipped by is-enabled so
    the flake is at least visible in deploy logs.

**Parallel-session flags (not mine, observed):**
15. [owner] 13:14 deploy exited 3 with NEW smoke failures: `emeet-pixyd.home.lan → auth gateway
    broken` + journal-rate regressions (node-exporter 345/min, discordsync 619/min) +
    discordsync CPU 103% — under storm mode (io PSI avg60 32.5%). Needs the owning session.
16. [owner] Manual tq pool double-run guard tripped (`/tmp/tq-test-build … :18091`) — cutover
    per docs/services/tq.md before relying on the systemd pool.
17. [owner] `M scripts/post-deploy-check.sh` uncommitted in the tree (foreign session).
18. [owner] quickshell-wra core dump 13:18:31; memory-emergency-guard tripped within the last
    hour; many services at MemoryHigh watermark (§17 sweep output in the 13:14 log).

**Phase-2 remainder (owner-gated, after burn-in):**
19. MacBook enrollment mechanism decision (darwin netbird client runtime — decision row exists).
20. Phone enrollment + dnsblockd CA import.
21. rpi3 client (module parameterization row exists, ~1h est. incl. test touchpoints).
22. Tailscale retirement post-burn-in (D6).
23. Exit-node `0.0.0.0/0` for the phone (D5 close-out).
24. Dex→Pocket ID dashboard IdP convergence decision (security.md decision row).
25. sopsFile git-visibility gate (queue row exists — the netbird.yaml near-miss).
26. nixpkgs upstream ManagementUrl string-crash issue filing (upstream.md blocked:push row).

## g) Questions I cannot answer myself

1. **Enrollment trigger:** run `sudo systemctl restart netbird-evox2-login.service` yourself now
   (fastest; the unit is idempotent and staged), or have me wait out the memory-guard window and
   re-run the full deploy? (The guard exists to dodge the freeze #5/#12 class — overriding with
   `DEPLOY_FORCE_PRESSURE=1` is technically possible and I won't choose it for you.)
2. **Parallel ownership:** the 13:14 deploy (exit 3, emeet-pixyd auth-gateway + sanity
   regressions), the manual tq double-pool, and the uncommitted `post-deploy-check.sh` edit
   point at an active second session — is that yours/another agent's in-flight work I should
   keep clear of, and does it own the TODO surfaces I'm scheduled to edit in §f.6-8?
3. **If the oneshot's first run rejects the setup key** (stale sops copy vs a re-minted pbx key —
   the provisioner silently re-mints on expiry): the fetch is an ssh to pbx
   (`ssh root@pbx.artmann.tech cat /var/lib/netbird-provision/setup-key`) + a sops edit +
   redeploy, which is owner-run by pbx policy — want me to queue exactly that as a ready row, or
   will you do it live if the journal shows a key rejection?

---

**Verification commands for whoever fires the next step:**
```bash
journalctl -u netbird-evox2-login -f                      # the oneshot's first-ever lines
journalctl -u netbird-evox2 -n 50 --no-pager              # expect ": Connected"
ls /sys/class/net                                          # expect a new VPN interface
dig @127.0.0.1 netbird.larsartmann.cloud +short           # 46.62.241.133 (unchanged)
ssh root@pbx.artmann.tech 'systemctl start netbird-provision.service'   # owner: router + "converged"
```
