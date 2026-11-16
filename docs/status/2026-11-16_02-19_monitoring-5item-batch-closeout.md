# Close-out — monitoring 5-item batch (task 000001a1e168d11a30350d0d74b800000000)

**2026-11-16 02:19 CET · one session, five monitoring-batch items, each footer-committed.**

## Items

1. **Boot-metrics livelock re-dispatch** — `6e547f83d` (evidence report `docs/status/2026-11-16_01-41_boot-metrics-livelock-redispatch-verification.md`). Fix session landed it via daemon `75c295712`; this fire verified per protocol (module state, evo-x2 eval green, §f.18 all-time CH sweep: phases flowing since 2026-10-17 — not a phantom), landed the footer-bearing report. Deploy+boot-gated legs stay named on both surfaces.
2. **Prom tmp orphans: guard + fixture** — `078679a7c` (work rode daemon `6da614d46`/`ce065b0e0`, provenance in-body). The fix session's tmpfiles janitor rule (`R …/*.prom.* - - - 1d`, `_signoz-metrics.nix`) was comment-asserted only; pinned by `prom-tmp-janitor-selftest` (11 legs through the REAL systemd-tmpfiles `--root` fixtures: real-.prom glob immunity, clean-mode age gate 1d-vs-0, mutation leg). Live census: 73 orphans, 69 >1d. Purge = first post-deploy daily clean (root-owned files, agent sudo dead).
3. **GPU findings persisted** — `946c8f03f` (rode daemon `c6bd83710`, amended). New "GPU/APU telemetry (Strix Halo)" section in `docs/agents/monitoring.md`; fdinfo one-liner + hermes-invisibility caveat RE-VERIFIED LIVE at landing (niri 618300 KiB/fd ×4 fds = the double-count demonstrated; llama fdinfo DENIED unprivileged).
4. **Swap-exhaustion coverage audit** — `7190b35e2`. Verdict: thresholds were NOT absent (SigNoz swap-critical >80% pre-#38; Gatus ZRAM Fill ≥90% out-of-band since 2026-08-16; zram is the only swap — a SwapFree<5% rule duplicates both). Store evidence: swap ≥99% 03:05→death 03:32:02 with samples flowing to the death instant; delivery unverifiable (logs TTL'd, journal vacuumed, gatus.db root-only). Coverage map persisted to monitoring.md; two follow-ups minted.
5. **Freshness-composite fixtures** — `35cc96fff` (work rode daemons `17680e2d5`/`53cd5e0db`, provenance in-body). `system-health-freshness-selftest`: the REAL mtime-composite blocks (all FOUR composites — memory-guard, niri, thermal-guard, psi) extracted from the staged module, driven across 6 states each (fresh/300-inclusive/301/stale/missing/future-mtime) + wiring pins; 33 legs, mutation-verified (`-lt 300` regression fails exactly its leg).

## Queue hygiene

- Both surfaces ticked for every item (the freshness ask existed as TWO rows per surface — all four ticked together).
- Follow-ups minted (queue + library twins): SigNoz rule→Discord delivery E2E dry-fire; system_health.prom self-freshness gauge.
- Daemon races ×5 (hot daemon, commits every 1-3 min): every fragment carried only my files; repairs by amend-forward with in-body provenance; the two `cannot lock ref` refusals were git protecting sibling daemon commits (the 2026-11-15 trap, worked as designed). One pre-commit link-check rejection taught the minted-rows lesson: library files must not carry self-referential arrow links.

## Not mine / flagged

Mid-session foreign working-tree edits appeared: `modules/nixos/services/cv.nix` (+52) and `modules/nixos/services/gatus-config.nix` (+58), unstaged, uncommitted, not authored by this batch — flagged per the concurrent-sessions rule, not touched, not co-verified.

## Verify gates

Per-item: evo-x2 toplevel eval green (item 1); both new flake checks built green post-stage (`prom-tmp-janitor-selftest`, `system-health-freshness-selftest` — the tracked-files trap bit once on the latter and was fixed by staging); shellcheck clean on both new scripts; every commit rode the full pre-commit battery (gitleaks, link check, eval-relevant flake check). Live probes: CH samples/log queries, /proc/meminfo, mm_stat, gatus+journal retention checks, node_exporter textfile census — all read-only.
