_: {
  # Passwordless sudo for wheel group members
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
    # Keep the no-heavy-builds gate's escape hatch across privilege
    # boundaries: deploy tooling re-invokes nix under `sudo env …` (nh's
    # post-switch profile-set leg), and sudo strips the caller's env —
    # without env_keep a switch forced past the gate still died at the
    # anchor step (2026-10-14: nh "Failed to set system profile" + the
    # 13:10 deploy exit 14 UNANCHORED, both re-anchored by hand mid-storm).
    extraConfig = ''
      Defaults env_keep += "NIX_HEAVY_GATE_FORCE"
    '';
  };
}
