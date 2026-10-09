# Eval-time assertion: a unit's MemoryHigh (soft throttle watermark) must
# never sit far below its own MemoryMax (hard kill).
#
# Bug class (llama-chat 2026-10-08, deployment #1): `harden {}` derives
# MemoryHigh as 80% of its OWN MemoryMax ARGUMENT; merging a bigger MemoryMax
# outside a bare `harden {}` call wins the ceiling while the watermark stays
# at the 512M-default derivation (410M). The kernel then reclaim-thrashes
# under the watermark forever: 46k throttle events, 10.7G swap, 1h53m stuck
# load, 45s timeouts on 16-token replies — while the unit stays
# `active (running)`, logs nothing, and every liveness check stays green.
# Throttling is a pure performance failure: nothing failed, so nothing
# alerted. This assertion makes watermark incoherence impossible at eval
# time instead of invisible at runtime.
#
# Rule: when BOTH watermarks are plain byte values, MemoryHigh >= 50% of
# MemoryMax (harden's own derivation is 80%). Under 50% the two values were
# set by different authors — the trap shape. Percent values resolve against
# TOTAL RAM (never the trap class on a large host) and "infinity"/"max" parse
# as null. high-only units (btrbk 4G throttle-only) and max-only units (no
# watermark: gitea-runner 16G) are different, VISIBLE failure modes and pass.
# Live probe for the runtime residue of this class:
#   cat /sys/fs/cgroup/system.slice/<unit>.service/memory.events  # `high` > 0
_: {
  flake.nixosModules.memory-watermark-audit =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.memory-watermark-audit;
      mult = {
        K = 1024;
        M = 1048576;
        G = 1073741824;
        T = 1099511627776;
        "" = 1;
      };
      # Bytes, or null when unparseable (percent / "infinity" / "max").
      parseBytes =
        v:
        let
          m = builtins.match "([0-9]+)([KMGT]?)" (toString v);
        in
        if m == null then null else (builtins.fromJSON (builtins.elemAt m 0)) * mult.${builtins.elemAt m 1};
      trap =
        name: svc:
        !(builtins.elem name cfg.allowUnits)
        && (
          let
            sc = svc.serviceConfig;
            high = if sc ? MemoryHigh && sc.MemoryHigh != null then parseBytes sc.MemoryHigh else null;
            max = if sc ? MemoryMax && sc.MemoryMax != null then parseBytes sc.MemoryMax else null;
          in
          high != null && max != null && max > 0 && high * 2 < max
        );
      systemOffenders = lib.attrNames (lib.filterAttrs trap config.systemd.services);
      userOffenders = lib.attrNames (lib.filterAttrs trap config.systemd.user.services);
      fix = ''
        Fix: pass MemoryMax INTO the harden{} call — the throttle watermark
        derives from that argument (llama-chat.nix is the reference) — or set
        MemoryHigh alongside the outside MemoryMax merge. A deliberate
        aggressive-reclaim design goes in
        services.memory-watermark-audit.allowUnits with a justification.
      '';
    in
    {
      options.services.memory-watermark-audit.allowUnits = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Units exempt from the MemoryHigh/MemoryMax coherence check. Every
          entry needs a justification comment where it is set: a sub-50%
          watermark is the llama-chat throttle-trap shape (2026-10-08).
        '';
      };

      config.assertions = [
        {
          assertion = systemOffenders == [ ];
          message = ''
            memory-watermark-audit: MemoryHigh < 50% of MemoryMax on system units:
            ${lib.concatStringsSep ", " systemOffenders}
            The throttle watermark and the hard ceiling were set by different
            authors; the kernel reclaim-thrashes under the watermark with the
            unit `active (running)` and no log line (llama-chat 2026-10-08:
            410M watermark under a 48G ceiling, 46k throttle events).
            ${fix}
          '';
        }
        {
          assertion = userOffenders == [ ];
          message = ''
            memory-watermark-audit: MemoryHigh < 50% of MemoryMax on user units:
            ${lib.concatStringsSep ", " userOffenders}
            The throttle watermark and the hard ceiling were set by different
            authors; the kernel reclaim-thrashes under the watermark with the
            unit `active (running)` and no log line (llama-chat 2026-10-08:
            410M watermark under a 48G ceiling, 46k throttle events).
            ${fix}
          '';
        }
      ];
    };
}
