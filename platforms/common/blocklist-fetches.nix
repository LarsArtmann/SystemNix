# Every blocklist of dns-blocklists.nix as its real fetchurl derivation, in
# one buildable attribute set.
#
# WHY (2026-11-25 deploy bomb): a wrong SRI hash only ever surfaced when a
# deploy's toplevel build reached the fetches. The nightly repair pass had
# committed six bad hashes and nothing built them, so every deploy died for a
# day. The `blocklist-fetches` flake check builds this, and the
# dns-blocklist-drift workflow builds it BEFORE its commit step.
#
# Each fetch mirrors `fetchedRawBlocklists` in
# modules/nixos/services/dns-blocker.nix (same URL, hash and `-raw` name), so
# a green build here means the service's own fetches are green. The function
# takes `pkgs` instead of importing nixpkgs itself because the workflow
# evaluates it outside the flake (the flake's private inputs need deploy keys
# that a scheduled job does not have).
{ pkgs }:
let
  inherit (import ./dns-blocklists.nix) blocklists;
in
pkgs.linkFarm "blocklist-fetches" (
  map (bl: {
    name = bl.name;
    path = pkgs.fetchurl {
      inherit (bl) url hash;
      name = "${bl.name}-raw";
    };
  }) blocklists
)
