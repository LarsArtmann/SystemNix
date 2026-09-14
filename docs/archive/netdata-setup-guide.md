# Netdata Setup and Configuration Guide

## Overview

Netdata is a real-time performance monitoring tool that provides comprehensive system metrics with minimal configuration. This guide covers setup, configuration, and best practices for the Nix-based macOS development environment.

## Current Installation Status

Netdata is installed via Nix in `environment.nix`:

```nix
netdata # Real-time performance monitoring tool
```

## Quick Start

### 1. Launch Netdata

```bash
# Start netdata daemon
sudo netdata

# Start with specific configuration
sudo netdata -c /opt/netdata/etc/netdata/netdata.conf
```

### 2. Access Web Interface

- Default URL: `http://localhost:19999`
- Real-time dashboard with automatic refresh
- No authentication required by default (localhost only)

### 3. Basic Commands

```bash
# Check if netdata is running
pgrep netdata

# View logs
tail -f /var/log/netdata/error.log

# Stop netdata
sudo killall netdata

# Restart netdata
sudo netdata -D
```

## Configuration

### Configuration File Locations

- Main config: `/opt/netdata/etc/netdata/netdata.conf`
- Custom config: `/usr/local/etc/netdata/netdata.conf`
- Log files: `/var/log/netdata/`
- Data storage: `/var/cache/netdata/`

### Generate Configuration File

```bash
# Generate configuration with current settings
sudo netdata -W set 2>/dev/null

# Generate configuration file template
sudo /opt/netdata/usr/sbin/netdata -c /opt/netdata/etc/netdata/netdata.conf -W set 2>/dev/null > netdata.conf
```

### Key Configuration Options

#### Performance Optimization

```ini
[global]
    # Reduce memory usage for development machines
    memory mode = ram
    history = 3600              # 1 hour of history (3600 seconds)
    update every = 2            # Update every 2 seconds

    # Optimize for macOS
    hostname = development-mac

    # Enable/disable sections
    run as user = netdata
```

#### Security Settings

```ini
[web]
    # Bind to localhost only for security
    bind to = localhost
    default port = 19999

    # Enable SSL (optional)
    ssl key = /etc/ssl/private/netdata.key
    ssl certificate = /etc/ssl/certs/netdata.crt
```

#### Data Retention

```ini
[global]
    # Adjust based on available disk space
    page cache size = 32        # MB
    dbengine disk space = 256   # MB
```

### macOS-Specific Configuration

#### System Monitoring

```ini
[plugin:macos]
    # Enable macOS-specific metrics
    command options =

[plugin:proc]
    # macOS doesn't use /proc filesystem
    /proc/net/dev = no
    /proc/diskstats = no
```

#### Network Monitoring

```ini
[plugin:tc]
    # Traffic control monitoring
    script to execute = /opt/netdata/usr/libexec/netdata/plugins.d/tc.plugin
```

## Advanced Setup

### Custom Dashboard Configuration

Create `/opt/netdata/etc/netdata/health.d/custom.conf`:

```ini
# Custom health monitoring
template: cpu_usage_high
      on: system.cpu
   class: Utilization
    type: System
component: CPU
    calc: $user + $system + $nice + $iowait
   units: %
   every: 10s
    warn: $this > 80
    crit: $this > 95
    info: CPU utilization is high
```

### Plugin Configuration

#### Enable Python Plugins

```bash
# Install required Python modules
pip3 install psutil python-socketio

# Configure in netdata.conf
[plugins]
    python.d = yes
    go.d = yes
    charts.d = yes
```

#### Go Plugins (Recommended)

```ini
[plugin:go.d]
    # More efficient than Python plugins
    enabled = yes
    modules path = /opt/netdata/usr/lib/netdata/plugins.d
```

## Integration with Development Workflow

### Just Task Integration

Add to `justfile`:

```bash
# Monitor system performance
monitor:
    @echo "Starting Netdata monitoring..."
    sudo netdata -D
    @echo "Dashboard available at http://localhost:19999"

# Stop monitoring
monitor-stop:
    sudo killall netdata

# Monitor with custom config
monitor-dev:
    sudo netdata -c ./configs/netdata-dev.conf -D
```

### Automated Startup (LaunchAgent)

Create `~/Library/LaunchAgents/com.netdata.agent.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.netdata.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/netdata/usr/sbin/netdata</string>
        <string>-D</string>
        <string>-c</string>
        <string>/opt/netdata/etc/netdata/netdata.conf</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/netdata/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/netdata/stderr.log</string>
</dict>
</plist>
```

Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.netdata.agent.plist
```

## Key Metrics for Development

### System Performance Metrics

- **CPU Usage**: Per-core utilization, load average
- **Memory**: Used, cached, swap usage
- **Disk I/O**: Read/write operations, latency
- **Network**: Interface statistics, traffic patterns

### Development-Specific Metrics

- **Build Performance**: Monitor during compilation
- **Process Monitoring**: Track resource usage of development tools
- **Docker Metrics**: Container resource consumption
- **Database Performance**: Connection pools, query performance

### Custom Metrics Collection

```bash
# Create custom chart for development metrics
echo "BEGIN development.build_time"
echo "SET compile_time = $(time make 2>&1 | tail -1)"
echo "END"
```

## Performance Optimization

### Resource Usage Optimization

```ini
[global]
    # Reduce CPU usage
    update every = 5

    # Limit memory usage
    memory mode = dbengine
    page cache size = 32

    # Disable unnecessary plugins
    plugins directory = /opt/netdata/usr/libexec/netdata/plugins.d
```

### Metric Selection

```ini
[plugin:proc]
    # Disable metrics not needed for development
    /proc/net/netstat = no
    /proc/net/snmp = no
    /proc/net/snmp6 = no
```

## Security Considerations

### Network Security

- Default configuration binds to localhost only
- No authentication required for local access
- Consider firewall rules for remote access

### Data Privacy

- Metrics stored locally by default
- No data transmitted to external services
- Configure data retention policies

### Access Control

```ini
[web]
    # Restrict access to specific IPs
    allow connections from = localhost 10.0.0.0/8 192.168.0.0/16

    # Enable basic authentication (optional)
    allow management from = localhost
```

## Troubleshooting

### Common Issues

#### Netdata Won't Start

```bash
# Check for existing process
pgrep netdata
sudo killall netdata

# Check configuration syntax
sudo netdata -t

# Start with verbose logging
sudo netdata -D -d 2>&1 | tee netdata.log
```

#### Permission Issues

```bash
# Fix ownership
sudo chown -R netdata:netdata /var/cache/netdata
sudo chown -R netdata:netdata /var/log/netdata

# Fix permissions
sudo chmod 755 /opt/netdata/usr/sbin/netdata
```

#### High Resource Usage

```ini
[global]
    # Reduce update frequency
    update every = 10

    # Limit history
    history = 1800

    # Disable heavy plugins
    plugins directory = /opt/netdata/usr/libexec/netdata/plugins.d
```

#### Missing Metrics

```bash
# Check plugin status
curl http://localhost:19999/api/v1/info

# Test specific plugin
sudo /opt/netdata/usr/libexec/netdata/plugins.d/go.d.plugin debug
```

### Debug Commands

```bash
# Configuration verification
sudo netdata -t

# Plugin debugging
sudo netdata -D -d

# API testing
curl http://localhost:19999/api/v1/charts
curl http://localhost:19999/api/v1/data?chart=system.cpu

# Log analysis
tail -f /var/log/netdata/error.log
tail -f /var/log/netdata/access.log
```

## Performance Monitoring Best Practices

### Development Workflow Integration

1. **Baseline Monitoring**: Establish performance baselines before changes
2. **Build Monitoring**: Track compilation times and resource usage
3. **Testing Impact**: Monitor system during test runs
4. **Continuous Monitoring**: Keep netdata running during development

### Alert Configuration

```ini
# Custom alerts for development environment
template: high_build_cpu
      on: system.cpu
   lookup: average -3m unaligned of user,system,nice,iowait
   units: %
   every: 30s
   warn: $this > 75
   crit: $this > 90
   info: High CPU usage during development tasks
```

### Data Export

```bash
# Export metrics for analysis
curl -s "http://localhost:19999/api/v1/data?chart=system.cpu&format=json" > cpu_metrics.json

# Historical data export
curl -s "http://localhost:19999/api/v1/data?chart=system.cpu&after=-3600&format=csv" > cpu_last_hour.csv
```

## Integration with Other Tools

### Grafana Integration

```bash
# Add Netdata as Grafana data source
# URL: http://localhost:19999
# Type: JSON
```

### Prometheus Integration

```ini
[backend]
    enabled = yes
    type = prometheus
    destination = localhost:9090
    update every = 10
```

### API Usage Examples

```bash
# Get all available charts
curl http://localhost:19999/api/v1/charts

# Get specific metric data
curl "http://localhost:19999/api/v1/data?chart=system.cpu&after=-600"

# Get alarms
curl http://localhost:19999/api/v1/alarms
```

This guide provides comprehensive coverage of Netdata setup and configuration for your Nix-based macOS development environment. The configuration emphasizes performance, security, and integration with your existing development workflow.
