# Improvement Ideas for SystemNix

**Date:** 2026-03-31

## Desktop & Niri

1. **Add swaylock HM module config** — referenced in wlogout but not configured (no Catppuccin theme)
2. **Add swayidle for Niri** — hypridle was removed but no idle daemon (dim/lock/suspend) replaces it
3. **Add wallpaper rotation for Niri** — the animated wallpaper module was removed, no cycling timer now
4. **Extract wallpaper path to a variable** — hardcoded in 2 places in niri-wrapped.nix
5. **Add Mod+Shift+W / Mod+Ctrl+W** — wallpaper next/prev keybinds (Hyprland had them, Niri doesn't)
6. **Configure dunst startup in Niri** — no exec-once for dunst in niri-wrapped.nix spawn-at-startup
7. **Remove sway from multi-wm.nix** — was a "backup WM for Hyprland", no longer needed
8. **Consolidate cliphist/wl-clipboard** — dunst, waybar, and hyprland all referenced them; verify niri works

## Hygiene & Cleanup

9. **Remove `regreet.css`** — display-manager switched to SDDM, regreet.css is orphaned
10. **Fix repeated `services` keys in configuration.nix** — already fixed once, verify it stays clean
11. **Remove swaybg from multi-wm.nix** — swww handles wallpapers, swaybg is unused
12. **Clean up comment references** — various files still mention "Hyprland" in comments (amd-gpu, fonts, etc.) — already done, verify
13. **Audit unused packages** — ghostty, foot both installed alongside kitty; pick primary terminal
14. **Remove duplicate terminal emulators** — kitty + ghostty + foot all installed, consolidate

## Nix & Build

15. **Add Just recipe for Niri reload** — `just reload` or similar for niri msg action reload-config
16. **Consolidate flake inputs** — multiple inputs may be outdated or unused after Hyprland removal
17. **Add build cache for Niri** — no cachix or binary cache for niri packages
18. **Automate flake updates** — scheduled tasks exist for crush but not `nix flake update`
19. **Add CI for nix flake check** — GitHub Actions only checks, could also build

## Services & Infra

20. **Add DNS-over-HTTPS** — unbound configured but no DoH upstream
21. **Consolidate monitoring** — Netdata, Prometheus, Grafana, ntopng all installed; pick 1-2
22. **Add Immich ML acceleration** — AMD NPU available but not configured for Immich
23. **Add git push reminder hook** — currently 3 commits ahead of origin, no reminder

## Security & Workflow

24. **Configure swaylock properly** — ensure it uses PAM and has a nice theme
25. **Add pre-push hook** — warn when >3 commits ahead of origin
