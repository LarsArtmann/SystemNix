# Drive → Paperless: brutal self-review + comprehensive session status

**Session:** 2026-10-19 00:5x → 01:33 CEST (continuation prompt: "what did you forget / what could you have done better")
**Scope:** THIS session's work only (the drive-paperless pipeline) + what I noticed along the way. No new research beyond it.
**Prior report:** [2026-10-19_01-30_drive-to-paperless-pipeline.md](./2026-10-19_01-30_drive-to-paperless-pipeline.md) (the build narrative; this file is the honest reckoning).

---

## a. FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | `modules/nixos/services/drive-paperless.nix` — ingest module (options, token mint unit, ingest unit+timer, assertions, user, backup-coordination row) | isolated nixosSystem evals green; fixture green |
| a2 | `scripts/test-drive-paperless.sh` — 6-leg fixture (happy path/idempotence, batch drain, size cap, failure injection, revision re-upload, google-sync config-check ×3) | built + ran green via standalone replica |
| a3 | `flake/parts/checks/fixtures-drive-ingest.nix` + flake.nix import line — committed check with eval-side pins | parse-checked; NOT yet built through `.#checks` (see d3) |
| a4 | `configuration.nix` — dormant one-flip coupling (`drive-paperless.enable = config.services.google-sync.enable`) | edit landed via daemon commit |
| a5 | Runbooks: google-sync.md ingest section, paperless.md incoming-import section | committed |
| a6 | TODO harvest (services.md: pre-work row CLOSED, go-live row, VM-test row; TODO_LIST queue: 3 rows), CHANGELOG entry | committed |
| a7 | Pre-work row closure evidence: pool free space 12 TB live-checked; rclone 1.75.2 flags live-checked; config-check fixture-tested against real rclone | session log |
| a8 | Session report 01-30 + this report | on disk |
| a9 | Two live-caught bugs fixed in-flight: `inherit_errexit` metadata hole; rclone `type = drive` listremotes requirement | fixture legs prove both |

## b. PARTIALLY DONE

1. **Verification of the committed check** — the standalone replica ran green, but the COMMITTED `fixtures-drive-ingest.nix` has never been built (blocked by the repo-wide go-standard break, pipeline.md:14). The two files received parallel sed edits and were **never diffed against each other** — a divergence would sit latent until the tree battery runs again.
2. **Docs** — written and committed, but two claims are pending live confirmation (see d5/e): the consume-dir-user wording, and the live paperless version for the API contract.
3. **Go-live enablement** — everything agent-side is wired; the flip itself is user-gated (OAuth) and deploy-gated (go-standard fix).
4. **fmt/lint discipline** — shellcheck re-run manually on my script; the 6 FOREIGN scripts that `nix fmt` canonicalized rode daemon commits (pre-commit bypass class — formatter-only diffs, low risk, but not shellcheck-verified by me).

## c. NOT STARTED (by design / user-gated)

1. OAuth client + `rclone authorize` ×3 + sops fill (USER — cannot be done by an agent).
2. Enable flip + `nix run .#deploy` (also blocked by go-standard break).
3. Live first-run verification (mirror seed 48h, ingest batches, paperless OCR tail, freshness alerting).
4. drive-paperless VM test against real paperless DRF (queued [ready]).
5. Post-deploy battery for the wiring (queued [ready]).
6. Takeout-ZIP extraction (documents inside archives are invisible to the pipeline).

## d. TOTALLY FUCKED UP (found by this self-review — honest list)

1. **REAL BUG — missing `StateDirectory` on the ingest unit.** `systemd.services.drive-paperless` sets `User=drive-paperless` + `ReadWritePaths=[/var/lib/drive-paperless]` but NOT `StateDirectory = "drive-paperless"`. `/var/lib` is root-owned; the script's `mkdir -p "$STATE"` will fail with permission denied on the FIRST live run → unit fails (loudly, but it can NEVER succeed until fixed). `users.users.<x>.home` does not create the directory. **The fixture missed it because it injects STATE via env into a scratch dir, bypassing unit semantics entirely.** Fix is one line + one eval pin; deliberately NOT applied yet (session was told to report and wait).
2. **Eval pins have the same blind spot** — they assert ordering/timer/URL/user but not StateDirectory; the pin set would have caught d1 and didn't.
3. **The committed check was never executed** — all my "green" evidence comes from a throwaway replica in `~/.cache/`; I edited both files in parallel with seds and never diffed them. If the committed variant has a typo'd pin, the check is red the moment the tree battery comes back and someone else gets to debug my file.
4. **configuration.nix + flake.nix edits never parse-checked individually.** The tree-wide eval being red masked them; a syntax error in either would be latent until the next successful eval. (Module + check files WERE parse-checked.)
5. **Unverified claim in my own runbook** — "would change semantics for every other consume-dir user" presumes consume-dir users EXIST; I never grepped for `PAPERLESS_CONSUMPTION_DIR` consumers. The API-route rationale stands on its own; the wording is a premise I didn't verify (the exact class AGENTS.md warns about).
6. **"Stronger than the planned VM test" overclaim** — true ONLY for the google-sync config-check legs (real rclone). The ingest legs run against a STUB API; the VM test remains the only proof of the real DRF contract. My 01-30 report said this precisely; the CHANGELOG sentence blurrs it.
7. **Minor rot I shipped anyway:** `inv_count()` defined but never called (dead code in the test script); `slug = tag: tag` identity function with a comment implying sanitization.
8. **sops scaffold `type = drive` uncertainty** — I instructed "keep `type = drive` per section" but CANNOT verify the encrypted scaffold contains those lines; if it doesn't, the user following the old fill instructions hits a confusing "remote missing" failure. The checklist should say "ADD if absent" and ideally the scaffold should be regenerated.

## e. WHAT WE SHOULD IMPROVE (structural lessons from this session)

1. **Unit-filesystem semantics are untestable by script-level fixtures** — StateDirectory/permissions/umask/races only exist at unit level. House gap: no cheap "unit-shape fixture" layer between eval pins and full VM tests. At minimum: pin StateDirectory/ReadWritePaths ownership pairs eval-side whenever a unit writes.
2. **Parallel-file sed editing is drift-prone** — replica-vs-committed should have been ONE file parameterized, or diff-verified. Rule for next time: after any parallel edit, `diff` is mandatory, not optional.
3. **Red-tree verification protocol** — when repo-wide eval is broken, my isolated evals were right, but parse-level checks for every touched nix file should be reflexive (`nix-instantiate --parse`), not something I remembered for 2 of 4 files.
4. **Assertions > prose** — the perms dependency (rclone lands 0644/0755 via umask; ingest user must READ them) is documented nowhere and pinned nowhere; an umask change upstream would silently blind the ingest.
5. **Shared admin DRF token** — drive-paperless and bank-sync both mint `drf_create_token admin`; rotation couples them and attribution is muddled. A dedicated paperless API user per consumer is the better model (paperless supports it; small upstream-ish change).
6. **Journal design is append-forever** — no compaction, and the per-candidate `grep -qxF` is O(journal) (fine at 100k lines, untested beyond). A client-side sha256 + API dedup pre-check would also avoid wasted uploads for cross-account duplicates (server rejects them anyway, but the read IO is spent).

## f. NEXT (prioritized; ~1h items unless marked)

**P0 — before anything else:**
1. Add `StateDirectory = "drive-paperless"` to the ingest unit (d1) + eval pin (d2); rebuild standalone fixture.
2. `diff` standalone-check.nix vs committed fixtures-drive-ingest.nix pins section; reconcile (d3).
3. Parse-check configuration.nix + flake.nix edits (d4).
4. Fix the runbook consume-dir wording (d5) + CHANGELOG nuance (d6) — two-line edits.
5. Fix checklist wording: "ensure `type = drive` present (add if absent)" (d8); regenerate scaffold if it lacks them.
6. Remove `inv_count()` + `slug` no-op (d7).

**P1 — go-live path:**
7. go-standard toolchain fix decision (owner: goTarballVersion=1.27.2+hash vs nixpkgs bump) — unblocks ALL verification/deploys.
8. USER: OAuth client "In production" + `rclone authorize` ×3 + sops fill.
9. Flip + deploy + post-deploy battery (queued row).
10. VM test drive-paperless (real DRF) (queued row).
11. Confirm live paperless version vs 3.3.1 API contract assumption.

**P2 — hardening/quality:**
12. Eval-pin mirror file read-perms dependency (umask note or assertion).
13. Fixture leg for `ingestImages = true`.
14. Client-side sha256 dedup pre-check before upload.
15. Journal compaction (or periodic `sort -u`) + document growth math.
16. Dedicated paperless API user for drive-paperless (decouple from bank-sync's admin token).
17. TimeoutStartSec sizing for worst-case batch (200×100MB under storm; consider dynamic batch by bytes, not count).
18. Takeout-ZIP extraction option (documents inside archives).
19. Update the stale paperless 3.2.x watch row premise (locked nixpkgs now carries 3.3.1).
20. `failed.log` retention policy (currently per-run truncate — repeated failures visible only via alerts).
21. Consider `docs/services/drive-paperless.md` split when the section outgrows google-sync.md.
22. Re-run shellcheck on the 6 foreign fmt-touched scripts (daemon-bypass belt-and-braces).

**P3 — nice:**
23. Per-top-level-Drive-folder tags (folder→tag mapping beyond the account tag).
24. paperless custom field "Drive path" for provenance.
25. Ingest metrics (uploaded/failed/pending gauges to textfile collector).
26. Syncthing decision (from this session's question): rejected for the pipeline (no Google backend; same-box leg adds nothing) — optionally revisit ONLY for mirror/export fan-out to the MacBook.

## g. QUESTIONS (cannot be figured out from the repo)

1. **Images in scope?** Should scanned-document images from Drive (JPG/TIFF scans — not camera photos) end up in paperless? Today `ingestImages = false` globally; a yes would flip the default or add a folder-allowlist.
2. **Takeout archives:** extract + ingest documents inside Takeout ZIPs sitting in Drive, or leave archives opaque (photos route to Immich via the existing immich-go note)?
3. **go-standard fix preference** (unblocks deploy + all batteries): build the exact toolchain from source (`goTarballVersion = "1.27.2"` + hash) or bump the nixpkgs input (moves floating inputs)? pipeline.md marks this an owner call.
