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

            ingestMain = main.config.systemd.services.drive-paperless.serviceConfig.ExecStart;
            ingestBatch1 = batch1.config.systemd.services.drive-paperless.serviceConfig.ExecStart;
            ingestCap1 = cap1.config.systemd.services.drive-paperless.serviceConfig.ExecStart;

            # The google-sync go-live gate: ExecStartPre config-check binary
            # out of an isolated enabled eval (mock-sops supplies the secret
            # path; backup-coordination is co-imported because google-sync
            # registers its freshness row unguarded).
            gsEval = inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              modules = [
                inputs.self.nixosModules.google-sync
                inputs.self.nixosModules.backup-coordination
                (root + "/tests/mock-sops.nix")
                {
                  services.google-sync.enable = true;
                  sops.secrets.google_sync_rclone_config = { };
                }
              ];
            };
            gsConfigCheck = lib.findFirst (
              e: lib.hasInfix "google-sync-config-check" e
            ) (throw "google-sync ExecStartPre carries no config-check") (
              gsEval.config.systemd.services.google-sync.serviceConfig.ExecStartPre
            );

            evalPins =
              let
                svc = main.config.systemd.services.drive-paperless;
                token = main.config.systemd.services.drive-paperless-token;
                timer = main.config.systemd.timers.drive-paperless;
              in
              ''
                echo "${
                  lib.concatMapStringsSep " " (
                    e: if lib.hasInfix "drive-paperless" e then e else ""
                  ) svc.after
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
                [ "${timer.timerConfig.OnCalendar}" = "hourly" ] || {
                  echo "FAIL: timer expected hourly" >&2; exit 1; }
                [ "${lib.boolToString timer.timerConfig.Persistent}" = "true" ] || {
                  echo "FAIL: timer must catch up (Persistent)" >&2; exit 1; }
                echo "${toString token.serviceConfig.ExecStartPost}" \
                  | grep -q "^+.*drive-paperless-token-chown" || {
                  echo "FAIL: mint handover must run as root (+ prefix)" >&2; exit 1; }
                [ "${lib.boolToString token.serviceConfig.RuntimeDirectoryPreserve}" = "true" ] || {
                  echo "FAIL: mint RuntimeDirectory must survive until the ingest reads it" >&2; exit 1; }
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
                ${gsConfigCheck}
              touch $out
            '';
      };
    };
}
