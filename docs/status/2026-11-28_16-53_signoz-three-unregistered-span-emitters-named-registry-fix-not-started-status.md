# Status: signoz service-map question answered, three unregistered span emitters named, fix not started

**Date:** 2026-11-28 16:53 CET
**Session span:** about 09:47 to 16:53 (the first half is recorded in
`2026-11-28_11-56_signoz-service-map-sparse-edges-only-root-cause-doc-notes-and-self-review.md`;
this report covers the work after it)
**HEAD at authoring:** `bbff692f9`
**Scope:** only the `/service-map` thread: why the page is sparse, and why
services with spans are not registered as trace emitters

---

## a) Fully done

| Item | Evidence |
| ---- | -------- |
| Root cause of the sparse service-map page (it draws edges, not services) | Verified from the pinned SigNoz source and the page's own API in the 11:56 report |
| Doc note: service-map page semantics | `docs/agents/monitoring.md:83` |
| Runbook: flip procedure uses `nix flake update <repo>` | `docs/services/signoz-coverage.md`, step 2 |
| Runbook: known gaps refreshed to the live four, plus a paragraph naming the unregistered emitters | `docs/services/signoz-coverage.md`, "Known gaps" |
| Question "why are emitters with spans not registered" answered | Section "The answer" below |
| Registry mechanics traced to source | `signoz-coverage.nix:264-312`, `integration.nix:767-776`, `monitor365.nix:720` |

## b) Partially done

- **Unregistered-emitter paragraph in the runbook** names the three emitters
  but does not yet carry the origins found in this half (PBX host, CI
  tests, selftest). Not updated.
- **Stalwart wiring location**: the receiver side is known
  (`platforms/nixos/system/configuration.nix:1795`, the collector binds
  `0.0.0.0` for the PBX over netbird). Where the PBX's Stalwart export is
  configured was not found: no `otlp`/`otel` match in `nix-email.nix` or
  `configuration.nix` outside that comment.
- **`dnsblockd-test` origin** is inferred, not proven: the journal shows a
  Forgejo runner build of `github.com/larsartmann/dnsblockd` test packages
  ending 2026-11-26 23:36:16, and the last span is 23:36:06. No code line
  setting that service name was read.

## c) Not started

- Registry entry for `stalwart` (needs a non-unit key, see e) below).
- Allowlist or re-routing of `dnsblockd-test` and `ai-meter-selftest`.
- Runtime check "service name seen in the store but not in the registry".
- Any eval, format run or deploy for the above: nothing was edited in this half.
- TODO rows for the fix: none minted.

## d) Went wrong

- **Wrong count in the premise.** The question said 2 unregistered emitters;
  the store says 3. Corrected up front, but the earlier report's wording
  invited the 2 by listing them without a count.
- **Two failed ClickHouse probes in this half** before a usable one:
  `any(resource_string_telemetry$ $sdk$language)` was a guessed column name
  and a syntax error, and `serviceName` does not exist on
  `distributed_span_attributes`. Neither result was used; the emitter
  origins rest on the journal and the timestamps instead.
- **The `ls /etc/systemd/system | rg -i 'stalwart'` probe returned no
  stalwart unit** and I read it as "not a local unit". That agrees with the
  PBX note, but the rg pattern sat in a pipeline whose exit code I did not
  check; treat it as consistent, not as proof.

## The answer given

- The registry is filled only by hand: explicit `expected` entries
  (`signoz-coverage.nix:388-535`, `monitor365.nix:720`) or the
  `services.integration` fan-out (`integration.nix:767-776`, source of the
  `indexer-web` entry). Nothing derives entries from what actually emits.
- The reverse assertion (`signoz-coverage.nix:291-295`) sees only local
  systemd units that set `OTEL_EXPORTER_OTLP_ENDPOINT`.
- So an emitter that is remote, config-wired, or not a unit can send spans
  indefinitely with no entry and no alert.

| Emitter | Spans | First to last seen | Why invisible |
| ------- | ----- | ------------------ | ------------- |
| `stalwart` | 72 | 2026-11-13 08:57 to 2026-11-28 09:03 | Runs on the PBX, another host |
| `dnsblockd-test` | 37 | 2026-11-14 19:34 to 2026-11-26 23:36 | Not a NixOS unit; CI test run |
| `ai-meter-selftest` | 1 | 2026-11-25 01:15 | One-off selftest |

## e) What to improve

1. **Runtime check for unregistered service names.** Any `service.name` seen
   in 30 days that is neither registered nor allowlisted raises a new
   `signoz_traces_unregistered` series. This is the only guard that would
   have caught all three.
2. **Registry keys are unit names.** `expected` cannot express a remote
   emitter. Add a separate `services.signoz-coverage.remoteExpected` (or
   equivalent) keyed by service name.
3. **Test traffic in the production trace store.** CI tests and selftests
   point at the production collector. Either allowlist them with a reason or
   export them elsewhere.
4. **Stalwart freshness alerting.** It is a real service with no alert if it
   stops emitting.

## f) Next (this thread only)

1. Decide the fate of the two test emitters (allowlist or re-route).
2. Add `remoteExpected` option to `signoz-coverage.nix`.
3. Register `stalwart` as a remote entry with a generous `maxAgeHours`.
4. Add the `signoz_traces_unregistered` collector leg, fail-closed like the others.
5. Negative-test the new leg in `scripts/negative-test-lints.sh`.
6. Gatus check plus SigNoz rule for `signoz_traces_unregistered > 0`.
7. Find where the PBX Stalwart OTLP export is configured and record it.
8. Prove the `dnsblockd-test` service name in the dnsblockd repo.
9. Update the runbook paragraph with the three origins.
10. Update `docs/agents/monitoring.md` with the "registry is hand-listed, assertion sees env units only" fact.
11. Owner question Q3 from the 11:56 report: keep or drop Stalwart's `from` sender address in span attributes.
12. Owner question Q1: native page or connector-based view.
13. Owner question Q2: raise traces TTL above 15 days.
14. Reconcile the 18 follow-ups of the 11:56 report with intake control.
15. Check whether other remote hosts (rpi3-dns) could emit and are equally unregistered.

No TODO rows were minted this session (intake control, ratchet at the current open count).

## g) Owner questions

1. Should CI test runs and selftests keep exporting into the production trace store, or export elsewhere?
2. Is Stalwart's trace export wanted enough to alert on a gap (it would then be an enforced entry)?
3. Of the three earlier open questions (Q1 to Q3 in the 11:56 report), which, if any, should be decided now?

## Self-harvest ledger

No follow-up of this report was harvested into `TODO_LIST.md` or a domain library. Deliberate: intake control, and every item in f) depends on question g1 or g2 except items 7, 8, 9 and 10, which are parked here until the fix is chosen.
