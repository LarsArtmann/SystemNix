# Pin-Lift Fleet Wave — 8 LarsArtmann inputs to tip (2026-11-11 01:0x–03:4x)

**Trigger:** owner directive ("all MY projects should be on latest ALWAYS; external lenient") after a deploy trace showed 12 deliberate input pins. The 2026-11-06 templ-0.3.1100 API-removal wave (deleted `templ.ResolveAttributeValue`/`templ.JoinURLErrs`) had left seven LarsArtmann repos with daemon dep-bumps that skipped `templ generate`, each pinned back in SystemNix with a LIFT condition.

## a. Result

| Input | Was | Now | Upstream fix |
|---|---|---|---|
| library-policy | pin 7fc0983 | **tip 088aaf2, floating** | regen landed upstream (probe green, no fix needed) |
| journal | pin 4a63e7f | **tip 0663476, floating** | regen landed upstream (probe green) |
| golangci-lint-auto-configure | pin 28340f6 | **tip 41e6ed1, floating** | regen landed upstream (probe green) |
| inboxclean | (floated) | tip e9d55c92 | lifted earlier today by the parallel session; tip re-probed green |
| crm | pin f32f4c0 | **pin rolled to f2d1726** (deliberate policy pin kept) | probe green at tip; live session active in checkout |
| overview | pin 67b2fac9 | **tip f90c9a73, floating** | dedup/v4 publicDeps wiring (635f832d) + templ-cli pin v0.3.1070→v0.3.1100 + stale app.css rebuilt + vendorHash paste |
| project-dependency-graph | pin 8335670e | **tip 05e5b1ae, floating** | cmdguard/v5 deps-map wiring + vendorHash paste (6b80811f) |
| discordsync | pin ea6c444c | **tip 79e622ab, floating** | the big one — see §b |
| file-and-image-renamer | pin 973dd383 | **pin STAYS** | tip 5a319ea6 still fails (committed vendor/ carries pre-regen templ-components); live session mid-migration in that checkout (cmdguard v4→v5) — vendor refresh not safe to land concurrently. Row + flake comment updated with corrected diagnosis |
| qmd | tag v2.8.3 | **unchanged** | already the latest upstream tag |
| paperless-gpt-src | tag v0.31.0 | **unchanged** | already the latest upstream tag |
| nixpkgs-llama-rag | rev 0968519 | **unchanged** | external; llama.cpp 0.4.x spin regression still open upstream |

## b. discordsync (the deep fix)

Tip 2f3b275 (go.mod bumped to templ 0.3.1100 + disgo v0.20 in one daemon commit) needed five things, all landed upstream and pushed (`ea6c444c → 79e622ab`):

1. **disgo v0.19→v0.20 migration**: guild events now carry `discord.CacheGuild` (payload lists moved into the client cache). `seedGuild` sources channels/roles/threads/members/voice-states from `client.Caches` (populated by the gateway handler BEFORE the event fires — parity verified against disgo's `gatewayHandlerGuildCreate`); `seedGuildData` keeps the pure core testable without a client (9 test call sites moved to a `guildSeedingFixture.seed()` helper). **disgo caches NOTHING by default** (`CacheFlags` zero value refuses every `Put`) — explicit `cache.WithCaches(FlagGuilds|Channels|Roles|Members|VoiceStates)` added in `bot.New` or seeding would silently produce empty data (the F4 class).
2. **catalog/v4 → v4.14.0** (regenerated docserver).
3. **templ-components deps-map rev → v1.27.0 tag commit** (was pinned at v1.24.0 pre-regen while go.mod said v1.27.0 — the two-graphs trap).
4. **templ-cli build generator pinned at go.mod's version** (overview's pattern): nixpkgs' stale `pkgs.templ` generated calls to the deleted APIs.
5. **go-cqrs-lite pin → master at a known rev (81aec5ac9)**: the daemon now cuts submodule tags off-line (id/v4.7.5 is NOT an ancestor of catalog/v4.14.0), killing the "newest tag commit covers all required submodules" doctrine; explicit subModules entries dropped — their /vN-stripped dirs no longer exist after upstream's dir restructure (auto-discovery derives real dirs). **Upstream helper fix queued** (docs/todo/upstream.md).
6. Docs count-claim guard caught the `+1` Bot method (ROADMAP 252→253); flake-pin drift guard caught TEN pins predating the dep-bump wave — all re-pinned to peeled tag commits.

Tests: full suite green (build, bot, web after golden refresh for templ-components v1.27.0 output, testutil after the count + pin-drift fixes). Remote probe green at 79e622ab.

## c. SystemNix side

- Six pins lifted (URLs → `?ref=refs/heads/master`), allowlist rows removed per the lift rule, crm row updated for the roll-forward; expected-locks regenerated from the post-float lock (101 rows).
- Eight inputs re-locked to tip (239+/174− lock diff). `nix run .#float-register`: **no drift, registry matches**.
- Eval probe green (pin-audit + all eval gates pass at the new lock).

## d. Gotchas hit (all pre-documented, all cost time anyway)

1. **jq file-arg trap, THIRD form — silent wrong data**: a file-arg `jq` call returned *plausible data from SystemNix's own flake.lock* instead of the targeted repo's, sending ~30 min of lock forensics down a phantom path. Only a grep cross-check exposed it. Datapoint added to the AGENTS.md jq bullet; lock forensics now via python3 json.
2. **Dirty-tree vendorHash measurement**: the discordsync hash measured on the dirty tree failed at the pushed rev (`KPrm4O9w…` vs `g1lj5XRU…`). Remote-at-pushed-rev is the only trustworthy measurement context.
3. **`go test -update ./pkg`**: the flag must come AFTER the package list; before it, Go parses `-update` as a package pattern ("no Go files in .").
4. **attic outage** (`cache.home.lan` unresolvable most of the session): probes/blocks need `--option substituters https://cache.nixos.org`; overview's css-drift gate needed the same pin added upstream to not read a LAN-cache outage as a gate failure.
5. **Daemon + gate interleaving on shared checkouts**: the css-drift tamper test restored a stale app.css AFTER `build-css` wrote the fresh one, and the daemon committed the stale version mid-race — rebuild-then-commit-immediately is the only safe order.

## e. Verification status

- Every lifted input: lock-free `builtins.getFlake` package probe green at the EXACT locked rev (remote fetch, not local tree).
- discordsync/overview/pdg: full local test suites green + remote probes green at pushed revs.
- `nix run .#float-register`: no drift (registry == lock). Eval probe of evo-x2 toplevel: green.
- Toplevel keep-going build: see §f (verdict appended below when the run completes).

## f. Follow-ups (harvested)

- go-nix-helpers mkPreparedSource explicit-subModules /v4-dir fix + consumer sweep (crm/pma/inboxclean) → docs/todo/upstream.md [ready].
- file-and-image-renamer vendor/ refresh (waits on the live cmdguard session) → docs/todo/upstream.md [watch].
- Deploy obligation: the new lock (8 inputs at tip) is proven by the toplevel build; the actual `nix run .#deploy` is the owner's call (another session deployed timesheets+invoices at ~01:30 — the 2026-11-10 bundle-2 wave).
