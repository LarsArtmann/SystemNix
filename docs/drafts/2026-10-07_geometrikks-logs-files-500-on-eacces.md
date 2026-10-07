> [!NOTE]
> This filing was drafted by GLM-5.3-flash via Crush from an AI-run investigation, not at my request. When the failure traces to an external report, that source is linked in the body.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** One unreadable log path makes `GET /api/v1/logs/files` return a raw 500: `_entry()` catches the `OSError` from `stat()`, but the very next line's `Path.is_file()` re-raises it (pathlib only suppresses `ENOENT`/`ENOTDIR`/`EBADF`/`ELOOP`, not `EACCES`). Ask: treat a failed existence check like the already-modeled missing case (`available: false`).

## Problem

`_candidates()` handles a missing file by flipping `available`, but `is_file()` only returns `False` for a small set of errnos and re-raises the rest:

```python
# geometrikks/services/logfiles.py:96-99 (_candidates)
            entry = _entry(path, "access", name=name)
            if not path.is_file():
                entry.available = False
            pairs.append((entry, path))
```

Two lines earlier, `_entry()` (logfiles.py:58-72) catches the same `OSError` from `path.stat()` and degrades gracefully - so permission errors already have a modeled landing spot; they just escape through the follow-up check. `LogsController.list_files` (`geometrikks/domain/system/controllers/logs.py:71-86`) has no error handling, so the request 500s. Live traceback from our deployment (v0.19.0, service running as a non-root user without read access to `/var/log/caddy`):

```
[error] Uncaught exception [litestar] connection_type=http
error="PermissionError: [Errno 13] Permission denied: '/var/log/caddy/access.log'"
path=/api/v1/logs/files
...
logfiles.py:103 in list_files
logfiles.py:97 in _candidates
PermissionError: [Errno 13] Permission denied: '/var/log/caddy/access.log'
[info] HTTP Response [litestar] status_code=500
```

## Impact

A single unreadable path takes down the whole file browser for the UI, even though the response shape already models per-file state (`available: false`). `/health` keeps returning 200, so from the outside the endpoint just looks broken. Observed on v0.19.0; the same code path is on main @ v0.20.0 (2026-10-06), and the traceback frames above match main's line numbers exactly.

## Fix / Proposal

1. In `_candidates()`, wrap the `is_file()` check so any `OSError` sets `entry.available = False` - the same treatment `_entry()` already gives `stat()`.
2. That also protects `resolve()` and `tail_main()`, which iterate `_candidates()` too, so no controller-level `try/except` is needed.

💘 Generated with Crush (GLM-5.3-flash)
