# hot-db — the declarative mechanism for the Samsung hot-DB tier
# (Samsung 970 EVO Plus TLC, Phase 2 of the ratified design).
#
# Plan: docs/planning/2026-09-14_13-27_SAMSUNG-PHASE2-HOT-DB-NATIVE-PARETO-PLAN.md
# (T3 module core, T4 bootstrap oneshot, T7 eval-time assertions).
#
# Design (Rev 3 amendment): each hot entry is a BTRFS subvolume
# `hot/<name>` on the Samsung `tlc` filesystem, mounted AT the service's
# existing dataDir via a generated `fileSystems` entry — the service module
# itself stays untouched; the tier is pure declaration. `cow = false`
# entries get `nodatacow` as a mount option AND `chattr +C` on the fresh
# subvolume root (fresh-subvol inheritance does NOT carry the flag):
# fsync ~1-2 ms for latency-critical SQLite/PG data dirs.
#
# Landmine guard (eval-time): a hot path must NEVER be referenced by any
# btrbk instance — one scheduled snapshot of a nodatacow subvolume
# transparently reverts its extents to CoW, silently destroying the tier
# while every check stays green.
#
# T14 monitoring (2026-09-30): a `hot-db-metrics` textfile collector (5 min,
# fail-closed) exposes `hot_tier_mounted` + per-entry
# `hot_db_entry_mounted{name}` and every enabled entry gets an anchored
# Gatus check — the tier's failure mode (Samsung detached → mounts fail →
# consumers condition-skip silently) was invisible. Runbook for the
# per-service waves: docs/services/hot-db.md.
#
# Anti-shadow wiring (eval-time, per consumer): consumers get
# `RequiresMountsFor` (a detached Samsung FAILS the unit — never a silent
# root-fs shadow write) AND `ConditionPathIsMountPoint` (if a shadow
# directory ever exists under the mountpoint, the unit condition-skips
# instead of writing into it). Per-entry mounts stay `nofail`: the boot
# must survive; the CONSUMER is the loud failure (boot-hazard gotcha).
#
# Deployment gate G0: NO entries are enabled on evo-x2 until the /nix
# soak completes (~2026-09-17) — this module ships dormant (enable=false,
# zero entries); migrations are user windows via
# scripts/migrate-hot-db.sh (clickhouse precedent).
{
  flake.nixosModules.hot-db =
    {
      config,
      options,
      pkgs,
      lib,
      utils,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        mkFilesystem
        mkHttpCheck
        discordAlert
        ;
      cfg = config.services.hot-db;

      entryOpts = {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            description = ''
              Absolute mountpoint — the service's existing dataDir. The
              `hot/<name>` subvolume is mounted exactly here, so the
              service config needs no changes.
            '';
          };
          cow = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Copy-on-write. Keep true for integrity-over-latency stores
              (gatus sqlite: corruption detection beats fsync latency);
              false (nodatacow + chattr +C) for latency-critical DBs
              where the app provides its own integrity (journaling WAL).
            '';
          };
          unit = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              Consumer systemd unit that owns the dataDir. Gets
              RequiresMountsFor + ConditionPathIsMountPoint anti-shadow
              wiring. null = explicitly unmanaged (the assertion then
              expects the path to be documented otherwise).
            '';
          };
          extraUnits = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            description = "Additional units to anti-shadow wire (sister units sharing the dataDir).";
          };
        };
      };

      entryList = lib.mapAttrsToList (name: opts: opts // { inherit name; }) cfg.entries;

      # Names whose `unit`/`extraUnits` cover at least one consumer — the
      # shadow-guard completeness assertion only fires on entries that
      # declare NONE (an entry with no unit anywhere would let a shadow
      # dir go unnoticed).
      unmanaged = builtins.filter (e: e.unit == null && e.extraUnits == [ ]) entryList;

      hotParent = "hot";
      subvolPath = name: "${hotParent}/${name}";
      # systemd-escape --path semantics: '/' → '-', BUT a literal '-' in
      # the path is escaped to \x2d (fstab-generator names the unit
      # var-lib-hotdb\x2dtest.mount, NOT var-lib-hotdb-test.mount — a
      # hand-rolled replaceStrings '/'→'-' name references a NONEXISTENT
      # unit, silently voiding the bootstrap's WantedBy/Before ordering;
      # leading-slash drop included via escape's own semantics).
      mountUnitName = path: "${utils.escapeSystemdPath path}.mount";

      # Every btrbk settings string, recursively — the landmine scan needs
      # no structure knowledge: if any config text mentions an entry path
      # or the hot parent, refuse.
      btrbkStrings =
        let
          go =
            v:
            if lib.isString v then
              [ v ]
            else if lib.isAttrs v then
              # attr NAMES carry the landmine too: `subvolume."hot/mydb" = { }`
              # names the snapshot target without ever being a leaf string.
              lib.flatten ((map go (lib.attrValues v)) ++ (lib.attrNames v))
            else if lib.isList v then
              lib.flatten (map go v)
            else
              [ ];
        in
        lib.flatten (
          map (inst: go (inst.settings or { })) (lib.attrValues (config.services.btrbk.instances or { }))
        );

      # Per-ENTRY landmine scan: a btrbk reference to an entry's subvolume
      # (`hot/<name>`) or its mountpoint is the snapshot landmine. Deliberately
      # NOT a blanket `hot/`-parent match: `hot/` hosts OTHER sanctioned
      # subvolumes — forgejo's Set-B leg (services.forgejo.dedicatedSubvolume)
      # is a COW subvol with its OWN btrbk send leg (snapshots.nix), which a
      # cow subvol may have and a nodatacow entry must not; a blanket match
      # would fail every eval the moment both designs coexist (any Phase-2
      # entry enablement was unimplementable with the blanket form).
      landmineHits = lib.filter (
        s: builtins.any (e: lib.hasInfix e.path s || lib.hasInfix "${hotParent}/${e.name}" s) entryList
      ) btrbkStrings;

      # Entry validation as a failure list, consumed by an ALWAYS-ON config
      # assertion below: config.assertions are enforced by `nix flake check`
      # and every toplevel build, while a bound throw (e.g. parked on a
      # system.build attr) is dead code — nothing forces such extras during
      # eval, so a duplicate-path config would deploy with the last entry
      # silently winning the colliding fileSystems attr.
      validationFailures =
        let
          dupPaths = lib.findFirst (p: lib.length (builtins.filter (e: e.path == p) entryList) > 1) null (
            map (e: e.path) entryList
          );
          badAbs = lib.findFirst (e: !lib.hasPrefix "/" e.path || e.path == "/") null entryList;
          underHot = lib.findFirst (
            e: lib.hasPrefix "/${hotParent}/" e.path || e.path == "/${hotParent}"
          ) null entryList;
        in
        lib.optional (cfg.entries != { } && !cfg.enable)
          "entries are declared but enable = false — set enable or remove the entries (a declared-but-disabled entry silently mounts nothing while consumers may already expect it)."
        ++ lib.optionals (dupPaths != null) [ "duplicate entry path ${dupPaths}" ]
        ++ lib.optionals (badAbs != null) [ "entry ${badAbs.name} path must be absolute and not /" ]
        ++ lib.optionals (underHot != null) [
          "entry ${underHot.name} path must not be under /${hotParent}"
        ];
    in
    {
      options.services.hot-db = {
        enable = lib.mkEnableOption "the Samsung hot-DB tier (mount hot subvolumes at service dataDirs)";
        device = lib.mkOption {
          type = lib.types.str;
          default = "/dev/disk/by-label/tlc";
          description = "Samsung TLC filesystem device (by-label: kernel NVMe enumeration flips).";
        };
        # The toplevel mount the bootstrap creates subvolumes through. Must
        # be an existing mount of `device` with subvolid=5 (toplevel) — on
        # evo-x2 that is /mnt/hot in hardware-configuration.nix (nofail).
        toplevelMount = lib.mkOption {
          type = lib.types.str;
          default = "/mnt/hot";
          description = "Existing toplevel (subvolid=5) mount of `device` the bootstrap oneshot creates subvolumes through.";
        };
        entries = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule entryOpts);
          default = { };
          description = "Hot-DB entries: name → { path, cow, unit }.";
        };
      };

      config = lib.mkMerge [
        {
          # ALWAYS-ON entry validation (fires also for the
          # declared-but-disabled shape).
          assertions = lib.optionals (validationFailures != [ ]) [
            {
              assertion = false;
              message = "services.hot-db: " + lib.concatStringsSep "\n  " validationFailures;
            }
          ];
        }
        # hot-db-bootstrap matches the deploy-restart-audit `-bootstrap`
        # converger pattern but is converged by its OWN mount units: each
        # generated entry mount Wants + Before's it, so any changed mount
        # re-pulls it (indirect unit — the deploy.sh is-enabled loop skips
        # it by construction, which is exactly why it is allowlisted).
        (lib.optionalAttrs (options ? services.deploy-restart-audit) {
          services.deploy-restart-audit.allowUnits = [ "hot-db-bootstrap" ];
        })
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = landmineHits == [ ];
              message = ''
                services.hot-db: BTRFS LANDMINE — a btrbk instance references the
                hot tier. One scheduled snapshot of a nodatacow subvolume
                transparently reverts its extents to CoW (silently destroying the
                tier while every check stays green). Offending config fragments:
                ${lib.concatStringsSep "\n  " (lib.take 3 landmineHits)}
                Remove the reference (or exclude hot/<name> explicitly) before
                enabling entries.
              '';
            }
          ];
          warnings = map (e: ''
            services.hot-db: entry "${e.name}" (${e.path}) declares NO consumer unit —
            nothing enforces the anti-shadow wiring for it; a detached Samsung would
            only surface as a plain-dir shadow on the root fs if something writes
            there. Register `unit` (or `extraUnits`) unless this is deliberate.
          '') unmanaged;

          fileSystems = lib.listToAttrs (
            map (e: {
              name = e.path;
              value = mkFilesystem {
                inherit (cfg) device;
                fsType = "btrfs";
                options = [
                  "subvol=${subvolPath e.name}"
                  "noatime"
                  "nodiscard"
                  "space_cache=v2"
                  # Boot must survive a detached Samsung; the CONSUMER's
                  # RequiresMountsFor is the loud failure (boot-hazard gotcha).
                  "nofail"
                ]
                ++ lib.optional (!e.cow) "nodatacow";
              };
            }) entryList
          );

          # fstab cannot create subvolumes — idempotent bootstrap before the
          # mounts come up (atticd-storage-dir class, ordered pre-mount).
          systemd.services = {
            # fstab cannot create subvolumes — idempotent bootstrap before
            # the mounts come up (atticd-storage-dir class, pre-mount).
            hot-db-bootstrap = {
              description = "Create hot-DB subvolumes and apply nodatacow on the Samsung TLC pool";
              # atticd-storage-dir pattern: each generated entry mount WANTS
              # this unit and is ordered AFTER it, so the subvolumes exist
              # before the mount is attempted. Do NOT use
              # `before = local-fs.target` here — with the unit's default
              # `After=sysinit/basic` (local-fs completes before sysinit in
              # the boot graph) that edge is an ordering cycle, and systemd
              # breaks it by deleting the local-fs job, voiding the whole
              # mount transaction (live VM-test failure).
              wantedBy = map (e: mountUnitName e.path) entryList;
              before = map (e: mountUnitName e.path) entryList;
              # Parens REQUIRED: inside a list, `f x` is TWO elements (the
              # bare lambda trips the unit-name type), not application.
              after = [ (mountUnitName cfg.toplevelMount) ];
              wants = [ (mountUnitName cfg.toplevelMount) ];
              unitConfig = {
                # Samsung detached (nofail toplevel absent) → skip cleanly
                # (Wants, not Requires, so the toplevel's own failure cannot
                # dependency-fail this unit); the generated per-entry mounts
                # then fail, and consumers fail on RequiresMountsFor. Never a
                # dead boot, never a shadow write.
                ConditionPathIsMountPoint = cfg.toplevelMount;
              };
              serviceConfig = lib.mkMerge [
                {
                  Type = "oneshot";
                  User = "root";
                }
                (harden {
                  CapabilityBoundingSet = "CAP_SYS_ADMIN CAP_CHOWN CAP_FOWNER";
                })
                (serviceOneshotDefaults { })
              ];
              path = [
                pkgs.btrfs-progs
                # chattr (nodatacow +C on the fresh subvolume root) lives in
                # e2fsprogs, not btrfs-progs — missing from the unit PATH it
                # exit-127s the bootstrap AFTER the create (VM-test caught).
                pkgs.e2fsprogs
              ];
              script = ''
                pool=${cfg.toplevelMount}
                mkdir -p "$pool/${hotParent}"
                ${lib.concatMapStringsSep "\n" (
                  e:
                  let
                    sv = "$pool/${subvolPath e.name}";
                  in
                  ''
                    if ! btrfs subvolume show ${sv} >/dev/null 2>&1; then
                      btrfs subvolume create ${sv}
                      echo "hot-db: created subvolume ${subvolPath e.name}"
                    fi
                  ''
                  + lib.optionalString (!e.cow) ''
                    # Fresh-subvolume inheritance does NOT carry +C — set it on
                    # every bootstrap (idempotent) so nodatacow holds even after
                    # the subvol was wiped and re-created.
                    chattr +C ${sv}
                  ''
                ) entryList}
              '';
            };
          }
          # Anti-shadow wiring, grouped PER CONSUMER UNIT: two entries may
          # share one unit (one service owning two hot dataDirs), and a
          # name/value pair list here silently keeps only the LAST entry's
          # paths (listToAttrs) — the shared unit would then start
          # dependency-free against the un-wired path's shadow dir, the
          # exact failure class this wiring exists to prevent.
          # zipAttrsWith folds the per-entry {unit = [path];} fragments
          # into unit → [all paths] so EVERY path of the unit is wired.
          // (lib.mapAttrs
            (_: paths: {
              unitConfig = {
                RequiresMountsFor = paths;
                ConditionPathIsMountPoint = lib.mkAfter paths;
              };
            })
            # systemd.services.<name> takes the unit name WITHOUT the
            # .service suffix — keying by the full unit name wires a
            # phantom unit and the real consumer never gets its
            # anti-shadow RequiresMountsFor (VM-test caught: the
            # consumer wrote into the unmounted dataDir).
            (
              lib.zipAttrsWith (_: lib.concatLists) (
                lib.concatMap (
                  e:
                  map (u: { ${lib.removeSuffix ".service" u} = [ e.path ]; }) (
                    lib.remove null ([ e.unit ] ++ e.extraUnits)
                  )
                ) entryList
              )
            )
          );
        })
        # T14: mount-presence collector (fail-closed). Emits the gauges ONLY
        # on a completed run — a dead collector leaves the textfile stale and
        # the anchored Gatus conditions below fail on absence, never
        # phantom-green (node_exporter serves a frozen textfile forever).
        (lib.mkIf cfg.enable {
          # Same rule _signoz-metrics declares (identical settings — tmpfiles
          # `d` lines are idempotent; a DIFFERENT owner here would fight the
          # 1777 sticky shape every other collector relies on). Keeps the
          # collector's ReadWritePaths target existing on hosts without
          # signoz (the 226/NAMESPACE class — namespaces build before
          # ExecStart, a missing path aborts the unit).
          systemd.tmpfiles.rules = [
            "d /var/lib/prometheus-node-exporter/textfile_collectors 1777 nobody nogroup -"
          ];
          systemd.services.hot-db-metrics = {
            description = "Hot-DB tier mount-presence textfile collector";
            serviceConfig = lib.mkMerge [
              {
                Type = "oneshot";
                User = "root";
                ExecStart = pkgs.writeShellScript "hot-db-metrics" ''
                  set -euo pipefail
                  DIR=/var/lib/prometheus-node-exporter/textfile_collectors
                  mkdir -p "$DIR"
                  TMP=$(mktemp "$DIR/hot-db.XXXXXX")
                  chmod 644 "$TMP"
                  trap 'rm -f "$TMP"' EXIT
                  mp() {
                    if mountpoint -q "$1"; then
                      echo 1
                    else
                      echo 0
                    fi
                  }
                  {
                    echo "hot_tier_mounted $(mp ${cfg.toplevelMount})"
                  ${lib.concatMapStringsSep "\n" (
                    e: ''echo 'hot_db_entry_mounted{name="${e.name}"}' "$(mp ${e.path})"''
                  ) entryList}
                    echo "hot_db_scrape_errors 0"
                  } >> "$TMP"
                  mv -f "$TMP" "$DIR/hot-db.prom"
                '';
                ReadWritePaths = [ "/var/lib/prometheus-node-exporter/textfile_collectors" ];
              }
              (harden {
                # mktemp + rename-over-foreign-owned in the sticky textfile
                # dir (mail-relay collector doctrine, 2026-09-02..06).
                CapabilityBoundingSet = "CAP_FOWNER";
              })
              (serviceOneshotDefaults { })
            ];
            path = [ pkgs.util-linux ];
          };
          systemd.timers.hot-db-metrics = {
            description = "Hot-DB tier mount-presence collector (5 min)";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "2min";
              OnUnitActiveSec = "5min";
            };
          };
        })
        # T14: one anchored Gatus check per entry + the toplevel. Mounted=1 is
        # the green state; 0, absent metric, or a dead collector all fail
        # (the != 0 + existence pair — asserted-value checks on a metrics
        # body MUST be newline-anchored, the 2026-08-22 phantom-green class).
        # Alert descriptions NEVER embed the labeled metric — gatus 5.36
        # panics at startup on quotes in descriptions (2026-09-29 incident).
        (lib.mkIf (cfg.enable && (options ? services.gatus-config)) {
          services.gatus-config.extraEndpoints =
            let
              # `or` guards the minimal-VM shape (no exporters module).
              nodePort = config.services.prometheus.exporters.node.port or 9100;
              mkMountCheck =
                name: metric: desc:
                mkHttpCheck {
                  inherit name;
                  group = "Storage";
                  url = "http://127.0.0.1:${toString nodePort}/metrics";
                  interval = "60s";
                  conditions = [
                    "[BODY] != pat(*${metric} 0\n*)"
                    "[BODY] == pat(*\n${metric} *)"
                  ];
                  alerts = discordAlert desc;
                };
            in
            [
              (mkMountCheck "Hot Tier Mounted" "hot_tier_mounted" "Samsung hot tier toplevel is not mounted — crush session DBs fall back to the QLC root and every hot-db entry consumer is down or condition-skipped. Check: findmnt for the toplevel mount; systemctl status hot-db-metrics; journalctl -b -u hot-db-metrics. Runbook: docs/services/hot-db.md.")
            ]
            ++ map (
              e:
              mkMountCheck "Hot-DB ${e.name} Mounted" "hot_db_entry_mounted{name=\"${e.name}\"}" "Hot-DB entry ${e.name} is not mounted at its dataDir — the Samsung subvol is detached or a migration window left the entry undeployed. Check: systemctl status hot-db-metrics; findmnt for the entry path; runbook docs/services/hot-db.md."
            ) entryList;
        })
      ];
    };
}
