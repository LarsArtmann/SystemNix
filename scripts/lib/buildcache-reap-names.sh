# shellcheck shell=sh disable=SC2034  # sourced by deploy.sh, never executed
# Single source of truth for the env-less cache reap inventories: the
# home.file out-of-store symlinks (platforms/nixos/users/home.nix) whose
# targets live on /mnt/buildcache. While the mount is dead, env-less tools
# recreate these paths as REAL dirs, which both re-contaminates the NVMe with
# build churn AND aborts the next home-manager activation (checkLinkTargets
# "Existing file ... in the way"). Every reap surface consumes THESE lists —
# never keep a private copy:
#   - scripts/deploy.sh pre-switch reap (unconditional of mount state)
#   - buildcache-usb-recovery step 2.5 (modules/nixos/services/buildcache.nix)
#   - home.nix activation.migrate-buildcache-fallback-caches (mount-gated)
# Nix consumers parse this file via lib/buildcache-cache-names.nix so the
# shell and Nix surfaces cannot drift.
# BUILDCACHE_REAP_CACHE_DIRS entries are ~/.cache/<name>;
# BUILDCACHE_REAP_HOME_DIRS entries are $HOME/<path> (relative, may contain
# slashes). 2026-09-17: gobuild/gocache/gomod — BuildFlow's cross-repo
# fallback names the original list evaded forever.
BUILDCACHE_REAP_CACHE_DIRS="goimports go go-build gobuild gocache gomod pnpm"
# .npm (2026-10-10): env-less npm's DEFAULT cache location — the last
# real-dir fallback from the 2026-09-22 sweep; converged onto
# /mnt/buildcache/npm via the home.nix HM out-of-store symlink.
BUILDCACHE_REAP_HOME_DIRS=".local/state/pnpm .cargo/registry .local/share/pnpm/store .npm"
# Subset of BUILDCACHE_REAP_CACHE_DIRS that is reaped but deliberately NOT
# an HM out-of-store symlink (no home.file entry): BuildFlow's cross-repo
# fallback names exist only when an env-less tool ran without the mount, so
# absence is their normal state. Surfaces that need the "HM-managed
# must-be-symlink paths" set derive it as
# REAP_CACHE_DIRS − REAP_FALLBACK_ONLY_CACHE_DIRS, plus REAP_HOME_DIRS.
BUILDCACHE_REAP_FALLBACK_ONLY_CACHE_DIRS="gobuild gocache gomod"
