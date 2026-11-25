# Library-policy vendorHash deploy blocker fixed — but the switch never became bootable and two crashes reverted the box to gen-1029

**Session:** 2026-11-25 04:30 → (in progress; DRAFT written at 11:20 so a successor session has the facts if the box crashes again — crash #2 of the morning hit 11:05:51)
**Trigger:** owner-pasted failed deploy (`DEPLOY_FORCE_PRESSURE=2 nix run .#deploy`, HEAD `3150a0050`, 01:35→01:53): `library-policy-e092b400-go-modules.drv` hash mismatch (specified `gYkUTyDk…`, got `UCnKnjhq…`).
**HEAD at authoring:** `2f7955707`
**Live system at authoring:** **gen-1029** (`gwfgxm1vy9`, built 2026-11-24 23:33) — the profile says `system-1030-link` (`hggzirywc8`). Boot id `0737ecd7` (booted 11:06:51).

---

## a) FULLY DONE

1. **Root cause of the pasted failure.** The consumer-side vendorHash shim in `lib/lars-packages.nix` was a pure treadmill: the overnight daemon float moved `library-policy` `8d2b87bf` → `e092b400` (commit `477059e19`, 00:32) while the shim still carried `gYkUTyDk…` (measured at `8d2b87bf` on 11-24). Upstream `e092b400` flake.nix:146 already bakes exactly the deploy's got-hash `UCnKnjhq…` (`a031de3` "refresh vendor hash for the go-datastar version bump"). got == bake = the documented drop-safety test (docs/agents/nix-flakes.md "Misattributed FOD hashes").
2. **Fix: shim dropped** (`library-policy = flakePkg inputs.library-policy;`, history comment cites the deploy log `/var/log/systemnix-deploys/2026-11-25_01-35-47.log`). Daemon-committed as `c008ddc62`.
3. **First-hand proof (this session):** flake-attr toplevel `--keep-going` built 34/34 green (04:49:36→04:50:17); exactly ONE library-policy in the closure (no twin surface); the built go-modules FOD's content hash, recomputed via `nix hash convert --hash-algo sha256 --from nix32 --to sri`, equals `sha256-UCnKnjhqG+PmNkrzZMT3w/F5BAVaMPAGCzrYasbQi0M=`; the a60fda4 binary answers `--help`.
4. **Real deploy carried the fix:** `DEPLOY_FORCE_PRESSURE=1 nix run .#deploy` 04:59:27 → rc=0 at 06:26:27 (`~/.cache/lockfix-20261125/deploy-forced-1.log`, also `/var/log/systemnix-deploys/2026-11-25_04-59-27.log`). §11 read "all deploy go-modules FODs cached"; the build passed; the switch activated `hggzirywc8` (gen-1030).

## b) PARTIALLY DONE

1. **The deploy did not survive the morning.** Activation ended with **exit 4** (failed units; `post-crash-calm-gate.service` alone held the activation 05:09→06:09 waiting for IO calm that never came). nh then printed "Activation failed; the new generation will not be added to the bootloader" and **skipped the boot entry**. ESP state read with sudo at 11:13 (both `/boot` and `/boot-mirror`): newest entry is still `Generation 1029` (`nixos-90cc59d1…a7fd.conf`, mtime 11-24 23:33:54), `loader.conf` `preferred` = that entry, **zero entries carrying gen-1030** on either ESP.
2. **Two hard resets reverted the box to gen-1029:** boot `b4931451` died 08:57:47 (reset `0x02000800` hardware watchdog), booted gen-1029; boot `8b31b428` died 11:05:51 (reset `0x00080800` software CF9, the panic-reboot class; journal ends mid-activity on redis BGSAVE lines), booted gen-1029 again. Each boot reaches IO PSI some 65-99% within minutes (11:12 attribution: `cvagent` pid 2487 read 116 MB/s for its cold pass then idled; `clickhouse.service` io.pressure some 68%; `llama-vlm-cap` model load in D-state on `blk_mq_get_tag`; `xfsaild/nvme0n1p9` D-state).
3. **A sibling report's anchor claim is refuted by the ESP state.** `docs/status/2026-11-25_06-19_self-review-supplements-weekly-print-deploy-and-fleet-blockers.md` item 8 says `stc boot` + mirror were done for gen-1030 and "pre-reboot-check SAFE TO REBOOT". The sudo journal confirms two `switch-to-configuration boot` invocations for `hggzirywc8` at 05:27:16 and 05:27:36 — **while this deploy's activation still held the switch lock (05:09→06:09)** — but neither ever wrote an entry or `loader.conf` (both mtimes still 23:33:54). The profile repair half (05:27:16 `nix build --profile`) is real; the boot-entry half is not.
4. **deploy.sh hole:** its anchor discipline verifies only `profile == /run/current-system` (profile self-repair + the final exit-14 assertion). It cannot see a generation that is live and profile-anchored but has **no boot entry** — exactly the exit-4 shape. Fix in progress (boot-entry anchor: verify the loader's preferred entry boots the running toplevel, repair with `switch-to-configuration boot`, fail 14 when still unanchored).
5. **§11 gate hole (contributed to the pasted failure):** `scripts/lib/vendor-freshness.sh` graded ANY `^error:` line in the toplevel `--dry-run` as "eval failed" and degraded to a context-free WARN, so at 01:35 the stale library-policy FOD was never previewed and died ~17 min into the deploy build. Fixed in the working tree / daemon commit `6f06c8771`: real eval failure now FAILs loud with the raw output tail and the tree-move note; only the known-benign nix error classes (check #1 vocabulary) are read past; fail-closed on a non-zero exit with no plan. 33 fixture + flow tests green (`scripts/test-pre-deploy-vendor.sh`), strict-mode harness green, new tests fail against the old lib.

## c) NOT STARTED

- A fresh deploy from HEAD (~101 commits ahead of the live generation). Not attempted: the box crashed twice in 2.5 h and the entry gate needs PSI < 20; I did not force (`=1` was used once at 04:59 under the owner's own `=2` precedent; I will not force into a box that is panic-rebooting).
- Crash ledger rows + boot evidence pulls for `b4931451` / `8b31b428` (`scripts/boot-evidence-pull.sh -b <id>`), stability rows, freeze census.

---

*(DRAFT: sections d-h and the TODO harvest follow when the work in b4/b5/c is finished.)*
