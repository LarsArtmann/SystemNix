# YT Sidebar Recommendations → Unhook Extension Landed (eval-verified, deploy-pending)

**Session:** 2026-10-06, ~20:50–21:31 · **Scope:** browser extension work only (Helium) · **Tree at edit:** `2f2f196a` (content-pinned before edit; daemon-committed parallel docs observed, no conflicts)

## Task chain

1. **Ask:** remove YT sidebar recommendations — configure an existing extension or add something?
2. **Research:** full extension inventory read from `platforms/nixos/system/configuration.nix` (21 force-installed exts) + `modules/nixos/desktop/browser-policies.nix` (the ExtensionSettings → `/etc/chromium/policies/managed/` pipeline, Helium proxy `update_url`).
3. **Verification chain (verify-external-claims skill loaded):**
   - uBO wiki raw fetch: `toOverwrite.filters` = policy-deployed My-filters lines; **wholly replaces** the pane (the wipe caveat that shaped the decision).
   - Sourcegraph: `ytd-watch-next-secondary-results-renderer` confirmed as the live YT sidebar element (2025-era userstyles/extensions reference it).
   - Unhook via **AMO raw fetch** (the Chrome Web Store page is JS-rendered and returned EMPTY): v1.6.9, updated **2026-03-19**, Mozilla _Recommended_ badge, 4.6★ / 1,192 FF reviews, 1M+ Chrome users, permissions = `youtube.com` + `m.youtube.com` only, **closed source** ("All Rights Reserved", no repo). Options confirmed: sidebar (Recommended / Live Chat / Playlist separately), end screens, comments, home feed, Shorts tab, autoplay.
4. **Decision:** Unhook in, uBO `toOverwrite` policy OUT (one mechanism; avoids the My-filters wipe). No pruning of existing exts — Shorts Blocker covers Shorts in home/subs/search (broader than Unhook's Shorts-tab toggle); BlockTube is content filtering (different axis).
5. **Edit:** `(ext "khncfooichmfjbepaaaebmommgaepoid" "Unhook")` → `platforms/nixos/system/configuration.nix:625`, YouTube section.
6. **Verify:** `nix eval …chromium.extraOpts.ExtensionSettings --json` contains the ID with `force_installed` + helium proxy `update_url` (22 exts + `*`); `nix flake check --no-build` green. Not committed — daemon sweeps.

## a) FULLY DONE

1. Extension-stack research + primary-source verification of every external claim used in the decision (uBO policy semantics, YT DOM element, Unhook facts/permissions/options/maintenance state).
2. Unhook added to `chromiumExtensions`; rendered policy eval-verified; full flake eval gate green.
3. Both meta-questions answered with evidence: worth-adding verdict (with closed-source caveat) and the ID→name mapping (names live inline in `configuration.nix:602-637`; the IDs-only JSON is Chromium's `ExtensionSettings` schema — no name field exists, `browser-policies.nix:45-47` drops it deliberately).

## b) PARTIALLY DONE

1. **End-to-end live verification** — eval-only so far. Not deployed → not installed → not toggled → sidebar not yet hidden. The "assert WHICH entity served it" doctrine is satisfied at eval level (proxy `update_url` in policy) but NOT at runtime (chrome://extensions probe outstanding).
2. **One-time manual Unhook toggle** — documented as the user's step (per-profile popup storage; cannot be declarative).
3. **Self-harvest** — this report harvests its follow-ups into TODO_LIST.md + docs/todo/desktop.md (done alongside this file).

## c) NOT STARTED

1. `nix run .#deploy` carrying the extension (restarts Helium).
2. Post-deploy install probe: chrome://extensions shows Unhook (CRX served by `services.helium.imput.net/ext`).
3. Toggle ceremony: Unhook popup → Hide Video Sidebar → Hide Recommended (plus whatever else wanted).
4. Functional probe: open a YT watch page, confirm the recommendation sidebar is gone.

## d) TOTALLY FUCKED UP

Nothing destructive; three process defects:

1. **Silent empty fetch (turn 2):** the Chrome Web Store fetch returned nothing; I never flagged the failed source in the answer — just quietly pivoted to AMO next turn. Transparency gap against the verify-external-claims rule ("agent-summarized/failed fetch is not evidence" — an empty fetch certainly isn't).
2. **Wasteful fetch order (turn 1):** pulled the 100 KB uAssets `filters.txt` raw (truncated, useless) BEFORE the sourcegraph code search that actually verified the element. Targeted code search should have come first.
3. **Cosmetic eval pipe:** `nix eval --json | jq` "parse error" was just stderr "Using saved setting" notices mixing into the pipe; self-diagnosed one command later. Hygiene, not damage.

## e) WHAT TO IMPROVE

1. **Tool-order discipline:** sourcegraph/code-search before bulk raw-list fetches; fetch lists only to confirm a specific hit.
2. **Flag failed fetches explicitly** in the answer ("store page empty, pivoting to AMO") — the reader should see the evidence chain's weak links.
3. **Run `nix fmt` after edits** even when formatting looks matched — daemon-swept commits bypass pre-commit filetype legs (documented class, heal-breadcrumb.sh).
4. **Blast-radius grep after count/list changes:** extension-count claims in docs could go stale (+1 ext). Grep ran this time (none stale — desktop.md has no count claims), keep it a habit.
5. **stdout-only pipes for `nix eval`** (`2>/dev/null` or stderr separation) when feeding jq.

## f) NEXT (session-derived; harvested per contract)

1. [blocked:deploy] Deploy carrying Unhook → post-deploy chrome://extensions install probe (which entity served the CRX).
2. [blocked:user] Unhook toggle ceremony + functional watch-page check.
3. [watch] Unhook maintenance watch: closed-source, updated 2026-03-19 — if YT DOM churn breaks it, fall back to the one-line uBO filter (`www.youtube.com##ytd-watch-next-secondary-results-renderer`).
4. [decision] Darwin parity: Unhook (and the YT drawer generally) on macOS Brave/Helium? `platforms/common/programs/chromium.nix` carries only `ytShortsBlocker` there.
5. [ready] Optional readability: an extension-inventory table (ID → name → purpose) in `docs/agents/desktop.md` — today the mapping exists only inline in configuration.nix (this session's "I can't fucking understand the config" question will recur for future readers).
6. Nothing else spawned: the rejected uBO `toOverwrite` path needs no tracking; no new split-brains (Unhook ID lives in exactly one surface, unlike KeePassXC's three-way).

## g) QUESTIONS (cannot be answered from the tree)

1. **Which Unhook toggles do you want ON?** Sidebar-recommendations only, or also end-screen videowall / home feed / comments / autoplay? (Settings are per-profile popup toggles — I can't set them; the answer determines what the post-deploy verification checks.)
2. **Deploy now or batch?** `nix run .#deploy` restarts Helium mid-session; the Spotify deploy row in the queue suggests a batch may already be pending.
3. **macOS parity:** should Darwin's browser get Unhook too (and the rest of the YT drawer), or is distraction-free YouTube a NixOS-only decision?
