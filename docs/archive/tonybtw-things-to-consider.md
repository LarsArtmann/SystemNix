# Things to Consider from tonybtw.com

> Source: [https://www.tonybtw.com/](https://www.tonybtw.com/) — reviewed every page (23 content pages) on 2026-05-06.

---

## Creator Profile

- **Name:** Tony (`@tony-btw` on YouTube, `tonybanters` on GitHub)
- **Tagline:** "Creating Quick and Painless Linux Tutorials"
- **Mission:** Encourage people to learn the CLI, install Linux distros, window managers, and text editors to grow as developers and computer enthusiasts
- **Primary distro:** Arch Linux ("I use arch, btw"), also demonstrates on NixOS, Gentoo, FreeBSD, and LFS
- **Support channels:** YouTube subscriptions, PayPal/Square donations, Ko-Fi
- **Discord community:** `https://discord.gg/nXZwDb8HB5`

_Sources: [/](https://www.tonybtw.com/), [/support/](https://www.tonybtw.com/support/)_

---

## Consistent Technical Preferences

These patterns appear across nearly every tutorial and community article:

| Category              | Preference                                                  | Source                                                                                                                                                               |
| --------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Theme                 | Tokyo Night (all apps)                                      | Every tutorial with theming                                                                                                                                          |
| Font                  | JetBrainsMono Nerd Font                                     | Every tutorial                                                                                                                                                       |
| Terminal (X11)        | `st`                                                        | [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/)                                                                                                        |
| Terminal (Wayland)    | `foot`                                                      | [/tutorial/hyprland/](https://www.tonybtw.com/tutorial/hyprland/), [/tutorial/dwl/](https://www.tonybtw.com/tutorial/dwl/)                                           |
| Terminal (alt)        | `alacritty`                                                 | [/tutorial/niri/](https://www.tonybtw.com/tutorial/niri/)                                                                                                            |
| Display manager       | `ly` (minimal TUI)                                          | [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/), [/tutorial/suckless-nixos/](https://www.tonybtw.com/tutorial/suckless-nixos/) |
| Editor (daily)        | Neovim                                                      | [/tutorial/neovim/](https://www.tonybtw.com/tutorial/neovim/)                                                                                                        |
| Editor (servers/ISOs) | Vim                                                         | [/tutorial/vim/](https://www.tonybtw.com/tutorial/vim/)                                                                                                              |
| App launcher          | `fuzzel` (Wayland), `rofi` (X11), `wmenu` (minimal Wayland) | Multiple tutorials                                                                                                                                                   |
| Wallpaper source      | wallhaven.cc                                                | Every tutorial with wallpaper setup                                                                                                                                  |
| Screenshots (X11)     | `maim` + `xclip`                                            | [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/), [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/)                                               |
| Screenshots (Wayland) | `grim` + `slurp` + `wl-copy`                                | [/tutorial/dwl/](https://www.tonybtw.com/tutorial/dwl/), [/tutorial/mangowc/](https://www.tonybtw.com/tutorial/mangowc/)                                             |
| Compositor (X11)      | `picom`                                                     | [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/), [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/)                                               |

---

## Tutorial Style & Philosophy

- **"Quick and painless"** is the signature format — every tutorial intro uses this phrase
- **"Slow and painful"** for LFS — self-aware humor about the contrast
  - _Source: [/tutorial/linux-from-scratch/](https://www.tonybtw.com/tutorial/linux-from-scratch/)_
- **Via negativa approach:** Tmux tutorial explicitly removes plugins rather than adding them (inspired by "Henry Misc")
  - _Source: [/tutorial/tmux/](https://www.tonybtw.com/tutorial/tmux/)_
- **Multi-distro instructions:** Almost every tutorial covers Arch, NixOS, and Gentoo
- **Video + written companion:** Every tutorial has both a YouTube video and a written article
- **Build-from-source-first:** Preference for compiling (DWM, DWL, st, dmenu, LFS) over pre-built packages
- **Honest/direct tone:** XMonad tutorial frames X11 as "honest" vs Wayland politics; irreverent humor throughout
  - _Source: [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/)_

---

## All Tutorials (13, chronologically newest first)

| #     | Title                                      | Date       | Key Topics                                                                                                                   | Source                                                                                |
| ----- | ------------------------------------------ | ---------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| 1     | Quickshell Tutorial - Build Your Own Bar   | 2025-12-03 | Qt/QML Wayland shell framework, PanelWindow, Repeater, Process, Timer, Hyprland IPC                                          | [/tutorial/quickshell/](https://www.tonybtw.com/tutorial/quickshell/)                 |
| 2     | The Last Honest X11 Window Manager: Xmonad | 2025-11-26 | Haskell WM, EZConfig, XMobar, spacing, Tokyo Night colors, ResizableTall layouts, window rules                               | [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/)                         |
| 3     | Tmux with Zero Plugins                     | 2025-11-13 | Terminal multiplexer, prefix Ctrl-a, vim-style pane nav, Alt+hjkl without prefix, Tokyo Night Moon theme, copy-mode-vi       | [/tutorial/tmux/](https://www.tonybtw.com/tutorial/tmux/)                             |
| 4     | Niri, btw                                  | 2025-11-05 | Scrollable-tiling Wayland compositor, Noctalia Shell (Quickshell-based bar), KDL config, overview mode, built-in screenshots | [/tutorial/niri/](https://www.tonybtw.com/tutorial/niri/)                             |
| 5     | Linux From Scratch                         | 2025-10-22 | Full LFS 12.4 build (chapters 1-7+), cross-toolchain, GCC 15.2.0, Glibc 2.42, chroot, SBUs                                   | [/tutorial/linux-from-scratch/](https://www.tonybtw.com/tutorial/linux-from-scratch/) |
| 6     | MangoWC Installation + Customization Guide | 2025-10-15 | Wayland compositor by DreamMaoMao, scrolling layouts, touchpad gestures, waybar, swaybg                                      | [/tutorial/mangowc/](https://www.tonybtw.com/tutorial/mangowc/)                       |
| 7     | Hyprland on NixOS (w/ UWSM)                | 2025-10-08 | Minimal ISO install, flake.nix + home.nix, UWSM session, nix-search-tv                                                       | [/tutorial/nixos-hyprland/](https://www.tonybtw.com/tutorial/nixos-hyprland/)         |
| 8     | How to Customize Vim in 2026               | 2025-10-01 | Vanilla vim, custom 6-line plugin manager (git clone wrapper), fzf, lightline, yegappan/lsp, rust-analyzer                   | [/tutorial/vim/](https://www.tonybtw.com/tutorial/vim/)                               |
| 9     | How to Install and Customize DWL           | 2025-09-22 | DWM port to Wayland, wlroots, bar patch, slstatus, swaybg, custom workspace indicators                                       | [/tutorial/dwl/](https://www.tonybtw.com/tutorial/dwl/)                               |
| 10    | Suckless Programs on NixOS                 | 2025-09-14 | DWM/dmenu/st on NixOS via overrideAttrs, devShells for suckless development, patching workflow                               | [/tutorial/suckless-nixos/](https://www.tonybtw.com/tutorial/suckless-nixos/)         |
| 11    | NixOS From Scratch (Flakes + Home Manager) | 2025-09-05 | Minimal ISO install, flakes, home-manager as NixOS module, mkOutOfStoreSymlink, modular .nix files                           | [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/) |
| 12    | Hyprland on Arch — Minimal Setup Guide     | 2025-08-24 | Fresh Arch install, waybar customization (config.jsonc + style.css), hyprpaper, wofi, Tokyo Night theme                      | [/tutorial/hyprland/](https://www.tonybtw.com/tutorial/hyprland/)                     |
| 13    | DWM on Arch — Minimal Config Tutorial      | 2025-04-27 | DWM build, config.h modification, patching (vanity gaps), dwmblocks, rofi, slock, autostart script                           | [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/)                               |
| Bonus | Neovim on Linux — Complete IDE Tutorial    | 2025-05-10 | Lazy.nvim, Telescope, Treesitter, Harpoon, nvim-lspconfig + mason, nvim-cmp + LuaSnip                                        | [/tutorial/neovim/](https://www.tonybtw.com/tutorial/neovim/)                         |

---

## Community Articles (8 total)

| Author            | Title                                 | Key Takeaways                                                                                                                                          | Source                                                                                                                |
| ----------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| NullSector-dev    | BSPWM! A seamless guide               | BSPWM + sxhkd architecture (keyboard → sxhkd → bspc → socket → bspwm), FreeBSD + Arch, bspwmrc config, sxhkdrc keybinds                                | [/community/bspwm/](https://www.tonybtw.com/community/bspwm/)                                                         |
| csode             | Emacs Beginner Guide                  | Single-file .emacs config, tsoding's rc.el package manager, gruber-darker theme, Iosevka Nerd Font, Magit, company-mode, multiple-cursors, smex        | [/community/emacs-guide/](https://www.tonybtw.com/community/emacs-guide/)                                             |
| 🐢 argos nothings | Mango WM                              | Tags vs workspaces distinction, dynamic window manager theory, comboview for multi-tag layouts, scratchpads, scrolling layouts emulating niri behavior | [/community/mango/](https://www.tonybtw.com/community/mango/)                                                         |
| NullSector-dev    | My experience with FreeBSD            | Personal essay — BSPWM + Alacritty + Vim + Doom Emacs on FreeBSD, prefers FreeBSD's cohesion over Linux fragmentation                                  | [/community/freebsd/](https://www.tonybtw.com/community/freebsd/)                                                     |
| Emzy              | Nix Package Hunting on The Big Screen | `nix-search-tv` fuzzy finder for nix packages/options, television integration, fzf integration with `writeShellApplication`                            | [/community/nix-search-tv/](https://www.tonybtw.com/community/nix-search-tv/)                                         |
| Zakky             | My Qtile Rice                         | Qtile on Gentoo, Nord theme, python-psutil widgets, qtile-extras                                                                                       | [/community/qtile/](https://www.tonybtw.com/community/qtile/)                                                         |
| Errium            | ZRAM in NixOS                         | ZRAM setup, algorithm comparison (zstd vs lz4 vs lzo vs lz4hc — recommends lz4), memoryPercent explained, priority settings                            | [/community/zram-in-nixos---download-more-ram/](https://www.tonybtw.com/community/zram-in-nixos---download-more-ram/) |
| (template)        | Example Community Article             | Submission template for contributors — markdown format, image placement in `static/img/community/<name>/`, table of contents                           | [/community/example/](https://www.tonybtw.com/community/example/)                                                     |

---

## NixOS-Specific Patterns

_Source: [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/), [/tutorial/suckless-nixos/](https://www.tonybtw.com/tutorial/suckless-nixos/), [/tutorial/nixos-hyprland/](https://www.tonybtw.com/tutorial/nixos-hyprland/)_

- **Flake structure:** `flake.nix` + `configuration.nix` + `home.nix` as the standard trio
- **Home Manager as NixOS module:** `home-manager.nixosModules.home-manager` — avoids separate `home-manager switch`
- **`inputs.nixpkgs.follows = "nixpkgs"`:** Prevents home-manager from pulling its own nixpkgs
- **`useGlobalPkgs = true; useUserPackages = true`** in home-manager config
- **`mkOutOfStoreSymlink`:** Used for live-editable dotfiles that symlink into `~/.config` instead of the Nix store
- **Modular home-manager:** Extract tools into `modules/<name>.nix` (e.g., `modules/neovim.nix`, `modules/suckless.nix`)
- **Suckless on NixOS:** `pkgs.dwm.overrideAttrs { src = ./config/dwm; }` — point to local source, patch manually, rebuild
- **DevShells for suckless:** `pkgs.mkShell` with build dependencies (pkg-config, libX11, libXft, etc.) for in-place compilation
- **nix-search-tv:** Tool for fuzzy searching nix packages from the terminal, integrated with fzf

---

## Wayland vs X11 Coverage Split

_Across all tutorials:_

**Wayland (8 tutorials):** Hyprland (×2), Niri, DWL, MangoWC, Quickshell + community articles on Mango WM, BSPWM on FreeBSD

**X11 (4 tutorials):** DWM, XMonad, Suckless on NixOS (DWM/st/dmenu), Hyprland setup mentions xwayland-satellite

**Cross-platform / editor (4 tutorials):** Vim, Neovim, Tmux, Linux From Scratch

**Trend:** ~60% Wayland emphasis, suggesting the content is oriented toward Wayland migration.

---

## Toolchain & Dependency Patterns

### X11 Stack (from DWM, XMonad tutorials)

```
xorg-server, xorg-xinit, base-devel, picom, xwallpaper, maim, xclip, slock
```

### Wayland Stack (from DWL, Hyprland, Niri tutorials)

```
wayland, wayland-protocols, wlroots, foot, wmenu/fuzzel, swaybg, grim, slurp, wl-clipboard
```

### NixOS Stack (from NixOS tutorials)

```
nixpkgs (unstable or 25.05), home-manager, flakes, nix-command
```

### Editor Stack (from Vim, Neovim tutorials)

```
ripgrep, fd, fzf, nodejs, gcc, LSP servers (lua_ls, rust-analyzer, nil)
```

---

## Notable Quotes & Humor

| Quote                                                                                                          | Context                    | Source                                                                                                                |
| -------------------------------------------------------------------------------------------------------------- | -------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| "In many respects, if Arch and Debian had a son, his name would be NixOS."                                     | NixOS from scratch intro   | [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/)                                 |
| "The Last Honest X11 Window Manager"                                                                           | XMonad title               | [/tutorial/xmonad/](https://www.tonybtw.com/tutorial/xmonad/)                                                         |
| "Niri is the anti-window manager... sometimes I forget I have 300 terminals opened all the way to the right."  | Attributed to "Argocrates" | [/tutorial/niri/](https://www.tonybtw.com/tutorial/niri/)                                                             |
| "A slow and painful tutorial on installing Linux from Scratch in 2026"                                         | LFS intro                  | [/tutorial/linux-from-scratch/](https://www.tonybtw.com/tutorial/linux-from-scratch/)                                 |
| "You can officially tell all your friends that you are a C developer."                                         | After first DWM rebuild    | [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/)                                                               |
| "Disclaimer: If you aren't tapped into this type of content, I suggest jumping over to MR.BEAST or Ms. Rachel" | Suckless on NixOS intro    | [/tutorial/suckless-nixos/](https://www.tonybtw.com/tutorial/suckless-nixos/)                                         |
| "Love your mom, and use ZRAM!"                                                                                 | ZRAM article closing       | [/community/zram-in-nixos---download-more-ram/](https://www.tonybtw.com/community/zram-in-nixos---download-more-ram/) |

---

## GitHub Repos Referenced

All under `github.com/tonybanters/`:

| Repo                 | Purpose                              | Source                                                                                |
| -------------------- | ------------------------------------ | ------------------------------------------------------------------------------------- |
| `hypr`               | Hyprland config                      | [/tutorial/nixos-hyprland/](https://www.tonybtw.com/tutorial/nixos-hyprland/)         |
| `waybay`             | Waybar config                        | [/tutorial/nixos-hyprland/](https://www.tonybtw.com/tutorial/nixos-hyprland/)         |
| `foot`               | Foot terminal config                 | [/tutorial/nixos-hyprland/](https://www.tonybtw.com/tutorial/nixos-hyprland/)         |
| `qtile`              | Qtile config                         | [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/) |
| `nvim`               | Neovim config                        | [/tutorial/nixos-from-scratch/](https://www.tonybtw.com/tutorial/nixos-from-scratch/) |
| `rofi`               | Rofi config                          | [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/)                               |
| `dwmblocks`          | DWM status bar blocks                | [/tutorial/dwm/](https://www.tonybtw.com/tutorial/dwm/)                               |
| `hyprland-btw`       | Full Hyprland rice (waybar + styles) | [/tutorial/hyprland/](https://www.tonybtw.com/tutorial/hyprland/)                     |
| `nixos-from-scratch` | NixOS install repo                   | [/tutorial/suckless-nixos/](https://www.tonybtw.com/tutorial/suckless-nixos/)         |

---

## Site Architecture Notes

- Built with **Hugo** static site generator (inferred from `/img/` paths, `/community/example/` template, and content structure)
- Content lives in `content/` directory (Hugo convention: `content/tutorial/`, `content/community/`)
- Static images at `static/img/` (community images at `static/img/community/<author>/`)
- Pagination: tutorials paginated at `/tutorial/page/2/`
- Navigation: 3 top-level sections (Support, Tutorials, Community) + Discord link
- Every page has a table of contents auto-generated from headers
- Every tutorial ends with the same CTA block (YouTube, website, Ko-Fi)
