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
  # The house module wraps the input package in overrideAttrs (git-in-sandbox
  # fix, 2026-10-02), so identity equality against fakeTq can never hold —
  # assertions must tolerate one wrapper layer around the input package.
  fakeTqName = fakeTq.name;

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
        # co-import: the module declares a services.integration entry (mkIf-wrapped options?-guard caveat, 2026-09-15)
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        # House sops.nix declares the real template under svcEnabled
        # "tq-agent-pool" (evo-x2 scope); minimal stand-in so the module's
        # EnvironmentFile reference evaluates in this bare eval.
        { sops.templates."tq-agent-pool-env" = { }; }
        # The house pool unit embeds pkgs.maintenance-entry-gate in
        # ExecStartPre (overlays/shared.nix provides it in the REAL host
        # eval); stand in a stub so the
        # pool-entry-gate-execstartpre-preserved leg can assert the gate's
        # presence without dragging the whole shared overlay into this
        # hermetic harness.
        {
          nixpkgs.overlays = [
            (_final: prev: {
              maintenance-entry-gate = prev.writeShellScriptBin "maintenance-entry-gate" "exit 0";
            })
          ];
        }
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
      # Verify gate + agent go commands inherit the pool env, NOT the fish
      # session: without jsonv2 every Go task on a jsonv2 repo dead-letters
      # (tq facts 2903/2987/2996-3001).
      name = "pool-carries-goexperiment-jsonv2";
      pass = builtins.elem "GOEXPERIMENT=jsonv2" (pool.serviceConfig.Environment or [ ]);
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
      # Boot-transaction bound (2026-10-19; reshaped 2026-10-26): the PSI
      # entry-gate REFUSE loop (upstream Restart=on-failure, RestartSec=30s)
      # kept boot 0 (2026-10-18) open ~2min while the gate refired ×5 INSIDE
      # multi-user.target's wait set. The unit must live PAST the boot
      # transaction — now via late-applications membership (the direct
      # after=multi-user edge was the gitea-runner ordering-cycle class,
      # 2026-10-26; enforced graph-wide by ordering-cycle-audit.nix).
      name = "pool-post-gate-late-applications";
      pass = builtins.elem "late-applications.target" (pool.wantedBy or [ ]);
    }
    {
      # The backward edge must stay GONE: after=multi-user on a
      # multi-user-reachable unit re-arms the deleted-start-job cycle class.
      name = "pool-no-multi-user-after-edge";
      pass = !builtins.elem "multi-user.target" (pool.after or [ ]);
    }
    {
      # The bound MOVES the refuse-and-refire churn, it does not remove the
      # storm gate: a refusal must keep FAILING the start attempt
      # (ExecStartPre, exit 1) so the upstream Restart= contract refires
      # until calm — the freeze-19/20/21 protection. An ExecCondition or a
      # deleted gate would silently skip storm entries instead.
      name = "pool-entry-gate-execstartpre-preserved";
      pass = builtins.any (lib.hasInfix "maintenance-entry-gate") (
        pool.serviceConfig.ExecStartPre or [ ]
      );
    }
    {
      # Suffix match, not full-string equality: the module's ExecStart embeds
      # the overrideAttrs-wrapped package path (2026-10-02), so only the
      # "/bin/tq serve --addr 127.0.0.1:<port>" tail is stable — which still
      # pins the binary basename, every flag, the loopback addr, and the port.
      name = "serve-exact-execstart-loopback-port";
      pass = lib.hasSuffix "/bin/tq serve --addr 127.0.0.1:${toString ports.tq}" serve.serviceConfig.ExecStart;
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
      # Name match, not identity: overrideAttrs (2026-10-02) changes the
      # derivation identity, but the name pins it to the pool's tq CLI — the
      # guarded regression is the CLI vanishing from systemPackages entirely.
      name = "tq-cli-on-system-path";
      pass = builtins.any (p: p == fakeTq || p.name == fakeTqName) on.environment.systemPackages;
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
