# Status: sops manifest deploy-blocker fix + sops-key-audit remap blindspot

**Date:** 2026-10-17 03:39 CEST
**Session scope:** single dispatch — owner pasted a failing `nix log` for the sops `manifest.json.drv` and said "fix". No other research performed (owner instruction).
**Trigger evidence:** `sops-install-secrets: manifest is not valid: secret ai-meter-openrouter-key in …-openseo.yaml is not valid: the key 'openrouter_api_key' cannot be found`

---

## Root cause (two layers)

1. **The incident**: the 2026-10-16/17 ai-meter build session declared a sops copy `ai-meter-openrouter-key` → `openseo.yaml` key `openrouter_api_key`, but that key was NEVER set in the encrypted file (`openseo.yaml` holds only `dataforseo_api_key`). Its own status report flagged this exact risk ("DECRYPTED values were never eyeballed — deploy will prove them"); the deploy proved it.
2. **Why the eval gate stayed green**: `sops-key-audit.nix` (shipped 2026-09-04 to catch exactly this class) skipped EVERY remapped key via `secret.key != name → null`. All four ai-meter copies are remapped — three passed by luck (crush.yaml really has zai/gemini/kimi), the fourth was invisible. The negative test even codified the skip under a lying name (`nested-key-not-skipped` testing a FLAT remap). The AGENTS.md Prevention Layers table's claim "sops keys declared but missing from encrypted files [caught at eval]" was FALSE for remapped copies for ~6 weeks.

## a) FULLY DONE

| Work | Evidence |
| --- | --- |
| Root-cause chain: manifest FOD → ai-meter copy → openseo.yaml key census (plaintext key names, no decrypt needed) | `grep '^[a-zA-Z_]+:' openseo.yaml` → only `dataforseo_api_key`; crush.yaml has zai/gemini/kimi/minimax/mimo |
| Owner decision honored: drop the openrouter upstream (option B of paste-key vs drop) | question tool, owner picked "drop" |
| `ai-meter.nix`: openrouter upstream block + sops copy entry removed; header comment truth-synced (records the incident + the re-add precondition) | diff in commit `44428273` |
| `docs/services/ai-meter.md` runbook: upstream map + secrets section synced, drop documented with the never-set-key reason | same commit |
| `sops-key-audit.nix` tightened: flat remapped keys (`key = "yaml_key"`) now checked against the top-level scan; ONLY dotted nested keys (`a.b`) skipped; failure message names secret AND key | `modules/nixos/services/sops-key-audit.nix` |
| Negative test rebuilt: misnamed case fixed (`flat-remap-present-falsely-flagged`), incident shape added (`remapped-missing-key-not-caught` — must FAIL naming both), true nested skip case added; 6/6 green | `nix build .#checks.x86_64-linux.sops-key-audit` → `sa18b9h1…-sops-key-audit-negative-test` |
| Eval gate green with tightened audit across all evaluated hosts | `nix flake check --no-build` → "all checks passed" (×2 runs: pre- and post-audit-fix) |
| **Deploy blocker PROVEN gone**: evo-x2 toplevel built with `--keep-going` → success; the BUILT manifest artifact greps: 0 `openrouter` entries, `ai-meter-{zai,kimi,gemini}-key` intact | toplevel `/nix/store/i4xlx7w6q9z3xx429yhqnym9p8412sba-nixos-system-evo-x2-26.11.20261014.55bfb4d`, manifest `ars56r1rn79d191jkf6dvlkwadd12rlb-manifest.json` |
| Scoped format clean | treefmt "0 changed" on second run |
| Darwin sops-audit coverage question closed by verification: `platforms/darwin/` has ZERO sops references → no unaudited surface | `rg -ln sops platforms/darwin/` → empty |
| Parallel-session contamination flagged, not touched: daemon commit `44428273` swept my 2 files together with `display-manager-heal.nix`/`.sh` (another session's work); `flake.lock` auto-bump `5e5fb7bb` noted (already inside the green toplevel build) | `git log -3 --stat` |

## b) PARTIALLY DONE

- **ai-meter deploy chain** — blocker cleared, chain itself still open and owned by `docs/todo/ai-stack.md` row "ai-meter BLOCKER: client-key permission design fix + deploy chain" (`TODO_LIST.md` mirror at line 1432): deploy + anchor verify + live chain (keys minted / /health / SigNoz series / gatus / real traffic through the proxy). Not mine to execute without owner go.
- **Upstream-key VALUE verification** — I proved key-NAME presence only (plaintext names); the three surviving copies' decrypted values remain un-eyeballed. The live chain's first real proxy request is the proof. (Inherited from the build session; re-flagged here.)
- **"2 changed" formatter attribution** — the first scoped `nix fmt` run reported 2 changed files while I had edited ai-meter.nix only. The daemon swept the tree minutes later, destroying the diff evidence. Deduction says file #2 was ai-meter.md (treefmt also formats md) — plausible but UNPROVEN; the 200-line `display-manager-heal.sh` churn in the same sweep commit cannot be attributed to me or the other session post-sweep. Flagged for owner; do NOT treat this as verified.

## c) NOT STARTED

- `nix run .#deploy` (owner-gated timing).
- Post-deploy live verification chain (see row in ai-stack.md).
- OpenRouter re-add path — deliberately NOT executed: requires the owner to set `openrouter_api_key` in `openseo.yaml` first (user-held value; sudo + interactive sops only; recipe recorded in ai-meter.md and the module header).

## d) TOTALLY FUCKED UP

Nothing destructive this session. The honest indictments:

1. **The repo shipped a false prevention-layer claim for ~6 weeks.** The audit existed since the 2026-09-04 incident, its negative test asserted the WRONG semantics under a name that said the opposite of what it tested, and AGENTS.md advertised coverage it didn't have. Nobody noticed because no remapped secret was ever wrong — until today, when the failure surfaced at the WORST layer (deploy FOD) instead of eval. That is exactly the "lint says X but doesn't" class the repo's own doctrine warns about.
2. **My first move was a predictably-futile decrypt attempt** (sudo/ssh-to-age one-liner) despite `sudo` being on the known parse-guard list. One wasted call, noisy failed-decrypt output (no values leaked — nothing decrypted). The plaintext-key-names check I ran SECOND should have been FIRST.
3. **Malformed question-tool call** (missing `type`) — one wasted round trip.
4. **Left an observation unverified** ("2 changed" formatter files) until the daemon sweep destroyed the evidence — see b). Verification debts compound; this one became permanently unanswerable.
5. **Did I lie?** No — every claim above has a command + output behind it. The one soft spot is the fmt-attribution deduction, explicitly labeled UNPROVEN.

## e) WHAT WE SHOULD IMPROVE

1. **Triage sops failures by plaintext key names FIRST** — sops encrypts values, never key names; `grep '^[a-z_]+:' <file>` answers "is the key there" with zero credentials. The decrypt attempt was theater.
2. **A skip predicate must encode the real boundary.** `key != name → skip` encoded "remapped = unverifiable"; the TRUE boundary is "dotted key = not top-level-scannable". The wrong variable in a guard turned a 3-line check into a 6-week blind spot. (Same lesson as the data-model doctrine: model the axis, not the instance.)
3. **Prevention-layer claims need their negative-test shape re-proven when a NEW declaration shape appears** (here: `builtins.listToAttrs`-generated remapped copies). New shape → re-run the class's negative test against the shape before trusting the gate.
4. **Verify formatter churn precisely or don't claim scoping** — after any `nix fmt`, diff WHAT changed when the count exceeds files-I-touched, BEFORE anything else can sweep the tree.
5. **Decision questions should present the full option space** — populate / drop / make-the-upstream-opt-in. I offered two; the opt-in-option third path (gate the copy behind a module option) was viable and went unmentioned.
6. **Snapshot `git status --short` before the first edit** — with the daemon sweeping every ~10 min, post-hoc file accounting is forensics; pre-edit snapshots make it bookkeeping.

## f) NEXT (session-scoped; harvest status recorded per AGENTS.md rule)

| # | Item | Status |
| --- | --- | --- |
| 1 | Deploy evo-x2 (`nix run .#deploy`) — ai-meter chain unblocked; then anchor verify (`readlink /run/current-system`) | already queued: `TODO_LIST.md` ai-meter BLOCKER row + ai-stack.md row 40 (updated this session with the sops-fix clause) |
| 2 | Post-deploy live chain: keys minted, both /health, ai-meter scrape series in ClickHouse, gatus green, one real request per client (crush / paperless-gpt / inboxclean) | same rows — deliberately not duplicated |
| 3 | Post-deploy §17 memory-throttle sweep + §19 storage-history freshness (standard post-deploy-check legs) | covered by `scripts/post-deploy-check.sh` at deploy time; not separately queued |
| 4 | CHANGELOG entry for blocker fix + audit tightening | DONE on sight this session (Unreleased → Fixed) |
| 5 | sops skill note: remapped copies now eval-audited | DONE on sight this session |
| 6 | Re-add openrouter upstream once owner sets `openrouter_api_key` in openseo.yaml (same key would also unlock openseo `aiFeatures` later) | blocked:user — recipe in ai-meter.md; not queued (owner-held trigger) |
| 7 | Owner verify the `display-manager-heal.*` churn that rode daemon commit `44428273` | owner action; I was told not to research other sessions |
| 8 | If the ai-meter session's VM test (`ai-meter-vm`) re-runs: it now inherits the tightened audit — expect green (the removed copy was the only remapped-missing shape) | informational; no row |
| 9 | Longer term (ROADMAP fuel, deliberately NOT queued): make sops-key-audit also validate TEMPLATE placeholder references; consider a repo-wide "declared-shape census" negative test per audit module | ROADMAP fuel per skill guidance — docs-health HARVEST routing, not this report's queue |

Items 1–3 deliberately not re-queued (already owned by ai-stack.md row 40 + `TODO_LIST.md` mirror; duplication = the exact drift the TODO system forbids). Items 6–9 recorded as not-harvested with reasons inline.

## g) QUESTIONS (cannot figure out myself)

1. **OpenRouter**: do you have an API key you'll paste into `openseo.yaml` eventually (keep the re-add recipe prominent), or is openrouter gone for good (I would strip the remaining mentions from docs so they stop implying a planned upstream)?
2. **Deploy timing**: deploy now (`nix run .#deploy`), or hold until other in-flight session work (display-manager-heal, dms/offline-banner extractions marked deploy-pending in the CHANGELOG) lands in the same switch?
3. **Attribution**: were the `display-manager-heal.nix`/`.sh` changes in daemon commit `44428273` your parallel session's intended work (in which case nothing to do), or unexpected (in which case that session's tree needs review before the next deploy)?
