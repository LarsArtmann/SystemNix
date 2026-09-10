# taciturnaxolotl/dots Review (2026-09-10) vs SystemNix

**Date:** 2026-09-10
**Subject:** [github:taciturnaxolotl/dots](https://github.com/taciturnaxolotl/dots) — "Kieran's opinionated (and ever expanding) nix config". Cross-platform (nix-darwin + 2 NixOS servers + standalone HM + ISOs), 591 days in operation, 776 commits, MIT, actively pushed (2026-09-08). 4 machines: `atalanta` (macOS workstation), `terebithia` (aarch64 homelab VPS), `prattle` (x86 media/CI, bcachefs root), `nest` (standalone HM).
**Method:** Full file-tree review + source-level reading of the interesting parts (mkService factory, services manifest, nix-cache module + nix daemon patch, deploy workflows, AGENTS.md, deployment docs). Key claims verified against primary sources (nix upstream issues, local systemd man page) per the verify-external-claims discipline; our exposure checked live on evo-x2.
**Relation to prior art:** same genre as `docs/research/UNIXPORN_NIXOS_ANALYSIS.md` (community config sweep) but a single-repo deep dive with claim verification.

---

## 1. Verdict table

| Domain | dots approach | SystemNix (live 2026-09-10) | Verdict |
| --- | --- | --- | --- |
| Service abstraction | `mkService` factory: one call creates options + user + systemd unit + Caddy vHost + backup hooks | Filename-auto-discovered modules + shared lib helpers (`harden`, `serviceDefaults`, `protectedVHost`) + AGENTS.md procedure | **Different fit** — our modules are heterogeneous (upstream wrappers); factory suits their homogeneous bun/node app fleet |
| Backup registration | Declared in-service via `data.sqlite`/`data.postgres`/`data.files`/`stopUnits` options; backup system discovers it | Manual `services.backup-coordination.backups.<name>` registration in configuration.nix | **Their model is better — adoptable as per-module metadata** |
| Service inventory | `nix eval --json .#services-manifest` (machines × services, incl. internal `_description`/`_runtime` options) → infra dashboard + mdbook | Homepage tiles + Gatus config + docs/services/*.md, all manually wired | **Their model is better — invertible into a completeness AUDIT for us** |
| Port collisions | Eval-time assertion comparing all enabled `atelier.services.*.port` | `lib/ports.nix` central registry + eval-time checks | **Aligned (ours is single-source-of-truth, catches disabled-service conflicts too)** |
| Deployment | CI (GitHub Actions) over Tailscale SSH: deploy-rs for infra, git-pull+install+restart per app service, auto-rollback incl. DB restore | Local `nix run .#deploy` (nh) with pre/post-deploy checks, anchoring warnings | **Opposite philosophies — theirs trades hermeticity for CI-driven rollback** |
| App runtime | `git clone` + `bun install` ON THE HOST (scaffold once), then CI pulls | Hermetic `buildGoModule`/flake-input builds, vendorHash-pinned | **Ours is right for us — theirs is unversioned runtime state** |
| Secrets | agenix, single RSA identity | sops-nix + age (SSH host key derived) | Aligned (equivalent tooling) |
| Docs | mdBook built by nix, lib functions documented in nixdoc format feeding `libdoc` | AGENTS.md + docs/services/ + docs/status/ + TODO_LIST/FEATURES | **Their generated-lib-docs trick is nice; our prose is deeper** |
| Hardware | nixos-facter JSON reports (declarative hardware scan) | hand-maintained hardware-configuration.nix | **Interesting, not urgent for a 2-host fleet** |

---

## 2. The nix 2.34 daemon-abort bug (the headline finding) ⚠️

Their `modules/nixos/nix-cache.nix` documents, with unusual engineering care, a **daemon-killing nix bug** and carries a patch overlay for it:

> An unreachable [substituter] does NOT quietly fall back to cache.nixos.org, whatever the extra-* keys suggest. Stock nix 2.34 aborts the daemon instead: a failing narinfo worker sets the thread pool's quit flag, the next worker logs its own error through TunnelLogger, and that write throws Interrupted from inside a catch block and unwinds out of the thread. The client sees "Nix daemon disconnected unexpectedly" and every host loses the ability to build anything. download-attempts, connect-timeout and --fallback were all tried; none help. NixOS/nix#3768 (open since 2020) and NixOS/nix#12871.

**The patch** (`patches/nix-2.34-daemon-no-interrupt-on-client-write.patch`, applied via `nixVersions.nixComponents_2_34.appendPatches`): adds an `allowInterrupts` flag to `FdSink` (default true) and sets it false on the daemon connection's sink in `processConnection` — logging writes and framed protocol writes must never be aborted by `checkInterrupt()`. Comment: "Drop this once upstream lands a fix."

### Verification status

| Claim | Status | Source |
| --- | --- | --- |
| nix#3768 "Crash (SIGABRT) when connecting to substituter times out", open since 2020-07-01 | ✅ Verified | gh issue view (2026-09-10) |
| nix#12871 "Abort (assertion failure) in TunnelLogger::enqueueMsg", open since 2025-04-02, stack: `ignoreExceptionExceptInterrupt` → `TunnelLogger::log` → `enqueueMsg` → `__cxa_rethrow` → `std::terminate` → SIGABRT | ✅ Verified (stack matches dots' mechanism description verbatim) | gh issue view (2026-09-10) |
| Client error string `Nix daemon disconnected unexpectedly (maybe it crashed?)` | ✅ Verified (appears verbatim in #12871 body) | same |
| No nix.conf knob mitigates (download-attempts / connect-timeout / --fallback) | 🔶 Their lived experience, plausible, untested here | dots repo comment |
| evo-x2 exposure | ✅ Checked live: nix 2.34.8 deployed, `https://cache.home.lan/monitor365` in `/etc/nix/nix.conf` substituters; journal sweeps 2026-01→09 = ZERO abort hits and ZERO `Main process exited`/`Failed with result` events for nix-daemon all year (coredumpctl check inconclusive — blocked/timed out in session) | local, 2026-09-10 |

### Why we have NOT been hit (and what would hit us)

Our attic-outage failure modes are all FAST failures, and the abort race needs a HANGING connect:

- dnsblockd down → `cache.home.lan` NXDOMAIN → immediate `unable to download narinfo` (the 2026-09-02 chicken-and-egg deploy block — clean error, daemon survived).
- DAS detached → atticd unit fails (mount-gated) but Caddy (root NVMe) still answers :443 with an instant 502 → clean error.
- The dangerous shape: machine-wide IO storm starving Caddy's accepts (or any state where the TCP connect hangs for the full timeout) while parallel narinfo queries race — exactly the freeze-incident IO conditions this box has repeatedly entered.

**Action encoded:** AGENTS.md Nix & Nixpkgs gotcha added (AGENTS.md:651) — if the signature ever appears, root cause is known, patch shape is known, adopt `appendPatches` rather than debugging from scratch. Recovery: `systemctl restart nix-daemon` (+ `reset-failed` if start-limited; the daemon is socket-activated).

**Note on their own doc drift (corrected 2026-09-10 23:55):** their AGENTS.md says "Both servers use Lix … Atalanta also uses Lix". Full-repo code search verifies only HALF of that: `modules/darwin/defaults.nix` does set `nix.package = pkgs.lixPackageSets.latest.lix` (atalanta, gated on `nix.enable`), but NO `nix.package = lix` exists anywhere for the Linux servers — terebithia/prattle run stock nix, which is exactly why the flake patches `nixVersions.nixComponents_2_34`. The "both servers" clause is stale; the atalanta clause is live. (Their README: "the most reliable docs are just the config itself" — the honest admission every long-lived dotfiles repo eventually makes. SystemNix's docs-health discipline exists precisely to fight this.)

---

## 3. The services manifest (best stealable pattern)

`lib/services-manifest.nix` + `lib/services.nix` evaluate every machine's `atelier.services.*` into a JSON flake output:

- Each mkService module exposes internal read-only options `_description` and `_runtime` — metadata rides INSIDE the module system.
- `isMkService` duck-types entries (has `enable`, `domain`, `port`, `_description`); custom non-factory services (herald, n8n, garage, knot…) get hardcoded manifest entries.
- Output feeds their public infra dashboard (infra.dunkirk.sh uptime stats) and is documented as a first-class command: `nix eval --json .#services-manifest`.

**The SystemNix inversion (added to TODO_LIST Priority 1.5):** we don't need a dashboard — we need an AUDIT. Cross-reference enabled `config.services.*` against (a) gatus-config endpoints, (b) homepage tiles, (c) `backup-coordination` entries, (d) `docs/services/*.md` existence. Today the "every new service MUST be monitored" rule lives only in AGENTS.md procedure text; a service added without a Gatus check sails through every prevention layer. A manifest-derived assertion closes the class at eval or CI time.

### The `stopUnits` lesson (they learned our paperless lesson independently)

Their backup integration has a `stopUnits` option whose docstring reads: "Defaults to the service name itself, which is only correct when the service ships a single unit named after it. Set this for services that split across several units (e.g. paperless), otherwise the stop is a no-op against a unit that does not exist." — the exact multi-unit backup trap class SystemNix handles per-service today.

---

## 4. mkService factory (interesting contrast, not adoptable wholesale)

`modules/lib/mkService.nix` (392 lines): one call generates options (`enable`, `domain`, `port`, `dataDir`, `secretsFile`, `repository`, `healthUrl`, `data.*`, `caddy.*`, `environment`), user/group, systemd unit with git-clone scaffolding, Caddy vHost with Cloudflare DNS TLS + optional rate-limit zone, port-conflict assertion, and sudo rules letting the service user restart its own unit (the CI/CD enabler).

What is genuinely good:

- **Backup-by-declaration** (§3) — the service module states its data SHAPE; the backup system does the rest (WAL checkpoint, pg_dump, file copy, stop/start orchestration).
- **Eval-time port-conflict assertion across all enabled services** with a message listing every port in use.
- **`_description`/`_runtime` internal options** powering the manifest without a parallel registry.

What does not fit SystemNix:

- The runtime model (`git clone` on host, `bun install` in preStart, `ExecStart = bash -c 'bun run src/index.ts'`) is the anti-hermetic opposite of our buildGoModule/flake-input doctrine — unversioned runtime state, no rollback of app deps, network dependency at first boot.
- Their Caddy is public-internet with ACME DNS challenge + per-vhost rate limiting; ours is LAN-first with sops TLS and Layer 0/1/2 auth. Different threat models.
- SystemNix's module fleet is mostly WRAPPERS around upstream LarsArtmann/nixpkgs modules (discordsync pattern) where a factory has nothing to add.

---

## 5. Deploy discipline (steal the practices, not the pipeline)

### Their infra deploy (`.github/workflows/deploy.yaml`)

- **Path-filtered node selection**: changes under `machines/<node>/` deploy only that node; anything shared (flake, modules, lib, secrets, packages) deploys all. `workflow_dispatch` deploys everything.
- **Pre-deploy generation capture** (`readlink /nix/var/nix/profiles/system` → `system-N`) + a **rollback job** on failure: `nix-env -p /nix/var/nix/profiles/system --switch-generation N` + `switch-to-configuration switch`. This is a CI-side defense against exactly our un-anchored-generation class (2026-09-09: activation exit-4 advances `/run/current-system` but skips the profile bump; a reboot reverts). We have deploy.sh's anchoring warning + `system_current_system_profiled` metric; theirs closes the loop with automated action.
- **Arch-matched runners** (ubuntu-24.04-arm for the aarch64 box) — native builds, no emulation; build on runner, ship only the closure diff, target substitutes the rest from cache.nixos.org.
- **Post-deploy attic push** of the built toplevel ("attic skips anything already on cache.nixos.org, so this uploads only our own paths") — CI as a cache seeder for the fleet.
- **Dead-socket timeout lesson (their 2026-08-23 incident, in comments)**: deploy-rs `activationTimeout`/`confirmTimeout` do NOT bound a dead SSH socket — two runs hung 2h+ in "Waiting for confirmation event...". The fix is SSH keepalives (`ServerAliveInterval=15 ServerAliveCountMax=4`, ~1min bound) plus a generous job timeout backstop. Directly relevant if SystemNix ever grows remote/CI deploys — our wedged-stc lock class (2026-08-18, exit 11) is the local-machine cousin.
- **Measured decision recorded in-repo**: GitHub runner nix cache was a wash — cache-nix-action cut downloaded paths 2459→55 but wall-clock didn't move (restoring a ~4.5 GB GitHub cache ≈ re-fetching from the nixos CDN); the 4-6 min floor is eval + input fetch + copy + activate, which no runner cache touches. They kept the measurement as a comment so nobody re-runs the experiment. This documented-experiment culture mirrors SystemNix's status-report discipline.

### Their app deploy (`.github/workflows/deploy-service.yml`, reusable)

Per-service workflow: Tailscale SSH as the SERVICE user → snapshot SQLite (`cp` pre-deploy) → `git reset --hard origin/main` → install + build → `sudo systemctl restart` (their mkService sudoers rule) → health check (HTTP 200 loop 12×5s, falls back to `systemctl is-active` when no health URL) → on failure, ROLLBACK gated on "the deploy step actually moved the checkout" (their comment: rolling back when nothing happened buries the real error under a second one), including DB snapshot restore. Plus GitHub `environment` URLs, per-service `concurrency` groups, and a step summary with commit/diff links.

The gating discipline and the rollback-precondition thinking are the transferable parts; the pipeline itself presumes the git-pull-on-host model we reject.

---

## 6. Smaller verified learnings

- **systemd `!` prefix (vs `+`)** — verified against the local systemd.service(5) man page (2026-09-10): `+` bypasses User=, Group=, CapabilityBoundingSet=, SystemCallFilter AND namespaces; `!` ONLY bypasses User=/Group=/SupplementaryGroups= — the sandbox STAYS. dots' mkService uses `!`-prefixed ExecStartPre for dir chown. Least-privilege rule: prefer `!` when root identity alone suffices and the sandbox is compatible; `+` remains REQUIRED when the command needs capabilities outside the bounding set (our CAP_DAC_OVERRIDE textfile-collector class). Noted in AGENTS.md:691.
- **facter belt-and-suspenders** — they generate hardware config with nixos-facter but still hard-name critical initrd modules, with the comment: "The facter report now covers both, but they are named here anyway — an initrd that cannot see the root disk is an expensive way to discover the hardware report drifted." Same doctrine as our by-id-over-sd-letters rules: generated state still gets manual pins on the unrecoverable-failure path.
- **nixdoc-format lib docstrings** — `lib/services.nix` uses `/** */` doc comments that feed an auto-generated `libdoc` page in their mdBook. Cheap API-reference generation for lib helpers; SystemNix's `lib/` helpers are documented only in AGENTS.md prose.
- **crush usage** — their repo-root `crush.json` declares only an ssh MCP scoped with `--allowed-hosts=terebithia,prattle` (server-side blast-radius constraint on the MCP itself). Also their SSH config `Match` block cancels the zmx `RemoteCommand` when `CRUSH`/`AI_AGENT` env vars are set — agents get plain SSH automatically. Nice agent-empathy touches; neither applies to our qmd-only MCP setup.
- **`wut` / `pbnj` / `ghrpc`** — in-repo CLI tools shipped with generated completions (bash/fish/zsh) + man pages as module files, and a repo-scaffolding CLI (cobra+fuh) with embedded templates incl. per-artifact license slots. The completions+manpage packaging pattern is the takeaway for any future SystemNix CLI tooling.
- **Their docs SUMMARY structure** — Overview / Installation / Deployment / Services / Secrets / Modules / mkService reference / libdoc. SystemNix's docs/services/*.md runbook depth exceeds their per-service pages; their STRUCTURE (single book, generated reference) is better browsable.

---

## 7. What NOT to copy (and why)

| Their choice | Why wrong for SystemNix |
| --- | --- |
| `git clone` + `bun install` on host at first start | Unversioned runtime state; no rollback of app deps; network dependency at boot. Our hermetic flake-input + vendorHash builds exist precisely to prevent this class. |
| Per-service users with sudo self-restart, CI SSHing in as service users | Enables their pipeline but multiplies SSH surface; our deploys are local, sudo stays operator-only. |
| Cloudflare DNS-challenge public TLS on every vHost | We are LAN-first with sops-managed TLS + the Pocket ID layer stack; public exposure is deliberately minimal. |
| Tailnet as the deploy transport + gate | Our box is the build host (128G RAM); remote-build-elsewhere trades away the one resource we have in abundance. |
| Caddy `rate_limit` plugin per vHost | Layer 0/1/2 auth + LAN bypass covers our threat model; a ratelimit plugin would add a non-default Caddy build for little gain. |

---

## 8. Actions taken from this review

1. **AGENTS.md gotcha added** (Nix & Nixpkgs): the nix 2.34 daemon-abort class — mechanism, upstream issues, our verified exposure (zero hits so far, fast-fail outage modes), and the known patch shape for the day the signature appears.
2. **AGENTS.md gotcha extended** (systemd): `!` vs `+` ExecStart prefix semantics with the least-privilege preference rule.
3. **TODO_LIST Priority 1.5 row added**: service-completeness manifest audit (enabled service ⇒ Gatus + Homepage + backup + docs), the inversion of their services-manifest.
4. This document.

Not actioned (recorded rationale): CI-driven deploys, path-filtered node selection (single NixOS host), nixos-facter (2 hosts, hand-maintained hw config is fine), nixdoc libdocs (low traffic on lib helpers), the nix patch itself (no observed hits — adopt on first occurrence, per the exposure analysis in §2).
