# Stalwart Single-Truth — Execution Session 1 Status

> Execution kick-off of the 2026-10-29 Pareto plan
> (`docs/planning/2026-10-29_22-11_stalwart-single-truth-pareto-execution-plan.md`).
> Session window: 2026-10-29 ~22:05–22:38 CET. Report written 22:38 after the
> owner requested a full stop-and-report. Evidence rule: every claim below is
> `verified <how>` (command output, git hash, test run) unless marked `inferred`.

## Context at session start

Owner gave the blanket GO ("the WHOLE TODO LIST") at ~22:05. Execution began
immediately at tier 1 (the 1% gate: doctrine amendment + CalDAV probe). An IO
storm (PSI io some avg10 peaked 95.6%, still 44–60% at report time) gated all
nix/VM work per the repo's own admission-gate doctrine; the session pivoted to
storm-immune code work (pim-sync build) while the storm runs.

**Concurrent sessions:** a live peer wave in crm (contact engagement, issues
#2/#3/#4) and crush-0990 deploys in SystemNix were active the whole time; one
SystemNix commit needed a 5-attempt retry loop against index.lock contention.

---

## a) FULLY DONE

1. **Task 1 — DATA-MESH constitution amendment (crm)** — verified `git show 507595b` + grep (3 owner cells). Landed via daemon commits `6964503`+`507595b` (content complete; see §d7 for the commit-message caveat):
   - Owner table: Contacts = **Stalwart (nix-email)**, Calendars = **Stalwart**, journal demoted to relations/companies/deals/tasks + read-only people projection.
   - Spoke table rewritten: Google Contacts IN+OUT (`bot:pim-sync:<acct>`, field-scoped writes + quarantine + caps + dry-run default), Stalwart CardDAV/CalDAV = HUB row, Google Calendar IN+OUT (`gcal:<acct>`), Kith people projection (`carddav-in:<acct>`, read-only).
   - Amendment note in the header: rationale (zero contacts = free window), gate (CalDAV probe), fallback (Mesh A), plan pointer.
   - Principle 1 closed ("named 2026-10-29: Stalwart"), §4 artifact rows, §5 namespace table (`carddav:` RETIRED, `carddav-in:`, `gcal:` added) + InboxClean alignment note rewritten.
   - dprint-formatted via `nix develop -c buildflow -s dprint-format --fix` (crm step green).
2. **Task 2 — doctrine propagation, all three repos** — verified git hashes:
   - pbx-artmann `docs/architecture/data-ownership.md`: contacts "no declared owner" → declared, calendar implicit → declared + gated, Gap 1 rewritten to "declared but not yet provisioned", evidence row added. Commit `15b25c6` (clean tree, hooks green).
   - SystemNix `docs/agents/data-ownership.md`: contacts + calendar inventory rows rewritten to Stalwart/pbx.artmann.tech; Known gaps bullets 1+2 rewritten (D1/D2 decided; free-window note; 139 route = Stalwart; Google ladder superseded by pim-sync). Commit `cd32cfd76`.
   - SystemNix `docs/todo/services.md`: D1/D2 row `[x]` DECIDED (Mesh B + field-scoped writes), row 16 calendar owner `[x]` decided (a), row 366 (139 import) route superseded to CSV→vCard→Stalwart, row 367 (Google ladder) superseded by pim-sync task 8. Same commit `cd32cfd76`, landed at retry-attempt 5, all pre-commit hooks green (link check, gitleaks, whitespace).
   - Cross-check grep (task 2.4): no "journal is contacts truth" remnants in the three doctrine docs; one stale see-also line fixed (crm.md described as relations-truth now).
3. **Task 3.1 — CalDAV probe scaffold** — verified file listing + `py_compile` exit 0. `nix-email/docs/probes/2026-10-29-caldav-01626/`: README (setup, coverage, PENDING verdict) + `caldav_probe.py` — 14 verdicts (C1 well-known → C14 calendar-query time-range), stdlib-only, mirrors the 10-19/10-28 CardDAV suite style, port overridable via `CALDAV_PROBE_PORT`.
4. **Task 10 — gcontacts + carddav core extraction into pim-sync** — verified `go test` green + commit `66a04cb`:
   - Ported stdlib-only: People client (pagination + tombstones), OAuth loopback consent + token cache, atomic 0600 state + EXPIRED_SYNC_TOKEN retry, multi-account registry, single-flight multi-runner, DAV client (Discover/Books/EnsureBook/Put-with-If-Match/Delete/Multiget/SyncCollection), vCard 4.0 emitter, the in-memory contract test server (carddavtest).
   - CRM-journal seams replaced: new `Runner` around a `Syncer` interface (keeps single-flight + token retry + token-persists-last; drops journal projection convergence — Stalwart reads are synchronous). Actor renamed `bot:pim-sync[:<acct>]` per the amended spoke table.
   - All ported plain tests green under `GOTOOLCHAIN=go1.27.2` (syncfile, gcontacts, carddav). `golang.org/x/oauth2` v0.37.0 admitted as the STACK.md-anticipated OAuth exception.
5. **Task 9 (partial credit) — pim-sync repo born**: `~/projects/pim-sync` git-init'd (master), `STACK.md` written per the stack-selection skill (profile table, chosen foundation: stdlib runtime + cmdguard + go-nix-helpers + BuildFlow; 8 deliberate exclusions incl. go-cqrs-lite with reasons; wiring order; decision log), `go.mod` at fleet floor 1.27.2, `.gitignore` + proprietary LICENSE.
6. **Skills honored**: buildflow, how-to-golang, stack-selection all loaded before the corresponding work (probe formatting, Go code, new-project scaffolding respectively).

## b) PARTIALLY DONE

1. **Task 15 (guardrails)** — `internal/guard` written: Policy (DryRun/MaxChanges/ClearedDeletions), per-run Guard (AllowWrite with abort-and-stay-aborted caps; Quarantine hold-unless-cleared, kind-scoped), Report. 4 tests, all green AFTER a semantics fix (see §d6). NOT yet wired into any leg (legs don't exist yet). Uncommitted in worktree.
2. **Task 13 (merge engine)** — `internal/merge` written: three-way field merge (base = last-agreed provenance; Diff → None/TakeRemote/TakeLocal/Conflict; Apply resolves and keeps conflicted bases; Summarize/ChangedFields for review lists + field-scoped payloads). 6 tests: 5 green, 1 RED (see §d1 — engine correct, test scenario mislabeled). Uncommitted. The provenance JOURNAL persistence (13.1's per-run state) is still to build on top.
3. **Task 9 remainder**: flake.nix (go-nix-helpers), `.buildflow.yml`, CI, README/AGENTS.md, cmdguard CLI wiring — all pending.
4. **SystemNix dprint-format**: my doctrine-table edits are committed but UNALIGNED (the buildflow dprint step was REFUSED by the nix admission gate mid-storm — PSI 84% at attempt). Cosmetic debt; rerun `nix develop -c buildflow -s dprint-format --fix` at the first calm window.

## c) NOT STARTED

- Tasks 3.2–5.4: the probe RUN (demo VM boot + transcript), verdict README, nix-email FEATURES.md CalDAV row, GO/NO-GO gate note.
- Task 6 (provision plan objects, demo VM → pbx dialect), Task 7 (PII restore drill + runbook) — both VM/archive-dependent.
- Task 8 (GCP OAuth client + consents — owner-gated clicks; instruction package not yet drafted).
- Tasks 11–12, 14, 16: contacts IN leg code (vCard upsert, dedupe ladder, dry-run review list), Stalwart write path tests, People write path, 139 CSV→vCard import.
- Task 17 (SystemNix service module), 18 (four artifacts), 19 (soak tooling).
- Tasks 20–23 (calendar legs: gcal client, normalization, VEVENT writer, caldav client, migration, write-back, scheduling policy).
- Tasks 24–25 (Kith projection spoke in crm; contact-leg retirement + FEATURES/WHERE-IS-MY-DATA updates).
- Tasks 26–27 (device pilot, Google terminal role — owner physical/decision acts; punch lists not yet drafted).
- pim-sync: vCard PARSER (needed for OUT leg + projection — only the emitter is ported), CLI, flake, gate.

## d) TOTALLY FUCKED UP (own goals, all diagnosed)

1. **The pim-sync tree is RED right now**: `TestApplyResolvesAndKeepsConflictBase` fails. Root cause FOUND (not yet fixed): the test labels `tel` a "conflict" but its data (local=999, remote=123, base=123) is a clean TakeLocal — `Apply` correctly advances the base to 999; the assertion expects the old base. The ENGINE is right; the TEST scenario contains zero actual Conflict fields. Fix: give the scenario a real both-changed field and assert base-keep on THAT.
2. **Heredoc-in-command parse failure** on the first pim-sync commit (`could not parse command: 25:74`) — two nested heredocs in one bash call. Worked around with `git commit -F <msgfile>`; lesson: message files for every commit.
3. **Two index.lock daemon races** (crm at 22:23, SystemNix at 22:27): one-shot commits collided with the auto-commit daemon/sibling session. Crm landed under the daemon's chore message; SystemNix needed a 10s×40 retry loop (landed attempt 5). Lesson: go straight to the retry-loop pattern in contended repos.
4. **False dependency claim**: I declared the extracted core "stdlib only" from a partial import scan; `oauth.go` imports `golang.org/x/oauth2`. Caught by the first build. STACK.md already anticipated the OAuth exception — but the claim should never have been made before grepping every file's imports.
5. **1 of 9 multiedit edits failed** on DATA-MESH (line-wrap mismatch in the alignment-note paragraph — I guessed the wrap instead of copying it). Fixed by re-viewing; cost one round trip.
6. **Guard zero-value contradiction**: doc comment said "zero value = dry-run" while the code (and test) treated MaxChanges=0 as no cap — a live `Policy{}` would have written unboundedly. Resolved by design decision: live-without-cap REFUSES all writes (cap is mandatory in production). Test rewritten to pin the refusal.
7. **Lost commit message on the constitution amendment**: the daemon won the index race, so the DATA-MESH amendment rides `chore: auto-commit` instead of my descriptive message. Content verified intact; amending mid-peer-wave was (correctly) judged too risky. Provenance lives in the doc itself.

## e) WHAT WE SHOULD IMPROVE

- **Derive test expectations from executed behavior, not from the scenario label I imagined** (§d1): run Diff mentally (or in a scratch test) BEFORE writing assertions about which verdict a field gets.
- **Grep ALL imports of copied code before declaring a dependency posture** (§d4).
- **Retry-loop commits from the start** in daemon-contended repos; single-shot `git commit` is the exception, not the default (§d3).
- **Commit smaller milestones**: guard+merge sat uncommitted when the interrupt arrived; the tree is red at a moment it could have been green-at-a-hash.
- **Poll PSI before phases, not only when a gate refuses**: the storm shaped the whole session; a 30-second `/proc/pressure/io` check before each phase boundary would have surfaced the deferral decision earlier and more calmly.
- **The storm itself is partly ours**: multiple concurrent agent sessions (crm wave, crush-0990 deploys, this build) fed the same IO pressure we were all being gated by. Worth a fleet-level conversation about session serialization during storms.

## f) NEXT UP TO 50 (execution order, mapped to plan tasks)

1. Fix the merge test scenario (real Conflict field); `go test ./...` green; commit guard+merge (13.x core, 15.x core).
2. Commit-message-file pattern for all further commits (lesson §d2).
3. Poll `/proc/pressure/io`; at avg10+avg60 < 20% + no guard trip: boot demo VM (`nix run .#vm` from nix-email).
4. Run `caldav_probe.py > caldav-probe.log`; capture `vm-console-excerpt.log` (tasks 3.2–3.4, 4.1–4.5, 5.1).
5. Write the verdict README (PASS/FAIL table + known-deviance list) (5.2).
6. Add the CalDAV row to `nix-email/FEATURES.md` with transcript pointer (5.3).
7. Draft the 5.4 GO/NO-GO note for the owner (expected GO; fallback Mesh A documented).
8. Rerun SystemNix `buildflow -s dprint-format --fix` at the calm window (deferred debt).
9. Write `internal/carddav/parse.go` — vCard parser (unfold, UID/FN/N/EMAIL/TEL/ORG/CATEGORIES/REV), table-tested.
10. Write `internal/personcard` — Person↔Card mapping + UID = stable hash of `google:<acct>/resourceName` (11.1).
11. Write `internal/contactsin` — the IN-leg `Syncer`: Discover → EnsureBook → etag map → upert (If-Match, 412 handling per the dialect) → dedupe ladder (UID → email → name) → quarantine deletions.
12. Dry-run review-list rendering (create/update/skip + dedupe candidates) (11.2–11.3).
13. IN-leg integration tests against `carddavtest` (11.1, 12.3 pattern).
14. Chaos test: wiped owner book must NOT wipe Google (15.4) — leg-level pin.
15. Provenance journal persistence per leg via syncfile (13.1 completion).
16. People write path: `people.updateConnection` with field masks (14.2).
17. OUT leg: SyncCollection delta → parse changed cards → three-way diff → field-scoped updates (13.2 wiring).
18. Round-trip test: owner edit → Google; Google edit → owner (14.3).
19. Cross-account dedupe candidates report (11.3 second half).
20. CSV→vCard importer with Twenty field map + provenance note per card (16.1).
21. Import dry-run counts reconcile 139/61 against demo VM book (16.2).
22. Update services.md:366 row when the import path is proven (16.3).
23. gcal client: events.list + sync tokens + page tokens (20.1).
24. Event normalization: Google JSON → internal event (20.2).
25. Calendar-set whitelist config (20.3).
26. Fixture tests: weekly RRULE, all-day, TZ-crossing (20.4).
27. VEVENT writer: RRULE + RECURRENCE-ID + EXDATE fidelity (21.1).
28. Attendee queue-not-push policy flag (21.2).
29. Event round-trip fuzz: semantic equality across the loop (21.3).
30. `internal/caldav` client: discovery reuse + calendar-query + PUT/GET + sync-collection (22.1).
31. Calendar migration dry-run tooling: counts + review list per calendar (22.2).
32. Calendar write-back leg through the same merge engine + guard (23.1).
33. Scheduling policy: invites originate owner-side only; incoming iTIP → queue (23.2).
34. Calendar quarantine + caps tests mirroring 15.x (23.3).
35. Prometheus textfile collector: per-leg changes/conflicts/quarantined/last-success (17.3).
36. Load `cmdguard` skill; wire `cmd/pim-sync` (sync-contacts, auth, import-csv, dry-run flags).
37. Load `nix-private-go-repos` skill; write flake.nix (go-nix-helpers + cmdguard private dep + vendorHash chase).
38. Write `.buildflow.yml` (env GOTOOLCHAIN go1.27.2); first full gate run.
39. pim-sync README + AGENTS.md (commands, dialect notes, invariants).
40. Run `stack-drift-check.sh`; register pim-sync in `meta`.
41. Task 6: provision plan objects (2 address books + 2 calendars) in demo VM; verify via DAV discovery (6.1–6.2).
42. Task 6: port objects to pbx host config (nix-email provision dialect) — deploy gated on owner (6.3–6.4).
43. Task 7: restore drill from the nightly store archive in demo VM + `PII-RESTORE-DRILL.md` runbook (7.1–7.3).
44. Task 8 prep: GCP OAuth instruction package for the owner (client creation, production publishing, 2× consent, refresh-token >7d verification).
45. Task 17: SystemNix pim-sync module (timer jittered 5min, sops, onFailure, start-limit) (17.1–17.2, 17.4).
46. Task 18: four artifacts (contract doc, ops runbook incl. kill switch, boot posture, DATA-MESH spoke links).
47. Task 19: soak report script + drift alert thresholds (19.1–19.2).
48. Tasks 24–25: Kith projection spoke (crm: Stalwart→journal read-only, links not copies) + FEATURES/WHERE-IS-MY-DATA re-pointed rows + boots-clean verify.
49. Tasks 26–27 prep: device-pilot instructions + Google terminal-role decision memo (owner punch list).
50. Soak week kickoff once legs are live (19.3 depends on wall-clock).

## g) QUESTIONS FOR THE OWNER (cannot be figured out from here)

1. **GCP project for the pim-sync OAuth client (task 8)**: reuse the SAME GCP project InboxClean lives in, or a fresh project? (I cannot see your GCP console layout; it changes the instruction package and the client-secret handoff.)
2. **Push/remote authorization**: the crm amendment (507595b) and pbx-artmann doctrine commit (15b25c6) are local-only — crm is mid-peer-wave with unpushed commits, and your earlier push authorization covered the SystemNix plan doc only. And pim-sync has NO remote yet: should I create `LarsArtmann/pim-sync` on GitHub (gh) and push all three when the peer wave settles?
3. **Probe timing**: boot the demo VM tonight as soon as PSI calms (background-poll + autonomous run), or hold VM work for the next working session? (Both are safe; the storm has been easing 95→44 avg10 over the session.)

— Session paused here per owner instruction; todos updated to execution-phase state; awaiting GO on the above.
