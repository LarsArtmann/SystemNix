# 2026-11-13 15:3x — four failed units investigated: 1 root-cause fixed (signoz-provision v8), 2 by-design gates confirmed, 1 escalation minted

## a) Task & verdict

Task: investigate the owner's health census (`forgejo-github-sync`, `inboxclean-sync`, `service-health-check`, `signoz-provision` all `failed`) — READ/RESEARCH/EXECUTE/VERIFY per unit.

**Verdict: 1 fixed in-tree (signoz-provision), 2 confirmed by-design owner gates (forgejo-github-sync, inboxclean-sync), 1 derived-by-design (service-health-check). All four attributed; every finding landed in its owning row; three stale script surfaces swept alongside the main fix.**

## b) Per-unit ledger (live-verified via journalctl + busctl-class reads)

| Unit | Live signature | Root cause | Disposition |
| --- | --- | --- | --- |
| `signoz-provision` | 11:28 run: every rule-create 200s interleaved with `jq: parse error … col 10`, dies exit 5 at "Verifying rule convergence" | The 2026-11-12 signoz package move (d00471c) removed the v1 rules routes — `GET /api/v1/rules` now serves the SPA index.html (200 HTML); jq died at `<!doctype` and errexit propagated exit 5. **Also:** `ok()` counts any 2xx, so the run's "OK rule created (HTTP 200)" lines were PHANTOM greens (SPA HTML) — nothing was created after the move | **FIXED in-tree** (provisionScript v8, see §c) |
| `forgejo-github-sync` | 14:33 run: ALL legs green (455 repos/0 failed, re-interval 476 at-target, avatars 0 failed) except `✗ dnsblockd: still a PULL mirror — refusing (flip first: sudo systemctl start forgejo-flip@dnsblockd.service)` → exit 1 | The forgejo-flip@dnsblockd precondition gate (services.md:1086 row) — fails loudly BY DESIGN until the owner executes the flip | By-design owner gate; also ANSWERS the open `[ready]` "exit-1 with all-green sub-steps" triage row (the mystery leg after forgejo-push-mirror IS this refusal) — row ticked both surfaces |
| `inboxclean-sync` | Every 30-min tick: `main` skipped (`invalid_grant` — owner re-consent owed) + `work` TEMPFAIL `gmail.list_history.rate_limit` 429 (exit 75, retryable, start_history_id pinned) | Two-layer: main = revoked grant (owner re-consent, row services.md:61); work = sustained quota loop — **4 consecutive day boundaries exceeded** (202/182/161/106 hits Nov 10→13; each tick burns the quota it needs; retry-after answers ~45 min stale yet still 429) | Escalation minted per the watch row's own clause: upstream backoff row (upstream.md + TODO_LIST twin) + testing-mode-quota hypothesis (same root as the 7-day token bomb) noted; watch row updated |
| `service-health-check` | 14:47 run lists exactly the failed units + `nextd-refresh.service (user, failed)` | Exits 1 listing failed units — it is the paging mechanism, metastable-red while any monitored unit is red | By design; heals when the others heal. NEW names seen in its list: `browser-history-agent` (exits 1 after a sync with `accepted:0 rejected:2` — rejection-as-failure contract question, row minted) and `nextd-refresh` (user unit, not a repo unit — flagged to owner only) |

## c) The fix (signoz provisionScript v7 → v8)

- List: `GET /api/v3/rules?limit=100` + truncation guard (fail, not converge-blind, if `data.total` > returned count).
- CRUD: `GET/PUT/DELETE /api/v2/rules/{id}`, `POST /api/v2/rules` (v3 is list-only; verified at the locked rev `pkg/apiserver/signozapiserver/ruler.go` + live probes).
- **`rule_to_v2` jq converter (load-bearing):** mirrors upstream `sqlmigration/145_migrate_rules_v1_to_v2alpha1` — threshold name = severity label (default critical), channels = preferredChannels, evaluation relocated, notificationSettings synthesized, `schemaVersion: "v2alpha1"`. The repo's rule files are still flat-v1 postable format and would 400 on the v2 write path ("schemaVersion: unsupported value") — without conversion the fix would have traded a jq death for a 400 death.
- Canon-compare now per-id v2 GET (the v3 list is summary-only — no condition/evaluation — the old canon could never match it); the converger stays notification-silent on unchanged runs.
- Route-policy + channels phases untouched: `/api/v1/route_policies` and `/api/v1/channels` verified ALIVE with unchanged response shapes.

## d) Verification ledger (all live this session)

| Check | Result |
| --- | --- |
| Converter vs live migrated rules | **3/3 canon-EXACT** (`ai-upstream-failure-rate` warning/10m, `clickhouse-down` critical/below/1m, `cv-credentials-scrape-broken` critical/30m) — byte-equal through the canon projection |
| Full system eval | `nix eval …evo-x2…toplevel.drvPath` rc=0 post-edit |
| Script build | writeShellApplication build rc=0 (shellcheck gate) |
| Rendered script (store) | `api/v1/rules` ×0, v3 list + v2 CRUD + converter present, v8 header |
| Smoke probe jq | `.data.total // (.data.rules \| length)` → 61 on live shape |
| shellcheck (3 swept scripts) | rc=0, zero findings |
| bash -n (3 swept scripts) | all OK |
| TODO gate | `check-todo-system.sh`: structure clean (46 unharvested WARNs = foreign sessions' reports, pre-existing drift) |
| Daemon commits swept my code | `532b0d615` = exactly the 4 code files (verified, nothing foreign); docs swept mid-edit into `0f64073c6` + this commit |

## e) What did NOT happen (honest scope)

- **No full green provisioner run yet** — the unit is a deploy-triggered oneshot; agents cannot start units (sudo dead in normal mode, busctl mutations polkit-denied). The v8 proof rides the next deploy's provisioner leg. Row updated to say exactly this.
- **forgejo-github-sync and inboxclean-sync stay red** — both need owner actions (flip execution; consent-screen production flip + main re-consent). service-health-check stays red with them, correctly.
- forgejo `exit 6/NOTCONFIGURED` row (2026-11-10→11) left untouched: today's runs fetch 455 repos fine, suggesting it's superseded by the f4a03c0 graph, but no positive proof it can't recur — not ticked without evidence.
- `verify-deployment.sh` + `test-fire-telemetry-export-alert.sh` were the same v1 class and unowned by any row — swept on sight (verify-deployment.sh had a 12-day stale-probe precedent).

## f) Follow-ups — HARVEST LEDGER (all landed this session)

1. signoz jq-parse row → fix-landed close-out on TODO_LIST + services.md twin — DONE.
2. post-deploy probe row → ticked + close-out on TODO_LIST + monitoring.md twin — DONE.
3. forgejo exit-1 triage row → ticked + ANSWERED on TODO_LIST + services.md twin — DONE.
4. inboxclean 429 watch row → ESCALATED pointer + upstream backoff row minted (upstream.md) + TODO_LIST twin — DONE.
5. browser-history-agent rejection-exit → new `[ready]` triage row (services.md) + TODO_LIST twin — MINTED.
6. CHANGELOG entry for the provisioner v8 wave — DONE.
7. Deliberately NOT harvested: `nextd-refresh` user-unit failure (not a repo unit; next-queue domain, flagged in §b).
