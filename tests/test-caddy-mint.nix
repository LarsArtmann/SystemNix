# VM test that RUNS the dnsblockd-cert-mint unit end-to-end (defect d1,
# status report 2026-09-30: the mint script shipped eval-verified only —
# its bare `openssl`/`install`/`mktemp` calls were one ambient-PATH
# regression away from failing the fail-closed chain and taking the whole
# home.lan web stack down at boot).
#
# Proves at runtime, against the REAL caddy module:
#   1. dnsblockd-cert-mint.service succeeds (absolute-path script, sops CA
#      fixture installed over the mock-sops placeholders)
#   2. caddy.service starts — the fail-closed After/Requires chain holds
#   3. The minted leaf: caddy:caddy ownership, 0444 cert / 0400 key
#   4. SANs cover BOTH zones (home.lan + *.home.lan + cloud + *.cloud)
#   5. The leaf verifies against the dnsblockd CA and matches its key
#   6. A real TLS handshake through caddy verifies against that CA for
#      BOTH a home.lan and a cloud.test vhost (dual-zone, one cert)
#
# Stub doctrine: test-integration.nix's proven option-stub set (the real
# caddy module reads sibling options unguarded — cheaper than importing
# the full sibling closure), mock-sops for the secret paths.
{
  pkgs,
  inputs,
}:
let
  lib = inputs.nixpkgs.lib;

  # Wrapper modules are flake-parts modules — `_: { flake.nixosModules.X = …; }`
  # functions; a few are plain attrsets or take inputs. Handle all shapes.
  mod =
    file: name:
    let
      imported = import ../modules/nixos/services/${file};
      wrapper =
        if !builtins.isFunction imported then
          imported
        else if (builtins.functionArgs imported) ? inputs then
          imported { inherit inputs; }
        else
          imported { };
    in
    wrapper.flake.nixosModules.${name};

  # Throwaway CA standing in for the sops'd dnsblockd CA. Generated at
  # BUILD time; the fixture unit below installs it over the mock-sops
  # placeholder files before the mint unit runs.
  caFixture = pkgs.runCommand "dnsblockd-test-ca" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    ${pkgs.openssl.bin}/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
      -keyout ca.key -out ca.crt -subj "/CN=Test dnsblockd CA"
    mkdir -p $out
    ${pkgs.coreutils}/bin/install -m 0444 ca.crt $out/dnsblockd_ca_cert
    ${pkgs.coreutils}/bin/install -m 0400 ca.key $out/dnsblockd_ca_key
  '';

  testDomain = "cloud.test";

  # Minimal stubs for options the real caddy module reads unconditionally
  # from siblings that are not part of this test's import set
  # (test-integration.nix precedent).
  stubs = {
    networking.local.subnet = lib.mkOption {
      type = lib.types.str;
      default = "192.168.1.0/24";
    };
    # The split-horizon option (normally from platforms/nixos/system/
    # local-network.nix). Declaring it here satisfies caddy.nix's
    # options-guard; the node sets it to enable mint mode.
    networking.local.cloudDomain = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    services.oauth2-proxy-config.port = lib.mkOption {
      type = lib.types.port;
      default = 4180;
    };
    services.dns-blocker.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    services.dns-blocker.blockInterface = lib.mkOption {
      type = lib.types.str;
      default = "lo";
    };
  };

  # Port-shaped options the unconditional caddy base vHosts force.
  portStubs = {
    services.signoz.settings.queryService.port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };
    services.signoz.settings.cadvisorPort = lib.mkOption {
      type = lib.types.port;
      default = 8087;
    };
    services.twenty.port = lib.mkOption {
      type = lib.types.port;
      default = 8081;
    };
    services.manifest.port = lib.mkOption {
      type = lib.types.port;
      default = 8083;
    };
    services.openseo.port = lib.mkOption {
      type = lib.types.port;
      default = 8084;
    };
    services.crush-daily.port = lib.mkOption {
      type = lib.types.port;
      default = 8085;
    };
    services.dns-blocker.statsPort = lib.mkOption {
      type = lib.types.port;
      default = 8086;
    };
    services.dns-blocker.blockIP = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
    };
  };

  enableStubs = names: {
    services = lib.listToAttrs (
      map (
        n:
        lib.nameValuePair n {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        }
      ) names
    );
  };

  siblingEnableStubs = enableStubs [
    "ai-stack"
    "attic-config"
    "bank-sync"
    "buildcache"
    "browser-history"
    "crush-daily"
    "cv-server"
    "discordsync"
    "fastflowlm"
    "file-and-image-renamer"
    "google-sync"
    "hermes"
    "inboxclean"
    "llama-rag"
    "mail-relay"
    "manifest"
    "monitor365"
    "monitor365-server"
    "overview"
    "pool-recovery"
    "pool-smart-metrics"
    "projects-management-automation"
    "signoz"
    "systemd-graph"
    "systemd-timer-monitor"
    "tq-agent-pool"
    "twenty"
    "voice-agents"
  ];
in
{
  name = "caddy-mint";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [
        (mod "caddy.nix" "caddy")
        (mod "pocket-id.nix" "pocket-id")
        # caddy.nix declares an mkIf-wrapped services.integration entry —
        # an mkIf definition at an undeclared path is still collected
        # (test-miniflux precedent: co-import the registry module).
        (mod "integration.nix" "integration")
        { options = lib.recursiveUpdate (lib.recursiveUpdate stubs portStubs) siblingEnableStubs; }
        ./mock-sops.nix
      ];

      networking.domain = "home.lan";
      networking.local.cloudDomain = testDomain;
      services.caddy.enable = true;

      environment.systemPackages = [ pkgs.openssl ];

      # Path references the caddy module evaluates (mint CA + static-cert
      # fallback paths); mock-sops materializes empty files at these paths.
      sops.secrets.dnsblockd_server_cert = { };
      sops.secrets.dnsblockd_server_key = { };
      sops.secrets.dnsblockd_ca_cert = { };
      sops.secrets.dnsblockd_ca_key = { };

      systemd.services.mint-test-ca-fixture = {
        description = "Install real test CA material over the mock-sops placeholders";
        wantedBy = [ "multi-user.target" ];
        before = [ "dnsblockd-cert-mint.service" ];
        after = [ "systemd-tmpfiles-setup.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.coreutils}/bin/install -m 0444 ${caFixture}/dnsblockd_ca_cert /run/secrets/dnsblockd_ca_cert
          ${pkgs.coreutils}/bin/install -m 0400 ${caFixture}/dnsblockd_ca_key /run/secrets/dnsblockd_ca_key
        '';
      };
    };

  testScript = ''
    machine.start()
    machine.wait_for_unit("mint-test-ca-fixture.service")
    machine.wait_for_unit("dnsblockd-cert-mint.service")
    # The fail-closed chain: caddy only reaches active when the mint
    # produced both files (After + Wants on the mint unit).
    machine.wait_for_unit("caddy.service")

    # 1. Ownership and modes of the minted material
    owner = machine.succeed("stat -c %U:%G /run/dnsblockd-certs/server.crt").strip()
    assert owner == "caddy:caddy", f"minted cert owned by {owner}, expected caddy:caddy"
    cert_mode = machine.succeed("stat -c %a /run/dnsblockd-certs/server.crt").strip()
    assert cert_mode == "444", f"minted cert mode {cert_mode}, expected 444"
    key_mode = machine.succeed("stat -c %a /run/dnsblockd-certs/server.key").strip()
    assert key_mode == "400", f"minted key mode {key_mode}, expected 400"

    # 2. Dual-zone SANs on ONE leaf
    san = machine.succeed("openssl x509 -in /run/dnsblockd-certs/server.crt -noout -ext subjectAltName")
    for name in ("home.lan", "*.home.lan", "${testDomain}", "*.${testDomain}"):
        assert f"DNS:{name}" in san, f"{name} missing from SANs: {san}"

    # 3. The leaf chains to the dnsblockd CA (client trust story unchanged)
    machine.succeed("openssl verify -CAfile /run/secrets/dnsblockd_ca_cert /run/dnsblockd-certs/server.crt")

    # 4. Cert and key are a pair
    cert_pub = machine.succeed("openssl x509 -in /run/dnsblockd-certs/server.crt -noout -pubkey | openssl sha256").strip()
    key_pub = machine.succeed("openssl pkey -in /run/dnsblockd-certs/server.key -pubout | openssl sha256").strip()
    assert cert_pub == key_pub, "minted cert public key does not match minted key"

    # 5. Real handshakes through caddy, verified against the CA, on BOTH
    #    zones (split-horizon mirror rides the same dual-SAN cert). Any
    #    HTTP status proves the TLS layer; 000 would mean handshake failure.
    code_lan = machine.succeed(
      "curl --cacert /run/secrets/dnsblockd_ca_cert --resolve dash.home.lan:443:127.0.0.1 -s -o /dev/null -w '%{http_code}' https://dash.home.lan/"
    ).strip()
    assert code_lan != "000", f"home.lan TLS handshake failed via minted cert (code {code_lan})"
    code_cloud = machine.succeed(
      "curl --cacert /run/secrets/dnsblockd_ca_cert --resolve dash.${testDomain}:443:127.0.0.1 -s -o /dev/null -w '%{http_code}' https://dash.${testDomain}/"
    ).strip()
    assert code_cloud != "000", f"${testDomain} TLS handshake failed via minted cert (code {code_cloud})"
  '';
}
