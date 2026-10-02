# VM test for the paperless-gpt service module (AI-max plan A10, 2026-10-02).
#
# Verifies the runtime behavior nix eval CANNOT check:
#   1. The paperless-gpt-token oneshot mints a DRF token at boot as the
#      paperless user (peer-auth PG) and drops a 0400 env file OWNED by the
#      daemon user (the bank-sync runtime-mint pattern, end-to-end).
#   2. The daemon starts with the minted token, seeds default_prompts/
#      into its state dir, creates prompts/ + config/ + db/ around its
#      WorkingDirectory, and initializes the gorm sqlite DB.
#   3. The web UI/API answers on the LOOPBACK interface only (the embedded
#      UI has no auth — a 0.0.0.0 bind would be a security regression).
#   4. /api/filter-tag returns the manual tag (liveness without auth).
#   5. END-TO-END paperless wiring: the daemon's startup EnsureTagExists
#      created the fail tag IN PAPERLESS through the runtime-minted token
#      (authenticated API write; proves base URL + token + REST path).
#
# fastflowlm is an OPTIONS-ONLY mock: paperless-gpt reads .enable/.model/
# .port from it (assertion + env rendering) but the daemon never CALLS the
# LLM in a fresh VM (no auto-tagged documents exist), so no NPU units run.
{ pkgs, inputs }:
let
  paperlessFlakeOutput = (import ../modules/nixos/services/paperless.nix) { };
  paperlessNixosModule = paperlessFlakeOutput.flake.nixosModules.paperless;

  paperlessGptFlakeOutput = (import ../modules/nixos/services/paperless-gpt.nix) { inherit inputs; };
  paperlessGptNixosModule = paperlessGptFlakeOutput.flake.nixosModules.paperless-gpt;

  # Option-only mock (pocketIdEnableMock pattern from test-paperless.nix):
  # declares exactly the leaves paperless-gpt reads. No flm units in the VM.
  fastflowlmOptionsMock =
    { lib, ... }:
    {
      options.services.fastflowlm = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "vm-mock-model";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 52625;
        };
      };
    };

  # Option-only mocks copied from test-paperless.nix: the paperless module's
  # registry entry fans its OIDC client into pocket-id-config.provision and
  # reads mail-relay.enable — the option PATHS must exist in this minimal VM.
  pocketIdOptionsMock =
    { lib, ... }:
    {
      options.services.pocket-id-config = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        provision.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        provision.extraOidcClients = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.userGroups = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.adminUser.username = lib.mkOption {
          type = lib.types.str;
          default = "vm-admin";
        };
        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/pocket-id";
        };
      };
    };

  mailRelayOptionsMock =
    { lib, ... }:
    {
      options.services.mail-relay = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        fromAddress = lib.mkOption {
          type = lib.types.str;
          default = "noreply@larsartmann.cloud";
        };
      };
    };
in
{
  name = "paperless-gpt";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [
        paperlessNixosModule
        paperlessGptNixosModule
        # Options-only import: paperless.nix reads
        # config.services.llama-rag.embeddingsAlias (embedding model name).
        (import ../modules/nixos/services/llama-rag.nix { }).flake.nixosModules.llama-rag
        # co-import: the module declares a services.integration entry (the
        # options?-guard does not survive mkIf cfg.enable with enable=true —
        # the 2026-09-15 flake-check-proven caveat).
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        # co-import: paperless-gpt declares an unconditional
        # services.catalog entry (ADR-008; loud eval failure if missing).
        (import ../modules/nixos/services/catalog.nix { }).flake.nixosModules.catalog
        fastflowlmOptionsMock
        pocketIdOptionsMock
        mailRelayOptionsMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      virtualisation.memorySize = 4096;

      environment.systemPackages = [ pkgs.jq ];

      sops.secrets.paperless_admin_password = { };

      services.fastflowlm.enable = true;
      services.paperless = {
        enable = true;
        dataDir = lib.mkForce "/var/lib/paperless";
        configureTika = lib.mkForce false;
      };
      services.paperless-gpt.enable = true;
    };

  testScript = ''
    machine.start()

    # 1. Paperless first (PG migrations + superuser bootstrap in the
    #    scheduler preStart), then the token mint, then the daemon.
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("paperless-scheduler.service")
    machine.wait_for_unit("paperless-web.service")
    machine.wait_for_unit("paperless-gpt-token.service")
    machine.wait_for_unit("paperless-gpt.service")

    # 2. Token mint artifacts: 0400, owned by the daemon user, valid hex.
    # (No trailing-$ anchors in grep patterns here: `$'` collides with
    # bash ANSI-C quoting through the test driver's shell wrapper.)
    machine.succeed("stat -c '%a %U %G' /run/paperless-gpt/env | grep '400 paperless-gpt paperless-gpt'")
    machine.succeed("grep -q 'PAPERLESS_API_TOKEN=' /run/paperless-gpt/env")

    # 3. State layout: seeded default_prompts (8 templates), app-created
    #    prompts/ copy + config/ + db/ (gorm sqlite initialized). The app
    #    populates prompts/ LATE in startup (behind its first paperless API
    #    round-trips — minutes-slow on a cold VM), so poll, don't assert.
    machine.succeed("ls /var/lib/paperless-gpt/default_prompts/ | wc -l | grep -qx 8")
    machine.wait_until_succeeds("test -f /var/lib/paperless-gpt/prompts/custom_field_prompt.tmpl", timeout=300)
    machine.wait_until_succeeds("test -f /var/lib/paperless-gpt/config/settings.json", timeout=60)
    machine.succeed("test -d /var/lib/paperless-gpt/db")

    # 4. Loopback-only bind (the embedded UI has NO auth — 0.0.0.0 would
    #    be a security regression) + liveness probe without auth.
    machine.succeed("ss -tln | grep '127.0.0.1:8106'")
    machine.fail("ss -tln | grep -E '0\\.0\\.0\\.0:8106|\\[::\\]:8106' || true")
    machine.succeed("curl -sf http://127.0.0.1:8106/api/filter-tag | jq -e '.tag == \"paperless-gpt\"'")

    # 5. END-TO-END: the daemon's startup EnsureTagExists must have created
    #    the fail tag IN paperless through the runtime-minted token. Mint a
    #    probe token the same way (peer auth as the paperless user) and
    #    query the API with it.
    token = machine.succeed(
      "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage drf_create_token admin | grep -oE '[0-9a-f]{40}'"
    ).strip()
    machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' 'http://127.0.0.1:2892/api/tags/?name=paperless-gpt-failed' | jq -e '.count >= 1'"
    )

    # 6. No token leakage: the mint file never appears in the journal.
    machine.fail("journalctl -u paperless-gpt-token.service --no-pager | grep -E '[0-9a-f]{40}'")
  '';
}
