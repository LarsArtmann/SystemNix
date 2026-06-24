#!/usr/bin/env bash
# SystemNix Health Check — cross-platform (Darwin + NixOS)
# Replaces: health-check.sh (macOS-only), health-dashboard.sh (macOS-only), just health (inline)
set -euo pipefail

source "$(dirname "$0")/lib.sh"

is_darwin() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }

# --- Nix ---
section "Nix"
if command -v nix >/dev/null 2>&1; then
  ok "nix $(nix --version 2>&1 | head -1 | awk '{print $NF}')"
else
  fail "nix not found in PATH"
fi

if is_linux && ! pgrep -x nix-daemon >/dev/null 2>&1; then
  warn "nix-daemon not running"
elif is_linux; then
  ok "nix-daemon running"
fi

# --- Flake ---
section "Flake"
if [[ -f flake.nix ]]; then
  ok "flake.nix found"
  if nix flake check --no-build 2>/dev/null; then
    ok "nix flake check --no-build passes"
  else
    fail "nix flake check --no-build fails"
  fi
else
  warn "not in SystemNix root (flake.nix not found)"
fi

# --- Direnv ---
section "Direnv"
if command -v direnv >/dev/null 2>&1; then
  ok "direnv $(direnv version 2>&1 | awk '{print $1}')"
  if [[ -f .envrc ]]; then
    if [[ -L .direnv/flake-profile ]]; then
      ok ".direnv/flake-profile is symlink (healthy)"
    elif [[ -f .direnv/flake-profile ]] && [[ ! -L .direnv/flake-profile ]]; then
      fail ".direnv/flake-profile is regular file (corrupted — trash it and reload)"
    else
      info ".direnv/flake-profile not yet created"
    fi
  fi
else
  warn "direnv not installed"
fi

# --- Shell ---
section "Shell"
for tool in starship fish fzf git just; do
  if command -v "$tool" >/dev/null 2>&1; then
    ver=$("$tool" --version 2>&1 | head -1 | sed 's/.* //')
    ok "$tool ${ver:-ok}"
  else
    fail "$tool not found"
  fi
done

# --- Dotfile Links ---
section "Dotfiles"
for f in ~/.config/fish/config.fish ~/.config/starship.toml ~/.config/git/config; do
  base=$(basename "$(dirname "$f")/$(basename "$f")")
  if [[ -L $f ]]; then
    ok "$base → $(readlink "$f" | sed 's|.*/nix/store/|/nix/store/...|' | cut -c1-60)"
  elif [[ -f $f ]]; then
    warn "$base is regular file (not HM-managed)"
  else
    fail "$base missing"
  fi
done

# --- Go ---
section "Go"
if command -v go >/dev/null 2>&1; then
  ok "go $(go version 2>&1 | awk '{print $3}')"
  for tool in gopls modernize; do
    if command -v "$tool" >/dev/null 2>&1; then
      ok "$tool available"
    else
      warn "$tool not found (run: just switch to install via Nix)"
    fi
  done
else
  warn "go not installed"
fi

# --- Platform-Specific ---
if is_linux; then
  # NixOS checks
  section "NixOS System"

  # Niri
  if systemctl --user is-active niri >/dev/null 2>&1; then
    ok "niri compositor running"
  else
    warn "niri not running (graphical session may be inactive)"
  fi

  # Graphical session target — critical for DMS, cliphist, swayidle, wallpaper
  if systemctl --user is-active graphical-session.target >/dev/null 2>&1; then
    ok "graphical-session.target active"
  else
    fail "graphical-session.target NOT active — DMS and other graphical services will not start"
    info "  This usually means niri.service is missing Wants=graphical-session.target"
    info "  Check: systemctl --user status graphical-session.target"
  fi

  # DMS (DankMaterialShell) — the desktop shell
  if systemctl --user is-active dms.service >/dev/null 2>&1; then
    ok "dms.service running"
  else
    fail "dms.service NOT running — desktop shell is down"
  fi

  # Systemd failed units
  failed_system=$(systemctl --failed --no-legend 2>/dev/null | grep -c "failed" || echo "0")
  failed_user=$(systemctl --user --failed --no-legend 2>/dev/null | grep -c "failed" || echo "0")
  if [[ $failed_system -eq 0 ]] && [[ $failed_user -eq 0 ]]; then
    ok "no failed systemd units"
  else
    fail "$failed_system system + $failed_user user failed systemd units"
    systemctl --failed --no-legend 2>/dev/null | head -5 | while read -r line; do
      info "  $line"
    done
  fi

  # Home Manager generation age
  if [[ -L /nix/var/nix/profiles/per-user/$USER/home-manager ]]; then
    hm_gen=$(readlink /nix/var/nix/profiles/per-user/$USER/home-manager)
    hm_date=$(stat -c %Y "$hm_gen" 2>/dev/null || echo "0")
    now=$(date +%s)
    age_days=$(((now - hm_date) / 86400))
    if [[ $age_days -gt 7 ]]; then
      warn "HM generation is ${age_days}d old (consider: just switch)"
    else
      ok "HM generation is ${age_days}d old"
    fi
  fi

  # Harden adoption audit — services with serviceConfig should use shared lib
  section "Service Harden Adoption"
  if [[ -d modules/nixos/services ]]; then
    missing_harden=""
    for f in modules/nixos/services/*.nix; do
      [[ "$(basename "$f")" == "default.nix" ]] && continue
      if grep -q "serviceConfig" "$f" 2>/dev/null && ! grep -q "harden" "$f" 2>/dev/null; then
        missing_harden="$missing_harden $(basename "$f")"
      fi
    done
    if [[ -z $missing_harden ]]; then
      ok "all service modules use harden{}"
    else
      warn "modules missing harden{}:$missing_harden"
    fi
  fi

  # Disk
  section "Disk"
  for mount in / /data; do
    if mountpoint -q "$mount" 2>/dev/null; then
      pct=$(df "$mount" | awk 'NR==2{print $5}' | tr -d '%')
      free=$(df -h "$mount" | awk 'NR==2{print $4}')
      if [[ $pct -gt 90 ]]; then
        fail "$mount ${pct}% used (${free} free)"
      elif [[ $pct -gt 80 ]]; then
        warn "$mount ${pct}% used (${free} free)"
      else
        ok "$mount ${pct}% used (${free} free)"
      fi
    fi
  done
  if [[ -d /nix/store ]]; then
    nix_size=$(du -sh /nix/store 2>/dev/null | awk '{print $1}' || echo "?")
    info "/nix/store is ${nix_size}"
  fi

  # Memory
  section "Memory"
  if [[ -f /proc/meminfo ]]; then
    total=$(awk '/MemTotal/{printf "%.0f", $2/1024/1024}' /proc/meminfo)
    avail=$(awk '/MemAvailable/{printf "%.0f", $2/1024/1024}' /proc/meminfo)
    used=$((total - avail))
    pct=$((used * 100 / total))
    if [[ $pct -gt 90 ]]; then
      fail "${used}G/${total}G used (${pct}%)"
    elif [[ $pct -gt 80 ]]; then
      warn "${used}G/${total}G used (${pct}%)"
    else
      ok "${used}G/${total}G used (${pct}%)"
    fi
  fi

elif is_darwin; then
  # macOS checks
  section "macOS System"

  if command -v brew >/dev/null 2>&1; then
    ok "homebrew $(brew --version | head -1 | awk '{print $2}')"
  fi

  if command -v darwin-rebuild >/dev/null 2>&1; then
    ok "darwin-rebuild available"
  fi

  # Disk
  section "Disk"
  root_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  root_free=$(df -h / | awk 'NR==2{print $4}')
  if [[ $root_pct -gt 90 ]]; then
    fail "/ ${root_pct}% used (${root_free} free)"
  else
    ok "/ ${root_pct}% used (${root_free} free)"
  fi
fi

# --- Summary ---
summary
