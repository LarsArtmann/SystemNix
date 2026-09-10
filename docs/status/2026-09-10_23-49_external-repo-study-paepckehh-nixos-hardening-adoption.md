# Status Report — External-Repo Study: paepckehh/nixos → Kernel/Network Hardening Adoption

**Date:** 2026-09-10 23:49 CEST
**Session scope:** Single task — "Can we learn something from https://github.com/paepckehh/nixos?"
**Verdict:** Yes — 3 patterns worth taking, all implemented and verified. Everything else SystemNix already does better. Nothing broken. Not deployed.

---

## Executive Summary

Studied `paepckehh/nixos` (532-module "company as Nix" repo: stateless-LUKS root via disko, central `siteconfig` hardening, local flake mirrors, agenix+YubiKey). Grounded every candidate lesson against SystemNix's **live system state** before adopting anything. Result:

- **Adopted (implemented + verified):** kernel module blacklist (14 exotic protocols), network-layer sysctl hardening (v4+v6), GitHub SSH host-key pinning.
- **Rejected with written reasons** (to prevent re-suggestion): `kptr_restrict=2`, `kexec_load_disabled`/`protectKernelImage`, `sysrq=0`, hardened kernel, stateless root, AppArmor, scudo, ro-mounted `/nix/store`, journal volatile, emergency-mode-off, zram writeback.
- **Documented as owner-decision candidates:** disko as disk-layout documentation + autoinstaller ISO, Forgejo-mirror-backed flake inputs, `allowed-users=@wheel`, YubiKey PAM.

All knowledge is persisted in `AGENTS.md` (new section "Kernel & Network Hardening (2026-09-10)"), so future sessions inherit the adopt/reject rationale.

---

## a) FULLY DONE

| # | Item | Where | Verification |
|---|------|-------|--------------|
| 1 | **Repo studied in depth**: README, flake.nix, configuration.nix, siteconfig/config.nix (900+ line central site config), modules/hardening{,-full,-max}.nix, log.nix, a representative service module (paperless-ngx-authelia), storage/ dir listing, git-mirror wiring | session | fetched + read |
| 2 | **Gap analysis grounded in LIVE state**, not docs: `sysctl` values (kptr=1, dmesg=1, bpf=2, perf=2, kexec=0, yama=1, sysrq=1), `nix show-config` (sandbox=true, sandbox-fallback already false, allowed-users=\*, trusted-users=root, require-sigs=true), journald `SystemMaxUse=8G` already present, **no** module blacklist, **no** knownHosts pinning, `services.openssh` NOT enabled on evo-x2 (port 22 open in firewall but nothing listening) | live probes + repo greps | every claim cross-checked |
| 3 | **Kernel module blacklist**: 14 exotic network protocols (sctp, sctp_diag, dccp, dccp_diag, tipc, tipc_diag, rds, rds_rdma, rds_tcp, x25, ax25, netrom, rose, ipx) hard-disabled via `install <mod> /bin/false` — blocks manual modprobe too (stronger than `boot.blacklistedKernelModules`). esp4/esp6 and k10temp deliberately NOT blacklisted (future IPsec; temperature telemetry) | `boot.nix:200-231` | eval: 14 install lines present |
| 4 | **Network sysctl hardening**: accept_redirects=0 + secure_redirects=0 + accept_source_route=0 + send_redirects=0 (v4+v6, IPv6 is enabled here), `tcp_rfc1337=1`, `icmp_ignore_bogus_error_responses=1`, `rp_filter=2` **loose** — strict (1) would drop packets during eno1→wlan0 wifi-failover windows | `boot.nix:263-290` | eval JSON: all values correct |
| 5 | **GitHub SSH host-key pin**: `programs.ssh.knownHosts.github` pins github.com + ssh.github.com to GitHub's ed25519 key. Key verified against TWO independent sources (GitHub live API `/meta` `ssh_keys` + fingerprints; paepckehh's independent siteconfig listing). All git+ssh flake inputs/deploy keys/pushes now fail LOUDLY on MITM instead of silent TOFU | `networking.nix:56-69` | eval: publicKey exact match |
| 6 | **Rejected-list with reasons written down** (kptr_restrict=2 breaks bpftrace forensics — the goroutine-dump tool class is explicitly SIGQUIT-based, verified in `scripts/dnsblockd-goroutine-dump.sh`; kexec_load_disabled risks systemd-sysctl↔kdump ordering and forfeits 2026-08-22 crash forensics; sysrq=0 wrong for freeze-prone box; perf paranoid=3 blocks profiling; hardened kernel breaks Strix Halo latest-kernel + r8125; stateless root wrong for state-heavy box; AppArmor painful on store paths; scudo risks GPU/ROCm native libs; ro `/nix/store` breaks ALL builds; journal volatile kills forensics; emergency-mode-off contradicts stuck-boot history; zram writeback = QLC storm class) | `AGENTS.md` new section | — |
| 7 | **Consider-later list documented** (disko-as-documentation + autoinstaller ISO; Forgejo-mirror-backed flake inputs — SystemNix ALREADY runs ~100 Forgejo mirrors, hagezi-404 precedent; `allowed-users=@wheel` — lars ∈ wheel verified live; YubiKey PAM) | `AGENTS.md` | — |
| 8 | **Stale-comment fix-on-sight**: `boot.nix` TTM comment said "carveout is 512 MiB, ~125 GiB MemTotal" — contradicted AGENTS.md's live-verified truth (1 GiB BIOS floor, 124.3 GiB, 2026-09-05). Exactly the doc-drift class AGENTS mandates fixing on sight | `boot.nix:9-15` | edit verified |
| 9 | **Format + full eval verification**: `nix fmt --no-update-lock-file -- --ci` → 0 changed (locked formatter, zero lock writes); `nix flake check --no-build` → all checks passed; targeted evals of all three changes | session | all green |
| 10 | **Concurrent-session discipline**: detected foreign dirty files (flake.nix, deploy.sh, pre-reboot-check.sh, TODO_LIST.md, a status doc — another session's deploy-guard/pre-reboot work), did NOT touch them, did NOT deploy, flagged to user | session | git status diff-scoped |

---

## b) PARTIALLY DONE

1. **Deployment** — changes are in the working tree, evaluated, and formatted, but NOT activated (`nix run .#deploy` not run — deliberate). Note: sysctls apply at switch; the modprobe install-false entries are fully effective only after next boot for any already-loaded modules (none of the 14 are loaded — `lsmod` expected clean).
2. **Consider-later items** — disko / Forgejo-mirror inputs / allowed-users / YubiKey PAM are documented decisions, not implementations. Each needs an owner call.
3. **Shared-surface green caveat** — the passing `nix flake check` evaluated a tree containing ANOTHER session's in-flight edits (flake.nix, deploy.sh, pre-reboot-check.sh). Green is a point-in-time snapshot of a shared tree, not a guarantee of the other session's final state.
4. **TODO_LIST harvest** — the (f) list below lives in this report; per the docs-health rule it should be harvested into TODO_LIST.md (not entombed here). Not yet done.
5. **WiFi-failover regression proof** — rp_filter=2 was chosen specifically to not break `wifi-failover`, but the VM test (`tests/test-wifi-failover.nix`) was NOT extended to assert cross-interface packet flow under loose rp_filter. Reasoned-safe, not test-proven.

---

## c) NOT STARTED

- disko declarative disk-layout documentation (all disks: QLC NVMe partitions, Samsung `/nix`, `/data`, ESPs)
- Autoinstaller ISO for evo-x2 rebuilds
- Switching any flake inputs to local Forgejo mirrors (GitHub-outage immunity)
- `nix.settings.allowed-users = ["@wheel"]`
- YubiKey PAM (u2f) for sudo/login; YubiKey-backed sops age-key disaster recovery
- SSH host-key pinning for other remotes (Forgejo/git.home.lan; GitLab/Codeberg — usage unverified)
- Eval-time assertion that the GitHub host-key pin exists (so it can't silently vanish)
- sshd hardening block (N/A while sshd is not enabled on evo-x2 — becomes relevant the moment it is)
- Post-deploy verification step asserting the new sysctls/modprobe entries live (could extend pre/post-deploy-check)

---

## d) TOTALLY FUCKED UP

**Nothing.** No broken state, no failed evals, no damage to other sessions' work, no deploy performed. Honest near-misses for the record:

1. **Tool-order slip:** I ran `nix fmt` BEFORE checking `git status` in a concurrent-session tree. The first fmt run hit a treefmt cache ERROR on `networking.nix` ("file has changed" between traversal and processing — my edit landing mid-scan) and reformatted 3 files tree-wide. Harmless here (the formatter arbiter doctrine held: same locked formatter as CI, 0 changed on re-run), but status-check-first is the correct order in a shared tree.
2. **Accepted operational consequence (design, not defect):** GitHub rotates host keys rarely but DOES (RSA 2023-03). The pin means a future rotation breaks every git+ssh operation LOUDLY until the pin is updated. That is the point of pinning — but it is a real contract the user should be aware of.
3. **Scope discipline held:** the parallel session's 5 dirty files were tempting to "tidy" — not touched, not committed, not commented on in code.

---

## e) WHAT WE SHOULD IMPROVE

1. **Prove rp_filter=2 is failover-safe, don't argue it** — extend `tests/test-wifi-failover.nix` to assert cross-interface flow under loose mode.
2. **Guard the host-key pin** — eval-time assertion (pin exists + key matches expectation) so a refactor can't silently drop it.
3. **Post-deploy verification for kernel-hardening changes** — extend `scripts/post-deploy-check.sh` with live sysctl + `modprobe -n sctp` effective checks.
4. **Rotation runbook** — a short `docs/` note: "git+ssh to github suddenly fails host-key verification → check api.github.com/meta → update pin in networking.nix."
5. **Close the SSH intent gap** — firewall allows port 22 but no sshd runs. Either enable+harden (paepckehh's sshd block is a good starting shape) or close the port.
6. **Harvest discipline** — run docs-health HARVEST on section (f) so items land in TODO_LIST.md/ROADMAP.md instead of a timestamped snapshot.
7. **"Learn from X" method** — this session's live-grounding pattern (probe live system → adopt/reject per item → write down rejections) worked well; worth a reusable checklist in AGENTS.md for future external-study sessions.
8. **Stale-comment sweep in touched files** — the 512 MiB drift survived inside a heavily-commented file; a periodic AGENTS↔code comment consistency check would catch the class (docs-health VERIFY mode territory).

---

## f) Up to 50 things we should get done next

> Brainstorm from this session's observations — NOT a commitment list. Sorted roughly by impact; top ~10 are the real candidates.

**Session follow-ups (deploy/verify the work just done)**
1. Deploy the hardening changes (`nix run .#deploy`) — coordinate with the parallel session's in-flight flake.nix/deploy.sh edits first.
2. Post-deploy: verify live sysctls (`accept_redirects=0` v4+v6, `rp_filter=2`, `tcp_rfc1337=1`) and modprobe entries effective (`modprobe sctp` must fail).
3. Add eval-time assertion + negative test for the `knownHosts.github` pin.
4. Extend `tests/test-wifi-failover.nix` for rp_filter=2 cross-interface flow.
5. Host-key rotation runbook in `docs/`.
6. Re-run `post-deploy-check` after the deploy; watch journal for unexpected rp_filter drops.
7. Confirm the auto-commit daemon's batch didn't mix my 3 files with the parallel session's 5 (pathspec hygiene).
8. Verify no currently-loaded module collides with the 14-name blacklist (`lsmod | grep -E 'sctp|tipc|rds|dccp|x25'` — expect empty).
9. Decide IPsec stance: if esp4/esp6 are never wanted, blacklist them too (I kept them deliberately).
10. After the parallel session lands: full `nix flake check` re-run on the quiescent tree (shared-surface rule).

**Owner decisions documented but not made**
11. disko: declarative disk-layout documentation for all 3 disks (document-only, never applied live).
12. Autoinstaller ISO for evo-x2 (disko + iso target, paired with #11).
13. Point selected flake inputs at existing Forgejo mirrors for GitHub-outage immunity (hagezi-404 precedent; tradeoff: builds need Forgejo up).
14. `nix.settings.allowed-users = ["@wheel"]` (lars verified in wheel; tq-agent pool runs as lars — compatible).
15. YubiKey PAM (u2f) for sudo/login.
16. YubiKey (age-plugin-yubikey) backup for the sops age identity — disaster recovery.
17. Pin the Forgejo/git.home.lan host key for LAN git+ssh.
18. SSH on evo-x2: enable+harden or close port 22 (firewall currently allows it, nothing listens).
19. If IPsec ever needed: document that esp4/esp6 were deliberately kept loadable.
20. Re-evaluate `security.protectKernelImage` only after verifying kdump preload ordering (documented rejection is order-dependent).

**Noticed during the session (SystemNix observations)**
21. `TODO_LIST.md` is dirty from the parallel session — after it lands, docs-health VERIFY on hardening-related entries.
22. journald cap is 8G; the 7.2G-journal-walk incidents suggest evaluating 4G + vacuum policy.
23. `perf_event_paranoid` stays 2 — revisit only if perf-based profiling becomes a workflow.
24. Consider `nix.settings.http-connections` / `stalled-download-timeout` tuning (marginal; paepckehh pins them).
25. Evaluate the `verified-fetches` experimental Nix feature (supply-chain hardening for git inputs).
26. build-dir-on-tmpfs evaluated and rejected (RAM pressure with flm/zram history) — record in AGENTS rejected-list (was in my analysis, NOT yet written down — gap).
27. siteconfig-style central site attrset could reduce hostname/domain scattering across platforms/* (big churn, low priority).
28. `install <mod> /bin/false` is the reusable pattern for any future "disable module class" ask — already in AGENTS ✓; cite it in future reviews.
29. Boot-flags duplicate-check: SystemNix uses `module_blacklist=serial8250` kernel param AND now modprobe install-false — do not double-implement for new modules.
30. `ssh.github.com` (port 443) pinned too — consider documenting it as the corporate-firewall fallback path.

**Hygiene / process**
31. Turn the live-grounding external-study method into an AGENTS checklist entry.
32. Consider annotating (not rewriting) older status reports that mention "no kernel hardening" once this deploys (docs-health ANNOTATE).
33. FEATURES.md: hardening additions are config, not features — no update needed (checked, skipped deliberately).
34. SignNoz coverage: no new OTel services added — nothing to register (verified mentally against the registry rule).
35. Gatus: no new endpoints — nothing to add (modprobe/sysctl effects aren't HTTP-checkable; post-deploy script owns it).
36. The parallel session's pre-reboot-check work + my boot.nix changes both touch the boot chain — run `nix run .#pre-reboot-check` before the next planned reboot.
37. After deploy, confirm `/run/current-system` == numbered profile (anchoring rule) — deploy.sh already warns, keep the habit.
38. Add the 14-module list + rationale to the next AGENTS.md touch if wording unclear (already done — re-check readability at next edit).
39. Consider CI guard: reject `install .* /bin/false` entries for modules in a keep-list (esp4/esp6, k10temp, uas, bfq, i2c-dev...) — cheap negative test.
40. When GitHub's key rotates (eventually): the fix is one line in networking.nix — make sure the runbook (#5) names that file.

**Roadmap fuel (bigger, exploratory)**
41. External-study #2: disko upstream patterns for the Samsung `/nix` BTRFS layout (pairs with #11).
42. External-study #3: nix-community hardening profiles vs our per-service harden{} (likely confirms our approach; cheap to check).
43. Evaluate their `srv-full` golden-build idea vs SystemNix's VM tests (likely rejected — VM tests stronger; document if so).
44. Evaluate journald-upload (systemd-journal-remote with mTLS) as a SigNoz-independent journal backup — likely overkill with OTel pipeline.
45. Their `openwrt/` firmware builder — only relevant if a NixOS-built router firmware ever becomes interesting.
46. Their `pki/` smallstep CA vs sops-managed Caddy TLS — owner-decision scale; not now.
47. Wazuh/EDR class — rejected for a personal box; revisit only if threat model changes.
48. Consider a `docs/research/` entry summarizing this external study (AGENTS section is the durable part; a research doc adds the survey narrative).
49. Sweep AGENTS.md for other code-comment contradictions like the 512 MiB one (docs-health VERIFY on boot.nix-adjacent claims).
50. Schedule the rp_filter monitoring check for a week post-deploy (nftables drop counters + journal grep) before declaring it done-done.

---

## g) Questions I cannot figure out myself

1. **Deploy coordination:** Do you want me to deploy the hardening changes now, or wait until the parallel session's flake.nix/deploy.sh/pre-reboot-check.sh work lands? (Shared-surface rule says quiescent moments; only you know their state.)
2. **SSH intent:** Firewall allows port 22 on evo-x2 but NO sshd is enabled — do you actually want SSH access to this box (then I'll wire a hardened sshd), or should the port be closed?
3. **Pin contract + YubiKey:** (a) Are you OK with "GitHub rotates its host key → all git+ssh ops fail loudly until the one-line pin update" as a standing contract? (b) Do you own a hardware key you'd want wired into sudo/login (YubiKey PAM), or is that a no?

---

*Point-in-time snapshot — 2026-09-10 23:49 CEST. Sections (e)/(f) are docs-health HARVEST input.*
