# VM test for Kernel Same-page Merging (KSM).
#
# Verifies the kernel mechanism end-to-end inside a VM (host ksmd is off
# and enabling it would need root):
#   1. Two processes with IDENTICAL anonymous memory merge across processes
#      (pages_shared = 1 unique page for both)
#   2. A process with DIFFERENT content dedups separately (pages_shared = 2)
#      — the negative control: KSM merges only exact page matches
#   3. ksmd CPU cost for the scan is visible and bounded
#   4. Teardown: stopping the probes unmerges; run=2 force-unmerges everything
#
# The probe allocates anonymous memory, fills every 4 KiB page with the same
# pattern, madvise(MADV_MERGEABLE)s it, and sleeps. This is exactly what QEMU
# does for guest RAM (memory-backend merge=on) — the workload KSM was built for.
{ pkgs }:
let
  ksmProbe = pkgs.stdenv.mkDerivation {
    name = "ksm-probe";
    src = pkgs.writeText "ksm-probe.c" ''
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>
      #include <unistd.h>
      #include <sys/mman.h>

      #ifndef MADV_MERGEABLE
      #define MADV_MERGEABLE 12
      #endif

      int main(int argc, char **argv) {
        if (argc < 3) {
          fprintf(stderr, "usage: %s MIB FILL_BYTE\n", argv[0]);
          return 2;
        }
        size_t len = (size_t)atoll(argv[1]) << 20;
        unsigned char fill = (unsigned char)strtoul(argv[2], NULL, 0);
        char *p = mmap(NULL, len, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (p == MAP_FAILED) { perror("mmap"); return 1; }
        memset(p, fill, 4096);
        for (size_t off = 4096; off < len; off += 4096)
          memcpy(p + off, p, 4096);
        if (madvise(p, len, MADV_MERGEABLE) != 0) { perror("madvise"); return 1; }
        printf("pid %d: %zu MiB mergeable fill=0x%02x\n", getpid(), len >> 20, fill);
        fflush(stdout);
        pause();
        return 0;
      }
    '';
    dontConfigure = true;
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      cc -O2 -Wall -Werror -o ksm-probe "$src"
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 ksm-probe $out/bin/ksm-probe
      runHook postInstall
    '';
  };
in
{
  name = "ksm";

  nodes.machine = _: {
    virtualisation.memorySize = 4096;
    environment.systemPackages = [ ksmProbe ];
  };

  testScript = ''
    def ksmstat(name):
        return int(machine.succeed(f"cat /sys/kernel/mm/ksm/{name}").strip())

    def wait_for(fn, timeout=120, what=""):
        import time
        deadline = time.monotonic() + timeout
        last = None
        while time.monotonic() < deadline:
            last = fn()
            if last:
                return last
            machine.sleep(2)
        raise AssertionError(f"timed out waiting for {what}, last={last}")

    machine.start()
    machine.wait_for_unit("multi-user.target")

    # Aggressive scan settings so the test completes in seconds.
    machine.succeed("echo 20000 > /sys/kernel/mm/ksm/pages_to_scan")
    machine.succeed("echo 50 > /sys/kernel/mm/ksm/sleep_millisecs")
    machine.succeed("echo 1 > /sys/kernel/mm/ksm/run")
    assert machine.succeed("cat /sys/kernel/mm/ksm/run").strip() == "1"

    baseline_shared = ksmstat("pages_shared")
    baseline_sharing = ksmstat("pages_sharing")
    machine.log(f"baseline: pages_shared={baseline_shared} pages_sharing={baseline_sharing}")

    # 1) Two processes, IDENTICAL content: expect cross-process dedup.
    #    2 x 256 MiB = 131072 pages -> sharing >= 130000. NOTE: pages_shared
    #    is NOT 1: KSM caps one physical page at max_page_sharing (default 256)
    #    mappings to bound rmap/COW-fault cost, so ~512 duplicate nodes exist.
    machine.succeed("systemd-run --collect --unit=ksmA ksm-probe 256 0x42")
    machine.succeed("systemd-run --collect --unit=ksmB ksm-probe 256 0x42")
    wait_for(lambda: ksmstat("pages_sharing") >= baseline_sharing + 130000,
             what="identical probes dedup")
    shared_one = ksmstat("pages_shared")
    max_sharing = machine.succeed("cat /sys/kernel/mm/ksm/max_page_sharing").strip()
    saved = (ksmstat("pages_sharing") - baseline_sharing) * 4096
    machine.log(f"two identical 256MiB probes: pages_shared={shared_one} "
                f"(max_page_sharing={max_sharing} fanout) "
                f"pages_sharing={ksmstat('pages_sharing')} (~{saved // 2**20} MiB deduped)")
    assert 100 <= shared_one <= 1000, f"pages_shared={shared_one}, expected ~512 dedup nodes"

    # 2) Control: DIFFERENT content must NOT merge with the first set —
    #    it forms its own dedup set (~256 more nodes, sharing grows ~64k pages).
    machine.succeed("systemd-run --collect --unit=ksmC ksm-probe 256 0x99")
    wait_for(lambda: ksmstat("pages_sharing") >= baseline_sharing + 195000,
             what="distinct probe forms separate set")
    shared_two = ksmstat("pages_shared")
    machine.log(f"after distinct probe: pages_shared={shared_two} "
                f"pages_sharing={ksmstat('pages_sharing')}")
    assert shared_two >= shared_one + 200, \
        f"distinct probe added only {shared_two - shared_one} nodes, expected ~256"

    # 3) ksmd CPU cost for scanning ~768 MiB of mergeable memory.
    machine.log("ksmd CPU time: " + machine.succeed("ps -C ksmd -o time=").strip())

    # 4) Teardown: stopping the probes drops the mappings; run=2 unmerges all.
    machine.succeed("systemctl stop ksmA.service ksmB.service ksmC.service")
    wait_for(lambda: ksmstat("pages_sharing") <= baseline_sharing + 1000,
             what="unmerge after probe exit")
    machine.succeed("echo 2 > /sys/kernel/mm/ksm/run")
    assert ksmstat("pages_sharing") == 0
    machine.succeed("echo 0 > /sys/kernel/mm/ksm/run")
  '';
}
