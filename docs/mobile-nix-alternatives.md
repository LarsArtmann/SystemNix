# Nix(OS) for Phones — Alternatives & Options

A quick reference for bringing Nix-style declarative management to mobile devices.

---

## Nix-Based Solutions

### NixOnDroid (Recommended)

| | |
|---|---|
| **Platform** | Android (any phone, Termux-based) |
| **Status** | Mature, actively maintained |
| **What it is** | Nix package manager + Home Manager-style declarative config on Android |
| **OS replacement?** | No — runs alongside Android |
| **Flakes** | Yes |
| **Home Manager** | Yes |

**Best for:** Sharing Home Manager configs across macOS, NixOS, and Android. Gives you a full Nix environment with reproducible dotfiles without replacing your OS.

- Repo: [github.com/nix-community/nix-on-droid](https://github.com/nix-community/nix-on-droid)

---

### NixOS Mobile (Experimental)

| | |
|---|---|
| **Platform** | PinePhone, some other ARM devices |
| **Status** | Experimental, not daily-driver ready |
| **What it is** | Full NixOS with mobile-specific modules |
| **OS replacement?** | Yes |

**Best for:** Tinkering, development, or if you want a true NixOS phone and don't mind rough edges.

- Docs: [NixOS Wiki — Mobile](https://nixos.wiki/wiki/Mobile)

---

## Non-Nix but Declarative/Immutable Alternatives

| Project | Base | Declarative Config | OS Replacement | Status |
|---------|------|-------------------|----------------|--------|
| **GrapheneOS** | Hardened Android | No (reproducible builds) | Yes | Mature, security-focused |
| **postmarketOS** | Alpine Linux | Partial (Alpine config) | Yes | Active, many devices |
| **Ubuntu Touch** | Ubuntu | No | Yes | Community-maintained |
| **LineageOS** | Android | No | Yes | Mature, privacy-focused |

---

## Recommendation

For a SystemNix-like workflow on a phone you actually use daily: **NixOnDroid**.

- No need to flash or replace your OS
- Full Nix flakes + Home Manager integration
- Share config modules with your existing macOS/NixOS setup
- Works on any Android device

If you want a *full* NixOS phone experience: track NixOS mobile — it's improving but not there yet for daily use.
