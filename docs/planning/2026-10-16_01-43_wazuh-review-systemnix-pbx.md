# Wazuh on SystemNix (evo-x2) + pbx-artmann (pbx.artmann.tech) — Review

**Date:** 2026-10-16 · **Feeds:** the owner ask "review Wazuh for this project and pbx-artmann"; the 2026-09-10 rejection row (external-repo-study item 47: "Wazuh/EDR class — rejected for a personal box; revisit only if threat model changes"); the archived Tier-3 listing (`docs/archive/cybersecurity-tools-evo-x2.md`). **Context:** CrowdSec was DECIDED 2026-10-14 (stage 1 in-tree, live verification pending — see the [watch] row in docs/todo/services.md), so the open question is whether Wazuh adds anything on top of the decided stack — on either host.

**Verification discipline:** nixpkgs-package claims verified against BOTH pinned store trees locally (SystemNix `7fd4004d`, pbx-artmann `55bfb4d`, resolved via `nix flake metadata`, read 2026-10-16; CrowdSec found by the same search as the positive control). Wazuh requirements fetched from official docs 2026-10-16. nixpkgs-history claims extracted via GitHub issue search 2026-10-16 (summarizer-mediated; corroborated by the local absence finding). Repo-side claims from local file reads, 2026-10-16.

---

## 1. What Wazuh is (one paragraph)

Wazuh is an open-source SIEM/XDR platform: a **wazuh-manager** detection engine (log decoders/rules, file-integrity monitoring via syscheck, rootkit checks via rootcheck, security-configuration assessment, vulnerability detection) fed by lightweight **agents** on each monitored host, plus a **wazuh-indexer** (OpenSearch fork) that stores alerts and a **wazuh-dashboard** UI. Current release: 4.14 (official docs, 2026-10-16).

## 2. Verified hard facts

| Claim | Status | Source |
| --- | --- | --- |
| `wazuh` ABSENT from SystemNix's pinned nixpkgs `7fd4004d` — no package, no NixOS module | ✅ Verified | store tree read (`pkgs/by-name/wa/`, `pkgs/**`, `nixos/modules/**`), 2026-10-16 |
| `wazuh` ABSENT from pbx-artmann's pinned nixpkgs `55bfb4d` (same method) | ✅ Verified | store tree read, 2026-10-16 |
| Wazuh never landed in nixpkgs at all: PRs #308041/#309573 (agent init) closed UNMERGED (last closed as stale 2024-10); package requests #259304/#267698/#274913/#350236 closed; tracking issue #230623 closed as not planned 2026-10-09 | ✅ Verified | GitHub issue/PR search (2026-10-16); blockers named in the thread: GCC-breakage, bundled deps, FHS/root assumptions vs the Nix build model, maintainer inactivity |
| All-in-one quickstart sizing: 1–25 agents = 4 vCPU / **8 GiB RAM** / 50 GB (90 days alerts); manager min 2 GB/rec 4 GB + **20 GB free disk** (`/var/ossec`, vuln-detection DB ≈ 11 GB unpacked); indexer min 4 GB/rec 16 GB; dashboard min 4 GB | ✅ Verified | documentation.wazuh.com quickstart + component install guides (fetched 2026-10-16) |
| Agent resource floor: NOT published by upstream ("lightweight") | ✅ Verified | same docs — treat any specific agent-RAM number as unverified |
| Community Nix packaging exists OUTSIDE nixpkgs (wazuh-agent-nixos / wazuh.nix flakes) | ⚠️ Unverified lead | named in nixpkgs #230623; not audited — do not build a verdict on them |

## 3. The two threat models + existing coverage (repo facts, 2026-10-16)

**evo-x2 (SystemNix).** LAN-bound homelab server/desktop behind the household firewall. The 2026-09-10 verdict rejected the Wazuh/EDR class for exactly this profile. Threat-model delta since then: an internet-facing PBX now exists, evo-x2 pulls its backups, and the two hosts are NetBird peers. Coverage in flight: **CrowdSec** (decided 2026-10-14, stage 1 in-tree: `modules/nixos/services/crowdsec.nix`, ports `crowdsec-lapi 8082` / `crowdsec-metrics 6061`), SigNoz three-pillar observability, gatus, per-service `harden{}` systemd, sops.

**pbx.artmann.tech (pbx-artmann).** Internet-facing Hetzner VPS, 8 GB-class (README: CX32/CAX21+ floor), disposable by design (~30 min rebuild from git + published installer). Surfaces: SIP 5060/5061 (FreeSWITCH), 443 webphone, Telnyx webhooks, Stalwart mail, NetBird control plane, Pocket-Id-backed oauth2-proxy gates. Coverage live: fail2ban (SIP + nginx-scanner jails, since 2026-10-07), 403-storm watchdog, `telephony-health` 60 s watchdog with OnFailure relay. Queued: Telnyx source-CIDR hardening; **the alert sink** (TODO_LIST line 305: two relays exist, NEITHER pages anywhere — 10-min owner pick).

## 4. Fit analysis — why NO on both hosts

**4.1 Wazuh on the PBX box itself: infeasible.** The all-in-one floor is 8 GiB RAM + 20 GB disk (manager vuln-DB alone ≈ 11 GB) with the indexer recommending 16 GiB — on the box that exists to move calls, whose whole doctrine is "no new monitoring stack — a webhook token, not Prometheus" (2026-09-17 planning). A SIEM that eats the PBX is not defense, it is a second outage mode.

**4.2 Agent-only on the PBX, manager on evo-x2 over NetBird: clean shape, still NO.** The architecture is attractive — both hosts are already NetBird peers (since 2026-10-14), so agent traffic rides the encrypted overlay with zero new internet ports, and evo-x2 has RAM to spare. The killer is the same one nixpkgs refused for three years: **the manager must be self-packaged** (C components + bundled deps + FHS/root assumptions), forever, for a security-critical component whose upstream moves fast. An unmaintained Wazuh manager is itself a vulnerability — this plan converts "no SIEM" into "stale SIEM", the worst of the options.

**4.3 Capability-by-capability, Wazuh's pillars are already owned or redundant here:**

| Wazuh capability | Already covered / why redundant |
| --- | --- |
| Log analysis (the core) | SigNoz three-pillar stack runs on evo-x2; journald persists on the PBX; the PBX doctrine rejects a second analytics stack |
| Scanner/brute-force detection | The PBX's real internet threat — owned by fail2ban (live) + 403-storm watchdog (live); CrowdSec (decided) is the modernized successor class on evo-x2 |
| File integrity (syscheck) | Largely redundant on NixOS: immutable `/nix/store` + declarative `/etc` + rebuild-from-git IS the integrity model; runtime-mutable dirs are few and enumerated |
| Vulnerability detection | Wazuh's CVE matching is distro-package oriented (deb/rpm); NixOS inventory maps poorly to `/nix/store` paths — a wrong-tool fit |
| Rootkit checks (rootcheck) | Marginal on a disposable box rebuilt from git in ~30 min |

**4.4 The "threat model changed" trigger — answered honestly.** The PBX IS the threat-model change the 2026-09-10 verdict anticipated. But the correct response to that change already landed: CrowdSec (decided 2026-10-14) + pbx fail2ban/watchdogs (live) + Telnyx CIDR hardening (queued). Re-affirming the rejection under the NEW model is consistent, not stubborn — none of Wazuh's incremental capabilities address a threat the current stack misses.

## 5. Verdict

- **evo-x2: NO** — the 2026-09-10 rejection is REAFFIRMED, now with the changed-threat-model question explicitly examined (§4.4) instead of open.
- **pbx-artmann: NO** — capacity-infeasible on-box (§4.1), packaging-infeasible distributed (§4.2).
- **The one actionable security gap this review found is pre-existing and is not Wazuh's to fix:** the PBX alert sink (pbx-artmann TODO_LIST line 305 — owner picks ntfy.sh/healthchecks.io/Discord, ~10 min). Wazuh would not have improved it; the relays already fire, nothing pages.
- **Reopen triggers** (any ONE is enough to re-run this review): a maintained wazuh package + NixOS module lands in nixpkgs; a compliance/regulatory requirement appears; the estate grows to ≥3 internet-facing multi-user services making central vuln-mgmt/FIM a real ask; or Wazuh ships first-class Nix support upstream.

## Verification status

| Claim | Status | Source |
| --- | --- | --- |
| Package/module absence in both pins; CrowdSec positive control | ✅ Verified | local store trees `7fd4004d` / `55bfb4d`, 2026-10-16 |
| Wazuh 4.14 current; AIO 8 GiB/50 GB (1–25 agents); manager 2/4 GB + 20 GB disk; indexer 4/16 GB; dashboard 4/8 GB; no published agent floor | ✅ Verified | official docs (fetched 2026-10-16); numbers quoted from quickstart + component pages |
| nixpkgs history (PRs/issues, closures, blocker reasons) | ✅ Verified with caveat | GitHub search via AI fetch (summarizer-mediated 2026-10-16) — corroborated by the primary local absence evidence; exact issue numbers spot-plausible, conclusion load-bearing |
| Community Nix flakes (wazuh-agent-nixos, wazuh.nix) exist and work | ❌ Unverified lead | named in nixpkgs #230623, not audited |
| pbx coverage claims (fail2ban live 2026-10-07, watchdogs, doctrine quote, TODO line 305) | ✅ Verified | pbx-artmann README/FEATURES/TODO_LIST/docs read 2026-10-16 |
| SystemNix coverage claims (CrowdSec decided/stage-1 in-tree, ports, SigNoz) | ✅ Verified | docs/todo/security.md + docs/todo/services.md + lib/ports.nix read 2026-10-16 |
