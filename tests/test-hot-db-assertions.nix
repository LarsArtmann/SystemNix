# Negative test for the hot-db module's eval-time guards (pure eval, no VM).
#
# `nix eval …toplevel.drvPath` never forces assertions, so THIS is the CI
# surface that proves each guard fires on its incident shape. The guards
# live in config.assertions (enforced by `nix flake check` and every
# toplevel build), asserted here via the same forced `.assertions` list:
#
#   1. btrbk referencing an entry path FAILS (the snapshot landmine).
#   2. btrbk referencing the `hot/` subvol parent FAILS (same class).
#   3. A clean btrbk config + wired consumer PASSES (no false positive).
#   4. entries declared with enable=false FAIL.
#   5. Duplicate entry paths FAIL.
#   6. An entry with no consumer unit emits the unmanaged WARNING.
#
# The no-false-positives half against the REAL config is trivial here — the
# module ships with zero entries on evo-x2 until the soak gate lifts — but
# `nix flake check` still evaluates the real (dormant) module.
{
  pkgs,
  inputs,
  system,
}: let
  lib = inputs.nixpkgs.lib;

  hotDb = (import ../modules/nixos/services/hot-db.nix).flake.nixosModules.hot-db;

  base = extraModules:
    [
      hotDb
      {
        services.hot-db = {
          enable = true;
          entries.mydb = {
            path = "/var/lib/mydb";
            cow = false;
            unit = "mydb.service";
          };
        };
      }
    ]
    ++ extraModules;

  evalConfig = extraModules:
    (lib.nixosSystem {
      inherit system;
      modules = base extraModules;
    }).config;

  # Forces only the assertions list (mirrors nix flake check semantics).
  assertions = extraModules: (evalConfig extraModules).assertions;

  hotDbFailures = extraModules:
    builtins.filter (a: !a.assertion && lib.hasInfix "services.hot-db" a.message) (
      assertions extraModules
    );

  warnings = extraModules: (evalConfig extraModules).warnings;

  btrbkInstance = cfg: [
    {
      services.btrbk.instances."evil" = {
        onCalendar = "daily";
        settings = cfg;
      };
    }
  ];

  cases = [
    {
      name = "btrbk-entry-path-landmine-not-caught";
      pass =
        hotDbFailures (btrbkInstance {
          snapshot_preserve = "3d 1w";
          volume."/mnt/pool" = {
            snapshot_dir = "/mnt/pool/.snapshots";
            subvolume."hot/mydb" = {};
          };
        })
        != [];
    }
    {
      name = "btrbk-entry-path-reference-not-caught";
      pass =
        hotDbFailures (btrbkInstance {
          volume."/mnt/btrfs-root".subvolume."@".target = "/var/lib/mydb";
        })
        != [];
    }
    {
      name = "clean-btrbk-false-positive";
      pass =
        hotDbFailures (btrbkInstance {
          volume."/data" = {
            snapshot_dir = "/data/.snapshots";
            subvolume."." = {};
          };
        })
        == [];
    }
    {
      name = "enable-false-with-entries-not-caught";
      pass =
        hotDbFailures [
          {
            services.hot-db.enable = lib.mkForce false;
          }
        ]
        != [];
    }
    {
      name = "duplicate-paths-not-caught";
      pass =
        hotDbFailures [
          {
            services.hot-db.entries.mydb2.path = lib.mkForce "/var/lib/mydb";
          }
        ]
        != [];
    }
    {
      name = "unmanaged-entry-warning-not-emitted";
      pass = let
        w = warnings [
          {
            services.hot-db.entries.orphan = {
              path = "/var/lib/orphan";
              unit = lib.mkForce null;
            };
          }
        ];
      in
        lib.any (lib.hasInfix "orphan") w;
    }
    {
      name = "happy-path-passes-and-wires-consumer";
      pass = let
        # cow=true variant (the base fixture is cow=false) so the
        # no-nodatacow expectation is meaningful; wiring assertions are
        # cow-independent and checked on the same eval.
        cfg = evalConfig [
          {
            services.hot-db.entries.mydb.cow = lib.mkForce true;
          }
        ];
      in
        hotDbFailures []
        == []
        && cfg.systemd.services."mydb.service".unitConfig.RequiresMountsFor == ["/var/lib/mydb"]
        && cfg.systemd.services."mydb.service".unitConfig.ConditionPathIsMountPoint == "/var/lib/mydb"
        && cfg.fileSystems ? "/var/lib/mydb"
        && cfg.fileSystems."/var/lib/mydb".options != []
        && cfg.systemd.services.hot-db-bootstrap != {}
        && !(builtins.elem "nodatacow" cfg.fileSystems."/var/lib/mydb".options);
    }
    {
      name = "cow-false-emits-nodatacow";
      pass = builtins.elem "nodatacow" ((evalConfig []).fileSystems."/var/lib/mydb".options);
    }
  ];

  failures = builtins.filter (c: !c.pass) cases;
  report = lib.concatStringsSep "\n" (map (c: "FAIL: ${c.name}") failures);
in
  if failures == []
  then pkgs.runCommand "hot-db-assertions-negative-test" {} "touch $out"
  else throw "hot-db-assertions negative test failures:\n${report}"
