# Status: nix-email contract fix (Stalwart 0.16) + evo-x2 deploy build-blocker inventory

**When:** session work 2026-10-17 05:06-05:39 CEST; report finalized ~10:40 CEST (wall-clock gap: the dispatch arrived hours after the fix turn — filename keeps the 05-39 work-window stamp; harvest citations depend on it)
**Session scope:** one `fix!` dispatch (eval-surface repair) + this status turn. Written from THIS session's runs and observations only — no out-of-scope research, per dispatch instruction.
**Format note:** `.md` per the dispatch's explicit path demand (status-report skill is HTML-canonical; explicit user format wins — recorded, not propagated).

> **2026-10-17 ~10:45 ANNOTATION (post-dispatch verification, user-directed):** sections §b1/§d1/§d2/§f below were written from the 05:06 enumeration and are now PARTIALLY STALE — sibling sessions re-greened most of the wave between 06:30 and 08:38 (commits `04c90efa`, `a751dcd4`): 11/12 go-module got-hashes shimmed, the art-dupl break root-caused and shimmed (rename, not missing upstream code), signoz `pnpmDeps` hash updated. Remaining at annotation time: `overview` (unshimmed, got `+WMj7c5U…`), go-taskqueue triage, and the build-level proof. See §i for the live re-verification result.

---

## TL;DR

The `fix!` dispatch landed on a RED `nix flake check --no-build`: the `nix-email` eval-contract test asserted the Stalwart **0.15** `queue.route`/`queue.strategy.route` shape, but the blanket `nix flake update` had floated the `nix-email` input to `7fda2c03` (2026-10-16), where upstream migrated the relay wiring to the **0.16 plan-object shape** (`provision.objects.MtaRoute` + `provision.singletons.MtaOutboundStrategy`). Test updated, strengthened, all checks green. **This did NOT unblock the deploy**: the user's `nh os switch --keep-going` enumeration (already in-hand, per the --keep-going doctrine) shows the evo-x2 toplevel is build-RED with **15 failures** — 12 stale LarsArtmann go-modules vendorHashes, 1 signoz pnpmDeps hash, and 2 non-hash upstream breaks (art-dupl, go-taskqueue). Eval surface: FIXED. Build surface: OPEN — this is the 10th fleet-wide vendorHash wave since 2026-10-01 (CI-restoration row in upstream.md is the durable fix).

---

## §a FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **nix-email eval-contract test migrated to the Stalwart 0.16 shape** — relay assertions now read `provision.objects.MtaRoute.objects."smarthost"` (`address`, `authUsername`, plus the previously-unchecked `authSecret` File-credential contract pinning `/run/credentials/stalwart.service/mail-server-relay`) and `provision.singletons.MtaOutboundStrategy.route."else" == "'smarthost'"`. Stale "IfBlock strategy" comment replaced with the 0.16 migration note. | `tests/test-nix-email.nix:147-171`; check builds → `/nix/store/n27rw8wp36ba3clyd8vwfmdz48xv20w8-test-nix-email`; content committed by daemon `bbae6986` (alejandra reformat of my first pass is staged on top, awaiting the next daemon sweep) |
| a2 | **Full `nix flake check --no-build` green** — the original `attribute 'queue' missing` at `tests/test-nix-email.nix:157` is gone; run completed with "all checks passed!" (aarch64-darwin omission = documented expected warning). | This session, twice (pre- and post-format; identical store path) |
| a3 | **Formatter compliance** — scoped `nix fmt . tests/test-nix-email.nix` (the pinned treefmt arbiter), diff reviewed post-format (formatter re-nested my `let` into alejandra style — semantics-identical, re-verified by identical output path). | `git diff` reviewed; only `tests/test-nix-email.nix` modified vs HEAD |
| a4 | **Premise spot-verification of the harvest rows before queueing** (queue-author rule): confirmed `lib/lars-packages.nix:15-29` owns the `flakePkgShim` vendorHash pattern, `modules/nixos/services/crm.nix:85` still carries the stale `WOZ2Iwqw…` specified-hash for kith-crm, and `modules/nixos/services/_signoz-packages.nix:51` owns the signoz `pnpmDeps`. | Greps this session |

**Root cause (one paragraph, for the record):** the deploy-preceding `nix flake update` moved 4 inputs (`hermes-agent`, `homebrew-cask`, `nur`, `nix-email`). The `nix-email` advance carried upstream's Stalwart 0.16 migration: `services.stalwart.settings.queue.*` (0.15 TOML) → `services.stalwart.provision.{objects,singletons}` plan objects (`MtaRoute` Relay + `MtaOutboundStrategy` route expression), with SASL auth re-keyed `auth.username` → `authUsername` + `authSecret{@"@type"="File"}`. The SystemNix contract test pinned the old shape → first read of `settings.queue` threw `attribute 'queue' missing`. Fixed by re-pointing the assertions; test intent (relay address + SASL auth + else-branch routing to the relay id) preserved and extended.

---

## §b PARTIALLY DONE

| # | Item | Works now | Remains open | Blocker | Effort |
|---|------|-----------|--------------|---------|--------|
| b1 | **Unblock the evo-x2 deploy** | Eval layer green (a1/a2); the failure enumeration is complete (user's `--keep-going` run — the doctrine worked as designed) | All **15 build failures**: 12 stale go-modules vendorHashes (got-hashes transcribed in §d1), signoz-frontend `pnpmDeps.hash` (error message itself prescribes the `""` → build → paste loop), art-dupl + go-taskqueue (non-hash, §d2/§d3) | None for the mechanical shims; art-dupl needs an owner disposition call (§g1) | M (shims+signoz) + M (triage) |
| b2 | **hermes-agent input state** | The blanket update floated the held pin `e76fb95` → `bebe448a`; `nix flake check --no-build` is GREEN on the new rev (the 2026-10-14 check-surface break did NOT re-fire this time) | The watch row's forward-move gate was "a green **toplevel build**" — the move happened via blanket update BEFORE that condition; build-unverified while the toplevel is red anyway | Sequenced behind b1 | S |
| b3 | **This report's follow-up hygiene** | §f direct follow-ups self-harvested at authoring time into TODO_LIST.md + upstream.md (see §h) | The 30+ non-harvested §f items are recorded as deliberately-not-harvested (§h) — they are brainstorm/other-domain observations, several with unverified premises I was told not to research | None | done |

---

## §c NOT STARTED (in this session — planned or surfaced, zero code written)

- **The 15-failure unblock itself** (b1) — nothing touched: no hash pasted, no pnpmDeps bumped, no triage opened. Deliberate: dispatch said report-then-wait.
- **Post-fix deploy + verification chain** — `nix run .#deploy`, anchor check (`readlink /run/current-system` = latest `system-N-link`, the 2026-10-14 exit-14 class), `pre-reboot-check`, full `post-deploy-check.sh`.
- **Darwin-side sanity** after `hermes-agent`/`homebrew-cask`/`nur` moves — `nix flake check` skips `aarch64-darwin` by default; nothing verified there this session.
- **rpi3-dns build verification** — eval-covered by flake check, build-uncovered.
- **The formatter "2 changed" anomaly data-point** — observed again this session (see §e4) but not investigated (already an open pipeline row).

---

## §d TOTALLY FUCKED UP

**d1. evo-x2 toplevel is build-RED — 15 failures, deploy pipeline DOWN.** Severity: blocks every `nix run .#deploy` until fixed. Root cause: the blanket `nix flake update` moved master-tracking LarsArtmann inputs; consumer-side vendorHashes are stale (the known fleet-wave class — 10th wave since 2026-10-01; trigger per the 2026-10-15 diagnosis: ANY lock movement of a master-tracking input). Workaround: none — builds are required for switch. The complete got-hash enumeration (from the user's `--keep-going` run, ready for shim transcription):

| Package @ rev | specified (stale) | got (paste me) |
|---|---|---|
| projects-management-automation @ `849573de…` | `sha256-lPN1fqTDp3jxmThsmdXIlbFpiM10h6qK1ksUYE1HvY8=` | `sha256-5WOy3BHvtQzhN87X/lS82TA0RZHfIDyTHKbQqiTi5E=` |
| overview @ `966465e` | `sha256-NXdLbWt+UbnP2boe/1sE1LR1qIg/EMHXBtPFZgLAoJk=` | `sha256-+WMj7c5UHyQQNwrMLdB5AQ5ErWqlLocZT0WlWwoakzE=` |
| kith-crm @ `56bdd4c2…` (shim lives in `crm.nix:85`) | `sha256-WOZ2IwqwAaI+Y7EBZyWGRfMPZ13p8rGWaHrMTDOxcE0=` | `sha256-R9ui8Fb7LMg5THOullEsoBYrQa1zH3qrfwb3K5acuVE=` |
| library-policy @ `aab411b9…` | `sha256-LNKl6MJs31DOTzZ1ThMIfvJ3+XOgFlS2KhXWKL2ncMY=` | `sha256-SIbgnu0y+2GpqjugkXxin2nlal6jJqt5BoobywJStd4=` |
| mr-sync @ `71d6b0d4…` | `sha256-cFy4AGocSu4kSWQZSjkcmGA8ZpNbm+QamGaq8n5zyis=` | `sha256-KaDlWefEw3DZHR5SGGBHqaY+3tT7MoSeGKApRYxmBpg=` |
| meta @ `d905380c…` | `sha256-RxJS6cpJ3x9VTvcroUeA2gMRNdbcD8xuRTzNUDSGYd0=` | `sha256-paiQbA3xU6V1JEKsXj9W3ryE7SB57yJPODdtc+v3wxk=` |
| inboxclean @ `b601473` | `sha256-xekigUvjNAYMr/BdJSGcjzkkgP5CbtOaBzisW78+Zuc=` | `sha256-6lPAB08xgr+wXcZWLPaIq/A/E0c6elfFWetCuKAudWM=` |
| cv @ `be4aa55` | `sha256-p7sOpco67lp1UtbwD21q0HxVHrITLuwVzCxeDo1EzTM=` | `sha256-8OAMcaF1rGMknRq53We7TCbgmfiqKMZkKGd6LbyLWBI=` |
| buildflow @ `defa7c0` | `sha256-cCl3IWhufWYGlRncOOKKvUwaOBceF7aapUXCwoyk2lA=` | `sha256-5OQbyOHyoCMh1vNV1QRrRpP0G7wu1Wto+5WrpCZsVa4=` |
| golangci-lint-auto-configure @ `d4447de3…` | `sha256-YmWGO9br4TEiWZ22pCI6+hQBbjYHK2K9K53SuFTY2pw=` | `sha256-IGt6NehaKqho31wFnaWw2SvtUfvbWA6SdZ33udl8aeE=` |
| go-humanize-linter @ `f8845aeb…` | `sha256-ZenhGNkklhWD/Ej4WZhZwtD16suWdQ0c2n+Lmf2J4ME=` | `sha256-/2zA0kMSs11mumZc8S34My1gxGs4te/fQFhxJcoJqns=` |
| cqrs-lint @ `60f2be41…` | `sha256-Zfte0X5r+rfuzQUfIjfvGiWVhobPYvYNg4cCP0VAcQ=` | `sha256-J7gNXzrVQ4cPdAXBHTjwu7mvvHZskDsFYIURJuoBIEM=` |
| signoz-frontend @ `6c6632f` | `pnpmDeps.hash` stale — `ERR_PNPM_NO_OFFLINE_TARBALL` for `@signozhq/design-tokens-2.2.1.tgz` (pnpm 10.34.5) | re-derive: set hash `""` → build → paste got (the error text prescribes exactly this) |

**d2. art-dupl 0.9.0 does not COMPILE at its pinned rev** — `printer/actionability/actionability.go:47:3: undefined: isTemplChildrenIdiom`. Not a hash problem: the templ-generated identifier is missing from the upstream source (generation/commit defect upstream). Severity: blocks the toplevel while art-dupl is in the package set. Mitigation: pin back to the last-building rev, drop from the package set, or wait for upstream — owner call (§g1).

**d3. go-taskqueue 0.3.4 build breaks on a missing module in its own go-modules store** — `go-cqrs-lite/decider/v4@v4.8.0: reading file:///nix/store/…-go-modules/…/v4.8.0.mod: no such file or directory`. The fetched module store and the build's module graph disagree (submodule-inclusion class). Not hash-fixable by transcription; needs triage (local packaging fix vs upstream go.mod issue). Note: go-taskqueue is also a tq-pool repo — a broken build here has queue-side blast radius.

**Honesty note:** nothing in THIS session broke anything — all §d items pre-date my fix and were caused by the blanket input update; my fix repaired the only eval-surface casualty.

---

## §e WHAT WE SHOULD IMPROVE

**Direct answers to the three questions asked:**

**What did I forget?**
1. **The deploy context.** I anchored on the first failing check (`nix flake check`) instead of the user's actual goal (a green deploy). After the deploy-failure paste landed mid-session, I closed out on "flake check green" instead of proceeding into the 15-failure enumeration that was sitting in the same conversation. The `--keep-going` doctrine exists precisely so the enumeration happens ONCE and gets fixed in one pass — I consumed the enumeration and fixed 1 of 16 surfaces.
2. **pre-deploy-check §11** (`--section-11-only` FOD preview) — the repo has a purpose-built real-build preview for exactly this failure class; I never ran it.
3. **Darwin side** — three moved inputs (hermes-agent, homebrew-cask, nur) affect darwin; I verified nothing there.
4. **The formatter anomaly data-point** — I saw "formatted 12 files (2 changed)" against exactly 1 git-modified file and moved on without recording it (now recorded, §e4).

**What could I have done better?**
1. First move after "fix!" with a deploy in play: run the toplevel `--keep-going` enumeration myself, then fix eval + build surfaces in the same pass.
2. Read the failure MESSAGES before the source: the signoz error text contains its own fix recipe; the upstream migration was discoverable from the module comments (which explicitly document the 0.15→0.16 replacement) before any store dive.
3. The contract test could have failed with its INTENT message ("generated queue route missing or wrong") instead of a raw `attribute 'queue' missing` — wrap upstream-shape reads in guarded access so upstream migrations produce diagnosable failures (§f9).

**What could we still improve? (pattern-level)**
- e1. **Contract tests that mirror upstream-generated shapes drift on every upstream migration.** A cheap hardening: assert a "shape sentinel" first (e.g. `tryEval` the new paths, throw "upstream shape migrated — re-pin test expectations deliberately") so the test failure names the migration instead of leaking a raw attr error. Impact: saves the source dive on every future upstream restructure. Effort: S.
- e2. **The shim treadmill is permanent until the CI-restoration row lands** (upstream.md: real Nix-build CI per master-tracking repo). This session is the 10th wave; each wave costs an M-size session. The durable fix is already queued — it needs owner push capacity, not more shims.
- e3. **Blanket `nix flake update` keeps violating input-hold gates.** The hermes-agent watch row ("forward-move only after a green toplevel build; the blanket-update source must not race it") was raced by this very update. The flake-update-bot rollback-on-red idea (pipeline.md) is the systemic closure.
- e4. **`nix fmt . <path>` scoping is still unverified** — reproduced the anomaly (3202 files processed, "2 changed", only 1 git-modified). Existing pipeline row owns the ask; this session adds the second independent data-point.
- e5. **"fix!" dispatches deserve a scope preamble.** One line from the dispatch ("fix the flake check failure" vs "fix the deploy") would have prevented the eval-vs-build anchoring miss. (Process suggestion, owner's call.)

---

## §f TOP NEXT TASKS (ranked; the dispatch allowed up to 50 — 24 grounded items below; padding to 50 would be filler, and the quality guide routes vague fill to ROADMAP)

| # | Task | Impact | Effort | Category |
|---|------|--------|--------|----------|
| 1 | Transcribe the 12 got-hashes (§d1 table) into `lib/lars-packages.nix` shims + `crm.nix:85`; kith-crm's shim takes `R9ui8Fb7…` | Critical | M | Bug |
| 2 | signoz-frontend: re-derive `pnpmDeps.hash` (`""` → build → paste) in `_signoz-packages.nix:51` | Critical | S | Bug |
| 3 | Re-run `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` until zero failures | Critical | S | Bug |
| 4 | Triage go-taskqueue 0.3.4 missing `decider/v4@v4.8.0.mod` (packaging include vs upstream graph); fix if local | Critical | M | Bug |
| 5 | art-dupl 0.9.0: owner disposition (pin-back / drop / wait-upstream) per §g1, then execute | Critical | S | Decision |
| 6 | Deploy evo-x2; verify anchor (`readlink /run/current-system` = latest `system-N-link`) per 2026-10-14 discipline | Critical | S | Process |
| 7 | Run full `post-deploy-check.sh` after the switch (incl. §17 memory sweep, §19 storage-history) | High | S | Process |
| 8 | Verify the staged alejandra reformat of `tests/test-nix-email.nix` lands via daemon sweep (one `git status` check) | Low | S | Cleanup |
| 9 | Harden test-nix-email.nix shape reads: `tryEval`-guard upstream paths → migration-named throw (§e1) | Medium | S | Quality |
| 10 | Re-scope the hermes-agent watch row: the blanket update already moved the held pin to `bebe448a` (check-green) — after b1, verify toplevel-build green and tick or re-hold deliberately | Medium | S | Cleanup |
| 11 | Darwin sanity pass post-input-moves (`nix build .#darwinConfigurations…toplevel` or darwin-rebuild check) | Medium | M | Bug-risk |
| 12 | Dedupe this wave against the 2026-10-15 "11 pending got-hash pairs" list (golangci-lint-auto-configure appears in both) when dispatching #1 | Medium | S | Cleanup |
| 13 | Feed the second formatter data-point (3202 files / 2 changed / 1 git-modified) into the open `nix fmt` scoping row | Low | S | Quality |
| 14 | After deploy green: one full `nix flake check` WITH builds (checks are eval-only today) | High | L | Process |
| 15 | Make "toplevel --keep-going preview" the standing first move whenever ANY input moved (codify in nix-flakes.md or pre-deploy §11 usage note) | High | S | Process |
| 16 | Land the CI-restoration sweep (upstream.md durable row) — agent-side: audit which of the ~23 master-tracking repos lack CI, draft workflows locally | High | L | Feature |
| 17 | rpi3-dns: build-verify after the wave lands (eval-green ≠ build-green, this wave proved it) | Low | S | Bug-risk |
| 18 | nix-email: after the deploy, re-run the contract test against any further nix-email lock movement (the upstream comments flag open 0.16 provision-deadlock work) | Low | S | Watch |
| 19 | go-taskqueue: if #4 turns out upstream, file with verify-before-filing + github-voice; if local, land the packaging fix and drop the wave-row exception | Medium | M | Bug |
| 20 | SigNoz: after #2 + deploy, verify signoz frontend serves + the §17/§19 post-deploy legs pass (the frontend FOD was one of the 15) | High | S | Process |
| 21 | CHANGELOG prune: tick the wave rows when #1-#5 land (queue `[x]` rows must never persist) | Low | S | Docs |
| 22 | Consider a `--keep-going` got-hash AUTO-extractor script (parse the enumeration into a paste-ready table) — the transcription is pure mechanical toil recurring every wave | Medium | M | Quality |
| 23 | Re-verify the nix-email wrapper's fallback-admin assertions still hold against the 0.16 stalwart module on the NEXT lock move (they passed this session; the settings store-backend split is new upstream surface) | Low | S | Watch |
| 24 | When the wave is green, update the upstream.md fleet-wave row with "10th wave 2026-10-17, 12 packages, resolved via shims" (history surface stays current) | Low | S | Docs |

---

## §g QUESTIONS I CANNOT ANSWER MYSELF

1. **art-dupl 0.9.0 disposition** — pin back to the last-building rev, drop it from the evo-x2 package set, or hold for an upstream fix? I can gather build evidence either way, but dropping a tool changes what's on your machine — that's an availability call only you can make.
2. **pbx-artmann stalwart state** — the nix-email upstream comments I read while fixing the test describe a "2026-10-17 pbx host switch burn (43-min wedge)" on the provision prestart probe. Is pbx-artmann already stable post-switch (nothing for SystemNix to follow up), or do you want a mail-stack health check (stalwart unit + provision apply + SMTP probe) queued? I cannot see pbx from this host.
3. **Concurrent-session exclusivity** — the 2026-10-15 fleet-wave diagnosis left "11 pending got-hash transcriptions", and this tree is multi-agent. Is another session currently driving the 15-failure unblock (so I stay off those rows entirely), or is the wave mine to execute on your go?

---

## §h HARVEST RECORD (self-harvest at authoring time, per AGENTS.md TODO System)

**Harvested NOW (direct follow-ups of this session's work):**
- TODO_LIST.md `### upstream`: 3 rows — (1) `[ready]` the 13-item got-hash/pnpmDeps transcription wave (→ upstream.md), (2) `[ready]` go-taskqueue 0.3.4 triage (→ upstream.md), (3) `[decision]` art-dupl 0.9.0 disposition (→ upstream.md).
- docs/todo/upstream.md: matching library rows with the full §d1 table reference, fix loci, and `**Source:**` pointers to this report.

**Deliberately NOT harvested, and why:**
- §f items 6-24 (deploy chain, CI-restoration execution, hardening ideas): either sequenced behind the harvested wave (premature queueing = the premature-row class), owned by EXISTING open rows (CI-restoration, `nix fmt` scoping, hermes watch row — queue duplicates would drift), or owner-process suggestions (e5) with no fix locus in this repo. The existing rows already carry them; this report is their Source citation when dispatched.
- No premise-verified config claim was queued unverified: the three harvested rows were spot-checked this session (a4) per the queue-author rule.
