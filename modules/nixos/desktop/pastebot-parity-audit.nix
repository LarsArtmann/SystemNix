# Eval-time audit: the PasteBot-parity surface (2026-10-15) — three niri
# binds + the systemnix-snippets DMS launcher plugin — must survive refactors.
#
# Why this exists: the whole feature is the blocker-removal for switching
# fully to NixOS (replacing PasteBot on macOS). Unlike ports or systemd
# shapes, NOTHING else would notice if a refactor renamed, repointed, or
# dropped "Mod+Shift+C" — the bind is a stringly key inside a freeform
# attrset, and a silent regression would only surface the day the user
# reaches for the picker and it is not there. This audit pins the bind
# KEYS and their full spawn COMMANDS (not just presence: a repointed
# Mod+Shift+C that opens the calculator instead of :s is exactly the
# regression class being guarded), plus the plugin registration key.
#
# Enforcement surface: NixOS toplevel eval — fires on every
# `nix flake check`, `nix eval`, and deploy build.
#
# Scope: only home-manager users running DankMaterialShell — the pickers
# are DMS-dependent, so DMS-enabled users are exactly where the surface
# must exist. (Filtering on programs.niri.enable is WRONG: niri-wrapped.nix
# never sets it — the enable lives at the NixOS level — so an enable-based
# filter silently matches nobody and the audit grows no teeth; caught by
# CASES=pastebot negative tests, 2026-10-16.) home-manager is absent on
# HM-less hosts (rpi3-dns) and in the flake-parts eval context — `or { }`
# guards both.
#
# Deliberate changes (moving a bind, retiring the feature): update this
# module IN THE SAME CHANGE — the failure message is the tripwire, not
# an obstacle. Verify both directions via
# `CASES=pastebot bash scripts/negative-test-lints.sh`.
{
  flake.nixosModules.pastebot-parity-audit =
    {
      config,
      lib,
      ...
    }:
    let
      expectedBindSpawns = {
        # Clipboard history picker (PasteBot cmd+shift+V equivalent)
        "Mod+Shift+V" = [
          "dms"
          "ipc"
          "call"
          "clipboard"
          "toggle"
        ];
        # Snippets picker (PasteBot cmd+shift+C equivalent) — :s trigger
        "Mod+Shift+C" = [
          "dms"
          "ipc"
          "call"
          "spotlight"
          "toggleQuery"
          ":s"
        ];
        # Calculator — displaced to Mod+Ctrl+C by the snippets bind
        "Mod+Ctrl+C" = [
          "dms"
          "ipc"
          "call"
          "spotlight"
          "toggleQuery"
          "="
        ];
      };

      userAssertions =
        user: uc:
        let
          binds = (uc.programs.niri.settings or { }).binds or { };

          bindAssertions = lib.mapAttrsToList (
            bind: spawn:
            let
              actual = binds."${bind}".action.spawn or null;
            in
            {
              assertion = actual == spawn;
              message = ''
                pastebot-parity-audit: niri bind '${bind}' for user '${user}' is
                missing or repointed (expected spawn: ${lib.concatStringsSep " " spawn},
                got: ${if actual == null then "(bind absent)" else lib.concatStringsSep " " actual}).
                This bind is the PasteBot-parity picker entrypoint — dropping or
                repointing it silently removes the feature that unblocked the
                NixOS switch. Fix: restore the bind in platforms/nixos/desktop/niri-wrapped.nix,
                or — for a deliberate move — update expectedBindSpawns in
                modules/nixos/desktop/pastebot-parity-audit.nix in the same change.'';
            }
          ) expectedBindSpawns;

          dmsEnabled = (uc.programs.dank-material-shell or { }).enable or false;
          pluginAssertions = lib.optionals dmsEnabled [
            {
              assertion = (uc.programs.dank-material-shell.plugins or { }) ? "systemnix-snippets";
              message = ''
                pastebot-parity-audit: the systemnix-snippets DMS launcher plugin is
                not registered for user '${user}' (programs.dank-material-shell.plugins
                lacks the key). Without it the ':s' trigger — and therefore the
                Mod+Shift+C snippets picker — is dead. Fix: restore the plugin block in
                platforms/nixos/desktop/quickshell.nix, or update this audit if the
                plugin was deliberately retired.'';
            }
          ];
        in
        bindAssertions ++ pluginAssertions;

      dmsUsers = lib.filterAttrs (user: uc: (uc.programs.dank-material-shell or { }).enable or false) (
        config.home-manager.users or { }
      );
    in
    {
      config.assertions = lib.concatLists (lib.mapAttrsToList userAssertions dmsUsers);
    };
}
