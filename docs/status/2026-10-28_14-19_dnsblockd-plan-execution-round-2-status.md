# dnsblockd Pareto Plan — Execution Status, Round 2 (2026-10-28 14:19)

**Plan under execution:** `docs/planning/2026-10-28_10-40_SUPERB-dnsblockd-integration-plan.md`
(27 tasks / 115 ≤12-min steps; tombstone `EXECUTING`, instance `crush-dnsblockd-exec-2`)
**Previous report:** `docs/status/2026-10-28_12-20_dnsblockd-plan-execution-status.md` (10/27 done)
**Session window:** 2026-10-28 13:31 → 14:19 CET · **HEAD before this session:** `656d0b208` · **HEAD at writing:** `56851cf6c`
**Source of the findings this executes:** `docs/architecture-understanding/2026-10-28_10-18_dnsblockd-integration.html` (3.57/5)

**Bottom line:** 16 of 27 plan tasks are now implemented, verified and committed, up from 10. Every remaining task is gated by
root/deploy (7), an owner decision (3), or a GitHub push (1), and the prune pass is gated by a file a concurrent session owns.
Nothing in this session needed root, and nothing was skipped because it was hard.

---

## Verification actually performed this session

| # | Command / probe | Result |
| --- | --- | --- |
| V1 | `nix build .#checks.x86_64-linux.dns-blocker-render` | green — banner: `… ECS, h3, pprof, rpi3 parity OK` (7 variants, was 6) |
| V2 | `nix flake check --no-build` | **exit 0**, "all checks passed!" (expected aarch64-darwin omission only) |
| V3 | `nix eval` — scheme-less `proxyInjectScriptURL` variant | the new assertion FIRES (exactly 1 failed assertion, message matched) |
| V4 | `nix eval` — well-formed `proxyInjectScriptURL` variant | **zero** failed assertions (false-positive guard) |
| V5 | `nix eval .#…evo-x2.config.assertions` (host) | **zero** failed assertions |
| V6 | `nix eval --raw …dnsblockd.serviceConfig.ExecStart` | `/nix/store/kxgximh…-dnsblockd-config.yaml` — **byte-identical to pre-session** |
| V7 | `comm -23` of rendered keys vs upstream koanf tags @ `f9bb6477` | **0 phantom keys** out of 57 rendered |
| V8 | `bash scripts/check-todo-system.sh` | `OK: TODO queue/library structure clean` (145 unharvested WARN = pre-existing) |
| V9 | `bash scripts/audit-shell-nullglob.sh` / `audit-textfile-tmp.sh` | `fail=0` both |
| V10 | Relative-link check across 6 edited docs | **0 broken links** |
| V11 | Live ALPN probe `openssl s_client -alpn h2` on `192.168.1.200:443` | `ALPN protocol: h2` — negotiates; page identical to h1.1 |
| V12 | Live Go client, h2 vs h1.1 block page | both `200`, both 92,567 bytes, same title/markers |
| V13 | Live per-SNI cert inspection | `O=dnsblockd, CN=doubleclick.net`, issuer `dnsblockd-CA`, 365d, cached (stable serial) |
| V14 | Live listener map (`ss -ltnp`) | `192.168.1.150:80/443` (caddy) + `192.168.1.200:80/443` (dnsblockd), nothing on loopback |
| V15 | `scripts/prune-done-todos.sh` dry run | 131 `[x]` rows / 11 files, WARN A DRIFT=49, baseline `b33a73fd` — **not applied** |

---

## a) FULLY DONE

1. **T03 — the falsified and stale rows are settled.** Five adoption-wave rows that had been live since 2026-09-30 were
   re-verified against the deployed config and closed; the "second-wave capabilities" row was retagged from `[watch]` to
   `[decision]` because policies, trial blocklists, ECS and h3 are all *implemented, rendered, assertion-guarded and
   deployed* — what remains is three owner calls, not code. The OTel-spam row moved from `[ready]` to `[blocked:deploy]`
   because its remainder genuinely needs the collector back.

2. **T19 — four runbook pointers.** The `/etc/hosts` shadowing sentence (with the 2026-10-14 catalog-sync deaths that
   justify it) went into the DNS runbook; the `:80`/`:443` listener map with the loopback-returns-empty gotcha went into
   `docs/services/caddy.md`; the three-concepts-called-"proxy" table went into `docs/agents/sso-dns.md`. The fourth pointer
   already existed — but the index around it was stale (`status/archive/` vs the real `status/archived/`, and three real
   documentation directories missing from the table entirely, including `services/` and `todo/`), which was fixed on sight.

3. **T20 — the comment sweep.** Pre-T299 recursion claims were already corrected everywhere, so the sweep found its wins
   elsewhere: a device-registry comment still promising "owner-confirm markers to verify at the next deploy window" for
   two identities resolved weeks ago, and a wildcard comment whose `search home.lan` consequence was contradicted by the
   resolv.conf that dropped that line on 2026-10-17. Both corrected in place with dates rather than deleted.

4. **T21 — the h2 question, answered by probing instead of by reading.** The standing note said the block page differs on
   h2 versus h1.1. It does not: h2 negotiates, returns 200, and serves the identical 92,567-byte page. The planned Gatus
   h2 variant and `--http2` smoke leg are therefore retired rather than built. Two facts nobody had written down went into
   the runbook instead: the certificate is minted per SNI on demand with the blocked domain as CN (cached, stable serial),
   and its validity window starts at mint time, so a skewed host clock turns every block page into a certificate error
   while DNS keeps answering — indistinguishable from a dead blocker.

5. **T06 — the 460-1195 blind spot, closed.** The review's own weakness was that it scored from the render block. The whole
   option block was read against the **locked** upstream revision (`f9bb6477`, via `git show`, not the working tree):
   - The row's "53 options" was wrong: 52 existed. It is 53 now only because this task added one.
   - **Zero phantom keys**: all 57 rendered keys exist in upstream's koanf struct.
   - The three "deliberate omissions" were adjudicated separately: `allow_sibling_domains` is left to its wanted upstream
     default, `dhcp_lease_file` has no data source on this host, and `pprof_enabled` was a real gap.
   - Full 53-row option→key map plus verdicts live in the plan's Appendix A.

6. **T06's finding — wedge forensics currently require killing the patient.** `scripts/dnsblockd-goroutine-dump.sh` reads
   stacks by sending SIGQUIT, which prints them and exits the process. That is precisely why the 2026-08-27 wedge still has
   no root cause. Upstream mounts `/debug/pprof/*` on the loopback stats listener behind the dashboard token, so a
   `pprofEnabled` switch (default off, inert, config store path unchanged) now exists, with a render-test variant proving
   both directions and that profiles cannot ride a widened stats address.

7. **T24 — five rows for one warning became one.** The catalog-coverage warning had accumulated five citations that quoted
   19, 21, 21 and 23 affected services — all stale, because the number is derived and nobody re-ran it. One row now owns
   it, states that the count is derived, gives the re-derive command, maps all 22 missing services to their modules, and
   records why the warning must stay a warning until the migration's second half deletes the hand-written DNS list. That
   rationale now also lives in `catalog.nix` so a future session cannot "fix" the warning by adding entries alone.

8. **T25d — the upstream validation question, answered.** Verified at the locked revision: upstream `SetInjectScript`
   assigns the string and returns. No scheme, host or reachability check exists, so a typo disables filtering with no
   error, no failed unit and no failing check. This configuration now refuses a non-`http(s)`-with-host value at eval time,
   with a rejection leg and a false-positive guard.

9. **T27a/T27b — the prune is prepared, not applied.** Dry run: 131 `[x]` rows across 11 files, WARN A DRIFT = 49, baseline
   `b33a73fd`, artifact at `~/.cache/prune-dryrun-20261028.txt`. The row's "3 done rows currently await" premise was stale
   and now says so. `--apply` is blocked **not** by capability but by ownership: step 2 pastes a 131-row block into
   `CHANGELOG.md`, which a concurrent storage session owned all session.

10. **The daemon's eight heuristic commits were rewritten.** All eight were mine (verified file-by-file before the rewrite),
    so they were softened and re-committed as three messages a future reader can use, each passing the full pre-commit
    battery (gitleaks, deadnix, statix, link check, flake check).

---

## b) PARTIALLY DONE

1. **T05 — the observer half is live in-tree, the exporter half is still dead.** The metric that reports the failure rides
   a textfile written by a unit that is not deployed yet, and the collector it watches has been in `start-limit-hit` since
   2026-10-27 20:21. Until a deploy plus `systemctl reset-failed`, SigNoz remains blind to its own blindness.

2. **T15 — decided, not built.** Manual-by-design is recorded (the refresh edits SRI hashes that need a commit and a
   deploy), and the freshness metric is the alarm instead. That is a decision, not an implementation.

3. **T06 — enabled-option coverage is complete, enabled-value coverage is not.** Every upstream knob we chose to expose is
   mapped and verified, and the ones we deliberately left alone are recorded with reasons. What no eval can prove is that
   the *values* we ship are right for this household — that is the owner's dashboard walk.

---

## c) NOT STARTED — and exactly what unblocks each

| Task | Gate | What it needs |
| --- | --- | --- |
| T04 allowlist backup | owner (Q3) | where the copy lands; whether `tracking.db` rides along (it ships per-device domain history offsite) |
| T08 `Type=notify` | deploy | AF_UNIX + notify in one commit; a wrong split leaves the resolver "activating" forever |
| T09/T10 migration spike + execution | owner (Q1) + root | adopt the unprivileged user: `chown -R` 4.6 G journal + 2.55 G tracking while the sole resolver is stopped |
| T11 VM test adoption | deploy/resources | aarch64-dns config cannot be realised here; needs a builder |
| T16 doctrine | owner | subvolume copy vs full btrbk entry for the allowlist |
| T17 gateway/firewall | owner | per-domain opt-in + external DoH/DoT blocking with an off switch and a drill |
| T18 wildcard decision | owner | the live wildcard evidence is assembled; the call is theirs |
| T25a-c upstream issues | push | verify the race at HEAD, then file three issues (now four) |
| T26 post-deploy battery | deploy | §22/§23/observer legs are the proof set |
| T27c prune apply | CHANGELOG ownership | exclusive access to `CHANGELOG.md` + a quiet window |

---

## d) TOTALLY FUCKED UP

Nothing this session, but three things were already wrong and are now on the record rather than in someone's head:

1. **Five rows tracked one evaluation warning and disagreed about it.** One said 19 services, three said 21, and the live
   answer is 22. Every one was written by a session that quoted a derived number instead of re-deriving it. The fix is the
   rule now written into both the row and `catalog.nix`.

2. **Our only forensics tool for the wedge class destroys the evidence.** That is not a documentation gap; it is why the
   2026-08-27 root cause is still unknown two months later. The switch to fix it exists now but is off.

3. **The block page's certificate behaviour was completely undocumented.** Two months of debugging notes about the block
   page never mentioned that the certificate is minted per queried domain and depends on the host clock. The next
   "the blocker is broken" report with a working resolver had a 50/50 chance of sending the next session down the wrong path.

And one process failure worth naming: **the auto-commit daemon committed this session's work in eight heuristic batches**
before any message could be written. Recovering required verifying all eight file lists, softening to `656d0b208`, and
re-committing by theme — work that would have been avoided by committing each unit as it finished.

---

## e) WHAT WE SHOULD IMPROVE

1. **Commit in units, not in waves.** The daemon wins any race where the working tree sits dirty for ten minutes. Every
   future session should land each verified unit immediately instead of accumulating a batch.

2. **Never write a derived number into prose.** Five rows and one module comment disagreed about the same count. State the
   command, not the result. The one place a count is acceptable is a dated census with the command next to it.

3. **A negative capability claim is the most expensive kind of comment.** "Recursion is broken", "wildcards do not work",
   "the page differs on h2" — each of the three was false by the time it was read, and each cost a session real time. The
   sweep rule is now written into the runbook: verify against the locked rev or delete it.

4. **Probe before planning a check.** T21 was going to add a Gatus endpoint and a smoke leg for a defect that does not
   exist. Ten minutes of probing retired two planned deliverables.

5. **Own the file, then own the edit.** The prune pass is ready and blocked purely because `CHANGELOG.md` belongs to another
   session this evening. Session planning should start by claiming the files a task will need.

---

## f) NEXT — 34 things, ordered by what unblocks the most

**Rank 1 — needs only a root path (7)**
1. `nix run .#deploy` — activates T01's gate fix, §22, §23, the observer, freshness, and the inject-URL assertion.
2. `systemctl reset-failed signoz-collector.service` then start it — ends a ~18 h telemetry blackout.
3. `nix run .#post-deploy-check` — the §22/§23/observer legs ARE the proof set for this wave.
4. Confirm `dnsblockd_otel_export_broken` reads 0 after the collector returns, and that the Gatus check is green.
5. Confirm the readiness gate logs `:53` UDP **and** TCP on the first post-deploy restart.
6. Run the freshness drill once: `scripts/dns-update.sh` in a lull, then watch the age metric reset.
7. Re-run the standing `node_textfile_scrape_error=1` root-cause sweep with the observer's new textfile in play.

**Rank 2 — owner decisions (5)**
8. Arm `pprofEnabled`? (loopback + auth-gated; buys non-destructive wedge diagnosis)
9. Q1: adopt the unprivileged `dnsblockd` user, or record root as deliberate?
10. Q3: allowlist backup destination, and may `tracking.db` ride along?
11. Second wave: enable ECS, enable h3, or record both refusals?
12. The tracking dial: stay METADATA_ONLY, or move to METADATA_AND_DNS?

**Rank 3 — agent-doable, no root (12)**
13. Re-read `docs/agents/monitoring.md` for the collector-outage narrative; the SEV1 row still reads as current.
14. Add the observer's own metrics to the SigNoz dashboard once they exist (a tile, not a rule).
15. Sweep `ss -ltn`-style listener gates for the wrong-port class (the row exists; the sweep does not).
16. Sweep for gates and polls with no executing fixture — T01's defect was findable only by running the script.
17. Compute the true count of `ps`-based liveness checks that would be fooled by PID reuse.
18. Extend `dns-caddy-wildcard-audit` to the APEX record ↔ apex vHost pair (row queued).
19. Make the observer script's branches a flake-comparable selftest rather than a hand-run drill.
20. Harden the observer after its first production cycle (it runs as a oneshot with no state-lock).
21. Write the "what a deploy must prove" checklist for dnsblockd — the proof set is now scattered across five sections.
22. Dedupe the remaining `task.reprioritized` pair and the two stale masterplan rows.
23. Re-verify the CA duplicate in the trust bundle: two identical certificates from a single option entry is still unexplained.
24. Add a runbook line for the `dnsblockd 7.2G` size question against the duplicate tracking-DB row.

**Rank 4 — needs a push or another repo (4)**
25. File the four upstream issues (race, startup hang, inject-URL validation, tag cutting).
26. Re-run the `-race` suite at upstream HEAD before filing the race — the original wave fired on a parent tree.
27. Push the curated inventory descriptor (still `[blocked:push]`).
28. Land the catalog migration's second half: derive `localRecords` from the catalog, delete `dns-local.nix`.

**Rank 5 — hygiene (6)**
29. Apply the prune once `CHANGELOG.md` is exclusively owned; expect the WARN count to rise.
30. Harvest the 145 unharvested reports, or record why the class is accepted.
31. Fix the pre-deploy §10 root-cause for `node_textfile_scrape_error=1`.
32. Re-stamp the derived counts (gatus endpoints, module count) immediately before the next commit that touches them.
33. Move the remaining `/tmp` scratch usages in scripts to `~/.cache` (the volatile-tmpfs lesson).
34. Re-check the `[blocked:deploy]` rows for ones whose deploy already happened.

---

## g) Three questions I cannot answer myself

**Q1 — Does a root path exist today, or should verified-but-inert work keep stacking?**
Twelve tasks are now in-tree and provably inert: the host's rendered dnsblockd config is byte-identical (`kxgximh…`
before and after). The telemetry outage is ~18 hours old and needs one deploy plus one `reset-failed`. If a root window is
open, say so and I will run deploy → post-deploy-check → the four live probes above. If not, the queue keeps growing and
every one of these fixes stays theoretical.

**Q2 — Should pprof be armed?**
It is loopback-only and auth-gated, and it is the difference between diagnosing the next stats-API wedge and destroying
the instance to look at it. The counter-argument is that it is a debug endpoint on a production daemon. My recommendation:
arm it, because the failure it prevents has already cost two incidents and the exposure is a loopback port behind the
existing token. Your call, and it stays off until you say otherwise.

**Q3 — Is the catalog warning acceptable for another cycle?**
22 services are declared to run but missing from the platform catalog, and the warning fires on every evaluation. I left it
as a warning deliberately, because adding entries without deriving DNS from the catalog would silence a drift detector
while leaving two DNS sources alive. The alternative reading is that 22 unbounded entries is too much debt to carry and the
migration should be forced now, in one session, with the DNS derivation in the same commit.

---

## Harvest record (§f self-harvest, at authoring time)

| §f item | Where it lives now |
| --- | --- |
| #8 pprof decision | `docs/todo/services.md` — new `[decision]` row (**this session**) |
| #9/#10/#11/#12 owner calls | already rows (`Q1` migration, `Q3` backup, second-wave adoption, tracking dial) |
| #13 collector-outage narrative | `docs/todo/monitoring.md` — new row (**this session**) |
| #15/#16 listener + fixture sweeps | already rows in `docs/todo/services.md` |
| #17 `kill -0` / PID-reuse sweep | `docs/todo/pipeline.md` + queue mirror (**this session**) |
| #18 apex wildcard guard | already queued (`docs/todo/services.md`) |
| #19/#20 observer selftest + hardening | already rows in `docs/todo/services.md` |
| #21 deploy proof checklist | already row in `docs/todo/services.md` |
| #23 CA duplicate | already row in `docs/todo/services.md` |
| #25 upstream issues | `docs/todo/upstream.md` — the inject-URL issue added (**this session**), 3 siblings already rows |
| #26 `-race` re-run | inside the upstream race row's "VERIFY first" clause |
| #28 catalog half two | the single canonical catalog row (deduped **this session**) |
| #29 prune apply | the prune row, now carrying the verified dry-run state (**this session**) |
| #30 unharvested reports | the harvest row, **recounted 88 → 145 this session** |
| #33 `/tmp` → `~/.cache` sweep | `docs/todo/pipeline.md` + queue mirror (**this session**) |
| #2/#3/#4/#5/#14/#22/#24/#27/#31/#32/#34 | covered by the rows named above or by the plan's remaining tasks; nothing left unrouted |

Deliberately NOT harvested: the root-gated items (#1-#7). They are a single deploy, and the plan already carries
`T26` for the verification half; duplicating them into the queue would create a fifth surface for one action.
