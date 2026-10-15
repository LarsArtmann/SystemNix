# VendorHash Fleet Wave — Fixed, Live, but UNANCHORED (2026-10-15 03:58–04:51)

**Session:** continuation of the 03:05 diagnosis + 03:49 execution reports (same wave).
**Verdict:** all 23 FOD failures fixed; toplevel GREEN; the owner's `nh os switch` activated the new
config LIVE — but the switch aborted at exit 4 (crowdsec, tq session's new unit) BEFORE updating the
system profile. `/run/current-system` = new toplevel, `/nix/var/nix/profiles/system` = OLD generation.
**A reboot right now reverts the fleet. Anchor repair is the #1 action and needs the owner's sudo.**

---

## 1. What this session did (03:58 → 04:51)

### 1.1 Lock quiescence + ground truth
- Content-pin at resume: HEAD `acd30a5d`, tree clean, lock mtime 03:39:13, last lock commit
  `2d2789ae` 03:40:46 — quiet 19 min, no lock-updater processes.
- **The 03:49 report's rev table was WRONG for 8 tools** (transcribed mid-churn). Live `jq` of the
  lock proved `root -> erraudit` resolves to node `erraudit_3` = `bb57433` (not `1e51205`); likewise
  go-auto-upgrade `93cb7cd4`, go-humanize-linter `d24bd274`, go-structure-linter `bfb7518a`,
  golangci-lint-auto-configure `104b54e6`, go-health-dashboard `93d13fd`, pdd `df32945`,
  project-meta `a00c6dae`, samber-linter `1ab1333`. Lesson: never trust a rev table captured during a
  churn wave — `jq` the live lock.

### 1.2 The enumeration oracle (round 1, `/tmp/toplevel-20261015b.log`)
`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` collapsed the
wave from 23 failures to **exactly 2 root causes**:

1. **buildflow-go-modules FOD mismatch** — but NOT the shimmed surface. Three drv instances exist;
   the mkLarsPackages twin (`sh3wb816…`, shim value `cCl3IWhu…`) **realized successfully** — proving
   the attrset `overrideAttrs` shim mechanism works — while a SECOND, UNSHIMMED surface failed with
   upstream's stale declaration: specified `LKFUuFhV…` (upstream `vendorHash.nix` at `d114f28`) vs
   got `cCl3IWhu…` (real content). The missed surface: `platforms/nixos/system/configuration.nix:321`
   — a bare `inputs.buildflow.packages.<system>.default` in `environment.systemPackages`. The
   03:49 consumer sweep covered modules/ + overlays but not the platform systemPackages list.
   Repo-wide re-sweep (`rg 'inputs\.[a-z-]+\.packages' platforms/ modules/ …`) found 6 more direct
   consumers (qmd, storage-collector, browser-history ×2, index, bank-sync, nsfw-classifier) — only
   buildflow's upstream hash was actually stale.

2. **papdashboard `c8d0cf92` failed to COMPILE** — upstream source bug, not a hash problem:
   `internal/mcpserver/server.go` syntax errors at 4 sites ("unexpected newline in argument list").
   Upstream master had already moved to `5a6794db`. Floated the single input:
   `nix flake lock --update-input papdashboard` (also converged papdashboard/go-cqrs-lite onto the
   root's `35ccad85` — beneficial). Probe at `5a6794db`: upstream STILL declares stale `pg/a63hg…`,
   real content = `CzxGeRnc…` — **identical to the existing shim value** (go dep set unchanged),
   so only the comment's rev annotation needed updating.

### 1.3 Why the "12 stale shims" fear was wrong (wave insight)
`vendorHash` hashes the downloaded go-module dependency set, not the source. The overnight upstream
commits moved source only — dep sets stable — so the 02:46-measured got-hash VALUES remained valid at
every moved rev. **A shim whose rev annotation went stale is not automatically a stale VALUE.**
Re-probe before rewriting. This killed the planned "re-pin ~12 shims" step: zero value changes were
needed; the real work was 1 missed surface + 1 broken upstream commit.

### 1.4 Round-2 detour: nix list-parse gotcha (self-inflicted, fixed in 3 min)
First shim edit placed `pkg.overrideAttrs { vendorHash = …; }` bare inside the `systemPackages`
**list** — nix parses that as TWO elements: `pkg.overrideAttrs` (partial → `<function>`, which
fails `types.package`) + a stray attrset. Eval error:
`environment.systemPackages."[definition 17-entry 6]" is not of type 'package' … <function>`.
The 12 existing shim sites live in `let` bindings where the attrset IS the argument. Fix: wrap the
whole expression in parens. Recorded in `docs/agents/go-ecosystem.md`.

### 1.5 Round 3: GREEN (`/tmp/toplevel-20261015d.log`)
`nix flake check --no-build` green (darwin warning documented-expected) → full toplevel build:
**NIX_EXIT:0**, 0 hash mismatches, papdashboard `5a6794db` compiled and realized.

### 1.6 Pre-deploy check
97 passed / 10 warnings / **1 failed** (`/tmp/predeploy-20261015-full.log`): the §-phantom-metric
check — `boot_phase_duration_seconds` ABSENT (Gatus would sit red). Pre-existing, unrelated to the
wave (failing before any of my edits; surfaced because I re-ran the full script). Owner deployed
past it.

### 1.7 Owner deploy + activation forensics (04:35 → 04:51)
Owner ran `nh os switch . -v --show-activation-logs --keep-going`: build 2 s (fully cached from
round 3), diff = exactly the intended fleet (papdashboard `381709f→5a6794db`, buildflow
`2db93be→d114f28`, cv `0ad2a6b→aa637cb`, erraudit `492c233→bb57433`, …, + tq session's crowdsec
units ADDED). Then `switch-to-configuration test` ran ~12 min (see §2 DAS) and exited **4**:
- `crowdsec.service` failed — `cscli machines add: unable to create machine: user 'evo-x2': user
  already exist` (the tq session's brand-new crowdsec-setup ExecStartPre is not idempotent).
- `tq-agent-pool.service` "failed to start" was TRANSIENT — journal shows it running and harvesting
  normally from 04:47:40 (papdashboard ingest returning 200).

**Resulting state (the 2026-10-14 unanchored class, exit-4 flavor):**
| Surface | State |
| --- | --- |
| `/run/current-system` | `5a5hk7pgi…` NEW ✓ (running config is the new one) |
| `/nix/var/nix/profiles/system` | `system-891-link` → `6hd6lr16…` OLD ✗ (no boot entry) |
| Fleet runtime | NEW: papdashboard `5a6794db`, mr-sync `f1a13263`, inboxclean `9d99e5d`, discordsync `9dfdc03`, fir `21a0ef5`, PMA `3149585c`, cv `aa637cb` (CRM-syncing live), kith-crm `a0341a0`, signoz `375b3f8`, hermes, tq — STALE (restart jobs canceled by the aborted transaction): overview `b819e1a`, browser-history `8900354`, pdd `f2f1bac` |

The aborted transaction is also why the stale units exist: systemd cancels queued jobs once the
activation barrier fails, so late units never got their stop+start.

---

## 2. The "silent disk" mystery — USB DAS hung (UNRESOLVED, owner action)

Owner observed the disk was SILENT while I reported io PSI ~60%. Both were right: PSI was
**D-state waiters**, not throughput. Evidence (04:44–04:50):
- `[usb-storage]` kernel thread (PID 731) in D-state with **etimes ≈ 93 min** — stuck essentially
  since the 03:1x boot; the USB DAS link (`/dev/sda` → `/mnt/pool`, JMS567 bridge `152d:0567`,
  shared `8-1` link) is HUNG, not busy.
- cpu PSI ≈ 0 the whole time; io some avg10 48–63% sustained with no device work visible.
- `hermes gateway run` caught a 39 s D-state window touching the pool, then recovered to S-state.
- The stall explains the activation's 12-minute crawl through the stop/start list.

Owner should physically check the DAS enclosure (power/reseat — the 2026-08-31 9-day-outage
runbook applies: NO manual re-seeding needed, btrbk resumes incrementally; `Gatus` "Pool Mounted /
DAS-link" checks own the alerting). If the enclosure was deliberately powered off, this whole
section is a known-state no-op; the zombie mount semantics are documented
(`docs/agents/storage.md` § USB hotplug self-healing).

---

## 3. Required next actions (ordered)

1. **OWNER (sudo, now):** anchor repair per AGENTS.md deploy-anchor discipline —
   ```bash
   sudo nix build --no-link --profile /nix/var/nix/profiles/system \
     /nix/store/5a5hk7pgi1jr3gnncskbmvvgshi5y05l-nixos-system-evo-x2-26.11.20261011.7fd4004
   sudo /nix/store/5a5hk7pgi1jr3gnncskbmvvgshi5y05l-nixos-system-evo-x2-26.11.20261011.7fd4004/bin/switch-to-configuration boot
   nix run .#pre-reboot-check   # before ANY reboot
   ```
   `boot` mode only writes profile+bootloader (no unit activation), so the crowdsec failure cannot
   abort it.
2. **Convergence re-switch** (after 1, and after 3): re-run `nh os switch` — cached build, it will
   restart the 3 stale units (overview, browser-history, pdd) to their new builds. It will abort on
   crowdsec again until 3 lands; the anchor from step 1 survives that.
3. **crowdsec-setup idempotency** (tq session's units — flagged, NOT silently patched here):
   `cscli machines add` must tolerate an existing machine (`cscli machines validate` /
   check-then-add / `--force`). Queued in `docs/todo/services.md`.
4. **DAS**: physical check per §2.
5. **Phantom metric** `boot_phase_duration_seconds` — queued (monitoring), pre-existing.

## 4. Upstream paste-back table (owner's per-repo convergence pass)

Current locked rev → correct vendorHash (the value each upstream `vendorHash.nix` should declare).
All verified this session via the round-3 green build or first-hand probes; values live in the
shim comments (`lib/lars-packages.nix`, service modules, `overlays/linux.nix`,
`platforms/nixos/system/configuration.nix`).

| input | locked rev | correct vendorHash |
| --- | --- | --- |
| buildflow | `d114f28` | `cCl3IWhu…` |
| papdashboard | `5a6794db` (floated past broken `c8d0cf92`) | `CzxGeRnc…` (upstream declares `pg/a63hg`) |
| erraudit | `bb57433` | `sKya91ES…` |
| go-auto-upgrade | `93cb7cd4` | `D5DnebMF…` |
| go-humanize-linter | `d24bd274` | `ZenhGNkk…` |
| go-structure-linter | `bfb7518a` | `O2hpYHSc…` |
| golangci-lint-auto-configure | `104b54e6` | `YmWGO9br…` |
| go-health-dashboard | `93d13fd` | `IRv9RBXa…` |
| project-discovery-daemon | `df32945` | `nNKXDH5N…` |
| project-meta | `a00c6dae` | `RxJS6cpJ…` |
| samber-linter | `1ab1333` | `79YZ0u7C…` |
| crush-daily | `16edaae` | `AAXq+KGA…` |
| discordsync | `9dfdc036` | `UnFb4VRS…` |
| inboxclean | `9d99e5da` | `xekigUvj…` |
| cv | `aa637cbf` | `p7sOpco6…` |

Unchanged-rev tools (library-policy `e8e3667a`, crm `a0341a0`, mr-sync `f1a13263`, overview
`4b48040`, pdg `5315ae0`, PMA `3149585c`, papdashboard pre-float `c8d0cf92` — superseded, fir
`21a0ef5`, branching-flow `aa1611d8`) keep their existing rows. After each upstream push:
`nix flake lock --update-input <tool>` + drop that shim (wave 3–8 protocol).

## 5. Lessons recorded (also in docs/agents/go-ecosystem.md)

1. **Three+ consumer surfaces, not two**: flakePkg shims + service-module direct inputs + overlay
   `mkPackageOption` AND platform-level `systemPackages` direct consumption. Sweep
   `rg 'inputs\.[a-z-]+\.packages'` over `platforms/` too.
2. **overrideAttrs attrset form needs parens inside nix lists** (parses as two elements otherwise).
3. **vendorHash is source-independent**: stale rev annotation ≠ stale value; probe, don't assume.
4. **The keep-going toplevel build remains the only oracle** — §11 was bypassed entirely this time.
5. **exit-4 aborts leave mixed runtime state** (canceled jobs) — anchor repair must precede any
   convergence re-switch, and the anchor check must compare BOTH `/run/current-system` AND the
   system profile link.
6. **Don't trust rev tables captured during lock churn** — `jq` the live lock.

## 6. Evidence files
- `/tmp/toplevel-20261015b.log` — round 1 enumeration (2 root causes)
- `/tmp/toplevel-20261015d.log` — round 3 GREEN (NIX_EXIT:0)
- `/tmp/predeploy-20261015-full.log` — pre-deploy 97/10/1 (phantom metric)
- Commit sweep: shims landed via daemon commits `acd30a5d`, `91036c6d`, `b95acb36`, `191dd21f`
  (final HEAD at authoring); `flake.lock` papdashboard float mtime 04:10:10.

*(§f follow-ups: anchor repair = owner step 1 above (deliberately not queued as agent work — needs
sudo); crowdsec idempotency → `docs/todo/services.md`; phantom metric → `docs/todo/monitoring.md`;
DAS → owner physical check, storage runbook owns recovery.)*
