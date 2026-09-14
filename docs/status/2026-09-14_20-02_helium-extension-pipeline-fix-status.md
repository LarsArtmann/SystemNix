# Status: Helium Extension Pipeline Fix (prod=chromecrx root cause) + KeePassXC-Browser

**Date:** 2026-09-14 20:02
**Session goal:** Answer "what secrets manager works with Helium" (researched) → then finish the half-wired KeePassXC integration.
**Plan doc:** `docs/planning/2026-09-14_18-59_helium-extension-pipeline-keepassxc-fix.md`

---

## a) FULLY DONE

1. **Research (verified, not "I know")** — corrected my own first answer (I wrongly claimed extensions must be sideloaded):
   - Helium runs its own Chrome Web Store proxy: `services.helium.imput.net/ext/*` (verified in `imputnet/helium-services` source: `svc/extension-proxy`, Omaha protocol).
   - Helium reads `/etc/chromium/policies/` — verified via `--v=1` log: `config_dir_policy_loader.cc: Found mandatory policy file: /etc/chromium/policies/managed/extra.json`.
   - Helium's user config dir is `net.imput.helium` (matches the already-deployed KeePassXC native-messaging manifest in `platforms/common/programs/keepassxc.nix`, live symlink verified).
2. **ROOT CAUSE of a 2-month phantom bug** — all 20 policy-managed extensions had **never installed** (profile created 2025-12-31, zero `Extensions/` dir):
   - `browser-policies.nix` used `update_url = clients2.google.com/service/update2/crx`.
   - Helium's `spoof-extension-downloader-platform.patch` sends `prod=chromecrx` (`CRX_DUMMY`).
   - CWS answers `prod=chromecrx` update checks with `<updatecheck status="noupdate"/>` — verified live (same request with `prod=chrome` returns a CRX codebase URL).
   - Helium's `proxy-extension-downloads.patch` only proxies installs whose update URL host matches its placeholder; `clients2.google.com` falls through to the raw (dead) path.
   - The 2026-07-29 "fix" (`--disable-background-networking` removal) fixed the downloader-never-runs layer; this layer sat untouched underneath it.
3. **Fix implemented + deployed** (generation **system-778**):
   - `browser-policies.nix`: `update_url` → `https://services.helium.imput.net/ext` (verified serving correct Omaha responses incl. sha256 + proxied CRX URL); stale header comment rewritten with the root cause.
   - `configuration.nix`: added KeePassXC-Browser (`oboonakemofpalcgghocfoadofidjkkk`, force_installed/pinned, cross-referenced with the manifest's `allowed_origins`).
4. **Verification chain (all green)**:
   - `nix eval` shows KeePassXC entry + proxy URL for all entries.
   - `nix flake check --no-build` — all checks passed.
   - Deploy via `nix run .#deploy` (blocked once by the IO-pressure gate — used the documented `DEPLOY_FORCE_PRESSURE=1` escape hatch; the activation is a one-text-file change, and the pressure source is the known wedged llama-rag spinners, not builds).
   - Live `/etc/chromium/policies/managed/extra.json` carries the fix (20 extensions + KeePassXC).
   - **End-to-end probe**: headless Helium with a consent-enabled throwaway profile downloaded and installed **18 extensions in 75 s, including KeePassXC-Browser**. The pipeline works.
5. **Committed**: auto-commit daemon swept my 3 files into `6ddc763f` (79-file batch).

## b) PARTIALLY DONE

1. **Push pending** — `origin/master..HEAD` = 1 commit (mine, batched with a parallel session's work). Not pushed because the user instruction was "report, then wait".
2. **2 of 20 extensions didn't install** in the 75 s probe window (first-run installs trickle over later update checks; two IDs may be dead/slow — the 2026-07-09 audit already flagged unverified 2018–2020-era IDs).
3. **Real user profile not yet served** — the running Helium picks the new policy up on **next browser start**. Only then does KeePassXC-Browser appear there.

## c) NOT STARTED

1. **KeePassXC ↔ browser pairing** — the extension must be connected to the KeePassXC database once (GUI: extension icon → Connect). Inherent user step, cannot be automated.
2. **macOS parity check** — `platforms/darwin/programs/chrome.nix` has its own extension list for real Chrome (which works — prod=chrome). If the user wants KeePassXC-Browser in Helium on macOS too, that's a separate add (darwin runs Helium as well per `darwin.nix`).
3. **Correcting stale docs** — CHANGELOG line 414 and the 2026-07-29/2026-08-09 status docs claim extensions work. They didn't. A correction note belongs in AGENTS.md's gotchas (the `prod=chromecrx` → noupdate class).

## d) TOTALLY FUCKED UP

Nothing in this session's diff is broken. Honest catches from the session:

1. **My first answer was wrong** (claimed "no Chrome Web Store, sideload only") — Helium has a full store proxy. User called it out ("researched or 'I know'"), retraction issued and corrected via source verification.
2. **Deploy smoke: 6 FAILs** — all match the pre-existing baseline (advisory exit), unrelated to this change.
3. **Pre-existing brokenness observed, not caused**:
   - llama-rag units spinning 94% CPU since 13:36 (the documented 2026-09-14 llama.cpp mid-load regression) — containment-only state, pin fix pending.
   - `checks.x86_64-linux.cv` still red on master (known, pre-existing).

## e) WHAT WE SHOULD IMPROVE

1. **The 2026-07-29 verification was a phantom green** — that session removed the flag, saw network requests fire, and declared victory without checking that anything INSTALLED. Rule: for "X now works" claims, assert the artifact (an `Extensions/<id>` dir, a DOM node), never the attempt (a network request).
2. **Extension list hygiene** — 2018–2020-era IDs never re-validated; 2/20 didn't install even via the working proxy. Dead IDs = silent noise on every browser start.
3. **AGENTS.md gotcha entry missing** for this class: "Helium policy installs must use the Helium proxy update_url; clients2.google.com silently no-ops (prod=chromecrx → noupdate)."
4. **Deploy-pressure gate friction** — chronic wedge states (llama-rag) permanently trip the IO-PSI gate, training operators to reflexively use `DEPLOY_FORCE_PRESSURE=1`. The gate works; the wedge fix (llama-cpp pin) is the real answer.

## f) NEXT (ranked, 15 items — scope-limited to what this session surfaced)

1. Push `6ddc763f` (user approval pending).
2. Restart Helium → confirm KeePassXC-Browser appears → user connects it to the DB.
3. Verify the 2 missing extension IDs (dead on CWS?) and prune/fix the list.
4. Add AGENTS.md gotcha: prod=chromecrx → noupdate; policy update_url must be the Helium proxy.
5. Correct the stale "extensions work" claims in CHANGELOG + 2026-07-29/08-09 docs (one-line pointers to this report).
6. Re-run the consent-probe after ~30 min to confirm all 20 land.
7. Fix the llama-rag regression (pin `llama-cpp-rocwmma` back to the 20260905-era build) — unblocks the IO gate AND paperless RAG.
8. Add a probe script (`scripts/verify-helium-extensions.sh`) so this verification is one command next time.
9. Consider `normal_installed` for dev-tool extensions (React DevTools, WhatFont) per the 2026-07-29 review.
10. Decide: uBlock Origin force-installed alongside Helium's built-in uBO fork — duplicate? (flagged 2026-07-29, still open).
11. macOS: add KeePassXC-Browser to the darwin extension list if wanted there.
12. Gatus/Homepage: nothing to add (browser-local feature) — deliberately no monitoring.
13. Helium upstream consideration: report that policy `update_url=clients2.google.com` silently no-ops (their proxy patch only catches the placeholder host) — candidate `verify-before-filing` + `github-voice` flow.
14. Evaluate `--headless` policy probes as a flake check (eval-time can't catch this; a tiny VM test could).
15. Watch the first real-profile extension update cycle (updates ride the proxy only when services are consented — the user's profile IS consented).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Push the unpushed commit now?** (It also carries a parallel session's work — that's the shared-tree reality, but you should know it's not just my 3 files.)
2. **KeePassXC-Browser: `force_installed` (cannot disable) or `normal_installed` (can disable, not remove)?** I chose force_installed to match the existing 20 — confirm.
3. **Do you want KeePassXC-Browser in Helium on the MacBook too?** (The macOS manifest half is already deployed; only the extension-list entry is missing.)
