# perSystem apps — operational CLI wrappers (deploy, pre/post-deploy checks,
# migrations, DMS helpers). mkApp wraps scripts/ via writeShellApplication.
# Split out of flake.nix 2026-10-08.
{
  inputs,
  root,
  theme,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      lib,
      ...
    }:
    {
      apps =
        let
          mkApp = name: description: runtimeInputs: scriptPath: {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                inherit name runtimeInputs;
                text = builtins.readFile scriptPath;
              }
            }/bin/${name}";
            meta.description = description;
          };
        in
        {
          validate = mkApp "validate" "Validate flake without building" [ pkgs.nix ] (
            root + "/scripts/validate.sh"
          );
          fix-nixpkgs-lock =
            mkApp "fix-nixpkgs-lock"
              "Restore the flake.lock nixpkgs node to github type (one-command recovery from the tarball regression)"
              [ pkgs.nix pkgs.jq ]
              (root + "/scripts/fix-nixpkgs-lock.sh");
          migrate-hot-db =
            mkApp "migrate-hot-db"
              "User-run migration of a service dataDir onto the Samsung hot-DB tier (services.hot-db): prepare|finalize with pressure gate + verify"
              [
                pkgs.bash
                pkgs.coreutils
                pkgs.findutils
                pkgs.gawk
                pkgs.rsync
                pkgs.util-linux
              ]
              (root + "/scripts/migrate-hot-db.sh");
          migrate-buildcache =
            mkApp "migrate-buildcache"
              "One-time migration of build caches (Go/Rust/npm/pip/pnpm/playwright) to the USB SSD at /mnt/buildcache. Run BEFORE the first deploy of services.buildcache"
              [
                pkgs.coreutils # cut, du, find, tr, wc
                pkgs.e2fsprogs # e2label
                pkgs.findutils
                pkgs.gnugrep
                pkgs.rsync
                pkgs.trash-cli
                pkgs.util-linux # findmnt, mountpoint
              ]
              (root + "/scripts/migrate-buildcache.sh");
          pocket-id-login-code =
            mkApp "pocket-id-login-code" "Generate a one-time Pocket ID login code for a new device"
              [ pkgs.curl pkgs.jq ]
              (root + "/scripts/pocket-id-login-code.sh");
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # evo-x2/NixOS operations apps. Linux-gated (2026-09-28): their
          # runtimeInputs carry Linux-only nixpkgs (systemd, procps,
          # efibootmgr, btrfs-progs, glibc) which REFUSE TO EVALUATE on
          # aarch64-darwin — plain `nix flake check` on a Linux runner
          # silently omits the darwin system, so the breakage is only
          # visible via `nix flake check --all-systems` (or on the Mac).
          deploy = mkApp "deploy" "Deploy NixOS config to evo-x2 via nh with post-deploy checks" [
            pkgs.nh
            pkgs.systemd
            pkgs.util-linux # flock — concurrent-deploy guard (T13)
            pkgs.procps # ps/pgrep — wedged switch_to-configuration detection
          ] (root + "/scripts/deploy.sh");
          migrate-rust-cache =
            mkApp "migrate-rust-cache"
              "One-time setup of the dedicated Rust cache SSD (/mnt/rust-cache, second SanDisk SDSSDA240G): format btrfs, mount, and move rust/sccache/cargo off /mnt/buildcache. Run BEFORE the first deploy of services.rust-cache"
              [
                pkgs.btrfs-progs # mkfs.btrfs
                pkgs.coreutils # df, find, ls, rm, wc
                pkgs.findutils
                pkgs.rsync
                pkgs.util-linux # findmnt, mount, mountpoint
              ]
              (root + "/scripts/migrate-rust-cache.sh");
          io-psi-forensics =
            mkApp "io-psi-forensics"
              "Snapshot per-cgroup I/O attribution + D-state stacks to /var/tmp (run during an I/O storm; same script the guard fires on trip)"
              [
                pkgs.coreutils
                pkgs.procps
                pkgs.gawk
                pkgs.gnugrep
                pkgs.findutils
                pkgs.systemd
              ]
              (root + "/scripts/io-psi-forensics.sh");
          pre-deploy-check =
            let
              # mkApp single-files scripts, but pre-deploy-check.sh
              # sources scripts/lib/metrics-gate.sh relative to its own
              # path — package the lib as a sibling so the wrapper's
              # runtime `source` resolves (2026-09-02: the refactor that
              # extracted the gate shipped without this and every deploy
              # aborted at the wrapper's runtime).
              inner = pkgs.writeShellApplication {
                name = "pre-deploy-check";
                runtimeInputs = [
                  pkgs.nix
                  pkgs.jq
                  pkgs.systemd
                ];
                text = builtins.readFile (root + "/scripts/pre-deploy-check.sh");
              };
            in
            {
              type = "app";
              program = "${
                pkgs.runCommand "pre-deploy-check" { } ''
                  mkdir -p $out/bin/lib
                  cp ${inner}/bin/pre-deploy-check $out/bin/pre-deploy-check
                  cp ${root}/scripts/lib/metrics-gate.sh $out/bin/lib/metrics-gate.sh
                  # §13 sources the offsite-borg smoke lib the same way;
                  # unstaged = the gate dies at source time on EVERY deploy
                  # (the 2026-09-02 metrics-gate staging class).
                  cp ${root}/scripts/lib/offsite-borg-smoke.sh $out/bin/lib/offsite-borg-smoke.sh
                  # vendor-freshness.sh was added to the script's sources
                  # without a staging line — same 2026-09-02 class; every
                  # deploy aborted at source time until staged (2026-10-04).
                  cp ${root}/scripts/lib/vendor-freshness.sh $out/bin/lib/vendor-freshness.sh
                  chmod +x $out/bin/pre-deploy-check
                ''
              }/bin/pre-deploy-check";
              meta.description = "Pre-deploy validation: catches boot-breaking issues before switch";
            };
          post-deploy-check =
            let
              # Same sibling-lib staging as pre-deploy-check: the script
              # sources scripts/lib/pressure-report.sh relative to its own
              # path, so package the lib next to the binary (2026-09-02
              # 21:57 deploy: the bare mkApp app failed its own build on
              # shellcheck SC1091/SC2016 and the smoke never ran).
              inner = pkgs.writeShellApplication {
                name = "post-deploy-check";
                runtimeInputs = [
                  pkgs.coreutils # date, wc, head, tr, sleep, id
                  pkgs.curl
                  pkgs.fish
                  pkgs.gawk # lib/pressure-report.sh PSI/zram arithmetic
                  pkgs.glibc # getent
                  pkgs.gnugrep
                  pkgs.jq
                  pkgs.nix
                  pkgs.procps # pgrep
                  pkgs.systemd # systemctl, journalctl
                ];
                text = builtins.readFile (root + "/scripts/post-deploy-check.sh");
              };
            in
            {
              type = "app";
              program = "${
                pkgs.runCommand "post-deploy-check" { } ''
                  mkdir -p $out/bin/lib
                  cp ${inner}/bin/post-deploy-check $out/bin/post-deploy-check
                  cp ${root}/scripts/lib/pressure-report.sh $out/bin/lib/pressure-report.sh
                  # §16 sources the shared offsite-borg smoke lib; stage
                  # it like pressure-report.sh or the smoke dies at source
                  # time on every deploy.
                  cp ${root}/scripts/lib/offsite-borg-smoke.sh $out/bin/lib/offsite-borg-smoke.sh
                  # The crush smoke section resolves helpers relative to
                  # BASH_SOURCE (the store bin dir), so stage the
                  # rc-test harness too or the check always fails with
                  # "No such file or directory" (2026-09-17 smoke).
                  cp ${root}/scripts/crush-rc-test.sh $out/bin/crush-rc-test.sh
                  chmod +x $out/bin/post-deploy-check
                ''
              }/bin/post-deploy-check";
              meta.description = "Post-deploy smoke test: verifies services are functional, not just alive";
            };
          pre-reboot-check =
            mkApp "pre-reboot-check"
              "Pre-reboot boot-chain audit: loader default -> ESP assets -> init on live store -> three-way profile anchor -> closure sanity -> initrd devices -> GC anchoring (built after the 2026-09-07 stuck boot; hardened 2026-09-09)"
              [
                pkgs.btrfs-progs # filesystem show (MISSING device audit)
                pkgs.coreutils # stat, timeout, dirname, awk-free parsing helpers
                pkgs.diffutils # cmp (exit-4 predictor unit-file diffing) + boot-mirror tree diff
                pkgs.efibootmgr # §11: mirror EFI entry / BootOrder audit
                pkgs.gawk # loader.conf/entry parsing
                pkgs.gnugrep
                pkgs.nix # path-info closure sanity + nix-store gc-root queries
                pkgs.systemd # systemctl (quiet-window advisories, nix-gc timer, bootctl)
                pkgs.util-linux # findmnt + lsblk (mirror ESP device resolution)
              ]
              (root + "/scripts/pre-reboot-check.sh");
          boot-mirror-activate =
            mkApp "boot-mirror-activate"
              "Switch the firmware boot chain to the Samsung 2nd-boot-disk ESP: ensure its EFI entry exists and order it first (idempotent; QLC entries stay fallback)"
              [
                pkgs.coreutils # tr/cut/paste
                pkgs.efibootmgr
                pkgs.gnused
                pkgs.gawk
                pkgs.gnugrep
                pkgs.systemd # bootctl is-installed
                pkgs.util-linux # findmnt + lsblk
              ]
              (root + "/scripts/boot-mirror-activate.sh");
          btrfs-inventory = mkApp "btrfs-inventory" "List all BTRFS subvolumes, snapshots, and mount points" [
            pkgs.btrfs-progs
            pkgs.util-linux
            pkgs.coreutils
            pkgs.findutils
          ] (root + "/scripts/btrfs-subvolume-inventory.sh");
          verify-io-tiers = mkApp "verify-io-tiers" "Verify BFQ I/O priority tiers are correctly applied" [
            pkgs.systemd
            pkgs.procps
          ] (root + "/scripts/verify-io-tiers.sh");
          dns-diagnostics =
            mkApp "dns-diagnostics" "Run DNS stack diagnostics (resolution, blocking, stats, connectivity)"
              [
                pkgs.systemd
                pkgs.bind.dnsutils
                pkgs.curl
                pkgs.iproute2
                pkgs.iputils
                pkgs.jq
              ]
              (root + "/scripts/dns-diagnostics.sh");
          dms-restart = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "dms-restart";
                runtimeInputs = [ pkgs.systemd ];
                text = "systemctl --user restart dms.service && echo 'DMS restarted'";
              }
            }/bin/dms-restart";
            meta.description = "Restart DankMaterialShell desktop shell";
          };
          dms-locks = {
            type = "app";
            program = "${
              pkgs.callPackage (root + "/pkgs/dms-lock.nix") { inherit (theme) colors; }
            }/bin/dms-lock";
            meta.description = "Lock screen via DMS IPC (fallback: swaylock-effects with wallpaper + Catppuccin Mocha)";
          };
          dms-wallpaper-next = {
            type = "app";
            program = "${
              pkgs.writeShellApplication {
                name = "dms-wallpaper-next";
                runtimeInputs = [ inputs.dankMaterialShell.packages.${system}.default ];
                text = "dms ipc call wallpaper next";
              }
            }/bin/dms-wallpaper-next";
            meta.description = "Cycle to next wallpaper via DMS IPC";
          };
          crush-daily-backfill = {
            type = "app";
            program = "${
              pkgs.writers.writePython3Bin "crush-daily-backfill" {
                flakeIgnore = [
                  "E501"
                  "E265"
                ];
              } (builtins.readFile (root + "/scripts/crush-daily-backfill.py"))
            }/bin/crush-daily-backfill";
            meta.description = "Backfill crush-daily reports for zero-data or missing dates";
          };
        };
    };
}
