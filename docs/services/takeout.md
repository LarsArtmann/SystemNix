# Google Takeout — Auth & Download Runbook

Fleet context lives in the TODO library (`docs/todo/services.md`), the registry
(`scripts/takeout-accounts.tsv`), and the fleet plan
(`docs/planning/2026-11-13_multi-account-takeout-fleet-plan.md`). This runbook
owns the ONE hard mechanical lesson of the pipeline: **the rart wall** —
distilled from the racedriver8k marathon
(docs/status/2026-11-11_20-58_takeout-g1-auth-marathon-full-status.md §e3).

## The rart wall (read FIRST, every account)

Google wraps Takeout download URLs in an **interactive re-auth interstitial**:
requesting a part URL with ANY non-browser client returns a `302` whose
`Location` carries `rart=` among its params (typically
`passive/osid/continue/followup/rart`). Proven dead ends — all bounce
identically, do NOT retry this arms-race:

1. curl + cookie jar + fresh `rapt`
2. curl + SAPISIDHASH auth + Origin/Referer/Chrome UA parity
3. headless real Chromium with cookies VERIFIED applied (21 cookies, UA override)
4. `curl_chrome150` TLS/HTTP2 impersonation (curl-impersonate)

The wall is NOT a cookie/fingerprint problem — Google demands a live
password step-up for Takeout exports. **One 302 dump answers this**; the
3-hour client arms-race that preceded the discovery was the avoidable cost.

## Step 1 — the rart-first probe (one command diagnostic)

```bash
bash scripts/takeout-probe.sh <staging-root>
```

The probe's FIRST action is a `--max-redirs 0 -D -` dump of the first export
URL (param-NAMES only — never URL values, never cookies):

- `PROBE: RART WALL — 302 Location params: …` (exit 5) → go to the
  owner-browser flow below. Do not try harder clients.
- `302 without rart` or a direct 200 → the bulk probe continues normally
  (smallest un-held part, zip magic + exact size → installs it).

## Account flow (distilled from racedriver8k)

1. **Request the export** at takeout.google.com; note the expiry (racedriver8k
   export: 2026-11-18 03:13). Register the account + staging root in
   `scripts/takeout-accounts.tsv`.
2. **DOM save**: open the export/download page in the OWNER's logged-in browser
   and save it (Ctrl+S, HTML). Do NOT dictate a filename — the browser default
   ("Google Takeout.html") is fine; intake is glob-based (next step).
3. **Intake (glob, not magic filename)**:
   `bash scripts/takeout-intake.sh --account <account>` installs ANY
   takeout-looking `.html` from `~/Downloads` as `<staging>/links.html`
   (validated, 0600), then extracts the href-form URIs (`i=0..N`, shared
   `rapt`) into `href-uris.txt` → `urls.txt` and renders
   `download-all.html` (23 clickable links) + `parts.tsv` (part → expected
   bytes).
4. **Owner-browser downloads** (the ONLY path through the rart wall): owner
   sets the browser download dir to `<staging>/zips` and clicks the links in
   `download-all.html` top-to-bottom. The `takeout-g1-rename` loop folds raw
   `takeout-*.zip` names into `part-NN.zip` (CRC-checked via `unzip -t`).
5. **Post-first-part**: optionally re-run `takeout-probe.sh` — if the owner's
   re-auth elevated the shared session, remaining parts may go scripted
   (deliberately opportunistic; never assume it).
6. **Verify (G2)**: `bash scripts/takeout-verify.sh <staging>` — CRC over the
   declared parts (from `parts.tsv` filename column), product coverage,
   per-product size bands. Background it, it is hours for large exports.
   An account manifest (export-page product list) upgrades completeness
   from UNPROVEN to proven: `--manifest scripts/takeout-manifests/<account>.products.tsv`
   (tab-separated `product / expected-size / present`; racedriver8k is the
   first resident there). With a manifest in play, a folder the manifest
   does not list is a hard FAIL (the manifest is proven partial) — without
   one, expectations self-derive from the zips with a loud UNPROVEN WARN.
   `--no-hash` skips the SHA256SUMS pass for quick re-runs.

## Fleet status (one command)

```bash
bash scripts/takeout-status.sh            # table: parts N/M, ledger, preflight, last verify
bash scripts/takeout-status.sh --account <a>
```

One line per registered account (from `scripts/takeout-accounts.tsv`): parts
present/declared, ledger rows + bytes, the `takeout-dedup balance --preflight`
verdict (PASS/FAIL/SKIP — SKIP means no zips downloaded yet, G1 outstanding),
and the staging's last verification-report stamp (G2 GREEN/FAIL + date).

## Post-deploy battery (§25)

`scripts/post-deploy-check.sh` carries a Takeout leg: the Immich key
converger's output is asserted (env file 0400 + key line, the
`takeout-import (nix-managed)` api_key row with 16 permissions via
sudo+setpriv psql, WARN-skip without sudo), the mint/converge journal
markers (fresh mint this deploy window, else mint-or-converge inside 30h —
daily timer + 6h jitter), and the balance `--preflight` sweep over every
registered staging with downloaded zips (a MISMATCH blocks any import).

## Traps

- **Never instruct a filename** in the handoff — glob intake exists precisely
  because the browser's default name won what the watcher watched.
- **Sort keys must be bounded**: `sort -n` on tab-joined lines mis-sorts
  (racedriver8k probed the wrong part once); sort by an explicit field.
- **State claims carry the verifying command's output** — "part already held"
  with an empty `zips/` was a red-probe exit, not a hold (§d.1).
- **Trim the cookie jar to the needed domain set on arrival** — probing with a
  full browser jar leaks unrelated cookies into the staging root.
- rart walls recur on EVERY new export request (7-day clock restarts + a NEW
  wall), so this runbook applies per-cycle, not once per account.
