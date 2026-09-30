# Status Report — nsfw-classifier × SystemNix Integration

**Date:** 2026-09-30 04:34 CEST
**Session scope:** Answer the wrong-verdict-reports question; audit whether SystemNix
auto-configures the browser extension's server URL and starts a classifier server;
implement whatever was missing; verify end-to-end. No unrelated research, per instruction.

**Repos touched:** `SystemNix` (implementation), `nsfw-classifier` (read-only — zero code changes needed).

---

## The one-line verdict

The extension was auto-installed but had **no backend and no configured server URL** —
discovery only works because the extension ships a built-in candidate list
(`nsfw.home.lan:8104` → `localhost:8080`, pairing-token gated). That backend now exists
as a NixOS service, verified live down to a real paired classify. **It is not yet
running on the host** (activation requires a rebuild, currently blocked by a
pre-existing, unrelated eval break).

---

## a) FULLY DONE

| #  | Item                                   | Evidence                                                                                                                                                                                                                                                                                                                                           |
| -- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Wrong-verdict reports explained        | `nsfw-classifier/internal/server/feedback.go:51` — `POST /feedback` appends `{media_hash, verdict: wrong\|miss, score, model_key, comment}` JSONL to `<cache>/nsfw-classifier/feedback.jsonl`; golden-set seed; `nsfw-human-review` returns `EXPLAIN-UNAVAILABLE` (complaint ≠ verified label)                                                     |
| 2  | SystemNix wiring audit                 | Extension auto-installed via `--load-extension` (`platforms/common/packages/base.nix:85`); NO server, NO port, NO server-URL config; only an unchecked plan (`docs/planning/2026-09-23_18-15_dynamic-service-mesh-registry.md` T10–T14)                                                                                                            |
| 3  | Flake input `nsfw-classifier`          | `flake.nix:353` — INTERIM `git+file?rev=46f02bb` (vendorHash fix unpushed; dirty worktree breaks the go-modules FOD); lock updated; INTERIM row added to `docs/INTERIM-INPUT-PINS.md`                                                                                                                                                              |
| 4  | Port registered                        | `lib/ports.nix:155` — `nsfw = 8104` (uniqueness eval passes)                                                                                                                                                                                                                                                                                       |
| 5  | DNS subdomain                          | `platforms/common/dns-local.nix:37` — `"nsfw"` (wildcard already resolved it; explicit entry satisfies the integration cross-check)                                                                                                                                                                                                                |
| 6  | Service module                         | `modules/nixos/services/nsfw-classifier.nix` — fast mode (`--fast --models falconsai`), `--pair-token auto`, `--host 0.0.0.0` (LAN-reachable), `User = lars` (0700 home traversal for the live-checkout models), persistent `XDG_CACHE_HOME=/var/cache` + `CacheDirectory`, hardened (`ProtectSystem=strict`, `MemoryMax=2G`, `ioTier.background`) |
| 7  | Catalog + integration entries          | Unconditional catalog entry (ADR-008); integration entry = plain vHost `nsfw.home.lan`, gatus check, homepage tile, `monitored`                                                                                                                                                                                                                    |
| 8  | Enabled on evo-x2                      | `platforms/nixos/system/configuration.nix:420`                                                                                                                                                                                                                                                                                                     |
| 9  | Pure-eval test, green                  | `tests/test-nsfw-classifier.nix` — 9 assertions over the resolved config (fast flag, pair token, LAN bind, models dir, lars user, cache persistence, disabled→no unit, catalog unconditional); registered in `tests/default.nix`                                                                                                                   |
| 10 | Binary builds from the pinned rev      | `/nix/store/f1wyri9…-nsfw-classifier-go-46f02bb` — same path the evo-x2 unit resolves to                                                                                                                                                                                                                                                           |
| 11 | **Live E2E of the extension contract** | `/readyz` carries `pairing.token` ✓ → tokenless upload **401** with self-explanatory JSON ✓ → paired upload **200** `{is_nsfw:false, severity:safe, mode:fast, 149ms, model:falconsai}` ✓; `pair-token` + `verdicts.db` persisted in the cache dir ✓                                                                                               |
| 12 | Fan-out resolved on evo-x2             | gatus endpoint `http://127.0.0.1:8104/readyz` ✓, caddy vHost `nsfw.home.lan` ✓, integration `{subdomain:nsfw, port:8104, layer:plain, monitored:true}` ✓                                                                                                                                                                                           |
| 13 | Quality gates                          | BuildFlow lightning `--fix` green (doctor 20 ok / 0 fail); README + planning docs updated                                                                                                                                                                                                                                                          |
| 14 | Read-back verification                 | Every critical edit re-verified by grep after the auto-commit daemon swept the changes (cross-session stale-write lesson applied)                                                                                                                                                                                                                  |

## b) PARTIALLY DONE

| # | Item                   | Gap                                                                                                                                                                                                                                                                                      |
| - | ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **Service activation** | Config exists and evals; the unit is NOT running — needs a rebuild/switch, currently blocked by the pre-existing assertions eval break (see d4). Nothing on the host changed at runtime.                                                                                                 |
| 2 | Mesh plan T10–T14      | T10 (module/unit), T11 (registry+DNS), T12 (vHost), T13 (`--pair-token`), T14 (extension gate) are functionally LANDED, but the planning doc's acceptance checkboxes are still unchecked — no annotation yet.                                                                            |
| 3 | Audit verification     | Scoped verifications are complete (gatus coverage, port registry, unit config, fan-outs), but the full `config.assertions` list cannot be evaluated on evo-x2 at all (pre-existing break), so a whole-config "zero failing assertions" statement is currently **impossible** for anyone. |
| 4 | Memory protocol        | Gotchas discovered this session are recorded in flake/`INTERIM-INPUT-PINS.md` comments but NOT yet in SystemNix `AGENTS.md` (git+file dirty-FOD trap, sanctioned `?rev=` on git+file only, signoz-coverage Environment-list contract, nsfw service entry).                               |

## c) NOT STARTED

1. GPU/ROCm path: no `device` option; CPU-only fast mode (Strix Halo iGPU idle for this workload).
2. Models packaging: models still read from the live checkout; no store/fetcher-based pinning.
3. Browser E2E against the deployed server (extension pairing on the real host, real helium launch).
4. Upstreaming a NixOS module into the nsfw-classifier repo itself.
5. SSE `stream:true` path verification with a token (only the fast path was E2E'd).
6. Cross-repo drift test: pin `DEFAULT_SERVER_URLS` port (extension JS) against `lib/ports.nix`.
7. Feedback-flow consumer work in nsfw-human-review (pre-existing AGENTS.md follow-up, untouched).
8. Runbook page `docs/services/nsfw-classifier.md` (house style for services).
9. TODO_LIST entries / `docs-health` HARVEST of this report's section (f).

## d) TOTALLY FUCKED UP

1. **I misread a failed verification as passing.** My first `nix eval …config.assertions | jq '[.[] | select(.assertion==false)]'` invocation failed silently (`2>/dev/null` swallowed the eval error; jq on empty input prints nothing) and I initially reported "zero failing assertions". Caught later when the same command errored loudly; corrected in-session. Root cause: suppressed stderr on a verification path + no explicit exit-code check.
2. **Attrset `Environment` broke the build eval.** First module version used `Environment = { XDG_CACHE_HOME = … }`; `signoz-coverage.nix` walks `Environment` as a list → `expected a list but found a set`. Fixed to list form. One wasted eval cycle; the contract now lives in a comment + a test assertion.
3. **Trusted an unbuilt store path.** The first `nix build … | tail -2` showed an "Output paths:" line for a build that had actually FAILED (vendorHash mismatch on the dirty tree); I then tried to exec the nonexistent binary. The committed rev builds clean — which is what forced the `?rev=` pin.
4. **Pre-existing, NOT mine, but surfaced and unresolved:** `config.assertions` on evo-x2 aborts with an upstream nixpkgs error (`oci-containers.nix:616` — "expected a set but found null", a rootless-podman assertion evaluating a nonexistent user). Reproduced at the pre-change commit `f8d04a8b`. This likely blocks `nix flake check`/switches on evo-x2 **regardless of my change**. Unfixed (out of session scope; reported).

## e) WHAT WE SHOULD IMPROVE

1. Never pipe verification-command stderr to `/dev/null`; assert exit codes explicitly.
2. Before choosing an option shape (attrset vs list), grep the config for every consumer that walks it (`signoz-coverage` lesson).
3. On daemon-churned checkouts, pin `git+file?rev=` from the first commit, not after the first FOD failure.
4. Record AGENTS.md gotchas at discovery time, not report time (Memory Protocol violation this session).
5. When landing plan items (T10–T14), annotate the planning doc in the same change.
6. Scoped audit evals (eval the audit module's own config) instead of relying on the monolithic assertions list — which one broken element currently blinds entirely.
7. A tiny "module-set smoke eval" harness (minimal nixosSystem importing the full discovered set) would have caught both the integration-option and Environment-shape issues pre-build.
8. The extension burns a doomed probe on `localhost:8080` on every discovery — SystemNix runs signoz there; the tokenless-refuse path works but wastes the 5s negative-cache window every time discovery runs.

## f) NEXT — up to 50 (brainstorm for HARVEST; sorted roughly by impact)

**Deploy & breakage (highest impact)**

1. Fix the pre-existing oci-containers assertions eval break on evo-x2 (blocks switch/flake check for everything).
2. Rebuild/switch to actually start `nsfw-classifier.service`; verify `/readyz` on the host.
3. Push nsfw-classifier `46f02bb` to origin/master; flip the input to `git+ssh…?ref=refs/heads/master`, drop `?rev=`, bump lock, clear the INTERIM rows.
4. Post-deploy verify: `curl https://nsfw.home.lan/healthz` through the caddy vHost (eval-verified only so far).
5. Real-browser E2E: launch helium, confirm the extension auto-pairs with the deployed server and filters.
6. Decide/discard the unrelated uncommitted edits in the nsfw-classifier checkout (`latencybench.go`, `.golangci.yml`) — they poison dirty-tree builds while the git+file pin exists.
7. Annotate the mesh plan doc: T10–T13 landed, T14 pre-existing — check the boxes with evidence links.

**Contracts & drift guards**
8. Cross-repo test: assert extension `DEFAULT_SERVER_URLS[0]` port == `ports.nsfw`.
9. Sweep all service modules for `Environment` attrset forms (signoz-coverage walker contract).
10. Add the module-set smoke-eval harness (see e7).
11. Record the four new gotchas in SystemNix `AGENTS.md`.
12. HARVEST this report's section (f) into `TODO_LIST.md` (docs-health).

**Service hardening & ops**
13. `device` option for ROCm/MIGraphX (`server-go-rocm`) — GPU fast mode.
14. gatus first-boot warmup: confirm `/readyz` during model load doesn't false-alert (interval 30s default).
15. Models packaging: pinned-fetcher store models to drop the live-checkout dependency (and the `User=lars` requirement with it).
16. Rate limiting (`--rate-limit`) now that the port is LAN-exposed.
17. Consider `CORS_ORIGIN` restriction vs the extension's needs.
18. `--cache-retention` policy for verdicts.db growth; disk monitoring.
19. Backup decision for `/var/cache/nsfw-classifier` (verdict cache + feedback JSONL + pair token — privacy note: hash+verdict history).
20. Pair-token rotation/retrieval runbook (0600 file, stable across restarts by design).
21. Socket-activation or idle-stop (the server is only needed while browsing).
22. Journal retention/log noise check for the new unit.
23. Health-dashboard federation: does `health.home.lan` pick the new service up automatically via `monitored`, or does it need registration?
24. Homepage tile: confirm the "AI" group name matches the existing dashboard tabs (new tab otherwise).
25. SSE `stream:true` E2E with token (fast path only was tested).
26. Skin-signal field on responses (`skinseg` sits in the same models dir) — confirm it survives fast mode and lands in the extension UI.

**nsfw-classifier product work (pre-existing follow-ups noticed this session)**
27. Feedback consumer: wire `feedback.jsonl` into nsfw-human-review (AGENTS.md open follow-up).
28. Add severity context to feedback records at complaint time.
29. Feedback auto opt-in policy: `isLocalhostUrl` means `nsfw.home.lan` NEVER auto-enables wrong/miss reporting — decide if that's the intent for the mesh name.
30. Upstream-able NixOS module inside the nsfw-classifier repo.
31. Golden-set export → evaluation loop (`nsfw-evaluate`) wiring.
32. Router: model-card docs for falconsai as the default fast model.

**Extension polish**
33. Server-status surface: show the user which server discovery paired (or that pairing failed).
34. Drift guard for `PAIR_TOKEN_HEADER`/`/readyz` shape vs server (currently comment-matched only).
35. Port-8080 candidate: fast-fail probe when a non-nsfw service (signoz) occupies it.

**Docs**
36. `docs/services/nsfw-classifier.md` runbook (house style).
37. README wildcard-DNS claim is stale ("dnsblockd has NO wildcard local resolution" vs `dns-blocker-config.nix:83` wildcard) — fix the doc or the config, pick one truth.
38. FEATURES/CHANGELOG entries in both repos for the integration.
39. ARCHITECTURE note: where the extension contract lives (url-utils.js ↔ pairing.go ↔ the unit flags).

**Testing debt (pre-existing, noticed in passing)**
40. Full `nix flake check` on SystemNix (currently impossible until #1 lands).
41. VM test for the nsfw unit booting with stub models (eval-only coverage today).
42. nsfw-classifier `GOEXPERIMENT=jsonv2` build + `go test ./internal/...` run after the daemon's recent commits (its repo got auto-commits during this session).
43. gatus-patterns test coverage for the new check shape.
44. Port-registry-audit negative test for `--port <registered>` form (exists generically; add the `--port 8104` instance).
45. Cross-check dns-local.nix vs catalog subdomains automatically (integration asserts one direction; close the loop).
46. Consider `_type = "if"` guard-shape lint: empty mkIf definitions on absent options error — a lintable pattern (cost me one eval cycle).
47. Decide whether `nsfw.home.lan` (443) and `:8104` direct should both exist long-term, or consolidate on one face.
48. Latency baseline: record fast-mode latency on evo-x2 (149ms wall including HTTP; model-only time unmeasured).
49. Scale path: room-queue + batch features unused in this deployment — document intentionally-off (`--room-id` absent by design).
50. Sunset criteria for the INTERIM pin (auto-remind if 46f02bb is still unpushed in N days).

## g) Questions I cannot answer myself

1. **Deploy:** The service is configured but NOT running, and activation is blocked by the pre-existing oci-containers assertions eval break (d4). Do you want me to fix that pre-existing break now and then run the rebuild/switch — or do you deploy yourself, on your own schedule?
2. **Compute:** Keep CPU fast mode (falconssai, ~150ms wall, zero warmup risk) or wire the ROCm/MIGraphX variant (Strix Halo iGPU; first warmup ~2 min, then lower latency)?
3. **Feedback policy:** Wrong/miss feedback auto-opt-in is localhost-only by design (`isLocalhostUrl`) — so a browser pairing with `nsfw.home.lan` never auto-enables verdict reporting. Intended for the mesh name too, or should LAN-mesh servers count as "local" for that opt-in?

---

_Point-in-time snapshot. Section (f) is HARVEST input for `TODO_LIST.md`/`ROADMAP.md`, not an entombed checklist. Format note: written as `.md` per explicit instruction (skill default is HTML)._
