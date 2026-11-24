# GLM-5.4 to Crush → gen-1028 Deploy → Verified → Queue Grind (2026-11-24, 22:37)

Single session, ~20:05–22:37. Owner order: "Add https://docs.z.ai/guides/llm/glm-5.4 to crush NOW!",
later widened to "bypass I/O check, make sure it works", then "work the WHOLE TODO list until done
and verified". The session ended up unblocking and landing the whole evening's deploy wave (which
three prior attempts — two by a parallel session, one by me — had burned on an overview FOD and the
doc-counts gate), verifying GLM-5.4 end-to-end, and closing 5 queue rows.

**Headline: GLM-5.4 is in crush, deployed on evo-x2 gen-1028, and verified END-TO-END
(http 200, `served_model: glm-5.4`, correct reply, thinking active, tokens metered through ai-meter).**

---

## a) FULLY DONE (all verified live in this session)

1. **GLM-5.4 spec research** (docs.z.ai): 1M context, 128K max output, image/video/file input,
   Loop Transformer flagship. Key findings that shaped the declaration: (a) Coding-Plan-only for
   now — the Model API is "pending security assessment", so **no PAYG pricing is published**;
   (b) thinking is default-ON for the GLM-5 series (GLM-5.3/Flash are forced) → `--thinking always`
   matches the provider default and survives slot routing; (c) z.ai's API exposes thinking
   enabled/disabled only — the picker's low/high/max tiers for glm-5.3 are catalog-side presets,
   not an API surface.
2. **crush-config declaration** (pushed `eed931d`, required — SystemNix consumes it as a github
   input): `model add zai/glm-5.4 --name "GLM-5.4" --context-window 1000000
   --default-max-tokens 131072 --can-reason true --thinking always --supports-images true
   --reasoning-effort xhigh` with a doctrine comment. Deliberately **NO `--price-*` flags**
   (unpublished pricing; invented prices are banned — ai-meter reference-price doctrine). Added the
   `module-render-defaults` grep assertion + a FEATURES.md row. `nix fmt` clean,
   `module-render-defaults` + `module-render-configured` checks green before push.
3. **SystemNix lock float** to crush-config `eed931d` (revCount 450, python3-verified — not jq,
   the direnv trap). Lock also picked up the parallel session's **overview float to `955ce9bb`**
   (upstream master, which contains their pushed vendorHash re-pin chain `eb9ed8dc`).
4. **ai-meter.nix**: comment documenting why glm-5.4 deliberately has NO reference-price row yet
   (both-repos mirror obligation when pricing lands; now also a `[watch]` row, see §f.1).
5. **THE DEPLOY — gen-1028, exit 0 at 21:54:45 after 2042s.** Context: the 20:06 and 20:18 deploy
   attempts (parallel session) died on `overview-6e05fdb-go-modules.drv` hash mismatch — the
   then-locked overview rev predated their upstream fix. After the float, the FOD verifies realized
   and valid. My own `DEPLOY_FORCE_PRESSURE=1` attempt was blocked by the battery on the
   **doc-counts gate** (README 320 vs eval-truth 321) + a transient mid-foreign-edit eval failure;
   after the re-stamp, the **foreign 21:20:43 holder evaluated MY committed wave** (sequencing beat
   re-firing) and landed it. The deploy's anchor leg self-repaired the profile and
   `readlink /run/current-system` == `system-1028-link` verified live — the box is finally on the
   Nov-21 nixpkgs root (2786a2a) after a day of failed waves, carrying the glm-5.4 crushrc, the
   overview FOD fix, and the parallel rust-cache/hermes/direnv waves.
6. **GLM-5.4 verified end-to-end**: `~/.config/crush/crushrc:53` live; `crush models` lists
   `zai/glm-5.4`; probe script (`~/.cache/glm54-probe.sh`, key read inside the script, never on
   argv) POSTed through the ai-meter proxy (`:8107/v1/zai` → coding-plan endpoint):
   `http=200`, `served_model: glm-5.4`, `content: 'GLM54-OK'`, reasoning_content present (192
   chars), usage metered (74 tokens).
7. **Doc-counts re-stamp** (the battery blocker): the +1 endpoint is `Rust Cache Critical`
   (rust-cache.nix, rode the 21:02 daemon commit unstamped — the recurring 2026-11-09 class).
   README chain head 320→321 with dated entry, stale prose 315→321, DOMAIN_LANGUAGE.md mirrored;
   `checks.doc-counts` green before commit.
8. **Polkit smoke FAIL triaged (deploy did NOT regress)**: all 4 `module ... is not installed`
   aborts are 00:54:52 from `~/.cache/polkit-fusion-repro/` (a manual repro harness), pre-switch.
9. **Queue grind — 5 rows closed, both surfaces ticked, footer commits:**
   - *Pre-implement daemon-commit probe* documented in CONTRIBUTING's re-dispatch protocol
     (footer grep → tree state → daemon name-only scan).
   - *Session-vs-session lock shapes* as daemon-race policy clauses (6)/(7) (transient foreign
     audits, poll-then-commit for long index.lock holds, amend-hint-wrong-after-rejection).
   - *Mount-state kernel-probe clause* (findmnt / /proc/self/mounts re-proof; EPERM-vs-proof).
   - *Assert-observations-not-diagnoses*: the polkit smoke leg rewritten observation-style (count +
     newest line with ISO timestamp + source path; class attribution and fix prescription removed),
     shellcheck green, stub-tested live — with the gen-1028 false-FAIL as the motivating evidence.
   - *Journal-consumer row closed CLEAN*: no consumer pattern-greps the retention journal text
     (systemd-audit.py matches unit names; no SigNoz/gatus text rule); the selftest was co-updated
     in the suffix commit and builds green at HEAD.
   - The continuation session then unit-scoped the polkit leg further (dms/niri-flake-polkit units
     only; repro lines → non-blocking WARN); landed dual-attributed (`284a4c509`).
10. **Stability row queued** (`57db76ca9`): autopsy-or-clear the 20:44:18 boot cut — boot -1
    (`27ec3ede…`) journal ends MID-ACTIVITY during an io storm (PSI avg10 98.8% at 20:41); boot 0
    (`b4931451…`) started 20:46:44; anchor verified good; no panic markers in quick greps.
11. **Answered the "thinking on/off vs levels" question**: levels come from charm's catalog
    (`zai/glm-5.3` has low/high/max; glm-5.4 is ABSENT from the catalog — that's why it needed the
    hand declaration), and `model add` has no reasoning-levels flag (crush `shellconfig/model.go`);
    the API itself only exposes thinking enabled/disabled, so no capability is lost.

## b) PARTIALLY DONE

1. **crush-config FEATURES.md live-proof polish**: the glm-5.4 row still cites only
   "asserted in module-render-defaults"; the live gen-1028 evidence (200 / served glm-5.4) should
   be added to the Evidence cell and pushed. In-progress at report time.
2. **ai-meter glm-5.4 pricing watch row**: queued with this report (services.md), pairing both
   repos' obligations.
3. **TODO grind**: 5 of ~2,426 open `[ready]` rows closed this session; grind was halted by the
   report order. Remaining rows triaged by domain (pipeline ~1520, services ~1187 links; most
   rows carry multiple domain links).

## c) NOT STARTED

1. The remaining unprivileged-actionable `[ready]` subset (the grind had just warmed up).
2. glm-5.4 as default LARGE slot — deliberately not done: host doctrine keeps large per-project
   (picker store / per-project `.crushrc`); needs an owner decision per project.
3. Catalog-pickup revisit: when charm's zai catalog ships glm-5.4, levels appear automatically and
   our rc declaration (which overrides the catalog) should be revisited/trimmed.
4. SystemNix master push (currently ahead of origin; owner-run per convention — never pushed here).
5. The 20:44 autopsy execution itself (row queued, evidence pull not run).

## d) TOTALLY FUCKED UP (all caught + repaired in-session; nothing landed broken)

1. **curl stdin-piping bug** in probe v1 — piped the JSON body into curl without `--data-binary`,
   so z.ai's backend answered 400 "request body is missing"; one probe cycle burned on what looked
   like a routing failure before the real bug was obvious.
2. **Line-number-based queue tick** violated the full-line-match rule — rows had shifted under me
   (parallel sessions tick constantly); the assertion caught it before corruption; switched to
   content-locate for every tick afterward.
3. **Byte-diff anchor trap (2026-11-03 lesson, live)**: transcribed a long CONTRIBUTING anchor
   from terminal echo; python assertion failed on invisible byte diffs; re-anchored on a short
   grep-count-verified substring.
4. **rc=13 flock misdiagnosis**: two consecutive bounces against a lock whose *recorded* holder
   PID was dead; I briefly read it as a stale-lock wedge, but `flock -n` proved a real kernel-level
   holder (child-inherited fd of a live foreign battery). Also misread the holder as exited once
   (racy /proc check) — it was alive and deploying my wave.
5. **Forced deploy into a mid-edit tree**: my `DEPLOY_FORCE_PRESSURE=1` attempt hit the battery
   while a foreign session was mid-edit (§2 eval failure) — one wasted battery before the tree
   settled.
6. **Python tick-helper bug** (`None` concatenation) → the pipeline.md twin tick silently missed →
   a one-commit surface drift, repaired in a follow-up (`8053ad889`).
7. **Subject-length gate trips ×2** (77-char subjects) — pure noise cycles.
8. An amend was interrupted mid-command (turn cut); re-verified HEAD identity and retried per the
   daemon-race discipline.

## e) WHAT WE SHOULD IMPROVE

1. **Never tick by line number** — content-locate every queue edit from the first attempt; the
   TODO tree is multi-live-writer by design.
2. **Anchor bytes before replace**: `grep -c` a short anchor through the same tool that will
   consume it; never transcribe long anchors from terminal echoes.
3. **Probe scripts**: bodies via `--data-binary`/in-script vars only (never stdin piping); keys
   read inside the script, never on argv — the glm54-probe.sh pattern is the keeper.
4. **Before any forced/patient deploy**, count live `crush -y` sessions and check for eval-relevant
   mtimes <5 min — the §2 transient was predictable from `pgrep -af crush`.
5. **deploy-when-quiescent rc=13 refinement**: "recorded holder dead + no readable fd" should
   distinguish a genuinely free lock (child-inherited fds!) from a stale file — tonight it cost two
   bounce cycles; candidate script gap, could fold into the existing pressure-gate [decision] row.
6. **FEATURES/claims**: add live-verified evidence at the moment of verification, not as a later
   polish pass (the glm-5.4 FEATURES row still says "asserted" only).
7. **Marathon-thinking watch**: z.ai's own docs warn glm-5.4 gets stuck in long "marathon thinking"
   loops; with `--thinking always` on a credits-based coding plan, quota burn is worth a dashboard
   glance the first week.

## f) UP TO 50 THINGS TO GET DONE NEXT

Session-direct (new or reopened by this session):
1. Queue the ai-meter glm-5.4 reference-price mirror when z.ai publishes PAYG pricing — **[watch]
   row QUEUED with this report** (services.md; names both repos' surfaces).
2. Finish the crush-config FEATURES.md live-proof polish (evidence cell: gen-1028, 200, served
   glm-5.4) + push. (b.1)
3. **Autopsy-or-clear the 20:44 boot cut** — queued row (stability.md; boot ids, evidence pull
   recipe included). (c.5)
4. glm-5.4 catalog-pickup revisit row for crush-config (levels appear when charm ships it; revisit
   or trim our declaration then) — candidate new `[watch]` row.
5. glm-5.4 default-large decision per project — owner call (g.2 below).
6. SystemNix master push (owner sweep; never pushed agent-side).
7. Continue the `[ready]` grind — next batch already scoped tonight:
   fix-ticket disposition protocol (pipeline.md:301), twin-session tombstone af13f5aa3
   (pipeline.md:524), GPU pid 4433 (desktop; evidence likely TTL'd → verdict row), watch-events
   operator notification (services), §18 shadow-split polish bundle (pipeline).
8. Post-deploy follow-through per the continuation session's own report: caddy `TQ_API_TOKEN`
   env confirmation (their §f.46), gatus "tq Write API" check-text port spot-check, §44
   drop-protocol pass over the 17 live shims, no `config.warnings` from
   noDashboardTile+subdomain at the final check.
9. First post-deploy 03:00 monitor365 fire verification (services.md [watch] row 625-era).
10. glm-5.4 marathon/quota watch the first week (owner dashboard; no row).

Already-tracked majors visible from tonight's context (pointers, no new rows):
11. **btrbk sends admission-starved since 2026-11-17** (5-night backup gap) — stability.md
    [decision] row, options (a)/(b)/(c), recommend (a)+(c); owner pick needed.
12. Pressure-gate doctrine for chronic-storm eras (rc=12 loop-back vs `DEPLOY_FORCE_PRESSURE=1`
    as routine) — stability.md [decision] row; tonight's owner-authorized force is live data for it.
13. Owner pushes for the interim chains: project-meta (52c248e+), overview (33ff7708→eb9ed8d…
    — eb9ed8dc landed and is now floating), go-error-family (1600c18), then flip the git+file
    interims back to github URLs (continuation session's §g.1).
14. monitor365: trash `monitor365.duckdb.pre-shrink` (39G on the 93%-full root) — sudo-gated,
    owner-run (services.md row).
15. trash-empty realized-reclaim measurement + storage.md row close (TODO_LIST:30).
16. Samsung-side watermark coverage for relocated Go caches (TODO_LIST:34).
17. Post-reclaim buildcache list cleanup (TODO_LIST:35).
18. `du --max-depth=2 /data/ai` breakdown refresh (TODO_LIST:37 — 535G figure is from 10-11).
19. Attribute the 2026-10-10 /data/ai +76G growth if it resumed (TODO_LIST:38).
20. Explain the ~175G df-vs-du gap on /data (TODO_LIST:45).
21. Re-verify /data du -sb baseline at MB grain (TODO_LIST:44).
22. Deploy-gate assertion: live btrbk retention matches the flake (TODO_LIST:51).
23. Co-change guard: `snapshot_preserve` edits must touch the freshness-alarm comment (TODO_LIST:52).
24. tq harvest gate: skip sudo-only remainders regardless of tag (TODO_LIST:32).
25. Machine-readable gate fields on queue rows (`gate:sudo`/`gate:owner`/`gate:deploy`)
    (TODO_LIST:57).
26. Harvest-gate: stamp-age+verdict skip for `[watch]` re-fires (TODO_LIST:46).
27. Re-fire protocol footer gap for daemon-landed fires (TODO_LIST:47).
28. Unharvested-§f-report sweep (~202 reports; TODO_LIST:41) — batched by month.
29. Log-only disposition in the dispatch contract (TODO_LIST:43).
30. Stale-row-snapshot harvest fix (TODO_LIST:40).
31. Re-arm llama-embeddings after the calm-gate failure (stability.md row).
32. dnsblockd gateway-mode post-deploy live-verify + off-switch drill (services.md row).
33. Post-deploy twin verification: fine-tune + pim-sync push_mirrors (services.md row).
34. pim-sync Kith projection spoke (services.md row).
35. Surface watch events to the operator (desktop notification) (pipeline row).
36. Queue premise-provenance + verification-failed lane (pipeline row).
37. Extend execution-marker convention to tq batches (pipeline.md:525-adjacent).
38. post-deploy-check remaining FAIL-leg review for assert-causes patterns beyond polkit
    (the row's spirit; polkit leg done tonight).
39. GPU pid 4433 amdgpu fini identification (evidence likely 30d-TTL'd → honest verdict row).
40. Idle-Tctl 98 °C in-shape reading annotation — landed tonight by the continuation session
    (`75e053079`); verify the row state on next pass.
41. Freeze #60-63 boot-evidence census — continuation session pulled it tonight
    (`33c4bd728`); cross-check my 20:44 row against their ledger for double-tracking.
42. AI-meter viewer wave follow-ups — continuation session harvested 9 rows tonight
    (`29bce883a`); they are in the queue already.
43. Rust-cache freeze follow-through rows — landed tonight (`47421770d`); verify none remain open.
44. Flag the fish-startup 208ms-under-pressure smoke WARN as pressure-attributed only (no action
    unless calm-baseline regresses).
45. Keep `~/.cache/polkit-fusion-repro/` in mind as a known false-FAIL source — now WARN-split in
    the smoke leg; no further action expected.
46. crush-config: consider a weekly catalog-diff check (WARN when charm's zai catalog gains
    hand-declared models) — improvement candidate, no row yet.
47. Consider documenting the glm54-probe.sh pattern (script-internal keys, ai-meter path) in
    docs/services/ai-meter.md as the canonical live-model probe recipe.
48. gen-1028 carried the continuation session's rust-cache/hermes/direnv waves — their own reports
    own the post-deploy verification of those; reconcile with their self-review (`548b26f67`).
49. SystemNix origin/master is behind local master — fold the glm-5.4 wave + tonight's rows into
    the next owner push sweep (same as 6).
50. Close the now-obsolete UNANCHORED-repair row if it is still open — gen-1028's anchor leg
    repaired and verified the profile (`readlink == system-1028-link`).

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **The 20:44:18 cut**: did YOU hard-reset/reboot the box then (3 live crush sessions were
   running), or was it an unattended freeze+WDT cut? This decides whether the queued row becomes a
   freeze autopsy or a one-line close.
2. **glm-5.4 default?** Should glm-5.4 become the default LARGE model for any projects (per
   project `.crushrc` / picker store), or stay pick-only everywhere? (Host doctrine: large stays
   per-project — I need your per-project list if any.)
3. **Push posture for SystemNix master** (glm-5.4 wave + tonight's queue rows are local): push
   now, or batch with your next sweep like the overview/project-meta/go-error-family chains?

---
*Report: 2026-11-24 22:37 CET, session on crush v0.102.0 / zai glm-5.3-flash.*
