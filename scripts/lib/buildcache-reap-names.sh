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
BUILDCACHE_REAP_HOME_DIRS=".local/state/pnpm .cargo/registry .local/share/pnpm/store"
