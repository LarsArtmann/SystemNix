# Status: Journal Hauptbuch — Lock Float, g-2 Answer, journal-serve Module (Deploy Pending)

**2026-10-26 15:05 CET · session span ~07:00 → 15:05 (with an idle gap ~11:15–15:05) · single agent (crush, glm-5.3) · evo-x2 working tree**

Trigger: owner asked for "the deployment of `~/projects/journal`", then discovered the new UI exists, hit the loopback guard on `journal serve --addr 0.0.0.0:8484`, and answered the upstream g-2 deploy-shape question (authenticated shared reverse proxy). Standing instruction: break into steps, execute, verify, keep going.

Scope discipline: ONLY this session's run (journal float → gen-950 verification → g-2 ask → journal-serve module → docs → commit attempts). Parallel sessions' work (caddy-edge, gen-949/951/952 deploys, fast-todo waves, hot-caches, opencloud port moves) is attributed, never touched.

---

## a) FULLY DONE

| # | What | Evidence | Surfaces |
|---|------|----------|----------|
| a1 | Journal UI understood end-to-end BEFORE acting: `journal serve` (Hauptbuch tier-0, commit 5407b71 upstream, pushed to origin/master=bad22c5) is loopback-only BY DESIGN until upstream T16 passkey auth; upstream T23 (NixOS module) explicitly gated on owner question g-2 | `cmd/journal/serve.go` errNonLoopbackBind; tier-0 closeout report §c/§f-31; TODO_LIST External g-2 | research only |
| a2 | Lock float 045476b → bad22c5 with probe-before-lock: FOD built clean at the target rev (no nix-hash-fix needed), registry row updated, trio (flake.lock + flake.nix comment + expected-locks.nix) committed ATOMICALLY with full pre-commit battery incl. the FOD-realized toplevel build gate | commit `89656bf44`; probe store path `137q6gkj…` | flake.lock, flake/expected-locks.nix, flake.nix |
| a3 | Deploy landed (via a sibling session's gen-950 — see d7) and verified: `readlink /run/current-system` == profile == newest-by-number (`system-950-link`) = ANCHORED ✓; deployed PATH binary `/run/current-system/sw/bin/journal` == bad22c5 store path | anchor check output 09:44; `journal --version` = bad22c5 | evo-x2 system state |
| a4 | Dashboard verified end-to-end on the DEPLOYED binary against real `~/books`: HTTP 200 on 127.0.0.1:8484, CSP/CSRF headers present, listener loopback-only; NEGATIVE test: `--addr 0.0.0.0:8484` refused with the fix message; clean shutdown by absolute-path kill | probe transcripts 07:24/09:44; serve2.log | verification only |
| a5 | Stale "no daemon, no port" claims corrected in ALL 4 surfaces (flake.nix input comment, lib/lars-packages.nix, journal-backup.nix header, docs/services/journal.md) — first pass said "no UI yet exists" which WAS true at lock time and was re-corrected after g-2 | this session's edits | docs + comments |
| a6 | SIDE-FIX (blocker for everything): the 01:35 memory-emergency-guard sacrifice left fastflowlm's :52625 socket dead → pma daemon's LLM provider refused → EVERY fleet auto-commit failing since ~01:38 (SystemNix batches failed 07:20/07:30 with `[transient:commit.generate]` + stage_all exit 128). Diagnosed via `journalctl -u projects-management-automation` + `journalctl -u fastflowlm.socket` (guard fired 01:35:03); memory verified healthy FIRST (62G avail, PSI 1.7%, zram 49%); socket re-armed via `busctl StartUnit`, cold-load kicked, daemon committing again by 08:03 | pma journal 07:20–08:03; ss 52625+52626 LISTEN | fastflowlm socket, daemon pipeline |
| a7 | g-2 asked properly (structured question after the owner hit the loopback guard): options = Caddy vHost + SSO / tunnel-only / unit-only; owner chose **sso-vhost**; answer recorded WHERE THE QUESTION LIVES — journal repo TODO_LIST External row (struck through, answered, RP ID = journal.home.lan) | question tool exchange; journal TODO_LIST (swept by its daemon 430a805) | journal repo |
| a8 | `services.journal-serve` module authored (modules/nixos/services/journal-serve.nix): unit runs `journal serve` as primary user, WorkingDirectory=~/books, ConditionPathExists clean-skip, harden{MemoryMax 1G, ProtectHome=read-only, ReadWritePaths=~/books} (dashboard MUTATES: waive/reconcile), serviceDefaults, ioTier.background, start limits, ExecStart embeds store path + port from registry; registry entry `journal-serve` (subdomain `journal`, layer **protected**, Gatus check `pat(*Hauptbuch*)` Finance 60s, tile firefly-iii.png Finance) | eval-rendered ExecStart + integration entry probes | module tree |
| a9 | All wiring: `lib/ports.nix` `journalServe = 8484` (port-registry-audit clean), `platforms/common/dns-local.nix` +`"journal"` (dns assertion passes), enable in `platforms/nixos/system/configuration.nix` | flake check green | wiring |
| a10 | Docs re-stamped: README ledger 133→134 modules / gatus 234→235 + services-table row; FEATURES 133→134; CHANGELOG narrative entry; runbook header/surfaces/Ops rewritten for the vHost reality; T23 todo row closed as ANSWERED | README:82, FEATURES:28, CHANGELOG.md | docs |
| a11 | Full gate suite green on the final tree: `nix flake check --no-build` all-checks-passed; statix clean (fix verified); the daemon swept the final statix-fixed state into `e7149c71d` (12:31, 23 files) — confirmed the sweep carries the FIXED module (inherit (cfg) enable port) | check output; `git show e7149c71d:modules/...` | gates |

## b) PARTIALLY DONE

| # | Item | State | Remaining |
|---|------|-------|-----------|
| b1 | **journal-serve deploy** | Module committed + eval green; gen-952 (live) PREDATES the sweep — unit/vHost/check/tile do not exist on the running system (`journal_2dserve.service` not loaded) | One quiescence deploy + live battery (queued [ready], TODO_LIST + docs/todo/services.md) |
| b2 | **My authored commit** | Never landed under my message: attempt 1 aborted (76-char subject > 72 house limit), attempt 2 (index.lock race), attempt 3 (statix `port = cfg.port` → `inherit`), fix applied+verified — then the daemon swept everything at 12:31 in `e7149c71d` | None required (content verified in the sweep); note for the attribution record |
| b3 | journal repo unpushed commits | 3 pre-session docs commits + this session's TODO_LIST g-2 edit ride local master (origin=bad22c5 at session start; daemon commits 430a805+ local) | Owner push decision (g-question 1) — never push without ask |

## c) NOT STARTED

- Live verification battery for journal-serve: busctl unit state, ss 8484 (post-deploy), `getent hosts journal.home.lan`, vHost HTTPS probe (openssl s_client via the LAN IP — resolve the caddy edge IP via ss first; the 443 IP map is perishable, .150 vs .200), gatus first-fire green, PapDashboard tile render, post-deploy battery review.
- VM/boot test for the module (deliberate skip candidate: unit is ConditionPathExists-gated and simple — but caddy-mint precedent exists; flagged as a possible follow-up, not self-assigned).
- Upstream T16 (passkey auth) follow-ups — upstream is actively developing (close-gate feature landed in journal master mid-session); when T16 ships: revisit layer (plain + native OIDC vs forward-auth double-auth).

## d) TOTALLY FUCKED UP

1. **Three structural Nix errors in the first module draft** (bare optionalAttrs in attrset position, missing `options` param, brace mismatch after the fix) — I wrote it from memory instead of copying the bank-sync skeleton first. Cost: 3 eval roundtrips. The examplar was already open in another buffer.
2. **doc-counts drift caught me TWICE** (README, then FEATURES) — I bumped counts only after each gate failure instead of proactively grepping ALL count surfaces before touching the module count.
3. **Two commit attempts burned on process discipline**: 76-char subject (limit 72 — didn't count before writing); index.lock races because my first commit had no wait-for-lock loop.
4. **statix finding shipped in my authorship** (`port = cfg.port` adjacent to `inherit (cfg) enable`) — caught by the hook, not by me.
5. **False UNANCHORED alarm** after gen-950: I compared a resolved store path against a relative symlink target (`system-950-link`) — procedure botch, re-run correctly within one command.
6. **Garbage pidfile** (`echo $! > file` wrote "g1" under the fish/bash interplay) → kill failed → had to re-resolve via pgrep. Agent shells here should resolve PIDs via pgrep/ss directly, not $$-capture across subshells.
7. **I fired a deploy at 09:43 without pre-checking for a concurrent deploy** — a sibling session's deploy was mid-flight (in post-deploy-check); the flock guard aborted mine cleanly (exit 13) and the sibling's build carried my committed float, but the correct pre-check (`pgrep -f deploy`) was missing. Luck + guard, not discipline.
8. **Premature "LANDED" in the T23 todo row** — I marked the row ANSWERED+LANDED while the module was written but NOT deployed (corrected this pass: ANSWERED + committed; deploy tracked separately). A reviewer reading the row at 14:00 would have believed journal.home.lan existed.
9. **question-tool schema error** (missing required description field) — one wasted round trip.

## e) WHAT WE SHOULD IMPROVE

1. **Copy the exemplar skeleton first** when authoring a new service module (bank-sync for registry+unit modules); the routing table already names the references — use them as templates, not just docs.
2. **Pre-flight ALL count surfaces** (README ledger + FEATURES) in one grep before any change that moves module/check counts — the doc-counts gate is deterministic and cheap to satisfy proactively.
3. **Always wrap agent-side commits in a wait-for-index.lock loop** in this tree (3+ concurrent committers is the NORM, not the exception).
4. **Count the subject line** before writing a commit message (72 is the house limit; em-dashes and long product names eat it fast).
5. **Pre-check `pgrep -f 'deploy|switch-to-configuration'` before firing ANY deploy**, even inside a "quiet window" — the flock guard is a safety net, not a plan.
6. **PID capture in agent shells**: resolve via `pgrep -f`/`ss -ltnp` at kill time; `echo $!` across subshell/fish boundaries is unreliable here (d6).
7. **When answering capability questions, lead with the roadmap** — my first "no URL, not web-facing" answer was factually correct but flat; the frustration it earned was partly avoidable by stating the upstream dashboard plan + tunnel one-liner in the same breath.

## f) Up to 50 things we should get done next

1. **Deploy journal-serve** (queued [ready], TODO_LIST + docs/todo/services.md): free 8484 first — a manually-run `journal serve` (owner dogfood session) held the port at 15:05; the unit cannot bind until it stops.
2. Post-deploy live battery (see c-list): unit state, port, DNS, vHost probe, gatus first-fire, tile, anchor discipline + `git status` clean check.
3. Re-probe the fastflowlm socket stability after the next memory-guard storm day — the guard's io-drain restore fix (2026-10-25) narrows but does not eliminate the down-window; a follow-up storm leaves the daemon commitless again (noticed, not researched).
4. Owner: push journal master (4+ local commits incl. the g-2 answer record) — agent never pushes unasked.
5. When upstream T16 passkey auth lands: decide layer=plain + native OIDC (avoid double-auth) vs keeping forward-auth; RP ID already fixed (journal.home.lan).
6. Consider a journal-serve VM/boot leg (or a documented deliberate skip) so the unit's first real start isn't on the production deploy (caddy-mint precedent).
7. The two foreign [ready] rows that rode my services.md commit scope (netbird dex check, 443-IP-map doc) belong to the 10:46 session — confirm they land in the next prune/harvest pass.
8. gatus check tuning after first fires: response-time baseline for a loopback SQLite dashboard (current `< 1000` is loose; bank-sync's own is 1000).
9. Add `journal-serve` to the month-end runbook's tool inventory (upstream journal repo `docs/runbooks/month-end.md`) once the vHost is live — the owner's dogfood flow should point at journal.home.lan.
10. Re-verify the README table row for journal-serve post-deploy (URL column claims journal.home.lan — currently forward-looking).

## g) Questions for the owner (cannot be figured out from the repo)

1. **Push journal master?** Local master holds 4+ commits beyond origin/bad22c5 (3 pre-session docs annotations + this session's g-2 answer in TODO_LIST). The SystemNix lock floats `?ref=refs/heads/master` — the g-2 answer record only reaches CI/other machines via push.
2. **Free 8484 or wait?** The manual `journal serve` on 8484 (looks like your dogfood session) blocks the journal-serve unit's bind at deploy time — should the deploy row stop your process (it's your terminal), or do you want to keep the manual instance until T16 and I deploy only when you say?
3. **Monitoring appetite for the money surface:** is the functional loopback check (`pat(*Hauptbuch*)` + 200) sufficient, or do you also want a vHost-path check (https://journal.home.lan through oauth2-proxy, asserting the auth redirect) so an auth-layer break pages you — knowing that probe rides the forward-auth path every 60s?

---

*Self-harvest: §f.1–f.2 landed as one [ready] row in TODO_LIST.md + docs/todo/services.md (the T23 row corrected from premature "LANDED" to ANSWERED+committed). §f.3–f.10 are recorded here for the next harvest pass; f.4 is owner-gated (question 1).*
