# DNS Blocker & System Status Report

**Date:** 2026-03-28 09:09
**Context:** DNS Blocker (dnsblockd), Unbound, YouTube Redirects, Blocklist Expansion.

---

## 1. Retrospective: What we forgot, could have done better, and can improve

**What we forgot:**

- We added false positive reporting to the Go backend (`/api/report` and `/api/false-positives`), but we didn't add a way to easily view, export, or manage these reports. They are just sitting in memory/logs.
- We discussed adding more blocklists (like OISD, HaGeZi, Block List Project) but never actually implemented them in the Nix configuration.
- The temp-allowlist functionality was disabled (removed from Unbound's `include`) to fix DNS, but the dead Go code for it and the `systemd.tmpfiles.rules` are still lingering.

**What we could have done better:**

- **Safety First:** We deployed a configuration where Unbound relied on an imperatively generated file (`temp-allowlist.json.conf`) that was incorrectly initialized by `tmpfiles.d` (with literal quotes). We should have used a fallback include mechanism or a pre-validated dummy file to ensure Unbound never fails to start. A DNS server failing takes down the entire system's ability to rebuild easily.
- **Testing:** We haven't rigorously tested the block page UI in a browser to verify if the category icons and block counts render correctly.

**What we could still improve (Architecture, Types, Libs):**

- **Type Models:** In Nix, we can improve the `services.dns-blocker.blocklists` type model to strictly validate SHA256 hashes and perhaps use an `enum` for categories to prevent typos. In Go, we could strongly type the `Category` instead of using plain strings.
- **Libraries:** In Go, if the block page routing gets more complex (especially with YouTube redirects), we should consider using `go:embed` for the HTML templates so the binary is 100% self-contained, rather than relying on raw strings or external files.
- **Nix Evaluation:** Currently, `pkgs.fetchurl` is used to fetch blocklists at build time, which is fine, but parsing a massive 87k+ line text file in pure Nix (`lib.splitString` + `lib.filter`) is computationally expensive during evaluation. We should consider writing a small build-time script (e.g., in bash/python/go) that parses the hosts file and outputs the Unbound config as a derivation, offloading the heavy lifting from the Nix evaluator to the builder.

---

## 2. Current State Breakdown

### a) FULLY DONE

- Restored DNS functionality by removing the faulty `temp-allowlist` include from the Unbound config.
- Added `TotalBlocked` counter and `CategoryIcon` to the Go `dnsblockd` application.
- Implemented `/api/report` and `/api/false-positives` endpoints in Go.
- Researched self-hosted YouTube frontends (Invidious vs. Piped) and documented them in `docs/research/youtube-frontend-alternatives.md`.
- Verified Go compilation and successfully deployed the NixOS configuration.

### b) PARTIALLY DONE

- **Temp Bypass Feature:** The UI button exists, the Go logic exists, but it's disconnected from Unbound because the include was removed for safety.
- **More Blocklists:** Researched the best blocklists (Block List Project, HaGeZi, StevenBlack) but haven't added them to `dns-blocker.nix` yet.

### c) NOT STARTED

- Implementing the YouTube redirect logic inside `dnsblockd` block page.
- Deploying Invidious on NixOS (`services.invidious.enable = true`).
- Refactoring the Nix blocklist parser to be a build-time script instead of Nix eval-time logic.
- Adding a dashboard/UI to view the collected false positive reports.

### d) TOTALLY FUCKED UP!

- **Temp-allowlist tmpfiles rule:** We tried to seed `temp-allowlist.json.conf` using `systemd.tmpfiles.rules` with type `w`, but passed literal quote marks which were written directly into the file. Since Unbound includes this file, the syntax error `error: stray '''` completely killed Unbound, and thus DNS for the whole system.

### e) WHAT WE SHOULD IMPROVE!

- **Never parse massive lists in Nix Eval:** Processing 100k+ line text files using `lib.splitString` in `dns-blocker.nix` slows down `nixos-rebuild` and eats RAM. We should use `runCommand` with `awk`/`sed` or a Go tool to convert hosts files to Unbound format.
- **Fail-safe DNS:** Unbound should _never_ fail to start if a blocklist is malformed. We should run a syntax check (`unbound-checkconf`) as an `ExecStartPre` in the systemd service.

---

## 3. Comprehensive Multi-Step Execution Plan (Top #25 Next Steps)

_Sorted roughly by Work Required vs. Impact (Highest impact / lowest work first)._

**Phase 1: Stabilization & Optimization (High Impact, Low Work)**

1. `Nix`: Add `ExecStartPre = "${pkgs.unbound}/bin/unbound-checkconf"` to the Unbound systemd service to prevent it from restarting if the config is broken.
2. `Nix`: Refactor blocklist parsing in `dns-blocker.nix` to use a derivation (`runCommand` + `awk`) instead of `lib.splitString` during evaluation.
3. `Go`: Use `go:embed` for the `dnsblockd` HTML templates to clean up `main.go`.
4. `Nix`: Clean up the dead `systemd.tmpfiles.rules` for the temp-allowlist until a safe implementation is ready.
5. `Go`: Remove or disable the temp bypass UI button since the backend for it is currently disconnected.

**Phase 2: Blocklist Expansion (High Impact, Medium Work)** 6. `CLI`: Fetch SHA256 hashes for HaGeZi Light/Normal DNS blocklists. 7. `CLI`: Fetch SHA256 hashes for Block List Project (Ads, Tracking, Malware). 8. `Nix`: Add HaGeZi Light/Normal to `cfg.blocklists`. 9. `Nix`: Add Block List Project (Ads, Tracking, Malware) to `cfg.blocklists`. 10. `Nix`: Build and test Unbound with the new, massive combined blocklist. 11. `Nix`: Verify `dnsblockd` memory usage with the expanded domain mapping JSON.

**Phase 3: YouTube Redirect Implementation (Medium Impact, Medium Work)** 12. `Go`: Add URL parsing logic in `dnsblockd` to detect `youtube.com/watch?v=...` and `youtu.be/...`. 13. `Go`: Create a `buildInvidiousURL(originalURL string)` function. 14. `Go`: Update the block page HTML to conditionally show a "Watch on Invidious" button if the domain is YouTube. 15. `Go`: Write unit tests (`main_test.go`) for the YouTube URL parsing and redirect logic. 16. `Nix`: Add `youtube.com` and `youtu.be` to `cfg.extraDomains` to ensure they hit the block page.

**Phase 4: Invidious Deployment (High Impact, Medium Work)** 17. `Nix`: Add `services.invidious.enable = true` to `dns-blocker.nix` or a new module. 18. `Nix`: Configure Invidious database (PostgreSQL local creation). 19. `Nix`: Set Invidious domain to `tube.local` (or similar) and bind to loopback. 20. `Nix`: Configure Nginx reverse proxy for Invidious if required for HTTPS. 21. `Nix`: Deploy and verify Invidious is running locally.

**Phase 5: False Positives & Admin UI (Medium Impact, High Work)** 22. `Go`: Create an in-memory or SQLite database for storing False Positive reports securely. 23. `Go`: Add an `/api/admin/false-positives` endpoint to list reports (JSON). 24. `Go`: Create a simple HTML admin page to view and clear reports. 25. `Nix`: Secure the admin endpoint (only accessible via specific local IPs or behind auth).

---

## 4. Top #1 Question

**"How exactly do you want to handle the persistence and reloading of the temporary bypass list without breaking the declarative nature of NixOS and causing Unbound to fail if the file is empty or malformed?"**

_Context:_ Unbound natively supports `include: /path/to/file`. If that file is empty, missing, or has bad syntax, Unbound crashes. Since we want `dnsblockd` to dynamically add/remove bypasses, it needs write access to this file, which conflicts with Nix's read-only store. If we put it in `/var/lib`, a failed deploy or reboot could leave it in a bad state, killing DNS. Should we use `unbound-control` to dynamically inject `local-zone` overrides in memory instead of writing to a `.conf` file and reloading the service?
