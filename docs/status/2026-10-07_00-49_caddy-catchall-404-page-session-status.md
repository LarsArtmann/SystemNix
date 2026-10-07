# Status: Caddy Catch-All 404 Page (unknown `*.home.lan` hosts)

**Session:** 2026-10-07 ~00:05–00:55 · single-feature session on top of the (still pending) monitor365 cache-policy chain
**Ask:** "I would like to get to some kind of 404 page if I try X_THIS_SERVICE_OTHER_ANYTHING_ELSE_THAT_DOES_NOT_EXIST.home.lan"
**State at authoring:** implementation complete + one regression check green; rendered-output eyeball, flake check, docs, and deploy still open. Tree is CLEAN, HEAD `ee63655e`, **6 unpushed commits**, parallel freeze-21 session co-committed (details in §d).

---

## Background (what exists today)

- Unknown `X.home.lan` **resolves by design**: dnsblockd carries a wildcard A record `*.home.lan.` → server (`platforms/nixos/system/dns-blocker-config.nix:135`). Caddy's catch-all then **permanently redirected** every unknown host to `dash.home.lan` (`modules/nixos/services/caddy.nix`, the `"https://*.${domain}"` block; cloud twin for `*.larsartmann.cloud`).
- `alerts.home.lan` is a **legacy PapDashboard alias** that deliberately had NO vHost: it rode exactly that catch-all redirect (documented in FEATURES.md ×2, `docs/services/caddy.md`, and the ghost-alias comment in caddy.nix).
- TLS: boot-minted dual-zone wildcard leaf (`*.home.lan` + `*.larsartmann.cloud` SANs, self-asserted at mint), `strict_sni_host on`.
- Cloud zone DNS is explicit-record-only (no wildcard, sdns ignores them) → unknown cloud names NXDOMAIN; only explicit names without a vHost reach the cloud catch-all.

---

## a) FULLY DONE

1. **Research / context** (per AGENTS.md routing): `docs/agents/integration-registry.md`, `docs/agents/sso-dns.md`, `docs/services/caddy.md` (full), all 734 lines of caddy.nix, `platforms/common/dns-local.nix`, `tests/test-cloud-domain.nix`, gatus-config.nix structure + `mkHttpCheck` conventions, `platforms/common/theme.nix` (Catppuccin Mocha), dns-blocker-config.nix record generation. Found every consumer of the old redirect behavior BEFORE changing it (alerts alias, FEATURES rows, runbook lines, net-vpn.md, smoke script, cloud test).
2. **Sandbox proof of the core mechanism** (the one thing refused to guess): `error 404` + `handle_errors { rewrite * /index.html; file_server }` on the **deployed caddy 2.11.4** binary (`/nix/store/1prdlf49vg3f87x7djvpknxcnwj2gmbi-caddy-2.11.4`), probed with python urllib on 127.0.0.1:18099: `/`, `/some/deep/path`, `/index.html` ALL returned **HTTP 404 with the page body** + `text/html; charset=utf-8`, caddy log clean. So the page serves WITH the correct status (the handle_errors 200-trap does not apply on this version).
3. **`modules/nixos/services/caddy.nix` implemented** (landed via daemon commit `3267b34e`):
   - `notFoundRoot` derivation (caddy.nix:67): `pkgs.linkFarm` + `pkgs.writeText`, self-contained branded page (inline CSS + one inline script echoing the requested host via `location.host`, no external assets → LAN-offline safe; Catppuccin Mocha hexes hardcoded with a comment pointing at theme.nix; dashboard link `https://dash.${domain}`). Inlined deliberately to avoid the new-untracked-file eval trap from the multi-agent rules.
   - home.lan catch-all (caddy.nix:467): redirect → `root * ${notFoundRoot}` + `error 404` + `handle_errors` page.
   - cloud catch-all: same 404 page (mirror semantics; NXDOMAIN note + auth-doctrine link note in the comment).
   - NEW explicit `"alerts.${domain}"` vHost (caddy.nix:485) with the catch-all's EXACT old redirect semantics (`redir * https://dash.${domain} permanent`, URI dropped, bookmark-safe); cloud twin comes free via the mirror map.
   - `ghostAliases` emptied with an updated comment (alerts is now a real vHost, not a ghost).
4. **`platforms/nixos/system/dns-blocker-config.nix`**: stale comment FIXED (claimed "unknown *.home.lan names return NXDOMAIN" while the wildcard record 10 lines below resolves them; now documents the wildcard as deliberate 404-page support and the cloud zone as deliberately wildcard-free).
5. **Gatus probe** (`modules/nixos/services/gatus-config.nix:406-414`): new `"Caddy Catch-All 404"` Infrastructure check — `https://catchall-probe.home.lan/` expecting `[STATUS] == 404` + `<1000ms` + cert-expiry `>168h`, discordAlert text naming the two regression shapes (redirect reintroduced / cert mint broke). Name `catchall-probe` deliberately NOT in dns-local (no ghost warning; resolves via the wildcard). Follows the file's literal-`home.lan` URL style.
6. **Post-deploy smoke** (`scripts/post-deploy-check.sh:177`): `check "Caddy catch-all 404" "https://catchall-probe.$DOMAIN/" "404"` next to the existing `:80` redirect check, advisory (`|| true`) like its sibling.
7. **`tests/test-cloud-domain.nix` extended** (+2 checks, header updated): both zones' catch-alls must contain `error 404` + `handle_errors` AND NOT `redir…dash` (per-line matches — `builtins.match`'s `.` does not cross newlines); `alerts.<zone>` vHosts must exist in BOTH zones. All using the REAL evo-x2 eval.
8. **Verification run:** both edited Nix files parse (`nix-instantiate --parse`); **`nix build .#checks.x86_64-linux.cloud-domain` PASSED** (pure-eval regression suite over the real evo-x2 + rpi3 configs — proves full evo-x2 eval works with all changes and every assertion, old + new, is green).

## b) PARTIALLY DONE

1. **Rendered-Caddyfile eyeball** — eval'd `environment.etc."caddy/caddy_config".source` fine, but the `Caddyfile-formatted` derivation needed a build; that `nix build` is **still running in background shell 00D** (empty output so far; likely nix contention with the freeze-21 session's battery). The config's CONTENT is already indirectly proven (cloud-domain check matches on the rendered extraConfig strings), but the human eyeball of the live block is unfinished.
2. **`nix flake check --no-build`** — not yet run this session (the cloud-domain check is stronger but narrower; the fast whole-flake gate is still owed).
3. **Formatting/lint of the edited files** — no alejandra run on my 4 Nix files, no standalone shellcheck on post-deploy-check.sh (the pre-commit legs were BYPASSED: the daemon committed my files, and daemon commits skip staged-path lint legs — the documented daemon-amend-bypass class; shellcheck must be run standalone).

## c) NOT STARTED

1. Docs: `docs/services/caddy.md` — three spots describe the catch-alls as "unknown → dash" redirects (vHost-map paragraph ~line 22-23, ghost-alias paragraph ~line 43-44, cloud-mirroring section ~line 143-144) + the alerts alias sentence; all now stale.
2. Docs: `docs/services/net-vpn.md:23-24` ("Cloud catch-all redirects to `dash.larsartmann.cloud`").
3. Docs: `FEATURES.md` two rows saying "`alerts.home.lan` redirects via the catch-all" → now an explicit vHost.
4. `CHANGELOG.md` entry under `[Unreleased]`.
5. Commit-message repair for the daemon commits carrying this work (see §d.5) — currently mislabeled "chore: auto-commit (heuristic)".
6. `nix run .#deploy` + the full live-verify battery (below, §f 1-4).
7. Self-harvest of §f into TODO_LIST.md + domain libraries — **deliberately deferred**: the user gated the session with "THEN WAIT FOR INSTRUCTIONS", and TODO_LIST.md was foreign-dirty for most of the session (freeze-21 session). Will harvest on instruction.

## d) TOTALLY FUCKED UP

1. **First sandbox probe hit a FOREIGN service.** I ran the test caddy on port 8099 without checking `ss -ltn` first; something else answers there (full HTML app, `class="h-full"` Tailwind-style body — NOT my fixture). I almost read those responses as caddy semantics; caught it only because the body did not match my fixture. The 18099 rerun is the authoritative proof. Port 8099 is unidentified (flagged in §f).
2. **Edit tool rejected my first gatus edit** ("must read the file first") — I had "read" gatus-config.nix only via bash sed/rg, not the view tool. Known rule, still cost a round trip.
3. **No content-pin BEFORE the first write.** The multi-agent discipline (rev-parse + status + log before every write in this shared tree) was run only AFTER the caddy.nix multiedit — and it promptly revealed the daemon had already swept the file into `3267b34e`. Preached in AGENTS.md, skipped in practice.
4. **A verification loop left dangling:** the rendered-Caddyfile `nix build` slipped into background shell 00D and sat unfinished when the status report was requested. The single worst item on this list — "assert WHICH config is live" is half of this task's contract.
5. **Daemon commits carry this session's work under heuristic messages, mixed with a foreign session's files:** `3267b34e` = my caddy.nix (130 lines) + dns-blocker-config.nix + the freeze-21 session's status report; `4fba14c3` = my gatus/smoke/test edits + foreign `check-buildcache-known-parity.sh` + more. I deliberately did NOT amend (mixed commits + a live second session = amend race), but the repair is now unscheduled debt, and the pre-commit lint legs never saw these files (daemon commits skip staged-path legs).
6. Minor: my first planned comment text used em dashes (banned in source) — caught during edit drafting, not before.

## e) WHAT WE SHOULD IMPROVE

1. **Pin-first, always**: `git rev-parse` + `git status --short` before the FIRST write of any session in this tree, not after the first daemon sweep.
2. **Port hygiene in sandbox tests**: `ss -ltn` before binding; assert the response body equals the fixture, never just the status code — the mismatch was the only thing that exposed the 8099 pollution.
3. **Never park a verification**: either run it synchronously with a timeout, or poll the background job to completion before moving on.
4. **View tool before edit tool** — bash sed/rg output does not satisfy the edit tool and shouldn't substitute for a real read.
5. **After every daemon sweep touching my files**: run the skipped lint legs standalone (shellcheck/deadnix/statix) immediately, not "later".

## f) UP TO 50 THINGS TO GET DONE NEXT

**This task — finish the chain (in order):**
1. Collect background shell 00D; eyeball the rendered Caddyfile: `*.home.lan` + `*.larsartmann.cloud` blocks carry `root * <store>` + `error 404` + `handle_errors`; `alerts.home.lan`/`alerts.larsartmann.cloud` carry the dash redirect; no other block changed.
2. `nix flake check --no-build` (whole-flake gate incl. audits).
3. Standalone `shellcheck scripts/post-deploy-check.sh` + alejandra check on the 4 edited Nix files (daemon-swept lint bypass).
4. Docs: caddy.md (3 catch-all spots + alerts sentence + a short "404 page" note: store-served, single page, dash.home.lan link by auth-doctrine).
5. Docs: net-vpn.md cloud catch-all sentence.
6. Docs: FEATURES.md two alerts rows.
7. CHANGELOG entry under `[Unreleased]` (behavior change: unknown hosts 404 instead of redirect; alerts alias preserved; gatus + smoke wired).
8. Commit the doc batch with a proper message (pathspec-commit only my files if the tree is dirty again).
9. Deploy via `nix run .#deploy` (owner call, see §g.1; caddy does a full RESTART on deploy per runbook — brief 80/443 blip).
10. Live verify: `https://catchall-probe.home.lan/` → 404 + branded body (python urllib; CA from sops path if readable, else explicitly noted verify-off probe).
11. Live verify: `https://alerts.home.lan/` → 301 → `https://dash.home.lan` (alias preserved) + cloud twin.
12. Live verify a random unknown host (browser or Host-header probe) → 404 page; `dash.home.lan` + one protected + one plain vHost unaffected.
13. Watch the FIRST gatus cycle of "Caddy Catch-All 404" go green (no alert noise on the new check).
14. Run `scripts/post-deploy-check.sh` end-to-end (new line exercised).
15. Self-harvest §f items into TODO_LIST.md + `docs/todo/services.md` per the self-harvest rule (deferred, see §c.7).

**Hardening / follow-through spawned by this session:**
16. Identify the foreign listener on 127.0.0.1:8099 (which unit/process serves that HTML app; is the port registered in lib/ports.nix or a stray dev server).
17. Eval-time pairing assertion: caddy's catch-all vHost should THROW if the `*.home.lan.` wildcard DNS record is ever removed (they are mutually dependent; today only the runtime gatus check notices, after deploy).
18. Extend the catch-all gatus alert text for the NXDOMAIN case (wildcard record removed → DNS failure, not 301/502; current text names only redirect + cert shapes).
19. Consider mirroring the 404 page for the cloud zone with a `dash.larsartmann.cloud` link variant IF the owner wants zone-consistent escape links (§g.2).
20. `:80` non-subdomain branch (bare-IP/foreign-Host HTTP → dash) is unprobed — one more smoke line if desired.
21. Sweep dns-blocker-config.nix for other comments contradicting adjacent config (this session found one of that exact class).
22. The empty `ghostAliases` mechanism: fine as-is; leave a breadcrumb that future legacy aliases must be explicit vHosts (the comment already says it — verify it reads that way after fmt).

**Standing monitor365 chain (prior session, still waiting on owner answers):**
23. Push monitor365 master (agent pushes forbidden; batched with CI-PAT decision?).
24. `nix flake lock --update-input monitor365` + `nix flake check --no-build`.
25. Deploy → live header verification (`/ui/bootstrap.js` = `no-cache, no-store, must-revalidate` upstream; hashed asset = `immutable`).
26. THEN remove the Caddy `@noCache` override (caddy.nix) + its annotation in the same commit + close the `[blocked:deploy]` row in docs/todo/services.md.
27. Answer the 3 open monitor365 questions (push cadence; fleet-wide cache doctrine; `/ds/` coverage).

**Git hygiene:**
28. Repair messages of `3267b34e` + `4fba14c3` (coordinate with the freeze-21 session — §g.3).
29. Push master (6+ unpushed commits, owner-run).
30. Confirm the freeze-21 session's files landed intact inside the shared daemon commits (spot `git show --stat` — their TODO_LIST/stability edits rode `4fba14c3`-adjacent commits).

**Optional polish (cheap, same theme):**
31. Add the 404 page's HTML to a `nix fmt`-safe check (no action needed — inline string; just confirming fmt stability).
32. Consider listing the served page's store path in the runbook for debugging (`readlink` recipe).
33. Test the 404 page's JS fallback (file:// or JS-off) — the `<code>` placeholder text reads fine without JS (already designed; verify once live).
34. Evaluate whether `handle_errors` should also emit a `text/html`-typed body for `/favicon.ico`-style noise requests (cosmetic; current behavior fine).
35. After deploy, re-run `nix run .#pre-reboot-check`? Not needed (no boot-chain change) — record the deliberate skip.
36. Update `docs/services/caddy.md` vHost-map table to include the catch-alls + alerts as first-class rows.
37. Add `catchall-probe` to any smoke allowlists that enumerate probe hostnames (none known — verify none exists).
38. Double-check the PapDashboard `services.json` / bookmarks for any `alerts.home.lan/deep-path` links that relied on URI-dropping redirect (kept exact old semantics, so safe — confirm no one relied on the OPPOSITE).
39. SigNoz: confirm the new gatus check's results appear in the dashboard group as expected (Infrastructure group).
40. Verify HTTP/3 path for the 404 page once live (curl --http3 equivalent from LAN; informational only).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy batching:** verify-and-deploy the 404 chain right after the remaining checks, or hold and batch with the monitor365 lock-bump deploy (one switch instead of two)? The tree currently also carries the freeze-21 session's committed work either way — deploying ships ALL of it.
2. **Cloud-zone page:** keep ONE 404 page linking `dash.home.lan` for both zones (auth-redirect doctrine, my current implementation), or a mirrored variant linking `dash.larsartmann.cloud` for cloud-host typos?
3. **Heuristic commit repair:** `3267b34e`/`4fba14c3` carry this feature under "chore: auto-commit (heuristic)" messages, mixed with the freeze-21 session's files. All unpushed. Coordinate a message-repair amend with the other session, or leave the heuristic messages and move on?

---

*Evidence: sandbox probe outputs in-session (caddy 2.11.4, port 18099, 3× 404 + fixture body); `checks.x86_64-linux.cloud-domain` build success `/nix/store/sp8jl6gmfsk0q0xr64h55faixjkf3wnb-cloud-domain-test`; caddy.nix:67/467/485; gatus-config.nix:406-414; post-deploy-check.sh:177; test-cloud-domain.nix:92-112; dns-blocker-config.nix:124-131.*

## §f harvest disposition (close-out 2026-10-07 02:0x)

- **Queued** (TODO_LIST.md + matching library, both surfaces edited): §f.17 → services, §f.18 → services, §f.20 → services, §f.21 → services, §f.39 → monitoring; §g.3 (commit-message repair) → pipeline `[decision]`. §f.16 was MERGED into the existing `:8099 poller` row (services library §f.3) instead of a duplicate — same unknown service; my probe adds the serves-HTML evidence.
- **Done in this close-out** (no queue entry): §f.1-14 executed in order (rendered-Caddyfile eyeball, flake check, standalone lint incl. the repo-pinned treefmt — the unpinned `nixpkgs#alejandra` 4.0.0 churn this induced was reverted, committed state is canon-clean; docs; pathspec commit `34211ef4`); §f.22 spot-swept (only the fixed comment matched); §f.30 confirmed (freeze-21 files intact across `4fba14c3`/`e49624eb`/`83225904`); §f.32 done (debug recipe line in the caddy.md 404 section); §f.37 verified — no allowlist enumerates probe hostnames; §f.38 verified — no `alerts.home.lan` deep links in papdashboard/platforms.
- **Folded into live verify**: §f.13 (first gatus cycle), §f.14 (post-deploy-check end-to-end), §f.33 (JS-off fallback is the static `<code>` placeholder by construction; confirmed on the live body).
- **Deliberately NOT harvested**: §f.19/§g.2 (owner decision, stays open as a question — no work item until decided); §f.31 (no-op: the inline string is fmt-stable, repo treefmt reports 0-changed); §f.34 (cosmetic, current behavior fine); §f.35 (deliberate skip recorded here: no boot-chain change in this deploy, pre-reboot-check not re-run); §f.36 (the rewritten vHost-map paragraph already names catch-alls + alerts as first-class hand-written vHosts — table rows would duplicate it); §f.40 (informational only). The monitor365 standing chain (§f.23-27) and the push (§f.29) stay owner-gated from the prior session (tracked in the services.md noCache row).
- **Deploy note:** the parallel freeze-21 session's own `nh os switch` (started 01:47:46, pid 333871) carried this feature (my code commits 00:16/00:19 predate its eval) but exited WITHOUT creating a profile generation (still 828 from Oct 6 16:49) — its deploy failed; state at close-out start, own deploy re-attempted by this session.
