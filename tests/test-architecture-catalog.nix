# VM test for the architecture-catalog service module
# (modules/nixos/services/architecture-catalog.nix) — one VM test per
# service is the house norm; the module shipped 2026-09-12 without one.
#
# The sync/collector behaviors were fixture-verified standalone in the
# 2026-09-23 hub session; this test pins them against the REAL unit
# wiring. The transport (git clone over HTTPS to forgejo.home.lan) is
# stubbed — a `git` stub on the unit's ambient PATH (writeShellApplication
# appends its runtimeInputs AFTER $PATH, so a unit-level `path = [stub]`
# shadows git) materializes /srv/fake-dist as the cloned tree, which the
# test rewrites between runs to simulate successive CI publishes:
#   1. PLACEHOLDER token skip path (pre-go-live is exit-0, not a scrape
#      error; the discordsync-Turso doctrine)
#   2. Real-token sync converge against the stub clone: generation dir +
#      a+rX perms + relative `current` symlink flip
#   3. Atomic swap under changed content (second publish, current moves)
#   4. keep-N pruning (maxGenerations = 2; oldest generation removed,
#      current intact)
#   5. Missing index.html → refuse-to-swap fail-closed (current keeps
#      last-good), unit fails loudly
#   6. Collector fail-closed matrix: fresh dist → dist_present 1 / fresh 1
#      / scrape_errors 0; stale builtAt → fresh 0; unreadable stamp → ONLY
#      scrape_errors 1 (value metrics omitted — the anchored Gatus pats go
#      red, never phantom-green); absent index → honest 0/0/-1 (not a
#      scrape error)
#   7. bash -n legs on the REAL rendered scripts: sync script, collector
#      script, the DNS-gate script, and the inline /dev/tcp probe (raw
#      systemd script strings are eval-checked only — the 09-23
#      doubled-`then` class)
#
# The DNS gate + endpoint probe stay LIVE: cfg.host is pinned to
# 127.0.0.1, which getent resolves instantly, and a socat stub listens on
# :443 so the ExecStartPre /dev/tcp probe passes without waiting out its
# 120s fail-open budget.
{
  pkgs,
  lib ? pkgs.lib,
  ...
}:
let
  catalogModule =
    ((import ../modules/nixos/services/architecture-catalog.nix) { })
      .flake.nixosModules.architecture-catalog;

  stateDir = "/var/lib/architecture-catalog";

  # `git` stub: the ONLY invocation the sync script makes is
  # `git clone --depth 1 --branch <b> <url> <dir>`; materialize the
  # current /srv/fake-dist content as the "cloned" tree.
  stubGit = pkgs.writeShellApplication {
    name = "git";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      if [ "''${1:-}" = "clone" ]; then
        dir=""
        for a in "$@"; do dir="$a"; done
        rm -rf "$dir"
        cp -r /srv/fake-dist "$dir"
        exit 0
      fi
      echo "vm-stub-git: unsupported invocation: $*" >&2
      exit 1
    '';
  };
in
{
  name = "architecture-catalog";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [
        catalogModule
        # co-import (the miniflux lesson): the module declares a
        # services.integration entry whose options?-guard does NOT survive
        # cfg.enable — an mkIf-wrapped definition at an undeclared path is
        # still collected, so integration.nix must declare the namespace.
        ((import ../modules/nixos/services/integration.nix) { }).flake.nixosModules.integration
        ./mock-sops.nix
        ./test-helpers.nix
      ];

      system.stateVersion = "25.11";
      virtualisation.memorySize = 2048;

      services.architecture-catalog = {
        enable = true;
        # 127.0.0.1 keeps the REAL mkDnsGate (getent) + ExecStartPre
        # /dev/tcp probe exercised; the :443 listener is the socat stub.
        host = "127.0.0.1";
        maxGenerations = 2;
      };

      # sops mock: the token env file ships as PLACEHOLDER (pre-go-live),
      # rewritten in-flight by the test once the real-token phases begin.
      sops.secrets.architecture_catalog_sync_token.path = "/etc/vm-sync-token";
      environment.etc."vm-sync-token".text =
        "ARCHITECTURE_CATALOG_SYNC_TOKEN=PLACEHOLDER\n";

      # :443 listener so the sync unit's ExecStartPre /dev/tcp probe
      # succeeds immediately (fork mode survives multiple probes).
      environment.systemPackages = [ pkgs.socat ];
      systemd.services.vm-https-stub = {
        description = "VM test: stub :443 listener for the sync endpoint probe";
        wantedBy = [ "architecture-catalog-sync.service" ];
        before = [ "architecture-catalog-sync.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.socat}/bin/socat TCP-LISTEN:443,fork,reuseaddr -";
          Restart = "always";
        };
      };

      # The stub clone source; re-seeded between phases from the test.
      systemd.services.vm-fake-dist = {
        description = "VM test: seed the stub clone source";
        wantedBy = [ "architecture-catalog-sync.service" ];
        before = [ "architecture-catalog-sync.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.coreutils ];
        script = ''
          mkdir -p /srv/fake-dist
          printf '<html><title>EventCatalog v1</title></html>\n' > /srv/fake-dist/index.html
          printf '{"builtAt":"%s"}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > /srv/fake-dist/build-stamp.json
        '';
      };

      # Stub git shadows the script's real git via ambient PATH.
      systemd.services.architecture-catalog-sync.path = [ stubGit ];
    };

  testScript = ''
    import shlex

    machine.start()
    machine.wait_for_unit("vm-fake-dist.service")
    machine.wait_for_unit("vm-https-stub.service")

    def store_script(unit, prop):
        out = machine.succeed(f"systemctl show -p {prop} --value {unit}").strip()
        lines = [l for l in out.splitlines() if l.strip()]
        return lines

    # 1. PLACEHOLDER skip path --------------------------------------------
    machine.succeed("systemctl start architecture-catalog-sync.service")
    journal = machine.succeed("journalctl -u architecture-catalog-sync --no-pager")
    assert "sync token is PLACEHOLDER" in journal, f"skip not journal-warned: {journal!r}"
    gens = machine.succeed("ls ${stateDir}/generations").strip()
    assert gens == "", f"PLACEHOLDER run must not create generations, got: {gens!r}"
    machine.succeed("test ! -e " + "$${stateDir}" + "/current")

    # Real token from here on (EnvironmentFile re-read on each start).
    machine.succeed(
        "printf 'ARCHITECTURE_CATALOG_SYNC_TOKEN=vmtesttoken\\n' > /etc/vm-sync-token"
    )

    # 7a. bash -n legs on the rendered scripts (before the runs so a
    # syntax defect fails the test at the gate, not mid-scenario).
    sync_exec = store_script("architecture-catalog-sync", "ExecStart")[0].split(";")[0].strip()
    machine.succeed(f"bash -n {sync_exec}")
    col_exec = store_script("architecture-catalog-metrics", "ExecStart")[0].split(";")[0].strip()
    machine.succeed(f"bash -n {col_exec}")
    for pre in store_script("architecture-catalog-sync", "ExecStartPre"):
        pre = pre.strip()
        assert pre.startswith("+"), f"ExecStartPre must stay +-prefixed: {pre!r}"
        machine.succeed(f"bash -n {pre[1:]}")
    # The inline /dev/tcp probe: extract its inner command from the unit
    # text and bash -n it (eval only checks the STRING).
    unit_text = machine.succeed("systemctl cat architecture-catalog-sync")
    probe = ""
    for line in unit_text.splitlines():
        if "bash -c" in line and "/dev/tcp" in line:
            probe = line.split("bash -c '", 1)[1].rsplit("'", 1)[0]
    assert probe != "", f"/dev/tcp probe missing from rendered unit: {unit_text!r}"
    machine.succeed(f"printf '%s' {shlex.quote(probe)} | bash -n")

    # 2. Real-token sync converge (stub clone) ----------------------------
    machine.succeed("systemctl start architecture-catalog-sync.service")
    journal = machine.succeed("journalctl -u architecture-catalog-sync --no-pager")
    assert "serving generation" in journal, f"sync did not converge: {journal!r}"
    current = machine.succeed("readlink ${stateDir}/current").strip()
    assert current.startswith("generations/"), f"current must be a RELATIVE symlink: {current!r}"
    idx = machine.succeed("cat ${stateDir}/current/index.html")
    assert "v1" in idx, f"stub dist did not land: {idx!r}"
    # world-readable files, traversable dirs (Caddy reads the tree)
    machine.succeed("test -r ${stateDir}/current/index.html")
    machine.succeed("test -x ${stateDir}/current")
    gens1 = machine.succeed("ls ${stateDir}/generations").strip().splitlines()
    assert len(gens1) == 1, f"expected 1 generation, got: {gens1!r}"

    # 3. Atomic swap under changed content --------------------------------
    machine.succeed("printf '<html><title>EventCatalog v2</title></html>\\n' > /srv/fake-dist/index.html")
    machine.succeed("systemctl start architecture-catalog-sync.service")
    current2 = machine.succeed("readlink ${stateDir}/current").strip()
    assert current2 != current, f"current did not move on re-publish: {current2!r}"
    idx2 = machine.succeed("cat ${stateDir}/current/index.html")
    assert "v2" in idx2, f"swap did not converge to new content: {idx2!r}"

    # 4. keep-N pruning (maxGenerations = 2) -------------------------------
    machine.succeed("printf '<html><title>EventCatalog v3</title></html>\\n' > /srv/fake-dist/index.html")
    machine.succeed("systemctl start architecture-catalog-sync.service")
    gens3 = machine.succeed("ls ${stateDir}/generations").strip().splitlines()
    assert len(gens3) == 2, f"keep-N pruning failed: {gens3!r}"
    current3 = machine.succeed("readlink ${stateDir}/current").strip()
    assert current3 == f"generations/{gens3[1]}", f"current must survive pruning: {current3!r} vs {gens3!r}"
    assert gens3[0] not in (current, current2), f"oldest generation not pruned: {gens3!r}"

    # 5. Missing index.html → refuse-to-swap fail-closed -------------------
    machine.succeed("rm /srv/fake-dist/index.html")
    machine.fail("systemctl start architecture-catalog-sync.service")
    journal = machine.succeed("journalctl -u architecture-catalog-sync --no-pager")
    assert "refusing to swap" in journal, f"missing-index must refuse loudly: {journal!r}"
    current4 = machine.succeed("readlink ${stateDir}/current").strip()
    assert current4 == current3, f"last-good generation clobbered: {current4!r}"
    machine.succeed("printf '<html><title>EventCatalog v3</title></html>\\n' > /srv/fake-dist/index.html")

    # 6. Collector matrix ---------------------------------------------------
    def run_collector():
        machine.succeed("systemctl start architecture-catalog-metrics.service")
        return machine.succeed("cat /var/lib/prometheus-node-exporter/textfile_collectors/architecture-catalog.prom")

    # 6a. fresh dist
    p = run_collector()
    for needle in ["architecture_catalog_dist_present 1", "architecture_catalog_fresh 1", "architecture_catalog_scrape_errors 0"]:
        assert needle in p, f"fresh dist prom missing {needle!r}: {p!r}"
    # 6b. stale builtAt
    machine.succeed(
        "printf '{\"builtAt\":\"%s\"}\\n' \"$(date -u -d '3 days ago' +%Y-%m-%dT%H:%M:%SZ)\""
        " > " + "$${stateDir}" + "/current/build-stamp.json"
    )
    p = run_collector()
    assert "architecture_catalog_fresh 0" in p, f"stale dist must read fresh 0: {p!r}"
    assert "architecture_catalog_scrape_errors 0" in p, f"stale dist is honest absence, not an error: {p!r}"
    # 6c. unreadable stamp → ONLY scrape_errors 1 (fail-closed)
    machine.succeed("echo '{}' > " + "$${stateDir}" + "/current/build-stamp.json")
    p = run_collector()
    assert "architecture_catalog_scrape_errors 1" in p, f"unreadable stamp must fail closed: {p!r}"
    assert "architecture_catalog_dist_present" not in p, f"value metrics must be omitted on scrape error: {p!r}"
    assert "architecture_catalog_fresh" not in p, f"value metrics must be omitted on scrape error: {p!r}"
    # 6d. absent index → honest 0 / 0 / -1, NOT a scrape error
    machine.succeed(
        "printf '{\"builtAt\":\"%s\"}\\n' \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        " > " + "$${stateDir}" + "/current/build-stamp.json"
    )
    machine.succeed("rm " + "$${stateDir}" + "/current/index.html")
    p = run_collector()
    for needle in ["architecture_catalog_dist_present 0", "architecture_catalog_fresh 0", "architecture_catalog_stamp_age_seconds -1", "architecture_catalog_scrape_errors 0"]:
        assert needle in p, f"absent-index prom missing {needle!r}: {p!r}"

    # Timers exist (the deploy-gated cadence contract)
    machine.succeed("systemctl list-timers | grep -q architecture-catalog-sync")
    machine.succeed("systemctl list-timers | grep -q architecture-catalog-metrics")
  '';
}
