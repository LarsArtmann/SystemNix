#!/usr/bin/env bash
# borg-restore-drill — small-subset TIMED restore drill for the offsite Borg
# leg (Hetzner StorageBox; module platforms/nixos/system/backup.nix).
#
# An untested restore is Schrödinger's backup. This drill proves the restore
# path end to end — connect, resolve the newest archive, extract a small
# subset, verify the bytes — and times each phase, so RTO numbers exist
# BEFORE the first real disaster. Runbook: docs/services/offsite-borg-restore.md.
#
# Modes:
#   sudo bash scripts/borg-restore-drill.sh                 # REAL repo (rendered
#                                                           # sops env; root-only
#                                                           # because the secrets are
#                                                           # 0400 root)
#   bash scripts/borg-restore-drill.sh --local <repo-dir>   # stand-in drill against
#                                                           # any local borg repo
#                                                           # (no root, no sops)
#   bash scripts/borg-restore-drill.sh --selftest           # builds a throwaway
#                                                           # local repo (same
#                                                           # repokey-blake2 +
#                                                           # compression as the job),
#                                                           # backs a fixture tree up
#                                                           # into it, then drills
#                                                           # against it — proves the
#                                                           # whole path unprivileged
#
# Options:
#   --archive <name>   drill a pinned archive (default: newest)
#   --subset "p1 p2"   archive-relative paths to extract
#                      (default: "etc/hostname etc/machine-id" — tiny, always
#                      present, and byte-comparable against the live files)
#   --verify-data      add a deep-integrity phase: dry-run `borg extract -n`
#                      over the WHOLE archive (every chunk read + hash/HMAC
#                      checked + decompressed, nothing written) — much
#                      slower than the subset drill, distinct from it; uses
#                      borg2's --verify-data when the binary supports it
#   --keep             keep the extraction scratch dir instead of removing it
#
# Phases (each timed): connect+resolve (auth + newest-archive listing),
# extract, verify (existence + non-empty + cmp vs live file when one exists),
# and — with --verify-data — deep-integrity.
#
# The borg binary is ALWAYS resolved from THIS flake's locked nixpkgs, so the
# drill client is the same borg the backup job (and a real restore) runs — no
# version skew in the timings or the on-disk format handling.
#
# Exit codes: 0 = PASS, 1 = FAIL (any phase). A per-run record (full output +
# timings, including early failures — record setup happens BEFORE any env
# check) is written under ${XDG_STATE_HOME:-~/.local/state}/borg-restore-drill/;
# records are tiny text logs, pruned to the newest 100 on every run.
set -uo pipefail

SUBSET="etc/hostname etc/machine-id"
ARCHIVE_PIN=""
LOCAL_REPO=""
KEEP=0
SELFTEST=0
VERIFY_DATA=0

die() {
  echo "FAIL: $*" >&2
  # The outcome lines are appended DIRECTLY to the record (not via stdout) so
  # a fast early death cannot race the tee process substitution.
  if [ -n "${record:-}" ] && [ -f "$record" ]; then
    printf '  result           : FAIL\n  record           : %s\n' "$record" >>"$record"
    echo "  result           : FAIL"
    echo "  record           : $record"
  fi
  exit 1
}

usage() {
  awk 'NR == 1 { next } !/^#/ { exit } { sub(/^# ?/, ""); print }' "$0"
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
  --local)
    [ $# -ge 2 ] || usage
    LOCAL_REPO="$2"
    shift 2
    ;;
  --archive)
    [ $# -ge 2 ] || usage
    ARCHIVE_PIN="$2"
    shift 2
    ;;
  --subset)
    [ $# -ge 2 ] || usage
    SUBSET="$2"
    shift 2
    ;;
  --keep)
    KEEP=1
    shift
    ;;
  --verify-data)
    VERIFY_DATA=1
    shift
    ;;
  --selftest)
    SELFTEST=1
    shift
    ;;
  -h | --help)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

# Record setup happens BEFORE any env/mode check, so the likeliest real-world
# early failures (root gate, still-PLACEHOLDER repo at pre-go-live attempts,
# detached Samsung tier) leave a record too — the header promises one.
record_dir="${XDG_STATE_HOME:-$HOME/.local/state}/borg-restore-drill"
mkdir -p "$record_dir" || die "cannot create record dir: $record_dir"
record="$record_dir/drill-$(date +%Y%m%d-%H%M%S).log"
# Full output goes to stdout AND the record file (tee dies with the drill).
exec > >(tee "$record") 2>&1
# Retention housekeeping: records are tiny text logs; keep the newest 100.
# (ls -1t newest-first; tail -n +101 = everything past the first 100.)
ls -1t "$record_dir"/drill-*.log 2>/dev/null | tail -n +101 | while IFS= read -r old; do
  rm -f -- "$old"
done

# borg ships in the borgbackup job unit's PATH, not necessarily the interactive
# system PATH — and a PATH borg may be a DIFFERENT version than the job's.
# Resolve from THIS flake's locked nixpkgs so the drill client is byte-for-byte
# the binary the job (and a real restore) runs (store-cached after first hit).
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "[drill] resolving borg from this flake's locked nixpkgs ($repo_root)"
borg_expr='let f = builtins.getFlake (toString '"$repo_root"'); in f.inputs.nixpkgs.legacyPackages.${builtins.currentSystem}.borgbackup'
borg_out="$(nix build --no-link --print-out-paths --impure --expr "$borg_expr" 2>/dev/null)" ||
  die "flake-locked borgbackup eval failed — 'nix build --impure --expr \"$borg_expr\"' must work from the repo (is nix available + the flake parseable?)"
# Multi-output flake: --print-out-paths prints every output — pick the one
# that actually ships bin/borg.
while IFS= read -r d; do
  if [ -x "$d/bin/borg" ]; then
    export PATH="$d/bin:$PATH"
    break
  fi
done <<<"$borg_out"
command -v borg >/dev/null 2>&1 ||
  die "no bin/borg among flake outputs: $borg_out"
echo "[drill] borg: $(borg --version)"

MODE="real"
if [ "$SELFTEST" -eq 1 ]; then
  MODE="selftest"
  [ -z "$LOCAL_REPO" ] || die "--selftest takes no --local"
elif [ -n "$LOCAL_REPO" ]; then
  MODE="local"
  [ -d "$LOCAL_REPO" ] || die "--local repo dir not found: $LOCAL_REPO"
  [ -f "$LOCAL_REPO/config" ] || die "--local repo has no borg 'config' file: $LOCAL_REPO"
fi

if [ "$MODE" = "real" ]; then
  [ "$(id -u)" -eq 0 ] ||
    die "real-repo mode needs root (sops secrets render 0400 root) — run: sudo bash $0 (or use --local/--selftest)"
  # The default literal is eval-time-pinned to the sops template path by
  # platforms/nixos/system/backup.nix — change BOTH together (nix flake
  # check fails on drift).
  BORG_ENV_FILE="${BORG_ENV_FILE:-/run/secrets/rendered/borg-env}"
  [ -r "$BORG_ENV_FILE" ] || die "rendered borg env not readable: $BORG_ENV_FILE (is services.offsite-borg enabled + deployed?)"
  repo_line="$(grep -E '^BORG_REPO=' "$BORG_ENV_FILE" | head -1 | cut -d= -f2-)" ||
    die "no BORG_REPO line in $BORG_ENV_FILE"
  [ -n "$repo_line" ] || die "empty BORG_REPO in $BORG_ENV_FILE"
  case "$repo_line" in
  *PLACEHOLDER*)
    die "BORG_REPO is still the go-live placeholder — follow docs/services/offsite-borg.md (go-live checklist)"
    ;;
  esac
  [ -e /run/secrets/borg_password ] || die "/run/secrets/borg_password missing"
  [ -e /run/secrets/borg_ssh_key ] || die "/run/secrets/borg_ssh_key missing"
  [ -e /run/secrets/borg_known_hosts ] || die "/run/secrets/borg_known_hosts missing"
  # The job unit is mount-gated (RequiresMountsFor); the manual drill is not.
  # With /mnt/hot UNMOUNTED, borg happily mkdirs its cache under the bare
  # mountpoint — landing every cache byte on the ROOT fs (the shadow-dir class
  # this repo documents). Gate loudly; an override means editing the script.
  if ! mountpoint -q /mnt/hot; then
    die "/mnt/hot is not a mountpoint (Samsung tier detached?) — borg would write its cache onto the ROOT fs under the bare mountpoint. Mount /mnt/hot first (this gate mirrors the job unit's RequiresMountsFor)"
  fi
  export BORG_REPO="$repo_line"
  export BORG_PASSCOMMAND="cat /run/secrets/borg_password"
  # Same RSH + cache wiring as the job unit (backup.nix): reuse the warm
  # chunk cache so connect timings are realistic, and fail closed on an
  # unpinned host key. -p 23 is load-bearing (scp-form repo string — the
  # StorageBox serves Borg on 23 only, and the known_hosts pin is
  # [host]:23-shaped).
  export BORG_RSH="ssh -p 23 -i /run/secrets/borg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/run/secrets/borg_known_hosts"
  export BORG_CACHE_DIR="/mnt/hot/borg/cache"
  export BORG_CONFIG_DIR="/mnt/hot/borg/config"
fi

if [ "$MODE" = "selftest" ]; then
  selftest_root="$(mktemp -d)"
  export BORG_PASSPHRASE="borg-restore-drill-selftest"
  mkdir -p "$selftest_root/repo" "$selftest_root/src/etc"
  printf 'borg-restore-drill-selftest\n' >"$selftest_root/src/etc/hostname"
  printf '%s\n' "$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')" >"$selftest_root/src/etc/machine-id"
  borg init --encryption=repokey-blake2 "$selftest_root/repo" ||
    die "selftest borg init failed"
  export BORG_REPO="$selftest_root/repo"
  borg create --compression auto,zstd,9 "$selftest_root/repo::evo-x2-selftest" \
    "$selftest_root/src/etc" ||
    die "selftest borg create failed"
  # Archive paths are absolute (src/...), so the drill subset is remapped.
  SUBSET="${selftest_root#/}/src/etc/hostname ${selftest_root#/}/src/etc/machine-id"
  LIVE_CMP=0
fi

if [ "$MODE" = "local" ]; then
  export BORG_REPO="$LOCAL_REPO"
  LIVE_CMP=0
fi
if [ "$MODE" = "real" ]; then
  LIVE_CMP=1
fi

read -r -a SUBSET_PATHS <<<"$SUBSET"
[ "${#SUBSET_PATHS[@]}" -gt 0 ] || die "empty subset"

scratch="$(mktemp -d "${TMPDIR:-/tmp}/borg-restore-drill.XXXXXX")"
cleanup() {
  # The selftest fixture (repo + source tree) is throwaway in every mode.
  [ -n "${selftest_root:-}" ] && rm -rf "$selftest_root"
  if [ "$KEEP" -eq 1 ]; then
    echo "[drill] scratch kept: $scratch"
  else
    rm -rf "$scratch"
  fi
}
trap cleanup EXIT

echo "[drill] mode=$MODE repo=$BORG_REPO subset=\"${SUBSET//$'\n'/ }\""
echo "[drill] scratch=$scratch"

t_resolve_start="$(date +%s%3N)"
if [ -n "$ARCHIVE_PIN" ]; then
  archive_line="$(borg list 2>/dev/null | grep -F "$ARCHIVE_PIN" | head -1)"
  [ -n "$archive_line" ] || die "pinned archive not found: $ARCHIVE_PIN"
else
  archive_line="$(borg list --last 1 2>/dev/null | tail -1)"
  [ -n "$archive_line" ] || die "no archive found in $BORG_REPO"
fi
t_resolve_end="$(date +%s%3N)"
archive_name="$(printf '%s' "$archive_line" | awk '{print $1}')"
[ -n "$archive_name" ] || die "could not resolve an archive name"
echo "[drill] archive: $archive_line"

t_extract_start="$(date +%s%3N)"
# Extract into scratch, NEVER over the live tree (borg extract overwrites
# existing files without asking, and extracts relative to the CWD — hence
# the subshell cd).
if ! (cd "$scratch" && borg extract --list ::"$archive_name" "${SUBSET_PATHS[@]}"); then
  echo "FAIL: borg extract of subset failed" >&2
  exit 1
fi
t_extract_end="$(date +%s%3N)"

t_verify_start="$(date +%s%3N)"
verify_failed=0
for p in "${SUBSET_PATHS[@]}"; do
  out_file="$scratch/$p"
  if [ ! -s "$out_file" ]; then
    echo "FAIL: extracted file missing or empty: $p" >&2
    verify_failed=1
    continue
  fi
  sha="$(sha256sum "$out_file" | awk '{print $1}')"
  echo "[drill] $p ($(wc -c <"$out_file") bytes, sha256 $sha)"
  if [ "$LIVE_CMP" -eq 1 ] && [ -e "/$p" ]; then
    if cmp -s "$out_file" "/$p"; then
      echo "[drill] byte-identical to live /$p"
    else
      # Not a drill failure (the live file may legitimately have moved on
      # since the backup) — surface it, never hide it.
      echo "warn: extracted $p DIFFERS from live /$p (backup drift or live change)" >&2
    fi
  fi
done
t_verify_end="$(date +%s%3N)"
[ "$verify_failed" -eq 0 ] || exit 1

deep_ms=0
if [ "$VERIFY_DATA" -eq 1 ]; then
  t_deep_start="$(date +%s%3N)"
  echo "[drill] deep-integrity: dry-run extract over the WHOLE archive (every chunk read + checked, nothing written)"
  # borg 1.x extract has NO --verify-data flag — its --dry-run already reads
  # and checks every chunk (hash/HMAC, decrypt, decompress) per `borg extract
  # --help`. borg2 adds --verify-data (fuller integrity re-verification); use
  # it when the binary grows it, never pass it blindly at 1.x.
  if borg extract --help 2>&1 | grep -q -- --verify-data; then
    deep_args=(--dry-run --verify-data)
  else
    deep_args=(--dry-run)
  fi
  if ! (cd "$scratch" && borg extract "${deep_args[@]}" ::"$archive_name" >/dev/null); then
    echo "FAIL: deep-integrity dry-run verify pass failed (chunk corruption?)" >&2
    exit 1
  fi
  t_deep_end="$(date +%s%3N)"
  deep_ms=$((t_deep_end - t_deep_start))
  echo "[drill] deep-integrity: OK"
fi

resolve_ms=$((t_resolve_end - t_resolve_start))
extract_ms=$((t_extract_end - t_extract_start))
verify_ms=$((t_verify_end - t_verify_start))
total_ms=$((resolve_ms + extract_ms + verify_ms + deep_ms))

echo
echo "Restore drill summary"
echo "  mode             : $MODE"
echo "  repo             : $BORG_REPO"
echo "  archive          : $archive_name"
echo "  subset           : $SUBSET"
printf '  connect+resolve  : %s ms\n' "$resolve_ms"
printf '  extract          : %s ms\n' "$extract_ms"
printf '  verify           : %s ms\n' "$verify_ms"
if [ "$VERIFY_DATA" -eq 1 ]; then
  printf '  deep-integrity   : %s ms\n' "$deep_ms"
fi
printf '  TOTAL            : %s ms\n' "$total_ms"
echo "  result           : PASS"
echo "  record           : $record"
