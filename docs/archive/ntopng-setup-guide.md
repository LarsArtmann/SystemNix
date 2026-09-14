# ntopng Setup and Configuration Guide

## Overview

ntopng is a high-performance network traffic monitoring tool that provides detailed network analysis, real-time traffic monitoring, and comprehensive network visibility. This guide covers installation, configuration, and best practices for the Nix-based macOS development environment.

## Installation

### Adding ntopng to Nix Configuration

Add ntopng to `dotfiles/nix/environment.nix`:

```nix
systemPackages = with pkgs; [
  # ... existing packages
  ntopng # High-performance network traffic monitoring
  # ... other packages
];
```

Apply the configuration:

```bash
just switch
# or
cd dotfiles/nix && darwin-rebuild switch --flake .
```

### Verify Installation

```bash
which ntopng
ntopng --version
```

## Quick Start

### 1. Basic Launch

```bash
# Start ntopng with default settings (requires sudo for packet capture)
sudo ntopng -i en0

# Start with web interface on custom port
sudo ntopng -i en0 -P /opt/ntopng/var/lib/ntopng/ntopng.pid -d /opt/ntopng/var/lib/ntopng -w 3001
```

### 2. Access Web Interface

- Default URL: `http://localhost:3000`
- Default credentials: `admin/admin`
- Change password immediately after first login

### 3. Find Network Interfaces

```bash
# List available network interfaces
ntopng -i help

# Common macOS interfaces
# en0: Primary Ethernet/WiFi
# en1: Secondary network interface
# lo0: Loopback interface
```

## Configuration

### Configuration File Setup

Create ntopng configuration directory:

```bash
sudo mkdir -p /usr/local/etc/ntopng
sudo mkdir -p /usr/local/var/lib/ntopng
sudo mkdir -p /usr/local/var/log/ntopng
```

### Main Configuration File

Create `/usr/local/etc/ntopng/ntopng.conf`:

```ini
# Network Interface Configuration
-i=en0                          # Primary network interface
# -i=en1                        # Additional interfaces (uncomment if needed)

# Web Interface Configuration
-w=3000                         # Web interface port
-P=/usr/local/var/lib/ntopng/ntopng.pid  # PID file location

# Data Storage
-d=/usr/local/var/lib/ntopng    # Data directory
-s                              # Enable historical data storage

# Authentication & Security
-l                              # Enable local networks auto-discovery
--disable-login                 # Disable login (localhost only - DEVELOPMENT ONLY)
# --https-port=3001             # Enable HTTPS (production)

# Performance Configuration
-F=hash:ntopng                  # Flow export
--max-num-flows=100000         # Maximum flows in memory
--max-num-hosts=25000          # Maximum hosts in memory

# Logging
--log-file=/usr/local/var/log/ntopng/ntopng.log
--verbose=2                     # Logging level (0-6)

# Historical Data
--dump-timeline                 # Enable timeline dump
--dump-hosts=all               # Dump all hosts
--mysql-host=localhost         # MySQL for historical data (optional)

# GeoIP (optional)
# --geoip-dir=/usr/local/share/GeoIP

# SNMP (optional)
# --snmp-port=161
```

### macOS-Specific Configuration

#### Interface Detection

```bash
# Detect active network interfaces
networksetup -listallhardwareports

# Monitor WiFi interface specifically
sudo ntopng -i en0 --http-port 3000

# Monitor multiple interfaces
sudo ntopng -i en0,en1 --http-port 3000
```

#### Packet Capture Permissions

```bash
# Add user to specific groups (if needed)
sudo dseditgroup -o edit -a $(whoami) -t user access_bpf

# Set up packet capture capabilities
sudo chmod 644 /dev/bpf*
```

## Advanced Configuration

### Database Integration

#### SQLite Configuration (Recommended for Development)

```ini
# In ntopng.conf
--data-dir=/usr/local/var/lib/ntopng
--dump-timeline
--dump-hosts=all
```

#### MySQL Configuration (Production)

```ini
# MySQL configuration
--mysql-host=localhost
--mysql-port=3306
--mysql-dbname=ntopng
--mysql-table-prefix=nt_
--mysql-user=ntopng
--mysql-password=ntopng_password
```

Set up MySQL database:

```sql
CREATE DATABASE ntopng;
CREATE USER 'ntopng'@'localhost' IDENTIFIED BY 'ntopng_password';
GRANT ALL PRIVILEGES ON ntopng.* TO 'ntopng'@'localhost';
FLUSH PRIVILEGES;
```

### Performance Optimization

#### Memory Optimization

```ini
# Optimize for development machine
--max-num-flows=50000
--max-num-hosts=10000
--host-max-idle=300            # Host idle timeout (seconds)
--flow-max-idle=30             # Flow idle timeout (seconds)
```

#### CPU Optimization

```ini
# Reduce CPU usage
--cpu-affinity=0              # Bind to specific CPU core
--packet-filter=""            # Custom packet filter
--zmq=tcp://127.0.0.1:5556    # ZMQ endpoint for external data
```

### Security Configuration

#### Authentication Setup

```ini
# Enable authentication (production)
--user=admin:admin            # Default user (change immediately)
--http-port=3000
--https-port=3001
--ssl-cert=/path/to/cert.pem
--ssl-key=/path/to/key.pem
```

#### Access Control

```ini
# Restrict access
--allowed-nets=127.0.0.1/32,192.168.1.0/24
--denied-nets=0.0.0.0/0
```

#### Privacy Settings

```ini
# Privacy configuration
--dont-change-user           # Don't drop privileges
--capture-direction=0        # Capture both directions
--ignore-vlan               # Ignore VLAN tags
```

## Integration with Development Workflow

### Just Task Integration

Add to `justfile`:

```bash
# Network monitoring tasks
ntopng-start:
    @echo "Starting ntopng network monitoring..."
    sudo ntopng --config-file=/usr/local/etc/ntopng/ntopng.conf --daemon
    @echo "Dashboard available at http://localhost:3000"

ntopng-stop:
    sudo killall ntopng

ntopng-restart:
    just ntopng-stop
    sleep 2
    just ntopng-start

ntopng-status:
    @pgrep ntopng > /dev/null && echo "ntopng is running" || echo "ntopng is not running"
    @ps aux | grep ntopng | grep -v grep

# Development monitoring
monitor-network:
    @echo "Starting network monitoring for development..."
    sudo ntopng -i en0 --http-port 3000 --verbose=1

# Monitor specific application traffic
monitor-app APP_PORT:
    @echo "Monitoring traffic for application on port {{APP_PORT}}"
    sudo ntopng -i en0 --http-port 3000 --packet-filter="port {{APP_PORT}}"
```

### Automated Startup (LaunchDaemon)

Create `/Library/LaunchDaemons/com.ntopng.daemon.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ntopng.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/nix/store/*/bin/ntopng</string>
        <string>--config-file</string>
        <string>/usr/local/etc/ntopng/ntopng.conf</string>
        <string>--daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/usr/local/var/log/ntopng/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/usr/local/var/log/ntopng/stderr.log</string>
</dict>
</plist>
```

Load the daemon:

```bash
sudo launchctl load /Library/LaunchDaemons/com.ntopng.daemon.plist
```

## Key Features and Metrics

### Network Traffic Analysis

- **Real-time Traffic**: Live network traffic monitoring
- **Protocol Analysis**: HTTP, HTTPS, DNS, FTP, SSH, etc.
- **Geographic Distribution**: Traffic by country/region
- **Top Talkers**: Most active hosts and applications

### Application Monitoring

- **Application Protocols**: Detailed application-level analysis
- **Flow Analysis**: Network flows and connections
- **Bandwidth Usage**: Per-application bandwidth consumption
- **Performance Metrics**: Latency, packet loss, throughput

### Security Monitoring

- **Threat Detection**: Malware detection and analysis
- **Anomaly Detection**: Unusual traffic patterns
- **DPI (Deep Packet Inspection)**: Content analysis
- **Blacklist Monitoring**: Known malicious hosts/domains

### Historical Analysis

- **Traffic Trends**: Historical traffic patterns
- **Capacity Planning**: Bandwidth utilization trends
- **Performance Analysis**: Network performance over time
- **Reporting**: Automated reports and alerts

## Development-Specific Use Cases

### API Development Monitoring

```bash
# Monitor API traffic on specific port
sudo ntopng -i en0 --http-port 3000 --packet-filter="port 8080"

# Monitor database connections
sudo ntopng -i lo0 --http-port 3000 --packet-filter="port 5432 or port 3306"
```

### Microservices Monitoring

```bash
# Monitor service mesh traffic
sudo ntopng -i en0 --http-port 3000 --packet-filter="portrange 8000-9000"

# Monitor container network traffic
sudo ntopng -i docker0 --http-port 3000
```

### Security Testing

```bash
# Monitor during penetration testing
sudo ntopng -i en0 --http-port 3000 --verbose=3

# Monitor API security scanning
sudo ntopng -i en0 --http-port 3000 --packet-filter="src host target_ip"
```

## Performance Tuning

### System Resource Optimization

```ini
# Low resource configuration
--max-num-flows=10000
--max-num-hosts=5000
--host-max-idle=60
--flow-max-idle=10
--dont-change-user
```

### High Performance Configuration

```ini
# High performance configuration
--max-num-flows=1000000
--max-num-hosts=100000
--cpu-affinity=0,1,2,3
--capture-direction=1
--zmq=tcp://127.0.0.1:5556
```

### Memory Management

```bash
# Monitor ntopng memory usage
ps aux | grep ntopng
top -p $(pgrep ntopng)

# Restart if memory usage is high
sudo killall ntopng && sleep 2 && sudo ntopng --config-file=/usr/local/etc/ntopng/ntopng.conf --daemon
```

## Troubleshooting

### Common Issues

#### Permission Denied

```bash
# Fix packet capture permissions
sudo chmod 644 /dev/bpf*

# Run with proper privileges
sudo ntopng -i en0

# Check interface permissions
ls -la /dev/bpf*
```

#### Interface Not Found

```bash
# List available interfaces
ifconfig -l
networksetup -listallhardwareports

# Use correct interface name
sudo ntopng -i $(route get default | grep interface | awk '{print $2}')
```

#### High CPU Usage

```ini
# Reduce monitoring frequency
--max-num-flows=25000
--host-max-idle=120
--flow-max-idle=15

# Use packet filtering
--packet-filter="not port 22"  # Exclude SSH traffic
```

#### Web Interface Issues

```bash
# Check if port is in use
lsof -i :3000

# Use alternative port
sudo ntopng -i en0 --http-port 3001

# Clear browser cache and cookies
```

### Debug Commands

```bash
# Verbose startup
sudo ntopng -i en0 --verbose=6

# Test configuration
sudo ntopng --test-config --config-file=/usr/local/etc/ntopng/ntopng.conf

# Check running processes
ps aux | grep ntopng
lsof -p $(pgrep ntopng)

# Monitor logs
tail -f /usr/local/var/log/ntopng/ntopng.log
```

### Performance Diagnostics

```bash
# Check network interface statistics
netstat -i

# Monitor system resources during ntopng operation
top -pid $(pgrep ntopng)

# Check disk I/O
iostat -w 1

# Monitor network connections
netstat -an | grep :3000
```

## API and Integration

### REST API Usage

```bash
# Get interface statistics
curl "http://localhost:3000/lua/rest/v2/get/interface/data.lua?ifid=0"

# Get top hosts
curl "http://localhost:3000/lua/rest/v2/get/host/active.lua?ifid=0"

# Get flow data
curl "http://localhost:3000/lua/rest/v2/get/flow/active.lua?ifid=0"

# Get alerts
curl "http://localhost:3000/lua/rest/v2/get/alert/data.lua"
```

### Data Export

```bash
# Export flow data
curl "http://localhost:3000/lua/rest/v2/export/flow/data.lua?ifid=0" > flows.json

# Export host data
curl "http://localhost:3000/lua/rest/v2/export/host/data.lua?ifid=0" > hosts.json
```

### Webhook Integration

Configure webhooks in ntopng web interface:

- **URL**: `http://localhost:8080/webhooks/ntopng`
- **Events**: Alerts, Flow events, Host events
- **Format**: JSON

## Best Practices

### Development Environment

1. **Start/Stop with Development**: Include in development startup scripts
2. **Monitor Resource Usage**: Keep an eye on CPU/memory consumption
3. **Use Packet Filters**: Focus on relevant traffic only
4. **Regular Cleanup**: Clear old data periodically

### Security

1. **Change Default Credentials**: Always change admin/admin
2. **Use HTTPS**: Enable SSL for production monitoring
3. **Restrict Access**: Limit access to development team only
4. **Monitor Logs**: Regularly check ntopng logs

### Performance

1. **Tune for Your Needs**: Adjust flow/host limits based on network size
2. **Use Database Storage**: Enable historical data for trend analysis
3. **Regular Maintenance**: Restart ntopng periodically to clear memory
4. **Monitor System Impact**: Ensure ntopng doesn't impact development performance

This comprehensive guide provides everything needed to set up and configure ntopng for network monitoring in your Nix-based macOS development environment.
