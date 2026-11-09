# Eval/build guards for the cv-relogin loop (SUPERB plan P3, 2026-11-09).
#
# WHY: the loop's proofs from the implementation session were ephemeral
# (journal, transient unit, hand-run script). Two cheap checks pin the claims
# that rot silently:
#
#   cv-relogin-specs — every configured relogin platform's spec (in the LOCKED
#     cv package) carries automation_spec.login_url + session_cookie. A spec
#     edit or package bump that drops either field turns the loop's relogin
#     into a guaranteed failure; this names the file at flake-check time.
#
#   cv-relogin-env — the evo-x2 unit's contract: SuccessExitStatus=10 (an
#     unseeded store stays green), TimeoutStartSec/MemoryMax sized for a
#     browser, store-enabled env, and a NODE_PATH that actually resolves
#     playwright/index.js (the served state dir has no node_modules — bun
#     resolution depends on this one symlink tree).
#
# Both derive from the HOST config (never a drifted copy), following the
# dnsblockd-guards pattern.
{ inputs, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      checks.cv-relogin-specs =
        let
          host = inputs.self.nixosConfigurations.evo-x2.config;
          platforms = host.services.cv-server.relogin.platforms;
          specsDir = "${host.services.cv-server.package}/share/cv/data/freelance-platforms";
          platformList = pkgs.writeText "cv-relogin-platforms" (lib.concatStringsSep "\n" platforms);
        in
        pkgs.runCommand "cv-relogin-specs" { } ''
          fail() { echo "FAIL: $*" >&2; exit 1; }
          [ -s ${platformList} ] || fail "services.cv-server.relogin.platforms is empty — nothing would ever refresh"
          while IFS= read -r p; do
            f="${specsDir}/$p.yaml"
            [ -f "$f" ] || fail "relogin platform '$p' has no spec at $f (share dir of the locked cv package)"
            grep -Eq '^[[:space:]]*login_url:' "$f" || fail "$p: automation_spec.login_url missing — relogin cannot open the login page"
            grep -Eq '^[[:space:]]*session_cookie:' "$f" || fail "$p: automation_spec.session_cookie missing — relogin cannot record the session"
            echo "ok: $p carries login_url + session_cookie"
          done < ${platformList}
          touch $out
        '';

      checks.cv-relogin-env =
        let
          unit = inputs.self.nixosConfigurations.evo-x2.config.systemd.services.cv-relogin.serviceConfig;
          envLines = pkgs.writeText "cv-relogin-env" (lib.concatStringsSep "\n" unit.Environment);
          # Eval-time pins: a regression in these changes loop behavior
          # silently, so they fail at flake-check, not at the first Monday.
          pin = cond: msg: lib.optionalString (!cond) "echo 'FAIL: ${msg}' >&2; exit 1;";
          pins =
            pin (
              unit.SuccessExitStatus == [ 10 ]
            ) "cv-relogin must keep SuccessExitStatus=10 (unseeded exits green, never pages)"
            + pin (
              unit.TimeoutStartSec == 1200
            ) "cv-relogin TimeoutStartSec must stay 1200 (3 platforms x 240s cookie wait + slack)"
            + pin (
              unit.MemoryMax == "3G"
            ) "cv-relogin MemoryMax must stay 3G (the 512M harden default throttles chromium to death)"
            +
              pin (unit.User == "cv")
                "cv-relogin must run as the cv service user (the only identity that can decrypt AND write the served session)"
            + pin (
              unit ? EnvironmentFile && unit.EnvironmentFile != [ ]
            ) "cv-relogin lost its EnvironmentFile (the store master key injection)";
        in
        pkgs.runCommand "cv-relogin-env" { } ''
          ${pins}
          nodepath="$(sed -n 's/^NODE_PATH=//p' ${envLines})"
          test -n "$nodepath" || { echo 'FAIL: cv-relogin lost its NODE_PATH' >&2; exit 1; }
          test -f "$nodepath/playwright/index.js" || {
            echo "FAIL: NODE_PATH=$nodepath does not resolve playwright/index.js — bun relogin scripts cannot require playwright" >&2
            exit 1
          }
          grep -qx 'CV_CREDENTIALS_STORE_ENABLED=1' ${envLines} || {
            echo 'FAIL: CV_CREDENTIALS_STORE_ENABLED=1 lost — the unit could silently degrade to the env seam' >&2
            exit 1
          }
          touch $out
          echo "ok: cv-relogin env contract holds (NODE_PATH resolves playwright)"
        '';
    };
}
