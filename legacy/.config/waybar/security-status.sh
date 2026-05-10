#!/usr/bin/env bash
# Waybar Security Status Monitor
# Shows real-time security status with color-coded alerts

# Security indicators
FAILURES=0
WARNINGS=0
SECURITY_STATUS="✅"
SECURITY_COLOR="#a6e3a1"

# Check if audit daemon is running
if ! systemctl is-active --quiet auditd; then
  ((WARNINGS++))
  AUDIT_STATUS="⚠️"
fi

# Check if fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
  ((WARNINGS++))
  FAIL2BAN_STATUS="⚠️"
fi

# Check if firewall is active (using ufw if available)
if command -v ufw &>/dev/null; then
  if ! ufw status | grep -q "Status: active"; then
    ((FAILURES++))
    FIREWALL_STATUS="🔴"
  fi
fi

# Check for failed login attempts (last hour)
FAILED_LOGINS=$(journalctl -u sshd --since "1 hour ago" | grep -c "Failed password")
if [ "$FAILED_LOGINS" -gt 5 ]; then
  ((FAILURES++))
  LOGIN_STATUS="🚨"
elif [ "$FAILED_LOGINS" -gt 0 ]; then
  ((WARNINGS++))
  LOGIN_STATUS="⚠️"
fi

# Check system load (potential DoS)
LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | tr -d ',')
if (($(echo "$LOAD_AVG > 5.0" | bc -l))); then
  ((WARNINGS++))
  LOAD_STATUS="⚠️"
fi

# Check disk space (potential log filling)
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 90 ]; then
  ((FAILURES++))
  DISK_STATUS="🔴"
elif [ "$DISK_USAGE" -gt 80 ]; then
  ((WARNINGS++))
  DISK_STATUS="⚠️"
fi

# Check for suspicious processes (optional)
SUSPICIOUS_PROCS=$(ps aux | grep -E "(nc -l|ncat -l|socat|python.*socket)" | grep -v grep | wc -l)
if [ "$SUSPICIOUS_PROCS" -gt 0 ]; then
  ((WARNINGS++))
fi

# Determine overall security status
if [ "$FAILURES" -gt 0 ]; then
  SECURITY_STATUS="🚨"
  SECURITY_COLOR="#f38ba8"
elif [ "$WARNINGS" -gt 0 ]; then
  SECURITY_STATUS="⚠️"
  SECURITY_COLOR="#f9e2af"
fi

# Output for Waybar
echo "{\"text\": \"$SECURITY_STATUS\", \"class\": \"security-$([ $FAILURES -gt 0 ] && echo \"critical\" || [ $WARNINGS -gt 0 ] && echo \"warning\" || echo \"ok\")\", \"tooltip\": \"Failures: $FAILURES | Warnings: $WARNINGS\"}"

# Log security check (optional)
# logger -t waybar-security "Security check: $FAILURES failures, $WARNINGS warnings"
