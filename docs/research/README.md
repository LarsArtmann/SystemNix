# Research Reports Index

One row per report in this directory: subject, date, and the trigger that
should refresh it. Sorted newest-first. Maintained by hand — add a row when
you add a report (the row's refresh-trigger is what keeps these from rotting;
`checks.doc-counts` does NOT police this file yet).

Doctrine (F08 errata, 2026-10-26): every audit-style deep dive MUST include
a live-probe phase — curl the library's live API/metrics/journal surface
before scoring a finding. Config presence proves intent, not behavior.

## Library deep dives (audit-style, scored)

| Report | Date | Subject | Refresh trigger |
|---|---|---|---|
| [2026-10-25_caddy-deep-dive.html](2026-10-25_caddy-deep-dive.html) | 2026-10-25 | Caddy edge adoption audit (89/100, 3 findings — all adopted same day) | next caddy major bump, helper/vHost architecture change |
| [2026-10-16_agent-router-deep-dive.html](2026-10-16_agent-router-deep-dive.html) | 2026-10-16 | Agent router evaluation | upstream major release / new AI-stack consumer |
| [2026-10-02_paperless-ngx-ai-deep-dive.html](2026-10-02_paperless-ngx-ai-deep-dive.html) | 2026-10-02 | Paperless AI pipeline audit | paperless-ngx major bump |
| [2026-09-30_dnsblockd-deep-dive.html](2026-09-30_dnsblockd-deep-dive.html) | 2026-09-30 | dnsblockd adoption audit | dnsblockd major feature (DoQ, HA) |
| [2026-09-18_forgejo-deep-research.html](2026-09-18_forgejo-deep-research.html) | 2026-09-18 | Forgejo adoption audit | forgejo major bump |
| [2026-07-21_monitor365-flake-deep-dive.html](2026-07-21_monitor365-flake-deep-dive.html) | 2026-07-21 | Monitor365 flake audit | monitor365 module restructure |
| [2026-07-21_discordsync-flake-deep-dive.html](2026-07-21_discordsync-flake-deep-dive.html) | 2026-07-21 | Discordsync flake audit | discordsync module restructure |
| [2026-05-11_STRIX-HALO-LINUX7-GPU-ARCHITECTURE-DEEP-DIVE.md](2026-05-11_STRIX-HALO-LINUX7-GPU-ARCHITECTURE-DEEP-DIVE.md) | 2026-05-11 | Strix Halo GPU architecture on Linux 7.x | kernel bump touching amdgpu/TTM/GTT (AGENTS.md GPU section supersedes details) |

## Evaluations & comparisons

| Report | Date | Subject | Refresh trigger |
|---|---|---|---|
| [2026-09-29_signoz-grafana-gap-analysis.md](2026-09-29_signoz-grafana-gap-analysis.md) | 2026-09-29 | SigNoz vs Grafana gaps | SigNoz major bump / dashboard pain that Grafana solves |
| [coroot-evaluation.md](coroot-evaluation.md) | — | Coroot observability evaluation | only if SigNoz is ever questioned |
| [deepflow-evaluation.md](deepflow-evaluation.md) | — | DeepFlow observability evaluation | only if SigNoz is ever questioned |
| [observability-signoz-to-victoriametrics.md](observability-signoz-to-victoriametrics.md) | — | VictoriaMetrics migration sketch | only if SigNoz is ever questioned |
| [youtube-frontend-alternatives.md](youtube-frontend-alternatives.md) | — | YouTube frontend alternatives | if an invidious-class service is ever deployed |
| [cloud-backup-pricing-2026-05.md](cloud-backup-pricing-2026-05.md) | 2026-05 | Offsite backup pricing | before any offsite-contract decision (see storage.md) |

## Integration & architecture studies

| Report | Date | Subject | Refresh trigger |
|---|---|---|---|
| [2026-10-11_decentralized-offsite-backup-review.md](2026-10-11_decentralized-offsite-backup-review.md) | 2026-10-11 | Offsite backup design review | storage architecture change |
| [2026-10-11_forgejo-sarif-support-community-sentiment.md](2026-10-11_forgejo-sarif-support-community-sentiment.md) | 2026-10-11 | Forgejo SARIF upstream sentiment | before re-proposing SARIF upstream |
| [2026-10-02_paperless-ngx-ai-internet-sweep.md](2026-10-02_paperless-ngx-ai-internet-sweep.md) | 2026-10-02 | Paperless AI internet sweep | paperless AI pipeline rework |
| [2026-10-01_ecapture-integration-assessment.md](ecapture-integration-assessment.md) | — | eCapture integration assessment | kernel-bpf trace needs |
| [2026-09-10_taciturnaxolotl-dots-review-vs-systemnix.md](2026-09-10_taciturnaxolotl-dots-review-vs-systemnix.md) | 2026-09-10 | External dotfiles review vs SystemNix | desktop restructure |
| [2026-09-05_btrfs-internet-sweep-vs-systemnix.md](2026-09-05_btrfs-internet-sweep-vs-systemnix.md) | 2026-09-05 | BTRFS best practices vs this repo | storage.md doctrine change |
| [2026-08-01_open-web-index-searxng-semantic-search.md](2026-08-01_open-web-index-searxng-semantic-search.md) | 2026-08-01 | SearXNG semantic search | search vHost rework |
| [2026-07-11_nixos-btrfs-wiki-recommendations.md](2026-07-11_nixos-btrfs-wiki-recommendations.md) | 2026-07-11 | BTRFS wiki recommendations review | storage.md doctrine change |
| [2026-06-02_activitywatch-aw-server-macos-data-read-analysis.md](2026-06-02_activitywatch-aw-server-macos-data-read-analysis.md) | 2026-06-02 | ActivityWatch macOS data paths | activitywatch module change |
| [immich-server-nixos-isolation.md](immich-server-nixos-isolation.md) | — | Immich NixOS isolation | immich module restructure |
| [mitmproxy-activitywatch-integration.md](mitmproxy-activitywatch-integration.md) | — | mitmproxy → ActivityWatch capture | watcher changes |
| [quickshell-desktop-shell-replacement.md](quickshell-desktop-shell-replacement.md) | — | Quickshell/DMS shell decision | desktop.md shell change |
| [reticulum-network-assessment.md](reticulum-network-assessment.md) | — | Reticulum mesh assessment | net-vpn architecture work |

## Nix ecosystem & migration studies

| Report | Date | Subject | Refresh trigger |
|---|---|---|---|
| [NIX-COLORS-INTEGRATION-IMPLEMENTATION-REPORT.md](NIX-COLORS-INTEGRATION-IMPLEMENTATION-REPORT.md) | — | nix-colors integration | theme.nix restructure |
| [UNIXPORN_NIXOS_ANALYSIS.md](UNIXPORN_NIXOS_ANALYSIS.md) | — | r/unixporn NixOS patterns review | desktop restructure |
| [REBUILDING-QUBES-IN-NIXOS.md](REBUILDING-QUBES-IN-NIXOS.md) | — | Qubes-style isolation in NixOS | compartmentalization work |
| [hetzner-storagebox-borgbackup.md](hetzner-storagebox-borgbackup.md) | — | Hetzner StorageBox + Borg design | offsite backup change |
| [home-manager-users-workaround-bug-report.md](home-manager-users-workaround-bug-report.md) | — | HM multi-user workaround bug report | upstream fix landing — retire the workaround |
