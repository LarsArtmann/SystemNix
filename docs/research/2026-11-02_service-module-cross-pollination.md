# Cross-pollination review: crush-daily and browser-history as SystemNix services

**Date:** 2026-11-02
**Scope:** `SystemNix/modules/nixos/services/crush-daily.nix` (143 lines),
`SystemNix/modules/nixos/services/browser-history.nix` (918 lines),
`SystemNix/platforms/nixos/system/configuration.nix`, `overlays/linux.nix`,
`flake/expected-locks.nix`, `tests/`, `lib/`, `docs/services/*`.
**Method:** every claim below was verified against the two modules, the host config, or live
production state (`journalctl -u crush-daily`, file metadata, a read-only copy of the production
database). Inferences are labelled.

Companion documents (per-project, source-level findings):

- `~/projects/crush-daily/docs/research/2026-11-02_browser-history-cross-pollination.md`
- `~/projects/browser-history/docs/research/2026-11-02_crush-daily-cross-pollination.md`

---

## 1. Verdict

The two services use the **same SystemNix contract** — upstream flake module owns options, defaults
and assertions; the SystemNix module layers host concerns; both register with `services.integration`
for vhost/Gatus/Homepage; both take `ports` from `lib/ports.nix` and `onFailure` from `lib/default.nix`.

What differs is **which host concerns have been solved**, and the gap is almost entirely on the
crush-daily side. browser-history's module is 6× larger because it carries four operational
capabilities crush-daily has none of:

| Capability                               | browser-history                                                       | crush-daily                                                                      |
| ---------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| Nightly, WAL-safe, off-volume DB backup  | `browser-history.nix:728-793` + pool leaf + restic + coordination row | **absent** (and the upstream implementation was WAL-unsafe — see §2)             |
| "Data is flowing" alert                  | textfile collector + Gatus, fail-closed (`:610-680`)                  | **absent** — only `[STATUS] == 200` on `/api/health` (`crush-daily.nix:112-127`) |
| NixOS VM test of the module              | `tests/test-browser-history.nix` + upstream `checks.*-vm`             | **absent** (`scripts/check-nixos-module.sh` covers eval + statix only)           |
| vendorHash stability against lock floats | shims dropped 2026-10-07; upstream re-bakes                           | **four re-stale shim waves** (`overlays/linux.nix:259,279`)                      |

The reverse direction is much smaller, and it is about **contract quality**, not coverage: crash-daily's
health endpoint returns per-check attribution, its Gatus alert text names the failing dependency, and
it asserts `runAsUser` existence at eval time.

---

## 2. Backup: none, and the one that exists was unsafe

### Today

`configuration.nix:1526-1534` enables crush-daily with only `enable`, `environmentFile` and
`runAsUser`. **`services.crush-daily.backup.enable` is never set**, so no timer exists, and
`/mnt/pool/backups/crush-daily` is not in `restic-app-dumps.nix`'s `paths` default list (which does
include `/mnt/pool/backups/browser-history`, `…/cv`, `…/paperless`, …), nor in the fleet
`backup-coordination` rows. The 38 MB event store is the service's **only durable state**: it holds
every generated report plus the LLM insight text, and a re-run cannot reproduce it byte-for-byte (every
report carries a `Generated <TIMESTAMP>` line, and the insight text is model output). Whether that makes it strictly irreplaceable depends on how much of the reporting
you would accept regenerating — that is the owner's call (open question 1 in
`crush-daily/docs/status/2026-11-02_01-56_cross-pollination-review.md`), but either way it has **no
backup leg at all** right now. Older `.backup_*` files in `/var/lib/crush-daily/` (Jul 28, Sep 12,
Oct 15) are ad-hoc, not scheduled.

### The implementation was also wrong (fixed upstream today)

Upstream's backup script copied the main database file:

```nix
cp "${cfg.dataDir}/crush-daily.db" "$backupDir/crush-daily-$timestamp.db"
```

The store runs in WAL mode (`internal/infrastructure/setup.go:500`). Measured on a read-only copy of
production at 2026-11-02:

| Artifact                    | events | newest event     |
| --------------------------- | ------ | ---------------- |
| source incl. `-wal`         | 4687   | 2026-11-01 23:31 |
| `sqlite3 -readonly .backup` | 4687   | 2026-11-01 23:31 |
| plain `cp` of the main file | 4666   | 2026-10-29 02:30 |

Three days and 21 events would have been lost, in a file that looks like a valid database. The
upstream module now uses `.backup` into a temp path, a `PRAGMA quick_check` gate and an atomic
rename, and the `nixos-module-eval` flake check asserts that shape
(`crush-daily/flake.nix`, `checks.x86_64-linux.nixos-module-eval`; verified green).

### What browser-history does that is worth adopting verbatim

`browser-history.nix:728-793` is the reference implementation of the _whole_ leg:

1. **online `.backup`**, never a file copy — consistent against the live writer;
2. destination leaf created by `mkPoolDirUnit` (mount-gated) so a missing `/mnt/pool` cannot silently
   turn a pool backup into a root-filesystem backup;
3. **torn-artifact healing**: a `-journal` sibling marks the backup untrustworthy and both files are
   deleted loudly;
4. 14-day retention, `CAP_DAC_READ_SEARCH`, `ioTier.background`;
5. a `backup-coordination` row, so a stale dump shows up in an audit rather than in an outage;
6. a `restic-app-dumps` entry, so the pool copy is dedup-mirrored.

**Actions, in order:**

1. (done, **uncommitted**) upstream: WAL-safe backup + a check that pins it — commit and push it
   before the `crush-daily` input rev moves, or the sandbox keeps building the old `cp`-based module;
2. host: `services.crush-daily.backup.enable = true` on evo-x2;
3. systemnix: add `/mnt/pool/backups/crush-daily` to `restic-app-dumps.paths` (or `extraPaths`), with
   the same mount-gated leaf + coordination row pattern;
4. **extract the pattern** rather than copy it a third time — see §6.

---

## 3. "Process up" vs "data flowing"

crush-daily's only registered check is:

```nix
url = "http://localhost:${toString cfg.port}/api/health";
conditions = [ "[STATUS] == 200" "[RESPONSE_TIME] < 1000" ];
```

Live evidence that this is insufficient: on 2026-11-02 01:07 `/api/health` answered **200** while the
night's collect had (a) skipped 13 of the project databases and (b) left the newest committed state
in the WAL. Health probes dependencies (`event_store → container.Ping`,
`cmd/crush-daily/main.go:762,989`); it does not know whether a report was produced.

browser-history addressed exactly this and its module header states the principle: _"Server up is NOT
data flowing: a dead agent timer alerts nowhere today."_ Its collector
(`browser-history.nix:610-680`) is worth copying for three properties:

- **restart-proof** — reads state from disk, not from an in-process counter;
- **process-independent** — node_exporter scrapes the textfile, so a hung or crashed service cannot
  phantom-green;
- **fail-closed** — on a scrape error the "active" metric is _omitted_, so a frozen textfile can
  never read as healthy.

**Action:** a `crush-daily-metrics` oneshot (root, 5 min) writing
`crush_daily_last_collect_age_seconds`, `crush_daily_projects_last_collect`,
`crush_daily_projects_failed`, `crush_daily_scrape_errors`, plus a Gatus rule with a bounded age
budget (the doctor's existing 36h threshold is the right starting point). Alert text must name the
signal, not just "unhealthy".

---

## 4. The module tests are asymmetric

`scripts/check-nixos-module.sh` (crush-daily) evaluates the module, runs `statix` and
`nix flake check --no-build`, and explicitly notes that VM tests are "documented in the README for
manual verification". Nothing exercises the module's riskiest logic: a `+`-privileged `chown -R`
migration, tmpfiles traversal, `runAsUser` switching, timer rendering, the backup unit.

browser-history has both layers: upstream VM checks (`browser-history/flake.nix:123-127`) and a
SystemNix VM test (`tests/test-browser-history.nix`) that asserts sysusers, `DynamicUser` ownership,
agent-token provisioning, freshness metrics and failure paths — 11+ ordered steps, including
"provisioner fails loudly before a user exists, then converges".

**Action:** `tests/test-crush-daily.nix` with five assertions, all cheap:

1. the module evaluates and the rendered config file carries the expected cron times;
2. after boot, `cfg.dataDir` is owned by the `runAsUser` target (the `ExecStartPre` migration);
3. `/api/health` answers 200;
4. `systemctl start crush-daily-backup` writes a file that passes `PRAGMA quick_check`;
5. (once §3 lands) the textfile collector emits `crush_daily_last_collect_age_seconds`.

Assertion 4 is the one that would have caught §2 before it shipped.

---

## 5. vendorHash shim churn — the asymmetry has a cause

`overlays/linux.nix` carries a `crush-daily` `overrideAttrs` vendorHash shim that has been re-pinned
at least four times (2026-10-15, 10-19, 10-26, 10-29 — see the comment block at `:272-285`), while
browser-history's shims were **dropped on 2026-10-07** (drop record in
`browser-history.nix:40-48`) because upstream re-bakes its hashes.

The cause is documented on both sides and they compose:

- crush-daily's flake input floats `go-cqrs-lite` master (`AGENTS.md` gotcha 109: the rev pin was
  lifted once the toolchain caught up), so **any** `nix flake lock` on SystemNix can move the
  go-modules FOD hash;
- crush-daily already has the right guard — `checks.x86_64-linux.vendor-hash` forces the FOD — but
  the hash still has to be re-baked _in the same commit_ as the dependency change, and a heuristic
  auto-commit daemon is active in this repo (`AGENTS.md` gotcha 123);
- browser-history pins exact input revs (`flake.nix:18-68`, no `?ref=master`) and documents a
  deliberate rev-sweep procedure, so its hashes only move when a human moves them.

**Actions:**

1. crush-daily: make `vendorHash.nix` re-baking part of the release ritual and assert it as
   `nix build .#checks.x86_64-linux.vendor-hash` before any lock move; consider re-pinning the
   go-cqrs-lite input to the same tag `go.mod` records (the repo already has the documented
   re-pin escape hatch).
2. SystemNix: when the shim is bit-neutral (current tree's `vendorHash.nix` equals the shim value),
   drop it and record why — the file-and-image-renamer entry at `:290-295` (dropped 2026-11-02) is
   the template.

Verified today: browser-history's `HEAD` **is** the locked rev (`f9c8916b`, clean tree), whereas at
crush-daily's locked rev (`83c4d8a3`) `vendorHash.nix` holds `sha256-TTFOwkoq…` while the overlay
shim holds `sha256-iPis8A3A…` — i.e. the shim is compensating for a hash that was re-baked _after_
the locked commit. That is precisely the churn the ritual is meant to prevent.

---

## 6. What both should build together: `lib/` helpers

Both modules now contain (or will contain) the same two multi-paragraph shell scripts: a SQLite
backup leg and a fail-closed textfile collector. browser-history's versions are battle-tested
(mount-gating, torn-journal healing, `CAP_DAC_READ_SEARCH`, `CAP_FOWNER` for the sticky textfile
directory); crush-daily needs both.

Copy-paste would create a third and fourth divergence in a fleet that already treats `lib/` as the
place for exactly this (`harden`, `mkStateDir`, `mkOidcGate`, `mkPoolDirUnit`, `onFailure`,
`serviceOneshotDefaults`, `ports`, `ioTier`).

**Proposal:** two helpers in `lib/`:

- `mkSqliteBackupUnit { name, db, destination, retentionDays, serviceUser, caps }` — online
  `.backup`, temp-file + quick_check + rename, mount-gated leaf, torn-journal healing, retention,
  `ioTier.background`, `onFailure`;
- `mkMetricTextfileCollector { name, script, interval, textfileDir, caps }` — oneshot shape,
  atomic rename into the sticky textfile dir, `serviceOneshotDefaults`, fail-closed contract
  documented in the helper's option docs.

Then browser-history's backup + agent-metrics units and crush-daily's backup + collect-freshness
units become ~15 lines each. Both modules shrink; the hardening that took three incidents to get
right lives in exactly one place.

---

## 7. Where crush-daily's module is the better teacher

1. **Per-check health attribution.** `crush-daily.nix:124` carries an alert string that explains
   _what a 503 means_ ("a 503 names the failing check … check the body's `checks[]` for
   attribution"). browser-history's Gatus checks describe symptoms but the endpoint's body is a flat
   struct; adding a `checks[]` array lets its alert strings name the dependency too.
2. **Eval-time assertions for `runAsUser`.** The upstream crush-daily module asserts the user exists
   (`builtins.hasAttr cfg.runAsUser config.users.users`) with an explicit message. Cheap, and it
   fails at build time instead of at 00:30.
3. **Explicit resource shape.** `MemoryMax = "1G"` + `GOMEMLIMIT=768MiB` +
   `TimeoutStartSec = "3min"` + `startLimitBurst = 3/60s` + journald caps
   (`journalMaxRetention`, `SystemMaxUse = 500M`) are all in the module rather than left to defaults.
   browser-history already sets `GOMEMLIMIT=384MiB` (`browser-history.nix:320`), `MemoryMax=512M`
   upstream, and per-unit `TimeoutStartSec` (`:349` server, `:576`, `:610`, `:646`) — the remaining
   piece is the **journald budget** (`journalMaxRetention` / `SystemMaxUse`), which its module does not
   set at all.
4. **Ownership migration with a documented privilege requirement.** crush-daily's `+`-prefixed
   `chown -R` ExecStartPre carries the incident history inline ("unprivileged it SIGSYS'd at every
   boot on `fchownat`, then EPERM'd even unfiltered"). browser-history learned the same class the hard
   way (`SQLITE_READONLY(8)` from DynamicUser uid drift) and now heals with `chown --reference` plus a
   journaled `ls -lan`. **Merge the two lessons in the helper:** operate on the real path (never
   through a symlink), `+`-prefix the unit, journal the evidence, and `chmod u+rwX`.
5. **Forward-auth doctrine.** crush-daily sits behind `vHost.layer = "protected"` (Caddy forward-auth)
   — correct, because its UI has no native auth. browser-history deliberately uses a plain
   `reverse_proxy` because forward-auth would intercept WebAuthn/OAuth2 calls and break login. Both
   are right; the rule should be written down once ("an app with native auth is never behind
   forward-auth; an app without it always is") instead of being re-derived per module.

---

## 8. The shared daemon bug, and the guard only one repo has

The heuristic auto-commit daemon has deleted `.buildflow.yml` in **both** repos: crush-daily
(`6b9be4b`, 2026-10-15 — `AGENTS.md` gotcha 123) and browser-history (`9fd3df7`, restored in
`f9c8916`, the current locked rev). Comments explaining why the file exists did not stop it.

crush-daily added a flake check (`checks.x86_64-linux.buildflow-config-exists`) that fails loudly when
the file is missing from the committed tree. browser-history has no equivalent (grep for
`buildflow-config` in its `flake.nix` returns nothing), so the same deletion would be noticed only
by a red treefmt check two weeks later.

**Actions:** port the check to browser-history; fix the daemon heuristic at the fleet level.

---

## 9. Prioritised action list

**P0 — data safety**

1. ~~Upstream: WAL-safe backup + pinned check~~ (done, verified green).
2. Enable `services.crush-daily.backup.enable` on evo-x2.
3. Add `/mnt/pool/backups/crush-daily` to `restic-app-dumps` (+ mount-gated leaf, + coordination row).

**P1 — signal**

4. `crush-daily-metrics` textfile collector + Gatus rule (collect age, projects collected/failed).
5. Add a `collect_freshness` probe to crush-daily's `EnableHealthCheck` registry so `/api/health`
   stops calling an idle service healthy.

**P2 — structure**

6. `tests/test-crush-daily.nix` (five assertions; backup integrity first).
7. `lib/mkSqliteBackupUnit` + `lib/mkMetricTextfileCollector`, then rewrite the three existing units
   on top of them.
8. vendorHash ritual: re-bake on every dependency move; drop bit-neutral shims.
9. Port the `.buildflow.yml` existence check to browser-history; then fix the daemon.
10. Write the forward-auth doctrine down once (in `lib/` docs), referencing both services.

---

## Appendix — reproduce

```sh
# Backup coverage: nothing enabled, nothing registered.
grep -n "crush-daily = {" -A 8 platforms/nixos/system/configuration.nix   # no backup.enable
grep -n "crush-daily" modules/nixos/services/restic-app-dumps.nix          # no hit
grep -rn "crush-daily" modules/nixos/services/backup-coordination.nix      # no hit

# The only health signal crush-daily registers.
grep -n "checks = \[" -A 12 modules/nixos/services/crush-daily.nix

# Shim churn vs the actually locked upstream rev.
grep -n "crush-daily" flake/expected-locks.nix
git -C ../crush-daily show 83c4d8a3:vendorHash.nix   # TTFOwkoq…
grep -n "crush-daily = prev.crush-daily" -A 2 overlays/linux.nix   # iPis8A3A… (post-lock re-bake)
```

_Verified against SystemNix at 2026-11-02; production claims come from `journalctl -u crush-daily`,
file metadata under `/var/lib/crush-daily`, and a read-only copy of the production database. No live
database was opened._
