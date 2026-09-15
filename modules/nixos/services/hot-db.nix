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
      pkgs,
      lib,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        ioTier
        mkFilesystem
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
      mountUnitName = path: builtins.replaceStrings [ "/" ] [ "-" ] path + ".mount";

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

      landmineHits = lib.filter (
        s:
        (builtins.match "(|.*[\" ])${hotParent}/.*" s) != null
        || builtins.any (e: lib.hasInfix e.path s) entryList
      ) btrbkStrings;

      validated =
        let
          dupPaths = lib.findFirst (p: lib.length (builtins.filter (e: e.path == p) entryList) > 1) null (
            map (e: e.path) entryList
          );
          badAbs = lib.findFirst (e: !lib.hasPrefix "/" e.path || e.path == "/") null entryList;
          underHot = lib.findFirst (
            e: lib.hasPrefix "/${hotParent}/" e.path || e.path == "/${hotParent}"
          ) null entryList;
        in
        if cfg.entries != { } && !cfg.enable then
          throw "services.hot-db: entries are declared but enable = false — set enable or remove the entries (a declared-but-disabled entry silently mounts nothing while consumers may already expect it)."
        else if dupPaths != null then
          throw "services.hot-db: duplicate entry path ${dupPaths}"
        else if badAbs != null then
          throw "services.hot-db: entry ${badAbs.name} path must be absolute and not /"
        else if underHot != null then
          throw "services.hot-db: entry ${underHot.name} path must not be under /${hotParent}"
        else
          null;
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

      config = lib.mkIf cfg.enable {
        # Force the validation inside the config (throws at eval on bad input).
        system.build.hot-db-validated = validated;

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
              device = cfg.device;
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
            wantedBy = [ "local-fs.target" ];
            before = [ "local-fs.target" ] ++ map (e: mountUnitName e.path) entryList;
            unitConfig = {
              # Samsung detached (nofail toplevel absent) → skip cleanly; the
              # generated per-entry mounts then fail, and consumers fail on
              # RequiresMountsFor. Never a dead boot, never a shadow write.
              ConditionPathIsMountPoint = cfg.toplevelMount;
              RequiresMountsFor = [ cfg.toplevelMount ];
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
            path = [ pkgs.btrfs-progs ];
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
        // lib.listToAttrs (
          lib.flatten (
            map (
              e:
              map (u: {
                name = u;
                value = {
                  unitConfig = {
                    RequiresMountsFor = [ e.path ];
                    ConditionPathIsMountPoint = lib.mkAfter e.path;
                  };
                };
              }) (lib.remove null ([ e.unit ] ++ e.extraUnits))
            ) entryList
          )
        );
      };
    };
}
