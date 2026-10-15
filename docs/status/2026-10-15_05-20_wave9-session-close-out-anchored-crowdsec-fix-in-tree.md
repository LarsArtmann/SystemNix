# VendorHash Wave #9 — Session Close-Out: Fixed, Anchored, Crowdsec Fix Awaiting One Switch (2026-10-15 03:58–05:20)

**Session:** the third leg of wave #9 (resumed from the 03:05 diagnosis + 03:49 execution reports;
deep evidence for §1–§4 lives in `docs/status/2026-10-15_04-51_vendorhash-wave-fixed-live-unanchored.md`).
**End state:** all 23 FOD failures fixed; the owner's `nh os switch` activated the new fleet live;
the activation's exit-4 (crowdsec) was root-caused to an upstream systemd list-reset trap and fixed
in-tree (`crowdsec-prereq.service`); the unanchored-profile hazard was repaired by the owner's sudo
run (~05:10–05:20). **Remaining:** one convergence `nh os switch` to activate the crowdsec fix +
3 still-stale units, and the hung USB DAS.

---

## State at session end (live-verified 05:20)

| Surface | State |
| --- | --- |
| `/run/current-system` | `5a5hk7pgi…` NEW ✓ |
| `/nix/var/nix/profiles/system` | `5a5hk7pgi…` NEW ✓ (owner's anchor repair, ~05:10–05:20) — **reboot-safe** |
| Fleet runtime | NEW: papdashboard `5a6794db`, cv `aa637cb`, inboxclean `9d99e5d`, discordsync `9dfdc03`, fir `21a0ef5`, PMA `3149585c`, kith-crm `a0341a0`, signoz `375b3f8`, mr-sync, hermes, tq — STILL STALE: overview `b819e1a`, browser-history `8900354`, pdd `f2f1bac` (their restart jobs were canceled by the 04:46 abort) |
| crowdsec | Fix IN-TREE (`crowdsec-prereq.service`, commit `86f1b9c6`), NOT yet live (no activation since 04:46); service still failed from that abort |
| USB DAS (`/mnt/pool`) | STILL HUNG (`[usb-storage]` D-state ~93 min as of 04:48; silent disk, io PSI = D-state waiters, cpu PSI ≈ 0). Owner physical check pending |
| Tree | HEAD `780241d0`, clean; wave fix + crowdsec fix + all docs committed (daemon commits `acd30a5d`→`13e33a05`) |

> **[ANNOTATED 2026-10-15 (adoption-audit session):]** the Fleet-runtime row's "browser-history `8900354` STILL STALE" did not hold — the live unit file carries `browser-history-server-fff6034` (== lock, verified 2026-10-15 via `/etc/systemd/system/browser-history.service`): the convergence switch landed after this report. overview/pdd staleness NOT re-verified by that probe. Evidence: `docs/2026-10-15_browser-history-deep-dive.html` §Version currency.

---

## a) FULLY DONE

1. **Ground truth over churn tables** — jq'd the live lock: the 03:49 report's rev table was wrong
   for 8 tools (transcribed mid-churn; `root -> erraudit` resolves to node `erraudit_3` `bb57433`,
   etc.). Lesson recorded in go-ecosystem.md.
2. **Wave root-cause collapse 23 → 2** — one toplevel `--keep-going` enumeration:
   (a) buildflow's unshimmed **4th consumption surface** (`platforms/nixos/system/configuration.nix:321`
   systemPackages — the 03:49 sweep missed platform-level direct inputs), shimmed with
   `cCl3IWhu…` (double-verified: the failing FOD's got + the shimmed twin instance realized);
   (b) papdashboard's broken upstream source `c8d0cf92` (compile errors) — floated to `5a6794db`,
   existing shim value re-verified identical by probe (upstream declares `pg/a63hg`, real content
   `CzxGeRnc`).
3. **The "~12 stale shims" fear disproven** — vendorHash is dep-set-derived; overnight upstream
   commits were source-only, so all 02:46-measured values stayed valid. Zero value re-pins needed.
4. **Toplevel GREEN** — round 3: NIX_EXIT:0, 0 hash mismatches, `nix flake check --no-build` green.
5. **Deploy verification** — owner's switch: 2 s cached build, diff = exactly the intended fleet;
   live verification of ~12 units on new builds (incl. cv CRM-syncing, papdashboard ingest 200s).
6. **crowdsec root cause + fix** — upstream's `ExecStartPre` opens with the `" "` reset marker →
   `mkBefore` gate+repair entries silently discarded → repair never ran → orphan row survived →
   "user already exist" → exit 4. Fixed: `crowdsec-prereq.service` (oneshot, crowdsec user,
   requires+before crowdsec, gate stays fatal, re-runs per restart). Eval green; rendered units
   verified (`Requires=crowdsec-prereq.service` on crowdsec; prereq carries wait-dns + repair,
   4min timeout, crowdsec:crowdsec).
7. **Unanchored-profile hazard resolved** — diagnosed (profile = OLD gen while current-system = NEW),
   handed the owner the surgical repair ladder; owner executed it ~05:10–05:20. Reboot-safe now.
8. **Close-out docs** — 04:51 status report (184 lines), CHANGELOG row, crowdsec + phantom-metric
   queue rows (services.md/monitoring.md/TODO_LIST.md, `check-todo-system.sh` clean), go-ecosystem.md
   doctrine refinements (list-parens, stale-rev ≠ stale-value, live-lock jq, keep-going oracle).
9. **Pre-deploy failure identified** — the 1 fail = phantom metric `boot_phase_duration_seconds`
   (pre-existing, unrelated; queued to monitoring.md).

## b) PARTIALLY DONE

1. **Convergence switch** — the crowdsec fix + 3 stale units need ONE more `nh os switch`; fix is
   in-tree and verified at eval/render level but NOT live.
2. **CrowdSec stage-1 verification battery** — services.md [watch] row updated with the new
   post-switch checks (8082/6061 listening, both acquis parsing, gatus green, second-boot no-op);
   blocked on the switch.
3. **DAS recovery** — diagnosis complete (hung USB bridge, not throughput); recovery is physical +
   runbook, owner-gated. Zombie-mount semantics documented in storage.md if the enclosure was
   pulled.
4. **Upstream paste-back** — the final rev→hash table for the owner's per-repo convergence pass
   lives in the 04-51 report §4 (15 rows); upstream.md rows themselves not yet updated with final
   hashes.
5. **Evidence-log durability** — committed comments cite `/tmp/toplevel-20261015{b,d}.log`; the key
   evidence IS quoted in the 04-51 report, but the raw logs die on reboot.

## c) NOT STARTED (this session)

- Full `post-deploy-check.sh` run after the convergence switch (§17 memory sweep, §19 restic
  freshness, auth-gateway checks).
- Unit-by-unit health battery for the whole restarted fleet (only spot-checks done).
- tq-agent-pool's transient "Failed to start" at 04:46 — never autopsied (it was healthy by
  04:47:40; race with what?).
- §11 blindness fix / §11-after-lock tripwire / shim-citation selftest (pre-existing queue rows,
  not this wave's work).
- CI-restoration sweep (queued earlier; owner-push gated).
- Freeze/boot-context check: uptime showed the box booted ≈03:13–14 tonight with usb-storage stuck
  ≈5 min after boot — no stability row was opened for that boot.

## d) TOTALLY FUCKED UP (honest)

1. **Phantom-IO misread** — I reported "IO storm from unit restarts + my own pre-deploy run" at
   04:44. The repo had EXACTLY the right tool, `scripts/io-psi-crosscheck.sh` (built 2026-10-14 for
   the PSI-high-devices-idle signature per CHANGELOG), and I forgot it existed. Your "disk is
   silent?" pushback forced the D-state + per-cgroup analysis that found the hung DAS. A 5-minute
   diagnosis took ~25.
2. **Future-time journal queries** — `journalctl --since '06:20'` on a 04:4x-clock box returned
   empty, and I briefly concluded "journal visibility restricted". Wrong filter, wrong conclusion;
   caught at 04:49.
3. **Premature anchor alarm at 04:39** — declared "RED FLAG" while the activation was still in
   flight (nh updates the profile only at completion). The check was right, the timing was wrong.
4. **Blind pre-deploy tail** — tailed 25 lines, missed the failing check, grep'd a pattern that only
   matched the summary line, re-ran the whole 3-minute script to capture it. Should have teed to a
   file from the first run (the earlier `context canceled` run was also lost).
5. **Planned around an unverified premise** — the resume todo said "re-pin ~12 stale shims" (from
   the prior session's churn-state table); I executed the quiescence check first but only jq'd the
   real revs AFTER the first build. The lock check should have included the rev table immediately.
6. **Minor**: buildflow list-parens eval break (self-inflicted, one rebuild); first crowdsec store
   `cat` on a directory path; `rg 'machines add'` scoped to modules/platforms missed the
   upstream-store script and nearly read as "unit not in repo".

## e) WHAT WE SHOULD IMPROVE

1. **PSI-vs-silent-disk triage order**: `io-psi-crosscheck.sh` FIRST on any io-PSI signature, then
   D-state sweep, then per-cgroup pressure — record the order in stability.md's classification
   shortcuts (the tool exists; it must be reflexive).
2. **Deploy doctrine**: pre-deploy failures must be IDENTIFIED before a deploy decision, not after
   (the phantom metric rode into production unnoticed-by-choice).
3. **Anchor rule timing**: `readlink /run/current-system` != profile is EXPECTED mid-activation;
   the verification gate belongs after nh exits. Worth a line next to the anchor discipline.
4. **`--since` hygiene**: derive journal windows from `date` output, never hand-typed clock times.
5. **Evidence durability**: wave-fix commits should copy their enumeration logs into `docs/` (or
   quote the pairs fully in the report — done here) so citations survive reboots.
6. **Upstream ExecStartPre reset marker** is a RECURRING trap for any module that `mkBefore`s into
   an upstream service — worth a lint (eval-time audit scanning merged units for entries dropped
   after a `" "` reset element) or at minimum a go-ecosystem/stability doctrine row. Tonight's
   proof: the c41a21ad fix was correct in intent and DEAD in effect for 12 hours.
7. **Wave triage speed**: the 23→2 collapse took one command; future waves should go straight to
   the keep-going enumeration instead of per-surface analysis first (this session did, after
   inheriting a stale plan — formalize it).

## f) NEXT (prioritized, ≤50)

1. Convergence `nh os switch` (activates crowdsec fix + restarts overview/browser-history/pdd).
2. CrowdSec stage-1 battery post-switch (services.md [watch] row).
3. DAS physical check / enclosure reseat → `pool-recovery` + Gatus green confirm.
4. post-deploy-check.sh full run after 1.
5. Verify the 3 stale units land on new builds after 1.
6. Confirm `readlink /run/current-system` == profile after 1 (anchor discipline).
7. Provision or delete `boot_phase_duration_seconds` (monitoring row).
8. tq-agent-pool 04:46 transient-start autopsy (one journal query).
9. Preserve `/tmp/toplevel-20261015{b,d}.log` into docs/ or verify quotation sufficiency.
10. Boot ≈03:13 tonight: intentional or crash? If crash → stability row + boot-evidence per §15.
11. Upstream paste-back: 15 repos (table in 04-51 report §4) — owner pushes, then per-repo
    `flake lock --update-input` + shim drop.
12. Shim-drop tracker: each shim's drop condition (upstream declares the got-hash) — currently only
    in comments.
13. CI-restoration sweep (upstream.md; owner-push gated).
14. §11 blindness fix (pipeline.md:59 — 3 documented instances).
15. §11-after-lock-commit tripwire (pipeline.md:395).
16. Shim-citation selftest (pipeline.md:479).
17. Eval-time lint: upstream `" "` reset defeats mkBefore (doctrine §e6) — selftest candidate.
18. `overrideAttrs`-in-list parens lint or go-ecosystem doctrine already covers — verify.
19. go-taskqueue dirty repo (M go.mod/go.sum — tq preflight refusals all night).
20. CV dirty repo (large modified set — tq preflight refusals; whose work?).
21. /data/docker ~15.5G owner reclaim (services.md).
22. /data/ai/models/ollama ~15G residue reclaim.
23. bank-sync deliberate pin: un-follow decision post-ceiling (upstream.md).
24. overview→pdd un-follow decision (overview pins pdd via its own input — the two-node split seen
    in tonight's lock).
25. Verify hermes D-state window (04:44, 39 s on the dead pool) left no corrupt state.
26. crowdsec stage-2 bouncer key (owner-interactive, services.md).
27. hot-db bootstrap CAP_DAC_OVERRIDE deploy row (services.md — pre-existing).
28. inboxclean-paperless flake app + fixture test (services.md rows).
29. btrfs-gc-guard fixture selftest (stability.md).
30. deploy.sh entry-gate fixture tests (stability.md).
31. node-exporter journal-rate confirm-in-calm-window (monitoring.md).
32. census-ring post-deploy wiring (monitoring.md).
33. inboxclean-canary live verify post-deploy (monitoring.md, blocked:deploy).
34. SEV1 chronic-storm latch implementation (stability.md design queued).
35. Dispatch verify-gate unblock: hermes-agent re-pin or docs-safe `.tq-verify` scope (pipeline.md).
36. Verdict-durability rule for dispatch sessions (pipeline.md).
37. Budget carve-out decision for closeout dispatches (pipeline.md, decision).
38. Re-dispatch verification protocol compliance check on re-fired rows (CONTRIBUTING).
39. `nix run .#deploy` vs `nh os switch` doctrine: tonight the owner used raw nh — fine for humans,
    but the anchor rule + post-deploy checks only fire via deploy.sh; decide whether to add an
    nh-path anchor check (deploy-restart-audit class).
40. Consider a post-activation "stale units" detector (units whose running exe ≠ new store path) —
    tonight's mixed state was found by manual pgrep.
41. DAS: if the enclosure returns, verify by-label pool mount + Gatus checks green (storage.md).
42. If the enclosure stays out >24h: btrbk mount-gate hole check (storage.md outage semantics).
43. PapDashboard upstream: also paste `pg/a63hg → CzxGeRnc` (their declared hash is stale at HEAD).
44. Wave-doc cross-link: 03-05/03-49/04-51/this report — a single wave index line in gotchas-archive.
45. CHANGELOG: the 04:35 activation incident is covered; verify no double-count with tq's 05-14
    report (their session overlapped ours).
46. Erase the AAAA-sentinel drv residue (`ivicr4ii…`) — harmless; note for probe-hygiene doctrine.
47. `environment.systemPackages` shim parenthesization: sweep for other bare `overrideAttrs` in
    list context (only one site existed; a static grep could prove it).
48. jq-live-lock helper (`scripts/lock-revs.sh`?) — tonight's ad-hoc jq pipeline is worth a script.
49. Re-run `nix run .#pre-reboot-check` before the eventual reboot (boot-mirror + §10/§11 audits).
50. Decide the DAS question (§g1) — it gates 3, 25, 41, 42.

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **The USB DAS**: did you (or something) power it off / unplug it tonight, or did it die on its
   own after the ≈03:14 boot? This decides whether §f3/§41/§42 are recovery work or a no-op, and
   whether the pool outage needs an incident row.
2. **Was the ≈03:13–14 boot tonight intentional?** (uptime at 04:44 showed 1h30m; usb-storage stuck
   from ≈03:19.) If it was a freeze/crash, the §15 pre-vacuum evidence gate wants a committed boot
   evidence file for it — I noticed it only via uptime and did not investigate (out of scope).
3. **Deploy path policy**: tonight you deployed via raw `nh os switch`, which skips deploy.sh's
   anchor verification, post-deploy checks, and pre-deploy gates (one benign failure rode in).
   Should I add the anchor + stale-unit checks to the nh path (or a deploy.sh `--nh-compat` mode),
   or is raw nh reserved for your manual runs and the gate gap accepted?

*Awaiting instructions.*
