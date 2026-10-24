{
  lib,
  buildGo126Module,
  src,
}:

buildGo126Module {
  pname = "gatus-alert-relay";
  version = "1.0.0";

  inherit src;

  # Stdlib only — no deps to vendor, no FOD, no toolchain-skew re-hash
  # waves (same doctrine as ai-meter).
  vendorHash = null;

  # policy_test.go runs in the build: every decision rule, replay
  # transition, and the fail-open path are build-time verified.
  doCheck = true;

  meta = {
    description = "Local gate on gatus' Discord webhook: boot grace, SEV1 parent-incident mute, flap collapse, re-arm guard — mutes delay, never lose";
    platforms = lib.platforms.linux;
    mainProgram = "gatus-alert-relay";
  };
}
