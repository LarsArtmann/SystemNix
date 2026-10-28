# Behavioral negative test for the dnsblockd readiness gate (2026-10-28
# review issue #2 / plan step F01d).
#
# WHY this exists: until 2026-10-28 the gate grepped `ss -ltn` for the BLOCK
# PAGE port (:80, TCP only) while its own comment, its budget rationale and
# two queue rows all described "the :53 listener". Intent and code disagreed
# for weeks because nothing executed the check against a fixture — the only
# evidence was a green start job, which a proxy port satisfies just as well.
#
# The gate now probes `ports.dns-blocker` over UDP+TCP. This check runs the
# REAL deployed script (taken from the evo-x2 unit's ExecStartPost, so a
# refactor that stops installing the gate fails here) against five fixture
# listener maps:
#
#   :80 only (tcp+udp)      -> FAIL   the old wrong-port proof, now impossible
#   :5355 only              -> FAIL   suffix matching must not accept :5355
#   :53 tcp + udp           -> PASS   the healthy contract
#   :53 udp only            -> PASS + WARNING (degraded, not dead: a start-job
#                                       failure would restart-churn the sole
#                                       resolver — the outage class the gate
#                                       exists to prevent)
#   probe unavailable       -> PASS + WARNING (fail OPEN: a monitoring blind
#                                       spot must never kill DNS)
#
# Budget is injected as 2s (test seam) so a failing leg costs seconds, not the
# production 300s. The seam is documented at the script; the unit inherits no
# ambient environment, so production always resolves the defaults.
{ inputs, root, ... }:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      checks.dnsblockd-readiness-gate =
        let
          unit = inputs.self.nixosConfigurations.evo-x2.config.systemd.services.dnsblockd.serviceConfig;
          gate = builtins.head unit.ExecStartPost;

          # Listener maps in `ss -ltnuH` shape: netid state recv send local peer.
          fakeSs = body: pkgs.writeShellScript "fake-ss" body;
          onlyBlockPage = fakeSs ''
            printf '%s\n' "tcp LISTEN 0 4096 *:80 *:*" "udp UNCONN 0 0 *:80 *:*"
          '';
          onlyNeighbourPort = fakeSs ''
            printf '%s\n' "tcp LISTEN 0 4096 *:5355 *:*" "udp UNCONN 0 0 *:5355 *:*"
          '';
          healthy = fakeSs ''
            printf '%s\n' "tcp LISTEN 0 4096 *:53 *:*" "udp UNCONN 0 0 *:53 *:*"
          '';
          udpOnly = fakeSs ''
            printf '%s\n' "udp UNCONN 0 0 *:53 *:*"
          '';
          probeBroken = fakeSs ''
            echo "ss: cannot open socket" >&2
            exit 1
          '';
        in
        pkgs.runCommand "dnsblockd-readiness-gate-selftest" { } ''
          work="$PWD"
          fail() {
            echo "FAIL: $*" >&2
            exit 1
          }

          # expect <leg-name> <want-rc> <fake-ss>
          expect() {
            local name="$1" want="$2" fake="$3" rc
            set +e
            DNSBLOCKD_LISTENER_WAIT_BUDGET=2 \
              DNSBLOCKD_LISTENER_WAIT_SS="$fake" \
              ${gate} >"$work/$name.out" 2>"$work/$name.err"
            rc=$?
            set -e
            [ "$rc" -eq "$want" ] || fail "$name: exit $rc, want $want. stderr: $(cat "$work/$name.err")"
          }

          expect blockpage-only 1 ${onlyBlockPage}
          grep -q 'ERROR: no :53 listener' "$work/blockpage-only.err" \
            || fail "blockpage-only: the failure must name the DNS port (:53), got: $(cat "$work/blockpage-only.err")"
          grep -q 'startup phase complete' "$work/blockpage-only.err" \
            || fail "blockpage-only: the error lost its journal discriminator"

          expect neighbour-port-only 1 ${onlyNeighbourPort}

          expect healthy 0 ${healthy}
          [ -s "$work/healthy.err" ] && fail "healthy: unexpected stderr: $(cat "$work/healthy.err")"

          expect udp-only 0 ${udpOnly}
          grep -q 'one transport only' "$work/udp-only.err" \
            || fail "udp-only: a single-transport resolver must WARN, got: $(cat "$work/udp-only.err")"

          expect probe-broken 0 ${probeBroken}
          grep -q 'ss probe unavailable' "$work/probe-broken.err" \
            || fail "probe-broken: a missing ss must fail OPEN with a warning"

          touch "$out"
          echo "dnsblockd readiness gate: 5/5 legs passed (2 negative, 3 positive)"
        '';

      # CA-parity fixture selftest (post-deploy §22, 2026-10-28 plan T02).
      # Runs the SAME scripts/lib/ca-parity-smoke.sh prod sources — never a
      # drifted copy — against REAL openssl-generated certificates, so a change
      # in openssl's subject/fingerprint formatting breaks here instead of
      # silently weakening the live guard. Live, both CAs agree; the FAIL
      # branches have no rehearsal path that does not deliberately break real
      # browser trust, so this is the only exercise they get.
      checks.dnsblockd-ca-parity-selftest =
        pkgs.runCommand "dnsblockd-ca-parity-selftest"
          {
            nativeBuildInputs = [ pkgs.openssl ];
          }
          ''
            scratch=$(mktemp -d)
            mkdir -p "$scratch/scripts/lib"
            cp ${root}/scripts/test-ca-parity-smoke.sh "$scratch/scripts/test-ca-parity-smoke.sh"
            cp ${root}/scripts/lib/ca-parity-smoke.sh "$scratch/scripts/lib/ca-parity-smoke.sh"
            ${pkgs.bash}/bin/bash "$scratch/scripts/test-ca-parity-smoke.sh"
            touch $out
          '';
    };
}
