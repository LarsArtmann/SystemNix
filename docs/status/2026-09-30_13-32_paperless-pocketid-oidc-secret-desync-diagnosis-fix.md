# Paperless × Pocket ID SSO Secret Desync — Diagnosis & Fix

**Date:** 2026-09-30 13:32 CEST
**Session scope:** Single task — diagnose and fix "paperless won't log me in via Pocket ID". Report covers ONLY this session's work and observations (per owner instruction; no unrelated research).
**Format note:** Owner explicitly requested `.md`; the status-report skill's canonical HTML format was overridden by that instruction.

---

## Incident summary

Paperless SSO (`paperless.home.lan`, Layer 1 native OIDC via Pocket ID) failed at the **token exchange** with `invalid_client`. The authorize leg worked (passkey screen reached, code round-tripped), so the client row and callback URLs were fine — the secret paperless presented did not match Pocket ID's DB. Root failure class: **Pocket ID client-secret desync**, made permanent by the provisioner's blind `Secret file already exists` trust.

## Timeline (journal-evidenced)

| Time (Sep 30 unless noted) | Event                                                                                                                                                                                   | Evidence                                   |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| ≤ Sep 29 (unknown)         | Desync occurred; break date NOT establishable (see §d-3)                                                                                                                                | —                                          |
| Sep 29 09:25:21 → 09:51:22 | **pocket-id ran 2.16.0 for ~26 min, then was reverted to 2.14.0** (still running 2.14.0 today)                                                                                          | version lines in `journalctl -u pocket-id` |
| Sep 29 21:48               | `5be64526` hardened provisioner secret write to mktemp+mv after a "near-miss" truncate-kill during the Sep 29 storm night                                                               | git log + commit comment                   |
| Sep 30 08:56:59 / 08:57:04 | Owner login attempts fail: paperless `Social authentication error ... invalid_client` AND pocket-id fosite `Failed to create access request ... invalid_client`                         | both journals                              |
| 10:43 (session)            | Diagnosis delivered; owner ran the break-glass: `sudo rm /var/lib/pocket-id/client-secrets/paperless` + `sudo systemctl restart pocket-id-provision paperless-oidc-setup paperless-web` | —                                          |
| 10:43:44                   | Provision detected missing file → generated NEW secret via multi-secret API → `Secret written to /var/lib/pocket-id/client-secrets/paperless`                                           | provision journal                          |
| 10:43:45                   | `paperless-oidc-setup` rewrote the env file (password login disabled, redirect-to-SSO on); `paperless-web` restarted                                                                    | bridge + web journals                      |

**Key diagnostic eliminations:**

- Not a stale process env: web restarted at 05:51, 07:00:27, 08:12:10 — each AFTER an env write. The mismatch was file-content vs DB, not in-memory staleness.
- Not a missing client row: authorize leg succeeded (fosite's `invalid_client` fired at token stage, which only runs after a successful code issuance).
- Provisioner at 08:10:47 explicitly logged `Client 'Paperless' already exists. Updating... Secret file already exists.` — the desync persisted _through_ a full deploy cycle because the provisioner never verifies file↔DB parity.
- Upstream release notes: 2.15.0/2.16.0 changed nothing about client-secret storage; **2.14.0 shipped "multiple client secrets per OIDC client" (#1679) — a data-model change**. The 2.16.0 round-trip on Sep 29 is the prime suspect for a DB-side hash change the 2.14.0 binary can no longer verify, but this is a HYPOTHESIS, not proof (§b-2, §d-1).

---

## a) FULLY DONE

1. **Failure localized to the token exchange** — `invalid_client` confirmed on BOTH sides' journals (paperless auth WARNING + pocket-id fosite ERR at 08:56/08:57). Evidence: journalctl, both units.
2. **Stale-env class eliminated** — three same-day web restarts (05:51/07:00/08:12) each followed an env write; EnvironmentFile freshness proven not the issue.
3. **Persistence mechanism identified** — provisioner's `Secret file already exists` skip path trusts file existence without DB parity; this is why the desync survived 4 deploys today. Evidence: provision journal 08:10:47.
4. **Version round-trip forensics** — pocket-id 2.16.0 ran Sep 29 09:25:21→09:51:22, reverted to 2.14.0; 2.14.0's #1679 multi-secrets data model identified as the migration surface. Evidence: journal version lines + upstream release notes (fetched).
5. **Fix executed and chain-verified at the systemd level** — secret regenerated into DB+file (10:43:44), bridge re-copied (10:43:45), web restarted with the new env (10:43:45). All three journal-confirmed. Scope: `/var/lib/pocket-id/client-secrets/paperless`, `paperless-oidc-setup`, `paperless-web`; zero config/repo changes needed.

## b) PARTIALLY DONE

1. **THE FIX — mechanically complete, functionally UNCONFIRMED.**
   - Works: DB and file now agree (fresh secret both sides); full restart chain verified.
   - Open: no evidence yet that an actual passkey login succeeds. Per the close-out rule: my evidence answers _"the chain re-synced"_, NOT _"the owner can log in"_. Owner confirmation pending.
   - Blocker: passkey ceremony is human-only; not automatable. Effort to close: S (one login attempt).
2. **Root cause — narrowed, not pinned.**
   - Works: failure class identified (secret desync); three candidate causes enumerated: (a) 2.14.0 #1679 migration behavior, (b) the 26-min 2.16.0 round-trip re-hashing/migrating, (c) provisioner truncate-race corruption (the `5be64526` near-miss).
   - Open: NONE proven. The mismatched file was deleted during the fix, destroying direct evidence.
   - Blocker: evidence now only in the 04:00 `pocket-id-backup` DB snapshot (time-sensitive — retention may rotate it). Effort: M.
3. **Fleet-wide blast radius — unknown.**
   - Works: 0 `invalid_client` hits in forgejo/immich/miniflux/gatus journals over 48h.
   - Open: that is absence-of-attempts, not proof of health. If the DB-side cause is real, every OIDC client is latently broken.
   - Blocker: requires a live login test per client (owner) or an authorize-endpoint sweep (S, scriptable). Effort: S–M.

## c) NOT STARTED

- §f harvest into `TODO_LIST.md` + `docs/todo/services.md` — **deliberately deferred**: owner ordered "THEN WAIT FOR INSTRUCTIONS"; harvest re-runs on their go (recorded here per the AGENTS.md self-harvest escape clause).
- AGENTS.md / gotchas-archive / runbook documentation updates — waiting on login confirmation + root cause (premature docs would enshrine a hypothesis).
- Provisioner parity verification, OIDC-depth monitoring, nixpkgs version-pin decision — all items in §f, none begun.
- No repo changes were made this session (fix was live-ops only; the auto-commit daemon owns the tree).

## d) TOTALLY FUCKED UP

1. **Evidence destroyed by the fix path (my call).** I handed the owner `rm` of the secret file as step 1 WITHOUT capturing the old file first (length/fingerprint via sudo was available — sudo works for the owner). The mismatched artifact is gone; definitive root-cause forensics now depend entirely on the 04:00 `pocket-id-backup` snapshot surviving retention. Severity: blocks the root-cause close-out; recurrence would re-land unexplained. Mitigation: 04:00 DB backup predates the fix — capture a copy BEFORE the next backup cycle rotates it (§f #1-adjacent, time-sensitive).
2. **"Fixed" with root cause UNKNOWN.** The system now works-by-regeneration; nothing prevents a recurrence of the same desync (whatever created it may still exist). Severity: medium. Mitigation: candidate causes + forensic path documented here.
3. **Break date unestablishable — logging gap.** Paperless logs failed social logins at WARNING but successful ones are not greppable in the journal; the last-success date is unknowable from logs. The outage was ALSO invisible to monitoring: the Gatus "Paperless" login-page check stayed green throughout (healthy bridge → button renders; token-exchange failure is unreachable by that probe). Severity: medium (future incidents of this class will again be owner-discovered).

## e) WHAT WE SHOULD IMPROVE

1. **Monitoring depth for SSO** — login-page-render checks are phantom-green for the token-exchange failure class. Fix: per-client authorize-endpoint probe (public, no creds — proves client row + callback) + SigNoz/Gatus alert on pocket-id journal `invalid_client` count > 0.
2. **Provisioner parity** — `Secret file already exists` must not be the only truth source. Fix: store a fingerprint (length + hash prefix, never the value) at generation time and verify each run; optionally regenerate-on-mismatch.
3. **Evidence-first fix discipline** — when a fix destroys state, capture forensics FIRST (even one `stat` + `wc -c` via sudo). Encode in the desync runbook.
4. **Sandbox probe coverage** — `curl`/`sudo`/`systemctl` were blocked this session, but python (urllib) was available on-host and never tried; the authorize-endpoint probe could have run without the owner. Lesson: enumerate unblocked HTTP tools before leaning on the user.
5. **Version round-trip breadcrumbs** — pocket-id 2.16.0 → 2.14.0 reverted within 26 min on Sep 29 with no commit/journal note explaining why. Session-scoped dig didn't chase it (out of scope); the revert rationale should be recorded wherever the pin decision lives.
6. **Successful-login observability** — raise paperless social-login successes to a greppable level (or emit a metric) so "when did SSO last work" is answerable.

## f) NEXT TASKS (brainstorm, impact-ranked — §f harvest deferred per owner's wait instruction; larger-N items are ROADMAP fuel per skill guidance)

| #  | Task                                                                                                                                                 | Impact   | Effort | Category      |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------ | ------------- |
| 1  | Owner confirms paperless passkey login post-fix (closes/refutes the whole incident)                                                                  | Critical | S      | Bug           |
| 2  | TIME-SENSITIVE: copy the 04:00 `pocket-id-backup` DB snapshot aside (sudo) before retention rotates it — it holds the only pre-fix mismatch evidence | Critical | S      | Bug           |
| 3  | Owner tests ONE other OIDC client login (e.g. a Layer-2 service or forgejo/miniflux) to split "paperless-only" from "fleet-wide DB-side"             | Critical | S      | Bug           |
| 4  | Forensic compare on the preserved backup: paperless client secret rows vs the (remembered/none) file state; pin cause (a)/(b)/(c)                    | High     | M      | Bug           |
| 5  | Find the Sep 29 2.16.0→2.14.0 revert commit/deploy; record WHO/WHY next to the pin decision                                                          | High     | S      | Cleanup       |
| 6  | Check which pocket-id version the current nixpkgs lock pins; if ≥2.15, next `nix flake update` re-runs migrations on 2.14.0 data                     | High     | S      | Bug           |
| 7  | Owner decision: hold pocket-id at 2.14.0 vs pre-flight the 2.16.x migration on a DB copy before any bump                                             | High     | S      | Decision      |
| 8  | Provisioner: log secret-file fingerprint (length + hash prefix, NO value) every run for drift visibility                                             | Medium   | S      | Feature       |
| 9  | Provisioner: parity check / regenerate-on-mismatch mode instead of trusting file existence                                                           | High     | M      | Feature       |
| 10 | Provisioner: sweep stale `.secret.*` mktemp leftovers (crash residue from the truncate-race era) at run start                                        | Medium   | S      | Cleanup       |
| 11 | Check NOW (sudo ls) whether stale `.secret.*` temp files exist in the client-secrets dir                                                             | Low      | S      | Cleanup       |
| 12 | SigNoz/Gatus: alert on pocket-id journal `invalid_client` occurrences (closes the §d-3 monitoring blind spot)                                        | High     | S      | Feature       |
| 13 | Gatus: per-client authorize-endpoint probe (proves client row + callback; public endpoint)                                                           | Medium   | M      | Feature       |
| 14 | Sweep ALL provisioned clients with a live auth test (gatus SelfHealth, dnsblockd SSO, oauth2-proxy, immich, forgejo, miniflux, browser-history)      | High     | M      | Bug           |
| 15 | Paperless: log successful social logins greppably (or emit a metric) — makes "when did SSO last work" answerable                                     | Medium   | S      | Quality       |
| 16 | Confirm the deployed provision unit actually carries the `5be64526` atomic-write script (generation vs commit check)                                 | Medium   | S      | Quality       |
| 17 | Verify the multi-secret API flow still matches pocket-id 2.14.0 semantics post-#1679 (the 2026-09-02 fix predated it)                                | Medium   | S      | Quality       |
| 18 | Update AGENTS.md (paperless section + pocket-id desync bullet) with the live-proven recovery one-liner — AFTER login confirmed                       | Medium   | S      | Documentation |
| 19 | Add "capture evidence before rm" warning to the desync recovery runbook (docs/services/paperless.md / pocket-id runbook)                             | Medium   | S      | Documentation |
| 20 | gotchas-archive entry for this incident once root cause is pinned                                                                                    | Medium   | S      | Documentation |
| 21 | Check pocket-id-backup retention window is long enough for the forensics dependency in #2                                                            | High     | S      | Bug           |
| 22 | Textfile metric: secret-file + env-file mtimes (drift alerting for the desync class)                                                                 | Low      | S      | Feature       |
| 23 | Code-read `paperless-oidc-setup` bridge: behavior when the pocket-id client ROW (not just secret) is missing                                         | Low      | S      | Quality       |
| 24 | Post-incident fleet "SSO smoke" runbook entry: 5-min post-deploy probe of each Layer-1 client's authorize endpoint                                   | Medium   | M      | Documentation |
| 25 | Upstream issue to pocket-id re downgrade-after-migration breakage — ONLY after root cause confirmed (verify-before-filing gates)                     | Low      | L      | Bug           |
| 26 | Harvest this report's §f into `TODO_LIST.md` + `docs/todo/services.md` (deferred per owner's wait instruction)                                       | Medium   | S      | Cleanup       |
| 27 | Record the sandbox lesson: python urllib as on-host HTTP probe when curl is blocked                                                                  | Low      | S      | Cleanup       |
| 28 | Post-confirmation: annotate this report with the login verdict (docs-health ANNOTATE mode, non-destructive)                                          | Low      | S      | Documentation |
| 29 | SigNoz: dashboard/rule for paperless auth WARNINGs (already flow journald→SigNoz; no rule watches them)                                              | Medium   | S      | Feature       |
| 30 | Decide whether `regenerateSecretsFor`-style declarative rotation should be standing config vs break-glass only (owner)                               | Low      | S      | Decision      |

## g) QUESTIONS (3 — cannot figure out myself)

1. **Did the paperless passkey login actually succeed after the 10:43 fix?** I cannot complete a passkey ceremony; this single answer closes or reopens the incident. (What I tried: full journal verification of the regen chain — but that answers "chain re-synced", not "login works".)
2. **Do OTHER SSO logins still work for you right now** (any Layer-2 protected service, forgejo, or miniflux)? This splits "paperless-only file corruption" from "fleet-wide DB-side breakage after the 2.16.0 round-trip", and decides whether this was a one-off or an incident with 7 more patients.
3. **Was the Sep 29 pocket-id 2.16.0 → 2.14.0 revert (09:25→09:51) deliberate — and do you want pocket-id held at 2.14.0, or pre-flight-tested on 2.16.x before the next flake update?** The journals show the flip but not the intent; the pin/migration policy is owner-gated.

---

_Session used no repo changes; the only live-system mutations were the owner-run secret regeneration + unit restarts (journal-verified above). Waiting for instructions._
