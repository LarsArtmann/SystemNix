# Status Report: 2026-08-16 17:09 — Deploy Failure: Buildcache Mount Staleness + Browser-History OIDC Discovery Race

## TL;DR

The 16:40 deploy failed activation because of TWO independent issues, both of
which were latent bugs exposed by a coincidental USB device remap:

1. **browser-history-server (status=69 / UNAVAILABLE)** — fixed in code
   (`browser-history.nix`: added `mkOidcGate` from `lib/default.nix`).
2. **buildcache-init (status=1 / chown EIO)** — kernel mountinfo is stale
   (references `/dev/sda1`, actual device is `/dev/sdc1`). Needs **user action**
   to recover (reboot or manual umount).

`nix flake check --no-build` passes after the browser-history fix. The fix is
NOT deployed yet — `nh os switch` will fail again until the buildcache mount is
recovered, even with the browser-history fix in place.

## What I diagnosed

The user's pasted terminal output covered ~50 lines of `nh os switch --test` failing
with `Activation (test) failed: exit status 4`. Two services reported:

- `browser-history.service`: `Main process exited, code=exited, status=69/UNAVAILABLE`
- `buildcache-init.service`: `chown: changing ownership of '/mnt/buildcache/go-build':
  Input/output error` → `status=1/FAILURE`

I dug into both root causes via direct journal reads (cannot use `sudo journalctl`,
but `strings` on `/var/log/journal/241d42a9732745578bef3062e6af2330/system.journal`
gives the same content).

### browser-history — root cause confirmed

The binary's own log message (excerpted from the journal):

```
{"time":"2026-08-16T16:40:24.331","level":"ERROR","msg":"[infrastructure:server.create_oauth2_provider]
  create OAuth2 provider: [transient:oauth2.init_provider] init provider \"pocket-id\":
  [transient:oauth2.oidc_discovery] discover oidc provider \"pocket-id\":
  Get \"https://auth.home.lan/.well-known/openid-configuration\":
  dial tcp: lookup auth.home.lan on 9.9.9.9:53: no such host","exit_code":69}
```

This is NOT `ProviderConfig.Validate()` (which was the previous browser-history
crash class, gated by the `oauth2SecretsFile` oneshot). This is **OIDC discovery
at startup failing because dnsblockd hasn't bound 127.0.0.1:53 yet**.

Timeline reconstruction from journals:

| Time | Event |
|------|-------|
| 16:40:21 | dnsblockd `loaded config file` (process started, CA loading…) |
| 16:40:21 | buildcache-init started, mkdir ok, chown → **EIO** |
| 16:40:22 | pocket-id-provision re-registered browser-history OIDC client |
| 16:40:24 | browser-history-server started → OIDC discovery → 9.9.9.9 lookup fails |
| 16:40:24 | browser-history exits status=69 (UNAVAILABLE) |
| 16:40:29 | dnsblockd `loaded CA certificate` (8s after browser-history tried DNS) |

**Mechanism:** browser-history v4.7.0+ (input `4e7604d`) does OIDC discovery at
startup when `OAUTH2_POCKET_ID_*` env vars are present. Go's `net.Resolver`
queries `127.0.0.1:53` first (per `/etc/resolv.conf`). dnsblockd hadn't bound
that port yet (process was mid-startup, CA cert not loaded) — query gets
connection refused. Go's resolver falls through to `9.9.9.9` (the secondary
nameserver). `9.9.9.9` doesn't know `auth.home.lan` → NXDOMAIN → exit 69.

The previous browser-history input (`f1f44c1`) did not do OIDC discovery at
startup (the old OAuth2 setup was lazy-initialized on first request). This
regression surfaced because `4e7604d` (+16 KiB) is a behavior-changing release.

**Existing dependency list is insufficient.** Current `systemd.services.browser-history.after`:
`["pocket-id.service" "pocket-id-provision.service" "browser-history-oidc-setup.service"]`.
None of these imply dnsblockd is up. dnsblockd is its own service with its own
startup timeline.

### buildcache — root cause confirmed

Direct device-state inspection (cannot sudo, so used sysfs + proc):

| Source | Finding |
|--------|---------|
| `lsblk` | No `sda` — device table starts at `sdb` (8:16) |
| `/proc/partitions` | Confirms `sdb/sdc/sdd/sde/sdf` only; no `sda` |
| `findmnt /mnt/buildcache` | Source = `/dev/sda1` (major:minor 8:1 — does NOT exist) |
| `/proc/self/mountinfo` | `8:1 / /mnt/buildcache ... ext4 /dev/sda1 rw,...,emergency_ro,shutdown` |
| `/sys/fs/ext4/` | Only `sda1` sysfs entry exists; no `sdc1` (kernel still has stale ext4 state) |
| `/dev/disk/by-id/ata-SanDisk_SDSSDA240G_174444471311-part1` | Symlinks to `../../sdc1` |
| Last buildcache-metrics write | `usage=99%, free=4GB/235GB, smart=PASSED` |
| Kernel logs | `EXT4-fs warning (device sda1): htree_dirblock_to_tree:1051: inode #2: lblock 0: comm ls: error -5` |

**Mechanism:** the buildcache SSD was hot-unplugged/replugged (or the enclosure
power-cycled). The kernel reassigned the device letter from `sda` to `sdc` (USB
enumeration changed), but the existing VFS mount entry was NOT refreshed. The
mount now references a dead major:minor (`8:1` = `sda1`, doesn't exist anymore).
ext4 detected directory read errors and flipped to `emergency_ro,shutdown` —
writes return EIO. `buildcache-init` chowns `go-build` → EIO → status=1 →
`multi-user.target` blocked → deploy activation fails.

The by-id symlink correctly resolves to the new device, so a fresh mount
(via the by-id path) WOULD work — but the zombie mount prevents systemd from
re-mounting. **Reboot** clears the kernel mountinfo and remounts cleanly via
the by-id path. **Manual umount** also works.

SMART health is PASSED (temperature 53→55°C, no reallocated sectors, no
errors). The filesystem corruption is from the abrupt USB disconnect, not
drive failure.

## What I changed

### `modules/nixos/services/browser-history.nix`

1. Added `mkOidcGate` to the helper imports from `lib/default.nix`.
2. Moved the `systemd.services.browser-history-oidc-setup` definition into the
   `pocketIdEnabled` `let ... in { ... }` block (it was previously outside the
   `lib.mkIf` boundary but using `lib.mkIf` internally — functionally fine but
   the `oidcGate` reference requires it inside the conditional's `let` binding).
3. Added `oidcGate.after` to the service's `after` (now includes `network-online.target`,
   `pocket-id.service`, `dnsblockd.service`, `pocket-id-provision.service` + the
   pre-existing `browser-history-oidc-setup.service`).
4. Added `oidcGate.wants` to `wants`.
5. Added `oidcGate.serviceConfig.ExecStartPre` to the service's `serviceConfig`
   via `lib.mkMerge` — this is the curl probe `browser-history-wait-oidc` that
   polls `https://auth.${domain}/.well-known/openid-configuration` with 60×2s
   retries (max 2min) before the server starts.

Eval verification:

```
$ nix eval .#nixosConfigurations.evo-x2.config.systemd.services.browser-history.after
[ "network-online.target" "pocket-id.service" "dnsblockd.service" "pocket-id-provision.service"
  "browser-history-oidc-setup.service" ]
$ nix eval .#nixosConfigurations.evo-x2.config.systemd.services.browser-history.serviceConfig.ExecStartPre
[ "+/nix/store/wq5mahdi00vkxw4mdfczmn9mja3raqml-browser-history-wait-oidc/bin/browser-history-wait-oidc" ]
$ nix flake check --no-build → all checks passed
```

### `AGENTS.md`

Added two new gotcha entries (long-term lessons, not session notes):

- **Browser History: OIDC discovery at startup requires dnsblockd-ready gate
  (v4.7.0+, deploy 2026-08-16)** — full mechanism, the dnsblockd-bound
  timing race, the 9.9.9.9 fallthrough, the mkOidcGate fix.
- **Build cache SSD: Stale mountinfo after USB hot-plug** — full detection
  recipe (`findmnt` vs `lsblk` cross-check, the `8:1` not-in-partitions signal),
  recovery steps (reboot vs manual umount+automount restart), the silent-EIO
  trap when GC thinks writes succeed but they're failing.

## What I did NOT change

- **Did not deploy.** `nh os switch` will still fail because buildcache-init
  hits the same EIO wall until the mount is recovered.
- **Did not run `nix fmt`.** The change is structurally clean; formatter
  shouldn't touch it. Will defer to the auto-daemon or next manual pass.
- **Did not add a `pre-deploy-check.sh` buildcache-mount-staleness assertion.**
  This SHOULD exist (it's exactly the kind of gate that prevents the next
  deploy-blocker) — but adding it requires sudo to verify the assertion logic,
  which I can't do from this session. Documenting as a queue item.

## What's needed from the user

**Before the next deploy, recover the buildcache mount.** Either:

```bash
# Option A — reboot (cleanest, ~30s)
sudo reboot
```

```bash
# Option B — manual umount + remount (no downtime for non-buildcache services)
sudo systemctl stop buildcache-init buildcache-metrics buildcache-gc.timer
sudo umount -l /mnt/buildcache
sudo systemctl daemon-reload    # pick up any pending unit changes
sudo systemctl reset-failed buildcache-init
sudo systemctl start mnt-buildcache.automount
sudo systemctl start buildcache-init
```

Then verify before deploying:

```bash
findmnt /mnt/buildcache          # source must be /dev/sdc1 (or current device letter), /dev/sda1 means still stale
ls /mnt/buildcache | head        # should list go-build, go-mod, npm, rust, etc. — not I/O error
```

Then deploy as usual — `nix run .#deploy`.

## Open queue items

1. ~~**`pre-deploy-check.sh` buildcache-mount-staleness check** — cross-check `findmnt /mnt/buildcache` source device against `lsblk` output; fail pre-deploy if the source device isn't in the current block-device list. The exact check the next session should add.~~ ← open — TODO_LIST Priority 3 (zombie-mount detector)
2. **Hermes deploy-failure investigation** — `hermes.service: status=1/FAILURE` on 2026-08-16 with `Slash command sync timed out` in the journal. ← open — TODO_LIST Priority 1
3. **`nix-build-cleanup.service` exit 1** — same deploy, separate issue, low priority (orphaned sandbox cleanup, not user-facing). ← open (untracked, minor)
4. **btrfs+zstd buildcache conversion** — still deferred. ← open — TODO_LIST Priority 2
   conversion would turn it into EIO→cache-miss→rebuild via btrfs checksums.
   Worth re-prioritizing.

## Verification

- `nix flake check --no-build`: passed (×1, after browser-history fix).
- Browser-history fix only — buildcache mount issue is NOT code-related and
  requires host action.
- Auto-git daemon will commit the change once verified clean (AGENTS.md + .nix
  edits). No manual commit needed.
---

## Resolution (2026-08-17, docs-health pass)

Both root causes were fully resolved the same evening by the 18-39 session: (1) the browser-history `mkOidcGate` fix was deployed (input `4e7604d` era — see CHANGELOG "browser-history fast startup" entry; the AGENTS.md gotcha landed verbatim); (2) the buildcache zombie-mount got the full self-healing stack (`buildcache-usb-recovery`, device-bound mount, udev rules, real-I/O-gated metrics, deploy.sh `Exited(4)` handling — CHANGELOG "Buildcache zombie-mount self-healing stack"). Queue items routed: #1 → TODO_LIST P3 detector, #2 → TODO_LIST P1 hermes, #4 → TODO_LIST P2 conversion window; #3 untracked-minor. Archived as resolution-complete.
