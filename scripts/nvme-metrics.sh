#!/usr/bin/env bash
# NVMe SMART metrics collector for node_exporter textfile
# Requires: nvme-cli (nvme smart-log)
# Usage: nvme-metrics.sh [device] [output_file]
set -euo pipefail

DEVICE="${1:-/dev/nvme0n1}"
OUT="${2:-/var/lib/prometheus-node-exporter/textfile_collectors/nvme.prom}"
TMP="${OUT}.tmp"

if ! command -v nvme &>/dev/null; then
  echo "nvme-cli not found, skipping" >&2
  exit 0
fi

# Read SMART log as JSON
SMART=$(nvme smart-log -o json "$DEVICE" 2>/dev/null) || {
  echo "Failed to read SMART log from $DEVICE" >&2
  exit 1
}

# Extract device identifier for labels
DEV_NAME=$(basename "$DEVICE")

# Parse JSON values using grep+sed (no jq dependency)
extract() {
  local key="$1"
  echo "$SMART" | grep -oP "\"${key}\"\s*:\s*\K[0-9]+"
}

# Temperature: extract numeric value from "40°C" or raw Kelvin
TEMP_KELVIN=$(echo "$SMART" | grep -oP '"temperature"\s*:\s*\K[0-9]+')
TEMP_CELSIUS=$((TEMP_KELVIN - 273))

CRITICAL_WARNING=$(extract "critical_warning")
AVAILABLE_SPARE=$(extract "available_spare")
AVAILABLE_SPARE_THRESHOLD=$(extract "available_spare_threshold")
PERCENTAGE_USED=$(extract "percentage_used")
DATA_UNITS_READ=$(extract "data_units_read")
DATA_UNITS_WRITTEN=$(extract "data_units_written")
HOST_READ_COMMANDS=$(extract "host_read_commands")
HOST_WRITE_COMMANDS=$(extract "host_write_commands")
CONTROLLER_BUSY_TIME=$(extract "controller_busy_time")
POWER_CYCLES=$(extract "power_cycles")
POWER_ON_HOURS=$(extract "power_on_hours")
UNSAFE_SHUTDOWNS=$(extract "unsafe_shutdowns")
MEDIA_ERRORS=$(extract "media_errors")
NUM_ERR_LOG_ENTRIES=$(extract "num_err_log_entries")
WARNING_TEMP_TIME=$(extract "warning_temperature_time")
CRITICAL_COMP_TEMP_TIME=$(extract "critical_composite_temperature_time")

{
  echo "# HELP node_nvme_temperature_celsius NVMe SSD temperature in Celsius"
  echo "# TYPE node_nvme_temperature_celsius gauge"
  echo "node_nvme_temperature_celsius{device=\"${DEV_NAME}\"} ${TEMP_CELSIUS}"

  echo "# HELP node_nvme_critical_warning NVMe critical warning flags (0 = none)"
  echo "# TYPE node_nvme_critical_warning gauge"
  echo "node_nvme_critical_warning{device=\"${DEV_NAME}\"} ${CRITICAL_WARNING}"

  echo "# HELP node_nvme_available_spare_percent NVMe available spare as percentage"
  echo "# TYPE node_nvme_available_spare_percent gauge"
  echo "node_nvme_available_spare_percent{device=\"${DEV_NAME}\"} ${AVAILABLE_SPARE}"

  echo "# HELP node_nvme_available_spare_threshold_percent NVMe available spare threshold"
  echo "# TYPE node_nvme_available_spare_threshold_percent gauge"
  echo "node_nvme_available_spare_threshold_percent{device=\"${DEV_NAME}\"} ${AVAILABLE_SPARE_THRESHOLD}"

  echo "# HELP node_nvme_percentage_used NVMe endurance used percentage (0-100, 100 = worn out)"
  echo "# TYPE node_nvme_percentage_used gauge"
  echo "node_nvme_percentage_used{device=\"${DEV_NAME}\"} ${PERCENTAGE_USED}"

  echo "# HELP node_nvme_data_units_read_total NVMe data units read (1 unit = 512 bytes)"
  echo "# TYPE node_nvme_data_units_read_total counter"
  echo "node_nvme_data_units_read_total{device=\"${DEV_NAME}\"} ${DATA_UNITS_READ}"

  echo "# HELP node_nvme_data_units_written_total NVMe data units written (1 unit = 512 bytes)"
  echo "# TYPE node_nvme_data_units_written_total counter"
  echo "node_nvme_data_units_written_total{device=\"${DEV_NAME}\"} ${DATA_UNITS_WRITTEN}"

  echo "# HELP node_nvme_host_read_commands_total NVMe host read commands"
  echo "# TYPE node_nvme_host_read_commands_total counter"
  echo "node_nvme_host_read_commands_total{device=\"${DEV_NAME}\"} ${HOST_READ_COMMANDS}"

  echo "# HELP node_nvme_host_write_commands_total NVMe host write commands"
  echo "# TYPE node_nvme_host_write_commands_total counter"
  echo "node_nvme_host_write_commands_total{device=\"${DEV_NAME}\"} ${HOST_WRITE_COMMANDS}"

  echo "# HELP node_nvme_controller_busy_time_minutes NVMe controller busy time in minutes"
  echo "# TYPE node_nvme_controller_busy_time_minutes counter"
  echo "node_nvme_controller_busy_time_minutes{device=\"${DEV_NAME}\"} ${CONTROLLER_BUSY_TIME}"

  echo "# HELP node_nvme_power_cycles_total NVMe power cycle count"
  echo "# TYPE node_nvme_power_cycles_total counter"
  echo "node_nvme_power_cycles_total{device=\"${DEV_NAME}\"} ${POWER_CYCLES}"

  echo "# HELP node_nvme_power_on_hours_total NVMe power-on hours"
  echo "# TYPE node_nvme_power_on_hours_total counter"
  echo "node_nvme_power_on_hours_total{device=\"${DEV_NAME}\"} ${POWER_ON_HOURS}"

  echo "# HELP node_nvme_unsafe_shutdowns_total NVMe unsafe shutdown count"
  echo "# TYPE node_nvme_unsafe_shutdowns_total counter"
  echo "node_nvme_unsafe_shutdowns_total{device=\"${DEV_NAME}\"} ${UNSAFE_SHUTDOWNS}"

  echo "# HELP node_nvme_media_errors_total NVMe media and data integrity errors"
  echo "# TYPE node_nvme_media_errors_total counter"
  echo "node_nvme_media_errors_total{device=\"${DEV_NAME}\"} ${MEDIA_ERRORS}"

  echo "# HELP node_nvme_error_log_entries_total NVMe error log entry count"
  echo "# TYPE node_nvme_error_log_entries_total counter"
  echo "node_nvme_error_log_entries_total{device=\"${DEV_NAME}\"} ${NUM_ERR_LOG_ENTRIES}"

  echo "# HELP node_nvme_warning_temperature_time_minutes NVMe time spent above warning temperature"
  echo "# TYPE node_nvme_warning_temperature_time_minutes counter"
  echo "node_nvme_warning_temperature_time_minutes{device=\"${DEV_NAME}\"} ${WARNING_TEMP_TIME}"

  echo "# HELP node_nvme_critical_temperature_time_minutes NVMe time spent above critical temperature"
  echo "# TYPE node_nvme_critical_temperature_time_minutes counter"
  echo "node_nvme_critical_temperature_time_minutes{device=\"${DEV_NAME}\"} ${CRITICAL_COMP_TEMP_TIME}"
} > "$TMP"

mv "$TMP" "$OUT"
