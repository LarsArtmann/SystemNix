# House-layer wiring test for the tq-agent-pool module (pure eval, no VM).
#
# The UPSTREAM module (deploy/nixos/tq-agent-pool.nix) has its own
# checks.module-eval in the go-taskqueue flake covering option rendering and
# drain invariants. THIS test pins the SystemNix overlay: primary-user pool,
# pool journal on the HDD pool, sops EnvironmentFile bridge, the storage-dir
# mount gate, bootstrap shape, CLI on PATH, and the enable gate.
#
# Pure-eval class (sops-key-audit pattern): assertions are forced when the
# flake evaluates this check, so `nix flake check --no-build` runs them — and
# the output derivation embeds ONLY booleans/names, never unit strings with
# package store-path context, so building the check never builds the Go
# package. The fake package (writeShellScriptBin "tq") satisfies
# lib.getExe' … "tq" shape cheaply.
{
  pkgs,
  inputs,
  system,
}:
let
  lib = inputs.nixpkgs.lib;
  house = ((import ../modules/nixos/services/tq-agent-pool.nix) { }).flake.nixosModules.tq-agent-pool;
  inherit ((import ../lib/default.nix lib)) ports;

  fakeTq = pkgs.writeShellScriptBin "tq" "exit 0";

  eval =
    enableFlag:
    (inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs.inputs.go-taskqueue = {
        # House module pulls the package from inputs — fake keeps this eval
        # hermetic while the REAL upstream module provides the option set.
        packages.${system}.default = fakeTq;
        nixosModules.default = inputs.go-taskqueue.nixosModules.default;
      };
      modules = [
        inputs.sops-nix.nixosModules.sops
        inputs.go-taskqueue.nixosModules.default
        house
        # House sops.nix declares the real template under svcEnabled
        # "tq-agent-pool" (evo-x2 scope); minimal stand-in so the module's
        # EnvironmentFile reference evaluates in this bare eval.
        { sops.templates."tq-agent-pool-env" = { }; }
        { services.tq-agent-pool.enable = enableFlag; }
      ];
    }).config;

  on = eval true;
  off = eval false;

  pool = on.systemd.services.tq-agent-pool;
  serve = on.systemd.services.tq-serve;
  storage = on.systemd.services.tq-storage-dir;
  bootstrap = on.systemd.services.tq-bootstrap;

  firstToken = str: builtins.head (lib.splitString " " str);

  cases = [
    {
      name = "pool-binary-is-package-bin-tq";
      pass = lib.hasSuffix "/bin/tq" (firstToken pool.serviceConfig.ExecStart);
    }
    {
      name = "pool-envfile-is-dedicated-sops-template";
      pass = pool.serviceConfig.EnvironmentFile == [ on.sops.templates."tq-agent-pool-env".path ];
    }
    {
      name = "pool-resource-ceilings";
      pass =
        pool.serviceConfig.MemoryMax or null == "8G" && pool.serviceConfig.CPUQuota or null == "400%";
    }
    {
      name = "pool-runs-as-primary-user";
      pass = pool.serviceConfig.User == "lars" && pool.serviceConfig.Group == "users";
    }
    {
      name = "pool-ordered-after-storage-dir";
      pass = builtins.elem "tq-storage-dir.service" (pool.after or [ ]);
    }
    {
      name = "serve-exact-execstart-loopback-port";
      pass =
        serve.serviceConfig.ExecStart == "${fakeTq}/bin/tq serve --addr 127.0.0.1:${toString ports.tq}";
    }
    {
      name = "serve-writable-journal-dir";
      pass = builtins.elem "/mnt/pool/services/tq" (serve.serviceConfig.ReadWritePaths or [ ]);
    }
    {
      name = "storage-dir-mount-gated";
      pass = storage.unitConfig.RequiresMountsFor == [ "/mnt/pool/services/tq" ];
    }
    {
      # Regression guard for the 2026-09-08 tolerance fix: bootstrap is a
      # purely local oneshot — network-online must NOT come back.
      name = "bootstrap-after-storage-dir-only-no-network-online";
      pass = bootstrap.after == [ "tq-storage-dir.service" ];
    }
    {
      name = "bootstrap-runs-as-primary-user-no-run";
      pass =
        bootstrap.serviceConfig.User == "lars"
        && lib.hasInfix "--no-run" bootstrap.serviceConfig.ExecStart
        && lib.hasSuffix "/bin/tq" (firstToken bootstrap.serviceConfig.ExecStart);
    }
    {
      name = "tq-cli-on-system-path";
      pass = builtins.any (p: p == fakeTq) on.environment.systemPackages;
    }
    {
      name = "disabled-yields-no-units";
      pass = !builtins.hasAttr "tq-agent-pool" off.systemd.services;
    }
  ];

  broken = map (c: c.name) (builtins.filter (c: !c.pass) cases);
in
if broken == [ ] then
  pkgs.runCommand "tq-agent-pool-house-wiring-test" { } "touch $out"
else
  throw ''
    tq-agent-pool house wiring regression: ${toString broken}
    The SystemNix overlay invariants (primary-user pool, pool journal,
    sops bridge, mount gates, bootstrap shape) must hold — see
    tests/test-tq-agent-pool.nix and modules/nixos/services/tq-agent-pool.nix.
  ''
