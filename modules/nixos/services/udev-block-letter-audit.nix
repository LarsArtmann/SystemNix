# Eval-time assertion: udev rules MUST NOT execute commands (RUN+=) at
# kernel-LETTER-matched disks (KERNEL=="sd[...]"). sd letters reshuffle on
# every replug/reboot — a rule written for one specific disk silently
# re-attaches to WHATEVER disk inherits the letter next.
#
# Bug class history (2026-08-12 → 2026-08-29, one week of DAS outage):
# the "spindown retired ZFS pool" rule (KERNEL=="sd[ab]" → RUN+= hdparm
# -S 120 -B 127) fired through the JMicron JMS567 DAS bridge once the DAS
# disks inherited the sda/sdb letters. The flaky bridge wedged mid-handshake
# (2026-08-22 00:59:15, zero kernel errors, instant bus disappearance) and
# the whole 4-bay DAS stayed dark while pool/buildcache services failed.
# Executing commands (RUN+=) at letter-matched disks is banned; attribute
# sets on whole-class matches (e.g. queue/scheduler=bfq for sd[a-z]*) are
# intentional and allowed. Match disks by ENV{ID_SERIAL} or
# ATTRS{idVendor}/ATTRS{idProduct} instead — never by letter. See AGENTS.md
# "DAS USB link" gotcha.
_: {
  flake.nixosModules.udev-block-letter-audit =
    {
      lib,
      config,
      ...
    }:
    let
      # Source of truth: the fully merged extraRules string at eval time —
      # catches rules contributed by ANY module, not just hand-written ones.
      rules = config.services.udev.extraRules;

      ruleLines = lib.splitString "\n" rules;

      # KERNEL=="sd[ab]" + RUN+= on the same line: executing a command at
      # letter-matched disks. (\[ escaped; anything before/after allowed.)
      letterRuleLines = builtins.filter (
        line: builtins.match ".*KERNEL==\"sd\\[.*" line != null && builtins.match ".*RUN\\+=.*" line != null
      ) ruleLines;
    in
    {
      config.assertions = [
        {
          assertion = letterRuleLines == [ ];
          message = ''
            services.udev.extraRules executes a command (RUN+=) at a
            KERNEL=="sd[...]" letter-matched disk:
              ${lib.concatStringsSep "\n  " letterRuleLines}
            sd letters are unstable across replugs/reboots; such a rule will
            eventually fire at an unrelated disk (2026-08-12 hdparm sd[ab]
            rule wedged the JMS567 DAS bridge → week-long pool outage).
            Match by ENV{ID_SERIAL} or ATTRS{idVendor}/ATTRS{idProduct}.
          '';
        }
      ];
    };
}
