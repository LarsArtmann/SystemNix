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
#   bash scripts/crush-rc-test.sh --expect-model zai/glm-5.3-flash
#                                                       # assert model IDENTITY
#                                                       # (repeatable, = form works too)
#   bash scripts/crush-rc-test.sh --expect-live zai      # assert a provider is
#                                                       # CONFIGURED (repeatable)
#
# WHAT IT DOES:
#   1. bash -n syntax check on the rc
#   2. loads it via `crush models` in a throwaway XDG_CONFIG_HOME
#      (sops secrets under /run/secrets stay readable — key injections work)
#   3. prints the loaded provider count; asserts every --expect-model ID is
#      LISTABLE (a deleted config source may own entities nothing else
#      provides — assert WHICH entities exist, never just that the load
#      didn't crash); OPTIONAL --probe runs one trivial completion against
#      -m provider/model to prove a key end-to-end
#
# --expect-model PROVES NOTHING ABOUT A CATALOG PROVIDER: `crush models`
# lists every model of crush's built-in catalog even when the provider is
# disabled or has no key (live 2026-11-27: minimax, disabled, still lists
# its models). "Listed" only means "enabled" for a hand-declared,
# non-catalog model. For a catalog provider use --expect-live <name>: it
# lists under a TTY, where an unconfigured provider's header reads
# "<name> (not configured)", and fails when that marker is present.
#
# NOTE: `crush models` load output goes to stderr on rc errors — a failing
# rc aborts the load and this script exits non-zero with the crush error.

set -euo pipefail

PROBE=false
CANDIDATE=""
EXPECT_MODELS=()
EXPECT_LIVE=()
EXPECT_NEXT=false
LIVE_NEXT=false
for arg in "$@"; do
  if [[ $EXPECT_NEXT == true ]]; then
    EXPECT_MODELS+=("$arg")
    EXPECT_NEXT=false
  elif [[ $LIVE_NEXT == true ]]; then
    EXPECT_LIVE+=("$arg")
    LIVE_NEXT=false
  elif [[ $arg == --expect-live=* ]]; then
    EXPECT_LIVE+=("${arg#--expect-live=}")
  elif [[ $arg == --expect-live ]]; then
    LIVE_NEXT=true
  elif [[ $arg == --expect-model=* ]]; then
    EXPECT_MODELS+=("${arg#--expect-model=}")
  elif [[ $arg == --expect-model ]]; then
    EXPECT_NEXT=true
  else
    CANDIDATE="$arg"
  fi
done
if [[ $EXPECT_NEXT == true || $LIVE_NEXT == true ]]; then
  echo "FAIL: --expect-model or --expect-live given without a value" >&2
  exit 2
fi
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
T="$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/crush-rc-test.XXXXXX")" # /tmp is volatile (2026-10-17 wipe class)
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
# Model IDENTITY assertions (whole-line match — `provider/model` exactly).
for m in "${EXPECT_MODELS[@]}"; do
  if grep -qxF "$m" "$T/models.out"; then
    echo "PASS: expected model listed: $m"
  else
    echo "FAIL: expected model NOT listed: $m" >&2
    exit 1
  fi
done
grep -E "^(zai|gemini|minimax|synthetic|llamacpp)/" "$T/models.out" | head -8 || true

# Configured-provider assertions, through a TTY: the "(not configured)"
# marker prints only when stdout is a terminal.
if [[ ${#EXPECT_LIVE[@]} -gt 0 ]]; then
  script -qec "crush models" /dev/null 2>/dev/null | tr -d '\r' >"$T/models.tty" || true
  for provider in "${EXPECT_LIVE[@]}"; do
    header="$(grep -E "^[^a-zA-Z0-9_-]*${provider}( |$)" "$T/models.tty" | head -1)"
    if [[ -z $header ]]; then
      echo "FAIL: provider not listed at all: $provider" >&2
      exit 1
    elif [[ $header == *"not configured"* ]]; then
      echo "FAIL: provider is NOT configured (disabled or without a usable key): $provider" >&2
      exit 1
    fi
    echo "PASS: provider configured: $provider"
  done
fi

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
