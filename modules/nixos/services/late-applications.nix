# late-applications.target — the single sanctioned post-boot pull point.
#
# WHY THIS EXISTS (2026-10-26 gitea-runner + geometrikks/crowdsec incident
# class): units gated on application readiness (DNS/OIDC waits, minutes at
# boot) must not sit on the boot critical chain — but giving them
# `After=multi-user.target` DIRECTLY (the 2026-10-18 family-audit shape)
# arms an ordering cycle for EVERY multi-user-wanted unit that transitively
# orders after them. systemd breaks such cycles by silently DELETING start
# jobs from the boot/switch transaction:
#   - gitea-runner (After=forgejo + nixpkgs wantedBy multi-user) with forgejo
#     gated After=multi-user → runner start job deleted on every boot/switch
#     (dead ~11h on 2026-10-25, down again 2026-10-26 20:00)
#   - geometrikks + crowdsec-bouncer-register deleted the same way at the
#     gen-954 switch (chain: geometrikks ← bouncer-register ← crowdsec ←
#     crowdsec-prereq ← gate After=multi-user)
#
# THE SHAPE: exactly ONE unit in the whole graph carries
# After=multi-user.target — this target. Membership via
# `wantedBy = [ "late-applications.target" ]` gives a unit:
#   - start AFTER multi-user.target (boot critical chain untouched — the
#     2026-10-17 llama-chat / 2026-10-18 miniflux-91s owner rulings hold)
#   - NO ordering edge toward multi-user.target → nothing that orders after
#     the unit can close a cycle back into the boot transaction
#
# Enforcement: modules/nixos/services/ordering-cycle-audit.nix fails eval on
# any ordering cycle over the composed unit graph (implicit target-membership
# edges modeled with systemd's explicit-ordering suppression rule).
_: {
  flake.nixosModules.late-applications = {
    systemd.targets.late-applications = {
      description = "Applications whose readiness waits must not sit on the boot critical chain";
      # Suppressed-idiom (live-verified 2026-10-26): wanted by multi-user but
      # explicitly ordered after it — the implicit Before=multi-user that
      # wants-membership would add is suppressed by this After=, so
      # multi-user.target NEVER waits for this target or its members.
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  };
}
