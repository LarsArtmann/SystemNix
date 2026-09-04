# Forgejo-Primary Migration Plan (GitHub → Mirror-Only)

**Date:** 2026-08-31
**Status:** PROPOSAL — decisions taken via Q&A, not yet executed
**Instance:** `forgejo.home.lan` (evo-x2, `modules/nixos/services/forgejo.nix`)

---

## Decisions (user, 2026-08-31)

| # | Question | Decision |
|---|----------|----------|
| 1 | Off-LAN access to homelab | **NOT a goal** — LAN-only is deliberate; GitHub mirror remains the off-site read surface |
| 2 | Flip scope | **ALL repos canonical on Forgejo** (incl. public: templ-components, go-nix-helpers) |
| 3 | GitHub's fate | **Keep as live push-mirror** (indefinite; re-evaluate later) |
| 4 | Off-precinct backup | **After the flip**, not a prerequisite |
| 5 | Motivation | **Sovereignty/control + free unlimited runners for private repos** |

## Why this works with near-zero migration cost

The existing provisioner (`modules/nixos/services/forgejo-repos.nix`) already creates every repo as
pull-mirror (GitHub → Forgejo) **plus push-mirror back to GitHub with `sync_on_commit: true`**
(forgejo-repos.nix:121-131). Consequences:

- Every `github:LarsArtmann/*` flake input across the ecosystem **keeps working unchanged** — Nix
  fetches the GitHub mirror, which Forgejo keeps updated on every push. The ~40-input rewrite is
  deferred until GitHub is ever actually cut off (nix has NO `forgejo:` fetcher — nix#11135 open,
  PR #11467 stuck; would require `git+ssh`/tarball URLs + narHash re-lock + auth on every machine).
- Go module paths (`github.com/LarsArtmann/X`) keep resolving: proxy.golang.org crawls the mirror's
  tags. Push mirrors sync tags (`git push --mirror`), which is all Go + Nix need. New public Go
  libraries keep being `go get`-able by strangers without any vanity-domain work.
- GitHub Actions keeps firing on mirror pushes — existing CI (nix-check, nixpkgs-compat,
  secret-history-scan) continues during the whole transition until deliberately ported.
- macOS CI stays on GitHub runners for free — no runner on the 90%-full MacBook Air needed.

**The flip itself is per-repo:** stop/demote the pull side (Forgejo stops treating GitHub as
upstream), commit on Forgejo, keep the push side. Git remotes: `git remote set-url origin
<forgejo>` in ~100 local checkouts.

## Hard rules after the flip

1. **The GitHub mirror is STRICTLY READ-ONLY.** Forgejo push mirrors FORCE-PUSH and overwrite
   anything on the remote. A commit pushed directly to GitHub will be silently clobbered on the
   next mirror sync. Consider GitHub branch protection on `master`/`main` of active repos as a
   seatbelt; at minimum document the rule.
2. **Mirror metadata gap is permanent:** push mirrors carry git data only (commits/branches/tags +
   LFS-over-HTTPS). Issues, PRs, releases-with-assets, labels exist ONLY on Forgejo/evo-x2. The
   GitHub mirror is therefore NOT a full backup — it is a git-data replica. Off-precinct backup of
   the forgejo dump zips (restic → Hetzner/B2, the T17 pattern) remains REQUIRED for metadata.
3. **Mirror reliability becomes Tier-1:** it is now the public interface AND the offsite git
   replica. The 3 verified-but-unfiled upstream mirror bugs (TODO_LIST:57: dead-queue silence,
   TouchMirror advancing `updated_unix` on failure, credential-helper ENOENT spam 2450×/day) must
   be filed upstream and monitored — a silent dead mirror no longer means "backup is stale", it
   means the public interface is stale.

## Known traps for this specific stack

- `DEFAULT_ACTIONS_URL = "github"` (forgejo.nix:205): `uses: actions/checkout@v6` etc. resolve
  against github.com. Works today; pins Forgejo CI availability to GitHub. Switch to
  `https://data.forgejo.org` when workflows are ported.
- `.forgejo/workflows/` vs `.github/workflows/`: two directories during transition. Mitigation:
  port workflows as thin wrappers that `workflow_call` a shared reusable workflow, or accept
  temporary dual-maintenance (only ~4 workflows exist).
- evo-x2 is now the single point of authority. Accepted per decision #3 (GitHub mirror = git-data
  failover: clone from GitHub, push back when home). Box has 3 freezes/10 days history — Gatus
  coverage on Forgejo exists; sev1-bridge does not watch forgejo units yet (add if desired).
- The pending history-purge decision gets SIMPLER under this model: purge locally on Forgejo, the
  push mirror force-pushes the rewritten history to GitHub automatically. (Rotation, per the
  standing decision, remains the real fix.)
- Private Go modules: module paths stay `github.com/LarsArtmann/…`; GOPRIVATE/direct-mode keeps
  working because the mirror exists. Local checkouts fetch the mirror via a scoped git insteadOf
  (`url."lars@forgejo.home.lan:".insteadOf = "git@github.com:LarsArtmann/"`) — optional; do NOT
  scope it wider than LarsArtmann or third-party GitHub fetches break.

## Remote-flip mechanics (insteadOf-first, not a set-url sweep)

The working-layer flip does NOT need to touch ~100 `.git/config` files. A scoped git
`insteadOf` rule redirects every `github.com/LarsArtmann/*` remote to Forgejo transparently
(fetch, push, and clones), on every checkout at once, and is reversible in one line:

```gitconfig
[url "git@forgejo.home.lan:lars/"]
    insteadOf = git@github.com:LarsArtmann/
    insteadOf = https://github.com/LarsArtmann/
```

- Scoped to the `LarsArtmann` owner only — third-party origins (upstream clones, forks of other
  owners) are untouched.
- Unmirrored stray repos fail LOUDLY on first push (repo missing on Forgejo) instead of silently
  staying GitHub-canonical — a feature: the failure names the repos to add to the mirror list.
- `git remote get-url origin` still shows the GitHub URL (insteadOf applies at transport time);
  scripts/gh-CLI that read the raw URL keep targeting GitHub for issues/CI/API — which is CORRECT
  while GitHub remains the live mirror.
- Needs to land on BOTH machines: evo-x2 and Lars-MacBook-Air (ideally declaratively via HM
  `programs.git`, so it survives reinstalls).
- Real `git remote set-url origin <forgejo>` becomes an optional end-state cleanup (on-touch or a
  scripted sweep) AFTER the insteadOf shim has proven itself; dropping the shim is only safe once
  no checkout relies on it.

**Ordering rule:** remotes flip FIRST (via shim), pull-mirror demote trails per repo. While both
mirror directions run, content is identical on both forges so pull+push mirrors no-op harmlessly —
a missed muscle-memory push to GitHub still converges into Forgejo via the pull mirror. Only
demote a repo's pull-mirror after its burn-in window.

**Pre-flip audit:** enumerate every checkout whose origin is `github.com/LarsArtmann/*` and join
against the Forgejo repo list, so stray/unmirrored repos are known before pushes hit them:

```bash
find ~/projects -maxdepth 4 -name .git -type d 2>/dev/null \
  | while read -r g; do r="${g%/.git}"; \
      u=$(git -C "$r" config --get remote.origin.url 2>/dev/null) \
      && echo "$u|$r"; done | grep -F 'github.com/LarsArtmann' | sort
```

## Phased todos

### P1 — finish staging (before any flip)
- [ ] Forgejo runner: CI token + Attic cache (TODO_LIST:154 — `attic cache create`, `atticadm
      make-token`, configure runner; push `signoz-frontend` + `hermes-agent` build trees)
- [ ] Port the 4 GitHub workflows to `.forgejo/workflows/` (nix-check, nixpkgs-compat,
      secret-history-scan, image-updates) — dual-run; GitHub CI keeps firing via mirror pushes
- [ ] Image-updates workflow: verify it can open Issues via Forgejo API + FORGEJO_TOKEN
- [ ] File the 3 verified mirror bugs upstream (verify-before-filing against current main first)
- [ ] Gatus: mirror-freshness check (newest `mirror.updated_unix` age across tracked repos)

### P2 — flip private repos first (lowest blast radius)
- [ ] Run the remote audit (see mechanics section) on evo-x2 AND Lars-MacBook-Air; reconcile
      strays against the `forgejo-repos` mirror list (add missing or leave on GitHub deliberately)
- [ ] Install the scoped `insteadOf` shim on both machines (declaratively via HM `programs.git`)
- [ ] Pilot ONE scratch repo end-to-end: commit on Forgejo → push-mirror lands on GitHub →
      consumer `nix flake lock --update-input X` resolves the new rev via the github: URL
- [ ] Per-repo pull-mirror demote only after burn-in (keep push-mirror forever)
- [ ] Verify the SSH git path once (`git ls-remote git@forgejo.home.lan:lars/<repo>.git`) —
      keys arrive via `forgejo-ssh-keys` provisioning
- [ ] Optional per-checkout polish: `git remote set-url origin` on touch; drop the shim only when
      every active checkout has a real Forgejo remote

### P3 — flip public repos
- [ ] Same per-repo flip; confirm proxy.golang.org still resolves new tags of a public Go lib
      (module path unchanged + tags present on mirror)
- [ ] templ-components consumers: nothing to change (github: URLs keep working); document in
      README that canonical development moved to Forgejo

### P4 — harden + offsite (after flip, per decision #4)
- [ ] restic backup of forgejo dump zips → Hetzner Storage Box/B2 (metadata: issues/PRs/releases
      exist nowhere else); restore rehearsal
- [ ] GitHub branch protection on active mirrored repos (read-only seatbelt)
- [ ] Decide `DEFAULT_ACTIONS_URL` → `data.forgejo.org` once GitHub-hosted actions are replaced
- [ ] Optional: sev1-bridge watch for forgejo unit failures (same pattern as gatus/dnsblockd)
- [ ] Record GitHub-mirror freshness in backup-coordination or a dedicated metric (stale mirror =
      stale public interface)

### Explicitly deferred (only if GitHub is ever cut off)
- flake input rewrite (~40 inputs, narHash re-locks, per-machine auth)
- vanity Go import path for public libs
- GitHub account deletion/archival
- Off-LAN git access (VPN/Tailscale) — declined for now

---

**Sources:** forgejo.org (v16.0.3 stable / v15 LTS, quarterly cadence; Actions production-grade,
`github` context aliased, runner v13 Linux amd64/arm64 + macOS; no marketplace — curated
`data.forgejo.org`); nix manual tarball protocol + NixOS/nix#11135, #11467; docs.renovatebot.com
(`platform = "forgejo"` fully supported, PAT-only, no Mend CE/EE); Forgejo repo-mirror docs
(push mirrors force-push, git-data-only sync, sync_on_commit supported).
