# 2026-09-18 — signoz pair + nix-email master flip (probe → migration review → build green)

## Scope

Two flake-input updates requested by the user ("Time for an update!?" / "Why
not master!?"), executed as one wave:

1. **`signoz-src` + `signoz-collector-src`** — the standing TODO item 13
   (migration-review class) lifted from the pre-2026-09-13 INTERIM revs to
   upstream HEAD, branch-ref governed.
2. **`nix-email`** — tag pin `v0.2.0` → `?ref=master` per the 2026-09-16 pin
   policy.

## SigNoz bump

### Delta (verified via gh compare, not assumed)

| Input                  | From → To              | Ahead | Notable                                                                                                                            |
| ---------------------- | ---------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `signoz-src`           | `e0da06f7` → `67895d3` | +53   | `refactor(prometheus)!: remove the v1 provider` (internal), tokenizer default flips, quick-filter fields API, authz for dashboards |
| `signoz-collector-src` | `b514eb4a` → `a1d8ac3` | +8    | dep bumps (thrift/grpc/otel-trace), clickhouselogsexporter dual-body ingestion + shared `pkg/tagdedup`, gen-AI billing attributes  |

### Migration review (the reason this was gated)

- **Metadata DB (sqlite, runs at signoz start):** exactly ONE new
  `pkg/sqlmigration` file in the delta —
  `126_normalize_quick_filter_fields.go`. Transactional (`BeginTx`) renaming
  of stored quick-filter field names to the new fields API (snake_case +
  explicit field context/data type). Touches user UI state only. **LOW
  risk.** No files removed.
- **ClickHouse (collector's `signozschemamigrator`, runs pre-start):** ZERO
  changes to `cmd/signozschemamigrator` in the delta. The
  `schema-signoz.go` change is a JSON-serialization writer change (LLM
  pricing costs excluded from the billable attribute bag; the
  `attributes_number` key is preserved so billing size is unchanged for
  other spans) — **no schema change, no migrator run delta.**
- **Config surface:** rendered `signoz.yaml` (signoz.nix) sets neither the
  REMOVED `telemetrystore.clickhouse.secondary_indices_enable_bulk_filtering`
  key nor any `tokenizer` section → no rendered-config change needed. The
  tokenizer provider DEFAULT flips `jwt` → `opaque` (upstream
  `b02aae2`/`67895d3`): opaque = server-side session tokens; for the
  single-user impersonation deployment this is strictly simpler (no JWT
  secret requirement). New `apiserver` options are default-off.
- **Sonic / Go-1.26 patches:** upstream STILL pins `bytedance/sonic v1.14.1`
  (+ loader v0.3.0) in both repos at HEAD → the
  `patches/signoz-*-sonic-go126.patch` files STAY (drop condition unchanged:
  SigNoz bumps sonic ≥ 1.15). Patch apply-ability verified BEFORE building:
  `patch -p1 --dry-run` against HEAD's go.mod/go.sum — signoz applies with
  line offsets only; collector hunk-1 matches with fuzz 2 (the
  `apache/thrift v0.23.0` context line upstream bumped to v0.24.0 — fuzz 2
  is GNU patch's and applyPatches' default, and the fuzz-matched context
  line is not part of the hunk's edit).

### Build results (all green from the new locks)

Fake-hash harvest pass (`lib.fakeHash`, `--keep-going`) then real hashes
pasted into `_signoz-packages.nix`:

| Derivation                                         | New hash                                              |
| -------------------------------------------------- | ----------------------------------------------------- |
| signoz go-modules                                  | `sha256-p/XXGwnxOSHBmVT/zMy7GG5HsTDSPSBYGDbrfxi3FI8=` |
| collector go-modules (collector + schema-migrator) | `sha256-BYYyzlC8KGo4XqWp7K0xJt2hoPFYPLqHdDwzucIBcKo=` |
| frontend pnpmDeps                                  | `sha256-3IiQUkVBxP0B2y+XobvahVljysh4JXknHyDa4KPpSLw=` |

All four packages (`signoz`, `signoz-otel-collector`,
`signoz-schema-migrator`, `signoz-frontend`) build green at HEAD revs;
`signoz --help` and the collector binary execute.

### Branch-ref note

SigNoz's default branch is **`main`**, not `master` — `?ref=master` fails
`nix flake lock --update-input` with 422 `No commit found for SHA: master`.
Pins are `?ref=main` accordingly.

## nix-email flip

- `v0.2.0` was stale: upstream cut **v0.3.0 + v0.3.1** (2026-09-17) and
  master is 95 commits past v0.2.0, now carrying its own CI + a
  flake-parts migration + stalwart/relay/parsedmarc E2E suites.
- Flipped to `github:LarsArtmann/nix-email?ref=master`; lock → `b54f5c3`
  (2026-09-17). New upstream input `flake-parts` added by the lock (its
  `nixpkgs-lib` follows nix-email/nixpkgs → our nixpkgs).
- **Compat doctrine updated:** the old flake.nix comment claimed "both repos
  pin the SAME nixpkgs rev on purpose" — upstream master now pins
  `eaad089` (09-11) while SystemNix is at `b1b87598` (09-16). With
  `follows`, OUR pin always wins, so the shared-rev doctrine is dead by
  construction; `checks.nix-email-contract` (which imports the real pinned
  upstream input and verifies the option surface + sops/LoadCredential/
  registry wiring against OUR nixpkgs) IS the compat gate now. Ran green.
  flake.nix comment rewritten accordingly.

## Verification

- `nix build .#checks.x86_64-linux.nix-email-contract` → green (against the
  new master lock).
- All 4 signoz packages build green from the new locks.
- `nix flake check --no-build` → all checks passed.
- `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath`
  → green.
- Full evo-x2 toplevel build → green (see session close).

## Interlude: cv lock was already broken (not ours — fixed forward)

The first full toplevel build failed on the `cv` input — `cv-1002288-go-modules`:
"go mod tidy inside the vendor FOD changed committed go.sum" (go-codec
v0.2.0 → v0.3.0; the daemon dep-wave class — a transitive dep moved to
go-codec v0.3.0 while the pinned rev's committed go.mod/go.sum still said
v0.2.0). Provenance verified before touching anything: our uncommitted
`flake.lock` diff contains ZERO cv-node changes — `1002288` was re-locked by
an earlier (parallel-session/daemon) commit and was already broken.

Fix forward, following the documented CV protocol (CI is dead there, so no
upstream signal — probe first):

1. CV local HEAD `93cf5bc0f` ("restore Go 1.26.7 toolchain floor broken by
   buildflow repair sweep") carries the TIDIED go.mod+go.sum (both at
   go-codec v0.3.0) and is PUSHED (verified `gh api .../commits/93cf5bc0f`,
   2026-09-18T05:49Z).
2. Probe green: `nix build /home/lars/projects/CV#default.goModules` builds
   at that rev (prepared source + FOD).
3. `nix flake lock --update-input cv` → lock `1002288` → `93cf5bc`
   (upstream also added a `cv/art-dupl` input in that range — upstream's
   own pin, un-followed, fine).
4. Full toplevel rebuild → **green (RC=0)**; final `nix flake check
   --no-build` → all checks passed.

## Deploy notes

- `nix run .#deploy` builds + restarts the signoz units (restartTriggers on
  the rendered configs fire). The metadata migration 126 runs inside signoz
  start; the `DELETE FROM migration_lock` preStart hygiene is already in
  place (signoz.nix).
- Post-deploy: verify the SigNoz UI login (impersonation check in
  post-deploy-check covers the endpoint; the tokenizer default flip is the
  one behavioral change — if a stale browser session was JWT-based it
  simply re-authenticates).
- Watchdog: clickhouse/collector/signoz dashboards + the existing alert
  rules are rev-agnostic; no rule edits needed.

## Docs updated

- `flake.nix` — signoz pair + nix-email comments rewritten (INTERIM removed,
  migration-review obligation + sonic drop-condition recorded).
- `docs/INTERIM-INPUT-PINS.md` §B — marked RESOLVED (all rows flipped
  2026-09-16..09-18), signoz migration-review obligation recorded.
- `TODO_LIST.md` — stale-vendorHash refresh list marked resolved (signoz
  pair with review verdict).
- `AGENTS.md` — pin-policy bullet: signoz pair moved from "Pins KEPT" to the
  landed record; nix-email tag note replaced with the master flip + contract
  doctrine.
