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
# exactly ANZD3eOm. Re-add a shim ONLY via nix-hash-fix evidence: change the
# `default` below to `pkg.overrideAttrs { vendorHash = <got>; }` on
# FIRST-HAND FOD proof, never by hand.
#
# NOTE: lib/lars-packages.nix's `journal = flakePkg inputs.journal` entry
# (the PATH CLI surface) is a separate consumer — if a future shim lands
# here, mirror it there (TWO sites total: this file + lars-packages PATH
# entry), the module defaults follow this file automatically.
{
  inputs,
  system,
}:
inputs.journal.packages.${system}.default
