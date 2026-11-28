#!/usr/bin/env bash
# cargo-gate: refuse to START Rust builds that have hard-frozen this box.
#
# Evidence class (freezes #60-63, 2026-11-22..24): agent/owner shells ran
# cargo test/clippy batteries whose target/ resolves onto /mnt/rust-cache —
# a 224G USB SSD that regrows to 100% in ~6 days (~28G/day, Nov-18 owner
# cargo-clean 92%->31% refilled by Nov-24). A DuckDB-class compile writing
# into the full disk + sustained all-core load rode the box into its
# documented hard-freeze classes (IO livelock + Tctl ceiling; journal cuts
# mid-traffic, no panic). See SystemNix docs/agents/stability.md.
#
# Gates (compile-type subcommands only; metadata/fmt/--version pass through):
#   1. Target filesystem headroom: >= RUST_BUILD_MAX_USAGE% (92) or
#      < RUST_BUILD_MIN_FREE_MB (10240) -> refuse. The 2026-11-24 crash
#      started with 11G free and ate it in ~10 minutes.
#   2. IO PSI some avg10 >= RUST_BUILD_MAX_PSI (60) -> the box is storming
#      (deploy gates use the same reading).
#   3. k10temp >= RUST_BUILD_MAX_TCTL_MILLIC (90000 = 90C) -> the box dies
#      at 95-99C under sustained compile (owner-waived cooling; software
#      containment is the terminal strategy).
#
# Escape: RUST_BUILD_GATE=0 cargo ... — for when a build MUST run anyway.
#
# Deployment: ~/.config/direnv/bin/cargo (SystemNix
# platforms/common/programs/direnv.nix), prepended to PATH by
# direnv-smart-lib.sh at lib load and re-prepended AFTER `use flake` in
# .envrc files (the devShell profile lands in front of lib-level edits).
# rust-analyzer is unaffected: its constant `cargo metadata` calls are
# pass-through subcommands.
# LIMIT (live-verified 2026-11-25, crashes #64 + #65): `nix develop -c cargo ...`
# and nix shells put the devshell cargo in FRONT of this shim, so
# agent-style invocations never pass these start gates (inside the
# devshell `type -a cargo` resolves the store toolchain first). Those
# paths are bounded by the session env caps in platforms/nixos/users/
# home.nix (CARGO_BUILD_JOBS=12, RUST_TEST_THREADS=8, NEXTEST_JOBS=8,
# NEXTEST_TEST_THREADS=8) and by the IO-PAUSE zone-6 guard.
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find the REAL cargo: first cargo on PATH outside this script's own dir.
# Works for nix devShell toolchains, rustup shims, and profile installs.
real_cargo=""
old_ifs=$IFS
IFS=:
for dir in $PATH; do
  [ "$dir" = "$SELF_DIR" ] && continue
  if [ -x "$dir/cargo" ]; then
    real_cargo="$dir/cargo"
    break
  fi
done
IFS=$old_ifs

if [ -z "$real_cargo" ]; then
  echo "cargo-gate: no real cargo found on PATH outside $SELF_DIR" >&2
  exit 127
fi

# First non-flag, non-toolchain-override argument is the subcommand
# (cargo +nightly build / cargo --version / cargo metadata all handled).
sub=""
for arg in "$@"; do
  case "$arg" in
  +* | -*) ;;
  *)
    sub=$arg
    break
    ;;
  esac
done

# Only gate subcommands that compile/link. Everything else (metadata, fmt,
# version, tree, locate-project, ...) execs straight through — zero cost.
case "$sub" in
build | test | run | bench | check | clippy | doc | install | rustc | fix | expand | package | publish) ;;
*)
  exec "$real_cargo" "$@"
  ;;
esac

if [ "${RUST_BUILD_GATE:-1}" = "0" ]; then
  exec "$real_cargo" "$@"
fi

refuse() {
  echo "cargo-gate: REFUSED ($1)" >&2
  echo "  A refused build is protecting this machine, not breaking it." >&2
  echo "  Escape hatch: RUST_BUILD_GATE=0 cargo $sub ... (know what you are doing)" >&2
  exit 125
}

# Gate 1: target filesystem headroom (df resolves the deepest existing
# ancestor mount, so a not-yet-created target dir still gets the right fs).
target_dir="${CARGO_TARGET_DIR:-$PWD/target}"
dfs_out="$(df -B1M --output=pcent,avail "$target_dir" 2>/dev/null | tail -n1 || true)"
if [ -n "$dfs_out" ]; then
  disk_pct="$(printf '%s' "$dfs_out" | awk '{gsub(/%/,"",$1); print $1}')"
  disk_free_mb="$(printf '%s' "$dfs_out" | awk '{print $2}')"
  disk_fs="$(df --output=source "$target_dir" 2>/dev/null | tail -n1)"
  max_usage="${RUST_BUILD_MAX_USAGE:-92}"
  min_free_mb="${RUST_BUILD_MIN_FREE_MB:-10240}"
  if [ "${disk_pct:-0}" -ge "$max_usage" ] 2>/dev/null ||
    [ "${disk_free_mb:-9999999}" -lt "$min_free_mb" ] 2>/dev/null; then
    echo "cargo-gate: target filesystem $disk_fs is at ${disk_pct}% with $((disk_free_mb / 1024))G free" >&2
    echo "  Building into a nearly-full cache disk froze this box 4x (2026-11-22..24)." >&2
    echo "  Reclaim first:" >&2
    echo "    monitor365:  bash scripts/target-gc.sh --apply   (fingerprint GC; run when cargo is idle)" >&2
    echo "    any project: cargo clean                        (drops that project's whole target cache)" >&2
    echo "    disk state:  df -h /mnt/rust-cache" >&2
    refuse "disk ${disk_fs} ${disk_pct}% full / ${min_free_mb}MB minimum"
  fi
fi

# Gate 2: IO pressure storm (same reading the deploy gate uses).
psi_avg10="$(awk '/^some /{sub("avg10=","",$2); print $2; exit}' /proc/pressure/io 2>/dev/null)"
if [ -n "$psi_avg10" ]; then
  max_psi="${RUST_BUILD_MAX_PSI:-60}"
  if awk -v v="$psi_avg10" -v t="$max_psi" 'BEGIN{exit !(v>=t)}'; then
    echo "cargo-gate: box is IO-storming (io PSI some avg10=${psi_avg10}%) — a heavy build here is the freeze class" >&2
    echo "  Current: $(head -1 /proc/pressure/io)" >&2
    echo "  Wait for calm, or shed the storm source first (gatus / SigNoz)." >&2
    refuse "io PSI avg10 ${psi_avg10}% >= ${max_psi}%"
  fi
fi

# Gate 3: thermal ceiling (k10temp; sensor absent = skip, other hosts).
max_tctl="${RUST_BUILD_MAX_TCTL_MILLIC:-90000}"
for hw in /sys/class/hwmon/hwmon*; do
  [ "$(cat "$hw/name" 2>/dev/null)" = "k10temp" ] || continue
  tctl="$(cat "$hw/temp1_input" 2>/dev/null)" || continue
  if [ -n "$tctl" ] && [ "$tctl" -ge "$max_tctl" ] 2>/dev/null; then
    echo "cargo-gate: Tctl is at $((tctl / 1000))C — this box hard-cuts at 95-99C under sustained compile" >&2
    echo "  Cooling is owner-waived (terminal constraint); software gating is the containment." >&2
    refuse "Tctl $((tctl / 1000))C >= $((max_tctl / 1000))C"
  fi
done

exec "$real_cargo" "$@"
