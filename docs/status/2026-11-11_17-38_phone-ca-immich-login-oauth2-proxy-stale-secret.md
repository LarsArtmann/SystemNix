# Phone CA + Immich Login — dnsblockd-CA Distribution, oauth2-proxy Stale-Secret Incident

**Session:** 2026-11-11 ~17:00–17:38 CET (single conversation, interactive help-desk → live incident fix)
**Author:** Crush agent session (evo-x2)

## Scope — what this report VERIFIED vs did NOT verify

**Verified live this session (command/artifact named):**
- `immich.home.lan` server health: `/api/server/ping` → `{"res":"pong"}`, `/api/server/version` → 3.3.6, `/.well-known/immich` → `{"api":{"endpoint":"/api"}}` (openssl s_client probes, 17:1x)
- oauth2-proxy journal (`journalctl -u oauth2-proxy`): phone fresh-login callbacks at 17:26:47 + 17:30:02 → **500, `invalid_client` "Client authentication failed"** at token exchange with Pocket ID; UA Chrome/156 Mobile, source `100.112.80.216` (a NetBird IP — the phone WAS inside the tunnel)
- `pocket-id-provision` 16:50:50 run: every client row reads "Secret file already exists" (no rotation by the provisioner) — `journalctl -u pocket-id-provision --since today`
- Restart timestamps: `systemctl show` → pocket-id ActiveEnter **2026-11-11 16:50:51**, oauth2-proxy was up since **2026-11-10 19:33:48** (pre-restart state)
- sudo available in this session: `sudo -n true` → rc=0 (2026-11-07/11 yolo-session datapoint, re-confirmed)
- oauth2-proxy restarted 17:32:46, OIDC discovery against `auth.home.lan` completed clean, unit active (`journalctl -u oauth2-proxy`)
- dnsblockd-CA extracted from `/etc/ssl/certs/ca-certificates.crt` by SHA-1 fingerprint match against the live sops CA (`6F:CD:55:40:8C:48:1A:69:0D:DC:7E:95:E0:EC:43:FF:44:DE:93:FC`), served on `http://192.168.1.150:18000/`, verified HTTP 200 / 1895 bytes (python urllib)
- Upstream Immich error provenance: `mobile/lib/pages/common/splash_screen.page.dart` `resumeSession()` — "Missing crucial offline login info" fires when `serverUrl`/`serverEndpoint`/`accessToken` were never persisted (subagent research, immich-app/immich#29050 et al.)

**NOT verified (why):**
- **The fix itself** — end-to-end phone login after the 17:32 restart has NOT been retried by the owner yet. The whole repair rests on the hypothesis "disk secret file == Pocket ID DB expectation; only oauth2-proxy's memory was stale". If the phone still 500s, the disk file itself has drifted and the repair is a forced rotation of the `oauth2-proxy` client in Pocket ID.
- Whether **Pocket ID's expected secret actually changed** today at 16:50 and WHO/WHAT changed it (the 16:38 deploy log was not opened; a UI-side client edit is equally possible). Attribution open — see §g.3.
- Whether the **Immich native-OIDC client** (`id: immich`, same `client-secrets/` directory, also read-once-at-start) suffers the same staleness — the phone never got past the forward-auth leg, so this is untested.
- Phone-side state: CA user-store install (owner reported "CA is in the User store" — not independently checkable from here), NetBird enrollment state (phone reached evo-x2 via a `100.112.80.216` NetBird IP, so SOME enrollment is live — but enrollment order/VPN-connected-during-auth state unknown).
- The `http.server 18000` temp server is **STILL RUNNING** (background job, serving `~/.cache/ca-serve/`). Not killed pending owner confirmation of the CA install.

---

## a) FULLY DONE

1. **Root cause of the phone login 500 identified and fixed in-session** — oauth2-proxy held a stale in-memory Pocket ID client secret (process up since 2026-11-10 19:33) while Pocket ID restarted/re-provisioned 2026-11-11 16:50; fresh logins (the phone, no session cookie) hit `invalid_client` → 500 on `/oauth2/callback`. Fix: `sudo systemctl restart oauth2-proxy` at 17:32:46; re-read of the secret + OIDC discovery clean, unit active. Verified at every layer EXCEPT the final user-facing retry (§ Scope).
2. **dnsblockd-CA distribution path for the phone built on the fly** — CA extracted from the world-readable trust bundle by fingerprint match against the live sops CA (no secret exposure), served over LAN HTTP on 18000 with three filename aliases (`dnsblockd-ca.crt`, `dnsblockd_ca_cert`, `ca.crt`), download verified 200/1895 bytes. Owner reported the CA is now in the phone's user store.
3. **Upstream error provenance pinned** — the Immich app's "missing crucial offline login" crash is `resumeSession()` force-logout on unpersisted session keys; it was a SYMPTOM of the oauth2-proxy 500 (login flow died before persistence), not a phone-side TLS/URL/app-version problem.
4. **Server-side Immich health ruled out with evidence** — ping/version/well-known all green from the host; `.well-known/immich` returns proper JSON (the endpoint-resolution failure class from the upstream issues does NOT apply here).
5. **Session-discipline navigation** — sudo-availability probed before relying on it; secret values never displayed or typed into command lines (fingerprint comparison only); live-secret read used for verification without exposure.

## b) PARTIALLY DONE

1. **The phone → Immich login end-to-end** — forward-auth leg repaired (restart), but the **Immich native-OIDC leg is unverified**: if Pocket ID's DB secret changed in today's 16:50 cycle, the `immich` client (same read-once-at-start pattern) can fail the same way one hop later. Owner retry pending.
2. **Phone setup for LAN services** — CA imported (owner-reported), but **NetBird enrollment as a deliberate step is not confirmed** (the phone evidently has SOME NetBird presence — its requests arrived from `100.112.80.216` — yet the CA→enroll→verify sequence from net-vpn.md step 7 / pixel6.md row "Motorola: import dnsblockd CA + enroll" is not walked through or closed).
3. **Per-secret-consumer staleness audit** — identified as needed (all `client-secrets/` consumers read once at start), NOT executed for any consumer beyond oauth2-proxy.
4. **Temp CA server hygiene** — serving, but still running; kill pending owner confirmation (§g.2).

## c) NOT STARTED

1. **Structural fix for the oauth2-proxy stale-secret class** — no systemd ordering/restart wiring between `pocket-id-provision`/`pocket-id.service` restarts and `oauth2-proxy` (nor any other consumer). Today's fix was a manual restart; the class remains one reprovision away from recurrence. → harvested (services.md + queue).
2. **End-to-end auth-flow monitoring** — gatus only probes `/ping` (30s, Gatus UA, verified in journal) and post-deploy checks catch 500s once; a FRESH-LOGIN 500 (broken token exchange) is invisible to every continuous check. → harvested (monitoring.md + queue).
3. **Drift attribution for today's 16:50 Pocket ID cycle** — why the expected oauth2-proxy secret diverged (deploy 2026-11-11_16-38-15.log unopened; possible UI edit) — blocked on §g.3 answer, then one log read.
4. **Permanent CA distribution endpoint** (`ca.home.lan` static vHost idea — existing backlog thought, not a queued row) — the phone needed an ad-hoc HTTP server today.
5. **sops secret permission anomaly** — this agent shell read `/run/secrets/dnsblockd_ca_cert` with openssl rc=0 WITHOUT sudo; prior docs describe the file as root-only 0400. Either the docs are stale or the permission drifted. Not investigated (out of session scope) — flagged as a security-hygiene check.

## d) TOTALLY FUCKED UP (own failures this session, honestly)

1. **Diagnosis ordering was wrong for three round trips.** The real blocker was SERVER-side (oauth2-proxy `invalid_client`) from the start; the journal one grep away. Instead the first three answers steered phone-side micro-causes (URL scheme, browser choice, app version, NetBird DNS theory). The phone-side advice was not *wrong* (the CA genuinely had to go into the user store; Chrome-vs-Firefox matters) but it was not the blocker, and I had the server logs accessible the entire time. Cost: ~3 owner round trips before the owner's own "500 after oauth2-proxy" observation pointed at the right layer. Lesson: for "app X fails to log in" against MY infrastructure, journal-first, client-theory-second.
2. **One verification leg was garbage and I shipped the session on the good one.** The `openssl s_client` probe against the plain-HTTP 18000 server returned empty (TLS handshake against a non-TLS listener); the python urllib leg was the real check. Sloppy probe design in the moment; caught nothing because the other leg covered it.
3. **First answer was impractical** (`scp` a file to a phone) — caught by the owner, cost one round trip.
4. **Nothing was destroyed / no data loss / no secret exposure** — proportionality note: the §d list here is diagnostic slowness, not damage. The single prod mutation (oauth2-proxy restart) was evidence-backed, announced in-flight, and low-risk.

## e) WHAT WE SHOULD IMPROVE

1. **Secret-lifecycle coupling is implicit.** Eight-plus consumers read `client-secrets/*` ONCE at process start; nothing couples their restarts to Pocket ID reprovision/rotation. Make the coupling declarative (ordering, restart trigger, or a freshness gate) instead of "restart the proxy when logins break".
2. **Fresh-login path is unmonitored.** Every auth check in the fleet probes liveness surfaces (`/ping`, sign-in pages). The token-exchange leg — the only leg that touches the secret — has zero continuous coverage. One canary-style check would have caught today's break within 15 minutes of the 16:50 cycle instead of at first human login.
3. **Phone/device enrollment has no runbook.** Today's CA distribution was improvised twice (paste-mangled `sudo cat` one-liner, then ad-hoc HTTP server). net-vpn.md step 7 is one line; the Android specifics (user-store-only, Chrome ignores user CAs, Firefox default browser, screen-lock precondition) live only in this session's chat.
4. **Agent-chat paste is a lossy channel for shell commands.** The owner's paste carried a trailing variation selector (U+FE0E) that mangled the filename twice. Anything I hand to the owner for interactive shells should be paste-safe (single commands, no quote-adjacent unicode, verifiable side effects) — or delivered as a repo script.
5. **"It works on desktop" hid a total fresh-login outage.** Long-lived oauth2-proxy cookies on desktops masked that EVERY fresh auth had been broken since the 16:50 cycle. Resilience lesson: high-traffic surfaces with sticky sessions need canary flows with clean sessions, not just liveness pings.

## f) NEXT — up to 50, impact-sorted (direct follow-ups marked; the rest is brainstorm-grade, no new research behind it)

**Direct follow-ups of THIS session (1–8):**
1. **[HARVESTED → monitoring.md + TODO_LIST]** Continuous end-to-end auth check: a gatus check that walks the oauth2 sign_in → callback/token-exchange path (or a canary OIDC token request against Pocket ID with the oauth2-proxy client) so `invalid_client` 500s page instead of waiting for a human login.
2. **[HARVESTED → services.md + TODO_LIST]** Close the stale-secret class structurally: oauth2-proxy (and the other client-secrets consumers) need restart-on-provision ordering (`pocket-id-provision.service` → `restart`/`reload` of consumers, or ExecStartPre freshness-compare + exit to fail closed), so a Pocket ID cycle can never leave a stale in-memory client secret again.
3. **Verify the fix end-to-end**: owner retries Immich login on the phone; if it 500s again → forced rotation of the `oauth2-proxy` client in Pocket ID (admin) + provisioner re-sync + restart. (Owner-gated; question §g.1.)
4. **Audit all client-secrets consumers for the same staleness** (immich, miniflux, forgejo, paperless, crm, cv, geometrikks, browser-history, opencloud, pim-sync, dnsblockd, monitor365): compare unit ExecMainStartTimestamp vs last pocket-id cycle; restart any predating it. One systemctl/journal sweep.
5. **Attribute the 16:50 drift** (after §g.3): read `/var/log/systemnix-deploys/2026-11-11_16-38-15.log`, determine whether a pocket-id version bump/UI edit changed the expected secret; if a UI edit: identify actor + consider disabling UI-side client edits (provisioner owns OIDC clients).
6. **Kill the 18000 temp server** once the CA install is confirmed (§g.2) — it is still running (background job, `~/.cache/ca-serve/`).
7. **Investigate the sops read-permission anomaly**: `stat /run/secrets/dnsblockd_ca_cert` — expected root-only 0400; an agent shell read it unprivileged. If perms drifted, that's a secrets-hygiene regression; if docs are stale, correct docs/services/dnsblockd.md + secrets docs.
8. **Phone enrollment closure**: walk net-vpn.md step 7 deliberately (enroll state check, split-DNS `auth.home.lan` resolution inside tunnel, relay-vs-direct connection type) and tick/close the pixel6.md Motorola row when done.

**Brainstorm-grade (9–35, no research behind them, ROADMAP/domain-library fuel at most):**
9. Permanent CA distribution: static `ca.home.lan` vHost (or a Caddy response rule on an existing host) serving the dnsblockd CA with a fingerprint footer; kills the ad-hoc-server pattern forever.
10. Phone enrollment runbook page (docs/services/net-vpn.md expansion or docs/agents/): Android CA user-store path, Chrome-ignores-user-CAs caveat, Firefox default browser, screen-lock precondition, Immich app login order, NetBird order-of-operations.
11. net-vpn.md step 7 text update: add "import CA into USER store (system store is not user-writable)" + "use a user-CA-trusting browser for OAuth legs".
12. pocket-id-provision: emit an explicit journal line per client when a secret VALUE changes (today attribution relied on absence-of-rotation lines); consider a `client-secrets-changed` marker file consumers can freshness-check.
13. oauth2-proxy: ExecReload + documented restart procedure in docs/services/oauth2-proxy.md ("stale client secret after Pocket ID reprovision → restart"; today's incident as the example).
14. Post-deploy-check: after a deploy that restarts pocket-id/provision, probe one fresh token exchange (not just vHost 500/502 detection) — closes the deploy-window variant of this class.
15. pocket-id-secret-rotation metrics: extend beyond file-age freshness to a canary token request (pairs with item 1).
16. Verify Chrome-on-Android behavior observed today: the OAuth page LOADED in a Chrome/156 UA despite user-CA-only install (Chrome allegedly ignores user CAs for browsing) — either the UA was a custom tab with different trust behavior or the docs claim needs a truth-up; one phone-side test settles it.
17. Immich app version gate note: server 3.3.6 needs a 3.x app; document in immich.md so the next phone incident skips the version-mismatch class (upstream #29050).
18. Immich dual-leg auth documentation: browser leg (forward-auth) vs app leg (native OIDC) are independent failure domains — immich.md §f row documenting "app login fails but browser works → check oauth2-proxy token exchange first" (today's exact signature).
19. AGENTS.md session-discipline candidate: paste-safe command delivery to interactive owner shells (variation-selector mangling, today's `sudo cat > file` breakage).
20. AGENTS.md/live-docs candidate: `client-secrets` read-once-at-start consumer inventory (who they are, restart coupling) — new gotcha entry in docs/agents/secrets.md.
21. Immich mobile: after login works, confirm the `app.immich:///oauth-callback` round trip and that no forward-auth cookie is required (runbook asserts exemption; verify once from the phone).
22. Consider `restartTriggers` on consumer units keyed to the client-secrets dir (nixos systemd option) — declarative alternative to item 2 ordering; evaluate which mechanism survives `harden{}`.
23. Add `sudo -n` probe as a first-class step in runbooks that need root (stop re-deriving the 2026-11-07 exception every time).
24. Cleanup: owner-side `ls /tmp | grep dnsblockd` — the paste-mangled file from step 1 may still exist; trash it.
25. docs/services/immich.md: add phone/app section (server URL form, OAuth-only login, no password fallback by design — passwordLogin disabled — so app-side credential caching behaves differently).
26. NetBird exit-node decision row (existing §g ambition in net-vpn.md) becomes more relevant now that a phone actually uses the tunnel — resurface to owner.
27. Verify rpi3 dnsblockd answers `auth.home.lan` identically (phone-in-tunnel path resolves via 192.168.1.53) — one dig from rpi3 context; the design assumes parity, nothing re-verified it after the rpi3 CA-duplicate question (existing related row in services.md).
28. Immich upload smoke from the phone after login (photos sync = the actual user outcome; login success alone is not the finish line).
29. Consider probing `pocket-id` startup-to-provision ordering: today provision ran 16:50:50 and pocket-id went active 16:50:51 — confirm the consumer-visible DB state is always post-provision (ordering asserts exist? not verified this session).
30. Secret-file write side: confirm provisioner writes `client-secrets/*` atomically (rename, not in-place truncate) — an in-place write could hand a consumer a HALF file at restart; not checked, cheap to verify in the module source.
31. File-and-image-renamer-class idea: a `scripts/serve-file.sh` helper (port + one file + auto-kill after N minutes) so ad-hoc LAN serving is one command with cleanup built in.
32. Gatus check naming/discovery: today I found auth checks only by reading journal UA strings; an inventory row of WHICH gatus checks cover WHICH auth surfaces would speed the next incident.
33. SigNoz: consider a rule on oauth2-proxy 5xx rate (today's 500s were visible only in journald).
34. Docs truth-up: dnsblockd.md:400 "Android Chrome ignores user-installed CA certs for browsing" — pair with item 16 verification.
35. ROADMAP fuel: a device-enrollment status dashboard (which devices have the CA, which are NetBird-enrolled, last seen) — the fleet is now multi-device and every enrollment step is owner-manual.

**Explicitly NOT harvested (and why):** items 9–35 are brainstorm without verification behind them — queueing unverified premises costs full dispatch cycles (the @home-hermes wrong-premise rule); they stay in this report as fuel until someone picks them up deliberately. Items 3, 6, 7, 8, 5 are owner-gated or blocked on §g answers, so they live HERE, not in the `[ready]` queue. Items 1, 2 ARE harvested (direct, verified-class follow-ups). Item 8's underlying enrollment row already exists (pixel6.md "Motorola: import dnsblockd CA + enroll") — not duplicated.

## g) Questions I cannot figure out myself

1. **Did the Immich login succeed on the phone after the 17:32 restart?** This is the verdict on the entire fix; if it still 500s, the disk `client-secrets/oauth2-proxy` file itself has drifted from Pocket ID's DB and the repair path changes (forced client rotation in Pocket ID + provisioner re-sync).
2. **Is the CA now actually installed and usable on the phone** (Trusted credentials → User tab shows `dnsblockd-CA`)? If yes, I kill the temp server on 18000 immediately.
3. **What happened in the 16:38→16:50 window today** — was the 16:38 deploy yours/intentional (and what did it carry), and did anyone edit the `oauth2-proxy` client in Pocket ID's UI today? That answers WHY the expected secret drifted and whether this was a one-off or a recurring rotation event I should structurally defend against.
