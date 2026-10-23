# vendorHash shim values consumed by MORE THAN ONE surface.
#
# Why this file exists (2026-10-23): the same shim literal was maintained in two
# places for projects-management-automation — `lib/lars-packages.nix` (the
# `packages.<system>` / PATH surface) and the module's
# `services.projects-management-automation.package` (the service surface,
# because that module consumes the flake's own package attr and therefore never
# saw the lars-packages override). Two hand-synced literals are a split brain
# waiting to drift, and a drifted shim reads as a stale-hash build failure at
# deploy time. One value, two consumers, no sync step.
#
# Scope rule: put a value here ONLY when two or more surfaces must agree. A shim
# with a single consumer stays next to that consumer (the class comments and
# drop conditions live there, where the reader is).
#
# Drop protocol is unchanged (docs/agents/nix-flakes.md): drop a value when
# upstream bakes the got hash or the lock moves past an upstream-fixed rev;
# re-add ONLY via nix-hash-fix / first-hand keep-going evidence, never by hand.
{
  # RE-ADDED 2026-10-23 lock float: specified U9F6gATv…, first-hand got
  # NBQcjrwD… (evo-x2 toplevel --keep-going enumeration).
  projects-management-automation = "sha256-NBQcjrwDfb5Eqeic7hpAN/1M4FI5XAA4YldmKXXpnt0=";
}
