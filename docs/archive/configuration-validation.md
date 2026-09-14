# Configuration Validation Framework

A comprehensive validation system for Nix-based macOS dotfiles that implements the philosophy: **"ABSOLUTE CARE! Better slow than sorry!"**

## Overview

This framework provides bulletproof validation to prevent configuration errors before deployment, ensuring system reliability and preventing broken configurations from being applied.

## Features

### ✅ Multi-Level Validation

1. **Syntax Validation** - Catches parsing errors before deployment
2. **Semantic Validation** - Detects configuration conflicts and inconsistencies
3. **Security Validation** - Identifies potential security misconfigurations
4. **Performance Validation** - Monitors shell startup times and system performance
5. **Integration Validation** - Checks compatibility between different tools and systems

### 🛡️ Safety Features

- **Pre-deployment validation** prevents broken configurations
- **Dependency conflict detection** avoids package manager conflicts
- **Shell configuration testing** prevents terminal session breakage
- **Security scanning** identifies hardcoded secrets and insecure settings
- **Performance monitoring** with configurable thresholds

### 🚀 Developer Experience

- **Fast feedback** with quick mode for development workflow
- **Comprehensive validation** for production deployments
- **Detailed logging** with color-coded output and timestamps
- **Actionable error messages** with specific fix suggestions
- **Report generation** for detailed analysis and troubleshooting

## Installation and Setup

### Prerequisites

- Nix with flakes enabled
- macOS (Darwin)
- Git
- Optional: `just` command runner for enhanced workflow

### Setup

1. **Install pre-commit hooks:**

   ```bash
   just setup-hooks
   # or manually:
   pre-commit install
   ```

2. **Verify installation:**
   ```bash
   ./scripts/config-validate.sh --help
   ```

## Usage

### Quick Start

```bash
# Fast validation during development
just validate-quick

# Comprehensive validation for deployment
just validate-strict

# Safe deployment with full validation
just deploy-safe
```

### Command Line Interface

The main validation script provides several commands and options:

```bash
./scripts/config-validate.sh [OPTIONS] [COMMAND]
```

#### Commands

- `all` - Run all validations (default)
- `nix` - Run only Nix configuration validation
- `shell` - Run only shell configuration validation
- `deps` - Run only dependency conflict detection
- `report` - Generate detailed validation report

#### Options

- `-v, --verbose` - Enable verbose output with debug information
- `-s, --strict` - Treat warnings as errors (recommended for deployment)
- `-q, --quick` - Quick validation mode (skips time-consuming checks)
- `-r, --report FILE` - Generate validation report to specified file
- `-h, --help` - Show help message

### Just Task Runner Integration

The framework integrates with `just` for convenient task management:

#### Development Commands

```bash
just dev              # Start development workflow with quick validation
just validate         # Comprehensive validation
just validate-quick   # Fast validation for development
just validate-strict  # Strict validation (warnings as errors)
```

#### Specific Validations

```bash
just validate-nix     # Only Nix configuration validation
just validate-shell   # Only shell configuration validation
just validate-deps    # Only dependency conflict detection
```

#### System Management

```bash
just build            # Build Nix configuration
just switch           # Switch to new configuration (with validation)
just deploy-safe      # Safe deployment with backup and validation
```

#### Reporting and Debugging

```bash
just validate-report  # Generate detailed validation report
just debug           # Show system debug information
just logs            # Show recent validation logs
just benchmark       # Performance benchmarking
```

## Validation Components

### Nix Configuration Validation

#### Syntax Validation

- **Flake check:** `nix flake check` with timeout protection
- **Individual file parsing:** Validates each `.nix` file syntax
- **Lock file consistency:** Ensures `flake.lock` is valid and consistent

#### Security Scanning

- **Hardcoded secrets detection:** Scans for passwords, keys, tokens
- **Insecure settings:** Identifies `allowUnfree`, `allowBroken` usage
- **Path validation:** Checks for hardcoded sensitive paths

#### Home Manager Integration

- **Configuration validation:** Tests Home Manager build process
- **Syntax checking:** Validates `home.nix` structure

### Shell Configuration Validation

#### Fish Shell

- **Syntax validation:** `fish -n` for syntax checking
- **Startup performance:** Measures startup time with thresholds
- **Configuration testing:** Tests Fish-specific configurations

#### Zsh Configuration

- **Syntax validation:** `zsh -n` for syntax checking
- **Startup performance:** Monitors Zsh initialization time
- **Profile validation:** Checks `.zshrc`, `.zprofile`, `.zshenv`

#### Bash Configuration

- **Syntax validation:** `bash -n` for syntax checking
- **Profile validation:** Checks `.bashrc`, `.bash_profile`, `.profile`

### Dependency Conflict Detection

#### Package Manager Conflicts

- **Nix vs Homebrew:** Detects packages installed by both managers
- **PATH analysis:** Identifies duplicate entries and conflicts
- **Version conflicts:** Checks for incompatible package versions

#### Service Conflicts

- **macOS services:** Monitors launchd service conflicts
- **Port conflicts:** Identifies services competing for same ports
- **Process conflicts:** Detects conflicting background processes

## Performance Thresholds

### Configurable Thresholds

```bash
# Shell startup time threshold (milliseconds)
SHELL_STARTUP_THRESHOLD_MS=500

# Nix build timeout (seconds)
NIX_BUILD_TIMEOUT=300
```

### Performance Monitoring

The framework monitors:

- Shell startup times for Fish, Zsh, and Bash
- Nix evaluation and build times
- Validation execution duration
- System resource usage during validation

## Pre-commit Integration

### Automatic Validation

Pre-commit hooks automatically run validation on:

- **Nix files (\*.nix):** Quick Nix validation
- **Shell files:** Shell configuration validation
- **Package files:** Dependency conflict checking

### Hook Configuration

```yaml
repos:
  - repo: local
    hooks:
      - id: nix-config-validate
        name: Nix Configuration Validation
        entry: ./scripts/config-validate.sh --quick nix
        language: script
        files: \.nix$
```

### Additional Quality Checks

- File formatting (nixpkgs-fmt)
- Shell script linting (shellcheck)
- Markdown linting
- JSON/YAML validation
- Security scanning

## Error Handling and Recovery

### Error Categories

1. **Critical Errors:** Syntax errors, security issues, configuration conflicts
2. **Warnings:** Performance issues, deprecated settings, minor conflicts
3. **Info:** Status updates, successful validations, recommendations

### Recovery Strategies

#### Backup and Restore

```bash
just backup           # Create configuration backup
just restore BACKUP   # Restore from backup
```

#### Incremental Validation

```bash
# Validate specific components
just validate-nix     # Only Nix issues
just validate-shell   # Only shell issues
just validate-deps    # Only dependency issues
```

#### Debug Mode

```bash
./scripts/config-validate.sh --verbose nix
just debug
just logs
```

## Reporting

### Validation Reports

Generate comprehensive reports for analysis:

```bash
just validate-report              # Default report name
just validate-report custom.md    # Custom report name
```

### Report Contents

- **Executive summary:** Error/warning counts, overall status
- **System information:** OS, architecture, tool versions
- **Detailed results:** Per-component validation status
- **Performance metrics:** Timing and threshold analysis
- **Recommendations:** Actionable improvement suggestions
- **Log references:** Links to detailed log files

### Log Management

- **Timestamped logs:** Each validation run creates timestamped logs
- **Structured logging:** Color-coded output with severity levels
- **Log retention:** Automatic cleanup of old log files
- **Centralized logging:** All validation activities logged centrally

## Best Practices

### Development Workflow

1. **Regular validation:** Run `just validate-quick` frequently during development
2. **Pre-commit hooks:** Let automatic validation catch issues early
3. **Incremental changes:** Make small, testable configuration changes
4. **Documentation:** Document complex configuration decisions

### Deployment Workflow

1. **Comprehensive validation:** Always run `just validate-strict` before deployment
2. **Backup first:** Create configuration backups before major changes
3. **Safe deployment:** Use `just deploy-safe` for important deployments
4. **Post-deployment verification:** Verify system functionality after deployment

### Maintenance

1. **Regular updates:** Keep dependencies and inputs updated
2. **Performance monitoring:** Monitor shell startup times and system performance
3. **Security reviews:** Regular security scans for configuration changes
4. **Log review:** Periodically review validation logs for patterns

## Troubleshooting

### Common Issues

#### Nix Flake Check Failures

```bash
# Debug with verbose output
nix flake check --show-trace

# Check individual files
nix-instantiate --parse file.nix
```

#### Shell Startup Performance

```bash
# Benchmark all shells
just benchmark

# Profile specific shell startup
time fish -c "echo test"
```

#### Dependency Conflicts

```bash
# Check specific conflicts
just validate-deps --verbose

# Review PATH configuration
echo $PATH | tr ':' '\n'
```

### Debug Commands

```bash
just debug           # System information
just logs            # Recent validation logs
just benchmark       # Performance metrics
just info           # Configuration status
```

## Advanced Configuration

### Custom Thresholds

Edit the validation script to customize thresholds:

```bash
# In scripts/config-validate.sh
readonly SHELL_STARTUP_THRESHOLD_MS=500
readonly NIX_BUILD_TIMEOUT=300
```

### Custom Validation Rules

Add custom validation functions:

```bash
validate_custom_rule() {
    log "INFO" "Running custom validation..."
    # Custom validation logic
    log "SUCCESS" "Custom validation passed"
    return 0
}
```

### Integration with CI/CD

```yaml
# GitHub Actions example
- name: Validate Configuration
  run: |
    ./scripts/config-validate.sh --strict
    ./scripts/config-validate.sh --report validation-report.md report
```

## Security Considerations

### Sensitive Data Detection

The framework scans for:

- Hardcoded passwords and API keys
- SSH private key paths
- GPG key directories
- Environment variables with sensitive data

### Security Best Practices

1. **Never commit secrets:** Use environment variables or secret management
2. **Regular security scans:** Run security validation frequently
3. **Principle of least privilege:** Minimize access permissions
4. **Audit configuration changes:** Review all security-related changes

## Contributing

### Adding New Validations

1. **Create validation function:** Follow naming convention `validate_*`
2. **Add error handling:** Use proper logging and return codes
3. **Update documentation:** Document new validation capabilities
4. **Add tests:** Include test cases for new validations

### Testing

```bash
# Run validation test suite
./test-validation.sh

# Test specific components
./scripts/config-validate.sh --verbose nix
```

## Support

### Getting Help

- **Documentation:** Check this file and inline help
- **Debug information:** Run `just debug` for system information
- **Verbose output:** Use `--verbose` flag for detailed logging
- **Report generation:** Create detailed reports for analysis

### Common Commands Reference

```bash
# Quick reference
just help-validate    # Validation-specific help
just --list          # All available commands
./scripts/config-validate.sh --help  # Script help
```

---

_This documentation covers the comprehensive configuration validation framework designed to prevent configuration errors and ensure system reliability through careful, thorough validation processes._
