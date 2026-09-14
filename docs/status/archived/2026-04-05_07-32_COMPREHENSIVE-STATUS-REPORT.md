# Comprehensive Status Report — 2026-04-05 07:32

**Session Date:** 2026-04-05 07:32:32
**Branch:** master
**Last 5 Commits:**

```
6668f40 fix(nixos): enable HTTPS for Gitea by updating ROOT_URL protocol
8b997ff fix(nixos): update Authelia session redirect URL from home to dash subdomain
d860ef2 docs(status): replace post-deploy service failures report with comprehensive incident analysis
8bb67e0 fix(nixos): migrate all services from *.lan to *.home.lan domain and fix multiple post-deploy failures
a7e3b00 docs(reports): add eCapture TLS capture integration assessment with NOT recommended verdict
```

---

## A) FULLY DONE ✅

| Item                             | Status               | Details                                                                                |
| -------------------------------- | -------------------- | -------------------------------------------------------------------------------------- |
| AppArmor disabled                | ✅ Already done      | `apparmor.enable = false` in `security-hardening.nix:41` — was set in commit `a7e3b00` |
| Prometheus removal               | ✅ Complete          | No remaining `prometheus` references in any `.nix` file                                |
| `*.lan` → `*.home.lan` migration | ✅ Complete          | All 35 domain references use correct format                                            |
| AppArmor comment cleanup         | ✅ Done this session | Removed stale "AppArmor conflicts" references from audit TODOs                         |
| eCapture evaluation              | ✅ Done              | NOT RECOMMENDED verdict documented in `docs/reports/`                                  |
| DeepFlow evaluation              | ✅ Done              | Report in `docs/reports/`                                                              |
| Nix syntax validation            | ✅ Passes            | `just test-fast` passes cleanly                                                        |
| Coroot evaluation report         | ✅ Written           | Staged: `docs/reports/coroot-evaluation.md`                                            |

---

## B) PARTIALLY DONE 🔶

| Item                       | Status  | What's Left                                                                   |
| -------------------------- | ------- | ----------------------------------------------------------------------------- |
| Audit daemon re-enablement | Blocked | 2 TODOs in `security-hardening.nix` — blocked by upstream NixOS bug (#483085) |

---

## C) NOT STARTED ⬜

### Critical Issues Found During Audit

| #  | Issue                                                                                                                             | Priority    | File                                                        |
| -- | --------------------------------------------------------------------------------------------------------------------------------- | ----------- | ----------------------------------------------------------- |
| 1  | **Duplicate fail2ban config** — conflicting settings in `configuration.nix` and `security-hardening.nix`                          | 🔴 CRITICAL | `configuration.nix:154-178`, `security-hardening.nix:58-88` |
| 2  | **Orphaned Grafana fail2ban jail** — Grafana never deployed, jail watches non-existent log file                                   | 🔴 CRITICAL | `security-hardening.nix:78-86`                              |
| 3  | **Dead package** — `pkgs/superfile.nix` has `vendorHash = null` and is unreferenced                                               | 🔴 CRITICAL | `pkgs/superfile.nix`                                        |
| 4  | **Duplicate packages** — `gnupg`, `foot`, `zellij`, `swappy`, `jq`, `wl-clipboard`, `rofi`, `cliphist` defined in multiple places | 🟡 HIGH     | Multiple files                                              |
| 5  | **Duplicate Go overlay** — defined in `flake.nix` AND `platforms/darwin/default.nix`                                              | 🟡 HIGH     | `flake.nix:139-147`, `darwin/default.nix:66-82`             |
| 6  | **Unused `nix-visualize` specialArg** — passed to both platforms but never used in modules                                        | 🟡 HIGH     | `flake.nix`                                                 |
| 7  | **Stale commented imports** in `configuration.nix` referencing removed services                                                   | 🟢 LOW      | `configuration.nix:21-29`                                   |
| 8  | **Orphaned `ssh-banner` file** — exists but never referenced                                                                      | 🟢 LOW      | `platforms/nixos/users/ssh-banner`                          |
| 9  | **Outdated justfile text** — "Go 1.26rc2" should be "Go 1.26.1"                                                                   | 🟢 LOW      | `justfile:1078`                                             |
| 10 | **Stale monitoring recipes** — netdata/ntopng recipes for macOS LaunchAgents                                                      | 🟢 LOW      | `justfile:866-916`                                          |
| 11 | **Orphaned `better-claude` recipes** — reference non-existent package                                                             | 🟢 LOW      | `justfile:1296-1323`                                        |
| 12 | **Overlapping system monitors** — `bottom`, `btop`, `htop` all installed                                                          | 🟢 LOW      | `base.nix:104-107`                                          |

---

## D) TOTALLY FUCKED UP 💥

| Item                            | What Happened                                                                                                                                                                                                                          | Impact                                                                                        |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| AppArmor disable (this session) | I edited `security-hardening.nix` to set `apparmor.enable = false` and updated comments — but the file **already had** `apparmor.enable = false` from commit `a7e3b00`. My edit was a no-op. I wasted time re-doing work already done. | Zero impact on config, but wasted session time. Lesson: check committed state before editing. |

---

## E) WHAT WE SHOULD IMPROVE

1. **Pre-edit verification** — Always `git diff HEAD` before editing to confirm the change isn't already committed
2. **Deduplication pass** — Remove all duplicate package definitions; pick one canonical location
3. **Dead code cleanup** — Delete `pkgs/superfile.nix`, orphaned `ssh-banner`, stale justfile recipes
4. **Fail2ban consolidation** — Single source of truth, remove Grafana jail
5. **Go overlay consolidation** — Define once, share across platforms
6. **`nix-visualize` cleanup** — Remove from flake inputs and specialArgs if only used via `nix run`
7. **Status report hygiene** — 95+ status reports in `docs/status/`. Consider archiving older ones (archive/ dir exists)

---

## F) Top 25 Things to Do Next

### Critical (Do First)

1. **Consolidate fail2ban config** — Merge `configuration.nix` and `security-hardening.nix` fail2ban into single definition
2. **Remove orphaned Grafana fail2ban jail** — Grafana was never deployed as a module
3. **Delete `pkgs/superfile.nix`** — Dead code: `vendorHash = null`, unreferenced anywhere
4. **Remove duplicate `gnupg`** — in both `base.nix:96` and `security-hardening.nix:108`
5. **Remove duplicate `foot`** — in both `base.nix:227` and `multi-wm.nix:12`
6. **Remove duplicate `zellij`** — in `base.nix:228`, `home.nix:182`, and `programs.zellij` module
7. **Remove duplicate `swappy`** — in both `base.nix:222` and `home.nix:173`
8. **Remove duplicate `jq`** — in `base.nix:88`, `home.nix:186`, and `yazi.nix:438`
9. **Remove duplicate `wl-clipboard`** — in both `home.nix:178` and `multi-wm.nix:42`
10. **Remove duplicate `rofi`** — `multi-wm.nix:29` conflicts with `programs.rofi` auto-install
11. **Remove duplicate `cliphist`** — in both `base.nix:136` and `home.nix:177`

### High Priority

12. **Consolidate Go overlay** — Single definition shared by both platforms
13. **Remove `nix-visualize` from specialArgs** — Unused in Nix modules
14. **Clean stale commented imports** — `configuration.nix:21-29` referencing removed services
15. **Fix justfile "Go 1.26rc2" text** — Update to "Go 1.26.1" at line 1078
16. **Remove netdata/ntopng justfile recipes** — Legacy macOS recipes (lines 866-916)
17. **Remove `better-claude` justfile recipes** — Reference non-existent package
18. **Resolve docker group duplication** — `configuration.nix:85` vs `modules/nixos/services/default.nix:16`

### Medium Priority

19. **Keep only `btop`** — Remove `bottom` and `htop` from `base.nix` (overlapping functionality)
20. **Delete orphaned `ssh-banner` file** — Never referenced in any config
21. **Archive old status reports** — 95+ reports, move pre-April ones to `archive/`
22. **Add `vendorHash` to superfile.nix or delete it** — If keeping, fix the build

### Lower Priority

23. **Re-evaluate auditd re-enablement** — Check if NixOS bug #483085 is resolved
24. **Consolidate `docs/operations/manual-steps-after-deployment.md` TODO** — Create the referenced security-tools-status script
25. **Review Darwin HM user pattern** — Document why explicit `users.users.larsartmann` is needed

---

## G) Top #1 Question I Cannot Answer

**Should the duplicate fail2ban configuration be consolidated into `configuration.nix` (system-level) or `security-hardening.nix` (thematic module)?**

Both files currently define `services.fail2ban` with different, partially overlapping settings. NixOS module merging combines them, which works but is confusing and error-prone. The thematic approach says "security stuff in security-hardening.nix" but the practical approach says "fail2ban is already in configuration.nix with SSH jails." Which file should be the canonical source?
