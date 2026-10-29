# Paperless-triage P1 green end-to-end in VM; deploy leg blocked by the IO-PSI corpse-pile (2026-10-29 12:55)

Session: resumption of `crush-triage-exec-2026-10-27` (plan
[2026-10-27_21-17](../planning/2026-10-27_21-17_paperless-decision-triage-productionization-plan.md);
prior reports 2026-10-27_22-43 + 2026-10-28_00-20). Scope: finish T1d (the VM
test), static verification, deploy, surface close-out.

## §a What landed this session

1. **T1d GREEN — `tests/test-paperless-triage.nix` exit-0** (attempt 19,
   2026-10-29 ~12:10): real paperless-ngx 3.3.1 + PostgreSQL VM, mock
   llama-chat with the exact top_logprobs shape. Proven end-to-end:
   Faktura → margin 0.986 → PASS → `paperless-gpt-auto` tag; letter →
   margin −0.986 → REVIEW → `needs-review`; token mint 0400 chown;
   metrics textfile (decisions pass/review 1/1, refusals 0);
   watermark+MRU idempotence (second sweep `processed=0/0`).
2. **Three paperless-3.3.1 API contract bugs** (runbook
   paperless.md §Decision-triage gate, traps 1–3; module comments at the
   call sites):
   - `bulk_edit modify_tags` requires BOTH `add_tags` AND `remove_tags`
     — every production sweep would have 400'd on every write. Found
     only after making tag_doc carry the `--fail-with-body` body in its
     WARN (never swallow failure reasons — the fix named the DRF error
     in ONE iteration after four blind ones).
   - `/api/tags/?name=` is NOT a server-side filter on 3.3.1 (TagFilterSet
     declares `name__istartswith/iendswith/icontains/iexact`; an
     unmatched `name=` param is silently IGNORED → ALL tags return,
     `results[0].id` = lowest pk). This broke the sweep's `tag_id_of`
     AND — worse — the **T6 provisioner's existence check**: `.count > 0`
     on an unfiltered response means once ANY tag exists the declarative
     drift-heal creates NOTHING. The exact SUPERB-restore scenario T6
     was built for would have silently no-opped in production. All three
     consumers now exact-match client-side over `?page_size=100000`.
   - (test-side) the mock classified the whole request body; the prompt
     template itself contains "receipt"/"VAT" → every doc YES. Fixed by
     decode-then-excerpt between the sweep's `---` markers.
3. **Script-class fixes** in the sweep: the selftest EXIT trap outlived
   its function-local `t` (nounset → "line 1: t: unbound variable" at
   exit 0 — bash reports trap errors at "line 1"); `ensure_tag` echoed
   "created tag" to stdout, polluting the captured id into invalid JSON
   on any fresh/restored instance (would have fired in prod after any
   SUPERB-class restore — the VM caught it because paperless-gpt is
   options-mocked there).
4. **README gatus stamp 247→250** — `checks.doc-counts` caught the triage
   pair ("Paperless Triage Unit" + "Paperless Triage Verdict Endpoint")
   that the 2026-10-28 stamp (module count only) missed; + the parallel
   media-atlas endpoint wave. Attribution verified by listing endpoint
   names through the eval.
5. **Static verification:** evo-x2 eval gate green; `nix flake check
   --no-build` exit-0 (after the re-stamp); `nix fmt --` canonical
   (0 changed); todo-system structure clean.

Attempt ledger (this session): 14 selftest-trap-scope → 15 first full
sweep run (bulk_edit 400, body swallowed) → 16 body surfaced
(`remove_tags not specified`) → 17 remove_tags fixed, name-filter trap
found → 18 all-functional-green but drv exit-1 → 19 identical content
exit-0 (the 18 exit-1 was a transient host-load casualty in the runner's
post-script `machine.execute("sync")` step — no test content difference).

## §b The deploy leg — deliberately not forced

`nix run .#deploy` (after a clean 4×60 s quiescence poll) was REFUSED at
the ENTRY gate: IO PSI some avg10 68.77% → 76.38% (worsening across the
session) with **idle disks** (per-device util ≤0.2%) — the corpse-pile
signature (crash3 class): events_unbound kworkers entering D-state
(~28 min old), and the user's nvtop/btop/iotop monitoring ghostty scopes
piled at 97–100% cgroup io.pressure behind them (readers hanging on
/proc of D-state tasks). Both 2026-08-22 freezes had builds as
contributing load; `DEPLOY_FORCE_PRESSURE=1` was NOT used. No parallel
session owns this in the latest status reports — **the owner should look
at the D-state pile** (stability runbook territory; likely needs the
dead-mount/corpse verification the gate message prescribes, possibly a
reboot through `nix run .#pre-reboot-check`).

Consequence: the module sits in the tree with `paperless-triage.enable
= true` on evo-x2, VM-proven, waiting for one clean deploy window.
Post-deploy smoke list lives in paperless.md §Decision-triage gate.

## §c Parallel-session friction handled

- media-atlas wiring poisoned every flake eval for ~25 min (rev-pin →
  float → missing registry row, in sequence); waited it out with a
  90 s-interval poller (17th probe green). Their module + endpoints now
  ride the same tree; the README re-stamp covers their endpoint wave.
- services.md shifted under me mid-edit once (11:22) — re-read, anchors
  intact, re-applied.
- One daemon commit boundary mid-session; no amend needed.

## §d What deliberately did NOT change

- Plan §6 owner pack (Q1–Q7), Clef keys, 9-general-docs label audit,
  T3/T4/T5/T7 — untouched, still gated.
- The ~800-doc `new` backlog mass-triage — still owner-gated (P1 scope).
- Row 589 ("Design the confidence gate") left as-is: its lifecycle
  belongs to the 2026-10-27 design session, superseded by row 588/103.

## §e Honest misses this session

- Attempt 18's drv exit-1 cost one extra full VM cycle because I read
  the failure from a stderr-suppressed rerun instead of capturing the
  log the first time — the "exit status 1" line was ambiguous until the
  full-capture rerun proved content-identical green.
- I initially misattributed the `?name=` behavior to "filter ignored =
  icontains" from memory; the filters.py read (CHAR_KWARGS dict-form)
  was the actual proof. Read the source before theorizing.

## §f Follow-ups (self-harvest ledger)

1. **DEPLOY + post-deploy smoke** (paperless-triage go-live + T6 live
   heal + `grep ensured` verify) — already harvested: services.md row
   103 + TODO_LIST row 588 carry the re-fire procedure; plan tombstone
   EXECUTING until live verify. NOT a new row (row 103 owns it).
2. **IO-PSI corpse-pile incident** — harvested as a `[watch]` row in
   docs/todo/stability.md (owner visibility; gate output is the
   evidence).
3. Row 105 continuations (b)/(d) marked DONE (T2) in both surfaces —
   (a)/(c) stay blocked:user.
4. No other open follow-ups: the 3.3.1 traps are documented (runbook +
   module comments), the README stamp is current, CHANGELOG entry
   written, no secrets touched.
