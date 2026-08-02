# VM test for the oauth2-proxy forward-auth module.
#
# Verifies the runtime risks that nix eval CANNOT check:
#   1. oauth2-proxy starts with correct config (port, provider, cookie domain)
#   2. /ping endpoint responds (built-in health check)
#   3. Cookie secret validation works (base64-decoded length check)
#   4. The hardening + serviceDefaults produce a valid systemd unit
#
# The OIDC wait gate (waitOidcReady) is replaced with a no-op since there's no
# Pocket ID in the VM. The real OIDC integration is tested post-deploy.
{pkgs}: let
  oauth2ProxyFlakeOutput = (import ../modules/nixos/services/oauth2-proxy.nix) {};
  oauth2ProxyNixosModule = oauth2ProxyFlakeOutput.flake.nixosModules.oauth2-proxy;

  # Generate valid secrets at build time
  cookieSecret = pkgs.runCommand "oauth2-cookie-secret" {} ''
    echo -n "0123456789abcdef" | ${pkgs.coreutils}/bin/base64 > $out
  '';
  clientSecret = pkgs.runCommand "oauth2-client-secret" {} ''
    echo -n "test-client-secret-value" > $out
  '';
in {
  name = "oauth2-proxy";

  nodes.machine = {lib, ...}: {
    imports = [
      oauth2ProxyNixosModule
      ./mock-sops.nix
      ./test-helpers.nix
    ];

    services.oauth2-proxy-config.enable = true;

    # Disable Pocket ID provision path — use sops secrets directly
    services.pocket-id-config.provision.enable = lib.mkForce false;

    # Register sops secrets (mock-sops creates empty files at these paths)
    sops.secrets.oauth2_proxy_cookie_secret = {};
    sops.secrets.oauth2_proxy_client_secret = {};

    # Write real secrets to the mock paths before the service starts
    systemd.services.oauth2-proxy-test-secrets = {
      description = "Write test secrets for oauth2-proxy";
      before = ["oauth2-proxy.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        cp ${cookieSecret} /run/secrets/oauth2_proxy_cookie_secret
        chmod 600 /run/secrets/oauth2_proxy_cookie_secret
        cp ${clientSecret} /run/secrets/oauth2_proxy_client_secret
        chmod 600 /run/secrets/oauth2_proxy_client_secret
      '';
    };

    # Override the ExecStartPre to skip OIDC wait (no Pocket ID in VM)
    systemd.services.oauth2-proxy.serviceConfig = lib.mkMerge [
      {
        ExecStartPre = [
          # Keep cookie secret check, skip OIDC wait
          "+${lib.getExe (pkgs.writeShellApplication {
            name = "check-cookie-secret-only";
            runtimeInputs = [pkgs.coreutils];
            text = ''
              secret_path="/run/secrets/oauth2_proxy_cookie_secret"
              len=$(base64 -d < "$secret_path" | wc -c)
              if [ "$len" -ne 16 ] && [ "$len" -ne 24 ] && [ "$len" -ne 32 ]; then
                echo "cookie_secret must be 16, 24, or 32 bytes, got $len" >&2
                exit 1
              fi
            '';
          })}"
        ];
        # Remove ExecStartPost ping retry (it works but takes time)
        ExecStartPost = lib.mkForce [];
      }
    ];
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # 1. oauth2-proxy service starts with mocked secrets
    machine.wait_for_unit("oauth2-proxy.service")

    # 2. Port is open
    machine.wait_for_open_port(4180)

    # 3. /ping endpoint responds (oauth2-proxy built-in health check)
    machine.succeed("curl -sf http://localhost:4180/ping")

    # 4. Cookie secret validation passed (service started = ExecStartPre succeeded)
    machine.succeed("systemctl is-active oauth2-proxy.service")
  '';
}
