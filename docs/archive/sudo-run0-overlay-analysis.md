# Feasibility: Overlay `sudo` with `run0` Wrapper on SystemNix

**Date:** 2026-05-06
**Status:** Feasible with caveats — not yet implemented

---

## The Idea

Overlay `pkgs.sudo` with a wrapper script that translates `sudo` CLI calls to `run0` calls. Remove the sudo setuid binary entirely from the system.

### Why this works at all

- **`sudo` is a leaf package** — zero reverse dependencies other than `system-path` and security wrappers, which rebuild every `just switch` anyway
- **Cache invalidation: ZERO** — no other packages rebuild
- **run0 is already installed** — systemd 260.1, symlink to `systemd-run`
- **Passwordless wheel** — the primary polkit complexity (auth prompting) is moot

---

## Flag Translation Table

Complete inventory of `sudo` flags used by NixOS modules + SystemNix codebase:

| sudo flag               | NixOS uses                               | run0 equivalent        | Status                 |
| ----------------------- | ---------------------------------------- | ---------------------- | ---------------------- |
| `-u <user>`             | 23 modules                               | `-u <user>`            | Direct match           |
| `-g <group>`            | pretix                                   | `-g <group>`           | Direct match           |
| `-n` (non-interactive)  | homebridge                               | `--no-ask-password`    | Direct match           |
| `-i` (login shell)      | user aliases                             | `-i`                   | Direct match           |
| `-s` (shell)            | user aliases                             | `--via-shell`          | Different name         |
| `--` (end flags)        | mediawiki                                | `--`                   | Direct match           |
| `--preserve-env=VAR`    | pretix, pretalx, healthchecks, nextcloud | `--setenv=VAR=$VAR`    | Parseable in wrapper   |
| `-E` (preserve all env) | paperless, glitchtip, pdfding            | Enumerate all env vars | Ugly but works         |
| `--preserve-env` (bare) | mastodon, libretranslate, healthchecks   | Enumerate all env vars | Ugly but works         |
| `-A` (askpass)          | nowhere                                  | No equivalent          | Unused — not a concern |

### The `--preserve-env` problem

**Named vars** (`--preserve-env=PRETIX_CONFIG_FILE`): Clean. Wrapper parses the var name, reads `$VAR` from current environment, passes `--setenv=VAR=value` to run0. These vars are load-bearing:

- `PRETIX_CONFIG_FILE`, `PRETALX_CONFIG_FILE` → config file paths
- `PYTHONPATH` → Python import paths
- `CREDENTIALS_DIRECTORY` → systemd secret injection
- `OC_PASS`, `NC_PASS` → Nextcloud admin passwords

**Bare `--preserve-env` / `-E`**: Ugly. Must enumerate every environment variable and forward as `--setenv`. This passes 100+ vars into a transient systemd unit. It works but is slow and inelegant. Used by paperless, glitchtip, pdfding, mastodon, libretranslate, healthchecks.

---

## Concerns to Consider

### 1. PTY Allocation Breaks Embedded Terminals

run0 allocates its own PTY by default. This corrupts input in embedded terminals (Crush, VS Code terminal, Emacs vterm, etc.).

- `--pipe` fixes embedded terminals but breaks `sudo -i` / `sudo -s` (no TTY for the child)
- Default (PTY) breaks embedded terminals but works for interactive shell use
- **Mitigation**: Wrapper detects `[ -t 0 ]` → use `--pty`, else `--pipe`
- **Tradeoff**: Shell modes (`-i`, `-s`) won't work inside Crush regardless

### 2. Polkit Requires D-Bus System Bus

run0 authenticates via polkit, which needs D-Bus.

- System bus is always available — SSH, cron, systemd services all have it
- With a passwordless `polkit.Result.YES` rule, no auth agent is needed
- **Should work everywhere** including SSH — but must be tested
- The polkit rule:

```javascript
// /etc/polkit-1/rules.d/20-run0-wheel.rules
polkit.addRule(function (action, subject) {
  if (action.id.indexOf("org.freedesktop.systemd1.") === 0 && subject.isInGroup("wheel")) {
    return polkit.Result.YES;
  }
});
```

### 3. Transient Unit Overhead

Every `sudo` call becomes: D-Bus → polkit → systemd → new cgroup → transient service → exec.

- ~50ms per call vs ~5ms for setuid
- `just switch` calls `sudo nixos-rebuild` once — negligible
- Scripts with many sudo calls (gitea-repos) — slightly slower but not blocking
- Every invocation creates a `.service` unit in systemd

### 4. Exit Codes May Differ

- sudo returns the child's exit code directly
- run0 may return different codes for transient unit failures (D-Bus errors, polkit denials)
- Scripts that check `$?` could see unexpected values
- Wrapper should propagate the child's exit code faithfully

### 5. NixOS Service Module Compatibility

27 NixOS service modules hardcode `/run/wrappers/bin/sudo` for privilege-dropping CLI wrappers. None are currently enabled on evo-x2, but enabling any in the future would break silently.

Affected modules: nextcloud, mastodon, paperless, pretix, pretalx, healthchecks, glitchtip, pdfding, mediawiki, mailman, crowdsec, snipe-it, pixelfed, monica, agorakit, gancio, mediagoblin, froide-govplan, libretranslate, akkoma, zammad, pihole-ftl, kresd, librenms, omnom, borgmatic, homebridge.

### 6. Single Point of Failure

- If polkit, D-Bus, or systemd is broken → **no admin access at all**
- With sudo, you only need a working setuid binary
- **Mitigation**: Keep `sudo` binary available as fallback at `/run/wrappers/bin/sudo.real`

### 7. The `sudo` Binary Path

NixOS modules use two paths:

- `/run/wrappers/bin/sudo` — the setuid wrapper (used by most modules)
- `${config.security.wrapperDir}/sudo` — same thing, parameterized
- `${pkgs.sudo}/bin/sudo` — the package directly (used by borgmatic, restic)

The overlay must provide a working `sudo` at `/run/wrappers/bin/sudo` AND in the system PATH.

---

## What the Wrapper Would Look Like

Approximately 40-60 lines of bash:

```bash
#!/bin/sh
# sudo → run0 compatibility wrapper
# Installed as overlay for pkgs.sudo

set -euo pipefail

run0_args=()
setenv_args=()
passthrough_args=()
preserve_all_env=false
preserve_vars=""

while [ $# -gt 0 ]; do
    case "$1" in
        -u) run0_args+=(-u "$2"); shift 2 ;;
        -u=*) run0_args+=(-u "${1#-u=}"); shift ;;
        -g) run0_args+=(-g "$2"); shift 2 ;;
        -g=*) run0_args+=(-g "${1#-g=}"); shift ;;
        -E) preserve_all_env=true; shift ;;
        -n) run0_args+=(--no-ask-password); shift ;;
        -s) run0_args+=(--via-shell); shift ;;
        -i) run0_args+=(-i); shift ;;
        --preserve-env)
            preserve_all_env=true; shift ;;
        --preserve-env=*)
            preserve_vars="$preserve_vars ${1#--preserve-env=}"; shift ;;
        -S) shift ;;  # stdin password — ignore for run0
        -k|-K|-V|-l|-v) shift ;;  # sudo-specific — ignore
        --) shift; passthrough_args+=("$@"); break ;;
        -*) shift ;;  # unknown flags — skip
        *) passthrough_args+=("$@"); break ;;
    esac
done

# Forward preserved env vars
for var in $preserve_vars; do
    eval "val=\${$var:-}"
    if [ -n "$val" ]; then
        setenv_args+=(--setenv "$var=$val")
    fi
done

# Forward all env if -E or bare --preserve-env
if [ "$preserve_all_env" = true ]; then
    while IFS='=' read -r name value; do
        [ -n "$name" ] && setenv_args+=(--setenv "$name=$value")
    done < <(env)
fi

# Choose PTY or pipe based on stdin
if [ -t 0 ]; then
    pty_flag=()  # default: run0 allocates PTY
else
    pty_flag=(--pipe)
fi

exec run0 \
    "${pty_flag[@]}" \
    --no-ask-password \
    "${run0_args[@]}" \
    "${setenv_args[@]}" \
    "${passthrough_args[@]}"
```

### Required NixOS config additions

```nix
# Polkit rule for passwordless run0
security.polkit.extraConfig = ''
  polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.systemd1.") === 0 &&
          subject.isInGroup("wheel")) {
          return polkit.Result.YES;
      }
  });
'';

# Overlay sudo package with wrapper
nixpkgs.overlays = [
  (final: prev: {
    sudo = prev.writeShellApplication {
      name = "sudo";
      runtimeInputs = [ final.systemd ];
      text = builtins.readFile ./scripts/sudo-run0-wrapper.sh;
    };
  })
];
```

---

## Implementation Checklist

If we proceed:

- [ ] Write wrapper script (`scripts/sudo-run0-wrapper.sh`)
- [ ] Add polkit rule to NixOS config
- [ ] Add overlay in `flake.nix`
- [ ] Keep `sudo.real` fallback in security wrappers
- [ ] Test from niri terminal
- [ ] Test from Crush
- [ ] Test over SSH
- [ ] Test `just switch` end-to-end
- [ ] Test `just dns-restart` (systemctl call)
- [ ] Test gitea-repos sops access (env forwarding)
- [ ] Test `sudo -i` and `sudo -s` in real terminal
- [ ] Verify fallback (`sudo.real`) works if polkit is broken
- [ ] Update AGENTS.md with migration notes

---

## Alternative: doas Overlay

If run0's architectural differences prove too fragile, doas is the simpler overlay:

- Same leaf-package story (zero cache invalidation)
- Same TTY as sudo (no PTY allocation problem)
- `-E` and `--preserve-env` still need wrapper translation (doas has `keepenv` in config, not CLI)
- No polkit dependency (setuid like sudo)
- ~600 lines of code vs sudo's 150K
- But: no ecosystem momentum, OpenBSD-origin, not the "future"

---

## Verdict

run0 overlay is **feasible but not recommended today**. The wrapper solves the flag translation, the cache story is perfect (zero invalidation), and the polkit rule should work everywhere. But:

1. It's a compatibility shim fighting run0's architecture (env isolation, transient units)
2. The PTY detection heuristic (`[ -t 0 ]`) has edge cases
3. Any future NixOS module using a new sudo flag breaks the wrapper silently
4. The single-point-of-failure risk (polkit/D-Bus/systemd chain)

If you want to proceed anyway, the implementation is ~2 hours including testing. Just keep `sudo.real` as an escape hatch.
