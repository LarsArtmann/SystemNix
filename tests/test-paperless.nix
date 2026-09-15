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
#   6. Layer 1 OIDC: the paperless-oidc-setup bridge degrades gracefully
#      without the Pocket ID secret, injects it when present, and the
#      reloaded web unit renders the Pocket ID provider button on the
#      login page (Django parsed the delivered JSON end-to-end)
#   7. Declarative dashboards: paperless-dashboard-provision runs at boot
#      (fallback owner, no-tags skip), creates saved views through the
#      token-authed REST API once tags resolve, lands them ON the dashboard
#      (v9 additive UiSettings visibility), and is create-only idempotent
#      with no token residue in the state dir
#
# Tika/Gotenberg are NOT enabled in this test (configureTika = false) —
# their closure (chromium + libreoffice) is multi-GB; the nixpkgs modules
# carry their own coverage, and the gatus endpoints verify them on the host.
_:
let
  paperlessFlakeOutput = (import ../modules/nixos/services/paperless.nix) { };
  paperlessNixosModule = paperlessFlakeOutput.flake.nixosModules.paperless;

  # Options-only imports: the paperless module reads
  # config.services.fastflowlm.model (AI model name) and
  # config.services.llama-rag.embeddingsAlias (embedding model name).
  fastflowlmNixosModule =
    (import ../modules/nixos/services/fastflowlm.nix { }).flake.nixosModules.fastflowlm;
  llamaRagNixosModule =
    (import ../modules/nixos/services/llama-rag.nix { }).flake.nixosModules.llama-rag;

  # fastflowlm.nix sets services.gatus-coverage-audit.allowPorts under
  # mkIf — the option PATH must exist in every eval importing the module,
  # even with the condition false (mkIf defers the value, not the
  # definition). On real hosts auto-discovery provides it; this minimal
  # eval must import the audit module itself.
  gatusCoverageAuditModule =
    (import ../modules/nixos/services/gatus-coverage-audit.nix).flake.nixosModules.gatus-coverage-audit;

  # Option-only mock for the OIDC gate: paperless.nix reads
  # `services.pocket-id-config.enable or false` and falls back to
  # /var/lib/pocket-id for the dataDir (`or` idiom, dns-blocker pattern).
  # The full Pocket ID module is not needed — the secret file is placed
  # by hand and the bridge is exercised directly.
  pocketIdEnableMock =
    { lib, ... }:
    {
      options.services.pocket-id-config = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        # The integration registry fan-out appends the module's OIDC client
        # here when the (mocked) namespace exists — declare the leaf.
        provision.extraOidcClients = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
      };
    };
in
{
  name = "paperless";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        paperlessNixosModule
        fastflowlmNixosModule
        llamaRagNixosModule
        # co-import: the module declares a services.integration entry (mkIf-wrapped options?-guard caveat, 2026-09-15)
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        gatusCoverageAuditModule
        pocketIdEnableMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      virtualisation.memorySize = 4096;

      sops.secrets.paperless_admin_password = { };

      services.pocket-id-config.enable = true;

      # Boot-time fake: paperless-oidc-setup is ConditionPathExists-gated on
      # the Pocket ID client secret (LoadCredential cannot tolerate a missing
      # path). Seed one before the bridge so it runs for real at boot; the
      # skip/degradation semantics are asserted in step 8 of the script.
      # RemainAfterExit keeps later bridge restarts from re-pulling (and
      # re-seeding) it — an active(exited) oneshot start job is a no-op.
      systemd.services.vm-pocket-id-secret = {
        description = "VM test: fake Pocket ID client secret";
        wantedBy = [ "paperless-oidc-setup.service" ];
        before = [ "paperless-oidc-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /var/lib/pocket-id/client-secrets
          printf 'vm-test-secret' > /var/lib/pocket-id/client-secrets/paperless
          chmod 600 /var/lib/pocket-id/client-secrets/paperless
        '';
      };

      services.paperless = {
        enable = true;
        dataDir = lib.mkForce "/var/lib/paperless";
        configureTika = lib.mkForce false;
      };

      # Declarative dashboards (steps 9-12): exercised with the DEFAULT
      # saved-views spec — the boot run has no tags yet (both views skip),
      # the post-seed run creates one + skips the other, and the third run
      # proves create-only idempotency.
      services.paperless-dashboard.enable = true;
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
    assert "PAPERLESS_AI_LLM_EMBEDDING_BACKEND=openai-like" in env, "embedding backend missing from unit env"
    assert "PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT=http://127.0.0.1:8848/v1" in env, "embedding endpoint missing from unit env"
    assert "PAPERLESS_AI_LLM_EMBEDDING_MODEL=bge-m3" in env, "embedding model missing from unit env"
    assert "PAPERLESS_TRASH_DIR=/var/lib/paperless/trash" in env, "trash dir setting missing from unit env"
    assert "PAPERLESS_FILENAME_FORMAT={{ created_year }}/{{ correspondent }}/{{ title }}" in env, "filename format missing from unit env"
    assert "PAPERLESS_DBHOST=/run/postgresql" in env, "postgres backend missing from unit env"
    # Duplicate rejection (2026-09-03 incident: per-account papersync uploads
    # stored byte-identical copies because the paperless default only warns).
    assert "PAPERLESS_CONSUMER_DELETE_DUPLICATES=true" in env, "duplicate rejection missing from unit env"

    # 4. Trash dir provisioned; exporter unit + timer wired
    machine.succeed("test -d /var/lib/paperless/trash")
    machine.succeed("systemctl is-enabled paperless-exporter.timer")

    # 5. Database + role exist in the shared PostgreSQL
    machine.succeed("runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_database WHERE datname='paperless'\" | grep -q 1")
    machine.succeed("runuser -u postgres -- psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='paperless'\" | grep -q 1")

    # 6. Layer 1 OIDC — bridge ran at boot with the fake secret: the env file
    #    carries the injected secret + provider structure on ONE line, plus
    #    the two password-login-off flags (three lines total).
    machine.wait_for_unit("paperless-oidc-setup.service")
    machine.succeed("grep -q 'vm-test-secret' /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("grep -q 'client_id' /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("grep -q 'token_auth_method' /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("grep -q '^PAPERLESS_SOCIALACCOUNT_PROVIDERS=' /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("grep -q '^PAPERLESS_DISABLE_REGULAR_LOGIN=true$' /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("grep -q '^PAPERLESS_REDIRECT_LOGIN_TO_SSO=true$' /var/lib/paperless-oidc/pocket-id.env")
    assert "PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect" in env, "allauth provider app missing from unit env"
    assert "PAPERLESS_SOCIAL_AUTO_SIGNUP=true" in env, "social auto-signup missing from unit env"
    envfiles = machine.succeed("systemctl show paperless-web --property=EnvironmentFiles")
    assert "/var/lib/paperless-oidc/pocket-id.env" in envfiles, "OIDC env file not attached to paperless-web"

    # 7. SSO-only mode live: the login page still renders (200) but with the
    #    password form GONE (PAPERLESS_DISABLE_REGULAR_LOGIN), the Pocket ID
    #    provider form present (Django parsed the delivered provider JSON
    #    end-to-end), and the auto-submit script mounted
    #    (PAPERLESS_REDIRECT_LOGIN_TO_SSO is a CLIENT-SIDE redirect —
    #    paperless's login template auto-submits the first provider form via
    #    JS; there is no 302, verified against the upstream template).
    login_page = machine.succeed(
      "curl -sf --retry 15 --retry-delay 2 --retry-all-errors 'http://localhost:2892/accounts/login/?next=/'"
    )
    assert "oidc/pocket-id" in login_page, "Pocket ID provider form missing from login page"
    assert "getElementById" in login_page, "SSO auto-submit script missing (PAPERLESS_REDIRECT_LOGIN_TO_SSO not parsed)"
    assert 'type="password"' not in login_page, "password form still present (PAPERLESS_DISABLE_REGULAR_LOGIN not parsed)"

    # 8. Degradation semantics: with the secret gone the bridge must SKIP
    #    cleanly (ConditionPathExists → inactive, NOT failed — LoadCredential
    #    would exit 243/CREDENTIALS), and removing the env file must
    #    AUTOMATICALLY restore the password login form — the disable flags
    #    ride in the same env file, so bridge degradation = break-glass on.
    #    The fake-secret helper stays active(exited) — RemainAfterExit makes
    #    its re-pull a no-op, so it does NOT re-seed the secret.
    machine.succeed("rm /var/lib/pocket-id/client-secrets/paperless")
    machine.succeed("systemctl restart paperless-oidc-setup.service")
    machine.succeed("test \"$(systemctl is-active paperless-oidc-setup.service)\" = inactive")
    machine.succeed("rm -f /var/lib/paperless-oidc/pocket-id.env")
    machine.succeed("systemctl restart paperless-web.service")
    machine.wait_for_unit("paperless-web.service")
    machine.succeed(
      "curl -sf --retry 15 --retry-delay 2 --retry-all-errors http://localhost:2892/accounts/login/ | grep -F 'Paperless-ngx sign in'"
    )
    machine.succeed(
      "curl -sf http://localhost:2892/accounts/login/ | grep -F 'type=\"password\"'"
    )

    # 9. Dashboard provisioner: ran at boot (wantedBy paperless-web),
    #    resolved the fallback owner (no SocialAccount exists in the VM),
    #    created nothing (neither the gmail nor the encrypted tag exists
    #    yet — both default views hit the no-resolvable-rules skip).
    machine.wait_for_unit("paperless-dashboard-provision.service")
    machine.succeed("journalctl -u paperless-dashboard-provision.service --no-pager | grep -F 'falling back to admin'")
    machine.succeed("journalctl -u paperless-dashboard-provision.service --no-pager | grep -F \"skipping view 'Gmail Archive'\"")

    # 10. Seed the gmail tag via the API — proves TokenAuthentication with
    #     a drf_create_token-minted key end-to-end (the exact auth path the
    #     provisioner uses). The encrypted tag stays absent ON PURPOSE: the
    #     next step then covers BOTH the created and the skipped path.
    token = machine.succeed(
      "runuser -u paperless -- /run/current-system/sw/bin/paperless-manage drf_create_token admin | grep -oE '[0-9a-f]{40}'"
    ).strip()
    machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' -H 'Content-Type: application/json' "
      "-d '{\"name\":\"gmail\"}' http://localhost:2892/api/tags/"
    )

    # 11. Re-run the provisioner: Gmail Archive now resolves its tag and is
    #     created ON the dashboard (API v9 legacy visibility = the additive
    #     UiSettings merge); Encrypted still skips (tag absent). The
    #     ui_settings membership check is the phantom-green killer.
    machine.succeed("systemctl restart paperless-dashboard-provision.service")
    machine.wait_for_unit("paperless-dashboard-provision.service")
    machine.succeed("journalctl -u paperless-dashboard-provision.service --no-pager | grep -F \"created saved view 'Gmail Archive'\"")
    machine.succeed("journalctl -u paperless-dashboard-provision.service --no-pager | grep -F \"skipping view 'Encrypted (needs attention)'\"")
    view_id = machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' -H 'Accept: application/json; version=9' "
      "'http://localhost:2892/api/saved_views/?page_size=100000' "
      "| jq -r '.results[] | select(.name == \"Gmail Archive\") | .id'"
    ).strip()
    assert view_id != "", "Gmail Archive saved view missing after provisioning"
    machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' http://localhost:2892/api/ui_settings/ "
      f"| jq -e --argjson id {view_id} '.settings.saved_views.dashboard_views_visible_ids | index($id) != null'"
    )

    # 12. Idempotency: create-only — a third run skips, count unchanged,
    #     and the token file cleanup left nothing behind in the state dir.
    machine.succeed("systemctl restart paperless-dashboard-provision.service")
    machine.wait_for_unit("paperless-dashboard-provision.service")
    machine.succeed("journalctl -u paperless-dashboard-provision.service --no-pager | grep -F \"saved view 'Gmail Archive' already exists - skipping\"")
    count = machine.succeed(
      f"curl -sf -H 'Authorization: Token {token}' http://localhost:2892/api/saved_views/ | jq '.count'"
    ).strip()
    assert count == "1", f"expected exactly 1 saved view, got {count}"
    machine.succeed("test -z \"$(ls -A /var/lib/paperless-dashboard)\" ")

    print("Paperless v3 wiring verified — units up, PG backend, AI env, trash, exporter, Pocket ID OIDC bridge, SSO-only + auto-break-glass, declarative dashboards (create-only + v9 visibility + idempotent)")
  '';
}
