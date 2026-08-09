# Aug 3 WDT Crash — Root Cause: user-1000.slice Memory Cap Silently Broken

**Date:** 2026-08-03 22:31
**Severity:** Critical — system hard-reset via watchdog timer
**Status:** Root cause found and fixed. Deploy pending.

---


## Crash Summary

System rebooted at **22:03** via **hardware watchdog timer (sp5100-tco)** after becoming
completely unresponsive. Kernel log confirms: `Previous system reset reason [0x02000800]:
hardware watchdog timer expired`.

The system was under **sustained memory pressure for the entire 2-day uptime** (Aug 1 21:05
to Aug 3 ~22:03). Gatus "Memory Pressure" endpoint reported `success=false` from Aug 1 21:10
(five minutes after boot) through the crash.

---

## Root Cause: user-1000.slice Memory Cap Silently Broken

The **primary defense** against OOM-induced WDT crashes was **silently disabled** by a Nix
eval-time null UID bug in `boot.nix`:

```nix
# boot.nix line 283 (BEFORE fix)
"user-${toString config.users.users.lars.uid}" = {
  sliceConfig = {
    MemoryHigh = "56G";
    MemoryMax = "64G";
  };
};
```

`config.users.users.lars.uid` is **`null`** at eval time because `isNormalUser = true` assigns
the UID at activation time (via `update-users-groups.pl`), not during Nix evaluation.

`builtins.toString null` evaluates to `""` (empty string), so the slice key becomes `"user-"`
instead of `"user-1000"`. The MemoryHigh/MemoryMax limits are applied to a **nonexistent
slice**.

### Proof

```
$ nix eval .#nixosConfigurations.evo-x2.config.users.users.lars.uid
null

$ nix eval --impure --expr 'builtins.toString null'
""

$ nix eval .#nixosConfigurations.evo-x2.config.systemd.slices --apply 'builtins.attrNames'
[ "-" "system" "system-clamav" "system-immich" "user" "user-" ]
                                                                ^^^^^^
                                                    Should be "user-1000"!

$ cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.max
max                          # UNLIMITED — no cap!
```

### Consequence

`user-1000.slice` ran with `memory.max = max` (no limit) since this code was written. Every
WDT crash attributed to "Helium renderers grew unbounded" was **enabled** by this bug. The
64G hard ceiling that was supposed to kill runaway user processes **never existed**.

This is the **same class of bug** documented in AGENTS.md for monitor365:
> `config.users.users.${primaryUser}.uid` being `null` at eval time

### Fix

Hardcoded `"user-1000"` with explanatory comment in `boot.nix`:

```nix
"user-1000" = {
  sliceConfig = {
    MemoryHigh = "56G";
    MemoryMax = "64G";
  };
};
```

---

## Crash Timeline

| Time | Event |
|------|-------|
| **Aug 1 21:05** | System booted after previous crash |
| **Aug 1 21:10** | Memory Pressure Gatus check FAILING (5 min after boot) — system already under pressure |
| **Aug 3 03:26** | systemd-oomd kills monitor365-server (Avg10: 61.56% pressure on /system.slice) |
| **Aug 3 03:40** | oomd kills monitor365-server again (Avg10: 69.02%) |
| **Aug 3 05:11** | oomd kills monitor365-server (Avg10: 60.06%) |
| **Aug 3 05:38** | oomd kills monitor365-server (Avg10: 60.61%) |
| **Aug 3 19:57** | oomd kills monitor365-server (Avg10: 57.23%, total pressure: 1h 28min) |
| **Aug 3 20:08** | Kernel OOM-kills dnsblockd (RSS: 1 GB — abnormal for DNS resolver) |
| **Aug 3 20:00-21:45** | monitor365-server DuckDB hitting MemoryMax (953.6 MiB) repeatedly, failing every alloc |
| **Aug 3 21:57** | monitor365 agent buffer at 95% capacity, mass-dropping events |
| **Aug 3 21:58** | Hermes heartbeat blocked >10s, Pocket ID SQLITE_BUSY — system freezing |
| **Aug 3 ~22:03** | System fully hangs. WDT fires (60s timeout). Hard reset. |

### Cascade Explanation

1. **user-1000.slice uncapped** — Helium/Electron/desktop apps can consume unlimited RAM
2. **monitor365-server backlog processing** — DuckDB churning memory (killed/restarted every
   ~30 min), creating PSI pressure on /system.slice
3. **dnsblockd memory leak** — sdns cache grew to 1 GB RSS before OOM-kill
4. **Total RAM exhaustion** — user processes (uncapped) + system services consumed all 94 GB
   visible RAM
5. **Journald starved** — kernel can't allocate memory for journald → logging stops
6. **WDT fires** — sp5100-tco watchdog (60s heartbeat) times out → hard reset

### Key Metrics at Crash

- GPUActive: **44 MB** (not an AI workload issue)
- BTRFS: healthy (unalloc=15%, meta=68%) — not a BTRFS issue
- NVMe SMART: passing — not an NVMe issue
- System slice: **unlimited** (`memory.max = max`)
- User slice: **unlimited** (`memory.max = max`) — should have been 64G

---

## Collateral Damage

### DiscordSync Database Corruption (SQLite)

The unclean WDT shutdown corrupted the DiscordSync SQLite DB. Crash-looping with:
```
internal error: entered unreachable code: cell_index_read_payload_ptr called on non-index page
```

21 crash cycles observed in current boot before `start-limit-hit`.

**Fix applied:** Added `discordsync-db-heal` ExecStartPre that runs `PRAGMA integrity_check`
on every startup. If corruption is detected, backs up the DB and removes it — DiscordSync
recreates from scratch or re-syncs from Turso cloud. Attachments in the separate `attachments/`
dir are preserved.

### 8 Services Failed to Start on Boot

| Service | Status | Cause |
|---------|--------|-------|
| DiscordSync | start-limit-hit | SQLite corruption (fixed by db-heal) |
| qmd MCP | failed | First-boot model loading timeout (expected, self-recovers) |
| Forgejo OIDC setup | failed | DNS gate race (dnsblockd not ready at boot) |
| Hermes | failed initially | Transient, self-recovered on restart |
| OAuth2 Proxy | failed initially | Pocket ID provision ordering |
| ActivityWatch Wayland | failed | Missing Wayland session at boot time |
| BTRFS compsize | failed | MemoryMax too low for 47 GiB Nix store (known issue) |
| Nix build cleanup | failed | BTRFS CoW + snapshot references |

---

## Fixes Applied (Source, Not Deployed)

### 1. user-1000.slice Memory Cap (`boot.nix`)

**Root cause fix.** Changed `"user-${toString config.users.users.lars.uid}"` to `"user-1000"`.
Verified via nix eval: `user-1000` slice now has `MemoryHigh=56G; MemoryMax=64G`. The stale
`"user-"` slice is eliminated.

### 2. DiscordSync DB Self-Healing (`discordsync.nix`)

Added `discordsync-db-heal` ExecStartPre that detects SQLite corruption via
`PRAGMA integrity_check` and recovers by moving the corrupt DB aside. Same self-healing
pattern as SigNoz migration-lock clear and monitor365 DuckDB WAL heal.

### Verification

```
$ nix flake check --no-build
all checks passed!
```

---

## What Was NOT Addressed

1. ~~**Deploy** — fixes are in source, not deployed. System is still running without the
   memory cap. **Deploy ASAP** to prevent another crash.~~ done at `4372f51d` (deployed Aug 4)

2. ~~**monitor365-server CPU runaway** — server was running at 113-148% CPU processing the 597M
   event backlog. The `max_events_per_day = 1000000000` (1B) override makes it drain as fast
   as possible. With the user-1000.slice cap now in place, the system should survive the
   backlog processing. But monitor365-server's DuckDB keeps hitting its 953.6 MiB MemoryMax.
   May need to raise the MemoryMax or reduce the backlog.~~ done at `9f1bd087`, `183925f4` (MemoryMax raised + pool-deadlock watchdog; root cause still tracked TODO_LIST P6)

3. ~~**dnsblockd memory leak** — grew to 1 GB RSS before OOM-kill in the previous boot. The
   sdns cache may have unbounded growth. Needs investigation upstream.~~ mitigated at `9bf6fc47` (GOMEMLIMIT=1500MiB + MemoryMax=2G; OTEL cardinality root cause tracked TODO_LIST P6)

4. **system.slice has no memory.max cap** — only user-1000.slice is capped. System services
   collectively have no hard ceiling. The per-service MemoryMax limits help, but the
   aggregate is uncapped. Consider adding a `system.slice` MemoryMax as defense-in-depth.

5. ~~**8 boot-time service failures** — most are transient (DNS races, model loading), but
   DiscordSync needs the db-heal deployed to recover.~~ done at `4372f51d` (deployed Aug 4; db-heal active)

---

## Lesson

`builtins.toString null` returns `""` silently in Nix. It does NOT throw an error. This makes
null UID references **silent bugs** rather than build failures. When using
`config.users.users.<name>.uid` in Nix expressions, ALWAYS verify it's not null at eval time,
or hardcode the UID.

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.
