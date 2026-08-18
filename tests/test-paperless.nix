# VM test for the Paperless-ngx service module (v3 wiring).
#
# Verifies the runtime behavior that nix eval CANNOT check:
#   1. All four paperless units start without crash-looping against the
#      PostgreSQL backend (database.createLocally — migrations + tantivy
#      reindex + superuser bootstrap in the scheduler preStart)
#   2. The web interface serves the real sign-in page
#   3. The v3 settings (AI endpoint, trash, filename format) land in the
#      unit environment
#   4. The trash dir is provisioned, and the exporter unit + timer exist
#   5. The paperless database + role exist in PostgreSQL
#
# Tika/Gotenberg are NOT enabled in this test (configureTika = false) —
# their closure (chromium + libreoffice) is multi-GB; the nixpkgs modules
# carry their own coverage, and the gatus endpoints verify them on the host.
{pkgs}: let
  paperlessFlakeOutput = (import ../modules/nixos/services/paperless.nix) {};
  paperlessNixosModule = paperlessFlakeOutput.flake.nixosModules.paperless;

  # Options-only import: the paperless module reads
  # config.services.fastflowlm.model for the AI model name.
  fastflowlmNixosModule =
    (import ../modules/nixos/services/fastflowlm.nix {}).flake.nixosModules.fastflowlm;
in {
  name = "paperless";

  nodes.machine = {lib, ...}: {
    imports = [
      paperlessNixosModule
      fastflowlmNixosModule
      ./mock-sops.nix
      ./test-helpers.nix
    ];

    virtualisation.memorySize = 4096;

    sops.secrets.paperless_admin_password = {};

    services.paperless = {
      enable = true;
      dataDir = lib.mkForce "/var/lib/paperless";
      configureTika = lib.mkForce false;
    };
  };

  testScript = ''
    machine.start()

    # 1. PostgreSQL first (paperless units are ordered after it), then the
    #    paperless stack. The scheduler preStart runs the initial migration,
    #    tantivy reindex, and superuser bootstrap.
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("paperless-scheduler.service")
    machine.wait_for_unit("paperless-web.service")
    machine.wait_for_unit("paperless-consumer.service")
    machine.wait_for_unit("paperless-task-queue.service")

    # 2. Real sign-in page (functional check, mirrors the Gatus body pattern)
    machine.wait_for_open_port(2892, timeout=60)
    machine.succeed("curl -sf http://localhost:2892/accounts/login/ | grep -F 'Paperless-ngx sign in'")

    # 3. v3 settings present in the web unit environment
    env = machine.succeed("systemctl show paperless-web --property=Environment")
    assert "PAPERLESS_AI_LLM_ENDPOINT=http://127.0.0.1:52625/v1" in env, "AI endpoint missing from unit env"
    assert "PAPERLESS_AI_LLM_MODEL=qwen3.6-moe:35b-a3b" in env, "AI model missing from unit env"
    assert "PAPERLESS_TRASH_DIR=/var/lib/paperless/trash" in env, "trash dir setting missing from unit env"
    assert "PAPERLESS_FILENAME_FORMAT={{ created_year }}/{{ correspondent }}/{{ title }}" in env, "filename format missing from unit env"
    assert "PAPERLESS_DBHOST=/run/postgresql" in env, "postgres backend missing from unit env"

    # 4. Trash dir provisioned; exporter unit + timer wired
    machine.succeed("test -d /var/lib/paperless/trash")
    machine.succeed("systemctl is-enabled paperless-exporter.timer")

    # 5. Database + role exist in the shared PostgreSQL
    machine.succeed("runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_database WHERE datname='paperless'\" | grep -q 1")
    machine.succeed("runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='paperless'\" | grep -q 1")

    print("Paperless v3 wiring verified — units up, PG backend, AI env, trash, exporter")
  '';
}
