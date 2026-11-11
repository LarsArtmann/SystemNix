# OpenSEO GSC unblocked agent-side: org-project OAuth client via legacy IAP API, sops keys landed, flags deployed, boot anchor repaired

**Date:** 2026-11-11 16:0x–17:4x
**Trigger:** owner pasted the live "Google OAuth client not configured" banner + the upstream self-hosting doc (`every-app/open-seo` SELF_HOSTING_GOOGLE_SEARCH_CONSOLE.md) with the directive "get as much done alone; ask only when gcloud truly can't".
**Follows:** docs/status/2026-10-26_15-04_synthetic-pivot-gcloud-project-better-auth-secret-landed.md (the previous session declared the consent-screen client "genuinely owner-console-only")
**Result:** GSC + AI features deployed and LIVE; residual = ONE console step + the Connect click (owner).

## a. Evidence table

| # | Claim | Evidence |
| - | ----- | -------- |
| a1 | gcloud/API paths exhaustively ruled out before the workaround | `gcloud alpha iam oauth-brands` absent (591.0.0); `oauthconfig.googleapis.com` retired (404 HTML on every path, org + no-org); IAP brands on no-org project → 400 "Project must belong to an organization" (openseo-evox2, storbi); IAP OAuth Admin deprecated (Jan 19/Mar 19 2026 turn-down) but still WRITABLE for org-anchored fresh-IAP projects |
| a2 | Brand + client created agent-side | `gcloud iap oauth-brands create` on `toms-343020` (org `helpless.ai`, 597408793327, parent-folder member, created 2022 = pre-cutoff) → brand `projects/411189549194/brands/411189549194`, applicationTitle OpenSEO, `orgInternalOnly: true`; first attempt with gmail support email failed INVALID_ARGUMENT — org brands require the Workspace support email (`lars@helpless.ai`) |
| a3 | Client + secret handling | `gcloud iap oauth-clients create` → `411189549194-giunklfghhpga89ieb3hvec1f1gemefr.apps.googleusercontent.com`; the create printed the secret to the transcript → rotated immediately via REST `:resetSecret` into a 0600 file (printed value dead; scratch files trashed); raw REST POST/PATCH for clients return Google HTML 404s while gcloud verbs work — gcloud routes differ, use gcloud |
| a4 | redirectUris NOT settable via API | client `describe` has no redirectUris field; PATCH → 404; `oauth-clients create` has no redirect flag, no update subcommand → console step is genuinely irreducible |
| a5 | sops keys landed without printing values | skill 2026-11-11 recipe: `AGEK=$(sudo -n cat …/ssh_host_ed25519_key \| ssh-to-age -private-key)`, `sops --set` twice with runtime-var values; verify via `--extract` shape checks (client id 71ch, secret `GOCSPX-` 35ch); census 5/5: dataforseo_api_key, better_auth_secret, openrouter_api_key, google_client_id, google_client_secret; scratch secret files trashed |
| a6 | Flags flip + eval green | configuration.nix `openseo = { enable; googleSearchConsole.enable; aiFeatures.enable; }`; `nix fmt --` clean; toplevel drv `f5njv4ck…` evals (sops-key-audit + validate wiring pass) |
| a7 | Deploy landed via the parallel session's run | my deploy hit the flock (code 13); the parallel audible-sync session's 16:38 deploy carried the same tree, first dying on THEIR `audible-sync-run` shellcheck (SC2095, 16:34 code 1) then exit 0 at 17:28:20 after 3005s |
| a8 | Post-deploy state live | `/run/secrets/rendered/openseo-env` = 5 vars (BETTER_AUTH_SECRET, DATAFORSEO_API_KEY, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, OPENROUTER_API_KEY); openseo restarted 16:50:49, active, 200s every 30s; validate gate green (service up = refusal would have crashed it) |
| a9 | UNANCHORED caught + repaired | post-switch `readlink /run/current-system` (aahs5p4b, the correct fresh toplevel) ≠ profile gen-1002 (f3jgwq68a registered 14:50:41 — STALE: pre-flags, pre-audible-fix); bootctl default pointed at the stale gen → a reboot would have reverted BOTH sessions' work; repair: `sudo nix build --no-link --profile …/system <live>` + `switch-to-configuration boot` → gen-1003 (current) ANCHORED ✓ |
| a10 | Boot chain verified post-repair | pre-reboot-check first run: §11 FAIL "mirror tree DIFFERS" → `systemctl restart boot-mirror-sync` (script-internal sudo) → 50 entries/248M mirrored OK 17:31:59 → re-run: **17 passed, 5 warnings, 0 failed — SAFE TO REBOOT** |
| a11 | Google-side project state | toms-343020: searchconsole.googleapis.com + iap.googleapis.com enabled; openseo-evox2: iap enable/disable round-trip left clean, Search Console API enabled (vestigial); `sys-26183086682055567139847818`: iap enabled, EXTRACT_URL brand untouched |

## b. Key discoveries (reusable)

1. **"Console-only" was wrong for org members.** Personal projects cannot create consent-screen brands via API (org-gate), but ANY org-anchored pre-2026 project with fresh IAP usage accepts `gcloud iap oauth-brands create`. The brand is `orgInternalOnly` — Internal consent screen: Workspace accounts only, no test users, no testing-mode 7-day refresh-token expiry, no unverified-app warning. Better posture than the External flow the upstream doc describes, at the cost of the gmail-account constraint (§d.2).
2. **gcloud ≠ raw REST on this surface.** Hand-built `POST …/oauthClients` and `PATCH …/oauthClients` 404 (HTML) on projects where `gcloud iap oauth-clients create` succeeds — gcloud hits different (live) routes. Always drive IAP OAuth admin through gcloud.
3. **Org brand support email must be a Workspace address** — gmail support email → INVALID_ARGUMENT on brand create.
4. **Client secrets print to stdout on create AND reset-secret** — rotate-on-create into a 0600 capture file when the create output touched a transcript; the printed value dies at reset.
5. **The deploy anchor gap is REAL and bit today**: a code-0 deploy left profile+boot-default 4h stale. The 2026-10-23 procedure ("wait for full process tree, compare by gen number") caught it exactly as designed; repair procedure worked verbatim. Investigation queued (§f.2).

## c. Residual owner work (the ONLY ask)

1. **Console redirect URI** — Console → APIs & Services → Credentials → "OpenSEO GSC" (project `toms-343020`) → Authorized redirect URIs → `https://seo.home.lan/api/gsc/oauth/callback` verbatim (scheme/host/port exact, no trailing slash). Without it the Connect click dies `redirect_uri_mismatch`.
2. **Workspace GSC access** — the brand is Internal: authorize with a helpless.ai account that has Search Console access to the target property. If the property is verified under a gmail account: GSC → Settings → Users and permissions → add `lars@helpless.ai` (Owner or Restricted is enough for read scopes) first.
3. **Connect** — OpenSEO (`seo.home.lan`) → Integrations → "Connect with Google" → pick the property. No weekly disconnects (Internal app, no testing-token expiry).

## d. Decisions

| # | Decision | Rationale |
| - | -------- | --------- |
| d1 | Host the OAuth client in `toms-343020`, abandon `openseo-evox2` | brand creation requires org membership; openseo-evox2 (lartyhd@gmail.com) has no org; toms-343020 is a 2022 scratch-named org project, least-prod-looking candidate; project choice recorded in openseo.md + configuration.nix comment |
| d2 | Land keys agent-side (file-captured rotation → runtime-var sops --set) rather than owner paste | owner directive "get as much done alone"; values never printed, never in history, never in repo docs |
| d3 | Do NOT flip flags before keys existed / do NOT stage a half-state | sops-key-audit makes eval FAIL on declared-but-missing keys → would have blocked the parallel session's deploys on a red master |
| d4 | Anchor repair targets the LIVE toplevel (aahs5p4b) | it contains both sessions' changes (GSC env render proves flags; audible fix proven by their green build); gen-1002 (14:50) predates both |

## e. Cost/attribution notes

- Daemon commits swept my files twice mid-session (29615ab95 = my flip+sops pair, clean; 48008e3e6 = my docs MIXED with the foreign `_forgejo-scripts.nix`) — no amend-forward on the mixed commit; all content is properly messaged via this report + CHANGELOG.
- Deploy storms: 5 deploy attempts across ≥2 sessions on nh's lock today (mine: 1 refusal; theirs: 2 refusals + 1 shellcheck failure + 1 success). Shared-claim-file row already queued by the parallel session (pipeline.md tail).

## f. Follow-ups (self-harvested at authoring time)

1. **Console redirect URI + Workspace GSC access + Connect** → queued `[blocked:user]` in TODO_LIST.md + docs/todo/services.md (the one owner ask; §c above).
2. **Investigate the deploy anchor gap: why did a code-0 deploy leave profile+boot-default on a 4h-stale generation?** → queued `[ready]` in docs/todo/pipeline.md. Suspects: nh profile-set step skipped/failed silently post-switch; or a cross-session activation interleave (the flock serializes deploy.sh, but a second `nh os switch` outside deploy.sh would not be blocked). Every future deploy's verify already checks this (anchor discipline), but a code-0 exit lying about the anchor is a deploy-infra bug worth a root cause.
3. **Secrets-runbook census follow-up from the 2026-10-25 report (§f.8: "verify openseo.yaml holds exactly 5 keys")** — SATISFIED today (a5 census 5/5); no new row.
4. **SAM live-turn test + post-enable memory watch** — already queued from the 2026-10-26 report (ai-stack/services rows); now unblocked by the AI flag being live; NOT re-queued (no drift — same rows).
5. **`sops-predeploy-gate` §19 live-host-key decrypt smoke proved the sudo-in-yolo path again** (SUDO-OK probe + anchor repair sudo runs) — matches the 2026-11-11 AGENTS.md exception; no doc change needed.

## g. What was NOT done

- The parallel audible-sync session's shellcheck iteration — theirs, landed in their deploys; not touched.
- ai-meter openrouter upstream re-add (separate `[ready]` row in ai-stack.md) — untouched, still open.
- GSC token-rotation hazard doc (better_auth_secret rotation orphanizes stored GSC tokens) — the 2026-10-25 §f.14 idea, still unqueued; folded into the residual row's context implicitly, NOT harvested (needs an owner-visible secrets.md note — deliberately left for the docs-health pass to avoid doubling this session's doc surface).
