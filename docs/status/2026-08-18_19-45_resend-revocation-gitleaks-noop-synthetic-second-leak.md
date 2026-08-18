# Session 2026-08-18 19:45 — Resend Key Revocation, gitleaks No-Op Discovery, Second Live Leak (Synthetic)

## Trigger

User received an automated email from Resend: their Pocket ID SMTP API key was
revoked by Resend's GitHub secret-scanning partner program because it sat in
plaintext at commit `cb6b780a` (2026-06-11) in
`docs/status/2026-06-11_02-57_SESSION-131B-SMTP-SOPS-GUARDS-OTEL-BOOT-FIX-COMPREHENSIVE-STATUS.md`.

An agent had pasted the full key (`re_bzp5m1…Eg8u4`) into a "manual sops step"
command block because it could not run sops from its sandbox. The file was later
moved to `docs/status/archive/` with the key intact — live in the public tree
until today.

## What was actually broken (3 layers, all no-ops)

1. **gitleaks config had zero rules** — `.gitleaks.toml` contained only
   `[allowlist]`. gitleaks does NOT auto-load its default ruleset when a config
   file exists, so every scan since the file was created ran with NO rules at
   all. Verified: an AWS-shaped key canary passed cleanly.
2. **Pre-commit hook never exited on failure** — the gitleaks block was
   `if detect; then … elif grep "No leaks found"; then … fi` with no `else`:
   leaks fell through silently.
3. **Custom history scanner had no `re_` pattern** — the 2026-08-18 taxonomy
   scan only looked for the patterns from the first incident audit.

## Second live leak found while fixing it

Re-running gitleaks WITH rules over the tree found the Synthetic LLM gateway key
(`syn_cb0b1e…f8c42`, `CRUSH_DAILY_LLM_API_KEY`) in FIVE status reports
(2026-07-29 x3, 2026-07-30, 2026-08-10) plus the Feb 2026 iTerm2 itermexport
blob. No partner auto-revocation exists for it — **rotation is a manual user
action**.

## Changes

| File | Change |
| ---- | ------ |
| `docs/status/archive/2026-06-11_…md` | Resend key redacted (2 occurrences) |
| `docs/status/archived/2026-07-29_{07-18,19-55,22-05}, 2026-07-30_00-05, 2026-08-10_…md` | Synthetic key redacted (5 files) |
| `.gitleaks.toml` | `[extend] useDefault = true` + `resend-api-key` + `synthetic-api-key` rules (+ per-rule AGENTS.md allowlists for the purge snippets) + false-positive allowlist (SigNoz commit SHA, "Immich/Forgejo" prose) |
| `.githooks/pre-commit` | gitleaks now scans the STAGED TREE via `git checkout-index` + `detect --no-git` and **exit 1** on leaks (full history stays CI's job — history leaks are purge-pending) |
| `scripts/scan-history-secrets.sh` | Added `re_` and `syn_` patterns |
| `AGENTS.md` | Incident table rows (Resend, Synthetic), purge replacements extended, "never write secret values into docs/commit messages" rule |

## Verification

- Staged-tree gitleaks scan: **exit 0, no leaks** (26 MB tree)
- Negative test: random-entropy `re_…` canary staged → **exit 1, blocked**
- Note: gitleaks entropy-filters sequential/placeholder-like values
  (`re_abcdef…` does NOT fire) — intentional, verified at the 30-char threshold
- History scanner: flags Resend (2 blobs) + Synthetic (19 blobs) — expected
  until the filter-repo purge is pushed

## User actions (blocking)

1. **Pocket ID email is BROKEN** — the revoked key is still in sops
   `pocket-id.yaml` (`pocket_id_smtp_password`). Generate a new Resend key,
   then: `SOPS_AGE_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key | ssh-to-age
   -private-key) sops --set '["pocket_id_smtp_password"] "re_NEWKEY"'
   platforms/nixos/secrets/pocket-id.yaml` + `nix run .#deploy`
2. **Rotate the Synthetic key** (crush-daily `synthetic_api_key` +
   `file_renamer_synthetic_api_key` in sops) — still live-assumed
3. **Push the history purge** (procedure in AGENTS.md) — replacements now
   include the Resend + Synthetic keys; it also scrubs the auto-commit daemon's
   commit message that quoted both keys in full (pushed as `85f41a62`)
4. Context7 key rotation (from the 2026-08-18 morning incident) still pending

## Concurrency note

The auto-commit daemon batched `scripts/post-deploy-check.sh` changes (+33
lines, not authored in this session) into the security commit `4d5270fd`, and
pushed both commits mid-session. Not unwound — flagging per the attribution
rule.
