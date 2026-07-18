# Chromium Extensions Configuration Guide

This guide documents how YouTube Shorts blocker extensions are configured via Nix, with support for both macOS (nix-darwin) and NixOS.

## Overview

The configuration manages browser extensions through two approaches:

1. **Home Manager** (preferred): Declarative extension management for Chromium-based browsers
2. **System Policies**: Enterprise policy-based management for Chrome/Chromium

## Extension: YouTube Shorts Blocker

| Property             | Value                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------- |
| **Name**             | Shorts Blocker by Umut Seven                                                             |
| **Extension ID**     | `ckagfhpboagdopichicnebandlofghbc`                                                       |
| **Repository**       | https://github.com/umutseven92/shorts-blocker                                            |
| **Chrome Web Store** | https://chromewebstore.google.com/detail/shorts-blocker/ckagfhpboagdopichicnebandlofghbc |
| **License**          | Open source                                                                              |
| **Maintenance**      | Actively maintained (10,000+ users, 4.5/5 rating)                                        |

### What It Does

- Hides YouTube Shorts from the homepage
- Removes Shorts from the subscriptions page
- Blocks Shorts from search results
- Uses CSS to hide Shorts-related DOM elements
- No data collection, no ads, no tracking

## Configuration Structure

### Common Configuration

**File**: `platforms/common/programs/chromium.nix`

Configures Brave browser with declarative extension management via Home Manager:

```nix
programs.chromium = {
  enable = true;
  package = pkgs.brave; # Extension management works best with Brave
  extensions = [
    { id = "ckagfhpboagdopichicnebandlofghbc"; } # YouTube Shorts Blocker
  ];
};
```

### macOS Configuration

**File**: `platforms/darwin/programs/chrome.nix`

Provides Chrome policy configuration and a helper script:

```bash
# Apply Chrome policies (requires sudo)
sudo chrome-apply-policies
```

This creates `/Library/Application Support/Google/Chrome/policies/managed/extensions.json` with enterprise policies to force-install the extension.

### NixOS Configuration

**File**: `platforms/nixos/programs/chrome.nix`

Uses the NixOS `programs.chromium` module for full enterprise policy management:

```nix
programs.chromium = {
  enable = true;
  extensions = [ "ckagfhpboagdopichicnebandlofghbc;https://clients2.google.com/service/update2/crx" ];
  extraOpts.ExtensionSettings = {
    "ckagfhpboagdopichicnebandlofghbc" = {
      installation_mode = "force_installed";
      toolbar_pin = "force_pinned";
    };
  };
};
```

## Helium Browser Extension Support

### Current Status

**Helium Browser** is a privacy-focused Chromium fork with the following extension capabilities:

| Feature                       | Support          | Notes                                         |
| ----------------------------- | ---------------- | --------------------------------------------- |
| Chrome Web Store              | ✅ Yes           | All extensions supported                      |
| Manifest V2                   | ✅ Yes           | Will maintain MV2 support as long as possible |
| Manifest V3                   | ✅ Yes           | Fully supported                               |
| uBlock Origin                 | ✅ Pre-installed | Custom Helium fork included                   |
| Extension Declarative Install | ⚠️ Manual        | No native Nix module available                |

### Installing Extensions in Helium

Since Helium is not in nixpkgs and uses a custom flake, you need to install extensions manually:

1. Open Helium browser
2. Navigate to `chrome://extensions/`
3. Enable "Developer mode" (toggle in top right)
4. Click "Load unpacked" to load local extensions, OR
5. Visit the Chrome Web Store to install directly:
   - Go to: https://chromewebstore.google.com/detail/shorts-blocker/ckagfhpboagdopichicnebandlofghbc
   - Click "Add to Chrome"

### Alternative: Policy-Based Installation for Helium

Helium supports Chromium enterprise policies. You can create a policy file:

**macOS**:

```bash
sudo mkdir -p "/Library/Application Support/Helium/policies/managed"
sudo cp /etc/chrome/policies/managed/extensions.json "/Library/Application Support/Helium/policies/managed/"
```

**NixOS**:

```nix
environment.etc."chromium/policies/managed/extensions.json".text = builtins.toJSON {
  ExtensionInstallForcelist = [
    "ckagfhpboagdopichicnebandlofghbc;https://clients2.google.com/service/update2/crx"
  ];
};
```

## Extension Management Approaches Compared

| Approach        | Works With                          | Pros                                            | Cons                                   |
| --------------- | ----------------------------------- | ----------------------------------------------- | -------------------------------------- |
| Home Manager    | Brave, Chromium, ungoogled-chromium | Native Nix integration, user-configurable       | Doesn't work with Google Chrome        |
| System Policies | Chrome, Chromium, Brave, Helium     | Works with all Chromium forks, enterprise-grade | Requires system-level configuration    |
| Manual Install  | All browsers                        | Simple, no configuration needed                 | Not declarative, requires manual steps |

## Alternative Extensions

If you want to try different YouTube Shorts blockers:

| Extension                             | ID                                 | Repository                                                       | Pros                        |
| ------------------------------------- | ---------------------------------- | ---------------------------------------------------------------- | --------------------------- |
| Shorts Blocker (Umut Seven)           | `ckagfhpboagdopichicnebandlofghbc` | [GitHub](https://github.com/umutseven92/shorts-blocker)          | Actively maintained, simple |
| YouTube Shorts Blocker (TaylorHo)     | `jchbbofddpgfbaheknainnhbdonkpogf` | [GitHub](https://github.com/TaylorHo/youtube-shorts-blocker)     | Multilingual, toggle button |
| Youtube Shorts Block (CarlosSanchess) | `kpcihppklbfdolkgkojhlgiblmeheihp` | [GitHub](https://github.com/CarlosSanchess/Youtube-Shorts-Block) | Multiple blocking modes     |

To switch extensions, update the ID in:

- `platforms/common/programs/chromium.nix` (Home Manager)
- `platforms/darwin/programs/chrome.nix` (Darwin policies)
- `platforms/nixos/programs/chrome.nix` (NixOS policies)

## Troubleshooting

### Extensions Not Installing

1. **Check Chrome policies**: Navigate to `chrome://policy` in your browser
2. **Verify policy file exists**:
   - macOS: `/Library/Application Support/Google/Chrome/policies/managed/extensions.json`
   - NixOS: `/etc/chromium/policies/managed/extensions.json`
3. **Restart the browser** completely
4. **Check for errors**: Look at `chrome://extensions` for any error messages

### Home Manager Extensions Not Working

- Home Manager's `programs.chromium.extensions` only works with Chromium-based browsers (Brave, ungoogled-chromium), NOT Google Chrome
- Google Chrome uses a different extension installation mechanism that requires enterprise policies

### Policy Conflicts

If you use both Home Manager and system policies, ensure they don't conflict:

- Home Manager installs extensions to `~/.config/chromium/External Extensions/`
- System policies install via Chrome's policy system
- These can coexist, but the same extension shouldn't be defined in both

## References

- [Home Manager Chromium Module](https://nix-community.github.io/home-manager/options.xhtml#opt-programs.chromium.enable)
- [NixOS Chrome Policies](https://nixos.wiki/wiki/Chromium)
- [Chrome Enterprise Policy Documentation](https://chromeenterprise.google/policies/)
- [Helium Browser Documentation](https://github.com/imputnet/helium)
