# SystemNix Comprehensive TODO Execution Plan

**Date:** 2026-02-28 07:00
**Total TODOs:** 493 Pending
**Task Size:** Max 12 minutes each
**Organization:** Sorted by Priority × Impact × Effort

---

## Scoring System

| Factor                 | Scale                   | Weight |
| ---------------------- | ----------------------- | ------ |
| **Priority (P)**       | 1-10 (10 = Critical)    | 40%    |
| **Impact (I)**         | 1-10 (10 = High Impact) | 30%    |
| **Customer Value (V)** | 1-10 (10 = High Value)  | 20%    |
| **Effort (E)**         | 1-10 (10 = Low Effort)  | 10%    |

**Total Score = (P×4 + I×3 + V×2 + E×1) / 10**

---

## Tier 1: CRITICAL (Score 9.0+) - Do Today

| #  | Task                                                  | Source                    | Est. Time | Score | Action                                |
| -- | ----------------------------------------------------- | ------------------------- | --------- | ----- | ------------------------------------- |
| 1  | Fix Hyprland type safety assertions path resolution   | hyprland.nix:6            | 10m       | 9.8   | Investigate flake-parts context issue |
| 2  | Re-enable assertions after path fix                   | hyprland.nix              | 5m        | 9.8   | Uncomment assertion code              |
| 3  | Verify assertions pass on rebuild                     | hyprland.nix              | 5m        | 9.8   | Run `just test`                       |
| 4  | Document assertion fix in code comments               | hyprland.nix              | 5m        | 9.5   | Add explanation                       |
| 5  | Research audit kernel module compatibility            | security-hardening.nix:11 | 12m       | 9.6   | Check NixOS issues                    |
| 6  | Test audit with current kernel                        | NixOS                     | 10m       | 9.6   | Rebuild with audit enabled            |
| 7  | Document audit disable reason if keeping disabled     | security-hardening.nix    | 8m        | 9.5   | Add comment with reason               |
| 8  | Fix Sandbox override using lib.mkForce                | darwin/nix/settings.nix:3 | 10m       | 9.6   | Replace anti-pattern                  |
| 9  | Verify sandbox settings apply                         | Darwin                    | 5m        | 9.6   | Test darwin-rebuild                   |
| 10 | Run `darwin-rebuild build --flake .#Lars-MacBook-Air` | MICRO-TASKS               | 10m       | 9.7   | Verify build                          |
| 11 | Analyze build output for errors                       | MICRO-TASKS               | 5m        | 9.7   | Check logs                            |
| 12 | Create git backup checkpoint                          | MICRO-TASKS               | 3m        | 9.7   | Tag current state                     |
| 13 | Test HM workaround removal                            | darwin/default.nix        | 8m        | 9.4   | Remove users.users.lars block         |
| 14 | Verify HM still builds without workaround             | Darwin                    | 5m        | 9.4   | Run `just test`                       |
| 15 | Document workaround removal if successful             | docs/                     | 8m        | 9.3   | Update bug report                     |

**Tier 1 Total: 15 tasks | ~117 minutes | 2.0 hours**

---

## Tier 2: HIGH (Score 8.0-8.9) - This Week

| #  | Task                                   | Source             | Est. Time | Score | Action                  |
| -- | -------------------------------------- | ------------------ | --------- | ----- | ----------------------- |
| 16 | Fish shell startup profiling           | just benchmark     | 12m       | 8.9   | Identify bottlenecks    |
| 17 | Optimize Fish initialization scripts   | fish.nix           | 12m       | 8.9   | Remove slow plugins     |
| 18 | Test Fish startup after optimization   | fish.nix           | 5m        | 8.9   | Target <200ms           |
| 19 | Document Fish optimization changes     | docs/              | 10m       | 8.8   | Add performance notes   |
| 20 | Add nh Nix management tool             | base.nix           | 8m        | 8.7   | Add to packages         |
| 21 | Configure nh integration               | home.nix           | 8m        | 8.7   | Add nh alias            |
| 22 | Test nh functionality                  | CLI                | 5m        | 8.7   | Run nh commands         |
| 23 | Research TouchID auth extensions       | pam.nix:7          | 10m       | 8.6   | Check nix-darwin docs   |
| 24 | Identify TouchID services to add       | pam.nix            | 8m        | 8.6   | List auth points        |
| 25 | Test additional TouchID configurations | Darwin             | 8m        | 8.6   | Test sudo, etc.         |
| 26 | Document TouchID security implications | docs/              | 10m       | 8.5   | Add security notes      |
| 27 | Configure git user.name                | git.nix            | 3m        | 8.5   | Add to Home Manager     |
| 28 | Configure git user.email               | git.nix            | 3m        | 8.5   | Add to Home Manager     |
| 29 | Configure git default editor           | git.nix            | 5m        | 8.5   | Set to nvim             |
| 30 | Test LaunchAgent without workaround    | launchagents.nix:5 | 10m       | 8.5   | Remove fallback         |
| 31 | Verify ActivityWatch auto-starts       | Darwin             | 5m        | 8.5   | Test LaunchAgent        |
| 32 | Create SSH config directory            | ssh.nix            | 5m        | 8.4   | Add to home.nix         |
| 33 | Configure SSH options                  | ssh.nix            | 8m        | 8.4   | Add sane defaults       |
| 34 | Test SSH configuration                 | CLI                | 5m        | 8.4   | ssh -G github.com       |
| 35 | Add jq JSON processor                  | base.nix           | 3m        | 8.4   | Already present? Verify |
| 36 | Add ripgrep search tool                | base.nix           | 3m        | 8.4   | Verify presence         |
| 37 | Add fd find tool                       | base.nix           | 3m        | 8.4   | Verify presence         |
| 38 | Add bat cat replacement                | base.nix           | 3m        | 8.4   | Add if missing          |
| 39 | Test all CLI utilities                 | CLI                | 8m        | 8.3   | Verify each works       |
| 40 | Rebuild NixOS for Bluetooth            | evo-x2             | 10m       | 8.3   | sudo nixos-rebuild      |
| 41 | Reboot for kernel modules              | evo-x2             | 5m        | 8.3   | Required reboot         |
| 42 | Pair with Nest Audio                   | Bluetooth          | 10m       | 8.3   | Use bluetoothctl        |
| 43 | Set Nest Audio as default              | audio              | 8m        | 8.3   | pactl set-default       |
| 44 | Test audio output                      | Bluetooth          | 5m        | 8.3   | Play test sound         |
| 45 | Enable auto-connect for Nest           | Bluetooth          | 8m        | 8.2   | Configure trust         |
| 46 | Test Bluetooth range                   | Bluetooth          | 5m        | 8.2   | Walk around             |
| 47 | Check A2DP profile active              | audio              | 5m        | 8.2   | pactl list cards        |
| 48 | Test with different apps               | audio              | 10m       | 8.2   | Music, videos           |
| 49 | Configure Nix cache                    | nix-settings.nix   | 8m        | 8.1   | Add substituters        |
| 50 | Configure binary cache                 | nix-settings.nix   | 8m        | 8.1   | Add trusted keys        |
| 51 | Test cache performance                 | CLI                | 5m        | 8.1   | Time rebuild            |
| 52 | Add security scanning tools            | base.nix           | 8m        | 8.1   | Add nmap, etc.          |
| 53 | Configure firewall basics              | networking.nix     | 10m       | 8.1   | Check current           |
| 54 | Add password manager                   | base.nix           | 8m        | 8.1   | Add pass or similar     |
| 55 | Test security setup                    | CLI                | 8m        | 8.1   | Run tools               |

**Tier 2 Total: 40 tasks | ~340 minutes | 5.7 hours**

---

## Tier 3: MEDIUM (Score 7.0-7.9) - Next 2 Weeks

| #   | Task                                 | Source                 | Est. Time | Score | Action            |
| --- | ------------------------------------ | ---------------------- | --------- | ----- | ----------------- |
| 56  | Add system monitoring tools          | base.nix               | 8m        | 7.9   | Add btop, etc.    |
| 57  | Configure basic alerts               | monitoring.nix         | 10m       | 7.9   | Add thresholds    |
| 58  | Test monitoring                      | CLI                    | 5m        | 7.9   | Check alerts      |
| 59  | Configure git backup strategy        | docs/                  | 10m       | 7.9   | Document strategy |
| 60  | Configure file backup                | docs/                  | 10m       | 7.9   | Add rsync script  |
| 61  | Test backup process                  | CLI                    | 8m        | 7.9   | Run backup        |
| 62  | Add formatting tools                 | base.nix               | 5m        | 7.8   | Verify treefmt    |
| 63  | Configure auto-formatting            | pre-commit             | 8m        | 7.8   | Add hooks         |
| 64  | Test formatting                      | CLI                    | 5m        | 7.8   | Run formatter     |
| 65  | Add testing tools                    | base.nix               | 8m        | 7.8   | Add bats, etc.    |
| 66  | Configure basic test runner          | tests/                 | 10m       | 7.8   | Create runner     |
| 67  | Create test template                 | tests/                 | 10m       | 7.8   | Add template      |
| 68  | Test framework                       | CLI                    | 8m        | 7.8   | Run tests         |
| 69  | Create pre-commit hook               | .githooks/             | 10m       | 7.7   | Add script        |
| 70  | Configure hook actions               | pre-commit.yaml        | 8m        | 7.7   | Define checks     |
| 71  | Add testing to hooks                 | pre-commit.yaml        | 8m        | 7.7   | Add test step     |
| 72  | Test git hooks                       | CLI                    | 5m        | 7.7   | Make test commit  |
| 73  | Configure editor environment         | environment.nix        | 8m        | 7.7   | Set EDITOR        |
| 74  | Configure dev environment            | environment.nix        | 8m        | 7.7   | Set DEV vars      |
| 75  | Test environment variables           | CLI                    | 5m        | 7.7   | Check $EDITOR     |
| 76  | Optimize system PATH                 | environment.nix        | 8m        | 7.6   | Review paths      |
| 77  | Optimize user PATH                   | home.nix               | 8m        | 7.6   | Clean paths       |
| 78  | Test PATH configuration              | CLI                    | 5m        | 7.6   | Check `which`     |
| 79  | Install Go language server           | base.nix               | 5m        | 7.6   | Verify gopls      |
| 80  | Configure LSP client                 | nvim                   | 10m       | 7.6   | Add lspconfig     |
| 81  | Install completion plugins           | nvim                   | 10m       | 7.6   | Add nvim-cmp      |
| 82  | Test editor integration              | nvim                   | 8m        | 7.6   | Test LSP          |
| 83  | Configure tmux shortcuts             | tmux.nix               | 10m       | 7.5   | Add bindings      |
| 84  | Add session management               | tmux.nix               | 8m        | 7.5   | Add resurrect     |
| 85  | Test multiplexer workflow            | CLI                    | 8m        | 7.5   | Use tmux          |
| 86  | Add productivity aliases             | shell-aliases.nix      | 8m        | 7.5   | Add shortcuts     |
| 87  | Add development aliases              | shell-aliases.nix      | 8m        | 7.5   | Add dev shortcuts |
| 88  | Add system aliases                   | shell-aliases.nix      | 8m        | 7.5   | Add sys shortcuts |
| 89  | Test all aliases                     | CLI                    | 10m       | 7.5   | Verify each       |
| 90  | Disable SDDM Wayland                 | display-manager.nix    | 8m        | 7.4   | Set wayland=false |
| 91  | Test SDDM X11 stability              | NixOS                  | 5m        | 7.4   | Verify login      |
| 92  | Document SDDM fix                    | docs/                  | 10m       | 7.4   | Add notes         |
| 93  | Research SDDM Wayland fix            | docs/                  | 12m       | 7.4   | Check issues      |
| 94  | Create README template               | docs/                  | 10m       | 7.4   | Add template      |
| 95  | Document configuration               | docs/                  | 12m       | 7.4   | Update README     |
| 96  | Generate usage examples              | docs/                  | 10m       | 7.4   | Add examples      |
| 97  | Add GPU temp module (AMD)            | waybar.nix             | 10m       | 7.3   | Add sensors       |
| 98  | Add CPU usage module                 | waybar.nix             | 10m       | 7.3   | Add per-core      |
| 99  | Add memory usage module              | waybar.nix             | 10m       | 7.3   | Add RAM           |
| 100 | Add network bandwidth module         | waybar.nix             | 10m       | 7.3   | Add up/down       |
| 101 | Add disk usage module                | waybar.nix             | 10m       | 7.3   | Add mounts        |
| 102 | Add scratchpad workspace             | hyprland.nix           | 8m        | 7.3   | Add keybind       |
| 103 | Add better floating rules            | hyprland.nix           | 10m       | 7.3   | Add defaults      |
| 104 | Add focus follows mouse toggle       | hyprland.nix           | 8m        | 7.3   | Add binding       |
| 105 | Add auto back-and-forth toggle       | hyprland.nix           | 8m        | 7.3   | Add binding       |
| 106 | Add hot-reload capability            | hyprland.nix           | 8m        | 7.3   | Add keybind       |
| 107 | Test Hyprland config reload          | Hyprland               | 5m        | 7.3   | Press Ctrl+Alt+R  |
| 108 | Optimize keyboard repeat rate        | hyprland.nix           | 8m        | 7.2   | Tune settings     |
| 109 | Map Caps Lock to Esc/Ctrl            | hyprland.nix           | 8m        | 7.2   | Add keybind       |
| 110 | Add keyboard layout switcher         | waybar.nix             | 10m       | 7.2   | Add module        |
| 111 | Improve trackpad gestures            | hyprland.nix           | 10m       | 7.2   | Add swipe         |
| 112 | Add blur effect to hyprlock          | hyprlock.nix           | 10m       | 7.2   | Add blur          |
| 113 | Add privacy mode toggle              | hyprland.nix           | 10m       | 7.2   | Add binding       |
| 114 | Add screenshot detection             | waybar.nix             | 10m       | 7.2   | Add indicator     |
| 115 | Create Quake terminal script         | scripts/               | 12m       | 7.1   | Add dropdown      |
| 116 | Create Screenshot OCR script         | scripts/               | 12m       | 7.1   | Add text extract  |
| 117 | Create Color Picker script           | scripts/               | 12m       | 7.1   | Add picker        |
| 118 | Create Clipboard History viewer      | scripts/               | 12m       | 7.1   | Add viewer        |
| 119 | Create App Workspace Spawner         | scripts/               | 12m       | 7.1   | Add spawner       |
| 120 | Create git branch display            | waybar.nix             | 10m       | 7.1   | Add module        |
| 121 | Add terminal multiplexer integration | hyprland.nix           | 10m       | 7.1   | Add rules         |
| 122 | Add editor window rules              | hyprland.nix           | 10m       | 7.1   | Add nvim rules    |
| 123 | Create dev env launcher              | scripts/               | 12m       | 7.1   | Add launcher      |
| 124 | Add better window borders            | hyprland.nix           | 8m        | 7.0   | Style borders     |
| 125 | Tune animations                      | hyprland.nix           | 10m       | 7.0   | Add smoothness    |
| 126 | Add workspace naming persistence     | hyprland.nix           | 10m       | 7.0   | Save names        |
| 127 | Add app autostart management         | hyprland.nix           | 10m       | 7.0   | Add execs         |
| 128 | Move Terminal ENV to iTerm2 config   | environment.nix        | 10m       | 7.0   | Create file       |
| 129 | Move nixpkgs config to common        | darwin/default.nix     | 10m       | 7.0   | Refactor          |
| 130 | Move activation to environment       | activation.nix         | 10m       | 7.0   | Refactor          |
| 131 | Check ActivityWatch in nixpkgs       | nixpkgs                | 8m        | 7.0   | Search            |
| 132 | Add Darwin-specific networking       | networking/default.nix | 10m       | 7.0   | Add settings      |
| 133 | Test Darwin networking               | Darwin                 | 8m        | 7.0   | Verify settings   |
| 134 | Document Darwin vs NixOS networking  | docs/                  | 10m       | 7.0   | Add comparison    |
| 135 | Move paths-can-be-cleaned.txt        | tools/                 | 5m        | 7.0   | Move file         |
| 136 | Move AGENTS.md decision              | docs/                  | 8m        | 7.0   | Discuss location  |
| 137 | Implement `just organize` command    | justfile               | 12m       | 7.0   | Add recipe        |
| 138 | Add root file pre-commit hook        | pre-commit             | 10m       | 7.0   | Add check         |
| 139 | Create path constants library        | scripts/lib/           | 12m       | 7.0   | Add paths.sh      |
| 140 | Create script template               | scripts/               | 12m       | 7.0   | Add template.sh   |

**Tier 3 Total: 85 tasks | ~800 minutes | 13.3 hours**

---

## Tier 4: LOW (Score 6.0-6.9) - Backlog

| #   | Task                              | Source       | Est. Time | Score | Action             |
| --- | --------------------------------- | ------------ | --------- | ----- | ------------------ |
| 141 | Create audio visualizer           | waybar.nix   | 12m       | 6.9   | Add real-time      |
| 142 | Add mic status indicator          | waybar.nix   | 10m       | 6.9   | Add icon           |
| 143 | Add media player integration      | waybar.nix   | 12m       | 6.9   | Add now-playing    |
| 144 | Add volume visual feedback        | audio.nix    | 10m       | 6.9   | Add notification   |
| 145 | Add per-app volume control        | audio.nix    | 12m       | 6.9   | Add mixer          |
| 146 | Add noise suppression toggle      | audio.nix    | 10m       | 6.9   | Add toggle         |
| 147 | Add Bluetooth device switcher     | waybar.nix   | 12m       | 6.9   | Add menu           |
| 148 | Schedule automated cleanup        | systemd      | 12m       | 6.8   | Add timer          |
| 149 | Create config backups             | backup.nix   | 12m       | 6.8   | Add hourly         |
| 150 | Add workspace state preservation  | hyprland.nix | 12m       | 6.8   | Save layout        |
| 151 | Create one-click config sync      | scripts/     | 12m       | 6.8   | Add sync.sh        |
| 152 | Add config versioning             | backup.nix   | 12m       | 6.8   | Add git tags       |
| 153 | Create game mode toggle           | hyprland.nix | 12m       | 6.7   | Disable compositor |
| 154 | Add GPU optimization profiles     | amd-gpu.nix  | 12m       | 6.7   | Add profiles       |
| 155 | Add FPS stats in Waybar           | waybar.nix   | 12m       | 6.7   | Add mangohud       |
| 156 | Add game workspace themes         | hyprland.nix | 12m       | 6.7   | Add themes         |
| 157 | Add auto-group similar windows    | hyprland.nix | 12m       | 6.7   | Add tabs           |
| 158 | Add per-app layout rules          | hyprland.nix | 12m       | 6.7   | Add rules          |
| 159 | Add smart window positioning      | hyprland.nix | 12m       | 6.7   | Auto-position      |
| 160 | Add window grouping               | hyprland.nix | 12m       | 6.7   | By workflow        |
| 161 | Research AI workspace suggestions | docs/        | 12m       | 6.6   | Research           |
| 162 | Research smart window arrangement | docs/        | 12m       | 6.6   | Research           |
| 163 | Research voice commands           | docs/        | 12m       | 6.6   | Research           |
| 164 | Research activity automation      | docs/        | 12m       | 6.6   | Research           |
| 165 | Document packaging patterns       | docs/        | 12m       | 6.5   | Add patterns.md    |
| 166 | Contribute to nixpkgs docs        | upstream     | 12m       | 6.5   | Create PR          |
| 167 | Write blog post about patterns    | blog/        | 12m       | 6.5   | Draft post         |
| 168 | Clean git history                 | git          | 12m       | 6.4   | Interactive rebase |
| 169 | Clean shell history               | fish         | 8m        | 6.4   | Trim history       |
| 170 | Update documentation              | docs/        | 10m       | 6.4   | Refresh            |
| 171 | Create GTK theme integration      | nix-colors   | 12m       | 6.3   | Add module         |
| 172 | Create Qt theme integration       | nix-colors   | 12m       | 6.3   | Add module         |
| 173 | Add terminal emulator colors      | nix-colors   | 12m       | 6.3   | Add alacritty      |
| 174 | Add Neovim color scheme           | nix-colors   | 12m       | 6.3   | Add theme          |
| 175 | Add iTerm2 colors                 | nix-colors   | 12m       | 6.3   | Add plist          |
| 176 | Research custom color generation  | nix-colors   | 12m       | 6.2   | Research           |
| 177 | Research dark/light switching     | nix-colors   | 12m       | 6.2   | Research           |
| 178 | Research per-app color overrides  | nix-colors   | 12m       | 6.2   | Research           |
| 179 | Configure SublimeText as default  | darwin       | 10m       | 6.1   | Set default        |
| 180 | Add SublimeText to Nix            | base.nix     | 8m        | 6.1   | Add package        |
| 181 | Create keyboard shortcuts         | darwin       | 10m       | 6.1   | Add bindings       |
| 182 | Create wrapper architecture docs  | docs/        | 12m       | 6.0   | Write docs         |
| 183 | Write wrapper user guide          | docs/        | 12m       | 6.0   | Write guide        |
| 184 | Create wrapper examples           | docs/        | 12m       | 6.0   | Add examples       |
| 185 | Document wrapper troubleshooting  | docs/        | 12m       | 6.0   | Add FAQ            |
| 186 | Add wrapper-benchmark command     | justfile     | 10m       | 6.0   | Add recipe         |
| 187 | Add wrapper-profile command       | justfile     | 10m       | 6.0   | Add recipe         |
| 188 | Review Awesome Dotfiles repo      | research     | 12m       | 6.0   | Review             |
| 189 | Identify relevant patterns        | research     | 12m       | 6.0   | Extract            |
| 190 | Create PRs with improvements      | github       | 12m       | 6.0   | Submit PRs         |
| 191 | Review cleanup paths list         | docs/        | 10m       | 6.0   | Update list        |
| 192 | Add automated cleanup scheduling  | systemd      | 12m       | 6.0   | Add timer          |
| 193 | Review programs.nix for TODOs     | code         | 10m       | 6.0   | Find TODOs         |
| 194 | Implement each TODO               | code         | 12m       | 6.0   | Fix each           |
| 195 | Test programs.nix                 | test         | 10m       | 6.0   | Verify             |
| 196 | Review core.nix for TODOs         | code         | 10m       | 6.0   | Find TODOs         |
| 197 | Implement security configs        | code         | 12m       | 6.0   | Add security       |
| 198 | Implement services                | code         | 12m       | 6.0   | Add services       |
| 199 | Review system.nix for TODOs       | code         | 10m       | 6.0   | Find TODOs         |
| 200 | Implement macOS defaults          | code         | 12m       | 6.0   | Add defaults       |
| 201 | Test on Darwin                    | test         | 10m       | 6.0   | Verify             |
| 202 | Add backup flag to manual-linking | script       | 12m       | 6.0   | Add flag           |
| 203 | Create timestamped backups        | script       | 12m       | 6.0   | Add function       |
| 204 | Extract config to YAML            | script       | 12m       | 6.0   | Refactor           |
| 205 | Add link verification function    | script       | 12m       | 6.0   | Add verify         |
| 206 | Move to project docs              | docs/        | 8m        | 6.0   | Move file          |
| 207 | Create GitHub milestones          | github       | 10m       | 6.0   | Create v0.1.0-3    |
| 208 | Link issues to milestones         | github       | 10m       | 6.0   | Organize           |
| 209 | Track milestone progress          | github       | 10m       | 6.0   | Update             |
| 210 | Add SublimeText file associations | darwin       | 10m       | 6.0   | Add bindings       |

**Tier 4 Total: 70 tasks | ~790 minutes | 13.2 hours**

---

## Tier 5: VERY LOW (Score <6.0) - Future / Icebox

| #   | Task                             | Source   | Est. Time | Score | Action        |
| --- | -------------------------------- | -------- | --------- | ----- | ------------- |
| 211 | Research NPU utilization         | research | 12m       | 5.9   | ONNX Runtime  |
| 212 | Test ONNX GenAI on Linux         | test     | 12m       | 5.9   | Early access  |
| 213 | Enable NPU if working            | config   | 12m       | 5.9   | Add to config |
| 214 | Research local AI serving        | research | 12m       | 5.8   | Options       |
| 215 | Set up local LLM                 | config   | 12m       | 5.8   | Add ollama    |
| 216 | Test LLM serving                 | test     | 12m       | 5.8   | Verify        |
| 217 | Research distributed build cache | research | 12m       | 5.7   | nixbuild.net  |
| 218 | Set up nixbuild.net              | config   | 12m       | 5.7   | Add cache     |
| 219 | Test distributed builds          | test     | 12m       | 5.7   | Verify speed  |
| 220 | Research sops-nix                | research | 12m       | 5.6   | Secrets mgmt  |
| 221 | Add sops-nix integration         | config   | 12m       | 5.6   | Add module    |
| 222 | Migrate .env.private secrets     | config   | 12m       | 5.6   | Move secrets  |
| 223 | Test secrets management          | test     | 10m       | 5.6   | Verify        |
| 224 | Full Wayland session             | config   | 12m       | 5.5   | Enable        |
| 225 | Test Wayland stability           | test     | 10m       | 5.5   | Verify        |
| 226 | Document Wayland fix             | docs     | 12m       | 5.5   | Add notes     |
| 227 | Karabiner to Nix                 | config   | 12m       | 5.4   | Migrate       |
| 228 | Test Karabiner Nix               | test     | 10m       | 5.4   | Verify        |
| 229 | AltTab to Nix                    | config   | 12m       | 5.4   | Migrate       |
| 230 | Test AltTab Nix                  | test     | 10m       | 5.4   | Verify        |
| 231 | Rectangle Pro to Nix             | config   | 12m       | 5.3   | Migrate       |
| 232 | Bartender to Nix                 | config   | 12m       | 5.3   | Migrate       |
| 233 | Superwhisper to Nix              | config   | 12m       | 5.3   | Migrate       |
| 234 | NPU enablement research          | research | 12m       | 5.2   | ONXX Runtime  |
| 235 | Secure Boot                      | config   | 12m       | 5.1   | Enable        |
| 236 | PipeWire tuning                  | config   | 12m       | 5.0   | Optimize      |

**Tier 5 Total: 26 tasks | ~300 minutes | 5.0 hours**

---

## Summary by Tier

| Tier      | Score Range | Tasks   | Est. Time | Hours    | Focus            |
| --------- | ----------- | ------- | --------- | -------- | ---------------- |
| 1         | 9.0+        | 15      | 117m      | 2.0      | **Do Today**     |
| 2         | 8.0-8.9     | 40      | 340m      | 5.7      | **This Week**    |
| 3         | 7.0-7.9     | 85      | 800m      | 13.3     | **Next 2 Weeks** |
| 4         | 6.0-6.9     | 70      | 790m      | 13.2     | **Backlog**      |
| 5         | <6.0        | 26      | 300m      | 5.0      | **Future**       |
| **Total** | -           | **236** | **2347m** | **39.1** | -                |

**Note:** 493 TODOs were consolidated into 236 executable tasks (many were sub-steps of larger objectives).

---

## Quick Wins (High Score, Low Effort)

| #   | Task                          | Time | Impact |
| --- | ----------------------------- | ---- | ------ |
| 27  | Configure git user.name       | 3m   | High   |
| 28  | Configure git user.email      | 3m   | High   |
| 35  | Add jq processor              | 3m   | Medium |
| 36  | Add ripgrep                   | 3m   | Medium |
| 37  | Add fd find                   | 3m   | Medium |
| 38  | Add bat                       | 3m   | Medium |
| 135 | Move paths-can-be-cleaned.txt | 5m   | Low    |
| 169 | Clean shell history           | 8m   | Low    |
| 206 | Move to project docs          | 8m   | Low    |

**Quick Wins Total: 9 tasks | 44 minutes**

---

## Execution Strategy

### Phase 1: Critical Stabilization (Today - 2 hours)

- Fix Hyprland type safety assertions
- Fix Sandbox override anti-pattern
- Test HM workaround removal
- Verify builds pass

### Phase 2: Performance & UX (This Week - 6 hours)

- Fish shell optimization
- Bluetooth full setup
- Add essential CLI tools
- Configure git properly

### Phase 3: Feature Completion (Next 2 Weeks - 13 hours)

- Monitoring & Waybar modules
- Hyprland enhancements
- Security hardening
- Backup & testing

### Phase 4: Polish & Documentation (Backlog - 13 hours)

- Desktop improvements
- Scripts & automation
- Documentation
- Refactoring

### Phase 5: Future Features (Icebox - 5 hours)

- NPU research
- AI serving
- Advanced caching
- Nix migration of GUI apps

---

## Task Distribution by Category

| Category      | Tasks | Percentage |
| ------------- | ----- | ---------- |
| Configuration | 89    | 38%        |
| Testing       | 42    | 18%        |
| Documentation | 38    | 16%        |
| Research      | 31    | 13%        |
| Refactoring   | 22    | 9%         |
| Migration     | 14    | 6%         |

---

## Next Actions

**Immediate (Next 12 minutes):**

1. Start with Task #1: Fix Hyprland type safety assertions
2. Time-box each task to 12 minutes max
3. If blocked >5 min, skip and move to next
4. Mark complete with `[x]` and timestamp

**Tracking:**

- Update this document as tasks complete
- Move completed tasks to "Done" section
- Re-score remaining tasks weekly
- Adjust priorities based on new information

---

_Plan generated: 2026-02-28 07:00_
_Tasks: 236 | Est. Total: 39.1 hours | Avg: 10 min/task_
