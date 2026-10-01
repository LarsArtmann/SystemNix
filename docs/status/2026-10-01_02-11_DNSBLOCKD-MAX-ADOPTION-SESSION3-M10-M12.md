# DNSBLOCKD Max-Adoption — Session 3 (M10 done, M12 mostly done; M11 discovered ALREADY DEPLOYED)

**Date:** 2026-10-01 02:11 CEST
**Plan:** `docs/planning/2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md`
**Prior reports:** `docs/status/2026-09-30_13-07_DNSBLOCKD-MAX-ADOPTION-W1-W4-EXECUTED.md` (superseded at close-out), `docs/status/2026-09-30_13-34_DNSBLOCKD-MAX-ADOPTION-RESUME-VERIFICATION.md`
**Scope of THIS report:** this session only (resume → M10 → lint → M12 partial), plus what I noticed en route.

---

## a) FULLY DONE (this session)

1. **Session-start verification trio** — HEAD at resume was `53e1b27b` (clean tree; 10 commits had advanced past the summary's `37a06935` via parallel sessions). Ancestry re-verified for `485a4166` (M01), `d9556da2` (M02), `8165f8c1` (M03), `b38dabbc` (M06–M08) — all OK. M09 memo rode daemon commit `94e2ac1b`. Lock rev = `f625cfee…` as expected. Content greps confirm all W1–W4 surfaces live in the tree (`allowlist_path`, `csrf_enabled`, devices/users, rate 50/100, render test registered).
2. **Absorbing-commit audit** — `git show --stat b9310217`: flake.lock ONLY (30 lines, the M05 lock bump). Clean absorption, zero foreign churn. No further action.
3. **HEADLINE DISCOVERY: the M11 deploy ALREADY HAPPENED before this session resumed.** Live probes (agent-safe: /proc cmdline, /health via python urllib): running binary = `/nix/store/0rv2rfwi…-dnsblockd-f625cfe/bin/dnsblockd` (f625cfee = **v0.9.3-73**), config = `/nix/store/0ry4913f…-dnsblockd-config.yaml`, `/health` reports `version: f625cfe`. Generation anchored: `system-810` == `/run/current-system`. All W1–W4 keys verified IN THE DEPLOYED YAML: `allowlist_path=/var/lib/dnsblockd/allowlist`, `csrf_enabled:true`, devices evo-x2/rpi3-dns/lan-router/pixel6/lg-tv + user `Lars`, rate 50/100, log_sampling 500/100, `tracking_mode=METADATA_ONLY` (owner gate respected by whoever deployed). **The allowlist data-loss window is CLOSED in prod.**
4. **M10 research (upstream source-level)** — read `internal/middleware/csrf.go` + `internal/server/handlers.go`: CSRF middleware rejects POST/PUT/PATCH/DELETE with **403** JSON `{"error":"Invalid or missing CSRF token"}` when the cookie/token pair is missing; the stats-router chain wraps csrf **OUTSIDE** `requireAuth` (`chain(mux, baseMW + middlewareTail(false))` with protectedMux carrying `authMW` inner). Therefore a bare `POST /api/allow`: **403 = csrf armed, 401 = csrf off** — a clean discriminator requiring no secret material. Also confirmed the prior session's probe-flaw finding: block-page field-greps phantom-green (pre-validated against running v0.9.2 — did NOT ship that probe).
5. **M10 implemented + verified + committed (`4ba06298`)** — 50 lines inserted into `scripts/post-deploy-check.sh` after the dnsblockd memory check:
   - Config-path extraction from the RUNNING unit's ExecStart (`systemctl show -p ExecStart --value` → `/nix/store/…-dnsblockd-config.yaml`), with a clean SKIP when extraction fails (host without dnsblockd).
   - 7 config-key greps: allowlist_path, csrf_enabled:true, `"id":"evo-x2"`, `"name":"Lars"`, rate 50/100, log_sampling_threshold 500 — with per-key missing-list FAIL naming exactly what's absent.
   - Behavioral csrf probe: bare `POST http://127.0.0.1:9090/api/allow` → expect 403; 401 = csrf inactive (FAIL); anything else = WARN inconclusive.
   - Verification performed: `bash -n` OK; pre-commit shellcheck + flake check green; **functional harness** (stubbed `systemctl` + `report_*` + sed-extracted block) → PASS×2 against the live deployed config; **negative test** against the pre-wave config `p6s93ln6…` → FAIL correctly listing all 7 keys missing (csrf probe still passes there — it probes the live server, correct semantics); **skip-path test** (systemctl unavailable) → SKIP.
6. **Lint/format round on W1–W4 .nix files** — `nix fmt --no-update-lock-file -- --ci` → **0 changed** (clean); deadnix → clean; statix → one PRE-EXISTING warning at `dns-blocker.nix:388` (inherit-from style suggestion, not applicable to an options-definition block; proven non-gating: `b38dabbc` passed the hook with this file staged).
7. **T299 ancestry verified** — upstream fix `8e598c01` ("wire resolver seams so root recursion works without forwarders") IS an ancestor of the deployed `f625cfee`. This unblocked the M12 recursion-comment rewrite with facts, not claims.
8. **M12 content edits (all 3 surfaces, all committed):**
   - `platforms/nixos/system/dns-blocker-config.nix` header: blocklist count 25→**23**, coverage ~2.5M+→**~4M+** domains (verified: `nix eval` blocklists=23; realized mapping 4,296,867 domains), recursion comment rewritten — T299 fixed, forwarders (Cloudflare+Quad9 DoT) now documented as deliberate owner choice with the drop-condition stated. → daemon commit `6dfcf827`.
   - `AGENTS.md`: stale SUPERSEDED rev claim corrected (`75b4ce9` → `f625cfe` with live-verification evidence) → `6dfcf827`; **new "Max-adoption wave DEPLOYED LIVE" bullet** (allowlist persistence, csrf incl. the 403/401 discriminator + do-NOT-probe-block-page rule, devices/users + owner-confirm markers, rate limits, extraDomains wiring, render-test contract, tracking-dial gate with memo pointer, T299) → swept into parallel-session commit `bba88c9e` (see §d).
   - Runbook pointers: the tracking-dial memo + plan doc are now referenced from the AGENTS.md bullet.

---

## b) PARTIALLY DONE

- **M12 commit attribution.** Content is 100% committed and live in HEAD, but split awkwardly: `6dfcf827` carries the header+rev-fix under the daemon's heuristic message (my amend attempt failed — see §d), and my AGENTS.md wave bullet landed inside the parallel session's report commit `bba88c9e` (they documented the sweep in their message — attribution preserved in prose, not in a clean commit). **Deliberately NOT fixing by amend**: `bba88c9e` is a foreign commit sitting on top; never amend past parallel commits. Close-out report will cite content locations instead.
- **M11 verification (agent-side half).** Config keys, csrf behavior, version, and generation anchor all verified live. NOT done: dashboard walk items (devices named in Top Clients, Likely-Broken accumulating — user-side), and allowlist-persistence restart test (restart requires root; the smoke probe now guards it at every future deploy instead).

## c) NOT STARTED

- **M13** — TODO harvest/annotations (note: rows should now say "deployed live", NOT "awaiting M11").
- **W7:** M14 (policies + shadow mode), M15 (trial blocklists + persistent cache dir), M16 (ECS options), M17 (h3 block pages).
- **W8:** M18–M21 (wrapper→upstream module migration: design/baseline, impl A, impl B, verification).
- **M22** — cutover (USER window).
- **Close-out report** superseding the 13-07 report (dead-SHA corrections, disposition table in the plan doc).
- **Smoke-harness persistence** — the M10 functional/negative/skip harness was ad-hoc in /tmp (deleted after use); persisting it as a fixture test (à la `scripts/test-offsite-borg-smoke.sh`) is a candidate, not started.
- **Answers-aware actions** for the 3 standing questions (see §g) — none can proceed without owner input.

## d) TOTALLY FUCKED UP (this session's mistakes)

1. **Commit-subject length rejected TWICE by the house hook — 73 chars (M10), then 74 chars (M12 amend).** I miscounted the 72-char limit two times in one session. First cost a retry round-trip; second cost the entire amend window: while I regrouped, a parallel session committed `bba88c9e` on top and my staged AGENTS.md bullet rode into THEIR commit (the exact 2026-08-30 swept-index class — my own Critical Rules call it out and I still lost the race). Root cause: composing messages without measuring the subject line. **Fix:** write subjects ≤70 chars and verify with `awk` length before `git commit` — mechanical, no judgment needed.
2. **Wrong generation-anchor one-liner on first attempt** — I compared `readlink /run/current-system` (a store path) against the string `system-810-link` with grep, which can never match; caught it myself immediately and redid it correctly (`readlink /nix/var/nix/profiles/system-810-link` == current-system). No damage, but sloppy.
3. **statix/deadnix invocation fumbles** — passed multiple files to `statix check` (single-target tool) and a nonexistent `--fail-on-dead-lambda-arg` flag to deadnix; one wasted round-trip.
4. **Averted (credit to prior-session lesson):** did NOT ship the phantom-greening block-page csrf field-grep — probe-before-write discipline held; the 403/401 discriminator was source-verified AND live-validated instead.

## e) WHAT WE SHOULD IMPROVE

1. **Session-start verification should include LIVE DEPLOYED STATE, not just git state.** The single biggest surprise this session was that M11 had already happened — discovered ~10 minutes in via /proc + /health probes. The plan, the resume summary, and the todo list all said "nothing deployed". Standard trio (ancestry / git log -S / git show --stat) should grow a fourth probe: running-binary version + deployed-config keys for the service under work.
2. **Mechanical subject-length gate for myself** (see §d.1): measure, don't eyeball. Every failed hook run risks a daemon/parallel race.
3. **Stage-then-message discipline under daemon+parallel pressure:** the correct order when the tree is hot is `git add <paths> && git commit` composed IN THE SAME command with a pre-measured subject — my M10 commit did this right; the M12 amend did not (message composed leisurely, window closed).
4. **Persist the smoke-block harness.** The sed-extract-block + stub approach validated all three paths (pass/fail/skip) of the M10 probes in seconds; it evaporated with /tmp. The offsite-borg smoke lib precedent (`scripts/test-offsite-borg-smoke.sh` + selftest flake check) is the model — the dns probes deserve the same before someone refactors the smoke script blind.
5. **Parallel-session index hygiene:** at report time the shared index holds a parallel session's staged files (TODO_LIST, storage.md, home.nix, …). I correctly touched nothing. Rule reaffirmed: before ANY commit on this box, `git diff --cached --stat` first and pathspec-commit only my files.

## f) NEXT THINGS (ordered, up to 50)

1. M12 completion check: confirm `6dfcf827` + `bba88c9e` carry all three M12 surfaces (done — content verified in HEAD); record attribution note in close-out.
2. M13: annotate the 5 dnsblockd TODO queue rows in `TODO_LIST.md` as **deployed live 2026-09-30 (system-810, f625cfee)** — NOT `[x]` until user dashboard-walk confirms; keep queue/library in sync.
3. M13: mirror annotations in `docs/todo/services.md` library rows.
4. M13: `docs/todo/upstream.md` tag-row annotation — v0.9.3 tag exists; deployed rev is v0.9.3-73 (`f625cfee`); tag-pin vs follow-master decision unblocked.
5. M14: author `services.dns-blocker.policies` option (name/groups/devices/block/allow/schedule; caps 64 policies / 512 domains; lowercase-slug name assertion).
6. M14: render policies into config YAML behind `optionalAttrs (cfg.policies != [ ])`.
7. M14: extend `tests/test-dns-blocker-render.nix` for policies + negative-proof via worktree mutation.
8. M14: shadow-mode probe doc (`GET /api/policies/shadow` usage, auth'd).
9. M15: author `blocklistTrialUrls` + `blocklistCacheDir` options.
10. M15: plumb PERSISTENT cache dir (`/var/lib/dnsblockd/blocklist-cache` — StateDirectory + ReadWritePaths audit; PrivateTmp eats /tmp defaults).
11. M16: ECS options (`dnsEcsEnabled` + ipv4 prefix 24 / ipv6 56) with INERT defaults (owner nod required to activate).
12. M17: `tlsH3Enabled` inert default + UDP-443 firewall check design note.
13. Each W7 option: eval + render-test extension + pathspec commit with pre-measured subject.
14. M18: wrapper↔upstream option mapping table (what upstream `nixosModules` can/cannot express: runtime whitelist filter, attach-ip, omd exemption, sops CA → overlay list).
15. M18: pre-migration baseline via `git worktree` eval-JSON set-compare (rendered YAML keys + unit text).
16. M19: impl A — consume upstream module, map W1–W7 keys.
17. M20: impl B — re-add SystemNix layers as overlays (whitelist pre-filter → blocklistFiles post-processing; harden/oomd; sops CA).
18. M21: verification — worktree baseline set-compare + VM test green (surface-preservation, paperless-/admin class).
19. M22: USER cutover window (deploy + smoke + watch DNS through one restart cycle).
20. Close-out report superseding `2026-09-30_13-07` (dead-SHA corrections: `accb0522`/`40eeac48` → content citations).
21. Close-out: disposition table sweep in the plan doc (M01–M22 status each).
22. Persist M10 harness as `scripts/test-post-deploy-dns.sh` + wire into the selftest pattern (candidate, owner-neutral).
23. If user confirms device IPs (Q1): fix `dns-blocker-config.nix` entries + re-render check.
24. If user sanctions tracking dial (Q2): flip `tracking_mode` to METADATA_AND_DNS + same-commit render-test assertion update + deploy note.
25. If user wants rpi3 parity (Q3): extend `platforms/nixos/rpi3/default.nix` with devices subset + rate limits (it already inherits extraDomains).
26. Check the stray `/tmp/e2e-repro/dnsblockd serve` process (foreign session artifact, left untouched — verify it's expected/idle).
27. Upstream (dnsblockd repo): consider cutting a tag past f625cfee so consumers can tag-pin (docs/todo/upstream.md row).
28. Verify at next deploy: smoke probes run green end-to-end inside `nix run .#post-deploy-check` (they were harness-validated only — the script itself hasn't run post-deploy since landing).
29. Gatus: confirm no check asserts the OLD config path/rev (none known — spot-check `gatus-config.nix` for dnsblockd path literals).
30. AGENTS.md: at close-out, strike the "Post-deploy live behavior confirmation … still pending" clause if the cached-/health probes were exercised (docs/todo/services.md live-probe items).

## g) QUESTIONS (cannot be resolved without you)

1. **Device identity confirmations (blocks final M07 confidence):** pixel6 = `192.168.1.29` (randomized WiFi MAC `2e:fd:a5:…`) and lg-tv = `192.168.1.62` (Realtek NIC `00:e0:4c:…`) — correct as attributed? The config carries `owner-confirm` markers pending your word. (Static IPs aren't pinned anywhere — these are DHCP/ARP observations; if your router assigns dynamically, say whether to add reservations or accept drift.)
2. **Tracking dial (M09 memo `docs/services/dnsblockd-tracking-dial.md`):** flip `tracking_mode` to `METADATA_AND_DNS` with the NEXT deploy, or hold at METADATA_ONLY? Flip requires your sanction + a same-commit render-test assertion update — both ready to execute on your word.
3. **Who executed the M11 deploy window (system-810, ~before 01:00 tonight), and did the dashboard walk happen?** I verified config/binary/anchor live, but attribution and the UI-side checks (devices named in Top Clients, Likely-Broken Sites accumulating, a csrf-protected allow form post) are outside my reach — knowing this decides whether M11's checklist can be marked complete in the close-out or stays "deploy done, walk pending".

---

**Awaiting instructions.**
