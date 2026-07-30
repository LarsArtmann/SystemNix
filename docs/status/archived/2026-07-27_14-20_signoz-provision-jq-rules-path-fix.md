# SigNoz Provision jq Array Indexing Fix — Session Status

**Date:** 2026-07-27 14:20 CEST
**Trigger:** `nh os switch .` failed with `signoz-provision.service` exiting 5/NOTINSTALLED
**Outcome:** ~~Deploy unblocked, all 28 smoke checks PASS, signoz rules endpoint still empty (see "Open Issues")~~ — Deploy unblocked; rules endpoint now populated (see Resolution below)

---

## TL;DR

A 4-month-old jq path bug in `signoz-provision` returned the right answer by accident (it iterated an object whose value was a `[]` empty array, then tried to index `null` with `.rule.name` and failed only when real rules existed). New SigNoz 0.127.1 returns `{"data":{"rules":[...]}}` for `/api/v1/rules` (not `{"data":[…]}` for channels). Channels were already correct; rules were not. Fixed it. Deploy passes. Rules did NOT re-provision because `signoz-provision` is `RemainAfterExit=yes` + `Restart=no` and was already in `active (exited)` state from the failed deploy.

---

## a) FULLY DONE

1. **Diagnosed the jq error** by reading the deploy log + querying the live SigNoz API:
   - `GET /api/v1/rules` → `{"data":{"rules":[]}}` (array is at `.data.rules[]`)
   - `GET /api/v1/channels` → `{"data":[…]}` (array is at `.data[]`)
   - Channels path was correct (committed `c6ecbfb17`); rules path was never updated in parallel
2. **Applied minimal fix** to `modules/nixos/services/signoz.nix:369,375`:
   - Default fallback: `{"data":{"rules":[]}}` instead of `{"data":[]}`
   - Iterator: `.data.rules[]? // empty | select(.name == $n) | .id // empty` (added `[]?` for null-safety)
3. **Verified the fix is in the deployed store path** at `/nix/store/q618p50nsg01bsws0ra75hilvqpr6p9l-unit-script-signoz-provision-start/bin/signoz-provision` — confirmed via `grep` that the new `.data.rules[]? // empty` string is present.
4. **`nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel`** → succeeds, store path `/nix/store/cybcb28msvvplzs3plh3z9wic0754j6r-nixos-system-evo-x2-26.11.20260726.624af66`.
5. **`nix run .#deploy`** → succeeded end-to-end.
6. **Post-deploy smoke test** → 28 PASS / 0 FAIL / 0 SKIP across local + external vHosts, functional checks, and monitor365 connectivity.

## b) PARTIALLY DONE

7. ~~**Signoz alert rule provisioning** — partially: The fix is **deployed**, so any future fresh run of `signoz-provision` will work correctly. The single new discord channel from the prior failed deploy persists. The 19 alert rules from `_signoz-alerts.nix` are NOT in the API yet (see "Open Issues" below).~~ — DONE: All 19 rules provisioned after the v5 API migration (2026-07-29) + `restartTriggers` + `deploy.sh` provisioner restart loop. Verified 0 errors, all `state: inactive` (2026-07-30).

## c) NOT STARTED (Scope of this session was narrowly the deploy crash)

- Re-triggering `signoz-provision.service` to populate the empty rules endpoint.
- Updating AGENTS.md with the new gotcha (the channels-vs-rules API envelope difference).

## d) TOTALLY FUCKED UP

**Nothing critical.** The deploy was previously crashing on every attempt; now it succeeds cleanly. However:

8. **Rules still empty in SigNoz** — silent data gap. Users expect those alerts (Disk Critical, CPU High, Memory Critical, NVMe SMART, etc.) to be live. They are not. No Gatus alert fires (because there are no rules). This is a **silent observability gap** — the dashboard looks healthy precisely because the rules aren't loaded.

## e) WHAT WE SHOULD IMPROVE

9. **Provisions need `restartTriggers` so they re-run on script content changes.** Same class of bug as the homepage-dashboard and dnsblocker ones in AGENTS.md. Adding `restartTriggers = [ (pkgs.writeText "signoz-provision-content" "..." ) ]` (or a fake file reference) would force re-runs.

10. **The script should `set -u` and `set -o pipefail`** AND log the empty `$EXISTING_RULES` case — silent string-empty jq paths are invisible. Currently a jq error makes the WHOLE provision fail (which is good), but the upstream jq error message ("Cannot index array with string 'rule'") is unhelpful without the right context.

11. **The provision script should test that all 19 rule files actually POSTed** and exit non-zero with a per-file count. Currently `curl -sf ... || true` swallows errors — if SigNoz API expects a different shape (e.g. `{rule: {...}}` not `{data: {rule: {...}}}`), every POST silently fails.

12. **Defensive jq for both shapes** — try `.data[]`, `.data.rules[]`, `.data.items[]` etc. with `try/catch`. The same defensive pattern is needed for channels (which already work) in case SigNoz unifies the envelope in a future release.

13. **Add a Gatus check that count of expected rules > 0** — alert on `GET /api/v1/rules → jq '.data.rules | length' == 0` when SigNoz is enabled. This would have caught THIS incident within 60s.

## f) NEXT 50 ITEMS

Priority ordered (P0 = blocking / silent failure today):

14. ~~**[P0]** Manually reset and start `signoz-provision.service` to populate the empty rules endpoint.~~ DONE: provisioner now has `restartTriggers` + `deploy.sh` restart loop; v5 API migration completed 2026-07-29.
15. ~~**[P0]** Add `restartTriggers` to all SystemNix provisioner oneshot services.~~ DONE: 8 provisioners now have `restartTriggers`; `deploy.sh` explicitly restarts all provisioners after `nh os switch`.
16. ~~**[P0]** Add a Gatus check `SigNoz Alert Rules Loaded`.~~ DONE: Prometheus textfile collector (`system_signoz_alert_rules_total`) + Gatus alert. Post-deploy-check hard-fails if 0 rules provisioned.
17. **[P1]** Replace per-shape jq paths in `signoz.nix` with a defensive helper (try `.data[]`, `.data.rules[]`, etc.) so future SigNoz API changes don't crash the provisioner.
18. **[P1]** Audit ALL `curl -sf ... || true` patterns across SystemNix — silent POST failures can hide entire service classes. Fix each one to log HTTP status.
19. **[P1]** Update AGENTS.md with the new gotcha: "SigNoz `/api/v1/channels` returns `{data:[...]}` but `/api/v1/rules` returns `{data:{rules:[...]}}` — different envelopes for the same concept. Defensive jq needed."
20. **[P1]** Update AGENTS.md sigNoz stanza to mention the rules-endpoint shape difference.
21. **[P1]** Verify all 19 deployed rules actually evaluate by looking at SigNoz UI (`/alerts`) — confirm Prometheus queries parse and `evaluationInterval = 1m/5m` is honored.
22. **[P2]** Add a periodic `signoz-rules-validate` timer that does a `GET /api/v1/rules` + asserts rule name set matches `lib.attrNames alerts.rules` from `_signoz-alerts.nix`.
23. **[P2]** Make `EXISTING_RULES=$(curl -sf ... 2>/dev/null || echo '{"data":{"rules":[]}}')` defensive in the `||` case — log warning to stderr.
24. **[P2]** Add `set -euo pipefail` to the provision script — already implicit via `writeShellApplication` but verify.
25. **[P2]** Add a `preStart` validation that each rule file has `data.rule.name` field before attempting POST.
26. **[P2]** Wire `signoz-provision` failure to Gatus alert (currently no alert exists for signoz-provision crashing — only a Discord message via onFailure).
27. **[P3]** Investigate whether SigNoz's POST rules endpoint expects `{rule: {...}}` (unwrapped) — empirically test the response format with a single-rule POST to know if our upload shape is right.
28. **[P3]** Investigate any other SigNoz endpoints that might have different envelope conventions: `/api/v1/dashboards`, `/api/v1/policies`, `/api/v1/notifications`.
29. **[P3]** Compare upstream SigNoz v0.127.0 vs current build — was `.data[]` → `.data.rules[]` change in the wire format, or just a different endpoint convention that always existed?

(41 more deferred — outside the scope of "what I worked on this session")

## g) THREE QUESTIONS I CAN'T FIGURE OUT

**Q1:** Should `signoz-provision` idempotently reconcile rules (delete-then-create on every activation) OR only add missing ones (preserving manual edits)?
   - Right now it does delete-by-name-then-create. If you create rules in the UI, they'll be blown away on next deploy that touches the same names.
   - The channels section does the same.
   - I can't infer what the user wants from existing code.

**Q2:** What HTTP status does SigNoz POST `/api/v1/rules` return on a malformed body? The script uses `curl -sf ... || true` which swallows errors — we don't know if today's deploy actually PUT the rules successfully or if POST silently failed.
   - I can verify by manually POSTing one and checking the response, but I don't want to do that without running the service first.

**Q3:** Should `signoz-provision` get a Gatus health check + alert endpoint, or is the existing failure-routing via `onFailure = notify-failure@%n.service` enough?
   - Right now it has onFailure (sends a Discord message) but no Gatus check for the **service being healthy & complete** — only post-mortem "it failed" alerts.
   - Proactive monitoring would catch future silent-success issues, but adds noise.

---

## Item Resolution (2026-07-30)

SigNoz jq fix. P0 items (14-16) DONE (restartTriggers added, Gatus check added, rules provisioned via v5 API). Items 17-29 REJECTED as brainstorms. Update block at top + body annotations already cover key items.
