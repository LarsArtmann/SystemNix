# Status Report — Mail Relay SPF Misdiagnosis: Cross-Repo Investigation + Correction

**Date:** 2026-09-21 17:02 CEST
**Session scope:** Two turns — (1) TODO-services-library triage summary (conversational, no artifacts), (2) "What is the Mail relay SPF problem?" → cross-repo investigation (`SystemNix` vs `domains`), live-DNS verification, and correction of a WRONG go-live instruction in 4 SystemNix docs.
**Repo pin:** HEAD `0b646899` at write time (auto-commit daemon active; parallel session live — an untracked `docs/status/2026-09-21_16-34_hot-db-phase2-session-closeout-self-review.md` from another session was present and left untouched).
**Format note:** Skill default is a styled HTML dashboard; the user explicitly requested `.md`. One-off override, not a new default.

---

## Executive Summary

The mail-relay go-live has been blocked since 2026-09-18 on a user step that is **wrong**: "REPLACE the apex `v=spf1 -all` SPF record with Resend's include." Investigation this session proved the SPF architecture is already **complete and deliberately so** — Resend's forge onboarding verifies SPF via ROUTING SUBDOMAINS (`send`/`rsend` CNAMEs, live, carrying valid SPF), and the apex lockdown record is the domains repo's intentional non-sending-domain hardening (onboarded 2026-09-06, commit `318affa`, since applied). Replacing the apex SPF would have **weakened** the domain while fixing nothing. Four SystemNix docs corrected; the remaining go-live work is now just: confirm "Verified" in the Resend dashboard + one non-owner delivery probe.

---

## a) FULLY DONE

| # | What | Evidence | Scope |
|---|------|----------|-------|
| A1 | Live-DNS verification of the ENTIRE Resend record set for `larsartmann.cloud` — apex TXT, DKIM, both SPF-routing CNAMEs, DMARC, MX | `dig` (2026-09-21 ~16:55): apex `"v=spf1 -all"`; `resend._domainkey` TXT present; `send` → `send.forge.rmta.net.` (its TXT: `v=spf1 ip4:52.3.252.119 ip4:44.222.39.36 ip4:199.249.231.0/24 ~all`); `rsend` → `rsend-euw1.forge.rmta.net.` (its TXT: `v=spf1 include:amazonses.com ~all`); `_dmarc` = `p=reject; sp=reject; adkim=s; aspf=s`; no MX (correct) | `larsartmann.cloud` live DNS |
| A2 | Root cause identified: cross-repo stale claim. The SystemNix instruction contradicts the domains repo's DELIBERATE design — non-sending apex + SPF-routing subdomains, DKIM-aligned strict DMARC | `domains/docs/status/2026-09-06_02-52_RESEND-LARSARTMANN-CLOUD-ONBOARDING-STATUS.md` exec summary + `larsartmann.cloud.tf:24-30` (module `resend_larsartmann_cloud_apex`, commit `318affa`, git log confirmed; records now LIVE → the apply happened) | `domains` repo (read-only) |
| A3 | Correction landed in all 4 live SystemNix docs carrying the stale instruction | `AGENTS.md:418` (SPF CORRECTION paragraph replaces the wrong "must REPLACE" sentence), `docs/todo/services.md:18` (mail-relay go-live row — remaining steps reduced to dashboard-Verify + non-owner probe, with the NEVER-add-include-to-apex guard), `docs/services/mail-relay.md` go-live status block (rewrite of the "Status 2026-09-18" paragraph), `CHANGELOG.md:45` (`[Unreleased]` entry corrected) | 4 files |
| A4 | Post-edit completeness sweep — zero stale "REPLACE the apex SPF" instructions remain in live docs | grep over `AGENTS.md`, `TODO_LIST.md`, `CHANGELOG.md`, `docs/**/*.md` (non-archived): only my correction text matches; `docs/reviews/2026-08-19` "spf" hits are `spf13` Go-library false positives | repo-wide |
| A5 | TODO-library triage answer delivered (turn 1): user-gated items ([blocked:user] top-priority digest) vs agent-ready ([ready] candidates) separated | Conversational; no artifacts intended | `docs/todo/services.md` (read-only this turn) |

---

## b) PARTIALLY DONE

| # | What works | What remains | Blocker | Effort |
|---|-----------|--------------|---------|--------|
| B1 | The stale claim is purged from all LIVE docs (a3/a4) | **`docs/status/2026-09-18_01-14_task-000001a0b198bd1f03092342367c3abb9951.md`** — a NON-archived status report (lines 23 + 115) still carries "USER: replace `v=spf1 -all` SPF record at registrar" UNANNOTATED. Per skill doctrine status reports are snapshots → needs `docs-health` ANNOTATE (EOF appendix or inline note), never a rewrite | Only the "write report then wait" instruction; one grep away | S |
| B2 | Mail-relay go-live is now a 2-step user checklist: (1) confirm "Verified" in Resend dashboard, (2) non-owner delivery probe | Verification state is dashboard-only — DNS-complete does NOT prove Resend flipped the flag; the accepted-250 may be the owner-address allowance (indistinguishable from postfix; only a non-owner delivery decides) | External dashboard + a non-owner inbox = user-gated | S |
| B3 | The correction makes the existing "[watch] Mail-relay non-owner delivery probe in post-deploy-check" backlog item directly actionable once Verified | That probe is NOT built (no post-deploy-check section, no smoke step) | Waiting on Verified + address choice | S/M |

---

## c) NOT STARTED

| # | What | Why not started | Still wanted? |
|---|------|----------------|---------------|
| C1 | Postfix `status=bounced` journal-rate textfile metric + Gatus check (standing `[ready]` item) | Pre-existing backlog, untouched this session; my correction neither builds nor blocks it | Yes — it is the journal-side signal that would have caught the 550 era faster and will catch any post-verification bounce regression |
| C2 | Harvest of this report's section (f) into `TODO_LIST.md` / `docs/todo/services.md` | Skill loop-closure step; user said "then wait" | Yes — else items die in this timestamped file |
| C3 | Any Nix evaluation / flake check of my edits | Docs-only session — no config surface touched; eval would prove nothing | No (N/A) |
| C4 | Cross-repo sweep for OTHER stale registrar-DNS instructions in SystemNix docs (pocket-id SMTP go-live also waits on the same "Verified" flag — its docs are ACCURATE as written, no stale SPF claim found, but a systematic sweep was not run) | Out of session scope per user instruction | Yes — cheap, see (f) |

---

## d) TOTALLY FUCKED UP

Radical honesty section — the most valuable one.

| # | What's wrong | Severity | Root cause | Mitigation |
|---|-------------|----------|-----------|------------|
| D1 | **A wrong, actively harmful go-live instruction shipped in SystemNix docs for 3 days** (2026-09-18 → 2026-09-21): "REPLACE the apex SPF record with Resend's include (do not keep `-all` alongside it)". Had the user followed it, the domain's spoofing hardening would have been WEAKENED (apex-SPF pass for mail from ANY SES-aligned sender) while fixing nothing — Resend's forge flow never checks apex SPF | Medium-High (wrong user instruction pending execution; zero damage — the live record is intact) | The 2026-09-18 session gathered DNS evidence (apex `-all`, DKIM present, no MX) but never dug the `send`/`rsend` SUBDOMAINS and never looked at the sibling `domains` repo that owns the record set; it read Resend's dashboard framing ("SPF unverified") as an apex-record requirement | Fixed this session (A3); correction text now names the NEVER-do (never add `include:amazonses.com` to the apex) |
| D2 | **The misdiagnosis survived two later doc passes** — the 2026-09-18 window closeout AND a 2026-09-19 task report both repeated "replace SPF" without cross-checking the domains repo. The class: SystemNix sessions treat DNS as "registrar-owned, external" and never cross-check the sibling Terraform repo even for `.cloud`-domain claims | Medium (recurrence risk for the NEXT DNS-coupled claim) | No cross-repo pointer doctrine exists; nothing in SystemNix AGENTS.md says "DNS facts about LarsArtmann domains → check `/home/lars/projects/domains` first" | (e) E1 proposes the one-line doctrine; (f) item 7 |
| D3 | **My own first verification grep was the false-clear pattern**: after the 4 edits I verified "no stale claims remain" over 4 hand-picked files + a `docs/`-scoped grep that missed root files and non-archived status reports on the first pass. The second, wider sweep caught the unannotated 2026-09-18 report (B1). No false "all clear" was published to the user, but the first grep WOULD have been one had I stopped there | Low-Medium (caught in-session, self-reported) | Assumed "status reports are archived" without checking; scoped the grep to what I remembered touching | Reported here; (e) E2 proposes the sweep-step habit |

**What I forgot (direct answer to the user's question):** the non-archived status report (B1/D3) — my correction pass covered live docs and mentally wrote off everything under `docs/status/` as historical, without checking the archived/ split. Also initially forgot to view files before editing (4 edit calls rejected, recovered by viewing first — harness enforced, no damage).

---

## e) WHAT WE SHOULD IMPROVE

| # | Pattern that's suboptimal | Impact | Concrete fix |
|---|--------------------------|--------|--------------|
| E1 | No cross-repo DNS doctrine: SystemNix claims about LarsArtmann-domain DNS records are made without consulting the `domains` Terraform repo (the authoritative record source) | 3-day wrong instruction; will recur for the next DNS-coupled feature (pocket-id SMTP, any future sending domain) | One line in SystemNix `AGENTS.md` (mail-relay section, done for SPF; generalize): "any DNS-record claim about a LarsArtmann domain MUST be checked against `/home/lars/projects/domains` (+ live `dig` of the EXACT records the provider names, including subdomains)" |
| E2 | Verification greps after doc corrections are scoped from memory, not systematically | False-clear risk (D3 nearly happened) | Habit: after a "claim X is wrong" correction, sweep `docs/status/` INCLUDING non-archived, root `*.md`, and `docs/reviews/` — not just the files you edited |
| E3 | `dig`-before-doc habit is missing: the wrong instruction would have died instantly if any session had run 4 dig commands (the two CNAMEs) instead of reading only apex TXT | Cheap insurance | When a mail-provider doc mentions SPF/verification, dig what the PROVIDER actually checks (subdomains, not just apex) |
| E4 | CHANGELOG factual-correction policy is undocumented | Next agent hesitates or reverts | One line in `docs/CONTRIBUTING.md`: correcting a factually wrong instruction inside an `[Unreleased]` entry is sanctioned; released entries get annotated instead |
| E5 | Go-live checklists drift into prose | The mail-relay row now mixes DONE and REMAINING inline | On next touch, renumber the runbook's remaining steps explicitly (1. dashboard Verify, 2. non-owner probe) and strike completed ones |
| E6 | Status-report skill's section (f) harvest loop routinely left unclosed across sessions (evidence: this repo's own status dir) | Items die in timestamped files | Run `docs-health` HARVEST right after each report (see skill's own closing rule) — including this one |

---

## f) Up to 50 things we should get done next

Scoped to this session's observations (mail/DNS/docs family). Ranked by impact; effort S <30min / M 30min-2h / L >2h. HARVEST: items marked ✅ → `TODO_LIST.md` / `docs/todo/*`; ⛔ → ROADMAP.

| # | Task | Impact | Effort | Category | Harvest |
|---|------|--------|--------|----------|---------|
| 1 | USER: open the Resend dashboard, confirm `larsartmann.cloud` shows "Verified" (SPF+DKIM green); if not, click Verify — DNS is fully in place, this should be a formality | Critical | S | Feature (user) | ✅ (mail-relay row already points here) |
| 2 | USER + agent: non-owner delivery probe once Verified — paperless share link or forgejo notification to an external (non-`larsartmann.cloud`) inbox; this is the ONLY test that distinguishes owner-allowance from full verification | Critical | S | Feature | ✅ |
| 3 | Annotate `docs/status/2026-09-18_01-14_task-000001a0b198bd1f03092342367c3abb9951.md` (EOF appendix): SPF instruction corrected, pointer to AGENTS.md:418 correction — kills the last non-archived stale carrier | High | S | Documentation | ✅ |
| 4 | If Verified + probe green: close the mail-relay go-live row in `docs/todo/services.md`, add CHANGELOG entry, update AGENTS go-live state to VERIFIED, retire the "pending signal" framing in the runbook's monitoring map | High | S | Documentation | ✅ |
| 5 | Re-click Pocket ID "Send test email" after Verified (AGENTS pocket-id section pending step) + update its docs if green | High | S | Feature (user) | ✅ |
| 6 | Build the non-owner delivery probe into `scripts/post-deploy-check.sh` (existing `[watch]` item — needs the verified state first; design: paperless share-link create + fetch, or a forgejo test notification) | High | M | Quality | ✅ |
| 7 | Postfix `status=bounced` journal-rate textfile metric + Gatus check (standing `[ready]` item; the 550-era blind spot) | High | M | Quality | ✅ (already in todo backlog) |
| 8 | Add the cross-repo DNS doctrine line to SystemNix AGENTS.md (E1) — generalize beyond mail-relay | High | S | Documentation | ✅ |
| 9 | Systematic sweep: grep SystemNix docs for OTHER registrar-DNS instructions/claims and cross-check each against the domains repo + live dig (pocket-id already checked clean; sweep mail-adjacent + geometrikks + anything mentioning DNS records) | Medium | M | Quality | ✅ |
| 10 | Run the domains repo's `dns-audit` for `larsartmann.cloud` post-verification + diff published-vs-committed DKIM string (its own report's B2/E4 suggestion, still open) | Medium | S | Quality | ✅ (domains repo) |
| 11 | Verify the domains repo's weekly drift-check covers the 3 new Resend records (its report's B1/E2 concern) | Medium | S | Quality | ✅ (domains repo) |
| 12 | Harvest this report (E6) — route (f) items into TODO_LIST/todo libraries before the next session | Medium | S | Documentation | ✅ |
| 13 | Add CHANGELOG-correction policy line to CONTRIBUTING (E4) | Low | S | Documentation | ✅ |
| 14 | Renumber mail-relay runbook remaining steps explicitly (E5) | Low | S | Documentation | ✅ |
| 15 | Immich SMTP admin-UI config (127.0.0.1:25, no auth) once the relay is verified (existing go-live step 5) | Low | S | Feature (user) | ✅ |
| 16 | Forgejo notification E2E re-test post-verification (part of probe 2; listed separately so it isn't lost if the paperless probe lands first) | Medium | S | Feature | ✅ |
| 17 | Consider DMARC `rua` reporting on the strict-reject domains (spoof visibility; domains repo ROADMAP item 20) | Low | S | Feature | ⛔ ROADMAP |
| 18 | 1024→2048-bit DKIM rotation request to Resend (domains repo C6, standing) | Low | S | Feature | ⛔ ROADMAP |
| 19 | Sweep `docs/status/` NON-archived reports for other stale cross-repo claims of the D2 class (any "external system rejects X" claim made without checking the owning repo) | Medium | M | Quality | ✅ |
| 20 | Document the non-sending+Resend coexistence pattern inside SystemNix mail-relay.md (one paragraph: why apex stays `-all`; currently only in the correction note) | Low | S | Documentation | ✅ |
| 21 | Cross-repo harvest check: confirm the domains repo TODO_LIST carries the apply/verify closure for `318affa` (its B1/C1 items may still read "not applied") | Low | S | Documentation | ✅ (domains repo) |
| 22 | Add a `dig`-the-subdomains step to any future mail-provider onboarding checklist template (E3, made concrete) | Low | S | Quality | ✅ |
| 23 | After verification: capture a fresh `status=sent` journal line + non-owner DSN as the go-live evidence pair, quote both in the closed go-live row (evidence discipline) | Low | S | Documentation | ✅ |
| 24 | Evaluate whether the "Mail Relay Queue" Gatus check needs a companion "bounced-since-deploy" condition once bounce metrics land (pairs with item 7) | Low | S | Quality | ⛔ ROADMAP |
| 25 | Decide CHANGELOG history policy question (g3) and record the outcome (E4 depends on it) | Low | S | Decision | ✅ |

---

## g) Questions I can NOT figure out myself

1. **Does the Resend dashboard show `larsartmann.cloud` as "Verified" (SPF + DKIM both green)?** What I tried: DNS is fully live and correct (A1), and the 2026-09-18 E2E send was accepted (250) — but acceptance is indistinguishable between "owner-address allowance" and "full verification" from postfix's side, and the flag lives only in Resend's dashboard. If NO → click Verify; the whole remaining go-live chain (items 2, 4, 5, 6, 15, 16) unblocks on this one answer.
2. **Which external inbox should receive the non-owner delivery probe, and may I trigger it once Verified?** Paperless share link, forgejo notification, and direct sendmail are all available surfaces; I need one non-`larsartmann.cloud` address and a go-ahead.
3. **CHANGELOG policy:** is my in-place correction of the `[Unreleased]` entry (current state, CHANGELOG.md:45) acceptable as the standing pattern for factually-wrong instructions, or do you want history-preserving annotations there too (correction appended, original text kept)?

---

## Session Appendix — Turn-by-turn

1. **Turn 1 (TODO triage):** user pasted `docs/todo/services.md` and asked "What do you need help with?" — answered with the user-gated digest (InboxClean re-consent, mail-relay SPF, miniflux SSO, paperless password, Hermes PAT, GeoMetrikks) vs [ready] candidates. No artifacts (conversational by design).
2. **Turn 2 (this work):** user asked what the mail-relay SPF problem is, pointing at `/home/lars/projects/domains`. Chain: `ls` + grep `spf1` in domains → read the 2026-09-06 onboarding status doc → `dig` the 6-record set → `dig` TXT on both routing subdomains → grep SystemNix for stale carriers → read exact texts → 4 edits → 2-pass verification sweep → this report.
3. **Harness note:** 4 first-round `edit` calls were rejected (read-before-edit rule); recovered by viewing each target region first — no damage. Commit skipped per Crush contract ("NEVER COMMIT unless asked"); the auto-commit daemon picks the file up.
