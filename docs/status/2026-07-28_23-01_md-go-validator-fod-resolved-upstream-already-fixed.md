# md-go-validator FOD Purity Break — RESOLVED (Upstream Already Fixed)

**Date:** 2026-07-28 23:01
**Session type:** Build break resolution + self-review
**Trigger:** Continuation of 18:16 session. User said "md-go-validator should be fixed upstream!" — this triggered investigation that revealed the fix was ALREADY shipped.
**Predecessor:** `docs/status/2026-07-28_18-16_md-go-validator-fod-purity-break-from-prebuilt-binary.md`

---

## a) FULLY DONE

1. **Root cause identified:** `go-branded-id` v0.5.0 shipped a prebuilt 3.3 MB ELF binary (`namer`) at the module root. Its DWARF `debug_info` embeds the absolute Nix store path of the Go compiler (`/nix/store/...-go-1.26.5`). `buildGoModule`'s `go mod vendor` copies this binary verbatim into the vendor directory → the `go-modules` fixed-output derivation (FOD) references the Go compiler store path → Nix refuses to build the FOD → 19 dependent derivations fail → entire deploy blocked.

2. **Fix discovered:** `go-branded-id` v0.5.1 (released the same day) moved `namer` from a root-level prebuilt binary to `cmd/namer/main.go` (source-only, no ELF in the module zip). The md-go-validator repo bumped to v0.5.1 in commit `b99e5fe`. SystemNix's `flake.lock` ALREADY pinned `b99e5fe` — the fix was already in place but the previous session was working against a stale diagnosis based on the old rev `f1e5584`.

3. **Band-aid removed:** The `stripPrebuiltGoBinaries` helper function (45 lines of vendored-module-mode workaround in `lib/lars-packages.nix`) was completely removed. The file now uses the simple `flakePkg inputs.md-go-validator` pattern like every other package.

4. **Build verified:** `nix build .#md-go-validator` succeeds — same store path as upstream (`/nix/store/2lpmgnpv5q5c2bf7zlbrg8s2fq7a1f6g-md-go-validator-b99e5fe`).

5. **All 8 lars-packages verified:** `branching-flow`, `buildflow`, `go-auto-upgrade`, `go-structure-linter`, `hierarchical-errors`, `library-policy`, `project-meta`, `todo-list-ai` — all build cleanly. No FOD purity issues in ANY package. The go-branded-id v0.5.1 upgrade fixed them all.

6. **`nix flake check --no-build` passes:** All NixOS modules evaluate correctly.

7. **Deploy succeeded:** `nix run .#deploy` completed. The system activated. The original blocker (20 build errors cascading from FOD purity violation) is completely resolved.

8. **Post-deploy smoke test:** 27 PASS, 2 FAIL, 1 SKIP. The 2 failures (SearXNG port 8888 conflict, DiscordSync DB issue) are pre-existing and UNRELATED to the FOD fix. The SKIP (DiscordSync API unreachable during startup backfill) is expected behavior per the AGENTS.md gotcha.

---

## b) PARTIALLY DONE

1. **AGENTS.md gotcha entry** — NOT YET WRITTEN. The task was in progress when the user interrupted with the self-review request. The lesson is real and valuable: "Prebuilt binaries in Go modules break FOD purity." This should be added even though the specific instance is resolved — the pattern will recur if any LarsArtmann repo ever commits a binary to its module root again.

2. **Predecessor status report annotation** — `docs/status/2026-07-28_18-16_*.md` should be annotated to note that the issue was already resolved upstream. It currently reads as an open problem with an unverified band-aid.

---

## c) NOT STARTED

1. **AGENTS.md gotcha entry** — Content planned but not written.
2. **TODO_LIST.md entry** — No entry tracking whether other LarsArtmann repos should audit for committed binaries.
3. **Upstream go-branded-id issue/PR** — Not filed. The binary was already removed in v0.5.1, so an issue is no longer necessary. But a comment on the repo suggesting a `.gitignore` rule or pre-commit hook to prevent future binary commits would be good hygiene.

---

## d) TOTALLY FUCKED UP

### Mistake #1: Wasted time iterating on a band-aid that was entirely unnecessary

**What happened:** The previous session's summary stated the flake.lock pinned rev `f1e5584` (which had go-branded-id v0.5.0). I trusted this and started iterating on vendor hashes for the `stripPrebuiltGoBinaries` band-aid. I went through THREE hash iteration cycles (`lib.fakeHash` → got hash → hash mismatch on rebuild → re-iterate) before the user said "fix it upstream."

**What I should have done:** My FIRST action should have been `nix eval --raw .#inputs.md-go-validator.rev` to check what rev SystemNix ACTUALLY pins. The flake.lock had already been updated to `b99e5fe` (which has go-branded-id v0.5.1). The band-aid was solving a problem that no longer existed.

**Root cause of the mistake:** I trusted the conversation summary's stated flake.lock rev without verifying against the actual file. The summary was written at 18:16; by 23:01 (this session), the flake.lock had been updated (likely by the auto-git commit daemon or a flake lock update between sessions). I should have re-verified ground truth before continuing work.

### Mistake #2: `./deps/go-finding` subpackage scan error

**What happened:** When I placed the go-finding source inside the module tree at `./deps/go-finding`, `buildGoModule`'s `subPackages` scanning tried to build it as a Go package: `main module does not contain package github.com/larsartmann/md-go-validator/deps/go-finding`.

**Fix applied:** Moved go-finding to `$NIX_BUILD_TOP/go-finding-src` (sibling directory, outside the module root) with a `../go-finding-src` replace directive.

**Lesson:** Go `replace` directives with `=> ./path` are resolved relative to the module root, but the path itself becomes part of the module tree if it's inside the root. `buildGoModule` scans all directories under the source root as potential subPackages. Place replace targets OUTSIDE the source root (use `$NIX_BUILD_TOP` or Nix store paths — but store paths break FOD purity, so `$NIX_BUILD_TOP` siblings are the answer).

### Mistake #3: Didn't check upstream FIRST before writing a band-aid

**What happened:** The entire `stripPrebuiltGoBinaries` 45-line helper in `lib/lars-packages.nix` was unnecessary. The user's instruction "md-go-validator should be fixed upstream!" was the hint that made me check the upstream repo, where I found the fix was already shipped.

**What I should have done:** Before writing ANY band-aid, check: (1) Is the upstream repo already at a newer rev with a fix? (2) Has the dependency that caused the issue been upgraded? (3) Is the simplest fix just bumping the flake input?

### Mistake #4: Continued iterating on vendorHash after a stale candidate failed

**What happened:** The candidate hash `sha256-X0b5+DXMDNW05HONHZUKw96PDrkCaHbkiMKk4mWqwg8=` from the previous session failed with hash mismatch. Instead of questioning WHY the hash was stale (which would have led me to discover the flake.lock update), I mechanically substituted the new got hash and continued.

**Lesson:** A stale vendorHash is a SIGNAL, not just an obstacle. It means something changed between when the hash was computed and now. Investigate the change before blindly iterating.

---

## e) WHAT WE SHOULD IMPROVE

1. **Verify ground truth before continuing from a summary.** The summary is a snapshot, not live data. Always re-read flake.lock, git log, and current file state before resuming work. A summary from 5 hours ago may be completely stale.

2. **Check upstream FIRST for any dependency-related build break.** Before writing a SystemNix band-aid, run:
   - `git log --oneline -10` in the upstream repo
   - `grep <dependency> go.mod` in the upstream repo
   - `nix eval --raw .#inputs.<pkg>.rev` in SystemNix
   The fix may already be shipped. Band-aids are debt — only incur them when the upstream fix is genuinely unavailable.

3. **The `stripPrebuiltGoBinaries` helper was over-engineered.** It switched vendor modes, rewrote replace directives, stripped binaries via `modPostBuild`. All of this was unnecessary because the real fix was a one-line dependency bump. When a fix requires 45 lines of Nix hackery, that's a signal to step back and ask "is there a simpler path?"

4. **Pre-commit/pre-merge hooks for committed binaries.** go-branded-id v0.5.0 shipped a 3.3 MB ELF binary in its Go module. This should have been caught by a `.gitignore` rule (`namer`, `*.exe`) or a pre-commit hook that rejects binary files >100 KB. All LarsArtmann Go repos should adopt this hygiene.

5. **The predecessor status report (18:16) should have verified its own diagnosis.** It stated the flake.lock rev was `f1e5584`, but the actual flake.lock had `b99e5fe`. The report was written from a stale checkout. Always `cat flake.lock` or `nix flake metadata` before writing a diagnosis.

6. **SearXNG port 8888 conflict is a real issue** — not caused by this session, but noticed during deploy. Something else is using port 8888. This needs investigation.

7. **DiscordSync DB issue** — also pre-existing, noticed during deploy. The "Check the database logs for details" error with exit code 69 suggests a migration or connection problem. Not related to this session's work.

---

## f) Up to 50 Things We Should Get Done Next

### Immediate (this repo, this session's scope)

1. **Add AGENTS.md gotcha entry** for "Prebuilt binaries in Go modules break FOD purity"
2. **Annotate predecessor status report** (`docs/status/2026-07-28_18-16_*.md`) — note issue was already resolved upstream
3. **Investigate SearXNG port 8888 conflict** — what else is using that port?
4. **Investigate DiscordSync exit code 69** — "Check the database logs for details"
5. **Verify DiscordSync recovers** from the known 5-11 min startup backfill race

### Hygiene (LarsArtmann Go repos)

6. **Add `.gitignore` for compiled binaries** to go-branded-id (prevent future `namer` commits)
7. **Add pre-commit hook** that rejects ELF/binary files >100 KB in all LarsArtmann Go repos
8. **Audit all LarsArtmann Go repos** for committed binaries (`find . -type f -exec file {} \; | grep ELF`)
9. **Consider a `golangci-lint` rule** or custom linter that detects committed binaries in module roots

### SystemNix maintenance

10. **Update TODO_LIST.md** — remove any stale md-go-validator entries, add SearXNG port conflict
11. **Re-enable cqrs-lint** — disabled due to samber-do-auditlog v0.6.0+ break; check if upstream fixed it
12. **Re-enable mr-sync** — disabled due to outputs signature missing `...`; check if upstream fixed it (commit `6492eef` was the break)
13. **Run `nix flake update`** — check if other flake inputs have updates available
14. **Review the auto-git commit daemon** — it committed changes between sessions that made the previous summary stale. Consider whether it should be more conservative or whether summaries should be re-validated on resume.

### Build system hardening

15. **Add a CI check** that runs `nix build .#md-go-validator` (and all lars-packages) on every flake.lock update
16. **Add a SystemNix pre-deploy check** that detects FOD purity violations before attempting a full deploy
17. **Document the `$NIX_BUILD_TOP` replace pattern** — for private Go deps that need local replace without FOD purity breaks
18. **Consider `vendorHash = null`** as a development tool — auto-computes the hash, useful for rapid iteration

### Upstream coordination

19. **Check if go-branded-id has a CHANGELOG entry** explaining why v0.5.0 had the binary and v0.5.1 removed it
20. **Suggest go-branded-id add a `Makefile` target** or CI step that strips binaries before `go mod` publishing
21. **Review md-go-validator's `package.nix`** — the `postPatch` that injects `replace ... => ${go-finding-src}` (absolute Nix store path) is a latent FOD purity risk if `proxyVendor` is ever set to `false`. It works with `proxyVendor = true` only because the proxy module cache doesn't include the replace in the hashed output. This is fragile.

### Monitoring

22. **Add Gatus check for SearXNG** — the service is failing; if it's supposed to be monitored, the check should catch it
23. **Add Gatus check for DiscordSync** — verify the API comes up after the backfill window
24. **Review post-deploy-check SearXNG healthz endpoint** — it's hitting `/healthz` and getting 404; check the correct health endpoint

### Documentation

25. **Document the "verify ground truth before resuming" protocol** in AGENTS.md or the global crush config
26. **Add a "Common FOD purity violations" section** to docs/CONTRIBUTING.md
27. **Update the predecessor report** to link to this resolution report

### Other items noticed

28. **`cqrs-lint` and `mr-sync` are disabled** — both for different upstream API breaks. These are tools that may be needed for development. Prioritize re-enabling.
29. **The `go-finding-src` flake input** is declared as `git+ssh://` (private repo). If the SSH key isn't available in CI, builds will fail. Consider mirroring or making the repo public.
30. **The md-go-validator `postPatch` replace pattern** uses `grep -q ... go.mod` to avoid double-adding the replace. This is fragile if the grep pattern changes. Consider using `go mod edit -replace=...` instead.

---

## g) Questions I CANNOT Answer Myself

1. **Did the flake.lock update happen between the 18:16 session and this session (23:01), or was the 18:16 session working with a stale checkout?** I need to know whether the auto-git daemon committed a flake lock update, or whether the previous session never re-read flake.lock. This affects whether the "verify ground truth" protocol needs to be stricter.

2. **Is SearXNG supposed to be on port 8888?** The post-deploy-check expects `http://localhost:8888/healthz` but the service log says "Port 8888 is in use by another program." Something else is on 8888 — is this a port collision in `lib/ports.nix`, or a stale process from a previous config?

3. **Should I annotate the predecessor report (18:16) inline or just write a resolution note at the bottom?** The predecessor contains 50 next-steps that are now mostly moot. Annotating every item would be noisy; a resolution header might be cleaner. What's the preferred style?
