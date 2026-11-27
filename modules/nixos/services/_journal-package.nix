# Single-site journal package default (consolidated 2026-11-19, task
# 000001a1f5d5…): journal-serve.nix + journal-backup.nix both import THIS
# file, so the next vendorHash re-stale edits ONE line here — never the old
# three-site "edit ALL THREE" dance (lib/lars-packages.nix journal entry +
# both module defaults).
#
# vendorHash shim history (2026-11-02 04:12 lock float: journal@3542a958
# spec OzU6YCvB…, got 1JuET6kA… — float-proof-20261102-043225-lars.log;
# RE-STALE 2026-11-06 journal@4a63e7f got 65uOOb5j; RE-STALE 2026-11-11
# 0663476 got OBIY8Nxi): SHIM DROPPED 2026-11-12 (treadmill drop-protocol) —
# the daemon float to 0ed74483 re-staled OBIY8Nxi (got ANZD3eOm,
# toplevel-proof-20261112-drop.log) and upstream 0ed74483 ALREADY BAKES
# exactly ANZD3eOm.
# SHIM RE-ADDED 2026-11-27 (first-hand FOD proof): the 10:34 daemon lock
# float (97b74f040) holds journal@f32e70c2, whose upstream bake 9M6laArs
# (flake.nix:215) stales under our graph — got 2piQtqwo from the pre-deploy
# §11 cached-FOD audit's check-mode rebuild (the stale FOD was silently
# REUSED in cache, so the old gate never saw it). Drop when upstream bakes
# 2piQtqwo; a future re-stale edits the `vendorHash` line below on
# first-hand FOD proof, never by hand.
#
# NOTE: lib/lars-packages.nix's `journal` entry (the PATH CLI surface) is a
# separate consumer — a shim here is mirrored there (TWO sites total: this
# file + lars-packages PATH entry), the module defaults follow this file
# automatically.
{
  inputs,
  system,
}:
inputs.journal.packages.${system}.default.overrideAttrs (_: {
  vendorHash = "sha256-2piQtqwofrGHq5IsRjyH5MFQasYLZikjE50O0+WQV6c=";
})
