# Takeout extract tool (X1) built, selftested, live dry-run green — session status 2026-11-14 10:16

Continuation of the 2026-11-14 00:54→04:13 arc (key converger consumer wired,
G2 manifest trap, 41 CI selftest legs — see
`docs/status/2026-11-14_04-11_takeout-key-converger-wired-verify-trap-selftests-status.md`).
This session executed the resumption plan's step 6 (extract tool) first and
recon for the rest; the doc tail (CHANGELOG/queue rows) is deliberately NOT
yet written so it can cover the extract tool in the same entry.

## a) What was done (this session, ~10:00–10:16)

1. **Recon.** Git: tree clean, the 04:11 report + dedup header fix already
   daemon-committed; 23 commits unpushed at session start — **pushed minutes
   ago by a parallel session** (origin/master advanced; 3 commits remain
   unpushed, all three exclusively `scripts/takeout-extract.sh` — verified via
   `git show --stat`). `TODO_LIST` rows 442/443 still open although the arc
   already did them (drift class again). `.buildflow.yml` present but
   budget-only (no step orchestration; repo nix gates stay canonical).
   Loaded docs-health + buildflow skills before touching docs/nix.
2. **`scripts/takeout-extract.sh` written (plan X1.1–X1.5), 432 lines:**
   - member-scoped `unzip -o` from `logs/zip-entries.tsv` — **reused when
     present** (one listing read per zip across the pipeline), regenerated
     only when absent; `--dry-run` writes NOTHING (listing goes to a temp
     file, `extracted/` untouched, `logs/` untouched).
   - patterns are unzip-style globs that MUST be rooted at `Takeout/`
     (refused otherwise); default scope `Takeout/*`.
   - capacity gate before any write: `free ≥ 1.2×extract + 500 GiB` via
     `df -B1` on the first existing ancestor of the dest (env-overridable
     knobs `TAKEOUT_EXTRACT_HEADROOM_BYTES` / `TAKEOUT_EXTRACT_MARGIN_PCT`,
     resolved at gate time so overrides actually work).
   - `unzip` rc 11 (no members in THIS zip) is a logged skip, never a failure;
     any other rc is captured per-zip into `logs/extract-<zip>.log` and fails
     the run (exit 2, "do not import").
   - fail-closed reconciliation: exact set compare (missing AND extra both
     fail) + byte totals, scoped to the pattern roots so a previously
     extracted OTHER product never counts as extra; zero matched members is
     never a pass (exit 2).
   - exit contract: 0 clean / 1 usage-hard / 2 gate-or-reconcile failure.
3. **Selftest: 9/9 legs green, `shellcheck -x` clean, `bash -n` clean.**
   Legs: dry-run-no-write, capacity-block, members-root-guard, extract-happy,
   member-scope, rc11-skip, corrupt-zip-fail (truncated zip after listing
   exists → EXTRACT FAILED exit 2), reconcile-extra-fail (stray on-disk file
   fails exact-set), listing-reuse (mtime-pinned tsv not regenerated).
4. **X1.5 live dry-run on the helpless.ai staging, green and read-only:**
   `DRY-RUN extract: 7496 members / 27374907654 bytes`, capacity OK
   (need ≥ 569,720,801,184 B, free 11,758,197,886,976 B), rc 0,
   `logs/zip-entries.tsv` NOT persisted (verified after the run).
5. **New live fact, root-caused:** extract counts 7496 members where
   `balance` reported 7495 — the delta is exactly one root-level member,
   `Takeout/archive_browser.html` (probe: every `unzip -l` entry not matching
   `Takeout/<product>/`), which balance's per-product bucketing skips by
   design. Extract's number is the complete one.
6. **Second live fact (blocks account #2's G2):** the helpless.ai zips carry
   RAW browser names (`takeout-20261110T…-001.zip`), and `takeout-verify.sh`
   G2.1/G2.2 hardcode `part-%02d.zip` / `part-*.zip` — **verify cannot pass
   on helpless.ai today** (also explains the empty `logs/` there). Extract
   was therefore written to glob `zips/*.zip` (both names, same as
   `balance`). Closing the gap needs either the rename-wrapper run on that
   staging or verify-side name tolerance (queued below).

## b) Evidence (commands + outputs)

```bash
nix shell nixpkgs#shellcheck nixpkgs#zip nixpkgs#unzip -c bash -c \
  'shellcheck -x scripts/takeout-extract.sh && bash scripts/takeout-extract.sh --selftest'
# → 9× "PASS: <leg>" + SELFTEST GREEN

bash scripts/takeout-extract.sh /mnt/pool/archive/google-takeout/lars-helpless-ai-2026-11-13 --dry-run
# → scope: Takeout/* -> 7496 members / 27374907654 bytes
# → capacity: need >= 569720801184 …, free: 11758197886976 bytes
# → DRY-RUN extract: 7496 members / 27374907654 bytes  |  DRY-RUN: capacity OK, nothing written

# the 7496-vs-7495 delta (root-level member balance's bucketing skips):
for z in zips/*.zip; do unzip -l "$z" | awk 'NF>=4 && $1~/^[0-9]+$/ { name=substr($0,index($0,$4));
  if (name !~ /\/$/ && name !~ /^Takeout\/[^\/]+\//) print FILENAME, name }'; done
# → takeout-20261110T224436Z-001.zip Takeout/archive_browser.html
```

Battery baseline for the CI leg-count assertion (empirical, this session):
verify 6 `^PASS`, dedup 21 `^leg …: OK`, intake 7 `^leg …: OK`,
browser-rename 5 `^PASS` + 2 `^leg …: OK` (= 7 legs), extract 9 `^PASS`.

## c) State changes

- NEW `scripts/takeout-extract.sh` (daemon-committed in 3 heuristic commits,
  `bc7580ddb` → `a9918a682`, all exclusively this file; 3 commits unpushed).
- NO other repo changes; nothing deployed; no pool writes (dry-run only).
- `/mnt/pool` free: 11,758,197,886,976 B (~11.76 TB); staging untouched.

## d) What I TOTALLY FUCKED UP (caught before or during the selftest)

1. **First draft shipped four latent bugs** my own self-review caught only
   after writing: (a) array env-prefix assignments (`PATTERNS=(…) cmd`) are a
   bash SYNTAX error — arrays cannot ride assignment prefixes; (b) selftest
   legs called `run_main` outside subshells, so `die()`/exit-2 would kill the
   selftest driver; (c) `local x=$(mktemp)` return-code masking; (d) the
   listing-reuse mtime assert pinned a LOCAL-time `touch -d` against a UTC
   epoch (TZ-dependent — now `touch -d '@946684800'`).
2. **`glob_to_re`'s bracket-class sed idiom was broken** (`unterminated s
   command` — every leg failed) and I replaced it with per-metachar escapes.
3. **Byte arithmetic written from memory, not from the fixture:**
   `'{}\n'` is 3 bytes, not 2 — my hardcoded 27-byte expectation was wrong
   (real total 28). Wrote the fixture AND the expectation without computing
   the sum once.
4. **The 500 GiB default headroom made every real-run leg fail the capacity
   gate** on the 76 GB free test filesystem — the selftest now pins a tiny
   headroom env at entry (the capacity-block leg overrides it to huge). The
   env knob only works because resolution moved INTO `capacity_gate`
   (at-startup resolution would have frozen the default).
5. **First live dry-run died on `part-*.zip`** — I copied verify's glob
   without checking the live filenames first; helpless.ai uses raw browser
   names. Fixed to `zips/*.zip`; the recon that found this belongs BEFORE
   writing the glob (the live-probe-first rule, applied late).
6. Two selftest rounds failed before green; every failure was diagnosed from
   the kept per-leg logs (`$fx/leg-*.log`), not by re-running blind.

## e) What we should improve

- **Recon-before-code for live interfaces:** the zip-naming surprise (d.5)
   and the verify-vs-helpless.ai mismatch (a.6) were both one `ls` away.
- **The `takeout-selftests` comment block in `flake/parts/checks/selftests.nix`
   is stale** (claims dedup 16 / rename 6; reality 21/7) and nothing enforces
   the counts — the planned leg-count assertion fixes both in one edit.
- **Queue drift is still live:** rows 442/443 describe done work
   (manifest trap fixed; selftests wired) and were never ticked; the tick +
   CHANGELOG + library pairing remains the resumption plan's step 2.
- **`takeout-ingest-photos.sh`'s 5 fixture legs are not in CI** (the 41 legs
   cover verify/dedup/intake/rename only) — its stub-immich-go harness should
   join the derivation.
- **immsg:** verify's G2.1/G2.2 part-name hardcoding vs the fleet's two
   naming schemes should be one decision (rename-everything-at-intake vs
   verify tolerance), not a per-script accident — extract now handles both,
   verify does not.

## f) What we should get done next (ordered)

1. Wire `takeout-extract.sh --selftest` into `takeout-selftests`
   (`flake/parts/checks/selftests.nix`): add to the script copy list, fix the
   stale leg-count comment, add the per-battery count assertion
   (6 / 21 / 7 / 7 / 9) so a silently deleted leg fails the build; build the
   derivation.
2. CHANGELOG entry for the whole arc (converger consumer + G2 trap + 41 CI
   legs + the two balance bugs + the extract tool + live dry-run numbers).
3. Tick `TODO_LIST` rows 442/443 (work done by the 04:11 session, verified
   this session) + matching `docs/todo/services.md` library pairing.
4. Add the new queue rows from the 04:11 report §f harvest: converger
   consolidation (discordsync + media-atlas + `apiKeys.drive-paperless` +
   delete the sops option), post-deploy converger acceptance (+ `balance
   --preflight` into the post-deploy battery), verify hardening (per-account
   manifest path, partial-manifest leg, `--no-hash` leg), takeout status
   one-liner; supersede-clause on row 490's manual-key steps.
5. Prove `deploy-restart-audit` fails when `immich-api-key-provision` is
   dropped from `deploy.sh`'s loop (fixture/negative leg).
6. Decide + implement the verify-vs-raw-zip-names gap (a.6): run the rename
   wrapper on the helpless.ai staging OR make G2.1/G2.2 name-tolerant
   (`zips/*.zip` + parts.tsv's filename column).
7. Final `nix flake check --no-build --all-systems`, then push the 3 unpushed
   commits (all exclusively mine — amend into a real message is available).
8. Deploy (owner window) + 3-probe converger acceptance + ingest preflight.
9. Ledger normalization L1 after the owner's schema answer (question 2).
10. Extract `Takeout/Google Photos` on helpless.ai via the new tool (G1.1),
    `--dry-run` first, then the real run + `balance --preflight`.
11. Owner-gated fleet work (unchanged): racedriver8k 0/23 browser download,
    exports-page save → intake → verify; OpenCloud app password + rclone;
    drive-paperless rated subset; account #3+ registry rows.

## g) Questions I cannot answer myself (3)

1. **Ship window:** push the 3 unpushed commits and deploy now (nothing in
   the converger chain is live until `nix run .#deploy`), or hold for a
   quiet window? Parallel sessions were still committing this morning; the
   23-commit backlog was pushed by another session minutes ago.
2. **Ledger schema (carried over):** prefix-free or prefix-kept `Takeout/`
   relpaths? `plan`'s `new-files.txt` is consumed by `rclone --files-from`
   relative to the extract root (needs the prefix today); `balance` strips
   it. Gates L1.
3. **Account #2 (carried over):** which Google account next, keep-alive vs
   retire, and when does the 2-monthly export cadence start? racedriver8k is
   still 0/23 (export expires 2026-11-18, account stays alive either way).

---

**HARVEST 2026-11-14 12:1x (resumption session):** §f1 EXECUTED — CI wiring +
leg-count assertion landed (50 legs, derivation built green, stale comment fixed);
§f2 CHANGELOG landed (whole-arc entry); §f3 rows 442/443 ticked both surfaces;
§f5 deployrestart negative group landed (2/2 green); §f6 + §e(ingest-photos
CI legs) + the 04-11 §f11-19/33-34 harvest landed as seven new queue + library
rows (consolidation, drive-paperless pairing, post-deploy battery, verify
trio, status one-liner, ingest-photos legs, zip-name divergence) + the row-490
supersede clause; §e(selftests comment) fixed by the rewrite; §f21 satisfied by
the plan's C1/C2 DONE block (battery counts documented). §f7 executing now
(final whole-flake gate + push). §f8-11 stay owner-gated/plan-tracked (queue
rows 439-441 + plan L1/G1). No deliberately-unharvested remainder.
