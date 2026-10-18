#!/usr/bin/env bash
# scripts/lib/process.sh — PID-safe process helpers shared by harnesses.
#
# Why: (1) the kill builtin is unsupported in some agent shell interpreters —
# always the coreutils binary with an explicit PID; (2) `pkill -f <substr>`
# matches PRODUCTION unit ExecStart lines (2026-10-17 near-miss) — killing is
# PID-only, resolved from an explicit port or pgrep the CALLER vetted.
#
# Usage:
#   source scripts/lib/process.sh
#   pid=$(pid_of_port 18991) && kill_pid "$pid"
#   pids=$(pgrep_pids 'my-harness-name')   # caller MUST read the cmdlines first

# pid_of_port <port> — the LISTEN-ing socket owner's PID (empty when none).
# ss -ltnp parses the users:((...pid=123,)) form; first match wins.
pid_of_port() {
  local port=$1
  ss -ltnp 2>/dev/null |
    grep -F ":${port} " |
    grep -oE 'pid=[0-9]+' |
    head -1 |
    cut -d= -f2
}

# pgrep_pids <pattern> — PIDs whose full command line matches (max 20).
# Caller discipline: print `/proc/<pid>/cmdline`-derived cmdlines and verify
# they are YOUR harness before any kill — never a production-matching prefix.
pgrep_pids() {
  pgrep -f "$1" 2>/dev/null | head -20
}

# kill_pid <pid> [pid...] — TERM, wait up to 5s, then KILL survivors.
# Uses the coreutils kill binary (the shell builtin is unavailable in some
# agent interpreters).
kill_pid() {
  local pids=("$@") pid
  [ ${#pids[@]} -gt 0 ] || return 0
  /run/current-system/sw/bin/kill -- "${pids[@]}" 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    local alive=0
    for pid in "${pids[@]}"; do
      /run/current-system/sw/bin/kill -0 -- "$pid" 2>/dev/null && alive=1
    done
    [ "$alive" -eq 0 ] && return 0
    sleep 1
  done
  /run/current-system/sw/bin/kill -9 -- "${pids[@]}" 2>/dev/null || true
}

# harness_scratch <name> — a durable scratch dir under XDG_CACHE (NOT /tmp:
# tmpfiles wipes lost two harness runs on 2026-10-17). Echoes the path; the
# caller cleans it up when it matters (or lets the next run reuse it).
harness_scratch() {
  local base="${XDG_CACHE_HOME:-$HOME/.cache}/systemnix-harness"
  mkdir -p "$base"
  mktemp -d "$base/$1.XXXXXX"
}
