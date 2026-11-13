# SUPERB contacts-plan resume session — probe verdict, publishes, foreign repairs

**Snapshot:** 2026-11-13 21:58 CET (claims verified as of this stamp)
**Session scope:** resume after the 19:25 report (`docs/status/2026-11-13_19-25_superb-contacts-plan-execution-status.md`); execute its §f items 1–10 plus the feasible slice of 21–50, per the owner's directive to keep going until the list is done and verified. Everything below is this session's work only.

## Verdict in one line

**The T5.2/T5.3 runtime question is ANSWERED with a live transcript (the plan dialect cannot provision address books on this pin — books are MKCOL-only pending the owner's upstream call); §f 1–10 executed end-to-end; every repo pushed; the shared eval surface repaired after a foreign session's commit broke it; every remaining CI red is proven inherited and queued.**

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| 1 | **T5.2/T5.3 runtime probe — the decisive finding** | The resumed VM was verified alive (qemu PID 3917021, port 18080→guest 8080, root autologin in the boot log). Authenticated PROPFIND of the demo account's home set: only `default` + three old `kith-probe` books, no `Contacts`. Traced the BOOTED closure: `etc/systemd/system/stalwart-provision.service` → apply script `srm3kax…` → `stalwart-cli-1.0.13 apply --file /nix/store/9qvf9…-stalwart-provision.ndjson` (the family ndjson, so the guest DID run the family plan). Re-applied the EXACT plan with the SAME pinned CLI binary from the host over the forwarded management port (admin/demo-admin from the demo module): **`upsert` → `error: cannot upsert singleton 'AddressBook' (operation #6); use update instead`, exit 1** — so the boot apply aborted at op 6 and ops 7–10 (NetworkListener/SpamDnsblServer/Tracer/reload) never ran this boot (the demo works off the persistent qcow2 from earlier boots). Corrected `update` form → **server rejects the patch: `invalidPatch — Invalid property — Properties: demoContacts`, exit 1**. PROPFIND unchanged after both attempts. Server fingerprint from the booted unit: **stalwart 0.16.26**. Conclusion: the dialect fails at the CLI/server contract, one step before T5.1's "no parentId" ownership gap is even reachable. Probe logs: `/var/tmp/cli-apply-replay.log`, `~/.cache/t52-probe/` |
| 2 | **Demo plan repaired + verified** | The family was REMOVED from `flake-modules/demo-vm.nix` with the verdict as a pointer comment (daemon commit `d94118e`, content verified 1-file-clean); demo toplevel evals green; the ndjson derivation rebuilt fresh (`igyrswa…`) carrying **zero** AddressBook ops with the `provision-check-sort.lua` gate green; VM torn down (absolute-path kill, port 18080 released) |
| 3 | **Plan-file tick pass** | All 60 breakdown/main-table rows moved QUEUED→truthful (DONE / PARTIAL / BLOCKED (owner)) by a scripted per-row-assertion pass (abort-on-drift; zero QUEUED remain), plus a dated §8 execution addendum with commit-hash evidence per task — `7336e2c62`; `nix fmt` clean |
| 4 | **T11.1 + T11.3 pbx doctrine** | `docs/architecture/data-ownership.md`: new section — the island book classified device-local consumer cache (never synced while writable) + the four caller-ID paths table (island `findContact` digits-exact / panel `h.crmDirectory` per-render merge / CRM `Resolver` TTL caches incl. cached-absence / digit-keyed journaled read model) with file:line evidence and the deliberate-divergence rationale; gap #1's "still unverified" dialect claim replaced with the probe verdict — pbx-artmann `92c394ca`, pushed (the daemon later prettier-aligned the table, content identical, diff-verified) |
| 5 | **InboxClean full-repo race gate** | `nix run .#test-race` **exit 0**, 36 packages green incl. crmsync (log `/var/tmp/inboxclean-race3.log`) once go-cqrs-lite landed `c357d69b6` — T12's full-repo gate from §b2 of the 19:25 report is CLOSED |
| 6 | **Stack fixtures committed + verified** | Daemon `93aa685` carried exactly my 2 files (`tests/configjs_check.py` +16/−9, `tests/webphone.nix` +21/−11, nothing foreign); the re-pin sequencing note rides the addendum (§b4's CI window stands until the next per-train bump) |
| 7 | **pim-sync publish train** | Pushed `be8ce8c..74bf91a`; SystemNix `flake.lock` re-locked pim-sync to `74bf91a`; the wrapper's flip-note replaced with the real wiring `receiptsDir = "/var/lib/pim-sync/receipts"`; evo-x2 eval green with the restored option |
| 8 | **Status report addendum, stamped twice** | The 19:25 report gained the T5.2 verdict section, the §f 1–10 outcomes table, foreign-session notes, and the final verdict stamp (webphone green + CI inheritance) — pushed through `f52d352d9` |
| 9 | **§f item 9 harvest** | SystemNix: 5 actionable queue rows + watch row into TODO_LIST/services.md/monitoring.md (`5cb11174f`), pipeline rows ×4 (`1f5b84dea`, `484cd8049`, `0b7c2c866`); pim-sync tracker: art-dupl decision row (`67fcc8a`, pushed); webphone tracker: 3 rows (`a4805106`, pushed) |
| 10 | **webphone CI green-watch closed** | The parallel session's `keepRunes`/`domain.DigitsOf` dedup landed and CI run `43497710619` (7m49s) **success** — main green again; the watch row was verified-then-removed per webphone's delete-done-work convention (`d1706028`, pushed) |
| 11 | **All repos pushed** | SystemNix `f52d352d9`, pim-sync `67fcc8a`, webphone `d1706028`, nix-email `d94118e`, pbx-artmann `f73dc540` — all at parity with origin at close |
| 12 | **§f receipts** | Registry drift check run live: clean, exit 0 (T19.2 verified); pim-sync art-dupl local run: **34 new clone groups** (the `report.*++` family, exit 2) — queued with the local log as evidence since the remote gate is billing-blocked |

## b) PARTIALLY DONE

1. **The immich foreign-session repair** — three repairs landed (missing `timers.` prefix on their daily timer; their helper imported bare-lib while declaring `{ lib }:`; their converger oneshot missing from `scripts/deploy.sh`'s provisioner list — each completing the commit's own documented intent), eval went green and two CI VM legs (hermes, memory-emergency-guard) flipped green as a result. But their FEATURE (apiKeys consumers, their deploy) remains theirs to land and verify; `services.immich.apiKeys` is still `{}` today so the unit is mkIf-off.
2. **SystemNix CI** — the content gates on my tree are green (shellcheck, drift, port-uniqueness, gatus-patterns, boot, browser-history, searxng, attic VM legs), but nix-check + 3 VM legs + 3 whole workflows are red — each proven inherited (the 18:24 pre-push run shows a strict superset failure set) and queued, none fixed.
3. **§f 21–50 follow-through** — of the ~30 feasible items, ~10 handled or queued this session; the rest deliberately skipped with reasons on record (foreign-dirty files, owner gates, live-system access).
4. **The cv input's vendorHash** — enumerated via `--keep-going` (`cv-640df58-go-modules.drv` fixed-output mismatch), queued in services.md, NOT fixed (the cv session's dep bump; build-time only — eval-only gates pass, which is why every hook/CI eval gate stayed green while deploys would trip).
5. **webphone dead sibling readers** — queued in the webphone tracker (same prod-dead class as the contacts reader `4fb24b61` deleted), not deleted (their repo, their train).

## c) NOT STARTED (all verified owner/live-gated — evidence, not excuses)

- **T5.4** (pbx host): the demo verdict now SHAPE-decides it (MKCOL-based provisioning or upstream fix) — needs §g2 + a quiescent pbx tree (the foreign `gates-contract.nix` question from 19:25 remains open).
- **T6** (restore drill): needs provisioned books (blocked on the MKCOL path) + live Stalwart + an owner-supplied target.
- **T9**: still 7/7 sops placeholders; `pim-sync.enable = false` at `configuration.nix:917`. Owner paste is the gate.
- **T13 flip**: `crm_stalwart_dav_password` still PLACEHOLDER. Owner paste.
- **T15/T16**: owner clear on the 137/61 projection / owner consent + supervision.
- **GitHub Actions billing**: pim-sync quality-gates jobs refuse to start ("recent account payments have failed or your spending limit needs to be increased") — run 43492435081 annotation. No in-repo fix exists.
- **Upstream filing** of the AddressBook finding: transcript complete, owner call per §g2.
- **Retired `crmpeople:extracted` KV key deletion** on the live DB: owner recipe (rehearse on a copy).

## d) TOTALLY FUCKED UP (own failures, plainly)

1. **The 72-char subject gate bit me TWICE** — I drafted long subjects knowing the limit, and the second failure interacted badly with a chained `git commit … && git push`: the stamp commit was REJECTED while the push still ran, so the push briefly published WITHOUT the stamp in its tree; I had to re-commit and push again. Rule violated: never chain a push to a commit that can trip a gate — commit, verify HEAD, then push as its own call.
2. **Receipt sloppiness, again**: ran gitleaks against a nonexistent `.gitleaks.toml` (pim-sync has no such config — I never checked how the repo actually invokes it), and captured `$?` AFTER a pipe (measured `tail`'s exit, not art-dupl's). Both redone with capture-once-then-grep — the exact discipline §e3 of the 19:25 report said to use.
3. **Daemon-race losses continued**: every SystemNix content commit this session (immich repairs, receiptsDir, lock, addendum) was swept by the daemon before my attributed message landed; only the tick pass (`7336e2c62`) and the harvest commits survived as properly-messaged commits. The narratives now live in the report addendum instead of history — the known cost, paid again because my edit→commit gap included 2–4 minute evals.
4. **The domino walk**: three full evo-x2 evals (one per foreign repair) instead of ONE `--keep-going` enumeration after the first failure — the --keep-going rule exists for exactly this class and I still walked errors one at a time (timer → eval → lambda → eval → audit → eval). Easily 10+ minutes wasted.
5. **My own grep pattern truncated store paths**: the charclass `[a-z0-9]*-stalwart-provision[a-z0-9.]*` dropped `-apply`/`-restart-verify` (no `-` in the class), sending me after "nonexistent" paths for a round. Should have been `[a-z0-9.-]*` from the start.
6. **What I FORGOT**: (a) to re-run the --keep-going enumeration EARLY; (b) to check pim-sync's actual gitleaks invocation before running it; (c) the subject limit while drafting, twice; (d) to re-surface the 19:25 §g owner questions explicitly in my close-out message (the addendum carried them, the message didn't); (e) to reproduce the nix-check CI leg locally before concluding — I proved it red-before-my-push, but the local-green/CI-red split is still unexplained and only queued.

## e) WHAT WE SHOULD IMPROVE

1. **Gate-aware command chaining**: `git commit` that can trip the subject/hook gates NEVER gets `&& git push` on the same line. Commit → check HEAD → push, three separate steps.
2. **--keep-going FIRST, always**: after any eval-relevant foreign change (or any first eval failure), run the keep-going enumeration immediately — one pass names every root failure; the domino walk is a self-inflicted tax.
3. **Commit BEFORE the heavy eval**: for eval-relevant edits, stage+commit first (the hook re-runs the eval gate at commit time anyway) — this both salves the daemon race and forces the narrative to survive.
4. **Receipt preflight**: before a tool's first run, check its config file existence and the repo's own invocation (scripts/ + workflows); never capture exit codes through pipes.
5. **Complete charclasses** in any pattern matching store paths (`[a-z0-9.-]*`), and the standing rule: if output looks implausible, suspect the pattern before the filesystem.
6. **Probe-then-repair worked** — the demo question went from open to transcript-complete in four network commands because the exact pinned binary was runnable from the host against the forwarded port. Next time, script boot→wait→probe→teardown end-to-end in one file (§e7 of the 19:25 report, still standing).

## f) NEXT (ranked; ~50)

**Owner gates (the critical path):**
1. Owner: paste the 7 pim-sync sops values (GCP client JSON, Stalwart bot creds, 4 consents) — T9's true gate.
2. Owner: paste `crm_stalwart_dav_password` into crm.yaml — T13's gate.
3. Owner: fix GitHub Actions billing/spending limit — pim-sync CI cannot start jobs at all.
4. Owner: §g2 call — file the AddressBook dialect finding upstream (transcript is complete in the 19:25 addendum) vs accept MKCOL-only. This decides T5.4's shape.
5. Owner: the T15.2 clear on the 137/61 projection; T16 canary consent.

**CI-red triage (all inherited, all queued in pipeline.md):**
6. Diagnose the nix-check leg (fails in CI while the identical `--all-systems` eval passes on-host — runner-side fetch/sandbox suspect).
7. Pull runner boot logs for the 3 failing VM legs (sev1-escalation, btrbk-rescue, miniflux).
8. Fix go-deps-audit runner breakage (red all day; exact eval expression passes locally).
9. Fix secret-history-scan: convert the Slack-shape fixture literal inside `.gitleaks.toml` to a runtime-derived template, prove one green scan.
10. Fix negative-lint-tests: identify the failing leg from run 43497657810, fix or re-baseline with rationale.
11. Rebuild the cv input's go-modules vendorHash (the queued services.md row) and prove ONE full toplevel BUILD (not just eval).
12. Confirm the final-tip nix-check run (still in_progress at close) brought no NEW leg reds.

**Contacts-plan continuation:**
13. T5.4 in its decided shape: MKCOL-based per-account book provisioning for the pbx host (boot script or converger oneshot pattern), `nix flake check`, deploy at a quiescent window (needs #4).
14. T6 restore drill against the provisioned books; stamp the receipt into the ownership row.
15. T9 flip when #1 lands: `enable=true, live=false`, deploy, verify first dry-run journal + metrics file.
16. T13 flip when #2 lands: enable carddavProjection, verify the first one-shot, wire the textfile collector group + Gatus freshness.
17. T15: Twenty import dry-run against the real CSVs → owner review → live with cap above row count.
18. T16: the one-account outbound canary (field-scoped, capped, owner review per write).
19. Add the receipts verification line to the pim-sync flip ladder steps 2/3 (queued services.md row).
20. Wire the SigNoz staleness rule for `crm_projection_last_success_unix` (queued monitoring.md row).

**webphone (their train, queued in their tracker):**
21. Delete the dead sibling legacy readers (faxes/snippets/threads/transcripts) in one pass.
22. Design the §5 export-or-confirm tooling before any DROP window.
23. Watch main stays green as the parallel session's funnel work lands.
24. Run the FULL `nix flake check` in webphone (only targeted suites have ever run; templ freshness + module checks rode nothing).
25. Owner-eyes: freshness chip in the thread strip head (currently context-items only).
26. Parked: trunk-form vs `+`-prefixed forking — a region-default option if a real duplicate is ever observed.
27. If a future config key legitimately contains the substring "contacts", convert the T10 absence-gate test to key-set equality (seam comment already pins this).

**pim-sync:**
28. The art-dupl baseline decision: accept the 34-clone `report.*++` family (then `art-dupl baseline`) or extract a shared increment helper — the local verdict stands in `/var/tmp/pimsync-dupl.log`; reconcile against the remote gate once billing heals.
29. Calendar-leg receipt e2e against carddavtest (contacts is covered; the calendar receipt content is only unit-shaped).
30. Reconcile the gitleaks receipt over the doctor fixtures once billing heals (no local `.gitleaks.toml` exists — the remote gate is the only arbiter).
31. Delete the retired `crmpeople:extracted` KV key on the live DB (owner recipe, rehearse on a copy).

**Stack / nix-email / pbx:**
32. Ride the stack's next per-train webphone bump (contacts-absent fixtures already committed `93aa685`); run the stack's configjs VM test against the new pin BEFORE merging — closes the §b4 CI window.
33. Check whether stalwart-cli's own repo grows owned-addressbook apply support (feeds the §g2 decision; the CLI crate was absent from the server source).
34. Re-run the `carddav_probe.py` set (17/18) after any stalwart pin advance (nix-email TODO row, re-armed posture).
35. pbx: confirm the foreign `tests/gates-contract.nix` modification with the owning session before any pbx deploy (open since 19:25).
36. Verify the immich session's feature at their deploy (my repairs were attribute-path only; `apiKeys` is still `{}` so the converger is inert until they wire consumers).

**SystemNix housekeeping:**
37. Docs-health freshness + annotate pass over pim-sync/crm/paperless docs (queued services.md row).
38. InboxClean `go.work` regen check now that go-cqrs-lite ADR-0141 landed (`go work use -r ../go-cqrs-lite` keeps eventtest).
39. Add `crmpeople:signature-hashes` to the InboxClean backup-scope notes if the KV table is in the backup set (verify inclusion).
40. Promote the §21 drift check to blocker after its quarantine window (owner decision; queued watch row).
41. The push-race etiquette checks from 19:25 §f: signoz session's `42a11b4f5` report push state; the foreign `docs/status/tasks/2026-11-13_17-18` report registration (flag only, not mine).
42. SystemNix: confirm the daemon sweeps of this session's narrative commits (immich repairs etc.) are fully covered by the report addendum — they are, but a spot-check of `git log --stat` against the addendum's claims costs nothing.

**Smaller debt surfaced this session:**
43. InboxClean: add the spec sentence for `factsByCall`-style fake extension if more extraction tests need sequential answers.
44. Consider extending `check-contact-registry-drift.sh`'s banned-DAV-family grep to the stack fixtures (currently 7 SystemNix surfaces).
45. pim-sync: decide whether `run .#test` should ALSO gate art-dupl locally (the remote gate being billing-blind makes a local leg useful).
46. webphone: the dedup's `keepRunes` helper — confirm the parallel session's AGENTS gotcha notes (commit `b0f322ee`) cover the pending-verdict CI-triage pattern they wrote about.
47. Re-check the 20:01 push's three still-unknown workflow verdicts once nix-check finishes (secret-scan and negative-tests are known reds; the run-level conclusion is what matters for the record).
48. When the cv session lands their fix, re-run the full keep-going BUILD to confirm evo-x2 toplevel builds end-to-end (eval gates already green).
49. Sweep for any SystemNix daemon commits after `f52d352d9` carrying foreign work that needs flagging (the TODO_LIST/pipeline/storage.md dirty files at close were foreign — leave, flag in the next report if they persist).
50. When §g2 is decided, update BOTH the plan file's T5.3/T5.4 rows AND the doctrine gap #1 in one pass (they must not drift).

## g) Questions I cannot answer myself

1. **§g2, now evidence-complete**: do you want the AddressBook dialect finding FILED upstream at Stalwart (with the demo transcript; verify-before-filing rules will be applied before drafting), or do we accept MKCOL-only provisioning and I write the pbx-host boot-script/converger MKCOL path as T5.4? This single call unblocks the whole book-provisioning chain (T5.4 → T6 → T15).
2. **CI-red triage priority**: five all-day red workflows (go-deps-audit, secret-history-scan, negative-tests, the nix-check + VM-leg cluster) are queued, plus the Actions billing block on pim-sync. Do you want the next session spent on the CI cluster (runner-side diagnosis of nix-check is the interesting one — local-green/CI-red on the identical eval), or does the flip chain (which needs your pastes anyway) outrank it?
3. **The pbx tree question**: T5.4's deploy needs a quiescent pbx tree, and a foreign `tests/gates-contract.nix` modification is still unaccounted for (open since the 19:25 report). Is that modification yours or another session's landed-intent that I may build on — or should every pbx deploy wait for explicit clearance from the owning session?

---

*Execution honesty note: this session enabled no service, deployed nothing, and touched no production state. The only live-system writes were against the throwaway demo VM (provision re-apply of the same plan idempotently, then teardown). The three immich repairs were attribute-path fixes to a foreign commit that had broken the shared eval surface for every session; the feature itself was left untouched.*
