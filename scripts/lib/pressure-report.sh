# Shared system-pressure reporting for post-deploy-check.sh, extracted so
# the WARN/PASS semantics are fixture-testable (2026-09-02 T07: the old
# inline check printed PASS "healthy" at memory-PSI avg10 48-77% during a
# live storm — a lying gate; scripts/test-post-deploy-pressure.sh feeds
# synthetic PSI/meminfo/zram files through the SAME code path).
#
# Sourced (NEVER executed). The sourcer MUST define report_pass/report_warn/
# report_skip helpers. File paths default to /proc + /sys and are
# parameter-overridable per call:
#   systemnix_report_pressure [psi_io] [psi_mem] [meminfo] [zram_mmstat] [zram_disksize]
# Semantics mirror the deploy.sh blocking gate (its thresholds WARN here —
# the deploy already happened; this reports what the box landed into and
# must NEVER call a storm "healthy").
systemnix_report_pressure() {
  local psi_io_file="${1:-/proc/pressure/io}"
  local psi_mem_file="${2:-/proc/pressure/memory}"
  local meminfo_file="${3:-/proc/meminfo}"
  local zram_mmstat_file="${4:-/sys/block/zram0/mm_stat}"
  local zram_disksize_file="${5:-/sys/block/zram0/disksize}"

  # I/O pressure (PSI) — catches the exact condition that caused Helium 3
  # FPS + WDT crashes during nix build storms on QLC NAND. <20% healthy,
  # 20-80% elevated (storm building), >80% saturated.
  if [ -f "$psi_io_file" ]; then
    local io_avg10
    io_avg10=$(awk '/^some/{print $2}' "$psi_io_file" | cut -d= -f2)
    local io_saturated io_elevated
    io_saturated=$(awk "BEGIN { exit !(${io_avg10:-0} > 80) }" && echo 1 || echo 0)
    io_elevated=$(awk "BEGIN { exit !(${io_avg10:-0} >= 20) }" && echo 1 || echo 0)
    if [ "$io_saturated" = "1" ]; then
      report_warn "System — I/O pressure avg10=${io_avg10}% (>80% SATURATED — BFQ tiers may need attention)"
    elif [ "$io_elevated" = "1" ]; then
      report_warn "System — I/O pressure avg10=${io_avg10}% (elevated, 20-80% — a storm is building; the deploy gate blocks new deploys at this level)"
    else
      report_pass "System — I/O pressure avg10=${io_avg10}% (healthy)"
    fi
  else
    report_skip "System — /proc/pressure/io not available"
  fi

  # MEMORY pressure (PSI) — the 2026-09-02 lying-gate companion: the evening
  # storm ran memory PSI some avg10 at 48-77% while this script's only
  # pressure verdicts were I/O ones. Blocking thresholds from deploy.sh
  # (avg10 >= 20% storm, >= 5% elevated) become WARN here.
  if [ -f "$psi_mem_file" ]; then
    local mem_avg10
    mem_avg10=$(awk '/^some/{print $2}' "$psi_mem_file" | cut -d= -f2)
    local mem_storm mem_elevated
    mem_storm=$(awk "BEGIN { exit !(${mem_avg10:-0} >= 20) }" && echo 1 || echo 0)
    mem_elevated=$(awk "BEGIN { exit !(${mem_avg10:-0} >= 5) }" && echo 1 || echo 0)
    if [ "$mem_storm" = "1" ]; then
      report_warn "System — memory PSI some avg10=${mem_avg10}% (>=20% STORM — deploy.sh would BLOCK new deploys at this level; freeze-precursor territory, watch the emergency guard)"
    elif [ "$mem_elevated" = "1" ]; then
      report_warn "System — memory PSI some avg10=${mem_avg10}% (elevated, 5-20% — above the calm baseline; combined pre-freeze zone arms at zram>=95%)"
    else
      report_pass "System — memory PSI some avg10=${mem_avg10}% (calm)"
    fi
    # Combined pre-freeze zone (deploy.sh gate): zram >=95% WITH PSI >=5%.
    if [ -r "$zram_mmstat_file" ] && [ -r "$zram_disksize_file" ]; then
      local zram_orig zram_size
      zram_orig=$(awk '{print $1}' "$zram_mmstat_file" 2>/dev/null || echo 0)
      zram_size=$(cat "$zram_disksize_file" 2>/dev/null || echo 0)
      if [ "${zram_size:-0}" -gt 0 ] 2>/dev/null; then
        local zram_fill prefreeze
        zram_fill=$(awk -v o="$zram_orig" -v d="$zram_size" 'BEGIN { printf "%.1f", o * 100.0 / d }')
        prefreeze=$(awk "BEGIN { exit !(${zram_fill:-0} >= 95 && ${mem_avg10:-0} >= 5) }" && echo 1 || echo 0)
        if [ "$prefreeze" = "1" ]; then
          report_warn "System — combined pre-freeze zone: zram ${zram_fill}% (>=95%) WITH memory PSI avg10 ${mem_avg10}% (>=5%) — the documented freeze configuration (incidents #1/#2)"
        else
          report_pass "System — zram fill ${zram_fill}% (outside the combined pre-freeze zone)"
        fi
      fi
    fi
    if [ -r "$meminfo_file" ]; then
      local avail_pct avail_low
      avail_pct=$(awk '/^MemAvailable:/ {a=$2} /^MemTotal:/ {t=$2} END { if (t > 0) printf "%.1f", a * 100.0 / t }' "$meminfo_file")
      avail_low=$(awk "BEGIN { exit !(${avail_pct:-100} < 10) }" && echo 1 || echo 0)
      if [ "$avail_low" = "1" ]; then
        report_warn "System — MemAvailable ${avail_pct}% (<10% floor — deploy.sh would block new deploys)"
      else
        report_pass "System — MemAvailable ${avail_pct}%"
      fi
    fi
  else
    report_skip "System — /proc/pressure/memory not available"
  fi
}
