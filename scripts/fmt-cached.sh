#!/usr/bin/env bash
# fmt-cached — format files with the repo's LOCKED treefmt formatter,
# reusing the pre-commit formatter memo (scripts/lib/precommit-eval-cache.sh)
# to skip the full flake eval whenever flake.nix / flake.lock / overlays/ /
# lib/ are unchanged since the last resolve. Any miss falls through to the
# real `nix build .#formatter.$sys`. CI arbitrates formatting with
# `nix fmt -- --ci` either way — drift fails red, never silent.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/lib/precommit-eval-cache.sh
source scripts/lib/precommit-eval-cache.sh

case "$(uname -m)" in
arm64 | aarch64) sys=aarch64-darwin ;;
*) sys=x86_64-linux ;;
esac

if p=$(precommit_formatter_cached_path 2>/dev/null); then
  echo "[fmt-cached] memo HIT — reusing $p" >&2
  exec "$p/bin/treefmt" "$@"
fi

echo "[fmt-cached] memo MISS — resolving .#formatter.$sys (full flake eval)..." >&2
p=$(nix build ".#formatter.$sys" --no-link --print-out-paths --no-update-lock-file)
precommit_formatter_store_path "$p" || true
exec "$p/bin/treefmt" "$@"
