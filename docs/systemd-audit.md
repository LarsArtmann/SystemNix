# systemd: What We Actually Use, What We Don't, and Why

_May 2026 — conversation-driven audit of systemd's role in SystemNix_

---

## systemd Size & Scope

systemd is not an init system. It's ~1.3M lines of C (~46MB of source) implementing an operating system within the operating system:

| Component  | What it does                                |
| ---------- | ------------------------------------------- |
| PID 1      | Process management (init)                   |
| journald   | Centralized logging                         |
| udevd      | Device management (`/dev`, hotplug)         |
| logind     | User sessions, seats, suspend               |
| tmpfiles   | Declarative directory/file creation at boot |
| resolved   | DNS resolver (caching, DNS-over-TLS)        |
| networkd   | Network interface management                |
| homed      | Encrypted home directories                  |
| timesyncd  | NTP client                                  |
| machined   | Container/VM registration                   |
| oomd       | Out-of-memory killer                        |
| portabled  | Portable service images                     |
| sysext     | System extension images                     |
| bootloader | EFI stub generator                          |
| repart     | Disk partitioning                           |

**Comparison:**

| Project       | Approx LoC             |
| ------------- | ---------------------- |
| systemd       | ~1.3M (C core)         |
| Linux kernel  | ~15M (x86_64 relevant) |
| GNU coreutils | ~70K                   |
| OpenRC        | ~15K                   |
| runit         | ~6K                    |
| s6            | ~30K                   |

systemd is roughly **100x larger than OpenRC** and **200x larger than runit**.

---

## Scope Creep Pattern

The recurring pattern with new systemd features:

1. Feature lands as **optional**
2. Distributions enable it **by default**
3. Other systemd components start **depending on it**
4. It becomes **effectively mandatory**

Example: the `birthDate` PR (#40954) — adding user birth dates to JSON user records. Optional today, but each new field in userdb grows the surface that homed/logind/userdb become responsible for.

The concern isn't any single feature. It's that systemd becomes the **only convergence point** for Linux system configuration, and every subsystem increases the attack surface of PID 1.

---

## What's Actually Running on evo-x2

| Component    | Status         | Can avoid?           | Notes                                                               |
| ------------ | -------------- | -------------------- | ------------------------------------------------------------------- |
| PID 1 (init) | Running        | No                   | Core — manages all services                                         |
| journald     | Running        | No                   | All service logging goes through it                                 |
| udevd        | Running        | No                   | Device hotplug, `/dev` management — emeet-pixy relies on udev rules |
| logind       | Running        | No                   | Graphical sessions, seat allocation — niri depends on it            |
| tmpfiles     | Running        | Trivially yes        | Could use `activationScripts` or `postBootCommands` instead         |
| resolved     | **Disabled** ✓ | Done                 | Would conflict with unbound on port 53                              |
| networkd     | **Not used**   | Already not using it | Using legacy `networking.interfaces` with static IP                 |
| homed        | **Not used**   | Already not using it | Using sops-nix + age for secrets                                    |
| timesyncd    | **Not used**   | Already not using it | Using `services.ntp` or chrony                                      |

### The Four You Can't Remove

init, journald, udevd, logind — these are the substrate NixOS is built on. Every `systemd.services.*`, every boot, every device event flows through them.

---

## DNS: Why systemd-resolved Is Disabled

Both resolved and unbound want port 53. Having both active causes intermittent resolution failures.

`platforms/nixos/system/networking.nix:67`:

```nix
services.resolved.enable = false;  # Disable systemd-resolved to prevent DNS conflicts
```

The DNS chain on evo-x2:

```
Applications → 127.0.0.1:53 (unbound)
                ├── 2.5M blocked domains → NXDOMAIN / block page
                ├── *.home.lan → static A records → LAN IP
                └── Everything else → root hints → full recursion from DNS root
                    (no upstream resolver — unbound walks TLD → authoritative directly)
```

Unbound provides: full recursive resolution, DNSSEC validation, 25 blocklists (2.5M+ domains), local `home.lan` zone, DNS-over-TLS upstream to Quad9. systemd-resolved would be a downgrade in every dimension except "it comes with systemd."

---

## tmpfiles: Declarative Directory Creation

`systemd-tmpfiles` creates directories with specific ownership/permissions at boot. Used in `modules/nixos/services/ai-models.nix` to create the `/data/ai/` tree:

```nix
systemd.tmpfiles.rules = [
  "d /data/ai 0755 lars users -"
  "d /data/ai/models 0755 lars users -"
  "d /data/ai/models/ollama 0755 lars users -"
  # ... 15 directories total
];
```

Format: `type path mode user group age`

Alternatives that don't use tmpfiles:

- `systemd.activationScripts` — arbitrary bash at boot
- `boot.postBootCommands` — NixOS-native bash
- `ExecStartPre` in the service that needs the directory

`systemd.tmpfiles.rules` is idiomatic NixOS — every module in nixpkgs uses it. Not worth fighting.

---

## networkd vs Legacy Networking

For evo-x2 (single interface, static IP), both are equivalent. networkd advantages only matter for complex setups.

| Aspect              | Legacy                        | networkd                          |
| ------------------- | ----------------------------- | --------------------------------- |
| Config mechanism    | Shell scripts (`ip addr add`) | `.network`/`.netdev` unit files   |
| Boot parallelism    | After networking target       | Parallel with other systemd units |
| Complex topologies  | Manual hacks                  | Native (VLANs, bonds, bridges)    |
| Hotplug reconfigure | Manual restart                | `networkctl reconfigure`          |
| Debugging           | `ip addr`, `ip route`         | `networkctl status`               |
| Status for evo-x2   | Perfectly fine                | No meaningful gain                |

**Verdict:** Single static IP = legacy is fine. Ten interfaces with VLANs and bonds = networkd is clearly better.

---

## Realistic Alternatives to systemd on NixOS

| Option                              | Viability          | Tradeoff                                                                  |
| ----------------------------------- | ------------------ | ------------------------------------------------------------------------- |
| NixOS as-is, minimize systemd       | Fully viable today | Best pragmatic choice — use dedicated tools for everything systemd offers |
| NixOS with `systemd.enable = false` | Doesn't exist      | Would require rewriting thousands of nixpkgs modules                      |
| NixBSD                              | Experimental       | FreeBSD-based Nix with its own init — very early                          |
| Guix System                         | Viable alternative | GNU Shepherd init, but different language/ecosystem                       |
| Non-Nix distro with alt init        | Viable but painful | Artix (runit/s6/OpenRC), Alpine (OpenRC), Devuan (sysvinit) — lose Nix    |

---

## The Pragmatic Stance

systemd on NixOS is not optional. The fight isn't replacing it — it's **containing** it:

- Use dedicated tools for everything systemd offers (sops-nix, unbound, Caddy)
- Disable systemd components you don't need (resolved, networkd, homed)
- Treat systemd as a service supervisor and nothing more
- Push back when systemd absorbs functionality that already has good independent implementations
- Minimize attack surface by minimizing what you hand to PID 1's ecosystem
