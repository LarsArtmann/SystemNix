# Forgejo upstream issue drafts — mirror-outage trio (verified 2026-09-18)

> Re-verified 2026-09-18 (second session): all three code claims independently checked against the live
> `forgejo` branch (mirror_pull.go, mirror.go, command.go fetched from codeberg.org) — UNCHANGED, drafts accurate.

Three issues from the 2026-08-22 mirror outage (`docs/status/archived/2026-08-22_08-52_*` §b2/§c),
verified against the CURRENT upstream `forgejo` branch (codeberg.org/forgejo/forgejo, checked
2026-09-18) per the verify-before-filing protocol. **Not yet filed — no Codeberg account/token
exists on this machine** (TODO_LIST P1, blocked on the account decision). When filing: paste each
draft into `POST /api/v1/repos/forgejo/forgejo/issues` (needs a token with issue write) or the
Codeberg web UI. No duplicates found for any of the three mechanisms (Codeberg issue search,
2026-09-18: `TouchMirror` → 0 hits; `forgejo-clone-credentials` → 0 hits; "mirror queue stuck" →
only unrelated results).

All three share one incident context (14-day silent pull-mirror outage, ~2,400 error lines/day,
Forgejo 15.0.6, self-hosted NixOS, systemd unit with `PrivateTmp=true`, 134 pull mirrors, 30-min
`update_mirrors` cron). Each issue stands alone; cross-link them when filing.

---

## Issue 1 — `TouchMirror` on failed sync advances `mirror.updated_unix`, masking outages from API consumers

### Problem

`SyncPullMirror` treats a failed sync the same as a successful one from the API's point of view.

`services/mirror/mirror_pull.go` (current `forgejo` branch):

```go
results, ok := runSync(ctx, m)
if !ok {
    if err = repo_model.TouchMirror(ctx, m); err != nil {
        log.Error("SyncMirrors [repo: %-v]: failed to TouchMirror: %v", m.Repo, err)
    }
    return false
}
```

`models/repo/mirror.go`:

```go
func TouchMirror(ctx context.Context, m *Mirror) error {
    m.UpdatedUnix = timeutil.TimeStampNow()
    _, err := db.GetEngine(ctx).ID(m.ID).Cols("updated_unix").Update(m)
    return err
}
```

On success, `runSync` also sets `m.UpdatedUnix = timeutil.TimeStampNow()`. So the API field
`mirror_updated` (GET /api/v1/repos/{owner}/{repo}, and the repo settings UI) shows the time of
the last sync ATTEMPT, never distinguishing a fetch that succeeded from one that failed for
days.

### Why this matters (real incident)

We ran a self-hosted Forgejo where every credentialed pull-mirror sync aborted for 4 days
(temp-file failures, see companion issue), then the mirror queue wedged entirely for ~9.5 h. A
monitoring script checked `mirror_updated` via the API as the freshness signal — it kept
advancing the whole time, because every failed sync still called `TouchMirror`. The outage was
invisible to the API and to the UI's "Updated" column; the repo page reported healthy freshness
while zero commits had arrived for days. I initially "verified mirrors were fine" from that
field and was wrong exactly because of this behavior.

### Suggestion

Keep a separate `last_success_unix` (or an `last_sync_result` column) and expose it in the API;
leave `updated_unix` as-is for compatibility if preferred. Minimal alternative: stop
`TouchMirror` on failure and only update `updated_unix` on success — but that changes the
`MirrorsIterate` ordering (`OrderBy("updated_unix ASC")` picks least-recently-attempted), so a
dedicated success column is the safer shape.

- Version: observed on 15.0.6; code identical on the current `forgejo` branch (checked 2026-09-18).

---

_Drafted with AI assistance (Crush); source claims verified against the `forgejo` branch on 2026-09-18._


---

## Issue 2 — mirror queue: `ErrAlreadyInQueue` dedup-skip logs at Trace level only, so a wedged queue silently stops ALL mirror syncs

### Problem

Pull- and push-mirror syncs go through one unique queue
(`services/mirror/queue.go`: `queue.CreateUniqueQueue(..., "mirror", ...)`). The 30-min
`update_mirrors` cron (`services/mirror/mirror.go` `Update()`) pushes every due mirror into it:

```go
if err := PushToQueue(mirrorType, referenceID); err != nil {
    if err == queue.ErrAlreadyInQueue {
        ...
        log.Trace("PullMirrors for %-v already queued for sync", repo)
        return nil
    }
    return err
}
```

If a queued item is never consumed — e.g. the queue worker wedged after a hard process kill, or
an item is stuck mid-sync — every subsequent cron tick dedup-skips at `log.Trace` and returns
nil. At the default `LEVEL = info` this produces **zero journal output** while mirror syncing is
completely dead. The only observable signal is `mirror.updated_unix` going stale — which,
combined with the companion `TouchMirror` issue, can be fully absent if failures were happening
before the wedge.

### Why this matters (real incident)

After a hard-freeze night with several forgejo restarts, the mirror queue on our instance
wedged: for ~9.5 h every 30-min cron fired, every push dedup-skipped silently, and nothing ran.
`journalctl -u forgejo -p info` showed a perfectly healthy service; the web UI was green. We
only found it because a second outage class had primed us to diff `mirror_updated` against wall
time. A `log.Trace` for "the thing that keeps your mirrors working is not consuming" is not
observably different from no log at all.

### Suggestion

Any of these would have caught it:

1. Count dedup-skips per `Update()` run and log a single Warn when a run skipped >0 mirrors that
   were already "queued" — sustained skipping across runs is the wedged-queue signature.
2. Or log `ErrAlreadyInQueue` at Info instead of Trace (it is rare in a healthy system and cheap).
3. Or add a staleness watchdog: a mirror whose `next_update_unix` is in the past for > N ×
   interval without its `updated_unix` advancing gets an Error log / repository notice.

- Version: observed on 15.0.6; code identical on the current `forgejo` branch (checked 2026-09-18).

---

_Drafted with AI assistance (Crush); source claims verified against the `forgejo` branch on 2026-09-18._


---

## Issue 3 — `AddAuthCredentialHelperForRemote` temp-file failure aborts the whole mirror sync with only a log line (no repository notice)

### Problem

For credentialed HTTP mirrors, `runSync` calls
`Command.AddAuthCredentialHelperForRemote` (`modules/git/command.go`), which creates a
credential-store file with `os.CreateTemp("", "forgejo-clone-credentials-")`:

```go
credentialsFile, err := os.CreateTemp("", "forgejo-clone-credentials-")
if err != nil {
    return "", nil, err
}
```

and `runSync` (`services/mirror/mirror_pull.go`) turns any error here into a full sync abort:

```go
_, credCleanup, err := cmd.AddAuthCredentialHelperForRemote(remoteURL.URL.String())
if err != nil {
    log.Error("SyncMirrors [repo: %-v]: AddAuthCredentialHelperForRemote Error %v", m.Repo, err)
    return nil, false
}
```

Contrast the actual fetch failure path a few lines below, which additionally calls
`system_model.CreateRepositoryNotice(...)` — surfacing the problem in the admin dashboard and
repo notices. A credential-helper setup failure produces only the log Error: no repository
notice, so an operator who does not watch raw logs never learns their mirrors are dead (and per
the companion `TouchMirror` issue, the API shows no staleness either).

### Why this matters (real incident)

On our instance (forgejo 15.0.6, systemd unit with `PrivateTmp=true`), `os.CreateTemp` inside
the unit's private `/tmp` started failing with ENOENT — onset occurred mid-process-lifetime with
no restart (an external cleaner had removed the unit's `systemd-private-*` backing directory,
leaving the namespace's `/tmp` unlinked). Result: every credentialed mirror sync aborted
instantly for days, ~2,400 `AddAuthCredentialHelperForRemote Error ... no such file or
directory` lines/day, while the service, UI, and API all looked healthy. The root trigger was
environmental, but the upstream-facing gaps are real regardless of trigger: (a) a fail-closed
temp file is treated as fatal for the sync with no user-visible notice, and (b) the generic
`no such file or directory` gives no hint that `/tmp` writability is the thing to check.

### Suggestion

1. On `AddAuthCredentialHelperForRemote` error, also `CreateRepositoryNotice` (matching the
   fetch-failure path) so the failure is visible in the admin dashboard.
2. Consider wrapping the error with context, e.g. `fmt.Errorf("creating git credential helper
   temp file (TMPDIR=%q): %w", os.TempDir(), err)` — it turns an opaque ENOENT into a
   self-diagnosing message.

- Version: observed on 15.0.6; code identical on the current `forgejo` branch (checked 2026-09-18).

---

_Drafted with AI assistance (Crush); source claims verified against the `forgejo` branch on 2026-09-18._

