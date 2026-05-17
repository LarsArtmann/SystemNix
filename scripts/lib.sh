#!/usr/bin/env bash
# Shared shell script library for SystemNix scripts.
# Usage: source "$(dirname "$0")/lib.sh"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# --- Counters ---
_PASS=0
_FAIL=0
_WARN=0

ok() {
  _PASS=$((_PASS + 1))
  echo -e "  ${GREEN}OK${NC}    $1"
}

fail() {
  _FAIL=$((_FAIL + 1))
  echo -e "  ${RED}FAIL${NC}  $1"
}

warn() {
  _WARN=$((_WARN + 1))
  echo -e "  ${YELLOW}WARN${NC}  $1"
}

info() {
  echo -e "  ${DIM}INFO${NC}  $1"
}

section() {
  echo -e "\n${BOLD}$1${NC}"
}

summary() {
  local total=$((_PASS + _FAIL + _WARN))
  echo ""
  if [[ $_FAIL -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}All ${_PASS} checks passed${NC}${_WARN:+ ($_WARN warnings)}"
  else
    echo -e "${RED}${BOLD}${_FAIL} failed${NC}, ${_WARN} warnings, ${_PASS} passed"
  fi
  echo ""
  [[ $_FAIL -eq 0 ]]
}

# Consecutive failure counter — persists across invocations via state file.
# Usage:
#   state_init /var/lib/my-check state 3  # creates dir, sets vars
#   # ... check condition ...
#   state_hit  && echo "threshold reached"  # increment + check
#   state_reset                              # clear counter on success
#
state_dir=""
state_file=""
state_threshold=0
state_count=0

state_init() {
  state_dir="$1"
  state_file="$1/$2"
  state_threshold="$3"
  state_count=0
  mkdir -p "$state_dir" 2>/dev/null || true
}

state_hit() {
  if [ -f "$state_file" ]; then
    state_count=$(cat "$state_file" 2>/dev/null || echo 0)
  fi
  state_count=$((state_count + 1))
  echo "$state_count" >"$state_file"
  [ "$state_count" -ge "$state_threshold" ]
}

state_reset() {
  rm -f "$state_file"
  state_count=0
}
