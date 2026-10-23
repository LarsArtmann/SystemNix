# Artifact-level unit test for the shared port guard (lib/port-guard.nix,
# berth-patterns plan T2). Runs the SHIPPED writeShellScript artifacts — the
# fastflowlm guard AND the llama-rag guard — with stubbed ss/cat/kill/sleep
# and asserts all six decision paths:
#
#   foreign-killed    foreign listener → TERM then KILL, port verifies free
#   owner-spared      owner-cgroup listener → never signalled
#   pid-reuse         starttime changes between enumeration and signal →
#                     NO kill, refuse the inherited decision (berth identity)
#   port-free         no listener → inert exit 0
#   unkillable        kill is a no-op against a corpse → BIND-BLOCKED, exit 1
#                     (the flm 2026-09-04 zombie class: name it, fail fast)
#   owner-lingering   foreign killed, owner still draining at verify → exit 0
#
# Stubs are sed-INJECTED into the script text (the writeShellScript wrapper
# bakes absolute store paths, so PATH-level stubs can never shadow them —
# the test-fastflowlm-idle precedent). sed/sort/gawk stay REAL: the pid
# extraction + starttime field-20 parsing must be exercised, not stubbed.
{ pkgs, self }:

let
  flmExec =
    self.nixosConfigurations.evo-x2.config.systemd.services.fastflowlm.serviceConfig.ExecStartPre;
  ragExec =
    self.nixosConfigurations.evo-x2.config.systemd.services.llama-embeddings.serviceConfig.ExecStartPre;
in
pkgs.runCommand "test-port-guard"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnused
      pkgs.gawk
    ];
    meta.description = "Shared port-guard decision-path unit test (stubbed ss/cat/kill/sleep)";
  }
  ''
    set -euo pipefail
    work="$PWD/portguard-test"
    mkdir -p "$work/stubs" "$work/fix"
    export STUBS="$work/stubs" FIX="$work/fix" KILLLOG="$work/killlog"

    inject() {
      # <exec-string> <out-file>: strip the leading '+' and argv, stub the
      # baked store binaries. Assert every stub site took before running.
      local src out n
      src="''${1#+}"
      out="$2"
      sed -e 's|/nix/store/[^ ]*/bin/ss|$STUBS/ss|g' \
          -e 's|/nix/store/[^ ]*/bin/cat|$STUBS/cat|g' \
          -e 's|/nix/store/[^ ]*/bin/kill|$STUBS/kill|g' \
          -e 's|/nix/store/[^ ]*/bin/sleep|$STUBS/sleep|g' \
          "$src" > "$out"
      chmod +x "$out"
      n="$(grep -c '\$STUBS/ss\|\$STUBS/cat\|\$STUBS/kill\|\$STUBS/sleep' "$out" || true)"
      if [ "$n" -lt 8 ]; then
        echo "FAIL: stub injection incomplete for $out ($n/8+ sites)"
        exit 1
      fi
    }

    inject "${flmExec}" "$work/flm-guard"
    inject "${ragExec}" "$work/rag-guard"

    # --- stubs ---
    # ss: call 1 = enumeration, call 2 = release verification (counter file).
    cat > "$STUBS/ss" <<'EOF'
      #!/usr/bin/env bash
      cnt="$(( $(cat "$STUBS/ss.calls" 2>/dev/null || echo 0) + 1 ))"
      echo "$cnt" > "$STUBS/ss.calls"
      if [ "$cnt" = "1" ] && [ -f "$FIX/ss-first" ]; then
        cat "$FIX/ss-first"
      else
        cat "$FIX/ss-verify" 2>/dev/null || true
      fi
    EOF
    # cat: dispatch by path against the fixture tree; a pid listed in
    # $RECYCLE serves a DIFFERENT /proc/<pid>/stat from its second read on.
    cat > "$STUBS/cat" <<'EOF'
      #!/usr/bin/env bash
      path="$1"
      if [[ "$path" == */cgroup ]]; then
        cat "$FIX/proc/''${path##*/proc/}/cgroup" 2>/dev/null || true
        exit 0
      fi
      if [[ "$path" == */stat ]]; then
        pid="''${path#/proc/}"; pid="''${pid%/stat}"
        base="$FIX/proc/$pid"
        if [ -n "''${RECYCLE:-}" ] && [ "$pid" = "$RECYCLE" ]; then
          cnt="$(( $(cat "$base.reads" 2>/dev/null || echo 0) + 1 ))"
          echo "$cnt" > "$base.reads"
          if [ "$cnt" -gt 1 ]; then
            cat "$base/stat2"; exit 0
          fi
        fi
        cat "$base/stat" 2>/dev/null || true
      fi
    EOF
    cat > "$STUBS/kill" <<'EOF'
      #!/usr/bin/env bash
      echo "KILL $*" >> "$KILLLOG"
    EOF
    cat > "$STUBS/sleep" <<'EOF'
      #!/usr/bin/env bash
      exit 0
    EOF
    chmod +x "$STUBS"/*

    # fixture helpers -------------------------------------------------------
    # stat fixture: "<pid> (comm) R <18 fillers> <starttime>" — after the
    # last ') ' the starttime is field 20 (state=1, fillers=2..19, start=20).
    mkstat() {
      local pid="$1" start="$2" dir="$FIX/proc/$1"
      mkdir -p "$dir"
      { printf '%s (rogue-proc) R' "$pid"; seq 1 18 | tr '\n' ' '; printf '%s 999999 999999\n' "$start"; } > "$dir/stat"
    }
    mkcgroup() { mkdir -p "$FIX/proc/$1"; printf '%s' "$2" > "$FIX/proc/$1/cgroup"; }
    listener() { printf 'LISTEN 0 128 127.0.0.1:%s 0.0.0.0:* users:(("rogue",pid=%s,fd=8))\n' "$1" "$2"; }
    FOREIGN_CGROUP="/user.slice/user-1000.slice/user@1000.service/app.slice/hermes-cron.scope"

    expect_rc() { # <expected-rc> <actual-rc> <label>
      if [ "$2" != "$1" ]; then
        echo "FAIL: $3 expected rc=$1 got rc=$2"
        exit 1
      fi
    }

    # 1. foreign-killed -----------------------------------------------------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 52626 111 > "$FIX/ss-first"; : > "$FIX/ss-verify"
    mkstat 111 1000; mkcgroup 111 "$FOREIGN_CGROUP"
    : > "$KILLLOG"
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    expect_rc 0 "$rc" "foreign-killed"
    grep -q "KILL 111" "$KILLLOG" || { echo "FAIL: foreign-killed: no TERM logged"; exit 1; }
    grep -q "KILL -9 111" "$KILLLOG" || { echo "FAIL: foreign-killed: no KILL logged"; exit 1; }
    echo "PASS: foreign listener TERM+KILLed, port verified free"

    # 2. owner-spared (the LIVE case the dry-fire proved) --------------------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 52626 222 > "$FIX/ss-first"; listener 52626 222 > "$FIX/ss-verify"
    mkstat 222 2000; mkcgroup 222 "/system.slice/fastflowlm.service"
    : > "$KILLLOG"
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    expect_rc 0 "$rc" "owner-spared"
    [ -s "$KILLLOG" ] && { echo "FAIL: owner-spared: kill was called"; exit 1; }
    echo "PASS: owner-cgroup listener spared (both enumeration and verify)"

    # 3. pid-reuse: starttime flips between enumeration and signal -----------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 52626 333 > "$FIX/ss-first"; listener 52626 333 > "$FIX/ss-verify"
    mkstat 333 3000; mkcgroup 333 "$FOREIGN_CGROUP"
    mkdir -p "$FIX/proc/333"; printf '%s' "$(cat "$FIX/proc/333/stat" | sed 's/ 3000 / 3999 /')" > "$FIX/proc/333/stat2"
    : > "$KILLLOG"
    export RECYCLE=333
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    unset RECYCLE
    expect_rc 1 "$rc" "pid-reuse"
    [ -s "$KILLLOG" ] && { echo "FAIL: pid-reuse: kill was called on a recycled pid"; exit 1; }
    grep -q "RECYCLED" <<<"$out" || { echo "FAIL: pid-reuse: no RECYCLED log"; exit 1; }
    grep -q "BIND-BLOCKED" <<<"$out" || { echo "FAIL: pid-reuse: no BIND-BLOCKED verdict"; exit 1; }
    echo "PASS: recycled PID spares the new occupant, start fails named (bind-blocked)"

    # 4. port-free -----------------------------------------------------------
    rm -rf "$FIX"; mkdir -p "$FIX"
    : > "$FIX/ss-first"; : > "$FIX/ss-verify"
    : > "$KILLLOG"
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    expect_rc 0 "$rc" "port-free"
    [ -n "$out" ] && { echo "FAIL: port-free: unexpected output: $out"; exit 1; }
    echo "PASS: free port is inert (rc 0, silent)"

    # 5. unkillable corpse (kill is a no-op, listener persists) --------------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 52626 444 > "$FIX/ss-first"; listener 52626 444 > "$FIX/ss-verify"
    mkstat 444 4000; mkcgroup 444 "/user.slice/user-1000.slice/flm-zombie.scope"
    : > "$KILLLOG"
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    expect_rc 1 "$rc" "unkillable"
    grep -q "BIND-BLOCKED" <<<"$out" || { echo "FAIL: unkillable: no BIND-BLOCKED verdict"; exit 1; }
    grep -q "pid 444" <<<"$out" || { echo "FAIL: unkillable: holder pid not named"; exit 1; }
    echo "PASS: unkillable holder named, start fails fast (flm 09-04 zombie class)"

    # 6. owner-lingering at verify ------------------------------------------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 52626 555 > "$FIX/ss-first"; listener 52626 222 > "$FIX/ss-verify"
    mkstat 555 5000; mkcgroup 555 "$FOREIGN_CGROUP"
    mkstat 222 2000; mkcgroup 222 "/system.slice/fastflowlm.service"
    : > "$KILLLOG"
    rc=0; out="$("$work/flm-guard" 52626 2>&1)" || rc=$?
    expect_rc 0 "$rc" "owner-lingering"
    grep -q "KILL 555" "$KILLLOG" || { echo "FAIL: owner-lingering: foreign not killed"; exit 1; }
    grep -q "owner-unit pid 222" <<<"$out" || { echo "FAIL: owner-lingering: no draining log"; exit 1; }
    echo "PASS: owner draining at verify is not a blocker"

    # 7. llama-rag guard: same helper, different owners (spare list) ---------
    rm -rf "$FIX"; mkdir -p "$FIX"
    listener 8848 666 > "$FIX/ss-first"; listener 8848 777 > "$FIX/ss-verify"
    mkstat 666 6000; mkcgroup 666 "/system.slice/llama-embeddings.service"
    mkstat 777 7000; mkcgroup 777 "$FOREIGN_CGROUP"
    : > "$KILLLOG"
    rc=0; out="$("$work/rag-guard" 8848 2>&1)" || rc=$?
    expect_rc 1 "$rc" "rag-owners"
    [ -s "$KILLLOG" ] && { echo "FAIL: rag guard killed its own embeddings listener"; exit 1; }
    grep -q "BIND-BLOCKED.*777" <<<"$out" || { echo "FAIL: rag guard missed foreign 777 at verify"; exit 1; }
    echo "PASS: llama-rag spare list matches its own units, flags foreign at verify"

    echo "ALL PORT-GUARD LEGS PASSED"
    touch "$out"
  ''
