# CV upstream spec — credentials-store write API (`cv` CLI)

_Status: DRAFT for upstream implementation (agents never push; this doc is
the ready-to-implement spec the CV repo work is rowed against —
`docs/todo/upstream.md`). Spec date: 2026-11-09, SystemNix session._

_Why: the store SDK exposes reads but no public create/rotate seam, so
seeding is admin-UI-only, `cv-relogin` refreshes the accounts file but not
the sealed `session_blob`, and `cv credentials status` does not exist. All
three gaps keep D3 (single session store of record) and D6 (human
operability) below superb in the
`docs/audits/credential-session-grading-rubric.md` grading._

## 1) `cv credentials set-password` (F10.3)

```
cv credentials set-password --platform <slug> [--username <login>]
                            [--read-stdin] [--timeout 30s]
```

- **Behavior**: upserts the `kind=password` credential for the platform in
  the ACTIVE store (prompts for username if absent and stdin is a TTY;
  password ALWAYS from a hidden prompt or `--read-stdin`, NEVER an argv flag
  — the fish_history/ps-exposure rule, see the 2026-08-18 incident class).
- **Exit codes**: `0` created/rotated · `10` store not active (typed
  `ErrStoreInactive`, message names CV_CREDENTIALS_STORE_ENABLED) · `20`
  platform slug unknown to the spec registry (names the closest match) ·
  `30` store write failed (schema/IO — full error chain).
- **Output**: one line `stored: platform=<slug> kind=password id=<key-id-8>`
  — NEVER the secret, never a length-leaking field.
- **Rotation semantics**: upsert by (platform, kind); the old ciphertext is
  event-logged in `meta_stream_log` (append-only audit trail), not deleted.
- **Tests to pin upstream**: no-secret-in-argv (ps sweep during run), typed
  exit codes, audit-trail append, TTY-prompt vs stdin shapes.

## 2) Post-relogin `session_blob` rotation (F10.4)

**Flow** (inside `cv profile relogin`, after the browser records a fresh
session cookie):

1. The relogin runner already holds the refreshed cookie in memory
   (`ReloginScriptOptions` wait result).
2. NEW: on success, resolve the store's `kind=session_blob` row for the
   platform; if the ACTIVE store booted, upsert the blob with the fresh
   cookie value (same env-only handoff rules as `CV_RELOGIN_*` — the secret
   transits child env into the store call, never the script file, never a
   log line).
3. Failure to rotate is a WARN (the accounts-file session is still fresh —
   the blob is the SECOND source in the four-source chain), EXCEPT when the
   blob row EXISTS and the store is ACTIVE: then rotation failure fails the
   relogin (a stale blob that outranks a fresh file would silently poison
   the chain).
4. `--no-rotate-blob` flag for operator runs that deliberately only want
   the file.

**Effect**: the ateam cookie chain's fourth source stops being a
one-time-captured artifact that ages forever; D3 convergence for every
platform with a `session_cookie` spec.

## 3) `cv credentials status` (F10.5)

```
cv credentials status [--json]
```

Output shape (human table; `--json` = the same fields):

```json
{
  "storeActive": true,
  "storeDir": "/var/lib/cv/data/credentials-store",
  "keySource": "env",                     // env | state-file | none
  "platforms": [
    {
      "platform": "ateam",
      "kinds": ["password"],              // kinds present
      "sessionBlobAge": null,             // ISO duration or null
      "lastRotatedAt": "2026-11-02T18:31:00+01:00"
    }
  ],
  "readModelEvents": 2                    // meta_stream_log count
}
```

- Read-only; boots the store (fatal under `StoreOn` when the key is broken —
  consistent with the relogin contract).
- Exit codes mirror the relogin contract (`0` / `10` inactive / `30` broken)
  so the SystemNix `cv-credentials-metrics` collector can call it as a
  deeper probe later without new exit-code parsing.

## What this unlocks on the SystemNix side (after upstream lands + lock bump)

- `cv-relogin` needs no change for (2) — it rides the relogin success path.
- A `cv credentials status`-backed collector upgrade replaces the sqlite
  read-model query with the CLI contract (one less schema dependency).
- The seeding walkthrough's "no in-place rotate" caveat (docs/services/cv.md)
  is deleted.
