# Status Report — Paperless SSO "Zero Permissions" Diagnosis (Log Sweep)

**Date:** 2026-09-30 13:17
**Session scope:** Full journal sweep of all paperless units + diagnosis of the user-reported "zero permissions" state. No config changes were made. **Nothing in this report has been harvested into TODO_LIST.md / domain libraries yet — deliberately deferred because the user instructed "report, then WAIT FOR INSTRUCTIONS" (recorded per the AGENTS.md self-harvest rule; harvest on demand).**

---

## What the session actually was

1. Swept all 7 paperless-related units (`paperless-web`, `-consumer`, `-scheduler`, `-task-queue`, `-exporter`, `-db-backup`, `-oidc-setup`) over the last 24h for warnings/errors.
2. Traced the user's "why do I have zero permissions" to its real cause: **a dead SSO session caused by an OIDC client-secret desync** (`invalid_client` at 08:56–08:57), NOT filesystem or model permissions.
3. Verified the self-heal chain from journals: secret rotation → bridge rewrite → web restart.
4. Classified all remaining log noise as benign.
5. Noticed (but did not investigate) an unrelated suspicious signal: **pocket-id failed at 10:33:08** and appears to restart roughly hourly.

**Result:** no code/config changes; diagnosis-only session. Everything below is state observed from journals.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | Full 24h log sweep of all 7 paperless units — every warning/error enumerated and classified | `journalctl` sweeps; only 4 noise classes found (see e) |
| 2 | Root cause of "zero permissions" identified: OIDC login broke with `invalid_client` (client-secret desync, the known provisioner-rotation class) → dead Django session → DRF answered **403 Forbidden** on `/api/ui_settings/` + `/api/saved_views/` (13:12:28) → the paperless frontend rendered its empty-permissions state | journal `paperless.auth: Social authentication error … invalid_client` (08:56:59, 08:57:04); `[django.request] Forbidden` (13:12:28, 13:12:49) |
| 3 | Self-heal chain verified end-to-end from journals: Pocket ID provisioner **rotated** the paperless secret (`POST /api/oidc/clients/paperless/secrets` → 201 at **10:43:44**), `paperless-oidc-setup` rewrote the bridge env (**10:43:45** and **13:03:54**, journal: "Pocket ID OIDC env file written (password login disabled, redirect-to-SSO on)"), `paperless-web` restarted **13:03:55** reading the fresh env | pocket-id + paperless-oidc-setup + paperless-web journals, same timestamps |
| 4 | Post-fix OIDC flow proven healthy up to the passkey gate: 13:12:21 `/authorize?client_id=paperless` → 302 → `/interaction` (passkey screen) rendered | pocket-id request log 13:12:21 |
| 5 | All residual log noise classified benign: systemd "multiple trigger source candidates (paperless-exporter.service ×2)" on every restart; `storage-collector` statvfs EACCES on `/run/credentials/*` (root-only credential tmpfs — correct denial); recurring ~2h `Unauthorized: /api/documents/` (unauthenticated probes); upstream Django `StreamingHttpResponse` async-iterator warning (paperless 3.1.3, harmless) | journal, multiple timestamps |

---

## b) PARTIALLY DONE

| # | Item | What works | What's open | Blocker | Effort |
|---|------|-----------|-------------|---------|--------|
| 1 | **SSO fix verification** | Whole server-side chain proven green (rotation → bridge → web restart → authorize → interaction page) | The final passkey login + resulting session was never observed (no successful callback logged after 13:12:21 in the window I read) | Requires the user to complete a passkey — I cannot | S (user, ~1 min) |
| 2 | **Desync origin** | The desync's EXISTENCE and its fix are proven; last `invalid_client` was 08:57, first rotation 10:43 | **Which earlier event left the bridge env stale** (a prior rotation without a bridge rewrite? Pocket ID DB churn?) is undetermined — I verified the repair, not the root cause of the mismatch | Deeper provisioner-history dig not done (scope discipline + wait instruction) | M |
| 3 | **DB-level user/permission state** | Symptom fully explained by the dead-session mechanism | The users table (which user, permissions, any stray auto-created SSO duplicate) was NOT inspected | Agent sandbox blocks `sudo` ("command is not allowed"); needs root/postgres peer auth | S (with sudo) |
| 4 | **Why the secret rotated at 10:43:44** | Rotation observed (201) | Was it `regenerateSecretsFor` policy or a MISSING secret file (implying Pocket ID DB lost the client row)? The two have different follow-ups | Not determined; coincides suspiciously with pocket-id's 10:33:08 crash | S–M |

---

## c) NOT STARTED

All planned follow-ups from this session's observations — nothing written yet (waiting on user instruction):

1. **Runbook troubleshooting entry** (`docs/services/paperless.md`): "SSO login fails → UI shows a zero-permissions/empty state" → meaning: dead session, re-authenticate; includes the invalid_client signature.
2. **AGENTS.md paperless section lesson**: the desync class PRESENTS AS "zero permissions" in the UI — a future agent must not go hunting for permission models first (this session's exact detour).
3. **Standing self-heal decision**: add `paperless` to `pocket-id-config.provision.regenerateSecretsFor` so future desyncs auto-rotate instead of silently failing logins (option already exists, `modules/nixos/services/pocket-id.nix:429`).
4. **Rotation visibility**: today's secret rotation was discoverable only by journal archaeology; no metric/alert fires when the provisioner mints a new client secret.
5. **Investigation threads** (each 15–30 min): pocket-id 10:33:08 exit-code failure; pocket-id's ~hourly restart pattern; the duplicated unit name in the trigger-candidates warning; which probe sends the ~2h `/api/documents/` 401s.

---

## d) TOTALLY FUCKED UP

| # | What is broken | Severity | Root cause | Mitigation |
|---|---------------|----------|-----------|------------|
| 1 | **Paperless SSO login outage ~08:56 → 10:43** — every OIDC login failed `invalid_client` at token exchange (authorize still worked, so it LOOKED half-alive). User-facing: anyone clicking "Pocket ID" got bounced; an already-open tab degraded into the misleading "zero permissions" screen | Medium (single-service, ~1h45m window, self-healed) | Client-secret desync between Pocket ID's DB and `/var/lib/paperless-oidc/pocket-id.env` — the bridge env was stale until the 10:43 rotation cycle rewrote it. **Origin of the mismatch: still unknown** | Healed by the 10:43:44 rotation + 10:43:45 bridge rewrite + 13:03:55 web restart. Structural fix = (c)3 standing `regenerateSecretsFor` |
| 2 | **The symptom camouflage** — a dead session renders as "you have zero permissions", which sent this diagnosis toward permission models before the auth logs told the truth. No doc anywhere maps this UI state to "your session is dead, log in again" | Diagnosis-cost (recurring) | Paperless frontend treats 403 on `ui_settings` as an empty-permission state | Runbook entry (c)1 |
| 3 | **pocket-id.service: Failed with result 'exit-code' at 10:33:08** + a suspicious near-hourly start pattern today (warning fires at each start: 04:43, 05:50, 06:59, 08:10, 09:00, 10:30, 13:02). The SSO IdP — the single auth dependency for EVERY Layer-1/Layer-2 service — shows an unexplained failure + restart churn on the same morning as the paperless desync | Potentially HIGH (IdP stability) | **Unknown — not investigated** (scope discipline; flagged, not chased) | None yet. Candidate link to (d)1: a pocket-id crash/DB event around that window is exactly the class that loses client rows and forces secret re-mints |

**Honest scope note:** (d)3 was noticed, not diagnosed. If the user says "go", thread (c)5 threads 1+2 are the next 30 minutes of work.

---

## e) WHAT WE SHOULD IMPROVE

1. **Map UI symptoms to causes in runbooks.** The "zero permissions" screen cost a diagnostic detour; one troubleshooting row (`SSO 403s → dead session`) prevents the next one. Impact: every future paperless auth complaint; Fix: (c)1.
2. **Make secret rotation observable.** Provisioner secret mints are silent (200/201 lines buried in INFO). One counter metric or a grep-guarded journal alert (`POST …/secrets 201`) makes desync windows measurable instead of archaeology. Impact: converts (b)2 from dig to glance.
3. **Prefer standing self-heal over one-off repair.** `regenerateSecretsFor` exists precisely for this class; today's heal worked only because a rotation happened to fire. Add `paperless` permanently (owner decision).
4. **Silence known-unreadable probes.** `storage-collector` statvfs EACCES on `/run/credentials/*` fires every minute — a static exclusion list (credential tmpfs dirs are root-only BY DESIGN) removes a permanent WARN class from every log sweep.
5. **Immunity-map the desync class across Layer-1 services.** Miniflux is immune (LoadCredential `%d` reads the secret file directly); paperless has the env-file bridge; forgejo reads at runtime. A one-paragraph table in the SSO section would tell future sessions which services can even HAVE this outage.
6. **Memory rule respected, deferred:** the AGENTS.md lesson (item (c)2) should land at harvest time — recorded here so it isn't lost.

---

## f) NEXT TASKS (session-derived, ranked — 18 real items, not padded to 50)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | User: complete the passkey login on paperless.home.lan; confirm paperless is usable | Critical | S | Verification |
| 2 | Investigate pocket-id.service exit-code failure at 10:33:08 (journal dig around that minute) | High | S | Bug |
| 3 | Investigate pocket-id's near-hourly restart pattern (04:43→13:02 start cadence) | High | S | Bug |
| 4 | Determine desync origin: find the rotation/DB event that left the bridge env stale pre-08:56 | High | M | Bug |
| 5 | Determine why the 10:43:44 rotation fired (regenerateSecretsFor policy vs missing secret file) — decides follow-up shape | High | S | Bug |
| 6 | Owner decision: add `paperless` to `provision.regenerateSecretsFor` as standing self-heal | High | S | Decision |
| 7 | Add "zero-permissions UI = dead SSO session" troubleshooting row to `docs/services/paperless.md` | Medium | S | Documentation |
| 8 | Record the desync-presents-as-zero-permissions lesson in AGENTS.md paperless section | Medium | S | Documentation |
| 9 | Verify paperless DB user state (permissions intact, no stray auto-created SSO duplicate) after re-login | Medium | S | Verification |
| 10 | Add rotation-visibility signal (metric or journal alert on provisioner secret mints) | Medium | M | Feature |
| 11 | Post-deploy ordering idea: assert the bridge env was rewritten AFTER any same-window rotation and BEFORE paperless-web restarts (smoke check) | Medium | M | Feature |
| 12 | Immunity map for the desync class across all Layer-1 OIDC services (which bridge shape each uses) | Medium | M | Quality |
| 13 | Identify the ~2h `Unauthorized: /api/documents/` probe source; label it in the runbook as expected | Low | S | Documentation |
| 14 | Chase the duplicated unit name in "multiple trigger source candidates (paperless-exporter.service ×2)" | Low | S | Quality |
| 15 | Exclude `/run/credentials/*` from storage-collector statvfs scanning (permanent benign WARN) | Low | S | Quality |
| 16 | Note upstream Django StreamingHttpResponse warning as known-harmless paperless 3.1.3 noise | Low | S | Documentation |
| 17 | Light health pass on paperless tasks/celerybeat after today's two postgres-bounce deploy waves (05:50, 13:03) | Medium | S | Verification |
| 18 | Identify which deploy/generation carried the 10:43 provisioner cycle (timeline completeness for (d)1's narrative) | Low | S | Documentation |

Items 1–5 close the incident; 6–12 make the class structurally impossible or visible; 13–18 are sweep hygiene found en route. **Deliberately NOT harvested yet** (see header) — say the word and I'll route these into `TODO_LIST.md` + `docs/todo/services.md`.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Did the passkey login complete after 13:12 — is paperless usable for you now?** (I can verify the server side is green, but only your passkey can close the loop; this is the acceptance test for the whole diagnosis.)
2. **Was your "zero permissions" the paperless UI's empty-permissions screen — or did you mean something else** (e.g. file/dir permission errors SSH'ing into `/mnt/pool/services/paperless`, which IS `paperless:paperless`-owned and unreadable to your user)? My entire diagnosis assumes interpretation A; if it was B, the root cause is different and my report needs a correction pass.
3. **Do you want `paperless` permanently in `regenerateSecretsFor`** (auto-rotate on every suspected desync, accepting that a rotation invalidates in-flight logins until the bridge+web restart chain completes) — or should rotation stay event-driven, meaning desyncs like today's heal only when the next provisioner cycle fires?

---

*Report written per user instruction (explicit `.md` format override of the skill's HTML default — flagged per skill spec). No commits made (harness rule: no commit without explicit request; auto-commit daemon will pick this up). Waiting for instructions.*
