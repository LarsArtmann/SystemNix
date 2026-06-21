# Quickshell + Nix: Real-World Implementations on GitHub

A field study of how the best Nix dotfiles and shell projects package, consume, and deploy Quickshell. Researched 2026-06-21 against live code.

Companion to `quickshell-nixos-vision.html`.

---

## TL;DR — Seven Patterns Found

| # | Pattern | Complexity | Example repo | When to use |
|---|---------|-----------|--------------|-------------|
| 1 | **Upstream-module consumer** | Lowest | `EdenEast/nyx` + DankMaterialShell | Adopting a shell that ships its own HM module |
| 2 | **Dotfiles wrapper** | Low | `soymou/illogical-flake` wrapping end-4 | Installing a shell that has no Nix story |
| 3 | **Pure wrapper** | Low | `noctalia-shell` (now in nixpkgs!) | Packaging a QML-only shell config |
| 4 | **HM module author** | Medium | `caelestia-dots/shell` | Building a shell to distribute to others |
| 5 | **CMake plugin build** | High | `caelestia-dots/shell` | Shell needs a custom C++ QML plugin |
| 6 | **withModules extension** | Low | `liixini/skwd-wall` | Adding Qt modules (qtsvg, qt5compat) to Quickshell |
| 7 | **Single-purpose app** | Low | `Ronin-CK/HyprQuickFrame` | One Quickshell tool, not a full shell |

**For SystemNix: Pattern 1 (consumer) → then Pattern 4 (author).** Start by consuming DankMaterialShell's upstream module like EdenEast/nyx does. Graduate to your own HM module once the SystemNix-native widgets are ready.

---

## Universal Rules (every repo follows these)

### 1. `inputs.nixpkgs.follows` is MANDATORY

Every single repo. No exceptions. Mismatched Qt versions between Quickshell and your system cause runtime crashes.

```nix
quickshell = {
  url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
  inputs.nixpkgs.follows = "nixpkgs";  # THIS LINE IS NON-NEGOTIABLE
};
```

### 2. Feature overrides trim for Wayland-only

Wayland-only setups universally disable X11 and i3 support:

```nix
quickshell = inputs.quickshell.packages.${system}.default.override {
  withX11 = false;
  withI3 = false;  # niri doesn't use i3 IPC anyway
};
```

### 3. The `-p` config-path flag

Every wrapper passes `-p $out/share/<shell-name>` to tell `qs` where the QML lives:

```nix
--add-flags "-p $out/share/noctalia-shell"
```

### 4. Runtime deps are wrapped into PATH

Shells need `brightnessctl`, `wl-clipboard`, `cliphist`, `ddcutil`, `networkmanager`, `swappy`, etc. at runtime. They go into the wrapper:

```nix
--prefix PATH : ${lib.makeBinPath runtimeDeps}
```

---

## Pattern 1: Upstream-Module Consumer (RECOMMENDED FOR SYSTEMNIX)

**The cleanest pattern.** When a shell ships its own home-manager module, you just import it and flip toggles. Zero hand-written services.

### Source: `EdenEast/nyx` (niri + DankMaterialShell)

This is the closest existing analog to what SystemNix wants: a niri dotfiles repo consuming a mature Quickshell shell.

**flake.nix input:**
```nix
dankMaterialShell = {
  url = "github:AvengeMedia/DankMaterialShell/stable";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Note: `quickshell` is NOT a direct input — it enters transitively through DMS's own flake.lock. This reduces your input count.

**Consumer module** (`modules/home/services/dms/default.nix`):
```nix
{
  config, inputs, lib, ...
}: {
  imports = [
    inputs.dankMaterialShell.homeModules.dank-material-shell
  ];

  options.my.home.services.dms = {
    enable = lib.mkEnableOption "Dank material quick shell";
  };

  config = lib.mkIf config.my.home.services.dms.enable {
    programs.dank-material-shell = {
      enable = true;
      enableSystemMonitoring = true;   # System widgets (dgop)
      enableDynamicTheming = true;     # Wallpaper theming (matugen)
      enableAudioWavelength = true;    # Audio visualizer (cava)
      enableCalendarEvents = false;    # khal — disabled
    };
  };
}
```

**Gating on niri** (`modules/home/desktop/niri/default.nix`):
```nix
config = lib.mkIf config.my.home.desktop.niri.enable {
  # ... niri config ...
  my.home.services.dms.enable = true;  # DMS only on niri machines
};
```

**Key insight:** No `home.packages`, no hand-written `systemd.user.services`. The upstream module handles everything. This is the lowest-effort, lowest-maintenance path.

### What DankMaterialShell provides out of the box

- Notifications, app launcher, wallpaper customization
- Auto-theming via matugen (GTK + Qt)
- 20+ customizable widgets
- Process monitoring (Go-based `dgop`)
- Notification center, clipboard history, dock, control center
- Lock screen
- Comprehensive plugin system (community plugins exist)
- Catppuccin theme support (confirmed in user configs)

---

## Pattern 2: Dotfiles Wrapper

**For shells with no Nix story.** Fetches the dotfiles as a non-flake input and writes a home-module that installs them alongside Quickshell.

### Source: `soymou/illogical-flake` (wrapping end-4/dots-hyprland)

end-4's dots-hyprland is the most visually acclaimed Quickshell config but ships as Arch-focused dotfiles, not a Nix flake. illogical-flake bridges this:

**flake.nix:**
```nix
inputs = {
  quickshell = {
    url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  nur = {
    url = "github:nix-community/NUR";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  dotfiles = {
    url = "git+https://github.com/end-4/dots-hyprland?submodules=1";
    flake = false;  # fetched as plain source, not a flake
  };
};

outputs = inputs@{ self, nixpkgs, quickshell, nur, dotfiles, ... }:
  let
    flakeInputs = { inherit quickshell nur dotfiles; };
  in {
    homeManagerModules.default = { config, lib, pkgs, ... }: (import ./home-module.nix) {
      inherit config lib pkgs;
      inputs = flakeInputs;
    };
  };
```

The `home-module.nix` then imports sub-modules for fonts, packages, Qt config, environment, and dotfiles installation. The dotfiles are installed via `xdg.configFile` or `home.file`.

**When to use this:** You want end-4's exact visual setup but need Nix packaging. Higher maintenance than Pattern 1 because you're responsible for adapting the dotfiles to Nix.

---

## Pattern 3: Pure Wrapper (QML-only, no compilation)

**The simplest packaging pattern.** For shells that are pure QML (no C++ plugins). No compiler needed — `stdenvNoCC`.

### Source: `noctalia-shell` — NOW IN NIXPKGS

noctalia-shell was upstreamed to nixpkgs at `pkgs/by-name/no/noctalia-shell/package.nix`. This is the reference implementation for packaging a QML-only Quickshell shell:

```nix
{
  fetchFromGitHub, lib, nix-update-script, stdenvNoCC,
  qt6, noctalia-qs,  # noctalia-qs is a forked quickshell build
  bluez, brightnessctl, cliphist, ddcutil, wlsunset, wl-clipboard, ...
}:

stdenvNoCC.mkDerivation {
  pname = "noctalia-shell";
  inherit version src;

  nativeBuildInputs = [ qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtmultimedia ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/noctalia-shell $out/bin
    ln -s ${noctalia-qs}/bin/qs $out/bin/noctalia-shell

    cp -R Assets Commons Helpers Modules Services Widgets shell.qml \
      $out/share/noctalia-shell
    rm -R $out/share/noctalia-shell/Assets/Screenshots
    runHook postInstall
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath runtimeDeps}
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share
      --add-flags "-p $out/share/noctalia-shell"
      ${lib.optionalString calendarSupport
        "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
    )
  '';

  passthru.updateScript = nix-update-script { };
}
```

**Key details:**
- `stdenvNoCC` — no C compiler needed, just copying files
- `qt6.wrapQtAppsHook` + `preFixup qtWrapperArgs` — the Nix-native way to wrap Qt apps with env vars (better than raw `makeWrapper`)
- `ln -s ${quickshell}/bin/qs` — the binary is just a symlink to `qs`
- `-p $out/share/noctalia-shell` — tells `qs` where to find `shell.qml`
- `GI_TYPELIB_PATH` — only needed if using GObject introspection (e.g., for calendar via evolution-data-server)
- `nix-update-script` — auto-updates the package version in nixpkgs

**For SystemNix:** If you write a custom QML shell, this is your packaging pattern. Put it in `pkgs/quickshell-shell/` or vendor it in the flake.

---

## Pattern 4: HM Module Author

**When you're building a shell to distribute.** The HM module manages the systemd user service and config generation.

### Source: `caelestia-dots/shell/nix/hm-module.nix`

The canonical HM module pattern for a Quickshell shell:

```nix
self: { config, pkgs, lib, ... }: let
  inherit (pkgs.stdenv.hostPlatform) system;
  cfg = config.programs.caelestia;
in {
  options.programs.caelestia = {
    enable = mkEnableOption "Enable Caelestia shell";
    package = mkOption {
      type = types.package;
      default = self.packages.${system}.with-cli;
    };
    systemd = {
      enable = mkOption { type = types.bool; default = true; };
      target = mkOption {
        type = types.str;
        default = config.wayland.systemd.target;  # from niri-flake/HM
      };
      environment = mkOption {
        type = types.listOf types.str;
        default = [];
      };
    };
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = {};
    };
  };

  config = let shell = cfg.package; in lib.mkIf cfg.enable {
    systemd.user.services.caelestia = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Caelestia Shell Service";
        After = [cfg.systemd.target];
        PartOf = [cfg.systemd.target];
        X-Restart-Triggers = lib.mkIf (cfg.settings != {}) [
          "${config.xdg.configFile."caelestia/shell.json".source}"
        ];
      };
      Service = {
        Type = "exec";
        ExecStart = "${shell}/bin/caelestia-shell";
        Restart = "on-failure";
        RestartSec = "5s";
        Environment = ["QT_QPA_PLATFORM=wayland"] ++ cfg.systemd.environment;
        Slice = "session.slice";
      };
      Install = { WantedBy = [cfg.systemd.target]; };
    };
  };
}
```

**Critical details:**
- `config.wayland.systemd.target` — this comes from niri-flake/HM and resolves to `niri.service` (or `graphical-session.target`). This is how you bind the shell to the compositor lifecycle.
- `Type = "exec"` — not `simple`, not `notify`. The `exec` type is correct for Quickshell.
- `X-Restart-Triggers` — restarts the shell when the config file changes! This gives you `home-manager switch` → shell restarts with new config. Important for the iteration loop.
- `Slice = "session.slice"` — resource isolation.
- `Restart = "on-failure"` with `RestartSec = "5s"` — survives crashes.
- `QT_QPA_PLATFORM=wayland` — forces Wayland backend.

---

## Pattern 5: CMake Plugin Build

**When your shell needs a C++ QML plugin.** Caelestia builds three CMake artifacts: a QML plugin (C++ types exposed to QML), extras (shared libs), and m3shapes (Material You shapes).

### Source: `caelestia-dots/shell/nix/default.nix`

```nix
stdenv.mkDerivation {
  pname = "caelestia-shell";
  nativeBuildInputs = [cmake ninja makeWrapper qt6.wrapQtAppsHook];
  buildInputs = [quickshell extras plugin m3shapesModule xkeyboard-config qt6.qtbase];
  propagatedBuildInputs = runtimeDeps;

  cmakeFlags = [
    (lib.cmakeFeature "ENABLE_MODULES" "shell")
    (lib.cmakeFeature "INSTALL_QSCONFDIR" "${placeholder "out"}/share/caelestia-shell")
  ];

  prePatch = ''
    substituteInPlace assets/pam.d/fprint \
      --replace-fail pam_fprintd.so /run/current-system/sw/lib/security/pam_fprintd.so
  '';

  postInstall = ''
    makeWrapper ${quickshell}/bin/qs $out/bin/caelestia-shell \
      --prefix PATH : "${lib.makeBinPath runtimeDeps}" \
      --set FONTCONFIG_FILE "${fontconfig}" \
      --set CAELESTIA_LIB_DIR ${extras}/lib \
      --add-flags "-p $out/share/caelestia-shell"
  '';
}
```

**Notable tricks:**
- `substituteInPlace` for PAM — patches `pam_fprintd.so` to point at the NixOS system path. If SystemNix builds a lock screen with fingerprint auth, this pattern is needed.
- `makeFontsConf` — creates a fontconfig file bundling the shell's fonts (material-symbols, rubik, nerd-fonts). Keeps font discovery deterministic.
- `passthru = { inherit plugin extras; }` — exposes sub-derivations for the devShell.
- `lib.fileset.toSource` with `lib.fileset.union` — precise source filtering so changing one file doesn't invalidate the whole build.

**For SystemNix:** Probably overkill unless you write custom C++ QML types. Start with Pattern 3 (pure QML).

---

## Pattern 6: withModules Extension

**Adding Qt modules to Quickshell.** Quickshell's `.withModules` function extends the binary with extra Qt QML modules.

### Source: `liixini/skwd-wall` (wallpaper selector with Matugen)

```nix
let
  qsPkgs = quickshell.inputs.nixpkgs.legacyPackages.${system};

  qtModules = with qsPkgs.qt6; [
    qtimageformats   # WEBP, HEIF support
    qtmultimedia     # video playback
    qtsvg            # SVG icons
    qt5compat        # gaussian blur (Qt4 compatibility APIs)
    qtwayland        # Wayland platform plugin
  ];

  quickshellWithModules = quickshell.packages.${system}.default.withModules qtModules;

  qtPluginPath = pkgs.lib.makeSearchPath "lib/qt-6/plugins" qtModules;
in
# ... then use quickshellWithModules in makeWrapper
```

**Key insight:** The Qt modules must come from quickshell's nixpkgs (`qsPkgs`), not your own — to avoid ABI mismatches. This is why `quickshell.inputs.nixpkgs` must follow yours.

---

## Pattern 7: Single-Purpose Quickshell App

Quickshell isn't just for full shells. It's great for individual tools.

### Source: `Ronin-CK/HyprQuickFrame` (screenshot utility)

```nix
runtimeDeps = pkgs: with pkgs; [
  quickshell grim imagemagick wl-clipboard satty libnotify
];

packages = forAllSystems (pkgs: {
  default = pkgs.stdenv.mkDerivation {
    pname = "hyprquickframe";
    src = pkgs.lib.cleanSourceWith {
      src = ./.;
      filter = path: type:
        !builtins.any (suffix: lib.hasSuffix suffix (baseNameOf path))
        [".git" "flake.nix" "flake.lock" "README.md" "LICENSE"];
    };
    nativeBuildInputs = [pkgs.makeWrapper];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/hyprquickframe $out/bin
      cp -r . $out/share/hyprquickframe/
      makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/hyprquickframe \
        --prefix PATH : ${pkgs.lib.makeBinPath (runtimeDeps pkgs)} \
        --add-flags "-c $out/share/hyprquickframe -n"
  };
});
```

**For SystemNix:** Could build a Quickshell-based screenshot tool, color picker, or clipboard preview as a standalone package without committing to a full shell.

---

## Ecosystem Map

### Shells (Quickshell configs)

| Shell | Repo | Nix story | Compositor | Maturity |
|-------|------|-----------|------------|----------|
| **Caelestia** | `caelestia-dots/shell` | Own flake + HM module + CMake | Hyprland | High (v1.0.0) |
| **Illogical-Impulse** (end-4) | `end-4/dots-hyprland` | Via `illogical-flake` wrapper | Hyprland | Highest (most cloned) |
| **DankMaterialShell** | `AvengeMedia/DankMaterialShell` | Own flake + HM module + Go core | Hyprland + Niri | High (v1.4.4, Fedora RPM) |
| **noctalia-shell** | `noctalia-dev/noctalia-shell` | **In nixpkgs!** | Niri-first | Medium-High |
| **iNiR** | `snowarch/iNiR` | Unknown (no flake found) | Niri-native | Medium |
| **blxshell** | `binarylinuxx/dots` | Own flake | Hyprland | Medium |
| **Zephyr** | `flickowoa/zephyr` | Unknown | Hyprland | Medium |

### Tools (single-purpose Quickshell apps)

| Tool | Repo | What it does |
|------|------|-------------|
| **HyprQuickFrame** | `Ronin-CK/HyprQuickFrame` | Screenshot annotation |
| **skwd-wall** | `liixini/skwd-wall` | Wallpaper selector with Matugen |

### Niri IPC integration layer

The `triad` project (greenm01/triad) defines a `niri-compat #true` IPC facade that Noctalia, DankMaterialShell, and Waylee all consume. This is emerging as a standardization layer for Quickshell shells that want niri workspace/window data. Worth watching.

---

## Recommendation for SystemNix

### Phase 1: Consume (Pattern 1)

```nix
# flake.nix
dankMaterialShell = {
  url = "github:AvengeMedia/DankMaterialShell/stable";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# modules/nixos/desktop/quickshell.nix (HM module)
{ config, inputs, lib, ... }: {
  imports = [ inputs.dankMaterialShell.homeModules.dank-material-shell ];

  options.programs.systemnix-shell = { ... };

  config = lib.mkIf cfg.enable {
    programs.dank-material-shell = {
      enable = true;
      enableSystemMonitoring = true;
      enableDynamicTheming = true;
    };
  };
}
```

### Phase 2: Graduate to custom (Pattern 3 + 4)

When the SystemNix-native widgets (Ollama, DNS stats, Taskchampion) are ready, package your own QML config using the noctalia pattern (stdenvNoCC + wrapQtAppsHook) and expose it via your own HM module (caelestia pattern).

### Corrections to the vision report

- DankMaterialShell is at `github:AvengeMedia/DankMaterialShell` (stable branch), NOT `DankModOS`
- noctalia-shell is now in nixpkgs — no flake input needed for it
- Quickshell itself is also in nixpkgs as `pkgs.quickshell`
- `config.wayland.systemd.target` (from niri-flake) is the correct systemd binding — not `graphical-session.target`
