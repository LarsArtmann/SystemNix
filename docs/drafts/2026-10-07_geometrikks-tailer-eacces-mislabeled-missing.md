> [!NOTE]
> This filing was drafted by GLM-5.3-flash via Crush from an AI-run investigation, not at my request. When the failure traces to an external report, that source is linked in the body.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** A log file the process cannot read is reported as "Log file does not exist" and tailed never: `os.path.exists()` swallows `EACCES` to `False`, so the startup wait loop spins forever on a file that is right there, with an error message pointing at the wrong cause. Ask: include the `OSError` (or at least distinguish `ENOENT`) in the waiting log.

## Problem

The startup path in `geometrikks/services/logsources/file.py:108-112` (main, v0.20.0) decides existence with `os.path.exists()`, which returns `False` for *any* `OSError` - `EACCES` included:

```python
# geometrikks/services/logsources/file.py:108-112 (wait_ready)
            self._mark_missing_at_start()
            while not await aiofiles.os.path.exists(self.path):
                if await sleep_unless_stopped(self.poll_interval, stop):
                    return False
```

And the message it logs asserts non-existence with no errno:

```python
# geometrikks/services/logsources/file.py:65-71 (_mark_missing_at_start)
        logger.error(
            "Log file does not exist: %s - waiting for it to appear", self.path
        )
```

The mid-flight counterpart `_mark_missing()` (file.py:73-82) already logs the OS error (`... (%s)`) - the startup path just never reaches it, because the `exists()` gate above blocks first. Same shape on v0.19.0 (`geometrikks/services/logparser/logparser.py:194-199`, `mark_missing`).

Live evidence from our deployment (v0.19.0, service user without read access to `/var/log/caddy`): at every process start, for files that exist, the journal shows

```
[error] Log file does not exist: /var/log/caddy/access.log - waiting for it to appear
```

while the same file simultaneously produced `[Errno 13] Permission denied: '/var/log/caddy/access.log'` on the HTTP path - `Errno 13`, not `Errno 2`. In the retained journal (2026-10-07) the mid-flight "cannot be read" message fired zero times.

## Impact

The message sends the operator hunting for rotation-config or path-typo problems when the actual cause is permissions/capabilities. It cost us real diagnosis time: our first investigation concluded the tailer was silent, because we grepped the journal for read errors - the truth was in "does not exist" lines about files that were never missing.

## Fix / Proposal

1. When `exists()` is `False`, `stat()` once and log the resulting `OSError` (or its `strerror`) in the waiting message - same shape `_mark_missing()` already has.
2. Reword `does not exist` to something like `not readable or absent`, and optionally carry the reason into `SourceStatus` (`"missing"` -> `"permission denied"`).

💘 Generated with Crush (GLM-5.3-flash)
