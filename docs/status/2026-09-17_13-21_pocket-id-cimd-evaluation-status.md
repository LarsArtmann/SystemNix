# Status Report — Pocket ID CIMD Evaluation Session

**Date:** 2026-09-17 13:21 CEST
**Scope:** This session only — triggered by the user's question: *"Pocket ID 2.14.0 shows a new Application Configuration → OIDC → Client ID Metadata Documents setting. Could this make sense for our Pocket ID setup?"*
**Verdict:** CIMD stays **DISABLED** — it already was (live-verified), and the decision is now documented + eval-enforced.

> **Format override flag:** the status-report skill's canonical output is a styled HTML dashboard; this report is Markdown because the user explicitly requested `docs/status/<timestamp>.md`. Skill rule honored: user instruction wins, one-off override not propagated back into the skill.

---

## a) FULLY DONE (evidence cited)

| # | Work | Evidence |
|---|------|----------|
| 1 | **CIMD evaluated end-to-end → verdict: keep disabled.** It solves "clients we have no relationship with" (MCP dynamic client registration) — a problem we do not have: every OIDC client here is first-party, preregistered via `pocket-id-config.provision` with pinned callbacks + provisioned secrets. Risks if enabled: self-asserted client name/logo (phishing, draft §6.4), IdP-side SSRF surface (§6.5), and the URL allowlist being the **only** scope control because Pocket ID enforces no redirect-URI ↔ client_id-URL relationship (only wildcard/js/data-scheme rejection). | AGENTS.md SSO/OIDC section, "CIMD — deliberately DISABLED (decision 2026-09-17)" paragraph |
| 2 | **Upstream research:** CIMD introduced v2.13.0 (PR #1526, implements draft-ietf-oauth-client-id-metadata-document-01, MCP-driven); v2.14.0 added auto-grant APIs to CIMD clients (#1692) + ignore-unsupported-grant-types fix (#1682) + RFC 8414 auth-server metadata (#1685). | `gh release view` v2.13.0/v2.14.0, `gh pr view 1526` |
| 3 | **Source-level implementation audit (pocket-id/pocket-id):** gate = app-config key `cimdUrlAllowlist`, default `"[]"` = deny-all, fail-closed (`backend/internal/appconfig/model.go:69,174`); enforcement = public clients only (`token_endpoint_auth_method=none`), PKCE forced, `code` response type only, redirect URIs reject wildcards/relative/js/data schemes (`backend/internal/oidc/cimd.go`); well-known flag = `client_id_metadata_document_supported` ⇔ `len(allowlist) > 0` (`backend/internal/controller/well_known_controller.go:94-96,125`). | files fetched via `gh api` and read |
| 4 | **Env-mode semantics established:** `CIMD_URL_ALLOWLIST` env override is honored **only** when `UI_CONFIG_DISABLED=true` (env-only mode); our module sets exactly that (`pocket-id.nix:510`, prior SMTP session). App config is therefore ENV-ONLY in our deployment — the "Application Configuration" admin UI is inert. | `backend/internal/appconfig/service.go` NewService/GetConfig + module comment |
| 5 | **IETF draft read** (draft-01, March 2026, Parecki & Smith): flow, §6.4 phishing, §6.5 SSRF, §6.10 pre-registration pattern (= the enterprise way to ever enable this: exact URLs, never wildcards). | datatracker fetch |
| 6 | **Live verification:** `https://auth.home.lan/.well-known/oauth-authorization-server` → `"client_id_metadata_document_supported": false` on the deployed 2.14.0 — MCP clients don't even see support advertised. | curl-equivalent fetch, this session |
| 7 | **Declarative hardening landed:** `services.pocket-id.settings.CIMD_URL_ALLOWLIST = "[]";` added to pocket-id.nix (upstream-default-drift insurance), eval-verified: `nix eval …settings.CIMD_URL_ALLOWLIST` → `"[]"`. | commit `51cb393a` |
| 8 | **Documentation landed + conflict reconciled:** AGENTS.md CIMD paragraph corrected twice same day (my error, then a parallel session's independent correction — see d2/e1) and finally reconciled to state the actual tree state. | AGENTS.md line ~571, commits `7c7e9be7`, `51cb393a` |

---

## b) PARTIALLY DONE (what works / what's open / effort)

1. **Pocket ID 2.14.0 feature sweep — only CIMD evaluated.** Remaining unevaluated: multiple client secrets per OIDC client (#1679 — *directly touches* our provisioner's rotation assumption, `pocket-id.nix:100-101`), "hide apps without launch URL" (#3ca9a55), one-time access-code length change (touches `scripts/pocket-id-login-code.sh`), RFC 8414 metadata (only live-probed). Open: adopt/ignore verdicts per feature. Effort: M.
2. **Spec currency.** Read draft-01 (what Pocket ID implemented). Draft-**02** is the current latest — unread. Effort: S.
3. **fosite layer unverified.** The "allowlist is the ONLY scope control" claim is scoped to Pocket ID's own code. fosite (the OAuth library doing the fetch) was not audited — it could impose additional checks. Risk is nil while disabled; claim should be completed. Effort: S.
4. **MCP consumer inventory.** "No current CIMD consumer" is based on AGENTS.md knowledge (qmd MCP = stdio; Hermes mcp extras disabled), not an exhaustive enumeration of every MCP client config. Effort: S.

---

## c) NOT STARTED (planned / noticed, zero work)

1. **TODO_LIST/ROADMAP harvest** of this report's section (f) — waiting per instruction ("THEN WAIT").
2. **Post-deploy assertion** that `client_id_metadata_document_supported` stays `false` (one jq check in post-deploy-check auth section) — proposed, not written.
3. **`docs/services/pocket-id.md` runbook** — Pocket ID ops knowledge lives only in the (very dense) AGENTS.md SSO section.
4. **Multi-secret provisioner redesign** — blocked on b1 evaluation.
5. **pocket-id-backup-dir shadow-dir remediation** — found this session (see d1), not started.
6. **Release-notes sweep procedure** for Pocket ID bumps — 2.14.0 landed Aug 18; its features went unevaluated here until the user noticed the UI today. No procedure exists to catch this class.

---

## d) TOTALLY FUCKED UP

**Nothing is currently broken or burning from this session.** Two real findings, one latent, one self-inflicted-and-fixed:

1. **LATENT (pre-existing, found this session): pocket-id tmpfiles rule = the root-fs-shadow-dir class.** `pocket-id.nix` creates `/mnt/pool/backups/pocket-id` via `tmpfiles.rules` — the exact mechanism REMOVED for cv on 2026-09-02 ("nofail pool + tmpfiles-setup After=local-fs.target = root-fs shadow dir during DAS outages"). During any boot with the pool unmounted, tmpfiles creates the dir on the root fs; a stale shadow then sits masked under the mountpoint forever. **Mitigations already present:** `pocket-id-backup` carries `RequiresMountsFor` (line 628), so backups FAIL loudly during outages — no silent backup misdirection. Residual: root-fs junk + masked stale data if the rule predates the Aug 22–31 DAS outage (unverified). **Fix = cv-backup-dir pattern** (mount-gated oneshot creator, drop the tmpfiles line) + a user-run bind-view check for an existing shadow. Severity: Medium, latent. NOT fixed this session (report-then-wait instruction).
2. **MY OWN WRONG DOCUMENTATION (self-caught, fixed):** the first AGENTS.md CIMD note claimed the env pin was impossible and said "do not flip UI_CONFIG_DISABLED" — but the module **already sets** `UI_CONFIG_DISABLED = true` (line 510). Root cause: I wrote docs citing module internals without reading the full settings block of a 709-line file (fragments only). Consequence chain: my wrong note → my pin commit (`51cb393a`, 13:18) vs a parallel session's independent doc correction ("keep env UNSET", `7c7e9be7`, 13:15) → ~4 minutes of committed doc/code contradiction → reconciled same hour. Runtime impact: none (both stances produce identical config).
3. **Not re-verified, out of scope:** pre-existing fleet issues (owed reboot, flm :52626 corpse, llama-rag config-disabled, Resend domain verification pending) are untouched and NOT re-checked this session.

---

## e) WHAT WE SHOULD IMPROVE (what I forgot / could do better / still improve)

1. **Read-before-doc-cite — the session's biggest failure.** I violated the repo's own READ-first doctrine by documenting module behavior from partial reads. Cost: one wrong doc, a cross-session contradiction, three extra commits. Rule going forward: never write "the module does/doesn't X" without a full-file read of that section first.
2. **`rg` self-inflicted failures ×3:** (a) `-r ln` — the `-r` REPLACE flag silently rewrote output, making me misread module names as `services.ln`; (b) `-rn` same trap on a verification grep; (c) unescaped parens in a pattern caused a false "paragraph missing" alarm mid-conflict. New personal rule: `rg -r` is radioactive; use `-F` for literals; suspect my own flags before the codebase.
3. **agentic_fetch broke all session** (internal `apierror` unmarshal ×3). Fallback (fetch + `gh api` git-trees walk) worked fine — should be a memory note, not an improvisation.
4. **`sudo` blocked in Crush shell** → no direct read-only SQLite probe of the live config. Achieved equivalent confidence via source + well-known endpoint; untried alternative: static API key + `GET /api/app-config`. The sanctioned live-probe paths for root-only surfaces should be documented once.
5. **Near-miss re-report:** I almost reported "SMTP env vars inert in UI mode" as a NEW finding — the module already solves it (`UI_CONFIG_DISABLED=true` + source-verified comment from a prior session). Rediscovering solved problems = read the whole file before claiming gaps.
6. **Parallel-session coordination:** my pin raced another session's doc edit and the daemon batched both into adjacent commits. The conflict was reconciled cleanly, but a `git log --since` check for concurrent edits to a shared doc before writing corrections would have avoided it.
7. **Version evidence hygiene:** deployed 2.14.0 taken from the user's screenshot footer; the nixpkgs lock rev wasn't cross-checked. Trivial, but it's the same verify-tool-output doctrine.
8. **No upstream-release feature sweep exists as a workflow step.** nixpkgs bumps silently deliver new upstream features; nothing prompts a per-release evaluation pass. (2.14.0 sat ~1 month before this session.)

---

## f) NEXT TASKS (30 grounded items — user asked "up to 50"; padding to 50 would be fabricated filler, so 30 honest ones, most are S-effort; per skill, items past #25 are ROADMAP-fuel and HARVEST must route rigorously)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Fix pocket-id-backup-dir shadow-dir class: replace tmpfiles rule with mount-gated oneshot (cv-backup-dir pattern) | High | S | Bug |
| 2 | User-run check for an existing shadow dir under the /mnt/pool mountpoint (bind-view trick; root fs) | High | S | Bug |
| 3 | **Review the parallel session's `github-auto-assign.nix`** (+164 lines, enabled in configuration.nix, commit `7c7e9be7`) — author flagged below in (g3) | High | S–M | Quality |
| 4 | Evaluate multi-secret OIDC clients (#1679) for provisioner rotation + the pocket-id-secret-rotation check | High | M | Feature |
| 5 | Verify provisioner secret API assumptions vs the 2.14 multi-secret surface (`pocket-id.nix:100-101` comment) | High | S | Quality |
| 6 | Verify `scripts/pocket-id-login-code.sh` against the 2.14 one-time-code length change | High | S | Quality |
| 7 | Arbitrate CIMD pin-vs-UNSET stance (g1); make doc + module agree on ONE | Medium | S | Cleanup |
| 8 | Post-deploy-check assertion: `client_id_metadata_document_supported == false` | Medium | S | Quality |
| 9 | Read fosite CIMD internals; complete the "allowlist is the only scope control" claim | Medium | S | Research |
| 10 | Sweep remaining 2.14 features (My Apps hidden-apps, RFC 8414, animated logo) for adopt/ignore verdicts | Medium | S | Quality |
| 11 | Confirm RFC 8414 endpoint is covered by existing auth-gateway/Gatus checks | Medium | S | Quality |
| 12 | Document MCP consumer inventory (crushrc mcp entries, hermes extras) with per-entry OAuth verdict | Medium | S | Documentation |
| 13 | Add "upstream release-notes sweep" step to the Pocket ID bump procedure | Medium | S | Process |
| 14 | Split `docs/services/pocket-id.md` runbook out of AGENTS.md | Medium | M | Documentation |
| 15 | pocket-id-backup restore-path test incl. post-2.14 schema | Medium | M | Quality |
| 16 | Read draft-02, diff vs draft-01 | Low | S | Research |
| 17 | VM test asserting the well-known CIMD flag stays false | Low | S | Quality |
| 18 | Add CIMD docs-page + PR #1526 links to AGENTS.md once the docs site is reachable | Low | S | Documentation |
| 19 | Grep-guard audit: reject non-`"[]"` CIMD allowlist / `UI_CONFIG_DISABLED` flips without a justification comment | Low | S | Quality |
| 20 | Track draft → RFC transition; update the AGENTS.md spec reference when numbered | Low | S | Documentation |
| 21 | IdP-neighbor survey (Authentik/Keycloak CIMD gating) to sanity-check the keep-off posture | Low | M | Research |
| 22 | Confirm `AUDIT_LOG_RETENTION_DAYS` is common-env, not an app-config field (no match in appconfig model this session — believed fine; one-line upstream confirm) | Low | S | Quality |
| 23 | Check whether `UI_CONFIG_DISABLED` hides the Application Configuration tabs or leaves inert forms (user-facing confusion risk — the user's screenshot showed the tabs) | Low | S | Documentation |
| 24 | Verify the pocket-id metrics surface post-2.14 (OTEL prometheus exporter unchanged; signoz scrape job still green) | Low | S | Quality |
| 25 | Memory/skill note: `rg -r` radioactive; `-F` for literal patterns | Medium | S | Process |
| 26 | Memory note: agentic_fetch fallback pattern (fetch + `gh api` git-trees walk) | Low | S | Process |
| 27 | Document the sudo-blocked limitation + sanctioned live-probe paths for root-only surfaces | Medium | S | Documentation |
| 28 | Habit: cross-check UI-reported versions against the nixpkgs lock rev | Low | S | Process |
| 29 | Harvest this section (f) into TODO_LIST/ROADMAP via docs-health | Medium | S | Process |
| 30 | Split the AGENTS.md SSO/OIDC section per-domain (navigation hazard at current length) | Low | M | Documentation |

---

## g) QUESTIONS ONLY YOU CAN ANSWER (3)

1. **CIMD pin stance — arbitrate:** the module now carries the explicit pin `CIMD_URL_ALLOWLIST = "[]"` (my stance: insurance against upstream changing the default; commit `51cb393a`), while an earlier same-day doc note preferred leaving it UNSET and trusting the fail-closed default. Runtime-identical today; I reconciled the docs to state both. Which stance do you want as the permanent one? *(I could not decide: two sessions picked opposite answers, and the difference is pure policy.)*
2. **Do you have a concrete near-term MCP-over-OAuth consumer** (Hermes mcp extras, ToolHive, Claude-style MCP clients) that would authenticate against Pocket ID? This is the single fact that flips the keep-disabled decision — the feature exists precisely for that case, and I cannot know your product roadmap.
3. **`github-auto-assign.nix` (+164 lines, enabled in configuration.nix, commit `7c7e9be7`) landed from a parallel session mid-conversation — yours/intentional?** Per the tree-sharing doctrine I flag it and don't co-verify it; if intentional, do you want a review pass (tests, eval guards, deployment state) scheduled for it?

---

**Awaiting instructions.** Daemon will auto-commit this file; no manual commit per Crush contract. Pre-existing fleet issues deliberately untouched and unverified (out of scope per instruction).
