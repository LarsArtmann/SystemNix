# quotaboard.home.lan is LIVE (always-on server, Layer 2 vHost, PapDashboard tile) — and the HaGeZi deploy bomb that blocked every deploy today is repaired (2026-11-25, 20:44)

**2026-11-25 20:44 CET, Crush agent (glm-5.4). Trigger: owner request "I want quotaboard.home.lan to be available, and in PapDashboard" + "execute and verify one step at a time, repeat until done", then "FULL COMPREHENSIVE STATUS UPDATE, then WAIT".**

**Harvest status: NOT HARVESTED, deliberately.** The owner asked for this report immediately; every §f row is still unpicked in `TODO_LIST.md` / the domain libraries. Harvesting §f is the first item of §f.

## Scope line

**Verified in this session (command + artifact, all 2026-11-25 17:30 → 20:47 CET, same boot `0737ecd7`):**

- Eval truth of my change: one `nix eval --json .#nixosConfigurations.evo-x2.config --apply` (output `~/.cache/quotaboard-vhost/eval.json`), module count `nix eval .#nixosModules` = 157, registry matrix via `nix build .#registry-matrix`.
- `nix flake check --no-build` at `e6bb40928` + my then-working-tree edits: rc=0, "all checks passed!" (17:50:30 → 17:56:09, log `~/.cache/quotaboard-vhost/fc.log`). **This run predates my last edits** (em-dash cleanup in the module, the `dns-update.sh` fix, the blocklist restore) — see §b.
- Toplevel build `--keep-going` at `5d1674211`: rc=0 in 43 s (`~/.cache/quotaboard-vhost/toplevel2.log`); the first attempt (before the blocklist repair) enumerated exactly 6 failing HaGeZi fixed-output derivations (`toplevel.log`).
- Live state at 20:45–20:47: running `6q9jp84a` = profile `system-1031-link` = `preferred` boot entry on BOTH ESPs; booted system still gen-1029 `gwfgxm1v`.

**NOT verified here:** the RUNNING gatus config (I could not locate its file; only "no alert line names quotaboard in the gatus journal since 19:00" was read); the sibling deploy's smoke section for the quotaboard lines; the PapDashboard tile in a real browser; the DMS bar widget in the live session; the boot-time start at the greeter (needs a reboot); a full `nix flake check` of the final tree; what the sibling sessions' commits since `5d1674211` contain beyond their filenames.

**HEAD at authoring:** `218c448bd` (20:30:56), tree clean at 20:45.
**Carrying deploy (not mine):** `/var/log/systemnix-deploys/2026-11-25_18-54-44.log` — started 18:54:44 by a sibling session at `HEAD 74763a8e7` (which contains all my commits), HM activation landed 19:05:13, profile link created 19:33:39, log ends `deploy exited code=14 at 19:45:56`. I read only those grep lines of it, not the log body.

---

## TL;DR

1. **`https://quotaboard.home.lan` answers 200 through Caddy (LAN path) and the tile "Quotaboard" (group AI, its own favicon) is in the deployed `/etc/papdashboard/services.json`.** Live on gen-1031 since 19:05.
2. **The quotaboard server is now always-on.** It was a session-scoped user unit (upstream home module), which is why it sat connection-refused through the 2026-11-23 SSH-only period. It started at 19:05:13, **52 minutes before the first graphical session of this boot existed (19:57:35)** — that gap is the always-on proof.
3. **No deploy of mine landed.** All 17 `nix run .#deploy` invocations from my wrapper/loop (18:48 → 20:42) were refused at deploy.sh's entry gates (pressure rc=12 or flock rc=13). A sibling session's 18:54 deploy carried my commits. My loop kept re-arming for 98 minutes after the feature was already live because its "already live" check compared one exact store path — see §d.
4. **A deploy bomb unrelated to quotaboard blocked EVERY deploy today and is repaired at the root:** the nightly `dns-blocklist-drift` workflow (04:30 UTC, `c7fb34007`) wrote GitLab-HEAD hashes into a file whose HaGeZi URLs are pinned-commit GitHub URLs since 2026-11-24. `scripts/dns-update.sh` now reads the pinned base from the file; the 6 wrong hashes are restored (file byte-identical to the pre-bomb state `c7fb34007^`); toplevel builds again.

---

## a) FULLY DONE

1. **Design decision — always-on instead of session-scoped.** The upstream home module binds the unit to `graphical-session.target`; behind a LAN vHost that is a 502 tile at the SDDM greeter, in SSH-only periods and after every crash reboot. Three rails hold the contract: declared + asserted linger, `session-boot-audit`, and two unconditionally paging Gatus checks (no session-aware meta check, unlike emeet-pixyd). Runbook: `docs/services/quotaboard.md`.
2. **`platforms/nixos/desktop/quickshell.nix`** — overrides ONLY `PartOf`/`After` (→ `[]`) and `WantedBy` (→ `default.target`); the unit body stays upstream's single definition. Landed in `0fe6523a7`.
3. **`platforms/nixos/system/configuration.nix`** — `users.users.lars.linger = true`: a declarative pin of the imperative `loginctl enable-linger` the box already ran on (live `Linger=yes` read before the change).
4. **`modules/nixos/services/quotaboard.nix` (new)** — registry entry derived from the home-manager enable switch (one switch owns server and exposure): Layer 2 `protected` vHost, Gatus "Quotaboard ready" (`/health/ready`, 30 s) + "Quotaboard quotas API" (`/api/quotas` envelope, 60 s), tile "Quotaboard" in group `AI`, icon `quotaboard.svg` copied from the locked source rev (`inputs.quotaboard + "/static/favicon.svg"`), eval assertion on linger, `monitored = false` (user unit — system-health cannot see it).
5. **`platforms/common/dns-local.nix`** — `quotaboard` added. Live: `getent hosts quotaboard.larsartmann.cloud` → `192.168.1.150` (it did NOT resolve at 18:22, before the switch — a clean differential).
6. **Re-stamps:** registry matrix regenerated (`quotaboard` row + the already-stale `forgejo` 5→6 checks), README gatus 320→322 and modules 156→157 (+ a Quotaboard row in the service table), FEATURES modules 156→157 with the file/helper census corrected to 164/7 (`_ai-meter-dashboard.nix` had ridden unstamped), `lib/ports.nix` comment, `scripts/post-deploy-check.sh` comment, `docs/agents/desktop.md` bullet, CHANGELOG entry (feature).
7. **HaGeZi deploy bomb — root cause fixed and hashes restored** (`5d1674211`): `scripts/dns-update.sh` derives the HaGeZi base from the file (`extract_hagezi_base`, comment lines ignored, unpinned refs extract empty → loud error), 3 new selftest cases (11/11 green), the 8 wrong hash lines restored — all 6 build got-hashes match, file byte-identical to `c7fb34007^`. Workflow `.github/workflows/dns-blocklist-drift.yml` re-documented (it is a REPAIR pass now) and the stale GitLab claim in `docs/services/dnsblockd.md` corrected.
8. **Live verification (20:45–20:47):**

| Probe | Result |
| --- | --- |
| Unit file `~/.config/systemd/user/quotaboard.service` | `[Install] WantedBy=default.target`; `default.target.wants/quotaboard.service` symlink dated 19:05; old `graphical-session.target.wants` link gone |
| Unit state | `active`, ActiveEnterTimestamp 19:05:13 CET; `graphical-session.target` active only since 19:57:35 |
| Listener | `127.0.0.1:8791` LISTEN |
| Loopback `/health/ready` | 200 `{"status":"up"}` |
| Loopback `/api/quotas` | 200, real providers (`"mock":false` on `/version`, zai `state: ok`, fresh `generatedAt`) |
| `https://quotaboard.home.lan` via `192.168.1.150:443` + SNI | `/health`, `/`, `/api/quotas`, `/favicon.svg` all 200; TLS 1.3; `-Server` header suppressed |
| `/etc/caddy/vhost-layers` | line 39: `protected quotaboard 8791` |
| `/etc/papdashboard/services.json` | tile `AI / Quotaboard / https://quotaboard.home.lan / quotaboard.svg` |
| `https://dash.home.lan/icons/quotaboard.svg` | 200 `image/svg+xml`, 290 bytes |
| Anchors | running = profile = `preferred` entry on `/boot` AND `/boot-mirror` (`init=/nix/store/6q9jp84a…`) |
| Mock-mode pre-deploy probe | vHost `Host` + same-origin `POST /refresh` → 200; cross-origin → 403 (throwaway instance on `127.0.0.1:18791`, killed afterwards, port confirmed free) |

## b) PARTIALLY DONE

1. **Gatus coverage is live by construction but only indirectly verified.** The two endpoints are in the eval'd config (`eval.json`), gatus restarted with the activation (new pid 19:12), and no gatus journal line since 19:00 names quotaboard. I did not find the RUNNING config file and did not read gatus results.
2. **The deploy smoke for quotaboard was not read.** I never opened the smoke section of `2026-11-25_18-54-44.log`; the PASS lines for "Quotaboard API/health" and the auth-gateway leg for `quotaboard.home.lan` are therefore unconfirmed.
3. **Final-tree verification gap.** My `nix flake check --no-build` (17:50) predates: the alert-string/comment cleanup in `quotaboard.nix`, the `dns-update.sh` change, the blocklist restore, the workflow + runbook edits. Covered since then: `dns-update.sh --selftest` 11/11, shellcheck clean, `bash -n`, `check-doc-links.sh` OK, `nix fmt --fail-on-change` clean on every touched file, toplevel build rc=0 at `5d1674211`. NOT re-run: a full flake check, `checks.dns-update-selftest` through nix.
4. **Docs for the blocklist repair are thin:** runbook bullet + workflow comment exist; no CHANGELOG line, no TODO ticks, no AGENTS.md lesson.
5. **Reboot path unexercised:** the boot-time start at the greeter (linger → user manager → `default.target`) is argued from the journal ordering (sops rendered 11:06:54, user manager 11:07:00) and from the 19:05 pre-login start, not yet from a real reboot into gen-1031.

## c) NOT STARTED

1. Harvest of §f into `TODO_LIST.md` + the domain libraries; ticks of the 4 quotaboard rows (`docs/todo/desktop.md` 197/198, `TODO_LIST.md` 3928/3932) and the 3 HaGeZi rows (`docs/todo/pipeline.md` 470, `TODO_LIST.md` 1548, `docs/todo/services.md` 85).
2. CHANGELOG entry for the HaGeZi repair.
3. The upstream quotaboard change (lifetime option or `nixosModules.quotaboard`, `brandAssets` passthru) — needs push permission.
4. Browser check of the tile; DMS bar widget check in the live session.
5. Reading the carrying deploy's log body (why it exited 14 at 19:45:56 while all three anchors read green at 20:47).

## d) TOTALLY FUCKED UP

1. **I ran a stale maintenance script before reading what it edits.** `scripts/dns-update.sh --hashes-only` still hashed the moving GitLab mirror while the file points at a pinned GitHub commit (the comment at the top of `dns-blocklists.nix` says so in its first line). My run wrote 8 wrong hashes on top of the nightly job's 6; the daemon committed that state as `e4c97bb01`. Caught ~10 minutes later by cross-checking the build's got-hashes, then fixed at the root and converged back (`5d1674211`). Any sibling building in that window saw the same FOD failures it already saw since 05:36.
2. **98 minutes of blind re-arming.** My "already live" check compared `/run/current-system` with the exact store path of the toplevel I had built at `5d1674211`. The sibling deployed `74763a8e7` → a different path → my loop never recognised that the payload had landed at 19:05 and kept firing until 20:43: **17 refused deploy invocations** (entry-gate noise in `/var/log/systemnix-deploys/` for everyone's forensics). The right check was one line: is the vHost in `/etc/caddy/vhost-layers`?
3. **I ended my turn parked on the loop without a status line.** The turn ended when the loop gave up; the report, the TODO harvest and the CHANGELOG line were only written because the owner asked.
4. **A false "0 boot entries" reading** — my first anchor probe expanded the entries glob as user `lars` against a root-only directory, so `grep -l` matched nothing. Re-run with the glob inside `sudo` in the next probe. This is the documented permission-blind-read class; I nearly reported an unanchored boot.
5. **Sloppy first edits:** a stray `0#` inside `dns-update.sh`'s new function (syntax-valid, would have failed at runtime — caught by re-reading, and the selftest would have caught it too); a patch script that aborted half-way because the formatter had re-indented the module; em dashes written into source and cleaned up in two passes; a mistyped busctl bus name and one garbage `/proc/diskstats` awk (numbers discarded, never used).
6. **A wrong reading of `|| true`** in `post-deploy-check.sh`: I first took it for an "expected-down" tolerance and planned to remove it; it is the `set -e` guard and every `check_local` call carries it. Nothing was changed beyond the comment, but the plan was wrong until I read the function.

## e) WHAT WE SHOULD IMPROVE

1. **Deploy watchers need a payload check, not a path check.** `scripts/deploy-when-quiescent.sh --fire` loops on rc=13 but treats the most common non-race outcome of a stormy evening (rc=12, pressure gate) as "STOP for human review", and has no notion of "my change is already live". Add `--until-live <command>` (a shell predicate) and `--retry-pressure N`.
2. **Refresh tools must take their target from the file they edit.** `dns-update.sh` is fixed; the same class is one stale constant away in every other "re-hash/re-pin" script (vendorHash shims, expected-locks). An audit row is worth one pass.
3. **CI did not catch the bomb.** The workflow comment promises "a bad hash there opens a normal CI failure" — `c7fb34007` passed. `nix-check.yml` should build the FODs behind `platforms/common/dns-blocklists.nix` when that file changes (cheap: ~23 fetches).
4. **Blocklist freshness is now a deliberate act.** With commit-pinned lists nothing moves by itself; the 30-day staleness alert text in `dns-blocker.nix` ("run scripts/dns-update.sh, commit the hash bump") no longer describes a working procedure. A `--bump-hagezi <sha>` mode (bump commit + re-hash all lists in one change) would make it one command.
5. **`homepage.iconFile` is a dead option** (`integration.nix:372`, consumed nowhere) — wire it into the `extraIcons` fan-out or delete it; today every module hand-wires `services.papdashboard.extraIcons`.
6. **emeet-pixyd carries the heavier pattern** (silent endpoint checks + session-aware meta check + SigNoz rule) for the same "user unit behind a vHost" problem. If its daemon can run pre-login, the quotaboard shape is simpler; if not, the runbooks should say why the two differ.
7. **Agent turn hygiene (mine):** never end a turn on a background loop without reporting; read the top of a file before running a tool that rewrites it; expand globs on the privileged side of `sudo`.

## f) NEXT (dedup-checked against what I saw; none harvested yet)

1. Harvest this §f: tick `docs/todo/desktop.md` 197 + 198 and `TODO_LIST.md` 3928 + 3932 (quotaboard availability rows — answered by this session), add the library row for item 9.
2. CHANGELOG entry for the HaGeZi deploy-bomb repair (script fix, restored hashes, workflow re-doc, runbook correction).
3. Re-run `nix flake check --no-build` on the final tree (my 17:50 run predates five edits) + `nix build .#checks.x86_64-linux.dns-update-selftest`.
4. Verify the two Gatus endpoints in the RUNNING config and their result state (not just the absence of alert lines).
5. Read the smoke section of `/var/log/systemnix-deploys/2026-11-25_18-54-44.log`: "Quotaboard API", "Quotaboard health", and the auth-gateway PASS for `quotaboard.home.lan`.
6. Owner eyeball: Services tab → group AI → tile "Quotaboard" with the clock icon and a green status; click through to `https://quotaboard.home.lan`.
7. Check the DMS bar widget in the live session (first login after the change was 19:57:35): it must show `Z …%  S …%`, not `!`.
8. After the next reboot into gen-1031: confirm `quotaboard.service` is `active` while `graphical-session.target` is still `inactive` (the real boot-time proof).
9. **quotaboard upstream (blocked:push):** lifetime option (session-scoped vs always-on) or `nixosModules.quotaboard`, plus a `brandAssets` passthru; then drop the three-key override in `quickshell.nix`, point the tile icon at the passthru, re-lock.
10. `dns-update.sh`: add `--bump-hagezi <sha>` (commit + all hashes in one change) and a `--check` exit-code mode (the latter is already an open row in `docs/todo/services.md`).
11. `nix-check.yml`: build the blocklist FODs on pushes touching `dns-blocklists.nix`.
12. Local timer `blocklist-auto-update` (weekly Mon 04:00, runs the script WITHOUT `--hashes-only`, so it still advances the StevenBlack pin): decide keep / retire now that HaGeZi is pinned.
13. Reconcile the 30-day blocklist staleness alert text in `modules/nixos/services/dns-blocker.nix` with the pinned model (I only saw the text in a grep, not the full rule).
14. Tick `docs/todo/services.md` 85 (library row is `[ ]` while its queue row `TODO_LIST.md` 579 is `[x]`) — the nightly automation exists and changed meaning today.
15. Wire or delete the dead `homepage.iconFile` option.
16. Make `deploy-when-quiescent.sh --fire` retry rc=12 and accept an "until-live" predicate (or script the loop I kept in `~/.cache/quotaboard-vhost/deploy-loop.sh`).
17. Reconcile why the carrying deploy exited 14 at 19:45:56 although profile (19:33:39) and both ESPs were anchored by 20:47 — an anchor-assertion ordering question in deploy.sh, or a repair that landed while that deploy was still running.
18. Session-lesson rows for AGENTS.md (owner-approved doc edits): "read the URL a file fetches before running a re-hash tool" and "deploy watcher payload-live check".
19. Coordination row for stability: BuildFlow/golangci batteries in agent sessions drove nvme0n1 to 100 % twice tonight and kept the deploy gate shut; heavy batteries and deploy windows should not overlap.
20. The tile icon is the app's generic clock favicon; a real quotaboard mark needs an upstream asset (rides item 9).
21. `services.catalog` has no quotaboard entry — correct under the accepted-debt doctrine ("do not fix the warning by adding entries alone"); nothing to do until the catalog migration resumes. Recorded so nobody "fixes" it.
22. README line 15 ("Self-Hosted Services" summary sentence) does not mention quotaboard; optional one-word addition.

## g) QUESTIONS FOR THE OWNER (cannot self-answer)

1. **Is "always-on" the contract you meant?** You said "available"; I made the server run from boot, independent of any login — which also means it polls the Z.ai and Synthetic quota endpoints 24/7 (about one request per provider per minute, the upstream default). If you only want it while you are logged in, the revert is the three-key block in `quickshell.nix` plus the emeet-pixyd-style session-aware checks.
2. **May I push the upstream quotaboard change** (lifetime option or a `nixosModules.quotaboard` + `brandAssets`) and re-lock SystemNix, or should the SystemNix-side override stay? I never push without an explicit yes.
3. **Blocklist freshness policy:** the HaGeZi lists are now frozen at commit `4efe3657` (2026-11-24) until someone bumps it by hand. Keep it manual, or do you want a cadence (e.g. weekly bump of commit + hashes), given that stale lists let new ad/malware domains through and the 30-day alert will start firing?

## Appendix — scratch (not volatile, `~/.cache/quotaboard-vhost/`)

`eval.json` (config slices), `fc.log` + `fc.head` (flake check), `toplevel.log` (6 FOD failures enumerated), `toplevel2.log` (rc=0), `deploy-loop.log` + `dwq.log` (17 refused invocations), `probe.py` (mock-mode vHost probe), `live-probe.py`, `anchor-probe2.sh`, `gatus-probe.sh`, `matrix.path`.
