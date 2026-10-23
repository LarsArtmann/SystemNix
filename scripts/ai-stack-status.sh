#!/usr/bin/env bash
# ai-stack-status.sh — berth's "who holds it, who waits, and why" as one
# command (berth-patterns plan T6). Aggregates the whole AI stack:
#   - unit states (flm socket/backend, llama-chat, llama-rag, vlm instances,
#     the memory guard) via ONE batched systemctl show (the PAM/session-burst
#     doctrine: never probe units one call at a time)
#   - port bind ownership from ss -ltnp against the expected owner unit
#     (FOREIGN holder = the P2/P5 incident classes at a glance)
#   - guard zone state: freshness (mtime + last_run age), restore_capped,
#     sacrifice socket, trips last hour, leak/dark gauges
#
# Contract: stdout = results (aligned table, or JSON with --format json),
# stderr = diagnostics, exit 0 = all green, exit 1 = anything red (failed
# unit, FOREIGN holder, leaks_present 1, rogue listeners > 0, guard stale,
# scrape errors). Ports arrive via AI_STACK_PORTS (JSON, injected by the
# flake app from lib/ports.nix — never hardcoded here).
#
# Run: nix run .#ai-stack-status [-- --format json]
set -uo pipefail

FORMAT="text"
for arg in "$@"; do
  case "$arg" in
    --format) ;;
    json) FORMAT="json" ;;
    *) echo "ai-stack-status: unknown argument: $arg (usage: [--format json])" >&2; exit 2 ;;
  esac
done

TEXTFILE_DIR="/var/lib/prometheus-node-exporter/textfile_collectors"
# single-line on purpose: `read -a` below consumes only the FIRST line of a
# herestring — a leading newline would silently produce an empty unit list
# (live-caught: every unit read not-found with a green systemctl call)
UNITS="fastflowlm.socket fastflowlm.service llama-chat.service llama-embeddings.service llama-reranker.service llama-vlm-e4b.socket llama-vlm-e4b.service llama-vlm-cap.socket llama-vlm-cap.service memory-emergency-guard.service memory-emergency-guard.timer"

red_reasons=()

# --- unit states (batched: one systemctl call for all) ---
declare -A unit_state2
last_id=""
read -r -a unit_args <<<"$UNITS"
while IFS= read -r line; do
  case "$line" in
    Id=*) last_id="${line#Id=}" ;;
    ActiveState=*) [ -n "$last_id" ] && unit_state2["$last_id"]="${line#ActiveState=}" ;;
  esac
done < <(systemctl show "${unit_args[@]}" -p Id -p ActiveState 2>/dev/null || true)

for u in $UNITS; do
  st="${unit_state2[$u]:-not-found}"
  if [ "$st" = "failed" ]; then
    red_reasons+=("unit $u FAILED")
  fi
done

# --- port ownership ---
ss_out="$(ss -ltnp 2>/dev/null || true)"
ports_json="${AI_STACK_PORTS:-[]}"
n_ports=$(jq -r 'length' <<<"$ports_json" 2>/dev/null || echo 0)

port_rows=()
for i in $(seq 0 $((n_ports - 1))); do
  port=$(jq -r ".[$i].port" <<<"$ports_json")
  owner=$(jq -r ".[$i].owner" <<<"$ports_json")
  label=$(jq -r ".[$i].label" <<<"$ports_json")
  # ss pads columns with runs of spaces — anchor on the port token followed
  # by whitespace (the Peer column), never on column positions
  line="$(grep -E ":${port}[[:space:]]" <<<"$ss_out" | grep -E '^LISTEN' | head -1 || true)"
  if [ -z "$line" ]; then
    verdict="free"
    holder="-"
  else
    pid="$(sed -n 's/.*pid=\([0-9]*\).*/\1/p' <<<"$line" | head -1)"
    if [ -z "$pid" ]; then
      # ss hides pids of sockets our user cannot ptrace (root-held incl.
      # systemd's own socket listeners). A hidden holder is FINE on an
      # ACTIVE socket unit (that is PID 1 holding the listening fd), but
      # on anything else it is an unattributable holder = the rogue class.
      if [[ "$owner" == *.socket ]] && [ "${unit_state2[$owner]:-}" = "active" ]; then
        holder="systemd (socket)" verdict="systemd(socket)"
      else
        holder="pid-hidden" verdict="HELD-UNVERIFIED"
        red_reasons+=(":$port held by an UNVERIFIABLE listener (owning unit ${unit_state2[$owner]:-not-found}, not an active socket) - the 2026-09-18 rogue class; run: sudo ss -ltnp 'sport = :$port'")
      fi
    else
      cg="$(cat "/proc/$pid/cgroup" 2>/dev/null || echo unreadable)"
      holder="pid $pid (${cg##*/})"
      case "$cg" in
        *"$owner"*) verdict="owner" ;;
        *init.scope*|*/system.slice/systemd*) verdict="systemd(socket)" ;;
        *) verdict="FOREIGN"; red_reasons+=(":$port held by FOREIGN $holder") ;;
      esac
    fi
  fi
  port_rows+=("$label|$port|$verdict|$holder")
done

# --- guard + leak/dark gauges ---
prom_field() { # <file> <metric> -> value or ""
  [ -r "$1" ] || return 0
  awk -v m="$2" '$1 == m {print $2; exit}' "$1"
}
guard_prom="$TEXTFILE_DIR/memory-emergency-guard.prom"
leaks_prom="$TEXTFILE_DIR/llama-rag-leaks.prom"
dark_prom="$TEXTFILE_DIR/llama-rag-dark.prom"

guard_fresh="absent"
if [ -f "$guard_prom" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$guard_prom") ))
  if [ "$age" -le 300 ]; then guard_fresh="fresh(${age}s)"; else guard_fresh="STALE(${age}s)"; red_reasons+=("memory-emergency-guard metrics STALE (${age}s) — RAM broker unwatched"); fi
fi
restore_capped="$(prom_field "$guard_prom" memory_emergency_guard_restore_capped)"
sacrificed="$(prom_field "$guard_prom" memory_emergency_guard_sacrifice_socket_active)"
trips_lh="$(prom_field "$guard_prom" memory_emergency_guard_trips_last_hour)"
leaks_present="$(prom_field "$leaks_prom" llama_rag_leaks_present)"
leaked_n="$(prom_field "$leaks_prom" llama_rag_leaked_instances)"
leak_err="$(prom_field "$leaks_prom" llama_rag_scrape_errors)"
rogues="$(prom_field "$dark_prom" llama_rag_ports_rogue_listeners)"
[ "$leaks_present" = "1" ] && red_reasons+=("llama-rag leaked instances: $leaked_n")
[ "$leak_err" = "1" ] && red_reasons+=("llama-rag leak collector scrape error")
[ "$rogues" -ge 1 ] 2>/dev/null && red_reasons+=("llama-rag dark-guard rogue listeners detected (check journal)")

# --- output ---
if [ "$FORMAT" = "json" ]; then
  {
    printf '{"units":{'
    first=1
    for u in $UNITS; do
      [ $first = 1 ] || printf ','
      first=0
      printf '"%s":"%s"' "$u" "${unit_state2[$u]:-not-found}"
    done
    printf '},"ports":['
    first=1
    for row in "${port_rows[@]}"; do
      IFS='|' read -r label port verdict holder <<<"$row"
      [ $first = 1 ] || printf ','
      first=0
      printf '{"label":"%s","port":%s,"verdict":"%s","holder":"%s"}' "$label" "$port" "$verdict" "$holder"
    done
    printf '],"guard":{"fresh":"%s","restore_capped":"%s","sacrifice_socket_active":"%s","trips_last_hour":"%s"}' \
      "$guard_fresh" "${restore_capped:-absent}" "${sacrificed:-absent}" "${trips_lh:-absent}"
    printf ',"leaks":{"present":"%s","instances":"%s","scrape_errors":"%s","rogue_listeners":"%s"}' \
      "${leaks_present:-absent}" "${leaked_n:-absent}" "${leak_err:-absent}" "${rogues:-absent}"
    printf ',"red":['
    first=1
    for r in "${red_reasons[@]:-}"; do
      [ -n "$r" ] || continue
      [ $first = 1 ] || printf ','
      first=0
      printf '"%s"' "$r"
    done
    printf ']}\n'
  }
else
  printf '%-28s %-12s %-7s %-10s %s\n' "UNIT" "STATE" "PORT" "VERDICT" "HOLDER"
  for row in "${port_rows[@]}"; do
    IFS='|' read -r label port verdict holder <<<"$row"
    owner_unit="$(jq -r --argjson p "$port" '.[] | select(.port == $p) | .owner' <<<"$ports_json" 2>/dev/null || echo '?')"
    st="${unit_state2[$owner_unit]:-not-found}"
    printf '%-28s %-12s %-7s %-10s %s\n' "$label" "$st" "$port" "$verdict" "$holder"
  done
  printf '\nguard: %s | restore_capped=%s sacrifice_socket=%s trips_1h=%s\n' \
    "$guard_fresh" "${restore_capped:-absent}" "${sacrificed:-absent}" "${trips_lh:-absent}"
  printf 'leaks: present=%s instances=%s scrape_errors=%s rogues(dark)=%s\n' \
    "${leaks_present:-absent}" "${leaked_n:-absent}" "${leak_err:-absent}" "${rogues:-absent}"
  if [ ${#red_reasons[@]} -gt 0 ] && [ -n "${red_reasons[0]}" ]; then
    printf '\nRED:\n' >&2
    for r in "${red_reasons[@]}"; do printf '  - %s\n' "$r" >&2; done
    exit 1
  fi
  printf '\nall green\n'
fi
