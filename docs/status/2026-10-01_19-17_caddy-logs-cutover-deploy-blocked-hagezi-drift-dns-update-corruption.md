# Caddy-logs hot-tier cutover: deploy blocked by HaGeZi drift; dns-update.sh corruption incident

- **Written:** 2026-10-01 19:17 +0200
- **Session scope:** execute the user-gated cutover (deploy + finalize) for the caddy-logs
  Samsung-TLC subvolume, unblock the failed deploy, verify, hand off again.
  NOT a whole-project audit — this reports this session's run only.
- **Tree at press time:** HEAD `38e146ab` ("add Spotify to NixOS desktop packages", foreign),
  working tree clean except this report. My repairs were daemon-swept into `ee80e46e` (verified
  by content greps, not just the commit stat).
- **Concurrent sessions ACTIVE:** a `nix eval …pbx…toplevel` process ran during my probes;
  `38e146ab` (Spotify) landed on top of my repairs mid-session; another session's status report
  (`2026-10-01_19-14_easy-fast-queue-closures-session-status-self-review.md`, untracked) is being
  written in parallel. I did not touch any of it.
- **Verification build:** round 2 IN FLIGHT at press time (background shell, started 19:13;
  round 1 was lost — see §d).

## a) FULLY DONE

1. **[prior legs of this task, unchanged]** All module/script/test/docs work for the caddy-logs
   hot tier: `platforms/nixos/system/caddy-logs-hot.nix` (fstab + tmpfiles + caddy unit
   `after/wants` the mount, `LogsDirectory = mkForce []`, `+`-prefixed ExecStartPre chown),
   `scripts/migrate-caddy-logs-hot.sh` (PSI gate, prepare/finalize), `tests/test-caddy-logs-hot.nix`
   (green, VM-proven 2026-10-01), `disko/samsung-tlc.nix` subvol row, staged status report,
   todo rows across `TODO_LIST.md` / `docs/todo/storage.md`.
2. **[user, via paste_1]** Stale subvol delete + `migrate-caddy-logs-hot.sh prepare` SUCCEEDED:
   106 files / 1,886,080,908 bytes rsync'd with exact-copy verify, caddy restarted, 1m10s total.
3. **[agent, prior leg]** `./caddy-logs-hot.nix` import uncommented in `configuration.nix`;
   `nix flake check --no-build` green; evo-x2 toplevel eval probes match the staged design
   exactly (mount options incl. `nofail`/5s timeout, `After=`/`Wants=` wiring,
   `Requires` only dnsblockd-cert-mint, `LogsDirectory = []`).
4. **[this session] Deploy failure diagnosed:** user's `nix run .#deploy` (paste_1, failed
   18:03:14, 9m6s) blocked by `HaGeZi-dga7-raw` FOD hash mismatch
   (`sha256-Xmg3…` → `sha256-17A3…`) — the documented drift class on the mutable GitLab
   `main` mirror. All 7 build errors cascaded from that single root failure; nothing in the
   caddy-logs change was implicated.
5. **[this session] `scripts/dns-update.sh` root-cause bug FIXED** (details in §d): pin-extraction
   regex now anchored to `hosts/\K[a-f0-9]{40}`, fails loud (`exit 1`) when the URL shape
   doesn't match, incident comment embedded at the site. `bash -n` + standalone
   `shellcheck -S warning` both clean (run via `nix shell nixpkgs#shellcheck` because the
   daemon-swept commit bypasses pre-commit filetype legs — house gotcha, re-run standalone).
6. **[this session] Blocklist refresh re-run CLEAN with the fixed script:** StevenBlack pin
   advanced `4a68876c…` → `abe587ab…` (correctly, URL intact), all 23 lists refreshed,
   9 hashes updated (ultimate, tif, oppo-realme, gambling, nsfw, urlshortener, dga7,
   StevenBlack), 0 failures. Diff verified surgical: only `hash =` lines + the SB commit pin.
7. **[this session] Repairs verified as landed:** daemon commit `ee80e46e` carries exactly
   `platforms/common/dns-blocklists.nix` (38 lines) + `scripts/dns-update.sh` (12 lines);
   content greps confirm SB URL shape, dga7 fresh hash, `hosts/ultimate.txt` URL, and the
   40-hex guard in HEAD-of-tree state.

## b) PARTIALLY DONE

1. **Toplevel verification build (round 2, in flight):** `nix build
   .#nixosConfigurations.evo-x2.config.system.build.toplevel --keep-going --no-link
   --print-out-paths`, launched 19:13, log at `~/.cache/evox2-toplevel-build2.log`. Dry-run
   enumeration before launch: **3040 derivations to build, 2444 paths to fetch (10.7 GiB
   download / 27.0 GiB unpacked)** — the flake's nixpkgs pin moved to `26.11.20260929.b4fd65b`
   (new kernel 7.2.8 etc.), so this deploy pulls a large closure delta regardless of the
   caddy change. Round 1 (launched 18:22) was lost to a background-shell registry reset (§d);
   completed downloads persist in the store, so round 2 resumes from partial warmth.
   No build error was observed in round 1's log before it vanished (the 14 grep hits for
   "error" were npm tarball NAMES like `assertion-error-2.0.1.tgz` — benign).
2. **The cutover itself:** prepare done (a.2), module enabled (a.3), deploy blocked (a.4→fixed),
   deploy + finalize still user-gated (§c). The log-gap window (new entries landing on the QLC
   shadow dir under the mountpoint) remains open until a successful deploy — bounded by
   caddy's rolling rotation, hidden not lost.

## c) NOT STARTED

1. **User: retry `nix run .#deploy`** once the verification build is green (store then warm →
   deploy build should be near-substitution + activate only).
2. **User: `sudo bash scripts/migrate-caddy-logs-hot.sh finalize`** after the deploy mounts
   `/var/log/caddy` (gates on mountpoint + `-mmin -2` freshness; EXIT trap restarts caddy
   if interrupted while stopped).
3. **Agent: post-finalize verification** (non-sudo): `findmnt /var/log/caddy` expecting
   `/dev/nvme1n1p2[/caddy-logs]`, fresh log mtimes under the mount, `pgrep -x caddy`.
4. **Docs STAGED→LIVE flips** (deliberately held until finalize passes): `AGENTS.md`
   doctrine-C hot-tier bullet (`caddy-logs` staged→live), `TODO_LIST.md` ~row 554,
   `docs/todo/storage.md` ~row 161, `CHANGELOG.md` entry (cutover + blocklist refresh +
   dns-update.sh fix; note the deployed generation the user reports).
5. **Post-soak (~2 weeks, after `@` snapshots expire):** delete the QLC shadow dir at the old
   `/var/log/caddy` path to reclaim 1.8G — tracked row already exists in `docs/todo/storage.md`.
6. **Existing `[ready]` rows, untouched by design:** migrate-script fixture test (model
   `scripts/test-migrate-hot-db.sh`), finalize existence+delta hardening, `trap '…' INT TERM
   EXIT` in the migrate script.
7. **Carried user decisions from the staged report §g** (now my §g questions 1–2).

## d) TOTALLY FUCKED UP!

1. **`scripts/dns-update.sh` corrupted `platforms/common/dns-blocklists.nix` on its first run
   in this session — MY action (I ran it).** Root cause: the StevenBlack pin-advance captured
   `raw.githubusercontent.com/StevenBlack/\K[^/]+` = the literal `hosts` path segment (repo
   name), not the commit; the global `sed s/hosts/abe587ab…/g` then rewrote EVERY `hosts`
   substring in the file — 15 `hagezi "hosts/…"` URLs plus all three `hosts` occurrences in
   the StevenBlack URL (19 lines total). Ironic: the script's own header comment documents
   exactly this failure class for its pre-2026-09-29 hagezi bug; the 09-29 fix repaired the
   hagezi leg but the SB leg had never been exercised with a moved pin, so it sat dormant.
   Recovery was fast (script FAILED loudly on the corrupted fetches → I diffed immediately →
   `git restore --source=eacd3ae3` of the one file → root-cause fix → clean re-run), but:
2. **The auto-commit daemon committed the CORRUPTED intermediate as `106c340e`** (18:21:47,
   before my restore). The corruption therefore lives in local history: `106c340e` (bad) →
   `ee80e46e` (repair). Pushes are user-held, so no remote damage; cosmetic but real (§g.3).
3. **Verification build round 1 lost silently:** background shells 02C/02D vanished from the
   registry between 18:55 and 19:11 (whole registry reset — likely a harness/session restart),
   killing the in-flight `nix build` mid-download (~30 min of bandwidth partially discarded;
   completed paths persist). Compounding: **an unknown actor deleted
   `~/.local/state/caddy-logs-cutover/`** (the build log dir) in the same window. Flagging
   per the concurrent-session rule: I did not author either event; concurrent sessions were
   demonstrably active (pbx eval, Spotify commit, the 19:14 report).

## e) WHAT WE SHOULD IMPROVE!

1. **Trace every in-place file EDIT a script performs before running it, not just its flow.**
   I read `dns-update.sh` top-to-bottom before executing and still missed that the capture
   regex would grab `hosts` — because I reviewed what the script DOES, not what its `sed`
   matches. For in-place editors, the review unit is the sed expression's blast radius.
2. **The near-miss that saved us is a habit worth codifying:** script exited nonzero → I
   diffed before anything else. Keep: any mutating script that fails = `git diff` FIRST,
   diagnose SECOND, repair THIRD.
3. **Never trust the daemon's commit as evidence** — verify content (`git show` + greps), which
   I did do here (ee80e46e verified by content, not stat). Worked; keep doing it.
4. **Verification-build logs must survive their shell:** put durable build logs under
   `~/.cache` (survived) rather than `~/.local/state` (deleted), and treat
   background-shell registries as volatile — derive ground truth from the store
   (`--dry-run` warmth probe) after any reset. This worked well in recovery; do it from
   the start next time.
5. **Daemon-swept script edits bypass pre-commit lint legs** (house gotcha, hit again):
   standalone `shellcheck` via `nix shell nixpkgs#shellcheck` after every daemon-swept
   script edit — cheap, do it always.
6. **Drift-class elimination candidate:** vendor the small HaGeZi lists (doh 98 KB, the
   native.* lists, dga7 13 MB) into the repo and fetch only the big ones (ultimate ~20 MB,
   hoster) — kills most of the hash-drift deploy-blocking class at the cost of repo size.
   Idea previously raised in the 2026-08-13 mirror-fix report; still unactioned (§f.13).
7. **Report-format note:** this report is Markdown per the user's explicit `.md` instruction,
   overriding the skill's HTML-dashboard default (flagged here per the skill's override rule).

## f) NEXT (ranked; tracked = already in queue/library, NEW = harvested with this report)

1. [user-gated] Retry `nix run .#deploy` once build 008 is green (§c.1).
2. [user-gated] Run `sudo bash scripts/migrate-caddy-logs-hot.sh finalize` (§c.2).
3. [tracked] Post-finalize agent verification probes, then STAGED→LIVE flips across
   `AGENTS.md` / `TODO_LIST.md` / `storage.md` / `CHANGELOG.md` (§c.3–4).
4. [NEW — harvested] dns-update.sh pin-extraction selftest (fixture: a blocklists file with
   the SB URL; assert extraction returns the 40-hex commit, never `hosts`; models
   `scripts/check-templ-committed.sh` selftesting precedent) → `docs/todo/services.md`.
5. [decision, user] Local history: leave `106c340e` (corrupted) + `ee80e46e` (repair) as a
   superseded pair, or rewrite before the held push (§g.3).
6. [watch] Identify the `~/.local/state/caddy-logs-cutover` deleter — likely a concurrent
   session or cleanup timer; ask around before placing durable state there again.
7. [tracked, existing `[ready]` rows] migrate-script fixture test; finalize existence+delta
   hardening; `trap INT TERM EXIT` in the migrate script (§c.6).
8. [decision, user — carried] hot-db `*Directory=` stance per service
   (gatus/dnsblockd/pocket-id/browser-history): fail-closed vs degrade; my leaning
   fail-closed for DB-backed (§g.1).
9. [decision, user — carried] caddy-logs retention: ratify "no new rotation" (caddy rolling
   already bounds growth, `caddy.nix:326-335`) or name a subvol cap (§g.2).
10. [tracked] Post-soak: delete QLC shadow dir (1.8G) after `@` snapshots expire (~2 weeks)
    (§c.5).
11. [tracked, TODO_LIST ~453 lineage] CHANGELOG credit for today's dns-update.sh fix rides
    the §c.4 flip batch (the 09-29 rewrite CHANGELOG row stays separate).
12. [improvement candidate] Vendor small HaGeZi lists to kill the drift class (§e.6) — needs
    a size/latency call, ROADMAP fuel unless the user wants it now.
13. [watch] After the big closure lands: confirm QLC free space recovered expectations
    (27 GiB unpacked ≈ ~15 GiB physical post-zstd; root was 92% pre-deploy) — read the
    gatus disk check, don't guess.

## g) QUESTIONS (cannot figure these out myself)

1. **Hot-db `*Directory=` stance, per service** (gatus / dnsblockd / pocket-id /
   browser-history): when each migrates to a hot-tier subvol, should a detached Samsung
   FAIL the service (fail-closed — my leaning for DB-backed: silent degradation risks
   split-brain data) or degrade to the QLC shadow (journal-hot/caddy-logs pattern)?
2. **caddy-logs retention:** ratify "no new rotation" (rolling rotation in `caddy.nix:326-335`
   already bounds growth; nodatacow subvol grows then rolls) or name an explicit subvol cap
   (e.g. btrbk quota / gatus size alert)?
3. **Local git history:** `106c340e` contains the corrupted blocklists file (superseded two
   commits later by `ee80e46e`; push still held). Leave as-is, or rewrite/amend the pair
   before the next push so the bad intermediate never leaves the machine?

## Harvest ledger (per the self-harvest rule)

- **Harvested:** §f.4 → `TODO_LIST.md` (queue) + `docs/todo/services.md` (library row), both
  pointing at this report §f.4.
- **Deliberately NOT harvested:** §f.1–3, 7, 10, 11 (already tracked in `TODO_LIST.md` /
  `docs/todo/storage.md` rows named in §c — re-queueing would duplicate); §f.5, 8, 9
  (user-gated decisions — they are §g questions now; the staged report's §g rows in
  `storage.md` remain their library home); §f.6, 12, 13 (watch/ROADMAP fuel, not
  agent-actionable asks).

_Snapshot report — will stale fast. Verification build verdict lands in the session transcript,
not by editing this file._

---

## ADDENDUM (post-press, 19:33): keep-going surfaced a SECOND failure class — LarsArtmann go-modules FOD drift

The round-2 `--keep-going` build (still running at 19:33, 981+ paths substituted) enumerated
beyond the HaGeZi fixes and found **three more root failures, all `go-modules` FOD hash
mismatches on mkLarsPackages tools** (pins live in `lib/lars-packages.nix`):

| FOD                                                                 | specified                                             | got                                                   |
| ------------------------------------------------------------------- | ----------------------------------------------------- | ----------------------------------------------------- |
| `branching-flow-0.2.0-go-modules.drv`                               | `sha256-Gitg6V8+pNQWYoXwdL2bTSsZEa1G6QtNvDkF+IUD3yM=` | `sha256-QUU2TvF76UJRO/AjO+MFPWvYfWrvuBMQ+RiAMMJ5B0w=` |
| `cqrs-lint-4d4137ee0b7920bd787cc922f83a066f67be9581-go-modules.drv` | `sha256-YHWDwUiUNwWEtnInfnqjWGfD5ljMqJN5pFVjNTMPihA=` | `sha256-yonqp/FVG61XlYlPbKWzlF6a6HTj4bMWMbJjiswtdCo=` |
| `cv-59f2ec6-go-modules.drv`                                         | `sha256-K+yEjs8fCsvTlpl/dPwHQifiKoQRSwu69xzVV1oDeGI=` | `sha256-w1drooS482Myluq8CaXeL0gZBMZvYHDcD2IcuAUXK44=` |

**Working hypothesis (unverified):** rev-pinned LarsArtmann repos whose history was rewritten
upstream (the repos are actively rebased), so the pinned rev now resolves to different content
through the proxy/direct fetch — the same class the go-ecosystem docs call re-tag/rev poisoning.
This explains why the user's 18:03 deploy never saw them (it died at 2m42s before reaching
these FODs). **The deploy remains blocked** until these are refreshed (got-hash adoption if the
rev content is legitimate, or re-pin if the rev is stale) — enumeration is still running, so the
final list may grow. Fix runs through the go-ecosystem upgrade procedure (re-pin protocol:
FOD probe at the new rev → lock/package verify → flake check), NOT blind hash adoption.

§f impact: item 1 (deploy retry) is gated on fixing THIS list first; the rest of §f stands.
