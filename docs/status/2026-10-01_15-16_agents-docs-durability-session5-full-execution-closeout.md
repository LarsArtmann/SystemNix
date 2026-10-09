# AGENT-DOCS-DURABILITY-PLAN — Session 5: full execution closeout (T4–T12)

**Date:** 2026-10-01 15:16 · **Scope:** finish the durability plan's remaining waves (T4 runbooks → T12 mention sweep) after session 4's research stop · **Plan:** `docs/planning/2026-10-01_03-00_AGENT-DOCS-DURABILITY-PARETO-PLAN.md`

**Headline:** every non-gated task of the plan is DONE. 16 runbooks (the 10 named + 6 beyond-scope), 51 module pointers, cross-links, conservative superseded rewrites, the mention sweep, all queue/library closures — all checker-gated and committed. What remains is owner-gated by design (D1′/D2′/D2″/T7 folds) plus one deliberately deferred T11 remainder (row landed).

## a) What was executed

| Wave          | Work                                                                                                                                                                                   | Commit(s)                                                      | Verify                                                             |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------ |
| T4a/b         | `docs/services/pocket-id.md` + `oauth2-proxy.md`                                                                                                                                       | `05e72d12`                                                     | check-doc-links green                                              |
| T4c/d         | `signoz.md` + `immich.md` + **sso-dns layer fix**                                                                                                                                      | `b416ccbc`                                                     | check-doc-links green + eval-proof below                           |
| T5            | `twenty.md` `taskchampion.md` `dozzle.md` `openseo.md`                                                                                                                                 | `dfad9354`                                                     | check-doc-links green                                              |
| T6            | `crush-daily.md` `atticd.md`                                                                                                                                                           | `8905a3f0`                                                     | check-doc-links green                                              |
| Beyond-scope  | `gatus.md` `file-and-image-renamer.md` `overview.md` `nsfw-classifier.md` `visionreviewd.md` `website-deploy-monitor.md`                                                               | `e98e2a22`                                                     | check-doc-links green                                              |
| Post-backfill | AGENTS.md:25 claim updated; both queue+library rows closed                                                                                                                             | `92a461fc` + daemon sweep (TODO_LIST)                          | check-todo-system structure OK                                     |
| T9            | `# Runbook:` pointer line 1 in **51** service modules (aliases attic→atticd, dns-blocker→dnsblockd, gatus-config→gatus, tq-agent-pool→tq, netbird-client→net-vpn, crush-hot-db→hot-db) | `df99aaf4`                                                     | grep coverage probe: **100%**                                      |
| T10           | bidirectional links integration-registry step 9 ↔ monitoring.md patterns                                                                                                               | daemon `0c82c3c5` (swept mid-commit; content verified in tree) | T2 anchor checker green                                            |
| T11 (2 of 7)  | storage p9 bullet + systemd hot-user-caches bullet lead-with-truth rewrites                                                                                                            | `89b3c725`                                                     | zero fact loss (reorders, dates kept)                              |
| T12           | 16 stale `AGENTS.md` comment pointers → docs/agents/runbook targets; gotchas-archive header; 2 queue-row premises fixed in BOTH surfaces                                               | `89b3c725`                                                     | classification table §c; check-doc-links + check-todo-system green |

**Runbook count:** `docs/services/` grew 59 → 75 files (the .md set); every enabled service now has a runbook (AI-stack daemons live in `llama-rag.md` + the root GPU section — named in the updated AGENTS.md:25 claim).

## b) The immich layer discrepancy — resolved eval-verified (session-4 §f.48)

`immich.nix` sets `vHost.layer = "protected"` while the sso-dns Layer 1 row listed Immich. Resolution: `nix eval` of the RENDERED evo-x2 caddy config shows `immich.home.lan` carrying `forward_auth localhost:4180` for `@external` + plain proxy for LAN — the Layer 2 protected shape. Module + caddy.nix comment + eval agree; the sso-dns table was the stale surface. Fixed: Immich removed from the Layer 1 list, a hybrid footnote added (native OIDC in-app + protected routing; mobile app's `app.immich:///oauth-callback` is a native-OIDC flow that cannot carry forward-auth cookies — the ONE sanctioned exception to "native OIDC ⇒ plain reverse_proxy"), and the runbook documents the hybrid so nobody "fixes" either side without the other.

## c) T12 classification table (living surfaces; archived/plans/status are historical by definition)

| Surface                                                                             | Mentions                                           | Class              | Action                                                                                                                                |
| ----------------------------------------------------------------------------------- | -------------------------------------------------- | ------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `docs/agents/README.md`, banners in `docs/agents/*.md`                              | migration provenance                               | historical-correct | none                                                                                                                                  |
| `docs/README.md`, `docs/CONTRIBUTING.md`, `README.md`, `docs/security/rotations.md` | live pointers to the root routing core             | live-valid         | none                                                                                                                                  |
| root GPU section pointers (`gpu-active.nix`, `system-health.nix:72`)                | GPU Platform Constraints stayed in root            | live-valid         | none                                                                                                                                  |
| hermes/crush `AGENTS.md` refs (hermes.nix, tests, flake.nix, post-deploy-check)     | DIFFERENT files (workspace doc, crush config repo) | live-valid         | none                                                                                                                                  |
| 16 module/test comments ("See AGENTS.md rule/gotcha …")                             | sections moved 2026-10-01                          | **stale**          | retargeted to `docs/agents/{systemd,stability,monitoring,sso-dns,integration-registry,desktop}.md` or the owning runbook (`89b3c725`) |
| `docs/gotchas-archive.md` header + rule-9 row                                       | gotcha table dissolved                             | **stale**          | retargeted                                                                                                                            |
| TODO_LIST 523/567 + matching library rows                                           | premises name AGENTS.md sections that moved        | **stale premise**  | fixed in BOTH surfaces (queue+library drift rule)                                                                                     |

## d) Session-3 §f (37) + session-4 §f (50) disposition audit

- **Done this session:** s3 #1–20, #22–23, #28–31; s4 #1–25, #27, #30–43 (content obligations verified present in the runbooks), #44–49 (gated/watch/discipline honored).
- **s3 #21/24–27 (T11 ×5):** deferred — see §e (row landed).
- **s3 #32–34 + s4 #50 (decisions):** owner-gated; plan defaults stand; re-asked in §g + the new decision row.
- **s3 #35/#37 (watch):** standing (W1 = parallel session's scope; D3 on-touch default).
- **s3 #36 (watch `/` at 93%):** live re-check 15:16 → **94% used, 47G free** — still tight; repeated here as the standing watch.
- **s4 #26/29:** this report closes them.
- **s4 §g (3 questions):** carried into the new decision row verbatim.

## e) T11 deferral rationale (the new row's Source)

A marker scan (`SUPERSEDED|RETRACTED|CORRECTION|was WRONG|was STALE`) over all 7 files: explicit chains exist ONLY in systemd/storage/stability. nix-flakes/secrets/desktop/monitoring are marker-clean (subtle corrections only — fold on touch per D3). stability.md's DAS/freeze mega-bullets are incident FORENSICS: each retraction names its superseder inline; rewriting converts primary evidence into summary. Only an explicit owner order shifts that tradeoff. The two rewrites that DID land were chosen because both chains had a single final truth and no evidence value in the wrong claim (reorders, not deletions — no line-audit exemption needed).

## f) NEXT — self-harvested at authoring time

Per the TODO System rule, this report's §f direct follow-ups are landed, not deferred: (1) **T11 remainder row** → TODO_LIST + docs/todo/pipeline.md; (2) **owner-questions decision row** (D1/D2/D3 ratify, push policy, in-flight-claims governance) → both surfaces; (3) the stale-count row fix (53→drift-proof wording) was executed this session in both surfaces. Gated work (D1′ core slim, D2′/D2″ crush hook, T7a–e appendix folds) stays gated per plan; the fold backlog is the existing "21 appendices" row. Nothing else open from this session.

## g) Questions (standing, owner)

1. **Push:** all five sessions' work is local (public only via a parallel session's side-effect push) — order an explicit `git push` when wanted?
2. **D1/D2/D3:** ratify the plan defaults (34KB core, no hook, on-touch folds) or override?
3. **Governance:** formalize in-flight-row-claim collision handling, or is the AGENTS.md daemon-race discipline sufficient?
