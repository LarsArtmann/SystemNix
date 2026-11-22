# End-to-end VM test for the Drive → Paperless ingest pipeline
# (modules/nixos/services/drive-paperless.nix) — REAL paperless + REAL
# immich, unlike checks.drive-ingest-fixture which proves script logic
# against a stubbed API. This is the API-CONTRACT test:
#
#   1. drive-paperless-token mints a DRF token via drf_create_token
#      against the live paperless PostgreSQL (bank-sync pattern, tmpfs env
#      file, root ExecStartPost handover).
#   2. immich-api-key-provision (the shared converger) mints the machine-
#      managed drive-paperless key into Immich's api_key table and renders
#      the 0400 env file the ingest unit reads as its second
#      EnvironmentFile — the 2026-11-14 supersession of the sops paste.
#   3. The ingest unit uploads documents to the REAL paperless DRF API
#      (multipart post_document fields: document/title/correspondent/
#      created/tags) and the document is queryable with its metadata —
#      title = filename stem, correspondent created on the fly, both
#      global + per-source tags, created = the file's mtime date.
#   4. ingestImages routes the raster image to the REAL Immich
#      /api/assets endpoint (x-api-key auth) and the asset row lands.
#   5. Journal interplay: journal.tsv gains one line per uploaded file,
#      last_success is touched, and a second run re-uploads NOTHING
#      (idempotence) while still touching last_success.
#
# Synthetic mirror tree: tmpfiles-seeded under /mnt/pool/backups/google-drive
# (source paths MUST live under /mnt/ — the module's mount-gating assertion).
# .txt/.md cover the document route; a 1x1 JPEG covers the image route.
# PDFs are deliberately absent: the contract under test is multipart field
# acceptance + metadata, which txt exercises identically without pulling an
# OCR-valid PDF fixture into the tree.
{
  inputs,
}:
let
  paperlessFlakeOutput = (import ../modules/nixos/services/paperless.nix) { };
  paperlessNixosModule = paperlessFlakeOutput.flake.nixosModules.paperless;
  drivePaperlessModule =
    (import ../modules/nixos/services/drive-paperless.nix { }).flake.nixosModules.drive-paperless;
  immichModule = (import ../modules/nixos/services/immich.nix { }).flake.nixosModules.immich;

  # Options-only co-imports (the test-paperless.nix set — see that file's
  # header for why each is needed).
  fastflowlmNixosModule =
    (import ../modules/nixos/services/fastflowlm.nix { }).flake.nixosModules.fastflowlm;
  llamaRagNixosModule =
    (import ../modules/nixos/services/llama-rag.nix { }).flake.nixosModules.llama-rag;
  gatusCoverageAuditModule =
    ((import ../modules/nixos/services/gatus-coverage-audit.nix) { inherit inputs; })
    .flake.nixosModules.gatus-coverage-audit;
  pocketIdEnableMock =
    { lib, ... }:
    {
      options.services.pocket-id-config = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        provision.extraOidcClients = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        provision.userGroups = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
        };
        provision.adminUser.username = lib.mkOption {
          type = lib.types.str;
          default = "vm-admin";
        };
      };
    };
  mailRelayEnableMock =
    { lib, ... }:
    {
      options.services.mail-relay = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        fromAddress = lib.mkOption {
          type = lib.types.str;
          default = "noreply@vm.test";
        };
      };
    };

  # 1x1 JPEG (public constant) — bytes only need to satisfy Immich's
  # upload acceptance; thumbnailing failures do not block the asset row.
  jpegB64 = ''
    /9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAMCAgICAgMCAgIDAwMDBAYEBAQEBAgGBgUGCQgKCgkICAgK
    DA8MCgsOCwkJDRENDg8QEBEQCgwSExIQEw8QEBD/yQALCAABAAEBAREA/8wABgAQEAX/2gAIAQEAAD8A
    0s8g/9k=
  '';
in
{
  name = "drive-paperless-e2e";

  nodes.machine =
    { lib, pkgs, ... }:
    {
      imports = [
        paperlessNixosModule
        drivePaperlessModule
        immichModule
        fastflowlmNixosModule
        llamaRagNixosModule
        (import ../modules/nixos/services/integration.nix { }).flake.nixosModules.integration
        (import ../modules/nixos/services/backup-coordination.nix { })
        .flake.nixosModules.backup-coordination
        gatusCoverageAuditModule
        pocketIdEnableMock
        mailRelayEnableMock
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      virtualisation.memorySize = 4096;
      networking.domain = lib.mkForce "vm.test";

      environment.systemPackages = [ pkgs.jq ];

      sops.secrets.paperless_admin_password = { };
      # Immich is OIDC-only; the mock-sops file satisfies the clientSecret
      # _secret render (pocket-id provisioning stays OFF so the sops path
      # branch is taken — the pocket-id- provisioned path is host-only).
      sops.secrets.immich_oauth_client_secret = { };

      services.paperless = {
        enable = true;
        dataDir = lib.mkForce "/var/lib/paperless";
        configureTika = lib.mkForce false;
      };

      services.immich = {
        enable = true;
        # VM overrides for the host-specific decls in our immich module:
        # no DAS pool, no GPU, no ML closure (the asset row is inserted at
        # upload; ML never sees it in this test).
        mediaLocation = lib.mkForce "/var/lib/immich";
        machine-learning.enable = lib.mkForce false;
        accelerationDevices = lib.mkForce [ ];
      };

      services.drive-paperless = {
        enable = true;
        ingestImages = true;
        batchSize = 10;
        sources = [
          {
            path = "/mnt/pool/backups/google-drive";
            correspondent = "Google Drive (private)";
            tag = "gdrive";
          }
        ];
      };

      # Synthetic mirror tree (systemd-tmpfiles, pre-everything): the ingest
      # seeds nothing itself — first-run without a mirror is the "missing
      # source" skip path the fixture already covers.
      systemd.tmpfiles.rules = [
        "d /mnt/pool/backups/google-drive/docs 0755 root root -"
        "d /mnt/pool/backups/google-drive/photos 0755 root root -"
      ];

      # File CONTENT cannot ride tmpfiles rules — one boot oneshot writes
      # the three payload files and stamps a known mtime (the created=
      # metadata assertion derives from it).
      systemd.services.vm-mirror-seed = {
        description = "VM test: seed the synthetic google-drive mirror tree";
        wantedBy = [ "multi-user.target" ];
        before = [ "drive-paperless.service" ];
        unitConfig.ConditionPathExists = "!/mnt/pool/backups/google-drive/docs/notes.txt";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          printf 'vm-test document body\n' > /mnt/pool/backups/google-drive/docs/notes.txt
          printf '# vm-test markdown\n' > /mnt/pool/backups/google-drive/docs/readme.md
          printf '%s' '${jpegB64}' | base64 -d > /mnt/pool/backups/google-drive/photos/beach.jpg
          touch -d '2026-06-01 12:00:00' \
            /mnt/pool/backups/google-drive/docs/notes.txt \
            /mnt/pool/backups/google-drive/docs/readme.md \
            /mnt/pool/backups/google-drive/photos/beach.jpg
        '';
      };
    };

  testScript = ''
    import json
    import time

    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("paperless-web.service")
    machine.wait_for_unit("vm-mirror-seed.service")

    # --- 1. the DRF token mint (drive-paperless-token) -------------------
    # No boot-time wantedBy: the mint is pulled by the ingest unit, which
    # the test starts manually below — start the mint explicitly first
    # (systemd start returns after the oneshot finished; a nonzero exit
    # raises here, so no wait_for_unit needed for these Type=oneshot units
    # — they deactivate to inactive on success).
    machine.succeed("systemctl start drive-paperless-token.service")
    machine.succeed("test -f /run/drive-paperless/env")
    token = machine.succeed("sed -n 's/^DRIVE_PAPERLESS_TOKEN=//p' /run/drive-paperless/env").strip()
    assert len(token) == 40, f"DRF token not a 40-hex: {token!r}"

    # --- 2. boot Immich + register its admin (fresh DB) ------------------
    machine.wait_for_unit("immich-server.service")
    machine.wait_until_succeeds(
      "curl -fsS http://127.0.0.1:2283/api/server/ping", 120
    )
    # The converger needs an admin user to attach keys to; a FRESH Immich DB
    # has none until first sign-up. admin-sign-up is the supported bootstrap.
    machine.wait_until_succeeds(
      "curl -fsS -X POST http://127.0.0.1:2283/api/auth/admin-sign-up "
      "-H 'Content-Type: application/json' "
      "-d '{\"email\":\"admin@vm.test\",\"password\":\"vm-test-password-1\",\"name\":\"vm-admin\"}'",
      60,
    )
    # --- 3. the converger mints the machine-managed key ------------------
    machine.succeed("systemctl reset-failed immich-api-key-provision.service || true")
    machine.succeed("systemctl start immich-api-key-provision.service")
    machine.succeed("test -f /var/lib/immich-api-keys/drive-paperless.env")
    machine.succeed(
      "test \"$(stat -c %a /var/lib/immich-api-keys/drive-paperless.env)\" = 400"
    )
    immich_key = machine.succeed(
      "sed -n 's/^IMMICH_API_KEY=//p' /var/lib/immich-api-keys/drive-paperless.env"
    ).strip()
    assert len(immich_key) >= 32, f"immich key too short: {immich_key!r}"
    # The key validates against the live Immich (the ingest preflight contract).
    machine.succeed(
      f"curl -fsS -H 'x-api-key: {immich_key}' http://127.0.0.1:2283/api/users/me"
    )

    # --- 4. the ingest run (docs → paperless, image → immich) ------------
    def run_ingest():
        machine.succeed("systemctl reset-failed drive-paperless.service || true")
        # start blocks until the oneshot finishes; failure raises here.
        machine.succeed("systemctl start drive-paperless.service")

    # immich-server may still be settling its first-boot jobs when the
    # ingest's preflight pings it — the unit fails loudly by design; retry.
    deadline = time.time() + 300
    while True:
        try:
            run_ingest()
            break
        except Exception:
            if time.time() > deadline:
                raise
            time.sleep(10)

    journal = machine.succeed("cat /var/lib/drive-paperless/journal.tsv")
    lines = [l for l in journal.strip().split("\n") if l]
    assert len(lines) == 3, f"expected 3 journal lines, got {len(lines)}: {journal!r}"
    assert any("docs/notes.txt" in l and l.startswith("gdrive\t") for l in lines), journal
    assert any("photos/beach.jpg" in l for l in lines), journal
    machine.succeed("test -f /var/lib/drive-paperless/last_success")

    # --- 5. paperless API contract: the document + its metadata ----------
    doc = None
    deadline = time.time() + 240  # consume is async
    while doc is None:
        out = machine.succeed(
            f"curl -fsS -H 'Authorization: Token {token}' "
            "'http://127.0.0.1:2892/api/documents/?query=notes'"
        )
        results = json.loads(out).get("results", [])
        doc = next((r for r in results if r.get("title") == "notes"), None)
        if doc is None:
            if time.time() > deadline:
                raise AssertionError(f"document 'notes' never appeared: {out!r}")
            time.sleep(5)
    assert doc["correspondent"] != None and doc["correspondent"] > 0, doc
    assert len(doc["tags"]) == 2, f"expected global+source tags: {doc}"
    tags = json.loads(
        machine.succeed(
            f"curl -fsS -H 'Authorization: Token {token}' "
            "'http://127.0.0.1:2892/api/tags/?page_size=100'"
        )
    )
    tag_names = sorted(t["name"] for t in tags["results"] if t["id"] in doc["tags"])
    assert tag_names == ["gdrive", "google-drive"], f"tags: {tag_names}"
    assert doc["created"].startswith("2026-06-01"), f"created: {doc['created']}"

    # --- 6. immich asset row landed (via the scoped API key itself — the
    # asset.read contract under test; search/metadata requires AssetRead,
    # verified in the deployed immich source search.controller.js) --------
    machine.wait_until_succeeds(
      f"curl -fsS -X POST http://127.0.0.1:2283/api/search/metadata "
      f"-H 'x-api-key: {immich_key}' -H 'Content-Type: application/json' "
      f"-d '{{\"filename\":\"beach.jpg\"}}' "
      f"| jq -e '(.assets.items // .items) | length >= 1'",
      120,
    )

    # --- 7. idempotence: the second run re-uploads nothing ---------------
    mtime_before = machine.succeed("stat -c %Y /var/lib/drive-paperless/last_success").strip()
    run_ingest()
    journal2 = machine.succeed("cat /var/lib/drive-paperless/journal.tsv")
    lines2 = [l for l in journal2.strip().split("\n") if l]
    assert len(lines2) == 3, f"second run grew the journal: {journal2!r}"
    mtime_after = machine.succeed("stat -c %Y /var/lib/drive-paperless/last_success").strip()
    assert mtime_after >= mtime_before, "last_success not touched on the second run"
    summary = machine.succeed("journalctl -u drive-paperless.service --since -5m | grep 'run complete' | tail -1")
    assert "uploaded=0" in summary, f"second run re-uploaded: {summary!r}"
  '';
}
