# Status: HaGeZi DNS Blocklists GitHub Lock — Mirror Fix

**Date:** 2026-08-13 16:11
**Session focus:** Fix build failure caused by `hagezi/dns-blocklists` GitHub repo being locked
**Severity:** Build-blocking (22 fetch derivations returning 404)
**Status:** FIXED — untested deploy

---

## What Was Broken

The Nix build (`nix run .#deploy`) failed with 22 errors. Every HaGeZi DNS blocklist fetch derivation returned HTTP 404 from `raw.githubusercontent.com/hagezi/dns-blocklists/<commit>/<file>`.

**Root cause:** The GitHub repository `hagezi/dns-blocklists` was locked/suspended by GitHub's automated fraud detection system. This is a recurring problem — HaGeZi (the maintainer) confirmed on Reddit and Hacker News that GitHub's bot systems repeatedly flag the repo, and he has opened support tickets each time. The repo is NOT deleted permanently — it comes back after manual review, but the timeline is unpredictable (days to weeks).

**Affected file:** `platforms/common/dns-blocklists.nix` — all 22 HaGeZi blocklist entries referenced `raw.githubusercontent.com/hagezi/dns-blocklists/489ce87162a4824080b8ab3fb4db7c8ea65fd38c/<path>`.

**Impact:** `dnsblockd` config generation was blocked → the entire `nixos-system-evo-x2` build failed → deploy was impossible.

---

## What I Did

1. **Diagnosed** the root cause by verifying that `github.com/hagezi/dns-blocklists` returns 404 (repo locked), not just a bad commit hash
2. **Researched** where the project moved — found the official GitLab mirror at `gitlab.com/hagezi/mirror` confirmed by HaGeZi himself
3. **Verified** the GitLab mirror serves the correct files (fetched `hosts/ultimate.txt`, confirmed 654,851 entries, version `2026.0813.0800.38`)
4. **Computed fresh SRI hashes** for all 22 blocklists by downloading each from the GitLab mirror and running `nix hash file --sri`
5. **Updated** `platforms/common/dns-blocklists.nix`:
   - Replaced `hageziRev` + `raw.githubusercontent.com` URL builder with a direct GitLab mirror URL builder
   - Updated all 22 `hash` values
   - Added comment explaining why GitLab is used
6. **Verified** via `nix eval` that the system configuration evaluates successfully
7. **Cross-verified** one hash (`hosts/ultimate.txt`) using `nix-prefetch-url` — SRI hash matches

---

## a) FULLY DONE

| Item | Details |
|------|---------|
| HaGeZi blocklist URLs switched to GitLab mirror | All 22 entries updated in `platforms/common/dns-blocklists.nix` |
| SRI hashes recomputed | All 22 hashes freshly computed from GitLab mirror content |
| Nix eval passes | `nix eval .#nixosConfigurations.evo-x2.config.system.build.toplevel.drvPath` succeeds |
| Hash verification | `nix-prefetch-url` for `hosts/ultimate.txt` matches the SRI hash in the file |
| Shared by both NixOS hosts | `dns-blocklists.nix` is shared — both `evo-x2` and `rpi3-dns` consume it (via `dns-blocker-config.nix` and `rpi3/default.nix`) |

## b) PARTIALLY DONE

| Item | Status | Gap |
|------|--------|-----|
| Deploy verification | NOT done | Build evaluates but hasn't been built or deployed. The actual fetch derivations haven't been built — only eval was checked |
| Blocklist freshness | Latest available | GitLab mirror serves `main` branch (today's data: version `2026.0813.0800.38`). Previously the pinned commit guaranteed reproducibility — now we fetch from `main` which is mutable |

## c) NOT STARTED

| Item | Why |
|------|-----|
| ~~AGENTS.md update~~ done at `61a2224b` — DNS gotcha documents the GitLab mirror + lock risk |
| Pinning strategy | No mechanism to pin a specific GitLab commit for reproducibility (see "Improvements") |
| ~~Testing on rpi3-dns~~ done — verified 08-14: `rpi3-dns` evaluates clean with the shared GitLab-mirror blocklists |

## d) TOTALLY FUCKED UP

Nothing. The fix is clean and minimal.

## e) WHAT WE SHOULD IMPROVE

### 1. Reproducibility regression (IMPORTANT)

**Before:** Blocklists were pinned to commit `489ce87162a4824080b8ab3fb4db7c8ea65fd38c` — deterministic, reproducible, any `nix build` at any time produced identical output.

**After:** We fetch from `gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/` — the `main` branch is mutable. The SRI hash pins the content (so a deploy either works or fails loudly on hash mismatch), but different deploys at different times will produce different store paths with different blocklist contents. This is acceptable for DNS blocklists (you WANT fresh data) but it breaks the "same flake.lock = same output" guarantee.

**Recommendation:** Add a periodic updater (cron or CI) that refreshes hashes monthly, OR pin to a specific GitLab commit hash and update it on a schedule. The SRI hash already prevents silent content drift — any mismatch will fail the build loudly. But it means deploys can break unexpectedly when GitLab `main` changes between hash updates.

### 2. No fallback mechanism

If GitLab also goes down (or locks the account), the build breaks again. Consider:
- Adding a jsDelivr CDN fallback (`cdn.jsdelivr.net/gh/hagezi/dns-blocklists@<rev>/`)
- Committing the blocklist files directly into the repo (they're large — `ultimate.txt` alone is ~20 MB — so this is a tradeoff)
- Using `fetchurl` with multiple mirror URLs

### 3. AGENTS.md should document this

Add a gotcha note: "HaGeZi blocklists are fetched from GitLab mirror (`gitlab.com/hagezi/mirror`) because GitHub repeatedly locks the repo. If GitLab mirror is also unavailable, check Codeberg mirror (`codeberg.org/hagezi/mirror2`) or jsDelivr CDN."

## f) Up to 50 Things We Should Get Done Next

### Immediate (this fix)
1. ~~**Deploy and verify** — Run `nix run .#deploy` and confirm `dnsblockd` starts with the new blocklists~~ done — deployed successfully the same evening (`2026-08-13_19-01`, `990fcd66`)
2. ~~**Verify blocklist entry counts** — After deploy, check `dnsblockd` logs for expected domain counts~~ done (moot) — "DNS Blocking Active" Gatus check guards the blocking pipeline
3. ~~**Verify DNS resolution still works** — Confirm `*.home.lan` resolves and ad-blocking is functional~~ done (moot) — "DNS Resolver" + "DNS Resolver TCP" Gatus checks monitor continuously
4. ~~**Evaluate rpi3-dns config** — Run `nix eval` for the rpi3 host to ensure shared file doesn't break it~~ done — verified 08-14, evaluates clean
5. ~~**Update AGENTS.md DNS section** — Document GitLab mirror as the source, add gotcha about GitHub lockouts~~ done at `61a2224b`
6. **Update archived status report** — `docs/status/archive/2026-05-06_07-10_SESSION-37-DNS-REPRODUCIBILITY-MANIFEST-HARDENING.md` line 22 references the old GitHub rev — add a note that GitHub is no longer used

### Short-term (reproducibility & resilience)
7. **Pin to a GitLab commit** — Instead of `main`, fetch from a specific GitLab commit hash for reproducibility, with a scheduled job to bump it
8. **Create a blocklist hash refresh script** — `scripts/update-dns-blocklists.sh` that downloads from GitLab, recomputes hashes, and updates `dns-blocklists.nix`
9. **Add jsDelivr as fallback mirror** — `fetchurl` supports multiple URLs; add `cdn.jsdelivr.net/gh/hagezi/dns-blocklists@main/` as fallback
10. **CI check for blocklist freshness** — Add a flake check that warns if blocklist hashes are >30 days old
11. **Consider vendoring critical blocklists** — The small lists (`dga7.txt`, `doh.txt`, native.* lists) could be committed directly; only `ultimate.txt` (~20 MB) needs fetching

### DNS system health
12. **Add Gatus check for GitLab mirror reachability** — Alert if GitLab mirror goes down, so we know before a deploy breaks
13. **Add blocklist download monitoring** — Expose Prometheus metric for blocklist entry count, alert if it drops dramatically
14. **Review the whitelist** — Some entries may be stale (e.g., movieffm.net, olevod.com — are these still needed?)
15. ~~**Test DNS failover** — What happens when dnsblockd is down? The fallback `9.9.9.9` in resolv.conf — verify it actually works~~ done — fallback ordering verified in the `2026-08-12_23-50` session (dns-fallback fixes)
16. ~~**Review StevenBlack blocklist** — That one uses a pinned GitHub commit (`4a68876c`); verify it's still reachable (different repo, likely fine, but check)~~ done (moot) — every successful build since has fetched it

### From the build log (other things noticed)
17. **OpenAudible AppImage download** — The build was also fetching `OpenAudible_4.7.4_x86_64.AppImage` (94 MB) from GitHub releases — consider mirroring or caching
18. **Geekbench tarball download** — 217 MB `Geekbench-6.7.1-Linux.tar.gz` was downloading during the build — this is a large FOD that should be cached or pre-fetched
19. **Review all GitHub-based `fetchurl` dependencies** — Audit the entire flake for other `raw.githubusercontent.com` or GitHub release downloads that could break if repos are locked
20. ~~**Check if the build eventually succeeded** — The log shows many things downloading successfully; the HaGeZi errors may have been the ONLY blocker~~ done (moot) — confirmed: builds and deploys green since `88c594cc`

---

## g) Questions I Cannot Answer Myself

### 1. Should I deploy now, or do you want to review the diff first?

The eval passes and one hash is verified, but I haven't run the actual build. Deploying will take time (downloading ~50 MB of blocklist data) and will restart `dnsblockd`. If the hashes are wrong, the build will fail loudly (SRI mismatch) — no risk of silent breakage.

> **Answered (2026-08-14):** Deployed the same evening — success (`2026-08-13_19-01`).

### 2. Do you want reproducibility (pin a GitLab commit) or freshness (track `main`)?

GitLab `main` gives you fresh blocklists but breaks reproducibility (same flake.lock can produce different builds over time). Pinning a commit gives reproducibility but requires manual or scheduled updates. For DNS blocklists, freshness arguably matters more — but this is your call.

> **Answered (2026-08-14):** Freshness — mutable `main` + SRI-hash pinning (fail-loud on drift). A periodic hash-refresh workflow is tracked in TODO_LIST.

### 3. Should I add fallback mirrors now, or wait until GitLab also breaks?

Adding jsDelivr/Codeberg fallbacks is ~15 minutes of work but adds complexity. If this is a rare event, it may not be worth it. If GitHub lockouts happen monthly (as HaGeZi暗示), resilience may be worth investing in.

> **Answered (2026-08-14):** Deferred — no fallback added yet; the GitLab mirror has held since. Codeberg mirror noted in AGENTS.md as the next fallback.
