{
  lib,
  buildGoModule,
  src,
}:
# ai-meter — loopback OpenAI-compatible metering proxy for every AI call on
# the host (crush, paperless-gpt, inboxclean, …). Source lives in-tree at
# pkgs/ai-meter/ (homelab-specific infrastructure, deliberately NOT a
# separate LarsArtmann repo); consumed by
# modules/nixos/services/ai-meter.nix with the SAME src argument on both
# call sites so the store path is identical, and exposed as
# `nix build .#ai-meter`.
#
# Stdlib only by design: zero module dependencies means vendorHash = null
# forever — no FOD, no toolchain-skew re-hashing waves (the 2026-10-03
# root-nixpkgs class can never hit this package).
buildGoModule {
  pname = "ai-meter";
  version = "0.1.0";

  inherit src;

  vendorHash = null;

  ldflags = [
    "-s"
    "-w"
  ];

  # The package's own tests run via buildflow (test-race) and the VM test
  # (tests/test-ai-meter.nix); buildGoModule's checkPhase is redundant
  # shell time on a stdlib-only module whose suite needs no sandboxing.
  doCheck = false;

  meta = {
    description = "Transparent metering proxy for OpenAI-compatible APIs (metrics + JSONL ledger)";
    mainProgram = "ai-meter";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
