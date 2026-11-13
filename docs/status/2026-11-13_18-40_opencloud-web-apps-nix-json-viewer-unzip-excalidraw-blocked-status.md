# Status: OpenCloud web apps land as Nix (JSON Viewer + Unzip) — Excalidraw BLOCKED on the 7.x production line

**2026-11-13 18:40 CET · session span ~11:00 → 18:40 · evo-x2 live gen `system-1006` (`2ih9snrn…`) · tree drv `mx57s2lx…` (drv-differs ⇒ real drift, deploy pending) · IO PSI some avg10=60.19% avg300=71.30% at authoring (deploy-gate-relevant)**

Owner ask: "my OpenCloud instance should have these Apps/plugins installed (via nix): JSON Viewer, Excalidraw, Unzip".

## Scope line — what this report VERIFIED vs what it did NOT

**VERIFIED (command / artifact, fresh at report time):**

- **Mechanism, from v7.2.4 source (not docs inference):** the web service serves external apps from `config.Asset.AppsPath` (`WEB_ASSET_APPS_PATH`), auto-discovers every app folder there (`apps.List(...)` → injected as `external_apps` into `config.json`) and mounts it at **`/assets/apps/<name>/`** (`_customAppsEndpoint = "/assets/apps"`). Sources read via `gh api`: `services/web/pkg/server/http/server.go` + `services/web/pkg/service/v0/service.go` @ `v7.2.4`; env contract from binary strings (`yaml:"apps_path" env:"WEB_ASSET_APPS_PATH" … desc:"… derives from $OC_BASE_DATA_PATH/web/assets/apps"`).
- **Package builds green:** `pkgs/opencloud-web-apps.nix` → `/nix/store/ns6mf0wm2irrgk8b2pkbqw9zzjlv5jx9-opencloud-web-apps-7`; layout `apps/json-viewer/{manifest.json,js,assets}` + `apps/unzip/{manifest.json,js,assets}`; both manifest `entrypoint` files **exist on disk** (`js/remoteEntry-DLHttYkq.mjs`, `js/remoteEntry-DT_ywuAe.mjs`).
- **Hashes pinned from real FOD builds:** json-viewer 2.1.0 `sha256-hLeyNYbcrv6mgmuupK3xCf606eEkUeOPeCa0fhL7lzo=`, unzip 2.2.0 `sha256-xAUKQSSVN+LdO+QX/2mU8kmUn4fcjNQhB0HB9Gi0V3Q=`.
- **Host wiring evals:** `nix eval --raw …config.systemd.services.opencloud.environment.WEB_ASSET_APPS_PATH` → `/nix/store/ns6mf0wm2irrgk8b2pkbqw9zzjlv5jx9-opencloud-web-apps-7/apps`.
- **Whole-host eval currently GREEN:** `…config.system.build.toplevel.drvPath` → `/nix/store/mx57s2lxsrxwgk0ffvx7i9khp44bzd22-nixos-system-evo-x2-26.11.20261107.f4a03c0.drv` (the earlier assertion failures were a *parallel session's* unfinished journal-mesh work; they fixed it mid-session).
- **Formatting:** `nix fmt -- --fail-on-change` on all 6 touched files (3 `.nix`, 3 `.md`) — traversed 6, **0 changed**.
- **TODO-system gate:** `scripts/check-todo-system.sh` → `OK: TODO queue/library structure clean` (45 pre-existing unharvested-report WARNs, none mine).
- **Version-compatibility matrix established (the load-bearing fact of this session):** opencloud-production **7.2.4 ships web 7.1.5**; `json-viewer` tag **2.1.0** declares `@opencloud-eu/web-client ^7` (2.2.0/main → `^8`); `unzip` tag **2.2.0** declares `^7` (2.2.1 → `^8`); **every** excalidraw tag (1.0.0, 1.0.1, 1.1.0) declares `^8` and its README requires **web ≥ 8.1.0** (shared Yjs runtime, opencloud-eu/web#3398) plus a Yjs server (`WEB_OPTION_YJS_SERVER_URL`).
- **Landed (daemon-committed, tree clean):** `a5ffbafe6` (pkgs + module + overlay), `32c1b8373` (runbook §Web apps), `d5e110370` (CHANGELOG + Excalidraw watch row). HEAD `042f1044b`, `git status` empty.

**NOT verified (and why):**

- **The apps are NOT live.** No deploy fired: the tree carries a parallel session's journal-mesh/bank-sync work and the deploy pressure gate is refusing on a *real* storm (PSI some avg10 60%, avg300 71%). Change is tree-side only; `cloud.home.lan` currently serves zero external apps (`/mnt/pool/services/opencloud/web/` does not exist; `WEB_ASSET_APPS_PATH` was unset on the live unit).
- `/assets/apps/json-viewer/manifest.json` HTTP 200 — documented as the verify recipe, **unrun** (needs deploy).
- "The App Store shows it as installed" — **inference**, not verified (the bundled `web-app-app-store` chunk exists in the web dist; whether it lists locally-discovered apps vs only store-catalog apps was not probed).
- Excalidraw on this line — verified as *impossible* from upstream requirements, not "tried and failed" (no compatible artifact exists to try).

---

## a) FULLY DONE (with evidence)

1. **Mechanism decided from source, not blog posts** — `WEB_ASSET_APPS_PATH` + auto-discovery + `/assets/apps` mount; the upstream docs' imperative `$OC_DATA_DIR/web/assets/apps` copy is replaced by a read-only store tree (survives deploy, no drift, no root-owned chown dance).
2. **`pkgs/opencloud-web-apps.nix`** — declarative app set sourced from official `opencloud-eu/web-extensions` release archives (`fetchzip`, both hashes real), installs `$out/apps/<name>`, with the compatibility rule written where the pins live.
3. **Overlay registration** — `overlays/shared.nix` gains `opencloud-web-apps = prev.callPackage ../pkgs/opencloud-web-apps.nix { }` in the existing package block (no new overlay file).
4. **Module wiring** — `modules/nixos/services/opencloud.nix` sets `WEB_ASSET_APPS_PATH = "${pkgs.opencloud-web-apps}/apps"` in the `environment` attrset (all overrides ride env by design; no `settings` file introduced, so the `opencloud init` trigger condition is untouched).
5. **App set vetted for the running web line** — JSON Viewer 2.1.0 + Unzip 2.2.0 (both `web-client ^7`). Explicitly rejected the tempting "latest tag" (2.2.0/2.2.1 → `^8`).
6. **Excalidraw verdict** — blocked, with the precise reason, version gate, and the two independent requirements (Yjs runtime sharing + Yjs server) recorded; not silently omitted.
7. **Runbook** — `docs/services/opencloud.md` §Web apps: table of installed apps + versions, the install/activation path, the pinning trap with exact tag boundaries, the Excalidraw blocker, and a verify recipe using the *correct* URL (`/assets/apps/<name>/manifest.json`).
8. **CHANGELOG entry** — one paragraph, dated, user-facing, names the compatibility pins and the Excalidraw blocker.
9. **Queue/library row** — Excalidraw `[watch]` row in `docs/todo/services.md` with the re-check trigger (next `opencloud-production` pin bump) and the exact one-entry change needed.
10. **Artifact inspection** — bundle layout + manifest entrypoint existence proven by hand (after the GC incident below); out-link kept at `~/.cache/ocapps/apps-result`.
11. **Formatting + TODO gate** — both green (see scope line).
12. **Attribution** — no commit authored by me (rule); the auto-commit daemon swept the 6 files into 3 heuristic commits; tree clean, nothing unpushed by me.

## b) PARTIALLY DONE

1. **Installation is config-complete but NOT live.** The apps cannot appear until a deploy lands; the live unit still has no `WEB_ASSET_APPS_PATH`. Every subsequent verification (HTTP 200, UI visibility, App Store listing, unzip behaviour on a real archive, JSON pretty-print on a real file) is unrun.
2. **Compatibility rule is documented but not mechanical.** It currently lives as a comment in `pkgs/opencloud-web-apps.nix` + runbook prose; nothing fails at eval if someone pins a `^8` app against web 7.1.5. A `webLine` field per app entry + `lib.assert` would make the trap impossible — not done.
3. **Observability.** No gatus check, no post-deploy leg. A broken apps path degrades silently (files simply vanish from the UI) — exactly the "new service must be monitored" doctrine, unfulfilled here.
4. **Deploy-blocked, not deploy-refused-by-me-alone:** the tree is eval-green but PSI-refusing (60% avg10). Even if I had been told to deploy, the gate would have held it.
5. **FEATURES.md** — not updated (OpenCloud feature inventory still lists the pilot without web apps).

## c) NOT STARTED

1. Excalidraw install (hard-blocked on web ≥ 8.1.0; no artifact exists for 7.1.5).
2. Yjs server (container image `opencloudeu/yjs` upstream — incompatible with this host's Docker-free posture; would need a Nix package + proxy route) — only relevant once web ≥ 8.1.
3. gatus check for the apps surface.
4. `scripts/post-deploy-check.sh` leg for `/assets/apps/<name>/manifest.json`.
5. Eval-time web-line assertion in `pkgs/opencloud-web-apps.nix`.
6. `packages.*` (flake) exposure of `opencloud-web-apps` for ad-hoc `nix build`/inspection.
7. VM/integration test (e.g. assert the rendered env var points at a tree containing N manifests — cheap, high value).
8. A `services.opencloud.webApps` module option (the env var is a hardcoded one-liner today; a list option would make future apps a one-line add).
9. `docs/agents/integration-registry.md` — deliberately untouched (no new vHost/service; correct).
10. Owner-side UI smoke (open a `.json` and a `.zip` in the browser; verify the two apps appear and function).

## d) TOTALLY FUCKED UP / honest misses

Nothing broke live — no service, no data, no config regression. But the process had four real misses:

1. **Evidence discipline gap (self-inflicted):** I first built with `nix build --no-link`, then inspected the path minutes later — a GC had reclaimed it. I rebuilt to the *same* deterministic path and pinned it with an out-link. The first inspection attempt errored on a missing file and, for a moment, looked like a broken bundle. Lesson already in repo doctrine (pin what you will re-inspect).
2. **Entrypoint existence was checked only AFTER that scare** — "manifest.json present" is not "app loadable". Both entrypoints exist, but that check should have preceded any "done" claim.
3. **Wrong first assumption on the public URL** (`/apps/<name>/`). I had already drafted the runbook verify recipe with it and caught it only by reading `_customAppsEndpoint` in source. Shipping that recipe would have sent the owner chasing a 404.
4. **A meaningless version string:** the derivation is `opencloud-web-apps-7` (`version = "7"`, meaning "web line 7"). It builds and reads fine, but it is a wart, not a version.
5. **Co-committed with foreign work:** I `git add`ed the new pkgs file (required — untracked files are invisible to flake eval), and the daemon then committed my 3 files inside a batch that also carried the parallel session's journal-mesh/bank-sync work (`a5ffbafe6`). Not damage; attribution is fuzzy for a reader of that commit.

## e) WHAT WE SHOULD IMPROVE (ranked by leverage)

1. **Make the compatibility rule mechanical.** `apps = { json-viewer = { version; hash; webMajor = 7; }; }` + `assert webMajor == pinnedWebLine` where `pinnedWebLine` is derived from `pkgs.opencloud-production.web.version`. That single assert converts the highest-cost trap in this session (a silently non-loading app) into a build failure. **Highest value remaining item.**
2. **Monitor the app surface.** One gatus check with a body condition (`"name":"json-viewer"`) makes an apps-path regression page instead of disappearing silently. The fleet doctrine ("every new service MUST be monitored") applies to a new *surface*, not just a new port.
3. **A `webApps` module option** instead of a hardcoded env string: list of attrs → derivation → env. Then "install Excalidraw" is one entry, and the runbook table is generated truth, not prose.
4. **Post-deploy leg** in `scripts/post-deploy-check.sh` (manifest 200 for each installed app) — the battery is where every other launch verification lives.
5. **Track upstream release compatibility in the watch row** — the row exists; consider also naming the *nixpkgs* signal (opencloud-production webVersion) rather than a date, which it already does. Good.
6. **Session hygiene:** when a concurrent session's unfinished module reddens whole-host eval, record the *assertion text* immediately in the report/queue (I did) and re-check eval before declaring anything "blocked by them" — I re-checked at close and the tree is now green, which changed the deployment story (blocked by pressure, not by eval).

## f) Up to 50 next things (session-scoped, actionable)

**Verify what we built (highest priority)**
1. Fire the deploy in a PSI-calm window (gate: some avg10 < 20 sustained; now 60%).
2. `GET https://cloud.home.lan/assets/apps/json-viewer/manifest.json` → 200 + `"name":"json-viewer"`.
3. `GET …/assets/apps/unzip/manifest.json` → 200 + `"name":"web-app-unzip"`.
4. `GET https://cloud.home.lan/config.json` → both under `external_apps` with paths `/assets/apps/<name>`.
5. Confirm the unit env: `grep WEB_ASSET_APPS_PATH` in `/run/current-system/etc/systemd/system/opencloud.service`.
6. Browser smoke: open a `.json` file → pretty view (JSON Viewer).
7. Browser smoke: right-click/download a `.zip`… perform an unzip action in the UI (Unzip) and verify the extracted folder in the same space.
8. Confirm apps survive an opencloud restart (discovery runs at startup only).
9. Confirm no duplicate app entries if a stale `$OC_DATA_DIR/web/assets/apps` ever reappears (fallback FS precedence).
10. Confirm the apps do **not** appear for a user without the group role (unauthenticated `/assets/apps/...` should follow the proxy's public-route policy — verify it is not anonymous-public if that is unintended).

**Hardening the config we just wrote**
11. Add `webMajor` per app + eval assert against `pkgs.opencloud-production.web.version`.
12. Add a `checks`-style selftest: bundle contains exactly N manifests and each entrypoint file exists.
13. Expose `opencloud-web-apps` in `flake/parts/packages.nix` so `nix build .#opencloud-web-apps` works.
14. Replace `version = "7"` with something truthful (`web7-json-viewer-2.1.0-unzip-2.2.0` or a date).
15. Promote the env string to a `services.opencloud.webApps` option in the wrapper.
16. Record app provenance (repo + tag + archive URL) in an app-level `meta` or a generated `APPS.md`.
17. Add the app set to `docs/services/opencloud.md` "Verify recipes" as an actual command block (currently prose + one line).
18. Add a negative-test leg: point `WEB_ASSET_APPS_PATH` at an empty dir → app list empty, service healthy (proves no hard dependency).

**Observability**
19. gatus check `OpenCloud JSON Viewer` (body condition) — Files group.
20. gatus check for the apps root (`/assets/apps/json-viewer/`) or a single combined "OpenCloud Web Apps" check.
21. `scripts/post-deploy-check.sh` §20-style leg for each installed app manifest.
22. SigNoz/health-hub: nothing new needed — confirm no phantom metric/gatus drift is introduced by the extra check (tile-free, no dashboard change).

**Excalidraw path (blocked)**
23. Watch `opencloud-production` webVersion on each pin bump (`nix eval … pkgs.opencloud-production.web.version`).
24. When web ≥ 8.1.0: add `excalidraw = { version = "<tag>"; hash = …; webMajor = 8; }` — module change: none.
25. Evaluate a Nix-packaged Yjs server (upstream image only) — websocket route through the opencloud proxy (`/yjs`, `additional_policies`) and `WEB_OPTION_YJS_SERVER_URL`.
26. Decide whether collaboration is even wanted LAN-only (single user ⇒ maybe read/write local whiteboards suffice).
27. If the owner wants Excalidraw *now*: evaluate a deliberate switch to the rolling line (`pkgs.opencloud` 8.1.0) — irreversible-ish (no path back to production until 8.x ships there); decision row, not an agent call.
28. Or: stay on 7.2.4 and check whether the browser extension / desktop app path offers any whiteboard alternative.

**Documentation / queue hygiene**
29. Note in the runbook that apps are discovered at *startup* (restart required, no live reload).
30. Note the fallback FS order (configured path wins over builtin `assets/core|apps`) — explains "app disappeared" symptoms.
31. Harvest the live-verification steps into the queue (done: paired row landed this report).
32. Add an entry to `docs/gotchas-archive.md` for the web-7/web-8 app-tag trap (it is an upstream-metadata trap, not a config bug).
33. Keep the Excalidraw watch row's premise renewable (re-check on every production pin bump, not a date).
34. Clarify in the runbook which "App Store" notion is which (bundled store app vs upstream store catalog vs locally discovered apps).

**Concurrent-session / process**
35. Treat whole-host eval as shared-state truth: re-check before declaring "blocked by the other session" (it reversed within this session).
36. Prefer deterministic build paths for inspection (`nix build -o ~/.cache/...`) over `--no-link` + later inspection.
37. When a new file must be staged for flake eval, note it in the report — the daemon may batch it into a foreign commit.
38. Keep `git add <new file>` path-scoped (done); never a bare `git add -A` (foreign staged work risk).
39. Record the exact assertion texts that blocked eval (done in report) — they are the evidence that "it wasn't me".
40. Deploy-attempt discipline: check drv equality first (done: tree `mx57s2lx…` vs live `2ih9snrn…` ⇒ real drift).

**Optional / future**
41. Consider unpkg-style hosting? No — server-side apps only.
42. Add `markdown-editor`/`draw-io` if the owner wants more (same pinning rule; draw-io v2.2.0 → check its web-client range before pinning).
43. Add `external-sites` if the owner wants dashboard tiles (needs `apps.yaml` config).
44. Add `importer` if a migration is planned.
45. Review whether any installed app widens the CSP (same-origin assets ⇒ no; verify if a future app loads a CDN).
46. Confirm backups: apps live in the store, but `apps.yaml` (if ever added) lives in `/etc/opencloud` — NOT snapshotted (trap #4 class).
47. Add the app set to the pilot acceptance checklist (owner-hands items).
48. Re-check the bundle after any `opencloud-production` bump — nixpkgs bumps `webVersion`, so the installed app set must be re-vetted in the SAME change.
49. Consider pinning the *web-extensions* repo commit instead of release zips if reproducibility of a tag ever breaks.
50. Re-read this report's §f after the deploy and tick what actually held.

## g) Questions I CANNOT answer myself (max 3)

1. **Excalidraw is impossible on `opencloud-production` 7.2.4** (needs web ≥ 8.1.0 + a Yjs server; every release tag targets web ^8). Do you want to (a) stay on production 7.x and get it the day the line reaches 8.x, (b) switch the instance to the rolling line `pkgs.opencloud` 8.1.0 now (forfeits the production-line downgrade guarantee — an owner decision, not mine), or (c) drop Excalidraw?
2. **Should I fire the deploy now-ish?** Tree is eval-green but carries a parallel session's journal-mesh/bank-sync work and PSI is 60% some-avg10 (deploy gate refuses). Options: wait for their session to quiesce + a calm window (my default), or have me attempt-and-retry through the gate.
3. **Do you want the apps surface monitored and exposed as a flake package** (gatus body check + post-deploy leg + `.#opencloud-web-apps`), or keep the change minimal until the pilot converts to production?

---

## f-harvest record (doctrine: self-harvest direct follow-ups)

- §f 1 + 2–9 → **harvested**: `[ready]` row in `TODO_LIST.md` + matching entry in `docs/todo/services.md` ("verify OpenCloud web apps live on the next deploy").
- Excalidraw path (§f 23–28) → **already harvested** as the `[watch]` row in `docs/todo/services.md` (this session).
- §f 11–18, 19–21, 30, 32 → **deliberately NOT harvested**: they are design improvements gated on the owner's answer to §g.3; queueing them now would pre-empt that choice and add harvest noise.
- §f 35–40 → **deliberately NOT harvested**: process lessons, not work items; the durable ones are already covered by AGENTS.md doctrine (drv-equality probe, daemon-race discipline).
