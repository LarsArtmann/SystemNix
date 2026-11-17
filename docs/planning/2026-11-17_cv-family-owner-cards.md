# CV Family — Owner Decision Cards (2026-11-17)

Four one-glance cards distilled from the 2026-11-15 CV health check's gated
items (Pareto plan T28/T29/T30/T44). Each card: the question, the options,
one recommendation. Nothing here blocks agent work — these are the four
items that cannot move without you.

---

## Card 1 — CV analytics database (T28, services.md:640)

**Question:** provision a Turso/libsql analytics DB, or accept the permanent
`database` intentional-absence warn on health.home.lan?

| Option | Effect | Cost |
| --- | --- | --- |
| A. Accept the warn (status quo) | `/health` stays 200-warn; analytics features stay dark; zero new moving parts | permanent warn noise on the health hub |
| B. Provision Turso + set `database.url` | analytics features live; warn clears | Turso account/db creation is yours; **configured-but-unreachable PANICS cv-server at every boot** — the DB must answer reliably or the CV site dies |

**Recommendation:** B only if you want the analytics features; a provisioned
external DB is a new boot dependency for a currently-healthy service. If the
analytics features have no near-term consumer, A is the honest choice and the
row closes as `won't-implement (2026-xx)`.

**If B:** fleet Turso-creds precedent lives in `discordsync.yaml`; wire
`CV_DATABASE_URL` via a sops template the same way.

---

## Card 2 — CV graphrag provider (T29, services.md:641)

**Question:** enable graphrag (pick the embedding provider) or accept the
permanent `graphrag` warn?

| Option | Effect | Cost |
| --- | --- | --- |
| A. Accept the warn | zero work | RAG features stay dark |
| B. Enable with go-graph-rag's LOCAL hash embedder | graphrag on, zero new deps | weak semantics — hash embedding is the toy tier |
| C. Enable via openaicompat embeddings (llama-rag bge-m3 :8848) | real semantics | llama-rag is config-DISABLED until the freeze-5 upstream bisect clears — C is blocked on that row |

**Recommendation:** A now, C later. Enabling B would let a weak embedder seed
the graphrag store with low-quality vectors you would re-embed later anyway.
Revisit C when the llama-rag bisect row clears.

---

## Card 3 — Portal seeding walkthrough (T30, T31; probe exit-3 context)

**Why now:** `cv-profile-probe` failed exit-3 on both Mondays (11-09, 11-16
09:41): freelancermap + gun.io sessions invalid and the credential store
UNSEEDED — the probe pages weekly until you seed once. The relogin loop
(daily 09:11) is live but WARN-skips all three platforms for the same reason.

**The store is empty and only YOU can fill it** — the admin UI is the sole
write path (the store SDK exposes no create/rotate API), so this is a human
act by design. Exact clicks:

1. Open `https://cv.home.lan/admin/credentials/` (Pocket-ID passkey).
2. "New credential" → platform slug EXACTLY: `ateam`, `freelancermap`,
   `gun.io` (the loop matches slugs, not display names).
3. kind `password`; username = the portal login email; secret = the portal
   password (form field only — never shell/CLI/chat).
4. Save. Within one collector window (≤6h)
   `cv_stored_logins{platform="<slug>",kind="password"} 1` appears in
   `/var/lib/prometheus-node-exporter/textfile_collectors/cv-credentials.prom`.
5. No deploy needed — the next 09:11 run picks it up; the following 09:41
   probe should flip exit-3 → green.
6. Rotate later = re-seed the row (no in-place rotate API yet).

**Post-seed proof checklist (T31):**
- [ ] `cv_stored_logins{...} 1` for all three slugs in the textfile.
- [ ] `journalctl -u cv-relogin -n 10` shows `→ refresh` per platform (not
      `skip(unseeded)`) and `<stateDir>/data/accounts/<platform>/state.json`
      mtimes advance.
- [ ] Next Monday's `cv-profile-probe` exits 0 (exit-3 pages stop).

---

## Card 4 — /health federation poll cadence (T44, monitoring.md:190 adjacent)

**Question:** the go-health federation poller runs at 2 Hz and journals one
INFO line per poll per remote — detection freshness vs journal volume.

**Numbers:** 2 Hz × 1 line × N remotes ≈ 172k lines/day/remote; at 5 fed
remotes that is ~860k journal lines/day from health polls alone.

| Option | Freshness | Volume |
| --- | --- | --- |
| A. Keep 2 Hz as-is | sub-second detection | ~860k lines/day |
| B. Drop the poll to 0.2 Hz (5s) | ≤5s stale detection — still far inside any alerting window | ~86k lines/day (10×) |
| C. Demote the per-poll line INFO→debug upstream | unchanged | ~0 at info level |

**Recommendation:** C + B upstream (log level change + interval default),
needing one small go-health/cvagent change; if you want zero upstream work,
A is defensible — journald compression absorbs it and the vacuum gate already
guards the evidence window.

---

*Prepared by the 2026-11-17 Pareto-plan execution session. Sources:
docs/services/cv.md (seeding §), services.md:640/641, status report
2026-11-15_14-35 §env-26. The cards are snapshots — the queue files own the
living state.*
