# Deploy Unblock — templ-API Hostage Wave: pins, ~50 FOD hashes, signoz patch, hagezi commit-pin

**Filed:** 2026-11-06 10:35 CET · **Directive:** "FIX … READ, UNDERSTAND, RESEARCH, REFLECT … keep going until everything works" + "make sure everything is on latest!" + "why is it so hard to fucking deploy?"
**Point-in-time:** SystemNix HEAD `e401485fe` (all work daemon-swept, tree CLEAN), a single toplevel proof is **RUNNING NOW** (`proof-102811.log`, 567 lines, 6 derivations into the build), registry matches flake.lock.
**Predecessors read:** `2026-11-06_06-35_everything-latest-pin-lift-wave-status.md` and (too late — see §d.7) `2026-11-06_08-40_eval-migrations-landed-fod-wave-parallel-collision-upstream-rescues.md`.

---

## a) FULLY DONE

1. **The eval blocker that started the whole session is FIXED and BUILT.** The pasted deploy died at §1 because `checks.x86_64-linux.crowdsec-render` still read `services.crowdsec.localConfig.acquisitions`, an option nixpkgs PR #446307 removed (`mkRemovedOptionModule`). `tests/test-crowdsec-render.nix` now reads `crowdsec.settings.acquisitions` with the migration note. Proof: `nix build .#checks.x86_64-linux.crowdsec-render` → rc=0 (the render test's assertion list runs at BUILD, so this is stronger than the eval-only check). `nix flake check --no-build` then reached `all checks passed!`.

2. **Lock floated to TRUE tips — including the `--refresh` discovery that explains the whole wave.** `nix flake update` moved 9 inputs; `nix flake update --refresh` moved 14 more *nodes*. Without `--refresh`, branch-tracked nodes whose parent flake's own `flake.lock` pins a rev are never re-resolved — that is why `templ-components` (master, `938dbd97`, 2026-10-31) survived a "latest" update while origin/master was already at `9a67228a` (2026-11-06). Evidence: `~/.cache/buildwave/update-*.log`, `update-refresh-*.log`.

3. **FOD hash wave: ≈50 distinct hash values across 18 files, every one probe-evidenced.** Three passes, in this order:
   - the 38-row `mismatch-table-0814.tsv` applied repo-wide (`~/.cache/buildwave/apply-hashes.log`: 38 OK, 1 skip = buildflow, 1 skip = a template fakeHash placeholder);
   - a cross-file sweep after the build showed 5 packages declared in BOTH a service module and `lib/lars-packages.nix` (journal, mr-sync, project-discovery-daemon, projects-management-automation, discordsync) — the first-match-only pass had left the second declaration stale;
   - fakeHash FOD probes for packages whose **stale fixed-output path was silently reused** (a fixed-output store path is keyed by the SPECIFIED hash, so an old build short-circuits): `art-dupl` (probed twice, once per rev), `branching-flow`, `tq` (both surfaces), `buildflow`, `quotaboard`, `cv`;
   - and then six values *reversed* to the pinned-back revs' own values (§a.6). Files: `platforms/common/dns-blocklists.nix`, `lib/lars-packages.nix`, `overlays/linux.nix`, `modules/nixos/services/{_signoz-packages,crm,cv,discordsync,inboxclean,journal-serve,journal-backup,mr-sync,papdashboard,project-discovery-daemon,projects-management-automation,visionreviewd,tq-agent-pool}.nix`, `platforms/nixos/desktop/quickshell.nix`, `flake.nix`.

4. **Three consumer-side shims added, each with first-hand probe evidence and a drop condition.**
   - `buildflow` → `flakePkgShim … "sha256-SRdpoBO+…"` (reverses the 2026-10-28 drop: that drop was evidenced for ce10b79 under the *then* toolchain; the 1d060086 float re-staled it).
   - `art-dupl` → new `flakePkgShim … "sha256-AFkwR+…"` at fork tip `e36712aa` (19: PROVEN the stale-path trap: "reading …/xo/terminfo/@v/v1.3.0.zip: no such file" is a *reused* FOD, never a download bug).
   - `quotaboard` → `package = lib.mkForce (… .overrideAttrs { vendorHash = "sha256-ajV4Osr8…"; })` in `platforms/nixos/desktop/quickshell.nix`, because upstream `61801b1` "chore(deps)" bumped go.mod without refreshing `nix/vendorHash.nix`; without `mkForce` the option collides with the upstream module's own plain definition (caught by eval, fixed before the next build).

5. **The 20-list HaGeZi daily deploy bomb is disarmed.** `platforms/common/dns-blocklists.nix` used a `main`-tracking GitLab URL with per-file pinned hashes — every upstream re-publish re-broke ~20 FODs (the 07:4x deploy died on exactly this: `HaGeZi-hoster-raw` specified `mME4che8`, got `BBE5rsFW`). Now **commit-pinned** at `f8c1f9f8` (mirror HEAD 2026-11-06 02:09) and two independent `nix-prefetch-url` checks confirm the new hashes byte-match the pinned commit (`hoster` → `BBE5rsFW…`, `ultimate` → `QpCn56gx…`). A moving ref with a pinned hash was a self-arming deploy bomb; bump commit+hashes together from now on.

6. **Root cause of the fleet-wide build red FOUND and PROVEN, and 9 inputs pinned to last-consistent revs.**
   `templ v0.3.1100` **deleted** `templ.ResolveAttributeValue` and `templ.JoinURLErrs` (present at `v0.3.1070` — `runtime.go:697` — and absent from the whole `v0.3.1100` tree; verified with `git grep` at both tags). A second, orthogonal break: the `a-h/parse` pseudo-version `db268905` removed `parse.Parser.Match`, so **templ 0.3.1100's own `jstokenizer` cannot compile against it**.
   A/B proof (not inference): a `git worktree` of `library-policy@fca47ff` with `templ v0.3.1070` builds GREEN end-to-end; the same rev with `v0.3.1100` dies `undefined: templ.ResolveAttributeValue`.
   Pins added (each with a LIFT observable, all in `flake.nix` + the allowlist block of `lib/flake-input-pin-audit.nix`): `discordsync` `ea6c444c` (also a discordgo `CacheGuild` API break), `library-policy` `7fc0983`, `journal` `4a63e7f`, `project-dependency-graph` `8335670e`, `crm` `197bdf1`, `golangci-lint-auto-configure` `28340f6`, `inboxclean` `e553c510` (go-cqrs-lite/catalog v4.12.0 is pre-regen), `file-and-image-renamer` `973dd383` (the `a-h/parse` break), `overview` `67b2fac9` (go.mod gained `go-cqrs-lite/dedup/v4` without a `mkPreparedSource` deps-map entry → "modules without local replace").

7. **Two smaller real bugs fixed on the way.**
   - `forgejo-provision-runner` failed to BUILD: under the new nixpkgs, `writeShellApplication`'s shellcheck now flags SC2153 (info) on `--token "$TOKEN"` (TOKEN comes from a sourced file). Fixed properly — explicit `TOKEN=""` before `source` plus a loud guard naming the real failure — rather than a suppression.
   - `signoz-sonic-go126.patch` no longer applied (go.mod context moved at the floated rev). Regenerated it against the live source with `go get github.com/bytedance/sonic@v1.15.4` (→ loader v0.5.2), verified with `patch -p1 --dry-run` before installing; the patch's own comment says drop it when upstream ships sonic ≥ 1.15, and `c14d256` still has v1.14.1, so the patch stays needed.

8. **Diagnosed and cleared the "builds hang forever" symptom.** Four orphaned `nix build … toplevel` clients of mine (plus a `nix flake check -j1`) were serializing on the daemon; the oldest had sat **1h25m with zero children**. Killed all six by explicit PID, then re-ran a single build — which immediately started progressing.

---

## b) PARTIALLY DONE

1. **The green proof.** Last full enumeration (`proof-094220.log`, after the pin wave) listed 8 roots: the 6 pinned apps' go-modules FODs + `file-and-image-renamer` + `overview-prepared-source`. All eight have since been addressed (hashes re-derived for the pinned revs, overview + f-i-r pinned). A **single clean build is running now** (`proof-102811.log`); it has NOT been watched to completion, so "green" is unproven at filing time.
2. **Registries and hashes are committed but never proof-gated together.** `flake/expected-locks.nix` was regenerated (three times: two of them because of my own sequencing bug, §d.1) and the daemon swept it; the float doctrine wants lock+registry committed only after a green proof. Current state is consistent but unproven.
3. **paperless-gpt v0.31.0 FODs** — flagged by the 06:35 session as expected-red; my runs never reached them (still masked behind earlier failures). Its `vendorHash`/`npmDepsHash` are still v0.28.0-era.

---

## c) NOT STARTED

1. Proof→deploy chain: `nix run .#pre-deploy-check` on a QUIET tree (its §11 tree-stamp voids on any edit — see §d.3), then `nix run .#deploy`, then the deploy-anchor check by generation NUMBER.
2. Post-deploy battery: crowdsec FIRST (unit shape changed wholesale: setup split, config render moved, lapi credentials path renamed), runner identity carry, `go version` == 1.27.3, and the known cv crash-loop (rev-independent, still unfixed upstream).
3. The five LIFT observables from the 06:35 report (aw-core, linux-7.3 r8125, `.#signozPkg`, dms-shell installPhase, templ runtime) — only signoz's patch was exercised.
4. Darwin eval probe (`nix flake check --no-build --all-systems`).
5. Docs/memory close-out: TODO rows for the 9 pins, CHANGELOG entry, `go-ecosystem.md`/`nix-flakes.md` pin-policy prose, and the `--refresh` lesson.

---

## d) TOTALLY FUCKED UP! (this session's own faults)

1. **Ordering bug — registry regenerated BEFORE the refresh float.** I re-derived `expected-locks.nix` at 08:35, then ran `nix flake update --refresh`, leaving lock≠registry; every eval then threw the float-audit "floated rev X, registry expects Y" wall (exactly what the owner's deploy battery hit in §13/§14/§16/§19 of the earlier paste). Fixed by regenerating again, but the drift window was self-inflicted.
2. **Four overlapping toplevel builds.** I launched builds and never reaped the previous clients; they queued on the daemon and one looked hung for **1h25m**. I then spent ~20 minutes diagnosing "why is the build stuck" before checking `/proc/<pid>`/children. One build at a time, always.
3. **Edited files while a build was running — and broke the owner's deploy battery with it.** Their `nix run .#deploy` aborted at the LAST gate with `§11 eval-relevant tree MUTATED during §11 (c0996aa → c0996aa*)`. That mutation was mine. A pre-deploy battery needs a quiescent tree; I treated the tree as mine alone.
4. **Trusted the parallel session's mismatch table as authority for the current lock.** `mismatch-table-0814.tsv` was extracted from a *different* graph; ~half the 38 hashes I pasted were for revs we then abandoned, which forced a full reversal pass (§a.3 last bullet). The table needs the lock sha it was taken from printed in the file name.
5. **Hash ping-pong.** I mass-applied "latest" hashes before deciding the latest-vs-pin-back policy; when the pin decision came, six values had to be reversed. The decision should precede the wave: *if tips are internally inconsistent upstream, hashes are a treadmill*.
6. **Corrupted prose in several edit payloads.** Multiple `edit`/`write` payloads contained garbled words (rendering artifacts on my side). Each was caught by re-reading with `sed -n` afterwards, but it cost cycles and could easily have shipped nonsense into a comment.
7. **Skipped the parallel-session pre-read.** I read the 06:35 report and not the 08:40 one until the very end — that report documents a parallel executor landing `768ac75bb` (12 files, the same hash wave) and pushing BuildFlow/cv upstream rescues. A 20-second read at session start would have redirected me to the half nobody was covering.

---

## e) WHAT WE SHOULD IMPROVE

1. **Decide policy before touching hashes.** The tree's problem was never hashes; it was that ~9 fleet apps' *tips* are mutually inconsistent (templ 0.3.1100 vs pre-regen generated code, plus the `a-h/parse` break). Hash work is only worth doing after that is settled.
2. **`nix flake update` is not "latest" without `--refresh`.** Branch-tracked transitive nodes are pinned by their parent's `flake.lock`; only `--refresh` re-resolves them. This deserves a line in `docs/agents/nix-flakes.md` and in `AGENTS.md`'s build section.
3. **Script the FOD sweep against the multi-declaration layout.** Each tool package exists in a service module AND `lib/lars-packages.nix`; a first-match `rg` leaves half of them stale (5/5 did). The sweep should rewrite every declaration of a given hash, not the first.
4. **Never edit during a build or a deploy battery.** Both are tree-stamped; edits void the verdict and (worse) abort the owner's deploy at the last gate.
5. **Run one build.** Reap clients (`pgrep -f "nix build"`) before launching another; a "hung" build is usually a queued one.
6. **Root-cause with a two-minute symbol check first.** `git grep ResolveAttributeValue v0.3.1070` vs `v0.3.1100` would have settled the biggest failure class before any build; instead I spent hours on derivation forensics.
7. **A `moving-ref-with-pinned-hash` lint.** The HaGeZi class (branch URL + FOD hash) is a guaranteed future deploy failure; a grep guard over `platforms/common/*blocklist*.nix` (and generally any `fetchurl` whose URL has no commit/rev) would have caught it months ago.

---

## f) NEXT (impact-ordered)

1. **Watch `proof-102811.log` to completion.** Enumerate any remaining roots and fix them; expect only stragglers (paperless-gpt FODs, possibly a `meta`/cvagent consumer).
2. **Freeze the tree, then run the pre-deploy battery alone** (`nix run .#pre-deploy-check`, §11 included) with no edits in flight, then `nix run .#deploy`.
3. **Anchor check by generation NUMBER** (`ls /nix/var/nix/profiles | grep '^system-[0-9]*-link$' | sort -V | tail -1`) before declaring the deploy done.
4. **Post-deploy battery, crowdsec first** (the whole unit shape changed), then runner identity, `go version`, cv status.
5. **File the pin-lift work**: 9 TODO rows (one per pinned app) with the LIFT observable = "upstream regenerates templates at 0.3.1100 / bumps catalog / wires dedup, and the package builds at tip".
6. **Docs**: CHANGELOG entry for this wave; `nix-flakes.md` `--refresh` + "decide policy before hashes" lessons; darwin eval probe before the next CI run.

---

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Do you want the 9 upstream repos fixed at the source?** Each needs a real fix in its own repo (regenerate `*_templ.go` with the 0.3.1100 generator, or pin templ back to 0.3.1070; bump `go-cqrs-lite/catalog`; wire `dedup/v4` into overview's deps map; pick a compiling `a-h/parse` pair). That means **pushes to 9 sibling repos** — outside my permission by standing rule. Say the word and I will prepare each as a one-commit branch; otherwise the pins hold until their own daemons/CI catch up.
2. **`nixpkgs-llama-rag`** — still deliberately pinned (llama.cpp 0.4.0 spin regression). Keeping it pinned unless you want the live re-verification.
3. **cv-server** — still crash-looping rev-independently (nil-deref at `ChatstoreSessions.HealthCheck`). Disable until upstream lands the guard + chunked rehydration, or leave it noisy?

---

## Evidence index (quote roots only with these)

| What | Where |
| --- | --- |
| crowdsec render check green | `nix build .#checks.x86_64-linux.crowdsec-render` (rc=0, drv `k2malzld5djb7i1a7q979z4zndwwhj7q`) |
| eval green (x86_64-linux) | `~/.cache/fc/check-071916.log` → `all checks passed!` |
| first lock float | `~/.cache/buildwave/update-*.log` (9 inputs) |
| `--refresh` float | `~/.cache/buildwave/update-refresh-*.log` (14 nodes) |
| hash application pass | `~/.cache/buildwave/apply-hashes.log` (38 OK) |
| hash→declaration map | `~/.cache/buildwave/hash-map.tsv` |
| probe evidence (art-dupl/branching-flow/tq) | session drvs `g4i7z32v…`, `hcd2q3pq…`, `wpnqzln1…` |
| buildflow probe | drv `96c9wjgjp4qkzy1pyii42izy9hl5y40m` |
| quotaboard probe | drv `7gvsk9ahjlysk3by72lipa04nnr4lgs0` (got `ajV4Osr8…`) |
| templ A/B proof | `~/projects/library-policy` worktree at `fca47ff` (removed after the test) |
| hagezi prefetch checks | `nix-prefetch-url … /raw/f8c1f9f8…` → base32 → base64 = `BBE5rsFW…`, `QpCn56gx…` |
| current proof | `~/.cache/buildwave/proof-102811.log` |

---

## §h. POST-REPORT ADDENDUM (2026-11-06 11:2x) — the deploy ran, failed on buildflow, and the fix inverted one of my earlier claims

The owner ran `nix run .#deploy` at 10:33 (`/var/log/systemnix-deploys/2026-11-06_10-32-32.log`). It exited 1 at 11:06:50 after 25m33s with ONE build failure, never switching generations.

**Two independent defects, both on `buildflow-ba3cd98`, and both were mine:**

1. **The shim hash I "proved this session" was misattributed.** `lib/lars-packages.nix` carried `sha256-SRdpoBO+…`, but the evidence drv was `…-buildflow-a1d0c14-go-modules` — probed at `a1d0c14` and pasted onto a lock that had already moved to `ba3cd98`. Re-probed at `ba3cd98` with `nix-store --realise 23qjyl87…-buildflow-ba3cd98-go-modules.drv`: `specified SRdpoBO+, got sha256-7F+fM3mxTCysNBZJtoBILx48X1uFLovD762UAISwtJU=` — **exactly what upstream's own `vendorHash.nix` bakes at that rev**. Drop-protocol applied: the shim is gone, `buildflow = flakePkg inputs.buildflow`.
2. **The same package reached `system-path` on two surfaces, so nix built it TWICE.** `platforms/nixos/system/configuration.nix:400` installed the raw `inputs.buildflow.packages.<system>.default` (`7F+fM3`) while `base.nix`'s `builtins.attrValues larsPackages` installed the shimmed twin (`SRdpoBO+`) — two derivations, two independent `go-modules` FOD downloads per deploy, only one of them correct. The `nh` graph showed it plainly (the same pname twice, each with its own `…-go-modules` child). The duplicate entry is removed; buildflow now arrives solely via `larsPackages`.

The deploy log's own error (`read "…/art-dupl/@v/…zip": stream error: stream ID 365; INTERNAL_ERROR`) was a **transient proxy flake on top of** defect 1, not the cause: the version resolves (`proxy.golang.org/…1b165cdb90fb.info` → 200) and the FOD now realises clean.

**Correction to my own §f evidence table:** the row `buildflow probe | drv 96c9wjgjp4qkzy1pyii42izy9hl5y40m` is the receipt for the misattribution — that drv is `a1d0c14`, not the locked `ba3cd98`. A probe's rev receipt is the drv NAME; check it against the lock before pasting.

**Post-fix state (all first-hand):**
- `nix-store -qR <toplevel.drv> | grep -i buildflow` → **one** `buildflow-ba3cd98` (was two).
- `nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going` → **EXIT=0**, 0 builder failures (`~/.cache/buildwave/proof-final2-114500.log`, drv `lqfgrh2da6j1wlv2bih8p2gs1s3jdphh`).
- `nix flake check --no-build --all-systems` → `all checks passed!` (`~/.cache/buildwave/fc-113500.log`).
- Lesson recorded durably in `docs/agents/nix-flakes.md` → "Misattributed FOD hashes and duplicate surfaces (2026-11-06)" + Index row; systemic fix rowed in `docs/todo/pipeline.md` (twin-surface `pname`/`vendorHash` divergence audit) and the pin-wave LIFT in `docs/todo/upstream.md`.

**Nothing else remains before a switch:** every FOD and every derivation the toplevel needs is realised. A `nix run .#deploy` now pays only the rev-metadata rebuild of the top layers (seconds), because `system.configurationRevision = inputs.self.rev` re-keys the toplevel drv on every commit.
