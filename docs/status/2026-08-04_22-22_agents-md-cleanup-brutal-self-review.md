# Status Report: AGENTS.md Cleanup — Brutal Self-Review

**Date:** 2026-08-04 22:22
**Session scope:** AGENTS.md bloat reduction — archive incident entries, compress gotcha table

---

## a) FULLY DONE

1. **Gotcha table extracted to archive** — `docs/gotchas-archive.md` (239 lines, 420 KB) preserves all 228 original table rows verbatim with full root-cause narratives, commit hashes, dates, and recovery procedures
2. **Gotcha table replaced with compressed categorized list** — 171 lines organized by domain (Nix, Systemd, Caddy, BTRFS, DNS, per-service, Desktop, Shell, Infrastructure)
3. **90% byte reduction** — 447 KB → 45 KB on the gotcha section
4. **`nix flake check --no-build` passes** — No evaluation breakage
5. **Archive header** explains what it is and cross-references back to AGENTS.md

---

## b) PARTIALLY DONE

1. **Key Procedures sections NOT cleaned** — The BTRFS section (lines 196-218), SearXNG procedure section (lines 155-165), Qmd section (lines 112-127), Quickshell section (lines 97-110) still contain dates, implementation minutiae, and some incident-level detail. These were untouched. The BTRFS section alone is 23 lines of dense implementation detail.
2. **Some compressed entries still leak dates** — Found 4 remaining date references in the compressed gotcha bullets:
   - Line 107: `Rofi migrated to DMS (2026-06-30)`
   - Line 202: `flagged since 2026-06-25`
   - Line 216: `prevents the 2026-06-26 metadata ENOSPC crash mode`
   - Line 244: `This caused the 2026-08-03 WDT crash`
3. **SearXNG gotchas duplicated** — There are SearXNG-specific gotchas in BOTH the "Key Procedures > SearXNG" section AND the "Non-Obvious Gotchas > SearXNG" subsection. Partial overlap, not fully de-duplicated.

---

## c) NOT STARTED

1. **~30-40 enduring lessons completely dropped** — Critical programming/SystemNix lessons that exist ONLY in the archive now, with zero representation in the compressed AGENTS.md. See section (e) for the full list.
2. **Archive file is a raw sed dump** — `docs/gotchas-archive.md` is lines 234-464 of the old AGENTS.md pasted under a header. No reformatting, no section breaks, no table-of-contents, no searchability improvements.
3. **Cross-reference links not added** — The compressed gotcha entries don't link to their full archive counterparts. An AI session reading "DuckDB WAL corruption self-heal" has no way to find the full recovery procedure without grep.
4. **No validation that knowledge is recoverable** — I ran `nix flake check --no-build` (which doesn't even touch AGENTS.md) but never verified that the compressed entries are actually sufficient for a fresh session to understand the rules.
5. **Other AGENTS.md sections not audited** — The "Architecture" section, "Platform Constraints" section, etc. were not reviewed for bloat.

---

## d) TOTALLY FUCKED UP

1. **Dropped ~30+ critical enduring lessons** — This is the biggest failure. The compression was too aggressive. These are NOT just "FIXED incident reports" — they contain transferable engineering lessons that a fresh AI session needs. Examples of knowledge now ONLY in the archive:

   | Dropped Lesson | Why It Matters |
   |---|---|
   | `go-git repo.Config()` only reads local scope | NEVER use go-git config reader for user identity — shell out to `git config` |
   | `errgroup.WithContext` cancels best-effort parallel work | Use plain `errgroup.Group` + error slice when partial results have value |
   | `time.Truncate(24h)` snaps to UTC midnight | Use `time.Date()` with local location for local-midnight truncation |
   | serde_json field ordering differs between struct and Value | Canonicalize before hashing — struct order ≠ BTreeMap alphabetical |
   | `ProtectHome = read-only` + binary defaults to `$HOME` | Redirect state via env vars into writable ReadWritePaths |
   | Two services sharing state = split-brain | Update ALL consumers when reconfiguring shared state paths |
   | `initServiceOrWarn` nil-swallow anti-pattern | Swallow + nil-safe callers is dangerous for required state |
   | OOM crash chain (user-1000.slice) | Per-service MemoryMax alone insufficient — user processes run outside it |
   | MGLRU `min_ttl_ms=1000` | Protects youngest page generation from eviction under pressure |
   | Strix Halo GPUActive = AI VRAM | NOT a leak — expected unified-memory behavior, 50+ GiB when AI running |
   | Network interface boot race | Dedicated `dnsblockd-attach-ip.service` needed, not `localCommands` |
   | Immich redis defaults to unix-socket-only (port 0) | Override `redis.port` + bind to `127.0.0.1` for monitoring |
   | Ollama `wantedBy = mkForce []` silent non-start | NEVER suppress nixpkgs default WantedBy without replacement |
   | Forgejo GitHub-sync token trap | NEVER put `FORGEJO_TOKEN` in sops template — stale placeholder |
   | SigNoz v0.127 v5 alerting API | Full v5 schema shape — legacy shape returns HTTP 400 |
   | `settings.signing` invalid + `gpg.ssh` dotted-key | Use nested form + HM structured `signing` submodule |
   | `post-deploy-check SIGPIPE false-FAIL` | `echo | grep -q` under pipefail fails on large bodies — grep from file |
   | `monitor365 circuit breaker` is in-memory | Only process restart clears it — degraded-but-alive needs health watchdog |
   | `monitor365 COALESCE` non-nullable lesson | "Confirmed non-nullable" is never confirmed until every INSERT path audited |
   | `PMA DefaultChain() vs DefaultChainFromEnv()` | Two factory functions — verify which reads configuration |
   | `cqrs-lint samber-do-auditlog` version drift | `mkPreparedSource` flake input ALWAYS overrides go.mod version |
   | `mr-sync` outputs signature missing `...` | Pin to last working commit when upstream breaks |
   | `file-and-image-renamer` auth fallback | `ErrorTypeAuth` — non-retryable, triggers provider fallback |
   | Docker backup service ordering | `requires` without `after` doesn't guarantee ordering |
   | `btrbk-data` missing snapshot_dir | tmpfiles rule required before btrbk can create snapshots |
   | `btrfs-verify-snapshots` stat reads wrong timestamp | Parse snapshot NAME not stat mtime — inherited from source |
   | `monitor365 agent auth model` | LoadCredential + figment env override — no secrets in Nix store |
   | `monitor365 runtimeDeps PATH` | Graphical collectors need `input`/`video` groups + `ProtectProc=default` |
   | `dnsblockd OOM` memory leak | GOMEMLIMIT forces GC below MemoryMax; high-cardinality labels are root cause |
   | `DiscordSync chattr ExecStartPre` | ExecStartPre is NOT shell — `2>/dev/null` passed as literal arg |
   | `DiscordSync Turso quota` | Degrades to local SQLite on quota exhaustion |
   | `Pocket ID francis crash-loop` | v2.12.0 fixes it; WAL-clearing ExecStartPre kept as defense |
   | `display-watchdog` false-positive at login screen | Login-screen guard checks for user Wayland/x11 session |
   | `monitor365 DuckDB pool deadlock` | `Restart=always` only covers EXIT — degraded states need active probes |

2. **No quality gate on the compression** — I never went back and asked "does a fresh AI session have enough context from the compressed version alone?" I should have diffed every archive entry against the compressed version and verified each enduring lesson survived.

---

## e) WHAT WE SHOULD IMPROVE

1. **Add back the ~30+ dropped enduring lessons** as terse 1-2 line bullets — strip dates/hashes/narratives but keep the lesson. The archive has the detail; AGENTS.md needs the rule.
2. **Strip remaining 4 date references** from compressed bullets — replace with the enduring rule only.
3. **Clean Key Procedures sections** — BTRFS (23 lines), SearXNG (10 lines), Qmd (16 lines) sections still have implementation-level detail that could be compressed.
4. **De-duplicate SearXNG** — Procedure section + Gotcha section overlap significantly. Merge into one location.
5. **Add cross-reference links** — Compressed entries should link to `docs/gotchas-archive.md` anchors for full detail.
6. **Reformat the archive** — Add section headers, table-of-contents, and anchor IDs so entries are findable.
7. **Review Architecture + Platform Constraints sections** — May also have bloat from accumulated edits.
8. **Establish a SIZE BUDGET** — Set a target (e.g. 300 lines) and enforce it. The current 421 lines is still large for "concise, enduring context."
9. **Add a CONTRIBUTING note** — "When adding a gotcha, write the ENDURING RULE (2-3 lines). Put incident detail in `docs/status/`. If a date or commit hash appears in AGENTS.md, it belongs elsewhere."
10. **Consider a separate `docs/GOTCHAS.md`** — The gotcha list might deserve its own file rather than being 40% of AGENTS.md. AGENTS.md would then be: Architecture + Procedures + Critical Rules + pointer.

---

## f) Up to 50 Things to Get Done Next

### Critical (knowledge recovery)
1. Add back `go-git repo.Config()` lesson as terse bullet
2. Add back `errgroup.WithContext` vs plain `errgroup.Group` lesson
3. Add back `time.Truncate` UTC midnight timezone trap
4. Add back serde_json field ordering canonicalization lesson
5. Add back `ProtectHome = read-only` + binary `$HOME` state override pattern
6. Add back two-services-sharing-state split-brain lesson
7. Add back `initServiceOrWarn` nil-swallow anti-pattern
8. Add back OOM crash chain / user-1000.slice MemoryHigh/MemoryMax
9. Add back MGLRU `min_ttl_ms=1000` thrashing prevention
10. Add back Strix Halo GPUActive = AI VRAM (not a leak)
11. Add back Immich redis unix-socket-only port 0 override
12. Add back Ollama `wantedBy = mkForce []` silent non-start
13. Add back Forgejo GitHub-sync token trap (never in sops template)
14. Add back SigNoz v5 alerting API schema shape
15. Add back `settings.signing` + `gpg.ssh` dotted-key fix
16. Add back post-deploy-check SIGPIPE false-FAIL (grep from file)
17. Add back monitor365 circuit breaker in-memory lesson
18. Add back monitor365 COALESCE non-nullable lesson
19. Add back PMA DefaultChain vs DefaultChainFromEnv
20. Add back cqrs-lint samber-do-auditlog mkPreparedSource override
21. Add back mr-sync outputs signature missing `...`
22. Add back file-and-image-renamer ErrorTypeAuth fallback
23. Add back Docker backup service ordering (requires without after)
24. Add back btrbk-data missing snapshot_dir
25. Add back btrfs-verify-snapshots stat vs name
26. Add back monitor365 agent auth model (LoadCredential + figment)
27. Add back monitor365 runtimeDeps PATH + graphical groups
28. Add back dnsblockd OOM GOMEMLIMIT fix
29. Add back DiscordSync chattr ExecStartPre shell-syntax
30. Add back DiscordSync Turso quota degradation
31. Add back display-watchdog login-screen false-positive
32. Add back monitor365 DuckDB pool deadlock watchdog pattern
33. Add back Network interface boot race (dedicated attach-ip service)
34. Add back Pocket ID francis crash-loop (v2.12.0)

### Cleanup (polish)
35. Strip 4 remaining date references from compressed bullets
36. Clean BTRFS Key Procedures section (compress 23 lines)
37. De-duplicate SearXNG between Procedures and Gotchas sections
38. Clean Qmd Key Procedures section
39. Add cross-reference links from compressed entries to archive anchors
39. Reformat `docs/gotchas-archive.md` with section headers + TOC
40. Review Architecture section for bloat
41. Review Platform Constraints for bloat
42. Set size budget target and measure against it

### Process (prevent recurrence)
43. Add CONTRIBUTING note about gotcha entry format (enduring rule, not incident)
44. Add pre-commit check: warn if AGENTS.md exceeds size budget
45. Add pre-commit check: warn if AGENTS.md contains commit hashes (7+ hex chars)
46. Consider splitting gotchas into `docs/GOTCHAS.md`
47. Document the "incident → enduring rule" extraction process
48. Add a "stale entry review" process — entries older than 90 days with no recurrence get archived
49. Add template for new gotcha entries: `| Rule | Enduring lesson (why) |`
50. Review whether `docs/status/` reports should auto-expire or be archived more aggressively (200+ files)

---

## g) Questions I Cannot Answer Myself

1. **Should the gotcha list live in AGENTS.md or a separate `docs/GOTCHAS.md`?** The global AGENTS.md rule says "concise, enduring context" — at 171 lines the gotcha list is still ~40% of the file. But moving it out means it's not auto-loaded by Crush. You decide the tradeoff.

2. **Should I re-add ALL ~30 dropped lessons, or curate which ones are truly "enduring" vs "one-time fix that won't recur"?** Some (like the `time.Truncate` timezone trap) are universal Go lessons. Others (like "Pocket ID 2.10.0 francis crash") are version-specific and may never recur. Where's the line?

3. **The Key Procedures sections (BTRFS, SearXNG, Qmd, Quickshell) are detailed reference material, not "gotchas" — but they're also bloated. Should I compress those too, or are they the right level of detail for procedural reference?** They're arguably the most useful part of AGENTS.md for a fresh session doing real work.

---

## Session Metrics

| Metric | Value |
|--------|-------|
| AGENTS.md before | 484 lines, 447 KB |
| AGENTS.md after | 421 lines, 45 KB |
| Archive created | `docs/gotchas-archive.md` — 239 lines, 420 KB |
| Gotcha entries compressed | 228 table rows → 171-line categorized list |
| Enduring lessons dropped | ~30-40 (critical failure) |
| Date references remaining | 4 (cleanup needed) |
| Sections NOT cleaned | Key Procedures (BTRFS, SearXNG, Qmd, Quickshell) |
| Validation | `nix flake check --no-build` passes (but doesn't validate AGENTS.md content) |
