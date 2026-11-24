# Re-dispatch verify: the 30s :8099 /health poller identification

**Task:** 000001a20c17084f0876b78f8c4000000000 (batch item 1) — 2026-11-24 07:51

The dispatched row (TODO_LIST "Identify the 30s /health poller on :8099") re-fired work
already landed under task 000001a1f5d5 (2026-11-19/20): the poller is the PapDashboard
services-tile monitor — the InboxClean tile had `href https://inbox.home.lan` with
`checkUrl null`, and papdashboard's servicestatus Monitor probes the HREF itself every
30s (DefaultInterval 30s, probeTimeout 5s). Fix bbc450b03 pinned the tile checkUrl to
`http://127.0.0.1:8099/health` (modules/nixos/services/inboxclean.nix).

## Re-dispatch protocol outcomes

1. **Footers + queue closure:** prior landing's commits exist but under the OLD task's
   footer (000001a1f5d5), not this task's — expected for a re-fire of done work. Both
   queue surfaces were unticked; this dispatch ticked TODO_LIST (row 577) +
   docs/todo/services.md (row 320) in one pass. Both ticks were swept by auto-daemon
   heuristic commits (70b809da6 TODO_LIST; 964cf9447 services.md) — hence this
   footer-bearing evidence commit per protocol step 4.
2. **Live spot-check (load-bearing claim: the tile now polls /health):**
   `journalctl -u inboxclean-web.service --since "-30 min"` → 102 `/health` requests
   (tile 30s + gatus legs cadence); live TCP probe `GET /health HTTP/1.0` on
   127.0.0.1:8099 → `HTTP/1.0 200 OK`. The deployed gen-1026 verification was already
   recorded live 2026-11-23 (services.md row 1236).
3. **Source §f sweep:** the Source reports' agent-actionable follow-ups are already
   harvested (gmail-verdict-cache test ticked 2026-11-24 under tq 000001a20b44; the
   8s-budget timeout pin lives in upstream.md row 2352; post-deploy tile-flip verify
   rows exist as blocked:deploy riders 3814/3822). Clean.
4. **Footer:** this commit carries it.
5. **BLOCKED reasons:** none stale (the item had none; rider rows correctly remain
   blocked:deploy).

## Timeout alignment (the item's remaining ask)

Client timeout vs the 8s /health budget: papdashboard probeTimeout is 5s — the tile
client already times out INSIDE the 8s server budget; no config change needed. Gatus
"Dashboard Renders" (secondary poller, `/` every 5m) is unaffected by the /health
budget. Closed as "verified, verdict unchanged".

Residue: post-deploy tile-flip verification stays on the existing blocked:deploy
rider rows (TODO_LIST 3814/3822) — not this item's scope.

## Footer-repair note (2026-11-24 07:5x)

This report and both queue-surface ticks first landed inside the formatter-swept
heuristic daemon commit 2655f7281 (514 files, parallel-session changes included);
this commit exists so the dispatch carries its own `Task-Queue-ID:` footer per the
re-dispatch protocol step 4. No content change beyond this note.
