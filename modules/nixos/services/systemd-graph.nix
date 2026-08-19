# systemd-graph: live web UI for the systemd unit dependency graph.
# Scoped to system units only (skips user bus if unavailable). D-Bus driven,
# serves a React SPA + JSON/SSE API. Zero state — restart is safe.
#
# Review tool — exposed on LAN only (no auth). Disabled by default.
_: {
  flake.nixosModules.systemd-graph =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceDefaults
        onFailure
        ioTier
        ports
        ;

      cfg = config.services.systemd-graph;
      # systemd-graph talks to the SYSTEM D-Bus only (user bus is best-effort
      # inside the binary; we leave the user-bus path alone to avoid
      # `XDG_RUNTIME_DIR` plumbing inside a hardened DynamicUser unit).
      # Bind 127.0.0.1 — never expose directly; Caddy proxies.
    in
    {
      options.services.systemd-graph = {
        enable = lib.mkEnableOption "systemd-graph (live D-Bus-driven systemd dependency graph web UI)";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.systemd-graph;
          defaultText = lib.literalExpression "pkgs.systemd-graph";
          description = "The systemd-graph package to use.";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = ports.systemd-graph;
          defaultText = lib.literalExpression "ports.systemd-graph";
          description = "Localhost port systemd-graph binds. Caddy proxies this.";
        };
        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Address to bind. Loopback only — never expose directly.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.systemd-graph = {
          description = "systemd-graph — live systemd dependency graph web UI";
          wantedBy = [ "multi-user.target" ];
          after = [ "dbus.service" "network-online.target" ];
          wants = [ "dbus.service" "network-online.target" ];
          inherit onFailure;
          restartTriggers = [ cfg.package ];

          startLimitBurst = 5;
          startLimitIntervalSec = 300;

          # systemd-graph has its own internal graph store; nothing to persist.
          # No StateDirectory needed. DynamicUser is safe — it only opens a
          # D-Bus system bus connection and listens on TCP.
          serviceConfig = lib.mkMerge [
            {
              ExecStart = "${lib.getExe cfg.package} -addr ${cfg.listenAddress}:${toString cfg.port}";
              DynamicUser = true;
              # The binary uses systemd1.ListUnits / Subscribe via the godbus
              # library. Connecting to the system bus as a DynamicUser requires
              # reading /run/dbus/system_bus_socket — that's the default for any
              # user, no extra group needed.
              RestartSec = "5s";
            }
            (harden { MemoryMax = "128M"; })
            (serviceDefaults { })
            ioTier.background
          ];
        };
      };
    };
}
