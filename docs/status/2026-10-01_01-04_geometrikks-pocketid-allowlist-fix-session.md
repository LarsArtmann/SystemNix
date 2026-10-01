# 2026-10-01 01:04 — Session Status: GeoMetrikks Pocket-ID allow-list fix (root cause, fix, verification, harvest)

Session scope: the user report "Geometriks doesn't auto allow PocketID users; why? fix". Work executed 2026-09-30 ~14:00–15:50 CEST; report authored 2026-10-01 01:04 CEST after a session gap. Everything below is first-hand from this session unless marked. A parallel session was active throughout (buildcache single-sourcing work: `0fdbf2d7`, `af9b3ef2`, `715e9510`, `43367872`, `51d990a6`) — several of my changes landed mixed with theirs in daemon sweeps, per the documented daemon-race policy.

---

## TL;DR

Every "Sign in with Pocket ID" login at geo.home.lan failed `reason=not_allowed`. Root cause verified end-to-end on BOTH sides: GeoMetrikks upstream matches an allow-list entry against the subject id always but against an email only when the IdP sends `email_verified: true` (strict boolean), and Pocket ID's `email_verified` is a **per-user column defaulting to FALSE**. The email-only allow-list could never match. Fix: the OIDC bridge now auto-resolves every enabled Pocket ID user's subject id from Pocket ID's SQLite and appends it to `OIDC_ALLOWED_USERS` (miniflux phase-1 pattern). Fix is **landed + verified in-tree, NOT deployed** — the live login proof is still pending the owner's `nix run .#deploy`.

---

## a) FULLY DONE

1. **Root cause diagnosis (source-verified both sides + live journal proof).**
   - Upstream `geometrikks/services/oidc/client.py::check_allow_list`: subject ∈ allow-list → else email matches ONLY when `email_verified is True` (test `test_allow_list_unverified_email_never_matches`, `test_email_verified_as_a_string_does_not_count`) → else group overlap.
   - Pocket ID `claims_service.go` releases `email` + `email_verified` whenever the client holds the `email` scope; `email_verified` is the per-user `users.email_verified` column added by migration `20260109090200` with `DEFAULT FALSE`, set only by Pocket ID's SMTP verification flow or an admin toggle.
   - Live proof at 13:50:59 (`journalctl -u geometrikks`): token exchange 200, userinfo 200, then `login_failed email=lars@larsartmann.cloud groups=[] reason=not_allowed subject=88bec46e-57cd-41c3-b768-e1a9e00425fb` — the email claim WAS delivered and still rejected ⇒ `email_verified` was false. (sudo/systemctl are blocked in this sandbox — journal + source were the two available evidence layers, and both agreed.)
2. **The fix** (`modules/nixos/services/geometrikks.nix`, landed `6f37b5f5` v1 + `432e193e` mktemp fix): `geometrikks-oidc-env` gained a `+`-privileged ExecStartPre `geometrikks-oidc-subs` that reads Pocket ID's SQLite (`users` where `disabled = 0`), charset-guards every id, retries 5×2s for sqlite transients, and stages `/var/lib/geometrikks-oidc/allowed-subs`; the bridge appends the subs to the configured emails in `OIDC_ALLOWED_USERS`. Design decisions: resolve ALL enabled users (the literal ask: "auto allow Pocket ID users" — matches every other Layer 1 service's trust posture), resolver failure is FATAL + OnFailure (email-only = every login rejected, must page), no staged subs = email-only WARN (not fatal — belt if `email_verified` is ever flipped), env overrides `GEOMETRIKKS_OIDC_DB`/`GEOMETRIKKS_OIDC_SUBS_FILE` for fixture testing, mktemp+trap staging (no fixed-`.tmp`).
3. **Verification (9 executed fixture cases on the REALIZED store scripts, not replicas)**: resolver — enabled/disabled split (only the enabled sub written), injection-shaped id refused with no file written, empty-users refused, missing-DB refused, post-mktemp re-run green + no leaked temp files; bridge — subs appended (exact expected `OIDC_ALLOWED_USERS=lars@…,<sub1>,<sub2>` rendered), email-only fallback WARN, bad-staged-sub refusal rc=1. Scripts `bash -n`-clean; `scripts/audit-textfile-tmp.sh` repo-wide green; evo-x2 toplevel eval green; `nix flake check --no-build` ALL CHECKS PASSED (run before the final 11-line mktemp delta; that delta was covered by eval + audit + fixtures, and the next commit's pre-commit hook re-runs the full check).
4. **Docs (all surfaces of the fact, same session)**: AGENTS.md geometrikks bullet rewritten (mechanism, why the sub append is load-bearing, failure semantics, convergence); fleet-wide fact added to the AGENTS.md SSO section ("Pocket ID `email_verified` is PER-USER and DEFAULTS TO FALSE" — any future relying party allow-listing by verified email hits this class); `docs/services/geometrikks.md` (SSO bullet, login line, go-live step 1 rewritten with the stale-subs diagnosis path); `docs/todo/services.md` go-live row updated.
5. **Pre-commit audit catch handled correctly**: my first draft used a fixed `allowed-subs.tmp` — the `textfile-tmp` audit blocked the commit; fixed with the sanctioned mktemp+trap shape (call-site fix, not scanner suppression), re-verified end-to-end.
6. **CHANGELOG entry** (landed `dfdd83b6`): full Fixed-section entry with the journal evidence line, mechanism, verification inventory, and the fleet-wide class.
7. **Self-harvest of this report's direct follow-ups (done at authoring time, per the AGENTS.md status-report rule)**: the existing geometrikks post-deploy smoke-probe row extended (TODO_LIST + services.md, no-drift rule) with the new OIDC allow-list assertions; one NEW [ready] pair landed for persisting the fixture harness as a flake check (both surfaces, pointer to this report).

## b) PARTIALLY DONE

1. **The fix itself is inert until deploy.** Config landed + eval/fixture-verified, but `nix run .#deploy` is owner-run (sudo is blocked in this sandbox; deploys are human-owned). deploy.sh's existing is-active-gated block (scripts/deploy.sh:577-580) restarts `geometrikks-oidc-env` + `geometrikks` — after deploy the bridge re-resolves subs and the daemon reloads the env. Until then the ORIGINAL behavior (every SSO login rejected) is still what's live.
2. **"Fixed" is fixture-proven, not login-proven.** The first real passkey login is the only end-to-end proof (the user's original question deserves that verdict, per the verification-close-out rule). The go-live row (`docs/todo/services.md` [blocked:user]) carries it.
3. **Attribution of the fix in git history is degraded.** All my changes landed under heuristic daemon messages (`6f37b5f5`, `432e193e` mixed with foreign caddy.nix, `dfdd83b6` mixed with the parallel session's AGENTS.md edit). My one manual pathspec commit attempt died at the pre-commit audit leg; by the time the fix was ready, HEAD contained foreign work, so per the daemon-race policy I did NOT amend (an amend would absorb the foreign changes into a misleading message). The durable narrative lives in this report + CHANGELOG, not in a commit message.
4. **Verification of the full flake check on the FINAL tree.** The full `nix flake check --no-build` ran green before the mktemp delta; after the delta I ran toplevel eval + repo-wide audit + re-fixtures (adequate coverage of an 11-line script-internal change), but strictly speaking the final tree's full check runs first at the next commit's hook.

## c) NOT STARTED (discovered or re-confirmed this session; see §f for the full list)

1. **In-repo fixture check for the two OIDC scripts** — the 9-case harness ran as throwaway /tmp commands; nothing in-repo regresses if a future edit breaks the resolver (harvested as [ready] pair).
2. **geometrikks post-deploy smoke probes** — pre-existing gap (post-deploy-check has ZERO geometrikks entries; the service sat dark 09-29 unnoticed); my change adds an assertable surface (allowed-subs + OIDC_ALLOWED_USERS) — harvested into the existing row.
3. **Allowed-subs staleness monitor** — if Pocket ID's DB is ever recreated (has happened: 2026-08-22 SQLITE_BUSY class), subs churn and geometrikks login breaks with NO page until someone tries to log in. No metric/Gatus check exists (brainstorm, §f).
4. **AGENTS.md SSO-layer table refresh** — I edited the SSO section and READ the Layer table, which still omits miniflux/geometrikks/indexer-web/health-dashboard; the queued row (TODO_LIST "Refresh AGENTS.md SSO-layer table vs the registry") already owns it and I left it alone (out of session scope).

## d) TOTALLY FUCKED UP

Nothing destroyed or broken. Honest worst-of list (degradations, not disasters):

1. **The fix's commit-message narrative was lost to daemon sweeps** — three heuristic "chore: auto-commit" messages carry the work, two of them mixed with a parallel session's files. Anyone doing `git log` archaeology sees nothing; the trail is this report + the CHANGELOG entry. Mitigated post-hoc; avoidable only by committing within the daemon's ~10-min window (see §e).
2. **No persisted regression net for a security-adjacent auth path** — the resolver/bridge scripts (root-privileged, feeding an allow-list) are protected only by throwaway evidence. For THIS class of script (charset guards on values that gate authentication) that is the weakest acceptable state; harvested as a [ready] row, not yet built.
3. **First-draft `.tmp` staging pattern** — would have shipped a latent foreign-leftover collision class if the audit hadn't blocked the commit. The prevention layer worked exactly as designed; the miss was mine (knew the pattern, wrote it anyway).

## e) WHAT WE SHOULD IMPROVE

1. **Commit within the daemon window after verification.** The daemon sweeps every ~10 min; my verification round took longer. New rule of thumb for this tree: after the LAST verification command, immediately pathspec-commit your files — don't batch docs + commit at the end.
2. **Persist verification harnesses at authoring time, not as follow-ups.** "Throwaway /tmp commands" are ghost evidence: they prove the thing ONCE and protect nothing. The forgejo-scripts-fixture / migrate-hot-db-fixture pattern should be the default reflex for any new script with security semantics (the env overrides I built into the resolver made this cheap — build them in from the start).
3. **writeShellScript carries no shellcheck** (only writeShellApplication lints). My two scripts got `bash -n` + fixture runs; shellcheck-grade linting would be stricter. Either default new scripts to writeShellApplication (with runtimeInputs) or add a shellcheck leg to script fixtures.
4. **Run the full gate AFTER the last delta**, not before — sequence the final fix, then one full `nix flake check --no-build`, then commit. (This session: check → delta → partial re-verification → daemon swept.)
5. **When editing a doc section, fix the stale adjacent surface you READ** — I updated the SSO section while the Layer table three paragraphs up is stale (owned by a queued row). Cheaper to fix on sight than to leave a cross-reference debt; the only reason I didn't: scope discipline on a user order ("don't research unrelated stuff"). Tension worth naming.
6. **The skill's canonical HTML format vs the user's explicit `.md`** — honored the explicit instruction (this file), flagging the override per the skill's own rule: this report is Markdown, not the styled HTML dashboard the status-report skill defaults to.

## f) Up to 50 things to get done next

Grouped; **[HARVESTED]** rows already landed in TODO_LIST + the owning library this session; everything else is brainstorm (ROADMAP fuel, deliberately NOT harvested — awaiting triage, per the HARVEST anti-patterns).

**Geometrikks / OIDC (this session's direct domain):**

1. **[HARVESTED]** Deploy + first live SSO login (unblocks the [blocked:user] go-live half; deploy.sh bridge+daemon block converges the env) — existing go-live row, updated.
2. **[HARVESTED]** Extend geometrikks post-deploy smoke probe: unit + `/health/ready` + provision journal + `allowed-subs` non-empty + `OIDC_ALLOWED_USERS` carries a UUID sub — existing row, extended both surfaces.
3. **[HARVESTED]** Persist the 9-case OIDC scripts fixture as `checks.geometrikks-oidc-scripts-fixture` (forgejo-scripts-fixture pattern; env overrides already exist) — new [ready] pair.
4. CHANGELOG entry for the fix — DONE this session (moved out of the queue; recorded here for the count).
5. **`allowedUsers` contract decision**: with subs auto-allowing everyone, is the email list + non-empty assertion still the right option semantics, or trim to a new contract (empty default, assertion moved/dropped)? Public option change — owner decision.
6. **Allowed-subs staleness monitor**: compare `allowed-subs` mtime vs `pocket-id.db` mtime in a fail-closed collector + Gatus check (closes the "Pocket ID DB recreated → silent SSO break until someone tries to log in" window).
7. **Belt: flip `email_verified` for lars in the Pocket ID admin UI** (one click) so the email entry also matches — keeps the sub path honest while making the email fallback real. User-gated.
8. **Retry-path fixture**: the sqlite-BUSY→5×2s-retry→fatal branch is the one untested resolver path (a locked-DB fixture would cover it).
9. **Same-class fleet sweep**: grep modules for any OTHER allow-list matching on verified email against Pocket ID (`OIDC_ALLOWED*`, email-claim checks) — GeoMetrikks is the known one; make "none" a verified claim.
10. **Upstream candidate (verify-before-filing gated)**: geometrikks' `oidc_forbidden` login error could name the expected allow-list surface (subject/email) — the current error gives the operator nothing.
11. **Pocket ID ops runbook surface**: the `email_verified` fact lives in AGENTS.md + geometrikks docs; if a Pocket-ID-specific runbook section exists, mirror it there (wherever IdP ops live).
12. **Stale TODO row closure candidate**: TODO_LIST "Investigate geometrikks.service FAILED (00:01/00:16)" is answered by the 05:43 toolkit report (root cause + fix + green) — close via the re-dispatch verification protocol.
13. **[watch] row due**: geometrikks docker-era volume removal (>48h green since the 09-29/30 native migration) — `docker volume rm geometrikks_geometrikks_timescale_data geometrikks_geometrikks_geoip_data`.
14. **Global access.log tailing**: the queued "verify geometrikks handling of runtime-log lines in the global access.log" row (15-39 report S7 falsified geometrikks.nix's comment) — confirm parser drops them / fix comment.
15. **[ready] geometrikks response-time condition**: the registry check carries `[RESPONSE_TIME] < 1000`; cold `du`-heavy collection days may flap — watch or widen (cheap).

**Adjacent queued items I touched or read this session (no new research):**
16. **Caddy double-logging check** [ready, services S7] — global vs per-vhost logs, roll bounds; geometrikks consumes the per-vhost set.
17. **Derive post-deploy `AUTH_VHOSTS` from the integration registry** [ready, pipeline] — hand-copied registry data is a drift bomb; geometrikks' eval-derived log paths are the in-repo model.
18. **Unformatted-commit path gating** [ready, pipeline] — geometrikks.nix + 3 scripts landed pre-`nix fmt` historically; my module passed the formatter clean this session, the root cause is still open.
19. **go-nix-helpers own-pinned consumer sweep** [ready, pipeline] — 4 independent lock nodes hold pre-fix `7c06ddc8`.
20. **Bank-Sync Wise SCA approval** [blocked:user] — re-armed 09-30; smoke stays red until post-approval restart.
21. **Health Hub post-deploy verification chain** [blocked:deploy].
22. **Hub cadence/timeout module options** [ready].
23. **indexer-web batch** (smoke/bring-up, ioTier, RESPONSE_TIME, VM test) [ready ×4].
24. **InboxClean upstream push + flake bump + deploy** — auth-command fix `1540a56` + dashboard banner `d23c48a` landed UNPUSHED upstream; deploy chain pending (AGENTS.md).
25. **NetBird Phase-2**: setup key into sops, then enable the gated client [blocked:user].
26. **Offsite Borg go-live inputs** (StorageBox hostname/username + host-key pin) [blocked:user].
27. **nix-email dmarc mailbox + sops paste** [blocked:user].
28. **Architecture-catalog go-live chain** (runner-PATH generation deploy → setup script → first CI → sops token → deploy → first sync).
29. **Monitor365 re-enable decision** (wireguard-collector publication path) — owner decision.
30. **DiscordSync Turso**: plan upgrade vs permanent local-only — owner decision encoded either way.
31. **Pocket ID groq-key warn** (CV chat config): wire a key or disable the provider — standing owner decision.
32. **Disk-cleanup P1–P6 owner-gated rows** (2026-09-28 proposal; ~366GB btrfs-level attribution).
33. **Samsung boot-mirror**: owner reboot + read-only post-reboot proof (`BootCurrent == 000C`) — activation landed 09-30, reboot pending.
34. **CV lock unlock**: upstream go_1_27 floor fix → probe `goModules` → drop the branch-ref hold.
35. **llama-rag root-cause** (unit-context spin on the pinned build; soak under REAL units ≥10 min before any re-enable) + re-enable decision.
36. **Freeze-7 residuals**: scrub timers `Persistent=false` + serialization chain (queued in stability).
37. **Hot-DB five migration waves** (owner sudo windows; vehicle + monitoring landed).
38. **flm held at v1.0.2**: the bump-validation discipline (live-serve + re-pull) whenever a bump is attempted.
39. **memory-emergency-guard + sev1 batch deploy** — landed in-tree 09-28/29, deploy pending (VM test executed green 09-30).
40. **Pre-commit GC-evicted input-source eval breakage root cause** [queued pipeline].
41. **Miniflux**: prove one live SSO login before flipping `disableLocalAuth` (AGENTS.md gate — still open).
42. **miniflux/cvim OIDC linking parity**: geometrikks now auto-resolves subs; miniflux's `oidcLink` converges an FK column — a shared "Pocket ID sub resolution" helper could serve both + future Layer 1 services (refactor, ROADMAP fuel).
43. **Pocket ID groups as an alternative gate** (`OIDC_ALLOWED_GROUPS`): if per-service restrictions are ever wanted, declarative group provisioning beats per-service sub lists (design note only).
44. **`AGENTS.md` SSO-layer table refresh** [ready, pipeline] — the table I read omits 4+ Layer 1 services.
45. **Fixtures for the other `-oidc-`/`-setup` scripts**: miniflux-oidc-setup, forgejo-oidc-setup, browser-history-oidc-setup share the shape (root sqlite reads, charset guards) and have the same no-fixture exposure — generalize the fixture pattern once, apply N times.
46. **post-deploy smoke for pocket-id-provision-dependent bridges generally**: the dnsblockd/cv/browser-history/forgejo/geometrikks bridges all break "silently until login" — one generic auth-surface smoke (discovery 200 + client-secret file exists + consumer env parsed) would cover the class.
47. **Daemon commit-message heuristics**: when a sweep mixes sessions, the losing session's narrative should get a follow-up `docs:` commit pointing at the report (cheap attribution repair; this session did it via CHANGELOG + report — could be the convention).
48. **`checks.geometrikks` VM test**: geometrikks has no VM test at all (pre-existing); the shared-PG + extension + OIDC bridge chain is assertable on the test-cv shape (heavy; ROADMAP fuel).
49. **Pre-deploy §10/§13 geometrikks entries** — the smoke-probe work (item 2) should ride the same pre-deploy enable-gated block pattern (metrics/units absent → SKIP cleanly).
50. **Session-resume hygiene (meta)**: this session resumed ~9h later mid-task; the report timestamp convention (run `date` immediately before creating) correctly produced an 01-04 filename for 09-30 work — the session gap should be stated in the filename or header (done here) so annotations don't mis-date the work.

## g) Questions I can NOT figure out myself

1. **Trust boundary**: I implemented "every ENABLED Pocket ID user passes the geo allow-list" (the literal ask). Confirm that's the intended trust model for geo analytics (LAN-only UI, Layer 1) — or should it be restricted (e.g. only your account), in which case I switch the resolver to a declared username/user list instead of all-enabled-users?
2. **`oidc.allowedUsers` future contract**: with subject ids auto-appended, the configured email entries + the `!= []` assertion are belt/explicit-intent. Keep that (my current state), or trim the option to a pure fallback (empty default, assertion removed/moved to the bridge)? This is a public module-option semantics change, so it's yours to call.
3. **`email_verified` belt**: do you want your Pocket ID user's email flipped verified (admin UI toggle, one click, makes the email allow-list entry real), or leave it false so the subject-id path remains the single honest gate?

---

## Harvest accounting (per the AGENTS.md status-report rule)

- Landed at authoring time: §f items 1–3 (go-live row update [earlier this session], smoke-probe row extension, new fixture-check pair — TODO_LIST + `docs/todo/services.md`, no-drift) + item 4 (CHANGELOG, done not queued).
- Deliberately NOT harvested: §f items 5–50 — brainstorm/ROADMAP fuel (owner decisions, pre-existing queued rows already owned elsewhere, or design notes) awaiting triage. No vague/long-term items were pushed into the queue.

## Commit trail (for archaeology)

| Hash             | Content                                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------- |
| `6f37b5f5`       | geometrikks.nix v1 (resolver + bridge + unit wiring) — daemon heuristic message                         |
| `0da82794`       | my AGENTS.md edits MIXED with parallel session's caddy/integration/networking (not amended, per policy) |
| `432e193e`       | geometrikks.nix mktemp fix + my two doc files MIXED with parallel session's caddy.nix                   |
| `dfdd83b6`       | my CHANGELOG entry MIXED with parallel session's AGENTS.md buildcache edit                              |
| (pending daemon) | this report + the harvest edits (TODO_LIST, docs/todo/services.md)                                      |
