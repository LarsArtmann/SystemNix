# Runbook: docs/services/quotaboard.md
# quotaboard: LAN exposure of the AI coding-plan quota dashboard
# (github:LarsArtmann/quotaboard): the home.lan vHost, the Gatus checks and
# the PapDashboard tile.
#
# The SERVER is deliberately NOT defined here. It stays the upstream
# home-manager unit (quotaboard.homeModules.quotaboard, consumed in
# platforms/nixos/desktop/quickshell.nix) and this module reads ITS enable
# switch: one switch owns server and exposure, so a vHost without a backend
# cannot be declared. The unit is ALWAYS-ON, not session-scoped (the
# lifecycle override lives next to the consumer, in quickshell.nix). That is
# why these checks page unconditionally instead of riding a session-aware
# meta check like emeet-pixyd's.
{
  inputs,
  ...
}:
{
  flake.nixosModules.quotaboard =
    {
      config,
      lib,
      options,
      ...
    }:
    let
      inherit (import ../../../lib/default.nix lib) ports;
      inherit (config.networking) domain;
      primaryUser = config.users.primaryUser;
      subdomain = "quotaboard";

      # The primary user's home-manager config on hosts that run one
      # (pastebot-parity-audit reads it the same way). Walked attr by attr:
      # `a.b.c or default` only guards the LAST selector.
      primaryHome =
        if options ? home-manager && config.home-manager.users ? ${primaryUser} then
          config.home-manager.users.${primaryUser}
        else
          { };
      serverEnabled = lib.attrByPath [ "services" "quotaboard" "enable" ] false primaryHome;
      port = ports.quotaboard;
    in
    {
      config = lib.mkIf serverEnabled (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = config.users.users.${primaryUser}.linger or null == true;
                message = ''
                  quotaboard: the server is an ALWAYS-ON user unit (quickshell.nix overrides the
                  upstream graphical-session binding because this vHost fronts it), so its user
                  manager must start at boot, but users.users.${primaryUser}.linger is not true.
                  Without lingering the vHost 502s at the SDDM greeter and both Gatus checks page on
                  every logout. Fix: users.users.${primaryUser}.linger = true
                  (platforms/nixos/system/configuration.nix).'';
              }
            ];

            services.integration = lib.optionalAttrs (options ? services.integration) {
              quotaboard = {
                inherit port;
                inherit subdomain;
                # Layer 2: the dashboard has no auth of its own (upstream ships
                # it as a loopback single-user tool). External clients pass
                # oauth2-proxy, LAN bypasses.
                vHost.layer = "protected";
                checks = [
                  {
                    name = "Quotaboard ready";
                    group = "AI";
                    path = "/health/ready";
                    interval = "30s";
                    conditions = [
                      "[STATUS] == 200"
                      "[RESPONSE_TIME] < 1000"
                      "[BODY] == pat(*\"up\"*)"
                    ];
                    alert = "Quotaboard down: ${subdomain}.${domain} unreachable and the DMS bar widget has no server to poll. The server is an always-on USER unit of the primary user: systemctl --user status quotaboard, journalctl --user -u quotaboard -n 50. A refusal right after a logout means the unit lost its always-on binding (quickshell.nix keeps WantedBy=default.target).";
                  }
                  {
                    name = "Quotaboard quotas API";
                    group = "AI";
                    path = "/api/quotas";
                    interval = "60s";
                    conditions = [
                      "[STATUS] == 200"
                      "[RESPONSE_TIME] < 2000"
                      # Functional, not just alive: the JSON envelope rendered
                      # (the contract route of the DMS widget).
                      "[BODY] == pat(*\"generatedAt\"*)"
                    ];
                    alert = "Quotaboard JSON API broken: /api/quotas no longer returns its envelope, so the dashboard and the bar widget cannot show quotas while the process may still be up. Check: journalctl --user -u quotaboard -n 50";
                  }
                ];
                homepage = {
                  name = "Quotaboard";
                  group = "AI";
                  description = "AI coding-plan quota dashboard (Z.ai GLM + Synthetic)";
                  icon = "quotaboard.svg";
                };
                # Deliberately NOT monitored=true: the server is a USER unit.
                # system-health's unit probes read the system bus and never
                # see it (emeet-pixyd precedent). A dead or crash-looping
                # server trips the two checks above instead.
                monitored = false;
              };
            };
          }
          # The product's own mark (static/favicon.svg, the tab icon the app
          # serves), copied from the SAME locked source rev the binary builds
          # from: tile logo and server identity cannot drift, and the tile
          # never depends on the linked service being up (timesheets
          # precedent). The attribute name IS the served file name and must
          # match the tile's icon above.
          (lib.optionalAttrs (options ? services.papdashboard) {
            services.papdashboard.extraIcons."quotaboard.svg" = inputs.quotaboard + "/static/favicon.svg";
          })
        ]
      );
    };
}
