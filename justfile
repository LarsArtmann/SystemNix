# SystemNix Justfile
# Task runner for cross-platform Nix configuration management
#
# Groups: core, quality, clean, services, desktop, tasks, ai, tools, disk

# Must match networking.local.lanIP in platforms/nixos/system/local-network.nix
evo_x2_ip := "192.168.1.150"

default:
    @just --list

# ═══════════════════════════════════════════════════════════════════
#  Core
# ═══════════════════════════════════════════════════════════════════

# Initial setup after cloning the repository
[group('core')]
setup:
    #!/usr/bin/env bash
    mkdir -p ~/.ssh/sockets
    pre-commit install 2>/dev/null || true
    just switch
    echo ""
    echo "Setup complete. Open a new terminal for shell changes."

# Apply Nix configuration (darwin-rebuild or nh os switch)
# Auto-snapshots BTRFS on NixOS before switching for rollback safety
# Runs hash-check first to catch stale vendor/npm hashes before the full build
[group('core')]
switch:
    #!/usr/bin/env bash
    just hash-check
    if [[ "{{ os() }}" == "macos" ]]; then
        sudo /run/current-system/sw/bin/darwin-rebuild switch --flake ./ --print-build-logs
    else
        just snapshot
        nh os switch . -- --print-build-logs
    fi

# Update flake inputs (run 'just switch' after to apply)
[group('core')]
update:
    nix flake update

# Self-update Nix to latest version (run 'just switch' after)
[group('core')]
update-nix:
    nix upgrade-nix

# Show current versions of all LarsArtmann packages
[group('core')]
versions:
    ./scripts/versions.sh

# Emergency rollback to previous generation
[group('core')]
rollback:
    #!/usr/bin/env bash
    if [[ "{{ os() }}" == "macos" ]]; then
        sudo /run/current-system/sw/bin/darwin-rebuild switch --rollback
    else
        nh os switch . -- --rollback
    fi

# List available system generations
[group('core')]
list-generations:
    #!/usr/bin/env bash
    if [[ "{{ os() }}" == "macos" ]]; then
        /run/current-system/sw/bin/darwin-rebuild --list-generations
    else
        sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
    fi

# ═══════════════════════════════════════════════════════════════════
#  Quality
# ═══════════════════════════════════════════════════════════════════

# Full build validation (flake check + build test)
[group('quality')]
test:
    #!/usr/bin/env bash
    nix flake check --all-systems
    if [[ "{{ os() }}" == "macos" ]]; then
        sudo /run/current-system/sw/bin/darwin-rebuild check --flake ./
    else
        nh os test .
    fi

# Syntax-only validation (fast, no build)
[group('quality')]
test-fast:
    nix flake check --no-build

# Run Home Manager integration tests
[group('quality')]
test-hm:
    #!/usr/bin/env bash
    bash scripts/test-home-manager.sh

# Run shell alias tests across all shells
[group('quality')]
test-aliases:
    #!/usr/bin/env bash
    bash scripts/test-shell-aliases.sh

# Alias: validate = test-fast (used by pre-commit hook)
[group('quality')]
validate: test-fast

# Verify all ExecStart/ExecStartPre paths exist and are executable files
[group('quality')]
test-exec-paths:
    #!/usr/bin/env bash
    set -euo pipefail
    PATHS_JSON=$(nix eval --impure --raw --expr 'import ./tests/exec-start-paths.nix {flake = builtins.getFlake (toString ./.); lib = (builtins.getFlake "nixpkgs").lib;}')
    TOTAL=$(echo "$PATHS_JSON" | jq -r '.total')
    echo "Checking $TOTAL ExecStart paths..."
    ERRORS=0
    SKIPPED=0
    OK=0
    while IFS= read -r path; do
        if [ ! -e "$path" ]; then
            SKIPPED=$((SKIPPED + 1))
        elif [ ! -f "$path" ]; then
            echo "FAIL: '$path' is not a regular file (directory?)"
            ERRORS=$((ERRORS + 1))
        elif [ ! -x "$path" ]; then
            echo "FAIL: '$path' is not executable"
            ERRORS=$((ERRORS + 1))
        else
            OK=$((OK + 1))
        fi
    done < <(echo "$PATHS_JSON" | jq -r '.paths[]')
    if [ "$ERRORS" -gt 0 ]; then
        echo "FAILED: $ERRORS broken path(s), $OK ok, $SKIPPED not built"
        exit 1
    fi
    echo "OK: $OK verified, $SKIPPED not built (run after 'just test' for full check)"

# Fast hash-only check for overlay packages (catches stale vendorHash/npmDepsHash)
# Lighter than hash-check: only tests packages with known FOD hashes
[group('quality')]
test-hashes:
    #!/usr/bin/env bash
    just hash-check

# Format all code with treefmt
[group('quality')]
format:
    treefmt

# Lint all shell scripts with shellcheck
[group('quality')]
validate-scripts:
    find scripts/ -name '*.sh' -exec shellcheck {} +

# System status, git status, outdated packages
[group('quality')]
check:
    #!/usr/bin/env bash
    echo "=== System ==="
    nix --version
    if [[ "{{ os() }}" == "macos" ]]; then
        echo "macOS $(sw_vers -productVersion)"
        echo ""
        echo "=== Homebrew ==="
        brew outdated 2>/dev/null | head -10 || echo "All up to date"
    else
        nixos-version 2>/dev/null || true
    fi
    echo ""
    echo "=== Git ==="
    git status --short
    echo ""
    git log --oneline -5
    echo ""
    echo "=== Disk ==="
    df -h / | tail -1 | awk '{printf "Root: %s used, %s free of %s\n", $5, $4, $2}'

# Cross-platform health check (Nix, flake, direnv, shell, systemd, disk, memory)
[group('quality')]
health:
    ./scripts/health-check.sh

# Run all pre-commit hooks on all files
[group('quality')]
pre-commit-run:
    pre-commit run --all-files

# Install pre-commit hooks
[group('quality')]
pre-commit-install:
    pre-commit install

# Check overlay packages for vendor hash drift (Go vendorHash + npmDepsHash)
[group('quality')]
hash-check:
    #!/usr/bin/env bash
    set -euo pipefail
    pkgs=(
        library-policy hierarchical-errors golangci-lint-auto-configure
        mr-sync buildflow go-auto-upgrade go-structure-linter
        branching-flow art-dupl projects-management-automation
        govalid aw-watcher-utilization jscpd todo-list-ai
    )
    failed=0
    for pkg in "${pkgs[@]}"; do
        echo -n "Building $pkg... "
        if nix build ".#$pkg" --no-link 2>&1 | grep -q "got:"; then
            echo "HASH MISMATCH"
            nix build ".#$pkg" --no-link 2>&1 | grep "got:" || true
            failed=$((failed + 1))
        else
            echo "OK"
        fi
    done
    if [ "$failed" -gt 0 ]; then
        echo ""
        echo "FAIL: $failed package(s) have stale hashes"
        echo "Fix: set vendorHash to \"\" in the package's flake.nix, rebuild, grep for 'got:' hash"
        exit 1
    fi
    echo "All packages OK"

# Build all upstream overlay packages to verify they compile after flake updates
[group('quality')]
test-upstream-builds:
    #!/usr/bin/env bash
    set -euo pipefail
    pkgs=(
        library-policy hierarchical-errors golangci-lint-auto-configure
        mr-sync buildflow go-auto-upgrade go-structure-linter
        branching-flow art-dupl projects-management-automation
        dnsblockd file-and-image-renamer
        govalid aw-watcher-utilization netwatch
        jscpd todo-list-ai
    )
    failed=0
    for pkg in "${pkgs[@]}"; do
        echo -n "Testing $pkg... "
        if nix build ".#$pkg" --no-link 2>/dev/null; then
            echo "OK"
        else
            echo "FAIL"
            failed=$((failed + 1))
        fi
    done
    if [ "$failed" -gt 0 ]; then
        echo ""
        echo "FAIL: $failed package(s) failed to build"
        exit 1
    fi
    echo ""
    echo "All upstream builds OK"

# Auto-discover and update stale vendorHash for Go overlay packages
# Usage: just update-vendor-hashes [pkgname] (no arg = all)
[group('quality')]
update-vendor-hashes PKG="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{ PKG }}" ]; then
        pkgs=("{{ PKG }}")
    else
        pkgs=(
            library-policy hierarchical-errors golangci-lint-auto-configure
            mr-sync buildflow go-auto-upgrade go-structure-linter
            branching-flow art-dupl projects-management-automation
            dnsblockd file-and-image-renamer
        )
    fi
    updated=0
    for pkg in "${pkgs[@]}"; do
        echo -n "Checking $pkg... "
        output=$(nix build ".$pkg" --no-link 2>&1 || true)
        if echo "$output" | grep -q "got:"; then
            new_hash=$(echo "$output" | grep "got:" | awk '{print $2}' | head -1)
            echo "STALE -> $new_hash"
            # Find the flake.nix that defines this package
            # (upstream repos own their own vendorHash)
            echo "  Manual fix needed: set vendorHash = \"$new_hash\" in the upstream repo's flake.nix"
            updated=$((updated + 1))
        else
            echo "OK"
        fi
    done
    if [ "$updated" -gt 0 ]; then
        echo ""
        echo "Found $updated stale hash(s). Update upstream repo(s), then run 'nix flake update <input>'"
    fi

# ═══════════════════════════════════════════════════════════════════
#  Clean
# ═══════════════════════════════════════════════════════════════════

# Clean Nix store, caches, temp files, and Docker (safe comprehensive cleanup)
[group('clean')]
clean:
    #!/usr/bin/env bash
    echo "=== Nix Store ==="
    echo "Before: $(du -sh /nix/store 2>/dev/null | cut -f1)"
    nix-collect-garbage --delete-older-than 1d 2>/dev/null \
        || sudo nix-collect-garbage --delete-older-than 1d
    nix-store --optimize 2>/dev/null || sudo nix-store --optimize
    nix profile wipe-history --profile ~/.local/state/nix/profiles/profile 2>/dev/null || true
    echo "After:  $(du -sh /nix/store 2>/dev/null | cut -f1)"
    echo ""
    echo "=== Package Managers ==="
    if [[ "{{ os() }}" == "macos" ]]; then
        brew autoremove 2>/dev/null && brew cleanup --prune=all -s 2>/dev/null || true
    fi
    go clean -cache -testcache 2>/dev/null || true
    pnpm store prune 2>/dev/null || true
    cargo cache --autoclean 2>/dev/null || true
    echo ""
    echo "=== Temp Files ==="
    find /tmp -maxdepth 1 \( -name 'nix-build-*' -o -name 'nix-shell-*' \) \
        -print0 2>/dev/null | xargs -0 trash 2>/dev/null || true
    echo ""
    echo "=== Docker ==="
    docker system prune -f 2>/dev/null || true
    echo ""
    df -h / | tail -1 | awk '{printf "Disk: %s free (%s used)\n", $4, $5}'

# ═══════════════════════════════════════════════════════════════════
#  Services (NixOS)
# ═══════════════════════════════════════════════════════════════════

# DNS blocker status (unbound + dnsblockd)
[group('services')]
[linux]
dns-status:
    #!/usr/bin/env bash
    echo "Unbound:   $(systemctl is-active unbound 2>/dev/null || echo 'not found')"
    echo "dnsblockd: $(systemctl is-active dnsblockd 2>/dev/null || echo 'not found')"

# DNS resolution and blocking test
[group('services')]
[linux]
dns-test:
    #!/usr/bin/env bash
    echo "google.com:      $(dig google.com +short 2>/dev/null | head -1 || echo 'FAIL')"
    BLOCKED=$(dig doubleclick.net +short 2>/dev/null)
    if [[ -z "$BLOCKED" || "$BLOCKED" == 192.168.1.* ]]; then
        echo "doubleclick.net: BLOCKED"
    else
        echo "doubleclick.net: NOT BLOCKED ($BLOCKED)"
    fi

# DNS service logs (unbound + dnsblockd, last N lines)
[group('services')]
[linux]
dns-logs N="100":
    journalctl -u unbound -u dnsblockd --no-pager -n {{ N }}

# Restart DNS services (unbound + dnsblockd)
[group('services')]
[linux]
dns-restart:
    sudo systemctl restart unbound dnsblockd

# Full DNS diagnostics (status + test + recent logs)
[group('services')]
[linux]
dns-diagnostics:
    #!/usr/bin/env bash
    just dns-status
    echo ""
    just dns-test
    echo ""
    echo "=== Recent Logs ==="
    journalctl -u unbound -u dnsblockd --no-pager -n 20

# Internet connectivity diagnostic (run on evo-x2 or via SSH)
[group('services')]
[linux]
internet-diagnostic:
    ssh lars@{{ evo_x2_ip }} 'bash -s' < scripts/internet-diagnostic.sh

# Dual-WAN / ECMP status (remote: evo-x2)
[group('services')]
[linux]
wan-status:
    ssh lars@{{ evo_x2_ip }} 'echo "=== Route Health Monitor ==="; journalctl -u route-health-monitor --no-pager -n 5 --output=cat; echo; echo "=== Default Route ==="; ip route show default; echo; echo "=== MPTCP Endpoints ==="; ip mptcp endpoint show 2>/dev/null || echo "MPTCP endpoints not available"'

# Update DNS blocklist URLs to latest commits and recompute SRI hashes
[group('services')]
[linux]
dns-update:
    ./scripts/dns-update.sh

# Immich service status (server, ML, postgres, redis, backup timer)
[group('services')]
[linux]
immich-status:
    #!/usr/bin/env bash
    for svc in immich-server immich-machine-learning postgresql redis-immich; do
        printf "%-25s %s\n" "$svc:" "$(systemctl is-active $svc 2>/dev/null || echo 'not found')"
    done
    systemctl list-timers immich-db-backup.timer --no-pager 2>/dev/null | grep -q "immich" \
        && echo "immich-db-backup.timer:  scheduled" \
        || echo "immich-db-backup.timer:  not found"
    BACKUPS=$(ls /var/lib/immich/database-backup/ 2>/dev/null | wc -l)
    echo "Database backups:       $BACKUPS files"

# Immich logs (server + ML, last N lines)
[group('services')]
[linux]
immich-logs N="100":
    journalctl -u immich-server -u immich-machine-learning --no-pager -n {{ N }}

# Run Immich database backup manually
[group('services')]
[linux]
immich-backup:
    sudo systemctl start immich-db-backup && echo "Backup complete (/var/lib/immich/database-backup/)" || echo "Backup failed"

# Restart all Immich services
[group('services')]
[linux]
immich-restart:
    sudo systemctl restart immich-server immich-machine-learning

# Hermes AI gateway status
[group('services')]
[linux]
hermes-status:
    systemctl status hermes --no-pager 2>/dev/null | head -15

# Hermes gateway logs (last N lines, use journalctl -u hermes -f for live tail)
[group('services')]
[linux]
hermes-logs N="200":
    journalctl -u hermes --no-pager -n {{ N }}

# Restart Hermes gateway
[group('services')]
[linux]
hermes-restart:
    sudo systemctl restart hermes

# Gatus health check dashboard status
[group('services')]
[linux]
gatus-status:
    systemctl status gatus --no-pager 2>/dev/null | head -15
    @echo ""
    @echo "Dashboard: https://status.home.lan"
    @curl -sf http://localhost:8083/api/v1/endpoints/status 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Endpoints: {len(d)} monitored')" 2>/dev/null || echo "API: not responding yet"

# Manifest LLM router status
[group('services')]
[linux]
manifest-status:
    #!/usr/bin/env bash
    systemctl status manifest --no-pager 2>/dev/null | head -15
    BACKUPS=$(ls /var/lib/manifest/backup/ 2>/dev/null | wc -l)
    echo "Database backups: $BACKUPS files"

# Manifest router logs (last N lines)
[group('services')]
[linux]
manifest-logs N="200":
    journalctl -u manifest --no-pager -n {{ N }}

# Restart Manifest LLM router
[group('services')]
[linux]
manifest-restart:
    sudo systemctl restart manifest

# Backup Manifest database
[group('services')]
[linux]
manifest-backup:
    sudo systemctl start manifest-db-backup && echo "Backup complete (/var/lib/manifest/backup/)" || echo "Backup failed"

# OpenSEO SEO suite status
[group('services')]
[linux]
openseo-status:
    systemctl status openseo --no-pager 2>/dev/null | head -15
    @echo ""
    @echo "Dashboard: https://seo.home.lan"

# OpenSEO logs (last N lines)
[group('services')]
[linux]
openseo-logs N="200":
    journalctl -u openseo --no-pager -n {{ N }}

# Restart OpenSEO
[group('services')]
[linux]
openseo-restart:
    sudo systemctl restart openseo

# Sync GitHub repos to Forgejo mirror
[group('services')]
[linux]
forgejo-sync-repos:
    forgejo-ensure-repos

# Update Forgejo GitHub token from gh CLI
[group('services')]
[linux]
forgejo-update-token:
    forgejo-update-github-token

# ═══════════════════════════════════════════════════════════════════
#  Auth (Pocket ID + oauth2-proxy bootstrap)
# ═══════════════════════════════════════════════════════════════════

# Bootstrap Pocket ID admin account and OIDC clients (first-time setup)
# Run this ON evo-x2 after deploying with Pocket ID enabled for the first time
[group('services')]
[linux]
auth-bootstrap:
    #!/usr/bin/env bash
    set -euo pipefail

    DOMAIN="home.lan"
    AUTH_URL="https://auth.${DOMAIN}"

    echo "=== Pocket ID + oauth2-proxy Bootstrap ==="
    echo ""

    # Step 1: Check Pocket ID is running
    if ! systemctl is-active --quiet pocket-id.service 2>/dev/null; then
        echo "ERROR: pocket-id.service is not running."
        echo "       Run 'just switch' first, then retry."
        exit 1
    fi

    # Step 2: Check if admin has been set up
    echo "Step 1: Opening Pocket ID setup page in browser..."
    echo "        If this is the first time, you will be prompted to create an admin passkey."
    echo "        URL: ${AUTH_URL}/setup"
    echo ""

    # Step 3: Generate cookie secret
    COOKIE_SECRET="$(openssl rand -base64 32)"
    echo "Step 2: Generated oauth2-proxy cookie secret."
    echo ""

    # Step 4: Instructions for creating OIDC clients
    echo "Step 3: Create OIDC clients in Pocket ID admin UI:"
    echo ""
    echo "  a) oauth2-proxy client:"
    echo "     - Name: oauth2-proxy"
    echo "     - Callback URL: ${AUTH_URL}/oauth2/callback"
    echo "     - Logout URL: (leave empty)"
    echo "     → Copy the Client Secret"
    echo ""
    echo "  b) Immich client (optional):"
    echo "     - Name: immich"
    echo "     - Callback URL: https://immich.${DOMAIN}/api/auth/callback"
    echo "     - Logout URL: (leave empty)"
    echo "     → Copy the Client Secret"
    echo ""

    # Step 5: Prompt for secrets and update sops
    echo "Step 4: Update sops secrets with real values."
    echo "        Run the following commands (requires age key on evo-x2):"
    echo ""
    echo "  sops platforms/nixos/secrets/pocket-id.yaml"
    echo ""
    echo "  Set these values:"
    echo "    oauth2_proxy_client_secret: <from Pocket ID step 3a>"
    echo "    oauth2_proxy_cookie_secret: ${COOKIE_SECRET}"
    echo "    immich_oauth_client_secret: <from Pocket ID step 3b, or keep placeholder>"
    echo ""
    echo "Step 5: Deploy updated secrets:"
    echo "  just switch"
    echo ""
    echo "After deploy, oauth2-proxy should start successfully."
    echo "Test by visiting any protected service from an external network."

[group('services')]
[linux]
auth-status:
    #!/usr/bin/env bash
    echo "=== Auth Services Status ==="
    echo ""
    echo "--- Pocket ID ---"
    systemctl is-active pocket-id.service 2>/dev/null && echo "  Status: active" || echo "  Status: INACTIVE"
    curl -sf --max-time 2 http://127.0.0.1:1411/healthz 2>/dev/null && echo "  Health: OK" || echo "  Health: FAIL"
    echo ""
    echo "--- oauth2-proxy ---"
    systemctl is-active oauth2-proxy.service 2>/dev/null && echo "  Status: active" || echo "  Status: INACTIVE"
    curl -sf --max-time 2 http://127.0.0.1:4180/ping 2>/dev/null && echo "  Health: OK" || echo "  Health: FAIL"
    echo ""
    echo "--- Secrets ---"
    for secret in pocket_id_encryption_key oauth2_proxy_client_secret oauth2_proxy_cookie_secret immich_oauth_client_secret; do
        if [ -f "/run/secrets.d/1/${secret}" ] || [ -f "/run/secrets/${secret}" ]; then
            echo "  ${secret}: exists"
        else
            echo "  ${secret}: MISSING"
        fi
    done

# ═══════════════════════════════════════════════════════════════════
#  Desktop (NixOS — evo-x2)
# ═══════════════════════════════════════════════════════════════════

# EMEET PIXY camera status (tracking, audio, position)
[group('desktop')]
[linux]
cam-status:
    @emeet-pixyd status 2>/dev/null || echo "EMEET PIXY daemon not running"

# Toggle camera privacy mode
[group('desktop')]
[linux]
cam-privacy:
    @emeet-pixyd toggle-privacy 2>/dev/null || echo "EMEET PIXY daemon not running"

# Enable face tracking
[group('desktop')]
[linux]
cam-track:
    @emeet-pixyd track 2>/dev/null || echo "EMEET PIXY daemon not running"

# Center camera (reset pan/tilt/zoom)
[group('desktop')]
[linux]
cam-reset:
    @emeet-pixyd center 2>/dev/null || echo "EMEET PIXY daemon not running"

# Cycle or set audio mode (no arg cycles: nc -> live -> org -> nc)
[group('desktop')]
[linux]
cam-audio MODE="":
    @emeet-pixyd audio {{ MODE }} 2>/dev/null || echo "EMEET PIXY daemon not running"

# Sync daemon state with camera's actual HID state
[group('desktop')]
[linux]
cam-sync:
    @emeet-pixyd sync 2>/dev/null || echo "EMEET PIXY daemon not running"

# Restart EMEET PIXY daemon
[group('desktop')]
[linux]
cam-restart:
    @systemctl --user restart emeet-pixyd && echo "Restarted" || echo "Failed to restart"

# EMEET PIXY daemon logs (last 100 lines)
[group('desktop')]
[linux]
cam-logs:
    @journalctl --user -u emeet-pixyd --no-pager -n 100

# Wallpaper daemon and service status, image count, outputs
[group('desktop')]
[linux]
wallpaper-status:
    #!/usr/bin/env bash
    echo "Daemon:  $(systemctl --user is-active awww-daemon 2>/dev/null || echo 'stopped')"
    echo "Service: $(systemctl --user is-active awww-wallpaper 2>/dev/null || echo 'inactive')"
    count=$(ls ~/.local/share/wallpapers/*.{jpg,jpeg,png,webp} 2>/dev/null | wc -l)
    echo "Images:  $count wallpapers available"
    if command -v awww >/dev/null 2>&1 && systemctl --user is-active awww-daemon >/dev/null 2>&1; then
        echo "Outputs:"
        awww query 2>/dev/null || true
    fi

# Set random wallpaper
[group('desktop')]
[linux]
wallpaper-random:
    @wallpaper-set random

# Restore last displayed wallpaper
[group('desktop')]
[linux]
wallpaper-restore:
    @wallpaper-set restore

# Restart wallpaper daemon + wallpaper service
[group('desktop')]
[linux]
wallpaper-restart:
    @systemctl --user restart awww-daemon awww-wallpaper

# Wallpaper daemon logs (last 50 lines)
[group('desktop')]
[linux]
wallpaper-logs:
    @journalctl --user -u awww-daemon -u awww-wallpaper --no-pager -n 50

# Niri session manager status
[group('desktop')]
[linux]
session-status:
    @echo "Niri Session Manager Status"
    @echo "============================"
    @systemctl --user status niri-session-manager --no-pager 2>/dev/null || echo "Service not active"
    @echo ""
    @echo "Session file:"
    @ls -la ~/.local/share/niri-session-manager/session.json 2>/dev/null || echo "  No session file found"
    @echo ""
    @echo "Backups:"
    @ls -la ~/.local/share/niri-session-manager/*.bak 2>/dev/null || echo "  No backups found"
    @echo ""
    @echo "Config:"
    @cat ~/.config/niri-session-manager/config.toml 2>/dev/null || echo "  No config file found"

# Manually trigger niri session restore
[group('desktop')]
[linux]
session-restore:
    @systemctl --user restart niri-session-manager

# Reload niri compositor config (no rebuild needed)
[group('desktop')]
[linux]
reload:
    @niri msg action reload-config

# ═══════════════════════════════════════════════════════════════════
#  Tasks (Taskwarrior + TaskChampion)
# ═══════════════════════════════════════════════════════════════════

# Show pending tasks (next report)
[group('tasks')]
task-list:
    @task next

# Add a new task (pass any taskwarrior arguments)
[group('tasks')]
task-add *ARGS:
    @task add {{ ARGS }}

# Add AI-tracked task (+agent source:crush)
[group('tasks')]
task-agent *ARGS:
    @task add {{ ARGS }} +agent source:crush

# Sync tasks with TaskChampion server
[group('tasks')]
task-sync:
    @task sync

# Task status overview (pending, overdue, sync config)
[group('tasks')]
task-status:
    #!/usr/bin/env bash
    echo "Pending:   $(task count status:pending 2>/dev/null || echo '?')"
    echo "Overdue:   $(task count status:pending +OVERDUE 2>/dev/null || echo '?')"
    echo "Due today: $(task count status:pending due:today 2>/dev/null || echo '?')"
    echo ""
    echo "Sync: $(task config sync.server.url 2>/dev/null || echo 'not configured')"

# Show auto-configured TaskChampion credentials (derived from hostname)
[group('tasks')]
task-setup:
    #!/usr/bin/env bash
    echo "Taskwarrior auto-config (no manual steps needed)"
    echo "  Client ID: $(task config sync.server.client_id 2>/dev/null || echo 'not set')"
    echo "  Sync URL:   $(task config sync.server.url 2>/dev/null || echo 'not set')"
    echo "  Encrypted:  $(task config sync.encryption_secret 2>/dev/null > /dev/null 2>&1 && echo 'yes' || echo 'not set')"
    echo ""
    echo "Run 'just switch && task sync' to get started."

# Export all tasks as JSON backup
[group('tasks')]
task-backup:
    @mkdir -p ~/backups/taskwarrior
    @task export > ~/backups/taskwarrior/tasks-$$(date '+%Y-%m-%d_%H-%M-%S').json
    @echo "Exported to ~/backups/taskwarrior/"

# ═══════════════════════════════════════════════════════════════════
#  AI Models (NixOS — evo-x2)
# ═══════════════════════════════════════════════════════════════════

# Migrate legacy AI data (/data/{models,cache}) to /data/ai/
[group('ai')]
[linux]
ai-migrate:
    #!/usr/bin/env bash
    echo "Migrating AI data to /data/ai/"
    if [ ! -d /data/ai ]; then
        sudo mkdir -p /data/ai
        sudo chown lars:users /data/ai
    fi
    [ -d /data/models ] && [ ! -d /data/ai/models ] && mv /data/models /data/ai/models && echo "  models -> done"
    [ -d /data/cache ] && [ ! -d /data/ai/cache ] && mv /data/cache /data/ai/cache && echo "  cache -> done"
    [ -d /data/ai/models/ollama ] && [ ! -d /data/ai/models/ollama/models ] && mkdir -p /data/ai/models/ollama/models
    sudo systemd-tmpfiles --create
    echo ""
    echo "Migration complete. Run 'just switch' to apply."

# Show AI model storage status (directory tree, disk usage, env vars)
[group('ai')]
[linux]
ai-status:
    #!/usr/bin/env bash
    BASE="/data/ai"
    if [ ! -d "$BASE" ]; then
        echo "/data/ai does not exist. Run 'just ai-migrate' first."
        exit 0
    fi
    echo "=== AI Storage ==="
    du -sh "$BASE" 2>/dev/null
    echo ""
    for dir in "$BASE"/models/*/; do
        [ -d "$dir" ] && printf "  %-15s %s\n" "$(basename "$dir"):" "$(du -sh "$dir" 2>/dev/null | cut -f1)"
    done
    echo ""
    echo "OLLAMA_MODELS  = ${OLLAMA_MODELS:-not set}"
    echo "HF_HOME        = ${HF_HOME:-not set}"
    echo "PYTORCH_CUDA_ALLOC_CONF = ${PYTORCH_CUDA_ALLOC_CONF:-not set}"

# Run Python with GPU memory capped at 95% (default) or custom fraction
# Usage: just gpu-python script.py        (95% GPU memory)
#        just gpu-python 0.8 script.py    (80% GPU memory)
[group('ai')]
[linux]
gpu-python *ARGS="":
    #!/usr/bin/env bash
    exec gpu-python "$@"

# ═══════════════════════════════════════════════════════════════════
#  Tools
# ═══════════════════════════════════════════════════════════════════

# Extract TODOs from code (default: mock provider, pass --dir and --provider)
[group('tools')]
todo-scan *ARGS="":
    @todo-list-ai {{ ARGS }}

# Extract TODOs with OpenAI
[group('tools')]
todo-scan-openai DIR="./":
    @todo-list-ai --dir {{ DIR }} --provider openai

# Auto-configure golangci-lint for current project
[group('tools')]
lint-configure *ARGS="":
    @golangci-lint-auto-configure configure {{ ARGS }}

# ═══════════════════════════════════════════════════════════════════
#  Disk (NixOS — evo-x2)
# ═══════════════════════════════════════════════════════════════════

# Create pre-deploy BTRFS snapshot of root subvolume
[group('disk')]
[linux]
snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    TS="$(date +%Y-%m-%dT%H%M%S)"
    ROOT="/mnt/btrfs-root"
    SNAP_DIR="$ROOT/.snapshots"

    # Ensure toplevel is mounted (automount handles this after first deploy)
    if ! mountpoint -q "$ROOT" 2>/dev/null; then
        echo "Mounting $ROOT..."
        # Try fstab first (works after first deploy), then direct UUID (first deploy)
        sudo mount "$ROOT" 2>/dev/null || sudo mount -t btrfs -o noatime,compress=zstd \
            "UUID=0b629b65-a1b7-40df-a7dc-9ea5e0b04959" "$ROOT" \
            || { echo "FATAL: Cannot mount $ROOT — cannot create pre-deploy snapshot. Aborting."; exit 1; }
    fi

    if ! [ -d "$ROOT/@" ]; then
        echo "FATAL: $ROOT/@ not found — root subvolume missing. Aborting."; exit 1
    fi

    sudo mkdir -p "$SNAP_DIR"
    sudo btrfs subvolume snapshot -r "$ROOT/@" "$SNAP_DIR/@.pre-deploy-$TS" \
        || { echo "FATAL: Snapshot creation failed. Aborting."; exit 1; }
    echo "Pre-deploy snapshot: $SNAP_DIR/@.pre-deploy-$TS"

    # Prune old pre-deploy snapshots (keep last 5)
    PRE_DEPLOY_COUNT=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.pre-deploy-*' | wc -l)
    if [ "$PRE_DEPLOY_COUNT" -gt 5 ]; then
        find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.pre-deploy-*' \
            | sort \
            | head -n $((PRE_DEPLOY_COUNT - 5)) \
            | while read -r old; do
                echo "  pruning: $(basename "$old")"
                sudo btrfs subvolume delete "$old"
            done
    fi

# List BTRFS snapshots
[group('disk')]
[linux]
snapshot-list:
    #!/usr/bin/env bash
    SNAP_DIR="/mnt/btrfs-root/.snapshots"
    if [ ! -d "$SNAP_DIR" ]; then
        echo "No snapshots directory. Run 'just switch' to create first snapshot."
        exit 0
    fi
    COUNT=$(find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l)
    echo "=== Root snapshots ($COUNT) ==="
    find "$SNAP_DIR" -maxdepth 1 -mindepth 1 -type d -name '@.*' | sort | while read -r snap; do
        basename "$snap"
    done

# One-time migration: convert /data from BTRFS toplevel to @data subvolume
# Required before /data can be snapshotted. Stops Docker first.
# After running: update hardware-configuration.nix to add subvol=@data, then just switch
[group('disk')]
[linux]
snapshot-migrate-data:
    #!/usr/bin/env bash
    set -euo pipefail
    DATA_UUID="046ea663-da55-48b7-b516-0dcdb87ba710"
    MNT="/mnt/btrfs-data-migrate"

    echo "=== /data BTRFS Migration ==="
    echo "This converts /data from toplevel (subvolid=5) to @data subvolume."
    echo "Docker and all services using /data will be stopped."
    echo ""
    read -rp "Continue? [y/N] " CONFIRM
    [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]] && echo "Aborted." && exit 0

    # Check /data is BTRFS and mounted as toplevel
    if ! mountpoint -q /data 2>/dev/null; then
        echo "ERROR: /data is not mounted"
        exit 1
    fi

    # Stop services that write to /data
    echo "Stopping services that write to /data..."
    sudo systemctl stop docker.service docker.socket 2>/dev/null || true
    sudo systemctl stop ollama.service 2>/dev/null || true
    sudo systemctl stop comfyui.service 2>/dev/null || true
    sudo systemctl stop btrbk-root.timer btrbk-root.service 2>/dev/null || true
    # Stop any podman containers using /data
    for svc in $(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print $1}'); do
        if systemctl show "$svc" --property=ExecStart 2>/dev/null | grep -q '/data/'; then
            echo "  stopping $svc (uses /data)"
            sudo systemctl stop "$svc" 2>/dev/null || true
        fi
    done

    # Mount toplevel
    echo "Mounting toplevel at $MNT..."
    sudo mkdir -p "$MNT"
    sudo mount -t btrfs -o compress=zstd:3,ssd,discard=async "UUID=$DATA_UUID" "$MNT"

    # Check if @data already exists
    if sudo btrfs subvolume show "$MNT/@data" &>/dev/null; then
        echo "ERROR: @data subvolume already exists. Migration may have been done already."
        sudo umount "$MNT"
        exit 1
    fi

    # Create @data subvolume
    echo "Creating @data subvolume..."
    sudo btrfs subvolume create "$MNT/@data"

    # Move content (everything except @data and subvolumes)
    echo "Moving content into @data (this may take a while)..."
    for item in "$MNT"/*; do
        name=$(basename "$item")
        [[ "$name" == "@data" ]] && continue
        [[ "$name" == ".snapshots" ]] && continue
        echo "  moving: $name"
        sudo mv "$item" "$MNT/@data/"
    done
    # Handle hidden files/dirs
    for item in "$MNT"/.*; do
        name=$(basename "$item")
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ "$name" == "@data" ]] && continue
        echo "  moving: $name"
        sudo mv "$item" "$MNT/@data/"
    done

    # Verify
    echo ""
    echo "Verification:"
    echo "  @data subvolume:"
    sudo btrfs subvolume show "$MNT/@data" | head -3
    echo "  Contents:"
    ls "$MNT/@data/" | head -20

    # Unmount
    sudo umount "$MNT"
    sudo rmdir "$MNT"

    echo ""
    echo "=== Migration complete ==="
    echo "Next steps:"
    echo "  1. Edit platforms/nixos/hardware/hardware-configuration.nix"
    echo "     Add 'subvol=@data' to /data mount options"
    echo "  2. Run 'just switch' to apply"
    echo "  3. Verify: mount | grep /data"
    echo "  4. Optionally add /data to btrbk in snapshots.nix"

# Disk monitor status, filesystem usage, and alert state
[group('disk')]
[linux]
disk-status:
    #!/usr/bin/env bash
    echo "=== Disk Monitor ==="
    systemctl list-timers disk-monitor.timer --no-pager 2>/dev/null | grep disk || echo "Timer not found"
    echo ""
    echo "=== Filesystem Usage ==="
    for mp in / /data; do
        if mountpoint -q "$mp" 2>/dev/null; then
            df -h "$mp" | tail -1 | awk -v mp="$mp" '{printf "  %-6s %s used, %s free of %s\n", mp, $5, $4, $2}'
        fi
    done
    echo ""
    ALERTS=$(ls ~/.local/state/disk-monitor/ 2>/dev/null | wc -l)
    echo "Active alerts: $ALERTS"

# Trigger manual disk check
[group('disk')]
[linux]
disk-check:
    @systemctl start disk-monitor.service && echo "Check completed" || echo "Check failed"

# Reset disk monitor notification state
[group('disk')]
[linux]
disk-reset:
    @trash ~/.local/state/disk-monitor/* 2>/dev/null || true
    @echo "Notification state cleared"

# Run Rust target/ cleanup (artifacts >7 days from dirs >2GB)
[group('disk')]
[linux]
rust-clean:
    #!/usr/bin/env bash
    sudo systemctl start rust-target-cleanup
    journalctl -u rust-target-cleanup --no-pager -n 20
