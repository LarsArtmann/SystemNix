# Monitoring Tools Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting information for Netdata and ntopng monitoring tools in the Nix-based macOS development environment.

## Common Issues and Solutions

### Netdata Troubleshooting

#### Issue: Netdata Won't Start

**Symptoms:**

- Command `netdata` fails to start
- No web interface accessible at `localhost:19999`
- Process not found with `pgrep netdata`

**Solutions:**

1. **Check for existing process:**

```bash
pgrep netdata
sudo killall netdata  # If process exists
```

2. **Verify installation:**

```bash
which netdata
netdata --version
```

3. **Check configuration:**

```bash
sudo netdata -t  # Test configuration
```

4. **Start with verbose logging:**

```bash
sudo netdata -D -d 2>&1 | tee netdata-debug.log
```

5. **Check permissions:**

```bash
sudo chown -R netdata:netdata /var/cache/netdata
sudo chown -R netdata:netdata /var/log/netdata
```

#### Issue: Netdata High Resource Usage

**Symptoms:**

- High CPU usage (>10%)
- High memory usage (>500MB)
- System slowdown during development

**Solutions:**

1. **Optimize configuration:**

```ini
# Edit /opt/netdata/etc/netdata/netdata.conf
[global]
    update every = 5        # Increase from default 1 second
    history = 1800         # Reduce from default 3600 seconds
    memory mode = ram      # Use RAM only for development
```

2. **Disable unnecessary plugins:**

```ini
[plugins]
    python.d = no
    charts.d = no
    node.d = no
```

3. **Limit data collection:**

```ini
[plugin:proc]
    /proc/net/netstat = no
    /proc/net/snmp = no
    /proc/net/snmp6 = no
```

#### Issue: Missing Metrics

**Symptoms:**

- Some system metrics not showing
- Empty charts in dashboard
- Plugin errors in logs

**Solutions:**

1. **Check plugin status:**

```bash
curl http://localhost:19999/api/v1/info
```

2. **Enable debug for specific plugin:**

```bash
sudo /opt/netdata/usr/libexec/netdata/plugins.d/go.d.plugin debug
```

3. **Check macOS-specific permissions:**

```bash
# For disk metrics
sudo diskutil list

# For network metrics
ifconfig -l
```

### ntopng Troubleshooting

#### Issue: ntopng Permission Denied

**Symptoms:**

- "Permission denied" error when starting ntopng
- Cannot capture packets
- Interface not accessible

**Solutions:**

1. **Run with sudo (required for packet capture):**

```bash
sudo ntopng -i en0
```

2. **Fix BPF permissions:**

```bash
sudo chmod 644 /dev/bpf*
ls -la /dev/bpf*
```

3. **Add user to access_bpf group (if needed):**

```bash
sudo dseditgroup -o edit -a $(whoami) -t user access_bpf
```

#### Issue: Interface Not Found

**Symptoms:**

- "Interface not found" error
- ntopng cannot start with specified interface
- Network monitoring not working

**Solutions:**

1. **List available interfaces:**

```bash
ifconfig -l
networksetup -listallhardwareports
```

2. **Use correct interface name:**

```bash
# Auto-detect active interface
INTERFACE=$(route get default | grep interface | awk '{print $2}')
sudo ntopng -i $INTERFACE
```

3. **Check interface status:**

```bash
ifconfig en0  # Replace en0 with your interface
```

#### Issue: ntopng High Resource Usage

**Symptoms:**

- High CPU usage (>20%)
- High memory usage (>1GB)
- System becomes unresponsive

**Solutions:**

1. **Optimize configuration in `/usr/local/etc/ntopng/ntopng.conf`:**

```ini
--max-num-flows=25000
--max-num-hosts=10000
--host-max-idle=300
--flow-max-idle=30
```

2. **Use packet filtering:**

```ini
# Monitor only specific traffic
--packet-filter="not port 22"  # Exclude SSH
--packet-filter="port 80 or port 443"  # Only HTTP/HTTPS
```

3. **Reduce update frequency:**

```ini
--housekeeping-frequency=3600  # Reduce from default
```

#### Issue: Web Interface Not Accessible

**Symptoms:**

- Cannot access `localhost:3000`
- Connection refused error
- ntopng running but no web interface

**Solutions:**

1. **Check if port is in use:**

```bash
lsof -i :3000
netstat -an | grep :3000
```

2. **Use alternative port:**

```bash
sudo ntopng -i en0 --http-port 3001
```

3. **Check ntopng process:**

```bash
ps aux | grep ntopng
```

4. **Verify firewall settings:**

```bash
# Check if firewall is blocking the port
sudo pfctl -s rules | grep 3000
```

### Network Interface Issues

#### Issue: No Network Interfaces Detected

**Symptoms:**

- Both tools show no network activity
- Interface statistics are empty
- Network monitoring not working

**Solutions:**

1. **Check network interfaces:**

```bash
# List all interfaces
ifconfig -a

# Check route table
netstat -rn

# Test network connectivity
ping -c 1 8.8.8.8
```

2. **Verify interface is active:**

```bash
# Check interface status
ifconfig en0

# Bring interface up if down
sudo ifconfig en0 up
```

3. **Check for virtual interfaces:**

```bash
# Docker interfaces
ifconfig docker0

# VPN interfaces
ifconfig utun0
```

### Performance Issues

#### Issue: Both Tools Causing System Slowdown

**Symptoms:**

- Development environment becomes slow
- High CPU/memory usage from monitoring
- IDE becomes unresponsive

**Solutions:**

1. **Prioritize monitoring needs:**

```bash
# Use only Netdata for general monitoring
just netdata-start

# Use ntopng only when network analysis is needed
just ntopng-start
just ntopng-stop  # Stop when done
```

2. **Optimize both tools:**

```bash
# Create optimized configuration files
# For Netdata: reduce update frequency
# For ntopng: limit flows and hosts
```

3. **Monitor resource usage of monitoring tools:**

```bash
# Check resource usage
top -pid $(pgrep netdata)
top -pid $(pgrep ntopng)
```

### Configuration Issues

#### Issue: Configuration Changes Not Applied

**Symptoms:**

- Changes to configuration files don't take effect
- Tools using old settings
- Expected behavior not working

**Solutions:**

1. **Restart services:**

```bash
# Restart Netdata
sudo killall netdata
sudo netdata

# Restart ntopng
sudo killall ntopng
sudo ntopng --config-file=/usr/local/etc/ntopng/ntopng.conf
```

2. **Verify configuration syntax:**

```bash
# Test Netdata configuration
sudo netdata -t

# Test ntopng configuration
sudo ntopng --test-config --config-file=/usr/local/etc/ntopng/ntopng.conf
```

3. **Check file permissions:**

```bash
# Configuration files should be readable
ls -la /opt/netdata/etc/netdata/netdata.conf
ls -la /usr/local/etc/ntopng/ntopng.conf
```

## Diagnostic Commands

### System Information

```bash
# System information
uname -a
sw_vers

# Network configuration
scutil --get ComputerName
scutil --get LocalHostName

# Process information
ps aux | grep -E "(netdata|ntopng)"
```

### Network Diagnostics

```bash
# Network interface statistics
netstat -i

# Route table
netstat -rn

# DNS configuration
scutil --dns

# Network services
networksetup -listallnetworkservices
```

### Performance Diagnostics

```bash
# System load
uptime

# Memory usage
vm_stat

# Disk usage
df -h

# Network connections
netstat -an | head -20
```

### Log Analysis

```bash
# Netdata logs
tail -f /var/log/netdata/error.log
tail -f /var/log/netdata/access.log

# ntopng logs
tail -f /usr/local/var/log/ntopng/ntopng.log

# System logs
log show --predicate 'eventMessage contains "netdata"' --last 1h
log show --predicate 'eventMessage contains "ntopng"' --last 1h
```

## Recovery Procedures

### Complete Reset

#### Netdata Reset

```bash
# Stop Netdata
sudo killall netdata

# Clear data
sudo rm -rf /var/cache/netdata/*
sudo rm -rf /var/log/netdata/*

# Restart with default configuration
sudo netdata
```

#### ntopng Reset

```bash
# Stop ntopng
sudo killall ntopng

# Clear data
sudo rm -rf /usr/local/var/lib/ntopng/*
sudo rm -rf /usr/local/var/log/ntopng/*

# Restart with minimal configuration
sudo ntopng -i en0 --http-port 3000
```

### Emergency Procedures

#### System Overload Recovery

```bash
# Stop all monitoring immediately
sudo killall netdata ntopng

# Check system resources
top -l 1 | head -20

# Restart with minimal configuration
sudo netdata -c /dev/null  # Minimal config
```

#### Network Interface Recovery

```bash
# Reset network interface
sudo ifconfig en0 down
sudo ifconfig en0 up

# Flush DNS cache
sudo dscacheutil -flushcache

# Restart network services
sudo launchctl unload /System/Library/LaunchDaemons/com.apple.networkd.plist
sudo launchctl load /System/Library/LaunchDaemons/com.apple.networkd.plist
```

## Prevention and Best Practices

### Monitoring Health

```bash
# Create monitoring health check script
#!/bin/bash
echo "=== Monitoring Health Check ==="

# Check Netdata
if pgrep netdata > /dev/null; then
    echo "✅ Netdata is running"
    curl -s http://localhost:19999/api/v1/info > /dev/null && echo "✅ Netdata API responsive" || echo "❌ Netdata API not responsive"
else
    echo "❌ Netdata is not running"
fi

# Check ntopng
if pgrep ntopng > /dev/null; then
    echo "✅ ntopng is running"
    curl -s http://localhost:3000 > /dev/null && echo "✅ ntopng web interface responsive" || echo "❌ ntopng web interface not responsive"
else
    echo "ℹ️ ntopng is not running (normal when not needed)"
fi

# Check system resources
echo "📊 System Resources:"
echo "Memory: $(vm_stat | grep "Pages free" | awk '{print $3}' | sed 's/\.//')KB free"
echo "Load: $(uptime | awk -F'load averages:' '{print $2}')"
```

### Regular Maintenance

```bash
# Add to Just tasks
monitor-health:
    @echo "Checking monitoring system health..."
    @./scripts/monitor-health-check.sh

monitor-cleanup:
    @echo "Cleaning up monitoring data..."
    sudo rm -f /var/log/netdata/*.log.old
    sudo rm -f /usr/local/var/log/ntopng/*.log.old

monitor-restart:
    @echo "Restarting monitoring services..."
    just monitor-stop
    sleep 2
    just monitor-all
```

This troubleshooting guide provides comprehensive solutions for common issues with both Netdata and ntopng monitoring tools in your macOS development environment.
