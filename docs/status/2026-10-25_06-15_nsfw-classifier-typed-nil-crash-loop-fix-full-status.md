# nsfw-classifier typed-nil crash-loop — root cause, upstream fix, deploy, service restored

**Date:** 2026-10-25 04:5x–06:2x CEST
**Trigger:** owner: "Why is https://nsfw.home.lan not responding?"
**Outcome:** FIXED end-to-end. `https://nsfw.home.lan/readyz` → HTTP 200 (all 12 checks pass, binary `61a5257`, gen 942). Root cause was a typed-nil Go error bug that crash-looped the service every boot since 2026-10-20 (239 restarts in boot 3e5c8af5 alone) — nsfw.home.lan had effectively been down ~5 days.

## a. What was wrong (layer by layer)

1. **User-visible:** `nsfw.home.lan` → Caddy 502 (vHost + TLS fine; upstream 127.0.0.1:8104 not accepting). Direct TCP connect to :8104 succeeded (kernel backlog) but never got an HTTP answer — the listener is bound at startup but serving is gated on load+warmup.
2. **Process:** `nsfw-server` "running" but never ready — listening backlog grew (46→71) while it burned 100–180% CPU for ~12–17 min per attempt, then died.
3. **Crash signature:** after a fully clean startup log (`verdict cache hydrated events=2780 entries=57` → all six `* store resolved`), `panic: runtime error: invalid memory address` at `(*buildVerdictStoreError).Unwrap` (`internal/app/app.go:788`) via `cobra.ExecuteC → errors.Is → samber/oops OopsError.Is`. Exit 2, `Restart=on-failure` re-spawned it, forever.
4. **Root cause (code):** `registerLazyStore[T any, E error]` checked `if any(err) != nil`. The six ADR-0020 store builders return a CONCRETE pointer type (`*buildVerdictStoreError` etc.); the SUCCESS return is a typed-nil, and boxing it through `any()` makes the comparison non-nil — so every successful boot took the error branch and returned a non-nil `error` interface wrapping nil. `errors.Is` then walked the chain and nil-dereferenced. `any(err)` compiles (plain `err != nil` does not for a type parameter — the compiler rejects it), which is how the bug shipped inside an otherwise-correct guard-then-nil form (introduced by daemon commit `878cf19f`, no rationale recorded).
5. **Why 5 days of silence:** each crash cycle (~12–17 min: model load dominates) outlives the 5-start/5-min start-limit window, so systemd never latched the unit failed; OnFailure paged Discord per cycle (relay flap-collapse suppressed repeats); gatus sat red; no rule consumed the restart counter. Detection gap queued (§f).

## b. Evidence trail

- Crash-loop census: `journalctl -u nsfw-classifier -b -1 | grep -c 'Started nsfw'` = **239** (2026-10-20 14:58 → 2026-10-25 04:22, ~11 min cadence).
- Identical panic across boots: same `pc=0x105fe40`, same `app.go:788` frame (2026-10-20 15:10/15:25/15:37 + 2026-10-25 04:50).
- Decisive experiment: quarantined the suspect journal (`/var/cache/nsfw-classifier/verdicts.db`, 10.4 MB, mtime Oct 15) → next instance hydrated **events=0 entries=0** from the fresh journal and **still panicked identically** → the corrupt cbor events were a red herring; the bug fires on every successful store build.
- Fix verification in production: with binary `61a5257`, the restored journal hydrated `events=2780 entries=57` (WARN skips for the corrupt events, by design) and **no panic** — first stable boot since Oct 15.

## c. The fix

- **Upstream** `github:LarsArtmann/nsfw-classifier` commit `61a5257c` (pushed to master): widen the six builders' second return from `*XError` to the plain `error` interface (success = true untyped nil; ADR-0020 shell errors remain reachable via `errors.As`), drop the `E error` generic parameter, and pin the contract with two regression tests (`internal/app/register_lazy_store_test.go`: success→nil error + non-nil store; failure→`errors.Is` cause + `errors.As` shell type). Local checks: `go vet` clean, both tests PASS, workspace build green (BuildFlow dev run partial: golangci-lint + go steps passed; heavy steps starved by the load-42 storm — noted, not absorbed).
- **SystemNix:** `nix flake update nsfw-classifier` (input → `61a5257c` + transitive sibling bumps), `nix flake check --no-build` green, deployed via `nix run .#deploy` (required `DEPLOY_FORCE_PRESSURE=1` — see §d). Post-deploy anchor check: `/run/current-system` == `system-942-link` == `b0y3pkjlcww…`.
- **In-flight quarantine reversed:** `verdicts.db` (+`-shm`/`-wal`) was renamed to `.corrupt-20261025` mid-diagnosis and RESTORED before the deploy (hydration handles the corrupt events by skipping — the journal was never the blocker); no data lost, temp `.pre-quarantine` copies of `feedback.jsonl`/`pair-token` removed.

## d. Deploy under the storm — judgment calls

- The deploy PSI gate blocked twice (io PSI avg10 ~45→22 draining, but the stall leaders were the owner's own ghostty scopes at 77–81% — starved largely BY the crash-loop's periodic GB-scale model re-reads). Used the documented `DEPLOY_FORCE_PRESSURE=1` override: the fix ends the box's single biggest CPU+heat burner, and Tctl was 90°C with the loop adding ROCm-init load every ~14 min.
- Post-deploy-check: 155 PASS / 6 FAIL (exit 3, "new failures"). All six triaged NON-regressions: Monitor365 API + "0 connected devices" = the switch-restart window + the agent the owner stopped 2026-10-21 (open decision row, services.md); both monitor365 units verified active with :3001 serving 200s post-switch. Storage-history = §19 first-window freshness. No action owed from them.
- Concurrent-session note: five parallel crush sessions + gradle/kotlin/npm builds were active throughout (attributed via ps; their load shaped every timing in this report).

## e. Verification (the question the item asked)

`printf 'GET /readyz … Host: nsfw.home.lan' | openssl s_client -quiet -connect 192.168.1.150:443 -servername nsfw.home.lan` → **HTTP/1.1 200 OK**, JSON `"status":"pass"`, `"version":"61a5257"`, 12/12 checks pass (Classifier, Runtime, Config, all six stores, skin/face/exposed, Listener), pairing token served (extension auto-re-pair contract intact). gatus probes 200 every 30s since 06:05:21 (245–345µs ≪ 500ms bar); Caddy traffic (`client_ip=192.168.1.150`) answering 200; zero panics since 05:43.

## f. Direct follow-ups — harvested at authoring time

1. **MIGraphX kernel cache never persists** (every start recompiles: 22 min warm-cache under load, 74m50s calm-cold; the runbook's "~2min cached under /var/cache" claim never held — cache dir has never existed). → `docs/todo/services.md` new [ready] row + TODO_LIST queue one-liner.
2. **cbor undecodable-event WARN flood** at hydration (per-event WARN lines every boot; skip+count+sample, `/metrics` counter). → services.md new [ready] row + queue.
3. **Crash-loop escalation gap** (239 restarts/5 days, no alert class fired). → `docs/todo/monitoring.md` new [ready] row + queue.
4. **Boot-evidence pull: 04:31:30 death of boot 3e5c8af5** (SEV1 MEMORY EMERGENCY GUARD TRIPPED + Tctl≥95°C at 04:28, dead 04:31:30 — distinct from the 03:40 task report's earlier window). → `docs/todo/stability.md` new [ready] row + queue.
5. **Queue closes:** services.md :285 gatus-verify → DONE (this session's §e evidence); :300 startup-timeline runbook section → DONE (written with both budgets + the crash-loop signature); TODO_LIST mirrors pruned per queue contract; :349 nsfw half annotated ANSWERED (mr-sync-dashboard still open).
6. **Deliberately not harvested:** the deploy-timeout BuildFlow step failures (dprint/nix-build/test-race starved by the storm) — environmental, re-run when calm; noted here so nothing is absorbed silently.
