# PMA Memory & CPU Investigation

**Date:** 2026-08-01 21:20  
**Service:** `projects-management-automation.service` (PMA)  
**Trigger:** `systemctl status` showed `Memory: 11.9G (max: 12G, available: 1.6M, peak: 12G)` with `8min 33s CPU` in `4min 43s` wall time  

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## TL;DR

The 12G "memory" is almost entirely **Linux page cache**, not process heap. PMA's actual RSS is **367 MB**. The cgroup v2 memory accounting charges file-cache reads (from scanning 260 git repos) against `MemoryMax`, making the service appear memory-exhausted when it is not.

A secondary issue — a **commit retry death-loop on go-cqrs-lite** — drives the CPU cost and generates continuous `git status` / `git diff` subprocess spawns + go-git index walks.

---

## Evidence

### cgroup memory breakdown (`memory.stat`)

| Metric | Value | Meaning |
|--------|-------|---------|
| `memory.current` (at investigation time) | 3.1 GB | Total cgroup memory (was 11.9 GB at peak) |
| **`anon`** | **367 MB** | Process heap + stack — the *real* footprint |
| `file` (page cache) | 2.6 GB (was ~10 GB at peak) | Cached git object/index/worktree reads |
| `slab_reclaimable` | 297 MB | Inode/dentry cache from scanning 260 directories |
| `read_bytes` | 16 GB | Total disk reads since service start |

### Process-level (`/proc/1544/status`)

| Metric | Value |
|--------|-------|
| `VmRSS` | 395 MB |
| `VmHWM` | 10.7 GB (peak RSS — includes reclaimable page cache) |
| `Threads` | 50 |

### File descriptors

Only 10 FDs open. One `inotify` FD watching `/home/lars/projects`. No FD leak.

---

## Root Causes (cascade order)

### 1. Discovery daemon scans 260 projects on every startup

PMA's co-located discovery daemon re-scans all ~260 projects in `/home/lars/projects/` on each restart. Each scan reads git objects, indexes, and worktree files. This loaded **16 GB of disk data** into the page cache, which cgroup v2 charges against the 12G `MemoryMax`.

When page cache fills to the ceiling, new reads can't allocate cache pages → go-git file operations fail with **EOF** errors:

```
stage file crates/db/src/compliance.rs: EOF
stage file crates/config/src/tests/config_tests.rs: EOF
get status: EOF
```

### 2. go-git `PlainOpen()` called per batch with no caching/reuse

Every batch triggers `committer.newCommitHandler(projectPath)` → `commit.New(projectPath)` → `git.NewGoGit(repoPath)` → `git.PlainOpen(path)` (`gogit.go:49`).

go-git's `PlainOpen` loads the full repository object (refs, config, object database) into memory. There is **no `Close()`** on the returned `*git.Repository`, and PMA creates a new one per batch. With 8 concurrent workers, up to 8 repos are open simultaneously, and Go's GC is the only reclamation path.

### 3. go-cqrs-lite commit death-loop

From the logs, `go-cqrs-lite` was processed **7+ times in 90 seconds** (21:10:12, 21:11:06, 21:11:23, 21:11:29, 21:11:38, 21:11:50, 21:11:58). Each cycle:

1. Watcher detects file change → enqueues batch
2. `processBatch` → `committer.Commit()`
3. Commit fails with `"commit not successful"` (see #4)
4. Files are still dirty → next watcher event → re-enqueue → repeat

The same pattern repeats for `projects-management-automation` itself (self-modifying) and `monitor365`.

### 4. "commit not successful" error swallows the real cause

`committer.go:206-211`:

```go
if !commitResult.IsSuccess() {
    result.Status = StatusFailed
    result.Error = oops.New("commit not successful")  // ← discards commitResult.Error
    return result, nil
}
```

`commitResult.Error` (the actual git/LLM failure reason) is **never logged**. `oops.New()` creates a fresh error with no wrapped cause. This makes every commit failure look identical in the logs, preventing diagnosis of the *real* failure (likely the EOF from memory pressure, or an LLM API error).

### 5. Each commit spawns expensive subprocesses + LLM calls

A single `processBatch` for one project does:

| Step | Implementation | Cost |
|------|---------------|------|
| `HasChanges` | go-git `worktree.Status()` — walks full index | Memory + CPU |
| `GetContext` → `getStagedDiff` | `exec.Command("git", "diff", "--staged")` | Subprocess |
| `GetContext` → `getFullDiff` | `exec.Command("git", "diff")` | Subprocess |
| `GenerateCommitMessage` | LLM API call (network roundtrip) | 2-20s latency |
| `StageAll` | go-git `worktree.Add()` per file — reads each file | Memory + IO |
| `Commit` | go-git `worktree.Commit()` | CPU |
| `getAuthorSignature` | `exec.Command("git", "config", "user.name")` + `"user.email"` | 2 subprocesses per commit |

For `monitor365` (large Rust repo), a single commit took **2 minutes 23 seconds**.

### 6. CPU summary

8 worker goroutines × the above pipeline = `8min 33s CPU` in `4min 43s` wall time = **~182% average** (nearly 2 cores). The `harden {}` default `CPUQuota=200%` caps this correctly, but the work itself is inherently expensive when repos are large and commits retry-loop.

---

## Recommended Fixes

### Priority 0 — Immediate (SystemNix)

**Raise or remove `MemoryMax`.** The 12G cap throttles page cache, not process memory. RSS is 367 MB.

```nix
# modules/nixos/services/projects-management-automation.nix
# Either remove the MemoryMax override entirely (let harden{} defaults apply)
# or raise it to account for page cache from 260 repos:
MemoryMax = lib.mkForce "16G";
```

The `harden {}` default `CPUQuota=200%` already prevents CPU runaway.

### Priority 1 — Upstream (go-commit)

**Fix error swallowing in `committer.go:208`.** Replace:

```go
result.Error = oops.New("commit not successful")
```

with:

```go
result.Error = oops.Wrap(commitResult.Error, "commit not successful")
```

This ensures the actual git/LLM error is logged, enabling diagnosis.

### Priority 2 — Upstream (PMA)

**Reuse go-git repository handles.** `PlainOpen` is expensive and should not be called per batch. Either:

- Cache `*git.Repository` per project path in the committer
- Or add a `Close()` method and defer it in `processBatch`

**Investigate the go-cqrs-lite commit loop.** Why does `commitResult.IsSuccess()` return false? Possible causes:
- LLM API error (network, auth, rate limit)
- The EOF errors from memory pressure (would be fixed by Priority 0)
- go-git commit failing on a locked index file

### Priority 3 — Configuration

**Narrow watched paths.** 260 projects is excessive for auto-commit. Consider:

- Excluding repos that rarely change (archived, forks, vendored)
- Splitting into multiple PMA instances with smaller path sets
- Using a more targeted `paths` list instead of the entire `/home/lars/projects/`

**Reduce worker count.** 8 workers on 260 repos means up to 8 concurrent `git diff` + LLM calls. Consider 2-4 workers for lower memory/CPU pressure.

---

## References

- `modules/nixos/services/projects-management-automation.nix` — SystemNix wrapper
- `/home/lars/projects/projects-management-automation/internal/service/committer/committer.go:206-211` — error swallowing
- `/home/lars/projects/projects-management-automation/internal/service/service_batch.go:127-139` — batch worker loop
- `/home/lars/projects/go-commit/pkg/commit/git/gogit.go:48-49` — `PlainOpen` per call
- `/home/lars/projects/go-commit/pkg/commit/git/diff.go:14-21,45-52` — subprocess diff calls
- `/home/lars/projects/go-commit/pkg/commit/git/gogit_stage.go:36-55` — `StageAll` walks full index
- `/home/lars/projects/go-commit/pkg/commit/commit.go:99-140` — `Execute` pipeline
