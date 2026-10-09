# NetBird phase-2 first deploy crashed on a string ManagementUrl fragment — root-caused, fixed, eval-verified; DEPLOY BLOCKED by the IO storm

**Date:** 2026-10-06 19:30 CEST · **Session:** netbird-evox2 deploy-failure response (the 18:36 deploy train abort)

## Verdict

The 18:36 deploy (`nix flake update browser-history bank-sync && nh os switch …`) built green but
activation failed with exit 4 on ONE new unit: `netbird-evox2.service` crash-looped to
start-limit-hit. Root cause found in netbird v0.80.0 source, fixed in SystemNix
(`modules/nixos/services/netbird.nix`), pinned by `checks.cloud-domain`, documented on all
surfaces — **but the fix is NOT LIVE**: two `nix run .#deploy` attempts aborted at the memory/IO
pressure gate (99% IO PSI, disk busy 100%+ — the parallel session's monitor365 build compiling
libduckdb-sys). `DEPLOY_FORCE_PRESSURE` was deliberately NOT used (freeze #18 happened the same
day). The live system is otherwise healthy; the failed unit is inert (new service, no dependents).

## a) Incident

- 18:36 deploy train: browser-history 68d0b6d→f091af3 (built + restarted fine) + FIRST activation
  of the netbird client (phase-2 flip: `services.netbird-client.enable = true`, sops
  `netbird_setup_key` present, netbird units + port 51820/udp added).
- `netbird-evox2.service` ExecStartPre (nixpkgs preStart fragment merge) OK, ExecStart died 10× in
  ~1 s each → start-limit-hit → nh exit 4:
  `json: cannot unmarshal string into Go struct field Config.ManagementURL of type url.URL`
- On-disk state: `/etc/netbird-evox2/config.d/50-nixos.json` =
  `{"DisableAutoConnect":false,"ManagementUrl":"https://netbird.larsartmann.cloud","WgIface":"nb-evox2","WgPort":51820}`
  — the string was OUR module's `config.ManagementUrl` override; the daemon reads the jq-merged
  copy at `/var/lib/netbird-evox2/config.json`.

## b) Root cause (source-verified, not guessed)

- netbird v0.80.0 `client/internal/profilemanager/config.go`: `Config.ManagementURL *url.URL`,
  read via plain `json.Unmarshal` (no custom marshaler anywhere in the repo — verified against
  v0.6.0/v0.27.0/main history: the field was ALWAYS url.URL; a string NEVER parsed). Netbird's own
  writer serializes it as a nested OBJECT (`{"Scheme":"https","Host":"…:443",…}`).
- The nixpkgs module (pinned rev + **master, checked 2026-10-06 — identical**) merges the
  `services.netbird.clients.<name>.config` fragment verbatim into the state config.json at every
  preStart. Its option docs still reference the 2024 netbird schema (commit 88747e3e) and warn
  the override "could break in the future" — netbird ≥0.80 (multi-profile rewrite) is where it
  broke. Affects every self-hosted nixpkgs netbird user who puts a management URL in the fragment.
- Sanctioned path found in source: root.go `SetFlagsFromEnvVars` maps `NB_*` env onto root CLI
  flags (`NB_MANAGEMENT_URL` → `--management-url`); `up` sends it in the LoginRequest
  (up.go:724) and the DAEMON persists the correctly-shaped object itself.

## c) Fix (all committed; daemon commit `e9a2028f` + docs sweeps)

`modules/nixos/services/netbird.nix`:

1. Fragment no longer carries the URL: `config.ManagementUrl` → `environment.NB_MANAGEMENT_URL`
   (wrapper bakes the env into daemon AND login unit invocations).
2. preStart purge (`lib.mkAfter` the nixpkgs merge — that script exports `$NB_CONFIG` + jq PATH):
   deletes string-typed `ManagementUrl`/`ManagementURL` keys only (object-typed values are
   netbird-written and must survive). Needed because the jq fragment merge never REMOVES keys and
   the state file is root-owned (no manual remediation possible from this session).
3. `tests/test-cloud-domain.nix`: probe now also asserts
   `environment ? NB_MANAGEMENT_URL` AND `!(config ? ManagementUrl)`.

Docs: `docs/services/net-vpn.md` (client bullet + step-5 annotation + both facts sections),
`FEATURES.md` netbird row, `CHANGELOG.md` Fixed entry, `docs/todo/upstream.md` nixpkgs issue row
([blocked:user]), `docs/todo/services.md` [blocked:deploy] resume row.

## d) Verification state

- Eval-verified: evo-x2 toplevel evals green; rendered fragment =
  `{"DisableAutoConnect":false,"WgIface":"nb-evox2","WgPort":51820}` (no URL); preStart renders
  purge AFTER the nixpkgs merge with `NB_MANAGEMENT_URL` exported; `checks.cloud-domain` green
  (runCommand, built clean).
- NOT verified live: deploy aborted twice at the pressure gate (19:01 attempt: PSI 20.66 mem /
  99 IO; 19:17 attempt entered on a drain sample, but the ~10-min check battery straddled the gap
  — monitor365's libduckdb-sys build resumed — and the gate re-sampled 99% IO / 105% disk busy
  and aborted). Each aborted attempt contributes ~10 min of eval IO to the storm.
- Live system now: `netbird-evox2.service` failed/inert since 18:36 (no dependents); everything
  else from the 18:36 train is live and healthy.
- `nix flake check --no-build` NOT run post-edit (storm discipline — avoid extra eval IO; changed
  surfaces covered by toplevel eval + the check that guards them). Gap acknowledged.

## e) Self-criticism / what I'd do better

1. **Deploy retry keyed on a ONE-SAMPLE drain window.** The watcher fired on a single sub-15%
   reading (avg10); the storm's avg60/avg300 never dropped. Should require ~3 consecutive calm
   samples OR avg10+avg60 both low. Cost: a 10-minute check battery under a live storm.
2. **Didn't check whether `service run` itself consumes NB_MANAGEMENT_URL** (runCmd not read).
   Immaterial to correctness (the login path guarantees the URL lands and is persisted), but the
   daemon's first-boot in-memory URL defaults to api.netbird.io until `up` completes — a few
   seconds of pointless cloud-URL state; would be nice to know/eliminate.
3. `nix fmt` over the shared tree reformatted `browser-history.nix` (formatting-only — the file
   turned out to have NO parallel content edits; risk was real though: fmt rides whatever a
   sibling session staged mid-flight).

## f) Follow-ups (self-harvested at authoring time)

- → `docs/todo/services.md` netbird subsection: **[blocked:deploy]** resume-the-deploy row with
  the sustained-drain heuristic + journal verification steps. (NOT queued to TODO_LIST — blocked
  work is deliberately not harvested into the dispatch queue.)
- → `docs/todo/upstream.md`: **[blocked:user]** nixpkgs issue row (string ManagementUrl breaks
  netbird ≥0.80; suggested module fix: dedicated option plumbed as NB_MANAGEMENT_URL; verified
  nixpkgs master identical; gate through verify-before-filing + github-voice).
- Pre-existing rows untouched: services.md 185 ([blocked:deploy] post-flip provisioner/peers
  verify — the client half of it completes when this deploy lands), 174 (phase-2 flip ceremony —
  executed by owner today).
- NOT harvested (owner decisions, not agent work): dashboard routing-peer assignment for
  `lan-subnet` once evo-x2 connects; whether to file the nixpkgs issue now or later.

## g) Questions for the owner

1. **Deploy override policy for THIS fix**: wait for real quiescence (monitor365/libduckdb build
   can run 30-60+ min), or do you want `DEPLOY_FORCE_PRESSURE=1` now given the fix build itself is
   tiny (no Go/FOD builds — unit-file derivations only)? Freeze #18 was today; I default to
   waiting.
2. **netbird-ui on the desktop**: `services.netbird.ui.enable` defaults ON (graphical sessions
   present) — a `netbird-ui` desktop wrapper landed (+30 MiB). Intended for evo-x2's hybrid
   desktop/server role, or set it false?
3. **Routing-peer step**: after evo-x2 enrolls, `lan-subnet` (192.168.1.0/24) needs evo-x2
   assigned as routing peer — dashboard by hand (runbook's current story), or extend the pbx
   `netbird-provision` reconciler to do it API-side once the peer ID exists?
