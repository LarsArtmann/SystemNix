# Paperless-triage P1 — session self-review + full status (2026-10-29 14:08)

Session: resumption #2 of `crush-triage-exec-2026-10-27` (attempts 14→19,
deploy attempt, surface close-out). Predecessors: 2026-10-27_22-43,
2026-10-28_00-20, 2026-10-29_12-55. Trigger: owner's brutal-self-review
request. Basis: this session's run only.

**One-line verdict:** implementation and VM-proof are DONE and green; the
go-live is parked behind a host-level IO corpse-pile that is DEEPENING as
of 14:08 (`/proc/pressure/io` some avg300 **81.65%**, a fresh
`kworker/u130:2+events_unbound` in D-state for **55 minutes** — worse than
the 12:45 reading that blocked the deploy).

---

## §0 Self-review (the brutal part)

**1. What did I forget?**
- **I fired a full-store `find /nix/store`** (job 0F8, ~12:00) while the
  host was already sliding into the IO corpse-pile — unbounded walk over
  ~100k store entries, abandoned by interrupt, never killed by me. It is
  gone (verified this hour), but for a while the session that later got
  blocked by IO pressure was itself contributing IO. Stupid.
- **Attempt-18's exit-1 was diagnosed blind**: I re-ran the check with
  `2>/dev/null` and got an ambiguous `exit status 1` — one extra full VM
  cycle (~4 min) to learn what a captured log would have shown instantly.
- **"Transient host-load casualty in the runner's post-script sync" is an
  INFERENCE, not a captured fact.** Evidence: runner source shows
  `machine.execute("sync")` post-script; identical content passed exit-0
  on attempt 19. I have no stderr of the failing phase (suppressed — see
  above). The close-out language in the 12-55 report should have said
  "inferred". It now does, here.
- **Loose stamp attribution**: README 247→250 says "+ the media-atlas
  endpoint wave" — I verified MY +2 (endpoint names listed through the
  eval) and saw 3 atlas-named endpoints, but never reconciled the exact
  historical composition (rename vs new). Gate is green (250 = eval
  truth); the prose is imprecise.
- **No live attempt ledger** — the prior session's own recorded lesson. I
  reconstructed the 14→19 ledger at report time and then had to
  double-check my own CHANGELOG wording against my own reconstruction
  ("18 failing iterations + 19th green" — verified correct, but the
  re-derivation dance is exactly the count-drift class this repo keeps
  burning on).
- **No proactive gatus re-stamp** when the checks were authored — doc-counts
  caught me (the 10-28 session missed it too; second consecutive miss of
  the same class).

**2. What's stupid that we do anyway?**
- The monitoring dashboards (nvtop/btop/iotop ghostty scopes) read
  /proc of D-state tasks and pile into every corpse — the watchers become
  victims and PSI amplifiers (97–100% cgroup io.pressure each).
- paperless 3.3.1 silently IGNORES unknown query params and returns the
  full unfiltered set — one wrong filter name = whole-population result
  with a 200. An entire bug class (three call sites fixed) exists because
  of this. Upstream design; we now adapt client-side everywhere, and the
  runbook documents it.
- "Never swallow failure reasons" keeps being re-learned: it cost the
  prior session 4 iterations; applying it cost me one edit and named the
  next bug in ONE iteration. The lesson should be applied at write time,
  not rediscovered per script.

**3. What could I have done better?** Fixture-first worked both times I
used it (selftest trap fix, ensure_tag) — but I adopted it for the mock
regex only AFTER v1 burned a VM cycle. The wire-body-vs-decoded-JSON
newline distinction was a 10-second local python check before building.

**4. What could I still improve?** See §e/§f — the shortlist: VM-test
coverage gaps (verdict-down, encrypted skip, lookback), the 3-way
name→id split-brain risk, and the deployment leg.

**5. Did I lie to you?** No claim I know to be false. Two claims were
weaker than their phrasing: the attempt-18 "host-load casualty" (inferred
— now flagged) and the stamp attribution (unreconciled — now flagged).
Counts in CHANGELOG/rows re-verified this hour: 18 failing runs, 19th
green, 5 runs executed in this session (15–19) + attempt 14's log read.

**6. How can we be less stupid?** Bank: fixture-first for every
parser/mock change; full log capture on every failing build from the
first rerun; re-stamp counts in the same edit that adds endpoints;
keep a live ledger after 3 iterations; client-side exact-match for DRF
list endpoints unless the filter is source-verified.

**7. Ghost systems?** None new. The triage module is fully wired (timer,
registry, catalog, 2 gatus checks, backup coordination, configuration.nix
enable) and VM-proven. The one near-ghost state — enabled-in-tree but
dark-in-prod — is a queued go-live (row 103), not an orphan.

**8. Scope creep?** Resisted: did not touch row 589 (other session's
lifecycle), the catalog-subdomain warning list (parallel sessions'), or
the host incident (owner domain).

**9. Removed something useful?** No removals this session.

**10. Split brains?** One small, real one: name→id resolution now exists
in THREE implementations with identical semantics — sweep `tag_id_of`,
provisioner tag-existence loop, provisioner `tag_id()` — plus the test
helper. They can drift again (a page_size change in one, not the others).
Today's guard is that the VM test exercises sweep + provisioner together;
the runbook trap names all sites. A shared helper is awkward across two
Nix-generated scripts; a shared VM leg IS the practical guard.

**11. Tests?** The VM test is the strongest artifact of this plan (19
runs, real paperless+PG, logprobs-shape mock, idempotence leg). Gaps
noticed: no in-VM verdict-down leg (refusal metric asserted only at 0),
no encrypted-tag-skip leg, no first-run-lookback leg, and no
header note about the rerun-identical-first policy for the attempt-18
exit-1 class.

---

## a) FULLY DONE (this session)

1. Selftest EXIT-trap scope fix (function-local `t` + surviving trap →
   nounset kill at exit 0; `trap - EXIT` + defensive `''${t:-}`).
2. `ensure_tag` stdout pollution fix (echo → stderr) + host-side bash
   fixture proof — a fresh/restored-instance production bug class.
3. `tag_doc` failure-reason capture (`TAG_API_ERR` via `--fail-with-body`,
   WARN carries the body) — named the next bug in one iteration.
4. Paperless 3.3.1 `bulk_edit modify_tags` contract fix (`remove_tags: []`
   always sent).
5. Paperless 3.3.1 `?name=`-is-not-a-filter fix in all three call sites
   (sweep `tag_id_of`, provisioner tags + custom fields) + test
   `tag_id_by_name` helper — including the T6 heal-bug (would have
   no-opped the drift heal in prod).
6. Mock verdict server classification fix (decode-JSON-then-excerpt;
   locally proven both classes before rebuild).
7. **VM test exit-0** end-to-end (attempt 19): routing, token mint,
   metrics, watermark+MRU idempotence.
8. Static verification green: evo-x2 eval gate, `nix flake check
   --no-build`, `nix fmt --` canonical (twice), todo-system structure OK.
9. README gatus re-stamp 247→250 (doc-counts green; attribution flagged
   above).
10. Docs: runbook §Decision-triage-gate "3.3.1 API contract traps" (3
    traps); plan §9 addendum + EXECUTING tombstone note with re-fire
    procedure.
11. Surface close-out: services.md rows 103 / 105(b)(d) / 106 / 51(b);
    TODO_LIST rows 588 / 591 / 592; CHANGELOG entry; stability.md
    corpse-pile watch row; 12-55 status report with §f harvested at
    authoring time.

## b) PARTIALLY DONE

1. **T1 (the gate)**: implementation + VM proof complete; **prod dark**
   pending one deploy (module enabled in tree, blocked at the entry gate).
2. **T6 (drift heal)**: declarative path complete + its heal-bug fixed;
   LIVE heal unverified until the deploy runs
   (`journalctl -u paperless-dashboard-provision | grep ensured`).
3. **Plan execution**: T1d green; deploy leg blocked; tombstone EXECUTING
   (flips only after live verify).
4. Name→id resolution: consistent in all sites today; 3-way
   implementation split-brain noted (§0.10).

## c) NOT STARTED (noticed this session, owner-gated or next-window)

1. Post-deploy live smoke (full list in paperless.md
   §Decision-triage gate).
2. Real-ai-meter logprobs passthrough verify — the ONLY functional leg
   never exercised live (VM used a mock; flagged by the prior session
   too).
3. Corpse-pile disposition (owner; watch row in stability.md).
4. VM-test gaps: verdict-down leg, encrypted-skip leg, first-run-lookback
   leg, rerun-first header note.
5. T2 row 105 continuations (a)/(c) — Clef keys + pricing (blocked:user).

## d) TOTALLY FUCKED UP

1. **Blind rerun of attempt 18** with stderr suppressed — cost one full
   VM cycle on a 19-iteration loop. Self-inflicted, avoidable, avoidable
   AGAIN next time unless the capture habit sticks.
2. **The full-store `find`** — IO contribution to a degrading host, left
   to die by interrupt instead of cleaned up by me.
3. **Mock regex v1 shipped to a VM build** without the 10-second local
   wire-shape check (cousin of the prior session's runtimeInputs
   regression: untested assumption + expensive venue).
4. Nothing else: no secrets touched, no prod mutation, no forced gates,
   no reverts of others' work.

## e) WHAT WE SHOULD IMPROVE (banked)

1. Fixture-first for every parser/mock change, no exceptions after 2
   proofs-of-value this session.
2. Full stdout+stderr capture to `~/.cache/<topic>/` on the FIRST failing
   rerun of any build/test.
3. Re-stamp counts in the SAME edit that adds endpoints/modules;
   doc-counts is a net, not a workflow.
4. Live attempt ledger from iteration 4 onward.
5. Client-side exact-match over server-side filtering for DRF list
   endpoints unless the filter is source-verified (generalize to other
   repos' scripts — candidates unverified: bank-sync, journal tooling).
6. `line 1: <var>: unbound variable` under nounset = EXIT trap outliving
   scope — check `trap - EXIT` placement first (candidate for
   docs/agents/shell-devtools.md).
7. VM flake-class policy: on infra-shaped exit-1 after a clean script
   phase, rerun IDENTICAL content before diagnosing.

## f) NEXT (from this session's run and observations; no padding)

1. Re-fire `nix run .#deploy` under quiescence (procedure on row 103).
2. Post-deploy anchor check + `post-deploy-check.sh` full battery.
3. Post-deploy triage smoke: sweep journal, `paperless_triage.prom`,
   timer state, gatus pair green.
4. T6 live heal verify: `grep ensured` → expect tags ≥4 + fields 2.
5. Live: "Needs Review (triage)" view exists.
6. Live: one real verdict through ai-meter — logprobs passthrough proof.
7. Close row 106 (live DB reconcile) after 4–5.
8. Close row 103 → flip plan tombstone to EXECUTED.
9. Corpse-pile disposition (owner decision; stability.md watch row).
10. VM test: verdict-down leg (stop mock → refusal metric, no writes).
11. VM test: encrypted-tag skip leg.
12. VM test: first-run 15-min lookback leg.
13. VM test header: rerun-identical-first note (attempt-18 class).
14. Split-brain guard note next to the three name→id sites (or a shared
    selftest).
15. Reconcile the 247→250 stamp composition via git archaeology (tiny).
16. Bank the EXIT-trap lesson in docs/agents/shell-devtools.md.
17. Row 105(a): Clef arm after owner pastes 2 Cloudflare keys.
18. Row 105(c): Jev → $/1k-docs pricing line.
19. Plan §6 owner pack Q1–Q7 (gates P2 shadow + P3 writes).
20. T3/T4/T5/T7 (pack-gated / cross-repo journal session).
21. Owner decision: ~800-doc `new` backlog backfill vs leave.
22. First-week margin threshold review against live decisions (shadow).
23. Audit paperless-gpt (Go) tag-id resolution under the 3.3.1 filter
    semantics — works in prod, but the class was proven today.
24. Quarterly re-audit 2027-01-02 (T8; calendar already owns it).
25. iotop/btop/nvtop dashboards: harden or keep (Q3 below).

## g) Questions I cannot answer myself

1. **Corpse-pile:** it deepened between 12:45 and 14:08 (avg300 61%→82%,
   D-state kworker now 55 min old). Do you want agent-side remediation
   attempted at your go (identify the dead mount, shed the reader pile),
   or do you drive it (`pre-reboot-check` + reboot), or leave it to
   self-resolve? I did not touch it — freeze-class territory.
2. **Deploy authority for THIS go-live:** row 99's general authority
   question is still open; concretely now — do you fire the paperless
   deploy yourself in a calm window, or do I fire it under the quiescence
   protocol at next dispatch?
3. **The always-on nvtop/btop/iotop ghostty dashboards** pile into every
   D-state corpse (97–100% io.pressure). In scope to harden (scope-level
   restart, replace iotop with a collector), or keep as-is because you
   watch them live?

---

*Report basis: this session only (attempts 14–19, one deploy attempt,
surface close-out). No unrelated research performed. Waiting for
instructions.*
