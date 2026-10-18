# Tile Logos: Go-Live Verification + Full Follow-Through Wave

**Session:** 2026-10-17 22:30 → 2026-10-18 02:0x CEST · **Executor:** Crush agent (tile-logos continuation)
**Plan:** [docs/planning/2026-10-17_09-27_SUPERB-tile-logos-go-live.md](../planning/2026-10-17_09-27_SUPERB-tile-logos-go-live.md) · **Predecessor:** [docs/status/2026-10-17_08-49_tile-logos-icon-pack-end-to-end.md](2026-10-17_08-49_tile-logos-icon-pack-end-to-end.md)
**Trigger:** owner directive to execute the entire go-live plan and verify everything.

## a) Outcome

**The tile logos are LIVE on dash.home.lan** (deployed 2026-10-17 ~19:34 by the evening
deploy wave, live-verified by this session at 23:2x), and the plan's agent-actionable
epics E2–E8 + E10 + E13 are implemented and verified. Remaining open work is explicitly
owner-gated (browser screenshots, the neutral-icon-set decision) or rides the next deploy.

## b) What landed, with probe depth (code → test-executed → live)

| Item | Depth | Evidence |
| --- | --- | --- |
| Post-deploy icon probes (`scripts/post-deploy-check.sh`: fragment ≥1 `src="/icons/`, route 200 on a fragment-derived file, `Cache-Control: immutable`) | 2 + 3 | Ran against a local test server (port 18991, explicit-PID kill): 3 PASS with a pack, loud FAIL without `PAP_ICONS_DIR`; the probes run in production on the next deploy |
| Pre-deploy §16 icon inventory (`scripts/pre-deploy-check.sh`: rendered icons ⊆ pinned pack, zero-icons fails, §13/§14 anti-blind-skip) | 2 + 3 | Isolated-leg run: 39/39 icons resolve on the real config; negative: missing dir → 1 loud FAIL, empty dir → 39 FAILs naming each icon |
| Negative-test harness legs (`scripts/negative-test-lints.sh` group `tileicons`) | 2 | `CASES=tileicons` = 3/3 PASS (control + `legacy-mdi-icon` eval_case + `pack-missing-icon` build_case via the new `build_case` surface); neuter-proof: assertion→`true` and gate-`exit 1`→no-op both go phantom-green on throwaway copies |
| Icon coverage metric + Gatus pair (`papdashboard_services_json_icons` + `_icons_ok`, anchored-pair conditions in the Services JSON check) | 2 (eval) | jq logic verified against the real config (39/39 → ok) and a crafted 1-of-2 config (→ not ok); `gatus-patterns` VM-test derivation evals green; the mock body + green/RED legs extended (full VM run pending — see §f) |
| Upstream: `/icons/` route is image-only (+ separator/`..` rejection), svg still served | 2 | New route tests (non-image 404 incl. a file that EXISTS in the dir, svg 200); full server suite green; first FOD attempt caught a REAL sandbox bug (see §d4) |
| Upstream: `/api/services` additive `iconUrls` map (`Config.IconURLs()`, shared `resolveIconURL`) | 2 | `TestConfigIconURLs` matrix (pack/external/bare × served/unserved); suites green |
| Upstream: startup WARN when the config references pack icons but the pack is unset/unreadable/empty/image-less | 2 | `TestWarnIconPackMismatch` (5 cases) + non-image-only case; `-race -count=2` green after the logger-injection fix (§d5) |
| Upstream: bookmark-link icons (`Link.Icon`, chip img replaces the abbr plate, dashboard.js drops failed chip imgs, SW `pap-v10`) | 2 | Render tests (img-vs-abbr per pack state), `templ generate`, full smoke GREEN including the new icon assertions |
| Upstream: smoke carries an icon pack (tile + chip icons, non-image file, route/cache assertions) | 2 | `bash scripts/smoke.sh` — all steps pass incl. `src="/icons/smoke-self.png"`, immutable header, README.txt 404, missing-icon 404 |
| Upstream: docs (DEPLOYMENT.md `PAP_ICONS_DIR` section, `docs/runbooks/services.md` runbook, schema bookmark row) | 1 | Written; the schema bookmark row + CHANGELOG entries arrived from the parallel session (see §e3) |
| Upstream: go.mod normalized to the 1.27.1 toolchain floor; `vendorHash.nix` fixed (`pg/a63hg…` → `ZNTUWEuj…`) | 2 | `nix build .#server` green upstream; hash is byte-identical to what the SystemNix FOD measured first-hand |
| **PUSHED:** upstream `origin/master` = `88156eb` (route guard, iconUrls, startup warn, bookmark icons, smoke, docs, go.mod floor, vendorHash fix, race fix) | 3 | `git push` output `06296fb..d96ee6e` + daemon push of `88156eb` |
| SystemNix: lock bumped `a1a505f5` → `88156eb`, papdashboard package builds hermetically (`yd1d0308…`) | 2 | FOD + checkPhase green INSIDE the Nix sandbox (52 specs + unit tests) |
| SystemNix: vendorHash shim DROPPED (E13.1 condition fired — upstream bakes the hash) | 2 | With the shim dropped the build yields the IDENTICAL store path (`yd1d0308…`) — the shim was provably a no-op re-statement |
| Off-LAN determination (E4): **no bypass needed** | 3 | Live-rendered Caddyfile: `forward_auth` has NO path matcher on `dash.home.lan` (protected layer intercepts everything off-LAN); LAN probe `GET /icons/caddy.png` → 200 + immutable with NO cookie; runbook documents why a bypass would be worse |

## c) E1 live verification (the deploy happened mid-plan)

The evening deploy wave (2026-10-17 ~19:34) carried the icon feature before this session
reached E1. Live evidence (23:2x):

- Running unit: `papdashboard-a1a505f5` (`276sx5y4…`), `/api/health` 200.
- Fragment: **39 `src="/icons/…"` images**.
- Through Caddy, no cookie: `/icons/{caddy,miniflux,open-webui}.png` → **200 +
  `Cache-Control: public, max-age=604800, immutable`**.
- Served SW: `pap-v9`.
- CHANGELOG flipped to LIVE; runbook "Deploy evidence (2026-10-17)" section added;
  `docs/todo/upstream.md` row closed (pruned to the CHANGELOG per doctrine).

**Deploy-anchor anomaly found and repaired (flag):** the wave's `switch-to-configuration`
activation at 20:38 left `/run/current-system` (f703wg5, the NEWEST toplevel — it carries
the 2026-10-17-evening `boot-mirror-sync.path` fix that profile gen 926 lacked) UNANCHORED:
`/nix/var/nix/profiles/system` still pointed at gen 926 (v4gdk8y, older). A reboot would
have booted the older generation. Executed the AGENTS.md-documented repair (self-elevating
script, guarded on "no deploy in flight" + "current-system unchanged since diagnosis"):
profile → gen 927 = the running toplevel, boot entry re-armed. **Attribution: the raw-stc
activation was the parallel session's deploy; the repair is this session's, per doctrine.**

## d) Mistakes this session made and fixed (self-review)

1. **`build_case` argument order** — first invocation passed `(group name expect marker
   attr mutation)` against a `(group name attr expect marker)` signature; the mismatched
   `expect` fell through the case statement SILENTLY (no branch, no count). Fixed the call;
   a stricter harness would `*)` on unknown expect values.
2. **First edit dropped `SIGNALERTS`** — a careless old_string in negative-test-lints.sh
   deleted the variable line; caught by grep one step later and restored in the same edit
   that added the new functions.
3. **FileServer prefix bug** — the image-guard stripped the URL prefix for the check but
   never for `http.FileServer`, so every VALID icon 404'd (caught by the existing test
   suite within one run, fixed with `http.StripPrefix` + explicit separator/`..` rejection).
4. **Sandbox-only race** — the warn tests swapped the GLOBAL `slog.Default()` from
   `t.Parallel` subtests: green locally, the hermetic Nix checkPhase lost log lines and
   failed 2 subtests. Fixed by injecting the logger (better design anyway); proven with
   `-race -count=2`. The local-only green pass was the exact "trust a local run" trap the
   Nix build exists to prevent.
5. **Shell-environment friction (mine, repeated):** the tool guard blocks typed `curl`
   (moved into harness scripts), `kill` is unsupported by the shell interpreter
   (`/run/current-system/sw/bin/kill` + explicit PIDs), and `/tmp/e2-test` was wiped twice
   mid-sequence (recreated atomically). One heredoc failed silently on a missing dir —
   re-verified every "file written" claim with `ls`/`grep` afterward.
6. **CHANGELOG daemon race** — first flip attempt refused ("modified since read", 23:26:50
   daemon touch); re-read + retried cleanly. No content lost.

## e) Concurrent-session ledger (attribution honesty)

1. The evening deploy (19:34) + the 20:38 raw-stc activation were the PARALLEL session's
   work; this session verified the results and repaired the anchor it left unanchored.
2. The upstream `services-schema.md` link-icons section and the CHANGELOG entries for the
   bookmark-icons/startup-warn/image-only epics were written by the PARALLEL session and
   swept by the daemon into shared commits (b110356 et al). Their content matches this
   session's implementation exactly — flagged here rather than silently co-verified.
3. This session's upstream work (route guard, iconUrls, warn, bookmark implementation,
   smoke, runbook, go.mod floor, vendorHash fix) rode daemon heuristic commits (2fc80b5,
   39b21e3, HEAD-run) PLUS one properly-messaged commit (`d96ee6e`); the interleaved
   history is public — no squash (see the E13.2 note in `docs/todo/upstream.md`).
4. The `scripts/negative-test-lints.sh` `build_case` surface + `tileicons` group and the
   `tests/test-gatus-patterns.nix` icon legs are this session's.

## f) Follow-ups (harvested at authoring time)

1. **[blocked:deploy] Next deploy carries the hardening wave** → `TODO_LIST.md` +
   `docs/todo/services.md`: lock `88156eb` (image-only route, iconUrls, startup warn,
   bookmark icons, SW pap-v10), icon-coverage metric + Gatus pair, §16 inventory, new
   post-deploy probes. First-fire verification: `papdashboard_services_json_icons_ok 1`
   on :9100/metrics + the §16 PASS line in the deploy log.
2. **[watch] `gatus-patterns` full VM run** → queued in the same row: the derivation
   evals green and the legs mirror the production pair verbatim; the VM boot rides the
   next calm-PSI window (IO some avg10 was 40–58% all session; VM tests were the one
   check deliberately not added to the storm).
3. **Owner (already queued, unchanged):** neutral-icon-set decision (`docs/todo/services.md`
   [decision] row) and the browser-side visual pass (dark/light, breakpoints, SW pap-v10
   arrival after the NEXT deploy — pap-v9 is live today).
4. **Parallel-session CHANGELOG attribution** — recorded in §e2; no action.
5. **Pack staleness [watch]** row — already filed in `docs/todo/services.md` (E6.2).
