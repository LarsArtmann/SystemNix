# PRO/CONTRA: Replacing `sudo` with `doas` or `run0` on SystemNix

**Date:** 2026-05-06
**Decision:** Keep `sudo` — migration cost exceeds security benefit for passwordless wheel setups

---

## Current Setup

```nix
# platforms/nixos/system/sudo.nix
security.sudo = {
  enable = true;
  wheelNeedsPassword = false;  # passwordless for wheel
};
```

**52 references to `sudo`** across 10 files (justfile, scripts, nix modules). Primarily `sudo systemctl` (9), `sudo nixos-rebuild` (9), and misc admin commands.

---

## The Contenders

|               | **sudo** (Sudoers)                                                                                | **doas** (OpenDoas)                | **run0** (systemd)                                  |
| ------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------- | --------------------------------------------------- |
| Origin        | Todd C. Miller                                                                                    | Ted Unangst (OpenBSD)              | Lennart Poettering (systemd)                        |
| Lines of Code | ~150,000+                                                                                         | ~1,000                             | Built into systemd                                  |
| Config        | `/etc/sudoers` (DSL)                                                                              | `/etc/doas.conf` (5-line)          | No config (uses polkit)                             |
| NixOS Module  | `security.sudo` (mature)                                                                          | `security.doas` (mature)           | No native NixOS module yet                          |
| CVE History   | 100+ CVEs, including **Baron Samedit** (CVE-2021-3156: unauthenticated heap overflow → full root) | **Zero CVEs** (OpenBSD provenance) | N/A (too new for CVE history)                       |
| Auth          | PAM                                                                                               | PAM / BSD Auth                     | polkit (systemd)                                    |
| Passwordless  | `NOPASSWD` flag                                                                                   | `nopass` flag                      | polkit rules                                        |
| Persistence   | `timestamp_timeout`                                                                               | `persist` (5 min)                  | polkit session                                      |
| Logging       | syslog, verbose                                                                                   | syslog, minimal                    | journald                                            |
| Env handling  | Complex (`env_keep`, `secure_path`, etc.)                                                         | Simple (`keepenv`, `setenv`)       | Clean slate — must use `--setenv`                   |
| PTY behavior  | Same TTY                                                                                          | Same TTY                           | Allocates its own PTY                               |
| Architecture  | setuid binary                                                                                     | setuid binary                      | No setuid — D-Bus → polkit → systemd transient unit |

---

## PRO doas (Arguments FOR switching to doas)

### 1. Security surface area is ~150x smaller

`doas.c` is ~600 lines. `sudo` is ~150K lines. The Baron Samedit CVE (CVE-2021-3156) proved sudo's complexity is an exploitable liability — unauthenticated local root via heap overflow in the meta-character escaping logic. That class of bug literally cannot exist in doas because doas doesn't have a plugin architecture, a complex DSL parser, or shell escaping modes.

### 2. Zero CVEs ever

doas has had zero security vulnerabilities in its history. It originated on OpenBSD, where code audit is a first-class practice. sudo has had dozens, including multiple critical ones.

### 3. First-class NixOS support

`security.doas` is a mature NixOS module with: `enable`, `wheelNeedsPassword`, `extraRules` (users, groups, commands, `noPass`, `persist`, `keepEnv`, `setEnv`), and `extraConfig`. Feature-parity with the current passwordless wheel setup.

### 4. Drop-in migration in NixOS

Setting `security.sudo.enable = false` + `security.doas.enable = true` removes sudo from the system entirely. NixOS handles the setuid wrapper correctly. `doas` is syntactically similar: `doas <command>` vs `sudo <command>`.

### 5. Current config is trivial to replicate

```nix
security.sudo.enable = false;
security.doas = {
  enable = true;
  wheelNeedsPassword = false;
};
```

Same passwordless-wheel behavior, 1:1.

### 6. OpenBSD provenance

OpenBSD's security track record is unmatched. Ted Unangst wrote doas specifically because sudo was too complex to audit. This is the "do one thing well" philosophy.

### 7. Removes the entire sudoers parser attack surface

sudoers DSL parsing has been the source of multiple vulnerabilities. doas.conf is a flat `permit/deny` format that's trivially parseable and impossible to misconfigure.

---

## CONTRA doas (Arguments AGAINST switching to doas)

### 1. 52 references to `sudo` in the codebase must be audited

- **justfile**: 16 `sudo` calls (`sudo nixos-rebuild`, `sudo systemctl`, `sudo nix-store`, etc.)
- **scripts/**: ~14 references (diagnostic script, niri-session-save filtering)
- **modules/**: `gitea-repos.nix` uses `sudo` for sops age-key access
- **NixOS module ecosystem**: Some NixOS modules and third-party tools may internally call `sudo` or depend on it being present. Not all of these are obvious.

### 2. Tools that hardcode `sudo`

Many programs (GUI updaters, polkit helpers, desktop environments) internally invoke `sudo`. If the `sudo` binary is removed, they silently break. This includes things like `pkexec` interactions and some polkit rule implementations.

Some NixOS modules may explicitly depend on `sudo` being in PATH.

### 3. `sudo` can be kept alongside `doas` but defeats the purpose

Both can coexist (`security.sudo.enable = true` + `security.doas.enable = true`), but then you've added attack surface instead of removing it.

### 4. Minor feature gaps

- **No `sudo -i` equivalent**: `doas -s` exists but doesn't perfectly replicate `sudo -i` login shell behavior (no profile sourcing by default).
- **No `sudo -A` (askpass)**: doas has no built-in askpass support for GUI password prompts.
- **No `visudo` equivalent**: doas.conf is simple enough not to need it, but no syntax checker beyond `doas -C`.
- **No `sudoedit`**: doas has no dedicated safe-edit mechanism. You'd use `doas $EDITOR /path`.
- **No lecture**: doas doesn't have the "we trust you have received the usual lecture" message (minor, but some compliance frameworks expect it).

### 5. No meaningful security gain for passwordless setups

The config is `wheelNeedsPassword = false`. The entire authentication bypass attack surface (the one doas eliminates) is moot — passwords are already disabled. The remaining attack surface is the setuid binary itself, where doas genuinely wins, but the practical risk difference is small when already passwordless.

---

## run0 Deep Dive

`run0` is already installed on the system (systemd 260.1, symlink to `systemd-run`):

```
/run/current-system/sw/bin/run0 → /nix/store/...-systemd-260.1/bin/run0
```

### How run0 is architecturally different

`run0` is not just another setuid binary — it's a completely different mechanism:

- **No setuid at all** — runs through the systemd service manager as a transient unit
- **Authentication via polkit**, not PAM directly (though polkit uses PAM under the hood via `systemd-run0` PAM stack)
- **Allocates its own PTY** — independent pseudo-tty for the invoked command
- **Clean environment** — no env vars inherited from caller, must use `--setenv`
- **Every invocation** goes: D-Bus → polkit → systemd → new cgroup → transient service

### run0 polkit actions

run0 uses these polkit action IDs (from `org.freedesktop.systemd1.policy`):

| Action ID                                        | Purpose                          |
| ------------------------------------------------ | -------------------------------- |
| `org.freedesktop.systemd1.manage-units`          | Start/stop/restart systemd units |
| `org.freedesktop.systemd1.manage-unit-files`     | Enable/disable unit files        |
| `org.freedesktop.systemd1.reload-daemon`         | Daemon reload                    |
| `org.freedesktop.systemd1.set-environment`       | Set systemd environment          |
| `org.freedesktop.systemd1.reply-password`        | Password replies                 |
| `org.freedesktop.systemd1.bypass-dump-ratelimit` | Dump rate limit bypass           |

Current NixOS polkit config (`/etc/polkit-1/rules.d/10-nixos.rules`) only grants access for `org.opensuse.cupspkhelper.mechanism.all-edit` to wheel. No run0 rules exist.

### Could we symlink `sudo` → `run0`?

Technically yes, but it breaks immediately because:

#### Problem 1: PTY takeover scrambles embedded terminals

`run0` allocates its own PTY by default. When run inside Crush (or any embedded terminal like VS Code's, Emacs' vterm, etc.), the PTY handoff corrupts input. This is the showstopper — every `sudo` call from within Crush, SSH, or any non-desktop-terminal context breaks.

Workaround: `run0 --pipe` avoids PTY allocation and uses direct pipes instead.

#### Problem 2: polkit authentication blocks non-interactive use

`run0` requires polkit authentication. With `--no-ask-password`, it just fails:

```
$ run0 --pipe --no-ask-password id
Failed to start transient service unit: Access denied as the requested operation
requires interactive authentication. However, interactive authentication has not
been enabled by the calling program.
```

Fix: A polkit rule granting wheel passwordless access:

```javascript
// /etc/polkit-1/rules.d/20-run0-wheel.rules
polkit.addRule(function (action, subject) {
  if (action.id.indexOf("org.freedesktop.systemd1.") === 0 && subject.isInGroup("wheel")) {
    return polkit.Result.YES;
  }
});
```

This catches all systemd1 polkit actions (manage-units, manage-unit-files, reload-daemon, set-environment, etc.).

#### Problem 3: Environment isolation

`sudo` inherits your environment (especially with `wheelNeedsPassword = false`). `run0` starts from a clean slate. Calls like:

```bash
sudo env SOPS_AGE_KEY_FILE="$AGE_KEY_FILE" sops "$@"    # gitea-repos.nix
```

The env var wouldn't reach the transient unit without `--setenv`. You'd need a wrapper script that parses env var assignments and forwards them:

```bash
#!/bin/sh
args=()
env_vars=()
while [ $# -gt 0 ]; do
    case "$1" in
        *=*) env_vars+=(--setenv "$1"); shift ;;
        env) shift ;;  # skip literal 'env'
        *) args+=("$@"); break ;;
    esac
done
exec run0 --pipe --no-ask-password "${env_vars[@]}" "${args[@]}"
```

#### Problem 4: CLI flag incompatibility

The wrapper must perfectly emulate `sudo`'s CLI parsing or every call site breaks:

| sudo flag                   | run0 equivalent                      | Notes                               |
| --------------------------- | ------------------------------------ | ----------------------------------- |
| `sudo <cmd>`                | `run0 --pipe <cmd>`                  | Works                               |
| `sudo -u user <cmd>`        | `run0 --pipe -u user <cmd>`          | Works                               |
| `sudo -i`                   | `run0 --pipe -i`                     | run0 has `-i` (via-shell + chdir ~) |
| `sudo -s`                   | `run0 --pipe --via-shell`            | Different flag name                 |
| `sudo -A`                   | No equivalent                        | run0 has no askpass support         |
| `sudo env FOO=bar cmd`      | Must parse and convert to `--setenv` | Wrapper needed                      |
| `sudo -n` (non-interactive) | `--no-ask-password`                  | Different flag                      |

#### Problem 5: Performance overhead

Every `sudo` call becomes: D-Bus → polkit → systemd → new cgroup → transient service → exec. Slower than setuid, and if polkit or systemd is unhappy, you lose ALL admin access with no fallback.

### Why the symlink still doesn't work

Even with the wrapper + polkit rule + `--pipe`, the fundamental problem remains:

1. **Scripts that check exit codes** get different error codes from run0
2. **Transient service overhead** on every `sudo` call (systemd creates a `.service` unit each time)
3. **No fallback** — if polkit/D-Bus/systemd is broken, you're locked out entirely
4. **The moment you're writing a sudo parser in bash** to translate flags, you've reinvented sudo badly

### run0 verdict

`run0` is the correct long-term architectural answer — no setuid, polkit-native, systemd-integrated. But today it:

- Has no NixOS module
- Breaks embedded terminals (PTY allocation)
- Requires polkit rules for passwordless operation
- Has incompatible env handling
- Would need a complex wrapper script to emulate sudo's CLI

Wait for proper NixOS module support. The symlink idea is a recipe for getting locked out.

---

## NixOS Internal Dependency on `sudo`

**This is the strongest argument against removal.** NixOS modules hardcode `/run/wrappers/bin/sudo` in ~25+ service wrappers. The standard pattern:

```bash
# Generated by NixOS modules for CLI wrappers
sudo='exec /run/wrappers/bin/sudo -u <service_user> --preserve-env=...'
$sudo <package>/bin/<command> "$@"
```

### Affected NixOS modules (in nixpkgs)

| Module                                | Usage                                                           |
| ------------------------------------- | --------------------------------------------------------------- |
| `services.web-apps.nextcloud`         | `sudo -u nextcloud` CLI wrapper                                 |
| `services.web-apps.mastodon`          | `sudo -u mastodon` for `tootctl`                                |
| `services.web-apps.snipe-it`          | `sudo -u <user>` for `artisan`                                  |
| `services.web-apps.pixelfed`          | `sudo -u <user>` for `artisan`                                  |
| `services.web-apps.monica`            | `sudo -u <user>` for CLI                                        |
| `services.web-apps.agorakit`          | `sudo -u <user>` for `artisan`                                  |
| `services.web-apps.pretix`            | `sudo -u pretix` with `--preserve-env`                          |
| `services.web-apps.pretalx`           | `sudo -u pretalx` with `--preserve-env`                         |
| `services.web-apps.healthchecks`      | `sudo -u healthchecks -E`                                       |
| `services.web-apps.gancio`            | `sudo -u gancio`                                                |
| `services.web-apps.mediawiki`         | `sudo -u <user> --`                                             |
| `services.web-apps.mediagoblin`       | `sudo -u mediagoblin`                                           |
| `services.web-apps.glitchtip`         | `sudo -E -u glitchtip`                                          |
| `services.web-apps.froide-govplan`    | `sudo -u govplan`                                               |
| `services.web-apps.pdfding`           | `sudo -E -u pdfding`                                            |
| `services.misc.paperless`             | `sudo -u paperless -E`                                          |
| `services.misc.omnom`                 | `sudo -u omnom`                                                 |
| `services.mail.mailman`               | `sudo -u mailman`                                               |
| `services.monitoring.librenms`        | `sudo -u librenms` (artisan + lnms)                             |
| `services.security.crowdsec`          | `sudo -u crowdsec` for `cscli`                                  |
| `services.networking.pihole-ftl`      | `sudo -u pihole`                                                |
| `services.networking.kresd`           | `sudo -u knot-resolver`                                         |
| `services.web-apps.libretranslate`    | `sudo -u libretranslate --preserve-env`                         |
| `services.web-apps.akkoma`            | `sudo -u akkoma` for `pleroma_ctl`                              |
| `services.development.zammad`         | `sudo -u zammad`                                                |
| `services.backup.borgmatic`           | `${pkgs.sudo}/bin/sudo -u <user>` (references package directly) |
| `services.home-automation.homebridge` | `sudo -n systemctl restart homebridge`                          |

These are **not optional** — they're the standard NixOS pattern for privilege-dropping CLI wrappers. Even if you don't use these services today, enabling any of them with `sudo` removed will silently break.

### The existing `security/run0.nix` compatibility shim

NixOS already has a module (`security/run0.nix`) that creates a shell script named `sudo` that does `exec run0 "$@"`. This exists specifically to ease run0 adoption. However, it's a naive passthrough — it doesn't translate `--preserve-env`, `-E`, `-u` flags, so the service wrappers above would still break.

---

## Migration Effort Estimate

### doas

| Step                                                    | Effort | Risk   |
| ------------------------------------------------------- | ------ | ------ |
| Flip NixOS module options                               | 5 min  | Zero   |
| Audit justfile for `sudo` → `doas`                      | 15 min | Low    |
| Audit scripts/ for `sudo`                               | 15 min | Low    |
| Audit modules/ for `sudo` (gitea-repos.nix)             | 10 min | Medium |
| Test every `just` command works with `doas`             | 30 min | Medium |
| Check for hardcoded `sudo` in NixOS module dependencies | 30 min | Medium |
| Verify no tools break without `sudo` binary             | 1 hour | High   |

**Total: ~2.5 hours of careful work + testing**

### run0 (via sudo symlink + wrapper)

| Step                                            | Effort   | Risk      |
| ----------------------------------------------- | -------- | --------- |
| Write and test polkit rule                      | 30 min   | Medium    |
| Write sudo-compat wrapper script                | 2 hours  | High      |
| Test every `just` command through wrapper       | 1 hour   | High      |
| Test embedded terminal (Crush) compatibility    | 30 min   | High      |
| Test SSH session compatibility                  | 30 min   | High      |
| Test systemd service scripts (gitea-repos)      | 30 min   | High      |
| Handle edge cases (env vars, exit codes, flags) | 2+ hours | Very High |
| Add emergency fallback (keep sudo installed)    | 30 min   | Medium    |

**Total: ~7+ hours, and the result is still fragile**

---

## Final Verdict

**Keep `sudo`.** Here's why:

1. **Threat model doesn't benefit.** Passwordless wheel means the primary doas advantage (simpler auth attack surface) is irrelevant. The remaining win (smaller setuid binary) is real but marginal.

2. **52 references to `sudo`** across production scripts, the justfile, and service modules. Every one needs auditing and testing. The blast radius of a missed reference is "command silently fails when you need it most."

3. **Tool compatibility.** The NixOS ecosystem, polkit, and desktop environments expect `sudo`. Removing it risks silent breakage in edge cases you won't discover until something goes wrong at 2 AM.

4. **run0 is the real answer** — but not today. When it gets a proper NixOS module and the embedded terminal PTY issue is handled, it'll be the correct migration target. doas is a stepping stone, not a destination.

5. **The "bloated" argument is philosophical, not practical.** sudo's complexity is real, but on NixOS you get a sandboxed, properly configured sudo with a minimal config. The attack surface that matters (your `sudoers` config) is already as simple as it gets: one line, passwordless wheel.

6. **A sudo→run0 symlink would be the worst of both worlds** — all the fragility of run0 with none of its architectural benefits, hidden behind a compatibility shim that will break in surprising ways.

**If you still want to switch** for philosophical reasons: doas is feasible (2.5 hours), run0 via wrapper is not (7+ hours, still fragile). But know that either choice is a purity play, not a security play, in this specific configuration.

---

**TL;DR**: doas is better software. run0 is better architecture. But with passwordless wheel, the security delta is negligible, and the migration cost + ecosystem compatibility risk isn't worth it today. Revisit when run0 gets NixOS module support.
