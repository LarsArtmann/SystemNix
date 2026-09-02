#!/usr/bin/env bash
# crush-rc-test.sh — test a crushrc in an isolated XDG_CONFIG_HOME without
# touching the live config, sessions, or secrets state.
#
# WHY: crushrc is executed at every crush start; a bad statement (unknown
# flag, failing $(command), enum violation) ABORTS the whole config load —
# all providers, LSPs, and MCPs vanish. The 2026-08-31 crush consolidation
# session built this harness to prove rc changes (model add flags, provider
# injections) before they reach the HM crushrc and a deploy.
#
# USAGE:
#   bash scripts/crush-rc-test.sh                       # test the LIVE HM crushrc
#   bash scripts/crush-rc-test.sh ./my-candidate-rc     # test a candidate file
#   EXTRA="model add zai/glm-5.3-flash ..." bash scripts/crush-rc-test.sh
#                                                       # test live rc + extra line
#
# WHAT IT DOES:
#   1. bash -n syntax check on the rc
#   2. loads it via `crush models` in a throwaway XDG_CONFIG_HOME
#      (sops secrets under /run/secrets stay readable — key injections work)
#   3. prints the loaded provider count; OPTIONAL=true runs one trivial
#      completion against -m provider/model to prove a key end-to-end
#
# NOTE: `crush models` load output goes to stderr on rc errors — a failing
# rc aborts the load and this script exits non-zero with the crush error.

set -euo pipefail

PROBE=false
CANDIDATE=""
for arg in "$@"; do
  case "$arg" in
  --probe) PROBE=true ;;
  *) CANDIDATE="$arg" ;;
  esac
done
EXTRA="${EXTRA:-}"

if [[ -n $CANDIDATE ]]; then
  RC_FILE="$CANDIDATE"
elif [[ -L "${XDG_CONFIG_HOME:-$HOME/.config}/crush/crushrc" ]]; then
  RC_FILE="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/crush/crushrc")"
else
  RC_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/crush/crushrc"
fi

if [[ ! -r $RC_FILE ]]; then
  echo "FAIL: crushrc not readable: $RC_FILE" >&2
  exit 1
fi

echo "target rc: $RC_FILE"

# 1. syntax
if ! bash -n "$RC_FILE"; then
  echo "FAIL: bash -n rejected the rc" >&2
  exit 1
fi
echo "PASS: bash -n"

# 2. isolated load
T="$(mktemp -d /tmp/crush-rc-test.XXXXXX)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/crush"
cp "$RC_FILE" "$T/crush/crushrc"
chmod u+w "$T/crush/crushrc"
if [[ -n $EXTRA ]]; then
  printf '\n%s\n' "$EXTRA" >>"$T/crush/crushrc"
  echo "extra line appended: $EXTRA"
fi

export XDG_CONFIG_HOME="$T"
PROVIDERS_BEFORE="$(grep -cE '^provider add' "$T/crush/crushrc" || true)"

if ! crush models >"$T/models.out" 2>"$T/models.err"; then
  echo "FAIL: crush models — rc load aborted:" >&2
  cat "$T/models.err" >&2
  exit 1
fi
echo "PASS: rc loads ($PROVIDERS_BEFORE provider add statements)"
echo "models available: $(wc -l <"$T/models.out")"
grep -E "^(zai|gemini|minimax|kimi-coding|synthetic|llamacpp)/" "$T/models.out" | head -8 || true

# 3. optional end-to-end key probe (costs one trivial completion)
if [[ $PROBE == true && -n ${PROBE_MODEL:-} ]]; then
  if timeout 120 crush run -q -m "$PROBE_MODEL" "Reply with exactly: RC-OK" | grep -q "RC-OK"; then
    echo "PASS: $PROBE_MODEL served RC-OK"
  else
    echo "FAIL: $PROBE_MODEL did not serve RC-OK" >&2
    exit 1
  fi
fi

echo "OK — rc is load-safe"
