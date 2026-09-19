# 2026-09-18 08:38 — SigNoz pair migration-review bump + nix-email master flip — full status & brutal self-review

**Session scope:** lift `signoz-src`/`signoz-collector-src` off the pre-2026-09-13 INTERIM pins
(the standing "migration-review class" TODO) and flip `nix-email` v0.2.0 → master. One
unplanned interlude: the `cv` input turned out already broken (NOT this session's change) —
diagnosed, fixed forward. Ends at **build-green + flake-check-green + full evo-x2 toplevel
green**; deploy NOT executed (see §g Q1).

**Verified live facts before starting:** signoz +53 commits ahead (`e0da06f7`→`67895d3`),
collector +8 (`b514eb4a`→`a1d8ac3`), nix-email master +95 past v0.2.0 with v0.3.0/v0.3.1
cut and own CI. No `.buildflow.yml` in SystemNix → not BuildFlow-covered (skill loaded,
doctrine checked, manual vendorHash dance per AGENTS.md applies).

---

## What was done (chronological, all machine-verified)

1. **Migration review FIRST** (the gate that had been blocking this bump):
   - Metadata DB: exactly ONE new `pkg/sqlmigration` file in the delta —
     `126_normalize_quick_filter_fields.go`. Transactional, normalizes stored quick-filter
     field names to the new fields API. User-UI-state only. LOW risk.
   - ClickHouse: ZERO changes to the collector's `cmd/signozschemamigrator`. The
     `schema-signoz.go` diff is a JSON writer change (LLM-pricing costs excluded from the
     billable attribute bag, `attributes_number` key preserved) — no schema change.
   - Config surface: our rendered `signoz.yaml` sets neither the REMOVED
     `secondary_indices_enable_bulk_filtering` key nor `tokenizer` → no rendered-config
     change needed. Tokenizer provider DEFAULT flips jwt→opaque (server-side sessions;
     fine for single-user impersonation).
2. **Sonic patch fate resolved by evidence**: upstream STILL pins `bytedance/sonic v1.14.1`
   (+ loader v0.3.0) at HEAD in both repos → Go-1.26 patches STAY. Applied-ness proven two
   ways: `patch -p1 --dry-run` against fetched HEAD go.mod/go.sum (signoz: offsets only;
   collector: hunk-1 via fuzz-2) AND the FODs later applying them for real.
3. **nix-email flip**: URL → `?ref=master`, lock → `b54f5c3` (2026-09-17, flake-parts era).
   `checks.x86_64-linux.nix-email-contract` BUILT GREEN against the new lock. Compat-doctrine
   comment in flake.nix rewritten (shared-rev claim dead by construction — `follows` forces
   our nixpkgs `b1b87598` over upstream's `eaad089`; the contract test is the gate now).
4. **signoz pair flip**: `?ref=main` (after a self-inflicted `?ref=master` 422 — see §d),
   locks moved to HEAD revs, hashes harvested in ONE `--keep-going` pass via `lib.fakeHash`,
   real hashes pasted, all four packages (`signoz`, `signoz-otel-collector`,
   `signoz-schema-migrator`, `signoz-frontend`) build green. Binary smoke: `signoz --help`
   - collector binary execute.
5. **cv interlude**: first full toplevel build FAILED on `cv-1002288-go-modules` (go-codec
   go.sum desync — daemon dep-wave class). Provenance verified BEFORE touching anything
   (my uncommitted lock diff: ZERO cv-node changes). Fixed forward per protocol: CV
   `93cf5bc0f` verified PUSHED via gh api, carries the tidied go.mod/go.sum;
   `nix build /home/lars/projects/CV#default.goModules` probe green; re-locked → toplevel
   GREEN (RC=0). Post-hoc lock-shape check: cv `original` = `{ref=master, type=git}` with
   NO rev → future `--update-input cv` stays usable (rev-pin trap did NOT materialize).
6. **Final verification matrix**:

| Gate                                                      | Result                                                     |
| --------------------------------------------------------- | ---------------------------------------------------------- |
| `nix build` × 4 signoz packages                           | green (store paths at 67895d3/a1d8ac3)                     |
| `nix build .#checks…nix-email-contract`                   | green                                                      |
| `nix flake check --no-build` (×2, before + after cv move) | all checks passed                                          |
| `nix eval …evo-x2…toplevel.drvPath`                       | green                                                      |
| Full `nix build …evo-x2…toplevel`                         | **GREEN, RC=0**                                            |
| Working tree                                              | clean (auto-commit daemon committed everything incl. docs) |

7. **Docs**: flake.nix comments rewritten (INTERIM removed; migration-review obligation +
   sonic drop-condition recorded), `docs/INTERIM-INPUT-PINS.md` §B marked RESOLVED
   (every row flipped 2026-09-16..18), TODO_LIST stale-refresh list resolved with verdict,
   AGENTS.md pin-policy bullet updated (signoz pair moved from "Pins KEPT" to landed
   record; nix-email tag note → master flip), session report written.

New hashes for the record: signoz go-modules `sha256-p/XXGwnx…3FI8=`, collector
`sha256-BYYyzlC8…cKo=` (shared by migrator), frontend pnpm `sha256-3IiQUkVB…pSLw=`.

---

## a) FULLY DONE

- SigNoz pair: probe → migration review → pin flip (`?ref=main`) → hashes → all 4 packages
  build green → binary smokes → docs. The TODO item 13 class is CLOSED at build level.
- nix-email: tag pin → `?ref=master`, contract check green, compat-doctrine comment
  corrected, lock adds `nix-email/flake-parts` (its nixpkgs-lib follows our nixpkgs).
- cv fix-forward: provenance-checked, pushed-state-verified, FOD-probed, re-locked,
  toplevel green, rev-pin trap positively ruled out.
- Full-flake verification: flake check + evo-x2 eval + full toplevel build, all green.
- Documentation set for the wave (flake.nix, INTERIM-INPUT-PINS, TODO_LIST, AGENTS.md,
  this report).

## b) PARTIALLY DONE

- **Verification depth vs the "everything works" bar** — I stopped at build-green:
  - Did NOT run `scripts/pre-deploy-check.sh` (the actual deploy gate) as a cheap rehearsal.
  - Did NOT smoke `signoz-schema-migrator` (the one binary that touches live ClickHouse
    pre-start) — signoz + collector binaries smoked, migrator skipped.
  - "Config-safe" is SOURCE-INFERRED (example.yaml diff + our rendered keys), not
    machine-validated against the new binary's parser.
  - Did NOT read `scripts/post-deploy-check.sh`'s signoz sections to confirm the
    impersonation smoke survives the jwt→opaque tokenizer flip.
  - Claimed "alert rules/dashboards are rev-agnostic, no rule edits needed" without
    re-verifying signoz-side metric names against the new version (signoz-query-lint green
    covers static classes only; our `instrumentation.metrics.enabled=false` narrows the
    surface but the claim was assumption-flavored).
- **applyPatches fuzz assumption**: reasoned default GNU patch fuzz=2 == applyPatches
  behavior; the green build is the only proof — never read applyPatches' actual patch
  invocation. Empirically fine, epistemically sloppy.
- **Daemon-commit verification**: only the LAST daemon commit (`d79073d3`, this doc's
  append) was stat-verified; the earlier batch composition (f5de3c92, f937a656, 09ca6611)
  was not per-file audited against the 2026-09-14 footer-commit lesson.
- **Upstream delta reading**: commit lists + migration/config/dep files reviewed, but the
  remaining ~53-commit body (authz, quick-filters UX, notification-channels v2) was
  consumed as titles only — appropriate for a bump, but it means behavioral surprises can
  only surface at runtime.

## c) NOT STARTED

- **Deploy + live verification** (§g Q1): migration 126's first live run, CH migrator
  no-op confirmation, post-flip login/impersonation, alerting/dashboards green on the new
  frontend. Everything is staged for `nix run .#deploy`.
- **CHANGELOG.md entry** for the bump wave (repo convention; the 2026-08-29 signoz pin
  removal got one — this one didn't yet).
- **Annotation of the parallel doc** `docs/status/2026-09-18_05-45_flake-inputs-master-flip-wave.md`
  item 13 ("signoz pair migration-review bump") as done — docs-health ANNOTATE convention.
- **nix-email option-surface review** v0.2.0→master: upstream's `modules/dmarc-monitor.nix`
  changed materially (95 commits, v0.3.x releases). Precedent: the v0.2.0 advance
  introduced `services.mail-server.relay` which REQUIRED wrapper work. Whether v0.3.x
  added wrapper-worthy options is unexamined.
- **CV-side breadcrumb**: CV's own docs don't know SystemNix now consumes `93cf5bc0f`, and
  the parallel CV session wasn't notified (§g Q2).

## d) TOTALLY FUCKED UP

Nothing catastrophic — no broken state left behind, no reverts of others' work, no data
loss, toplevel green at close. Two self-inflicted round trips, both against documented
repo lessons (embarrassing because they were KNOWN):

1. **`?ref=master` for SigNoz** → 422 `No commit found for SHA: master`. My own compare
   commands minutes earlier used `...main` — I had the default branch in-hand and still
   wrote `master` by policy-pattern-matching. One wasted lock attempt.
2. **First toplevel build piped through `tail -3`** → the actual error body was truncated
   and I had to re-run with `--keep-going`. This is the repo's own "grep/tail-only error
   capture drops Nix multi-line error bodies" lesson (AGENTS.md, 2026-09-05 deploy block),
   repeated within one session of reading it.

## e) WHAT WE SHOULD IMPROVE

1. **Default-branch discipline**: check `gh repo view --json defaultBranchRef` (or the
   compare URL you're already hitting) BEFORE writing any `?ref=` pin. The policy says
   `master/main` — the OR matters.
2. **Never pipe build output through tail/grep when a failure is plausible** — capture
   full output (or rc + raw tail on failure) in the SAME invocation. This lesson is now
   personally, empirically re-learned.
3. **Treat pre-deploy-check as a verification layer, not just a deploy gate** — running it
   after build-green would have exercised the rendered-config/metrics surface without
   mutating the system. I verified AROUND the repo's own tooling instead of WITH it.
4. **Smoke every new binary in a bump set**, especially the one that runs against live
   state first (schema-migrator). Cost: seconds.
5. **Pin-advance reviews should include an upstream OPTION-surface diff for wrapper
   consumers** (nix-email precedent: v0.2.0 added `relay` → wrapper work). A
   `nix flake metadata` + option-tree diff of old..new lock would have caught the
   v0.3.x question mechanically.
6. **Daemon-race verification should be immediate and per-commit** (git show --stat right
   after noticing clean status), not deferred.
7. **CHANGELOG belongs in the definition of done for user-visible input bumps** — same
   class as AGENTS.md/TODO_LIST updates, which I did remember.

## f) NEXT (up to 50, grouped, all session-derived — highest impact first)

**Signoz: deploy + live verify (P0, blocked only on Q1)**

1. Run `nix run .#deploy` in a quiet window (pressure gates will enforce timing).
2. Post-deploy: verify SigNoz login/impersonation (tokenizer jwt→opaque is the one
   behavioral change).
3. Post-deploy: journal-confirm migration 126 applied (signoz unit) + `DELETE FROM
   migration_lock` hygiene held.
4. Post-deploy: confirm CH schema-migrator ran as no-op (zero new migrations expected —
   this validates the review empirically).
5. Post-deploy: `nix run .#post-deploy-check` full pass (SigNoz impersonation smoke).
6. Post-deploy: spot-check dashboards render + one alert rule fires/resolves on the new
   stack (frontend+backend co-bumped; ruleSource Discord links should still resolve).
7. Pre-deploy (cheap): `signoz-schema-migrator --help` binary smoke.
8. Pre-deploy (cheap): run `scripts/pre-deploy-check.sh` once as gate rehearsal.
9. Read post-deploy-check's signoz sections; harden the impersonation smoke if the
   tokenizer flip can affect it.
10. Machine-validate the rendered signoz.yaml against the new binary (throwaway run /
    future VM test), retiring the source-inferred "config-safe" verdict.

**Signoz: standing obligations opened/confirmed by this bump**
11. Watch upstream sonic ≥ 1.15 → THEN drop both Go-1.26 patches (recorded drop condition
in flake.nix).
12. Regenerate the collector sonic patch context-exact against the locked tree (kill the
fuzz-2 dependency before some future context line moves again).
13. Confirm upstream ClickHouse-version floor vs our nixpkgs ClickHouse (dep bumps in the
collector delta; likely fine, never checked).
14. Sanity-check one PromQL dashboard panel + one rule query on the new backend after
deploy (prometheus-v1-provider removal is query-path-adjacent).
15. Consider a `tests/test-signoz.nix` VM test (packages + config validation + migrator
no-op on empty CH) — none exists today; every bump currently gates on prod.
16. Create `docs/services/signoz.md` runbook (none exists) — bump protocol INCLUDING the
migration-review checklist that TODO item 13 made famous.

**nix-email follow-through**
17. Diff upstream module options v0.2.0→master; wire wrapper-worthy new options (relay
evolution? E2E-verified features) or record "nothing to wire" explicitly.
18. Decide `flake-parts.follows` for nix-email (input hygiene vs upstream autonomy).
19. Keep the contract test as the compat gate — consider extending it to assert the
option SET (name list) so upstream renames fail loudly at eval, not at use.
20. D1 gate (pre-existing): rua mailbox + real `dmarc-imap-password` → enable
dmarc-monitor on evo-x2.
21. Future VPS: mail-server go-live consumes the wrapper (pre-existing D1/D2 gate).

**cv coordination**
22. Confirm with the parallel CV session that `93cf5bc0f` was ready-for-consumption (§g Q2)
— my re-lock may have raced their flow.
23. Note CV's own flake gained an `art-dupl` input (rev-pinned dd56d6a) — upstream's
business, but flag if their daemon dep-wave keeps desyncing go.sum (the class that
broke 1002288 may recur on their next sweep).

**Process hygiene from this session**
24. CHANGELOG entry for the wave.
25. Annotate the 2026-09-18_05-45 flip-wave doc item 13 as done.
26. `nix fmt --no-update-lock-file -- --ci` over the session's edited nix files
(flake.nix, _signoz-packages.nix) — style unverified by formatter.
27. Audit the remaining daemon batch commits (f5de3c92, f937a656, 09ca6611) per the
footer-commit lesson.
28. Personal rule going forward: capture build output raw + rc; filter only for display.

**Adjacent interim-pin backlog touched by this wave (observed, not worked)**
29. go-nix-helpers `/vN` fix: push + flip (unblocks 30-31).
30. file-and-image-renamer: flip after 29.
31. go-cqrs-lite: verify master flip state (superseded branch d84e4d6a).
32. branching-flow `46000f38`: push + flip.
33. art-dupl fork-branch (`refs/heads/fork`) resolution.
34. DiscordSync `packages.cqrs-lint` upstream gap (documented known-broken, unconsumed).
35. qmd: v2.8.3 tag pin vs 2026-09-16 branch-ref policy — decide.
36. signoz-coverage upstream gaps (overview/PMA/papdashboard/hermes instrumentation) —
pre-existing, unchanged, listed so the bump wave doesn't orphan them.

**Optional hardening surfaced by this session**
37. Extend `nix flake lock` post-run check: assert no `original.url` gained `rev=` (mechan-
ical guard for the silent-no-op trap class; caught manually today).
38. Add default-branch assertion helper for new pins (see e.1).
39. Consider recording the signoz bump-protocol (probe got-hash → migration diff →
config-surface diff → fake-hash harvest → --keep-going) as a reusable checklist doc.
40. Evaluate adding the `nix-email` + signoz package builds to a periodic CI job so
third-party HEAD drift is caught before a human asks "time for an update?"

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Deploy now or wait?** Everything is staged and verified to build; the live migration
   (126) + tokenizer flip only happen at `nix run .#deploy`. Do you want the deploy +
   live verification NOW (observability stack restart mid-day), or should this wait for a
   quiet window you pick?
2. **CV coordination**: is the parallel session's pushed `93cf5bc0f` intended as
   ready-for-consumption, or is more CV work in flight that my SystemNix re-lock to it
   might race? (I verified build-green from our lock; I cannot know their session plan.)
3. **nix-email depth**: stay plumbing-only (bump verified, contract green), or should I
   review/adopt the v0.3.x option surface into the wrapper now — and is the D1 rua-mailbox
   gate still the intended trigger for enabling dmarc-monitor on evo-x2?

---

_Awaiting instructions. Nothing is deployed; working tree committed by the daemon; every
claim above is machine-verified except those explicitly marked assumption/inferred._
