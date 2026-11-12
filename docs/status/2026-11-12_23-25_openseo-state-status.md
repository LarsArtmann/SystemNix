# Status: OpenSEO (seo.home.lan) — LIVE on GSC+AI flags, one owner console step from data flowing

**Date:** 2026-11-12 23:25 CET
**Trigger:** owner question "What is the state of OpenSEO!?" — full state inventory of the service (not a whole-repo report).

## Scope

**VERIFIED live this session (2026-11-12 23:14–23:25):**
- `openseo.service` **active/running** (busctl `ActiveState/SubState`)
- Port **3002 listening** on 127.0.0.1 (ss)
- Journal: `GET / 200 OK` every 30 s cadence (gatus probes), latency 4–24 ms
- HTTPS vHost **200 OK** through Caddy (`openssl s_client` probe of seo.home.lan @ 192.168.1.150:443, `Via: 1.1 Caddy`)
- MemoryCurrent **171 MB** vs MemoryMax 2G — no throttle risk (llama-chat 410M class watch row §f.7 of the 2026-10-26 report: still comfortable)
- Flags in-tree: `openseo = { enable; googleSearchConsole.enable; aiFeatures.enable; }` (configuration.nix:1310-1314)
- sops census **5/5 key names present** in `platforms/nixos/secrets/openseo.yaml` (grep on names only, zero values read)
- Deploy anchor: `/run/current-system` == latest `system-1004-link` — the 2026-11-11 unanchored repair held
- Todo-row state re-read from TODO_LIST.md + docs/todo/{services,ai-stack}.md

**NOT verified this session (and why):**
- A real **SAM AI turn** through the synthetic.new upstream — no status report records one since the 2026-11-11 enable; end-to-end AI feature proof is still missing
- **GSC data flow** — structurally blocked on the owner console step (§b); nothing to verify until it lands
- Live **dashboard tile + gatus check** eyeball — the §g-migration watch row (services.md:612) predates the gen-997/1004 deploys and was never explicitly closed with a live eyeball; eval+rendered parity was proven 2026-10-26 5/5
- D1 database content — only its presence/size from the 2026-10-26 assessment (964K SQLite), not re-probed

---

## a) FULLY DONE

| Item | Evidence |
| --- | --- |
| **Packaging** — `pkgs/openseo.nix`, upstream v0.1.1, pnpm/Vite build, native NixOS service (no Docker), workerd runtime | builds green; pnpm hash re-pinned through the 2026-10-23 + 2026-11-12 vendorHash waves |
| **synthetic.new baseURL patch** — 1-line `postPatch` routes AI agents at synthetic.new instead of openrouter.ai (2026-10-25 owner decision, `syn:large:text`) | pkgs/openseo.nix:29-47, dated comment; live env `OPENROUTER_BASE_URL`/`MODEL` in the module |
| **Service module** — validate→stage→migrate→`vite preview` chain, StateDirectory D1, restartTriggers on package, telemetry off | docs/services/openseo.md; openseo-validate green (service refuses to start without feature keys) |
| **Hand-rolled Caddy vHost** — `/api/gsc/oauth/callback` exempt from forward-auth, rest Layer 2 | live 200 probe; doctrine pinned in sso-dns.md ("do NOT simplify") |
| **Registry fan-out** — subdomain `seo`, gatus check (5m), homepage tile (Productivity), `vHost.layer = "none"` | integration-registry.md matrix row; rendered parity proven 5/5 (2026-10-26) |
| **Secrets 5/5** — google pair landed agent-side 2026-11-11 via the toms-343020 org-project IAP workaround (secret rotated after transcript print); better_auth_secret, dataforseo, synthetic key | census re-verified this session; zero values ever printed post-rotation |
| **Flags flipped + deployed + anchored** — 2026-11-11, rode the audible session's 16:38 deploy; post-switch UNANCHORED anomaly repaired same evening (gen-1003 + boot entry + mirror resync + pre-reboot-check 17/0) | CHANGELOG 2026-11-11 entry; docs/status/2026-11-11_17-3x_openseo-gsc-gcloud-oauth-client-anchored.md |
| **Live service health** — active, 200s, 171 MB RAM, HTTPS green | busctl + ss + journal + openssl, this session |

## b) PARTIALLY DONE

| Item | State | What's missing |
| --- | --- | --- |
| **GSC integration** | Client "OpenSEO GSC" exists in `toms-343020`, env renders, feature enabled | **Owner console step (blocked:user):** register `https://seo.home.lan/api/gsc/oauth/callback` verbatim on the client (IAP API cannot set redirectUris) + authorize via a helpless.ai Workspace account with GSC access (orgInternalOnly — gmail CANNOT consent). Until then the app shows the "OAuth client not configured" banner and NO Search Console data flows. Rows: TODO_LIST:643 + services.md:616 |
| **AI features (SAM agents)** | Enabled, synthetic key live, requests route to `api.synthetic.new/openai/v1` | No verified end-to-end SAM turn post-enable — "re-verify SAM turns post-deploy" from the pkgs comment never recorded as done. Cheap agent-side probe: one chat-agent turn, confirm model attribution (`syn:large:text`) |
| **D1 backup** | Assessed 2026-10-26 with live state: `/var/lib/openseo/.wrangler/state/v3/d1/…` plain SQLite 964K; pocket-id `.backup` pattern transfers verbatim (~30 lines) | Adoption pending owner yes + retention answer (assessed → never materialized as a [ready] row) |
| **Tile-coverage §g migration** | Eval-side + rendered parity done; several deploys (gen-997 → gen-1004) since | services.md:612 [watch] row never closed with the explicit live eyeball (Services tab: OpenSEO + Taskwarrior tiles, live dots) |

## c) NOT STARTED

| Item | Row |
| --- | --- |
| Re-add ai-meter openrouter upstream + route openseo through the proxy (metering coverage) | TODO_LIST:1507 / ai-stack.md:48 [ready] |
| Mechanize the rendered-parity proof over the REAL render (checks derivation vs the fixture trap) | TODO_LIST:644 / services.md:614 [ready] |
| Paperless Tika/Gotenberg → nixpkgs services; OpenSEO feasibility (Sept arc) | TODO_LIST:2071 / services.md:833 [ready] |
| SigNoz rule: openseo unit restart loop (gatus covers down; thrash is a different signal) | 2026-10-26 report idea #16, never queued |
| io-tier re-check post-GSC-sync (writes change shape) | 2026-10-26 report idea #17, never queued |
| Upstream watch row (v0.1.1 → next; pnpm-hash churn every bump) | 2026-10-26 report idea #14, never queued |

## d) TOTALLY FUCKED UP

**Nothing live.** Service is green end to end at the infra level.

Two adjacent process warts, both already tracked:
- The 3-week "console-only" GSC dead-lock conviction — the OAuth client was gcloud-creatable all along (legacy IAP OAuth Admin API still writes for org-anchored projects). Fell in one session on 2026-11-11; the lesson (exhaust gcloud routes before declaring "console-only") is recorded in the status report + CHANGELOG.
- The 2026-11-11 deploy's **anchor gap** (exit-0 deploy left profile/boot-default 4h stale) was first caught on THIS service's deploy; root cause still under investigation — pipeline.md:1121 [ready] row.

## e) WHAT WE SHOULD IMPROVE

1. **Close the last mile of GSC** — the entire integration is one owner console paste + one Connect click away from producing data; nothing else blocks.
2. **Prove the AI feature once** — a single verified SAM turn with model attribution turns "enabled" into "working" (and de-risks the OPENROUTER-specific request extensions riding along to synthetic, flagged in the pkgs comment).
3. **Adopt the D1 backup** — assessment is done and the pattern is proven; ~30 lines mirrors pocket-id. SEO keyword/audit state is currently unbacked up.
4. **Meter the AI spend** — route openseo through ai-meter once its client-key permission fix lands; right now openseo burns synthetic tokens unmetered.
5. **Retire the fixture trap** — the mechanized parity check kills a recurring manual proof class.

## f) Top #25 things to get done next

Prioritized by impact. Items 1–15 are actionable; 16–25 are lower-rung hygiene.

| # | Item | Priority | Status |
| --- | --- | --- | --- |
| 1 | Owner: register GSC redirect URI on "OpenSEO GSC" (toms-343020) | High | blocked:user (TODO_LIST:643) |
| 2 | Owner: Connect with Google + pick property (Workspace account w/ GSC access) | High | blocked:user (same row) |
| 3 | Agent: one verified SAM turn post-enable, model-attribution checked | High | NEW ask this session (harvest note below) |
| 4 | Adopt D1 backup (owner yes + retention) — mirror pocket-id pattern | High | assessed, awaiting owner |
| 5 | Investigate the deploy anchor gap (gen-1002/1003 class) | High | pipeline.md:1121 [ready] |
| 6 | ai-meter client-key permission fix + deploy chain (prereq for #7) | High | ai-stack.md:43 [ready] |
| 7 | Route openseo through ai-meter proxy (restore upstream + cost entries) | Medium | TODO_LIST:1507 [ready] |
| 8 | Mechanize rendered-parity check over the real render | Medium | TODO_LIST:644 [ready] |
| 9 | Close the §g tile-migration [watch] row with a live eyeball | Medium | services.md:612 |
| 10 | Close services.md:612's monitor365 PSI-calm watch twin | Medium | same row |
| 11 | Paperless Tika/Gotenberg nixpkgs + OpenSEO feasibility | Medium | services.md:833 |
| 12 | SigNoz restart-loop rule for openseo | Low | idea, queue on next docs-health pass |
| 13 | io-tier re-check after GSC sync lands | Low | idea, same |
| 14 | Upstream watch row v0.1.1 → next (pnpm churn) | Low | idea, same |
| 15 | Native-OIDC expansion for OpenSEO (Layer 1) | Low | ROADMAP material — deliberately not queued |
| 16-25 | Fleet hygiene this service rides: vendorHash/pnpm-hash churn on every nixpkgs bump (3 files re-pinned 2026-11-12), §16 tile-icon inventory green, anchor-discipline verify after every deploy, pre-vacuum §15 gate, registry matrix drift check, sops predeploy §19 gate, script-port-audit, memory-watermark audit, tile-coverage assertion, boot-mirror path trigger | Low | all standing fleet gates, green |

**Harvest note (AGENTS.md self-harvest rule):** #3 (SAM-turn verification) is the only genuinely new ask — minted below into TODO_LIST.md + docs/todo/services.md. Everything else #1–#15 already lives in its queue row; no duplicates minted.

## g) Top #1 question I cannot figure out myself

**Which Google account holds the GSC properties OpenSEO should track — `lartyhd@gmail.com` or `lars@helpless.ai`?** The org-internal consent screen FORCES a helpless.ai Workspace account, so if the properties verify under the gmail account, they must first be delegated to lars@helpless.ai in GSC Settings → Users — otherwise the Connect flow succeeds but the site list comes back empty. (Still open since the 2026-10-26 report §g.1; also parked there: the artmann.tech fallback if Google ever refuses `.lan` origins — the redirect URI registration is accepted for internal apps, so this looks moot unless the console rejects it.)
