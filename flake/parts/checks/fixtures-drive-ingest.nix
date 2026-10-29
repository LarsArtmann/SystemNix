# Behavioral fixtures for the Drive → Paperless ingest pipeline and the
# google-sync go-live config gate. Both eval ISOLATED nixosSystem configs
# (module under test + nixpkgs paperless + mock-sops) — independent of the
# evo-x2 graph so a broken toplevel never masks module regressions (the
# 2026-10-06 test-paperless-gpt whole-tree lesson).
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      checks = {
        drive-ingest-fixture =
          let
            paperlessModule = "${inputs.nixpkgs}/nixos/modules/services/misc/paperless.nix";

            mkIngestEval =
              extraConfig:
              inputs.nixpkgs.lib.nixosSystem {
                system = "x86_64-linux";
                modules = [
                  inputs.self.nixosModules.drive-paperless
                  inputs.self.nixosModules.backup-coordination
                  inputs.self.nixosModules.integration
                  paperlessModule
                  {
                    services.paperless.enable = true;
                    services.drive-paperless = {
                      enable = true;
                      sources = [
                        {
                          path = "/mnt/pool/backups/google-drive";
                          correspondent = "Google Drive (private)";
                          tag = "gdrive";
                        }
                        {
                          path = "/mnt/pool/backups/google-drive-work";
                          correspondent = "Google Workspace";
                          tag = "gwork";
                        }
                      ];
                    };
                  }
                  extraConfig
                ];
              };

            main = mkIngestEval { };
            batch1 = mkIngestEval { services.drive-paperless.batchSize = 1; };
            cap1 = mkIngestEval { services.drive-paperless.maxFileSizeMB = 1; };

            immichModule = "${inputs.nixpkgs}/nixos/modules/services/web-apps/immich.nix";
            imagesEval = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                inputs.self.nixosModules.drive-paperless
                inputs.self.nixosModules.backup-coordination
                inputs.self.nixosModules.integration
                paperlessModule
                immichModule
                (root + "/tests/mock-sops.nix")
                {
                  services.paperless.enable = true;
                  services.immich.enable = true;
                  services.drive-paperless = {
                    enable = true;
                    ingestImages = true;
                    sources = [
                      {
                        path = "/mnt/pool/backups/google-drive";
                        correspondent = "Google Drive (private)";
                        tag = "gdrive";
                      }
                      {
                        path = "/mnt/pool/backups/google-drive-work";
                        correspondent = "Google Workspace";
                        tag = "gwork";
                      }
                      # THIRD source, hyphenated tag: the slug bash-identifier pin
                      {
                        path = "/mnt/pool/backups/google-drive-shared";
                        correspondent = "Google Drive (shared with me)";
                        tag = "gdrive-shared";
                      }
                    ];
                  };
                  sops.secrets.drive_paperless_immich_api_key = { };
                }
              ];
            };

            ingestMain = main.config.systemd.services.drive-paperless.serviceConfig.ExecStart;
            ingestBatch1 = batch1.config.systemd.services.drive-paperless.serviceConfig.ExecStart;
            ingestCap1 = cap1.config.systemd.services.drive-paperless.serviceConfig.ExecStart;
            ingestImages1 = imagesEval.config.systemd.services.drive-paperless.serviceConfig.ExecStart;

            # The google-sync go-live gate: ExecStartPre config-check binary
            # out of an isolated enabled eval (mock-sops supplies the secret
            # path; backup-coordination is co-imported because google-sync
            # registers its freshness row unguarded).
            gsEval = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                inputs.self.nixosModules.google-sync
                inputs.self.nixosModules.backup-coordination
                inputs.self.nixosModules.integration
                (root + "/tests/mock-sops.nix")
                {
                  services.google-sync.enable = true;
                  sops.secrets.google_sync_rclone_config = { };
                }
              ];
            };
            gsConfigCheck =
              lib.findFirst (e: lib.hasInfix "google-sync-config-check" e)
                (throw "google-sync ExecStartPre carries no config-check")
                gsEval.config.systemd.services.google-sync.serviceConfig.ExecStartPre;

            evalPins =
              let
                svc = main.config.systemd.services.drive-paperless;
                token = main.config.systemd.services.drive-paperless-token;
                timer = main.config.systemd.timers.drive-paperless;
                imgSvc = imagesEval.config.systemd.services.drive-paperless;
              in
              ''
                echo "${
                  lib.concatMapStringsSep " " (e: if lib.hasInfix "drive-paperless" e then e else "") svc.after
                }" | grep -q "drive-paperless-token.service" || {
                  echo "FAIL: ingest unit not ordered after the token mint" >&2; exit 1; }
                echo "${toString svc.requires}" | grep -q "drive-paperless-token" || {
                  echo "FAIL: ingest unit must require the token mint" >&2; exit 1; }
                echo "${toString svc.unitConfig.RequiresMountsFor}" \
                  | grep -q "/mnt/pool/backups/google-drive-work" || {
                  echo "FAIL: RequiresMountsFor must gate every source path" >&2; exit 1; }
                echo "${lib.concatStringsSep " " svc.serviceConfig.Environment}" \
                  | grep -q "DRIVE_PAPERLESS_URL=http://127.0.0.1:2892" || {
                  echo "FAIL: URL must derive from ports.nix (paperless=2892)" >&2; exit 1; }
                [ "${svc.serviceConfig.User}" = "drive-paperless" ] || {
                  echo "FAIL: dedicated system user expected" >&2; exit 1; }
                [ "${svc.serviceConfig.StateDirectory}" = "drive-paperless" ] || {
                  echo "FAIL: StateDirectory must exist — without it the first live run dies at mkdir against root-owned /var/lib (self-review §d.1)" >&2; exit 1; }
                [ "${timer.timerConfig.OnCalendar}" = "hourly" ] || {
                  echo "FAIL: timer expected hourly" >&2; exit 1; }
                [ "${lib.boolToString timer.timerConfig.Persistent}" = "true" ] || {
                  echo "FAIL: timer must catch up (Persistent)" >&2; exit 1; }
                echo "${toString token.serviceConfig.ExecStartPost}" \
                  | grep -q "^+.*drive-paperless-token-chown" || {
                  echo "FAIL: mint handover must run as root (+ prefix)" >&2; exit 1; }
                [ "${lib.boolToString token.serviceConfig.RuntimeDirectoryPreserve}" = "true" ] || {
                  echo "FAIL: mint RuntimeDirectory must survive until the ingest reads it" >&2; exit 1; }
                # images-variant pins: Immich env + secret + ordering
                echo "${lib.concatStringsSep " " imgSvc.serviceConfig.Environment}" \
                  | grep -q "IMMICH_URL=http://127.0.0.1:2283" || {
                  echo "FAIL: IMMICH_URL must derive from ports.nix (immich=2283)" >&2; exit 1; }
                echo "${toString imgSvc.serviceConfig.EnvironmentFile}" \
                  | grep -q "drive_paperless_immich_api_key" || {
                  echo "FAIL: ingestImages must wire the sops API key as EnvironmentFile" >&2; exit 1; }
                echo "${lib.concatMapStringsSep " " (e: if lib.hasInfix "immich" e then e else "") imgSvc.after}" \
                  | grep -q "immich-server.service" || {
                  echo "FAIL: images ingest must be ordered after immich-server" >&2; exit 1; }
                # slug pin: hyphenated tags must render valid bash identifiers
                grep -q "meta_gdrive_shared" ${ingestImages1} || {
                  echo "FAIL: gdrive-shared tag must slug to meta_gdrive_shared" >&2; exit 1; }
                grep -q "meta_gdrive-shared" ${ingestImages1} && {
                  echo "FAIL: raw hyphenated tag leaked into a bash identifier (bad substitution at runtime)" >&2; exit 1; }
              '';
          in
          pkgs.runCommand "drive-ingest-fixture"
            {
              nativeBuildInputs = with pkgs; [
                bash
                coreutils-full
                findutils
                gnugrep
                gnused
                gawk
                diffutils
                rclone
              ];
            }
            ''
              ${evalPins}
              bash ${root}/scripts/test-drive-paperless.sh \
                ${ingestMain} \
                ${ingestBatch1} \
                ${ingestCap1} \
                ${ingestImages1} \
                ${gsConfigCheck}
              touch $out
            '';
      };
    };
}
