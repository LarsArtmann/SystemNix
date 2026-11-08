# Runbook: docs/services/cvagent.md
# cvagent — keep the CV repo's code-derived evidence fresh (scan + mesh).
#
# Daily: scans the configured repositories with cvagent (event-sourced
# sqlite fact store under the operator's state dir) and exports the mesh
# artifacts into the CV checkout: the RFC 6902 variant patch
# data/cv/lars_artmann-en-cvagent.patch.json (renderable via
# `cv render --variant cvagent`) plus data/projects-v2/<slug>.md evidence
# pages. The repo's PMA auto-commit daemon picks the diff up and
# cv-server-content-sync ships it on the next deploy.
#
# DELEGATED 2026-11-08 (own-project upstreaming wave): the deployment
# contract lives upstream — inputs.cvagent.nixosModules.default gained the
# production shape (scan.repositories curated mode with per-repo tolerance,
# scan.aiModel/aiBaseUrl rendered config, scan.aiDailyFactCap spend gate,
# scan.timeoutStartSec, mesh.runWithScan combined unit; VM-tested in the
# cvagent repo's nixos-module check). The unit is cvagent-scan.service +
# cvagent-scan.timer (combined scan+mesh; no separate mesh unit/timer).
# SystemNix layers ONLY site specifics: the operator identity (runs as the
# primary user — writes the CV checkout and ~/.local/state, so home
# protection must not apply), the sops AI-key env file, ioTier, onFailure,
# the system-health row, and the fleet harden bound.
#
#   - AI extraction (owner decision 2026-11-04): one SAMPLED AI call per
#     repo per run (MaxCommitSample caps the prompt; 24 repos ≈ 24
#     calls/day on the GLM coding plan). Endpoint/model: glm-5.3-flash @
#     https://api.z.ai/api/coding/paas/v4 — the fleet-verified triple
#     (cv-agent runs it live since 2026-11-02, sops.nix). Key: hermes.yaml
#     glm_api_key exposed as cvagent_ai_api_key + the cvagent-env template.
#     AI failures fall back to rule-based extraction automatically
#     (extractor name recorded per fact).
#   - No HTTP endpoint: daemon-less-unit doctrine — failure alerting rides
#     OnFailure (Discord) + the system-health state metrics.
{ inputs, ... }: {
  flake.nixosModules.cvagent =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      cfg = config.services.cvagent;
      primaryUser = config.users.primaryUser or "lars";
      inherit (import ../../../lib/default.nix lib)
        harden
        serviceOneshotDefaults
        onFailure
        ioTier
        ;
    in
    {
      imports = [ inputs.cvagent.nixosModules.default ];

      config = lib.mkIf cfg.enable {
        services.cvagent = {
          package = lib.mkDefault
            inputs.cvagent.packages.${pkgs.stdenv.hostPlatform.system}.default;

          # Operator identity (cv-profile-probe precedent): the scan reads
          # the whole projects tree and the mesh writes the CV checkout and
          # ~/.local/state — a system user with home protection cannot.
          user = lib.mkDefault primaryUser;
          group = "users";
          dataDir = "/home/${primaryUser}/.local/state/cvagent";

          # No dashboard deployed (daemon-less doctrine); the CLI reaches
          # the service database on PATH via the upstream module.
          serve.enable = false;

          scan = {
            enable = true;
            # meta list --sort-by importance, owner directive 2026-11-04
            # ("all that changed, by importance"): importance >= 80, real code
            # checkouts; templates/forks and the CV export target itself
            # excluded. Order follows the meta ranking. buildflow (95) is NOT
            # here: meta lists it but no local checkout exists
            # (~/projects/buildflow missing, first cycle failed on stat —
            # 2026-11-05 08:40).
            repositories = [
              "/home/lars/projects/go-composable-business-types" # 96
              "/home/lars/projects/go-commit" # 95
              "/home/lars/projects/ai-router-implementation" # 92
              "/home/lars/projects/cmdguard" # 92
              "/home/lars/projects/universal-workflow" # 92
              "/home/lars/projects/timesheets" # 91
              "/home/lars/projects/gogenfilter" # 90
              "/home/lars/projects/SystemNix" # 90
              "/home/lars/projects/erraudit" # 90
              "/home/lars/projects/invoices" # 90
              "/home/lars/projects/go-filewatcher" # 90
              "/home/lars/projects/go-output" # 90
              "/home/lars/projects/go-auto-upgrade" # 90
              "/home/lars/projects/project-discovery-sdk" # 87
              "/home/lars/projects/terraform-to-d2" # 85
              "/home/lars/projects/terraform-diagrams-aggregator" # 85
              "/home/lars/projects/md-go-validator" # 82
              "/home/lars/projects/project-meta" # 80
              "/home/lars/projects/go-business-rules" # 80
              "/home/lars/projects/go-cqrs-lite" # 70
              "/home/lars/projects/Code-To-CV-Agent"
              "/home/lars/projects/go-aichat"
              "/home/lars/projects/monitor365"
            ];
            useAI = true;
            aiModel = "glm-5.3-flash";
            aiBaseUrl = "https://api.z.ai/api/coding/paas/v4";
            # Owner credit ceiling (2026-11-05): one run-level gate. If today
            # already holds >= cap AI facts, the ENTIRE run goes rule-based —
            # spend is bounded even on manual triggers/double runs. Calls ≈
            # facts/20 and linear in credits, so a fact cap is a spend cap.
            # Normal day ≈ 500 AI facts (24 repos × ~20); 600 trips only on
            # anomalies. The fleet-visible meter (ai-meter proxy routing) is a
            # queued follow-up; today cvagent hits z.ai directly.
            aiDailyFactCap = 600;
            # Scan budget: 24 repos at ~2.5 min per repo WITH AI (live
            # 2026-11-05 02:1x battery: gogenfilter 926 commits → 28 AI
            # facts in 2.6 min; the 20min budget killed the run at repo
            # ~13/24, OnFailure paged). Sequential AI calls ≈ 60 min for
            # the full list — 90 min is the generous bound. Bulk work in
            # the 05:53 slot is off-peak by design (ioTier.background).
            timeoutStartSec = "90min";
            calendar = "*-*-* 05:53:00";
            randomizedDelaySec = 600;
            # AI key via sops-rendered env file; OPENAI_API_KEY is read
            # directly by cvagent outside the CVAGENT_* koanf namespace.
            environmentFile = config.sops.templates."cvagent-env".path;
          };

          mesh = {
            enable = true;
            # Combined unit (upstream mesh.runWithScan): scan + mesh in ONE
            # timer, ONE start budget, mesh failure fails the unit, per-repo
            # scan tolerance preserved.
            runWithScan = true;
            targetDir = "/home/lars/projects/CV";
            minConfidence = 0.6;
          };
        };

        systemd.services.cvagent-scan = {
          inherit onFailure;
          serviceConfig = lib.mkMerge [
            {
              Environment = [ "HOME=/home/${primaryUser}" ];
            }
            # The export writes the CV checkout and the fact store under
            # /home, and scans read across the projects tree — the
            # cv-profile-probe precedent: home protection must not apply.
            # mkForce: the upstream scan unit sets ProtectHome=read-only
            # (plain priority beats mkDefault — registry CPUQuota trap).
            (harden {
              ProtectHome = lib.mkForce false;
              MemoryMax = lib.mkForce "512M";
            })
            (serviceOneshotDefaults { })
            ioTier.background
          ];
        };

        # Daemon-less unit: no HTTP endpoint to probe, so monitoring is
        # OnFailure (Discord) + the system-health state metrics. The unit
# name changed cvagent → cvagent-scan with the 2026-11-08 delegation.
        services.system-health.extraMonitoredServices = lib.mkAfter [
          "cvagent-scan"
        ];
      };
    };
}
