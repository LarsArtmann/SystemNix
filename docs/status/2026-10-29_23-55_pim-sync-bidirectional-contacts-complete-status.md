# pim-sync bi-directional contacts COMPLETE — session 3 status

> Continuation of plan v2
> (`docs/planning/2026-10-29_22-42_stalwart-single-truth-remaining-work-pareto-v2.md`).
> Session 3 = 23:26–23:55, agent-autonomous (owner blanket GO). All code
> claims below are backed by `GOTOOLCHAIN=go1.27.2 go test ./... -count=1`
> = 9/9 packages green + `go vet` clean at 23:54.

## a) FULLY DONE AND VERIFIED

| What | Evidence |
| --- | --- |
| Plan v2 mermaid validated (mmdc exit 0); plan committed + pushed; probe files committed | SystemNix was in sync at 23:26; nix-email `4079eed` |
| Task 4 — vCard parser `internal/carddav/parse.go` (unfold/params/groups/BOM/LF tolerance; UID/FN/N/EMAIL/TEL/ORG/CATEGORIES/REV/NOTE; round-trip + 13 deviance tests) | carddav pkg green |
| Task 5 — `internal/personcard` (StableUID pinned vector, Card/Record mappings, Stalwart TEL-dialect canonicalization; load-bearing invariant: `RecordFromPerson == RecordFromCard(parse(CardFromPerson(p).Emit()))`) | personcard green |
| Task 6 — IN leg `internal/contactsin` (discover→EnsureBook→snapshot→upsert with If-Match/412 dialect→squatter eviction→tombstone quarantine→dry-run review list; Syncer impl) | contactsin green |
| Task 7 — dedupe ladder (email rung, name+org rung, weaker-rung suppression, cross-account scan, snapshot foreign-card scan, RenderSummary) | contactsin green |
| Task 8 — integration + chaos pins (runner-level idempotence; wiped-book→cap abort; Google-emptied→quarantine holds; mid-run 412→refetch→re-PUT via new `carddavtest.ConcurrentEditOn` knob) | integration tests green |
| Task 11 — OAuth package `pim-sync/docs/oauth-setup.md` (GCP choice rec, Desktop client steps, production-publishing rationale, per-account consent, day-8 refresh recipe, sops path contract) | doc committed (daemon) |
| Task 12 — provenance persistence `internal/provenance` (per-uid last-agreed records inside `gcontacts.State.LegState`, one atomic write with the sync token; corrupt = safe full re-merge; dry-run never settles) | provenance + contactsin green |
| Task 13 — People write path `gcontacts/update.go` (PersonPatch, field-group masks, UpdatePerson PATCH `:updateContact`, DeletePerson with 404 absorption, retry classification) + `personcard.PatchFromCard`/`GroupsFromChangedFields` | gcontacts + personcard green |
| Task 14 — OUT leg `internal/contactsout` (carddav sync-token deltas, three-way Diff vs provenance base, TakeLocal-only masked writes, TakeRemote left to IN leg, conflict queue, deletion quarantine mirror, correct settle rule that prevents ping-pong) | contactsout green |
| Task 15 — E2E round-trips (owner edit→OUT→Google→IN→settle; Google edit→IN→book→OUT no bounce; 3 idle rounds = zero writes both directions; cross-account same-human: both UIDs kept + candidate reported) | e2e green |
| Task 16.1–16.3 — Twenty importer `internal/twentyimport` (field map, composite identity, source-scoped `twenty:` UIDs, NOTE provenance via `Config.CardNote`) — LIVE dry-run against the real dump: **139 rows → 137 unique + 61 companies, reconciling the rehearsal receipt 61/137/2 exactly** | `PIMSYNC_TWENTY_DUMP=… go test -run TestLiveDumpDryRun` PASS |
| Task 16.5 — services.md row updated (implemented + verified; landing owner-gated) | commit incl. `b686c7c56` |
| PSI calm-window poll running since 23:26 (script `/tmp/psi-poll.sh`, log `/tmp/psi-poll.log`, flag `/tmp/psi-calm.flag`) | storm continues: io_sum 121–166, guard tripped |

## b) PARTIALLY DONE

- **Tasks 1–2 (CalDAV probe RUN + verdict):** authored + committed; RUN
  blocked by the IO storm the whole session (PSI never below calm bar;
  admission gate would refuse the VM anyway).
- **Task 3 (storm debt):** dprint-format needs a calm window; SystemNix
  now **ahead 2** (daemon commits incl. mine + sibling crush-0990 wave) —
  push held mid-sibling-wave per plan §6.
- **Tasks 9–10 (provision + PII drill):** VM-gated, not started.
- **7.5 / 2.3 / 9.4 / 11-consents / 16.4:** owner gates open, waiting.

## c) NOT STARTED

Tasks 17–27 (metrics, CLI, flake/buildflow, README/AGENTS/meta,
SystemNix module, four artifacts, soak tooling, gcal client, VEVENT
writer, caldav client + migration, Kith projection + retirement). All
storm-immune code work except 21.x deploy and 26.3.

## d) TOTALLY FUCKED UP (all fixed in-session; none left broken)

1. **Href-encoding mismatch (the big one):** the server returns the BOOK
   href percent-encoded (`user%40example.test`) but CARD hrefs decoded —
   prefix filters and refetch matching silently matched nothing (second
   runs re-created cards). Fixed with leg-level `normalizeHref` on EVERY
   boundary. Real Stalwart lesson: normalize hrefs at the edge, compare
   decoded.
2. **fakeGoogle edit lost twice** to daemon/gofmt write races (edit tool
   "modified since read"); re-applied via python atomic write. Lesson:
   daemon-contended repos get python-based edits for multi-hunk changes.
3. Candidate A/B ordering was map-iteration-nondeterministic → flaky
   test; fixed with `orderedPair`.
4. Pinned UID vector mismatch (StdEncoding vs HexEncoding) — caught by
   the vector, fixed to StdEncoding.
5. Imagined test labels AGAIN (phone canonical 11 vs 12 chars) — executed
   values win; this lesson keeps recurring.
6. Small self-inflicted compile errors (BOM literal in source,
   maps.Keys iter.Seq, CutPrefix arity, Builder.Itoa) — all caught by
   build/test immediately.

## e) IMPROVEMENTS (what I should have done differently)

- Read the services.md row 370 fully before writing the import
  expectation: the 61/137/2 receipt was already there; I wrote 139 and
  was corrected by execution.
- The href normalization belongs in the carddav CLIENT (one place), not
  two legs; refactor opportunity when task 26 caldav client lands.
- I fought the auto-commit daemon for 2 explicit commits before accepting
  it as the committer; should have switched to verify-after-green from
  the start (daemon lands within seconds).

## f) NEXT (ordered)

1. Calm window → boot demo VM (1.2) 2. Run probe (1.3) 3. Console
excerpt + shutdown (1.4) 4. Verdict README C1–C14 (2.1) 5. nix-email
FEATURES row (2.2) 6. GO/NO-GO note (2.3 🧑) 7. dprint storm debt (3.1)
8. SystemNix push after sibling wave (3.2) 9. crm/pbx push call (3.3 🧑)
10. Provision demo objects (9.1–9.2) 11. pbx dialect port (9.3) 12.
Deploy provision (9.4 🧑) 13. PII restore drill + runbook (10.1–10.3) 14.
Owner OAuth clicks (11 🧑) 15. Day-8 refresh check (11.3) 16. Metrics
collector (17.1–17.2) 17. cmdguard CLI (18.1–18.4) 18. flake +
buildflow gate (19.1–19.4) 19. README/AGENTS/meta (20.1–20.3) 20.
SystemNix module (21.1–21.5) 21. Four artifacts (22.1–22.4) 22. Soak
tooling (23.1–23.3) 23. gcal client (24.1–24.4) 24. VEVENT writer
(25.1–25.3) 25. caldav client + migration (26.1–26.5) 26. Kith
projection + retirement (27.1–27.7) 27. Real import approval + run
(16.4 🧑) 28. First cross-account dry-run review to owner (7.5 🧑) 29.
href normalization refactor into carddav client 30. plan v2 errata note
(137-count + href lesson) 31. Phase-B OAuth scope re-consent when OUT
goes live 32. Soak week start + daily reports 33. Device pilot (27.6 🧑)
34. Google terminal role (27.7 🧑) 35. Closing report + docs
cross-check.

## g) QUESTIONS (3)

1. **GCP project for pim-sync OAuth:** fresh `pim-sync-prod` (my
   recommendation — quota + consent isolation) or reuse InboxClean's?
2. **Pushes:** SystemNix is ahead 2 mid-sibling-wave (push now or hold?);
   crm ahead 8 / pbx ahead 5 from the peer wave — push or keep holding?
3. **pim-sync GitHub remote:** create now (private `pim-sync`) or after
   flake/CI (task 19) so the first push is buildable-from-clone?
