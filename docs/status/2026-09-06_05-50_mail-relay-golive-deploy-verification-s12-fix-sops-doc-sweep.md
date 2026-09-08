# Status: Mail-Relay Go-Live Deploy Verification, sops Doc Fixes, Smoke §12 Repair

- **Date:** 2026-09-06 05:50 CEST
- **Session scope:** continuation of the mail-relay collector-outage fix session (2026-09-06 03:39 report). This segment: user secret-entry guidance (with one self-inflicted failure), go-live deploy verification, live triage of the deploy's FAIL/WARN signals, §12 false-WARN fix, `sudo sops` doc landmine sweep.
- **End state of this segment:** mail relay go-live credentials are LIVE and verified on evo-x2; the smoke's credential check is fixed and live-verified; 6 broken doc commands fixed; 3 user actions remain (Resend domain verify, InboxClean re-auth, Wise SCA approval).

---

## Deployment facts (verified, not assumed)

| Signal                              | Value                                                                                                                      | Source                          |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `mail_relay_credential_placeholder` | **0** (real Resend key rendered + live)                                                                                    | collector textfile, post-deploy |
| Postfix queue                       | **0** messages                                                                                                             | collector textfile              |
| `mail-relay-metrics` collector      | **WRITING** (first green since 2026-09-02; the 4-day outage is over)                                                       | post-deploy smoke PASS          |
| §12 credential check                | **PASS** "real upstream credential rendered (collector verdict)" — fix live-verified                                       | standalone smoke run 05:39      |
| pocket-id.yaml (new Resend key)     | committed `467983e8`                                                                                                       | git log                         |
| §12 script fix                      | committed `1e171324`                                                                                                       | git log                         |
| mail-relay.yaml key save            | lastmodified 2026-09-06T02:35:45Z (user edit), daemon-committed `04e5118b`                                                 | sops metadata + git             |
| Bank-sync DNS failures 03:42/04:12  | transient name-resolution outage; **recovered 05:28** ("sync completed successfully")                                      | journal                         |
| Wise SCA challenge                  | **NEW challenge live** — statements degraded, OTT `30a5f530-…` issued in journal                                           | journal 05:28                   |
| CV `/export/pdf` FAIL at 05:39      | **I/O casualty** (`sqlite … context deadline exceeded`), not typst/assets; deploy-time PASS proved the render path         | journal 05:47                   |
| I/O saturation (avg10 83%)          | post-deploy background wave: activitywatch-data-to-pool + buildcache-gc, both **completed 05:45**                          | journal + /proc/pressure/io     |
| freshclam                           | self-recovered 05:00                                                                                                       | journal                         |
| service-health-check                | aggregator only: inboxclean-sync (auth) + stale `aw-watcher-window-wayland` user-unit state (no journal entries this boot) | journal                         |

---

## a) FULLY DONE

1. **§12 false-WARN fixed and live-verified.** The smoke ran as the user but read a `0400 postfix` file under the `0700` root sops dir — a permanent false "SASL map missing" WARN. Replaced with the collector textfile verdict (`mail_relay_credential_placeholder` + `scrape_errors`, fail-closed). Verified on the live system: PASS. Commit `1e171324`.
2. **Mail relay go-live state machine is GREEN end-to-end on the host:** real key rendered, template rendered, postfix active, banner 220, queue 0, collector writing, Gatus check unblocked.
3. **User's secret entry succeeded** after corrected instructions: both Resend keys pasted (mail-relay 02:35, pocket-id 02:37), both sops saves verified via `lastmodified`, both deployed with the 04:40 switch (system-766 → 767).
4. **pocket-id.yaml committed** (`467983e8`) — HEAD no longer carries the dead June key.
5. **Bank-sync deploy FAIL correctly diagnosed as transient DNS** (not Wise auth, not SCA, not 422) — confirmed by its 05:28 recovery without intervention.
6. **6× `sudo sops` doc landmines fixed** (live-failure-derived): AGENTS.md lines 43 (CV), 178 (papersync), 179 (decrypt), 323 (mail relay) + docs/services/mail-relay.md runbook step 3 and troubleshooting. All now carry the `SOPS_AGE_KEY=$(sudo cat … | ssh-to-age -private-key) sops …` user-context one-liner with the "plain `sudo sops` FAILS" note.
7. **AGENTS.md §12 description updated** (line 326) with the why (root-only rendered map) and the stale `paperless.conf` wording corrected to the unit-file grep.
8. **Verification discipline held:** `bash -n` on the edited script, `audit-textfile-tmp.sh` re-run clean (189 files), no flake.lock churn, parallel-session mid-air collisions handled by re-read+retry without damage.

## b) PARTIALLY DONE

1. **Mail relay end-to-end delivery is still UNPROVEN.** Key is live, but zero real sends have occurred since (queue was already empty — nothing to flush; `postqueue -f` is moot). Blocks on: Resend domain verification + one real test send.
2. **InboxClean:** sync still red. Main account `auth_expired`; the work account token (issued Aug 29 under Testing) has passed its 7-day bomb too. Re-auth of BOTH required, in the right order (consent screen to "In production" FIRST).
3. **Bank-sync:** syncs work again, but **statements are DEGRADED** on a fresh Wise SCA challenge (balance-only via transfers fallback). Human approval step pending.
4. **Docs:** all edits applied; the AGENTS.md changes are staged/awaiting the auto-daemon commit (mail-relay.md + post-deploy-check.sh already committed).
5. **Gatus textfile freshness** (frozen-file phantom-green class): identified across two sessions, still not implemented anywhere.
6. **Textfile collector class sweep:** converted repo-wide last session, but the two allowlisted safety-critical units (memory-emergency-guard, sev1-escalation) remain on cosmetic-only exemption — revisit-on-touch stance unchanged.

## c) NOT STARTED

1. **AGENTS.md gotchas from the prior session's VM-test lessons:** `fs.protected_regular=2` blocking even root's O_TRUNC of foreign-owned files in sticky dirs, and `AmbientCapabilities` (not BoundingSet) being what GRANTS caps to non-root `User=` units. Grep confirms 0 mentions — never landed.
2. **Gatus textfile freshness conditions** for all collectors (mtime-based, fail-closed) — the frozen-prom phantom-green class.
3. **§12 staleness assertion** on `mail-relay.prom` mtime (the new credential-verdict source should refuse stale input).
4. **Bank-sync smoke-check semantics:** `bank_sync_sync_errors_total` is cumulative since process start — the check FAILs forever after ANY historical failure until a unit restart (proven tonight: syncs succeed since 05:28, check still FAIL). Needs a windowed delta or last-cycle-success signal.
5. **`tests/test-oauth2-proxy.nix`** is unregistered in `tests/default.nix` (dead file) — register or trash.
6. **The 50-task backlog** from the prior report (`docs/status/2026-09-06_03-39_…`) — untouched, still valid; see (f) for the carried-forward subset.
7. **User-action secrets not yet set:** Hermes fine-grained PAT (placeholder), InboxClean decrypt password (placeholder, inert by design).
8. **The owed reboot** (D-state corpse pile, wedged amdxdna/llama state, flm :52626 zombie socket, zram-50% sizing activation) — user decision, unchanged.

## d) TOTALLY FUCKED UP

1. **I handed the user a command that failed at their terminal.** First answer: `sudo sops platforms/nixos/secrets/mail-relay.yaml` → "failed to load age identities" (root carries no age identity). The repo's own skill doc — which I had VIEWED **in the same turn** — shows the correct `SOPS_AGE_KEY` one-liner at line 29, and its mistakes table literally warns about sudo stripping the env. Root cause: AGENTS.md itself contains `sudo sops` in ≥4 sections; two repo docs disagreed, and I pattern-matched the wrong one without verifying. The verify-external-claims doctrine (verify before encoding into instructions) was violated for the single most-used operational command in this repo. Cost: one failed user round-trip, and the broken pattern stayed in docs until today.
2. **§12 shipped a check that could never pass.** The credential check read a root-only file from a user-run script (`deploy.sh:441` runs `nix run .#post-deploy-check` with no elevation). Every deploy since the mail-relay feature landed would emit the false WARN. Root cause: never asked "what user executes the smoke?" — same doctrine family as the paperless.conf phantom-grep ("probe the surface the config actually lands on"). Fixed only because the user pasted the full deploy output.
3. **The repo's docs have been teaching the broken command for months** (AGENTS.md CV/papersync/mail-relay sections, mail-relay runbook). The go-live runbook the user followed was wrong at step 3 of 4. That is exactly how the 4-day collector outage class reproduces: the runbook says X, reality does Y, nobody re-verifies.
4. Minor: my first two AGENTS.md edit attempts hit mid-air collisions with the parallel wifi-failover session (file modified between read and edit). Handled correctly — re-read, retry, zero damage — but two wasted round-trips; I should have expected contention on AGENTS.md given the known concurrent-session pattern.

## e) WHAT WE SHOULD IMPROVE

1. **Verify every operational command before giving it to the user** — especially when repo docs disagree. The correct pattern was one screen away in the skill I had just loaded.
2. **Smoke checks must declare their assumed privilege context.** Add a header note in post-deploy-check.sh ("runs as unprivileged user; never assert on root-only paths") and prefer `[ -f ]` + readable-surface probes; where a permission denial is possible, distinguish missing from unreadable instead of conflating both into "missing".
3. **Operational command patterns need ONE canonical home** (the sops skill doc) and every other mention should reference it instead of restating — restatement is how the 6 landmines diverged. A doc-lint that greps for `sudo sops` outside the canonical pattern would have caught this class.
4. **Cumulative-counter smoke checks need windowed semantics** (bank-sync class): a check that can only un-FAIL via a unit restart is a false alarm generator.
5. **Post-deploy background jobs should respect I/O pressure** — deploy.sh fired activitywatch-data-to-pool + buildcache-gc + data-to-pool concurrently; IO PSI avg300 hit 81% and took out CV's SQLite deadlines (deploy-time smoke PASSed only because it ran before saturation peaked). Reuse the scrub-guard pattern (skip/defer on IO PSI) for deploy.sh's post-switch section.
6. **Re-verify deploy-time PASSes that touch slow paths** (CV export) — the 04:40 PASS and the 05:39 FAIL are both real; time-of-check under an I/O wave is not a stable signal.
7. **fish startup regression (460ms → 758ms)** — likely I/O-linked; re-measure post-reboot before chasing it.

## f) NEXT TASKS (prioritized)

**P0 — user actions blocking go-lives (this week):**

1. Approve the Wise SCA challenge in the Wise app; drop the OTT into `/var/lib/bank-sync-sca/token.env` (runbook `docs/services/bank-sync-sca.md`), restart bank-sync, then remove the file.
2. Verify `larsartmann.cloud` in Resend (Domains → SPF/DKIM → "Verified"), then one real send: `printf 'Subject: relay test\n\nok\n' | sudo sendmail -f noreply@larsartmann.cloud <your mailbox>`; confirm arrival + postfix journal.
3. InboxClean: flip the Google OAuth consent screen to "In production" FIRST, then re-auth BOTH accounts via the AGENTS.md runbook (work account needs the `INBOXCLEAN_CONFIG` env), verify `/health` both connected, re-enable `services.inboxclean.sync`.
4. Schedule the owed reboot (quiet window): clears the D-state corpse pile, flm's :52626 zombie socket, wedged driver state, and activates zram-50% sizing.
5. Confirm the daemon committed the AGENTS.md sops-fix edits (git status).

**P1 — this session's class, small and high-value:**
6. AGENTS.md gotchas: `fs.protected_regular=2` + `AmbientCapabilities` (write both, with the VM-test provenance).
7. Gatus textfile freshness conditions for all collectors (frozen-file phantom green).
8. §12: add mtime staleness assertion on the collector textfile it now trusts.
9. Bank-sync smoke check: replace cumulative-counter FAIL with windowed/last-cycle semantics.
10. Doc-lint: reject `sudo sops` occurrences outside the canonical SOPS_AGE_KEY pattern (pre-commit grep, same shape as audit-textfile-tmp.sh).
11. Re-verify CV `/export/pdf` PASS after the I/O wave drained (should self-heal; if not, journal dig).
12. Deploy.sh: gate/stagger post-switch background jobs on I/O PSI (scrub-guard pattern).
13. `tests/test-oauth2-proxy.nix`: register in tests/default.nix or trash.
14. Post-deploy smoke: distinguish missing vs unreadable on all file-path assertions; state the privilege context at the top of the script.
15. Update the mail-relay runbook with the observed go-live evidence (queue was pre-drained; `postqueue -f` unnecessary) to prevent cargo-cult steps.
16. Re-measure fish startup after reboot; investigate only if still >200ms.
17. Record the SCA recurrence observation (challenge ~18d after the last, vs the ~90d assumption) in the bank-sync runbook if confirmed real (verify token issue dates).

**P2 — carried forward from the 03:39 report (still open, unchanged):**
18. Convert memory-emergency-guard + sev1-escalation to the mktemp pattern on next touch (cosmetic; allowlisted).
19. Hermes fine-grained PAT (user action, sops `hermes-github-token.yaml`).
20. InboxClean bank-PDF decrypt password go-live (user action, sops `inboxclean-decrypt.yaml`).
21. CV `pipeline.evaluation.min_day_rate` owner decision (unset).
22. Signoz-coverage flips: dnsblockd `WithInsecure()` fix push + tag + flake bump; bank-sync OTLP support same pipeline.
23. Drop-day sweep: go-dev tarball overrides in browser-history, papdashboard, crush-daily, PMA (nixpkgs now ships 1.26.7).
24. Monitor365 re-enable decision (vendored private crate — publish/publicize/vendor).
25. Post-reboot verification battery: corpse pile gone, :52626 bindable, llama-embeddings cold load <1min, zram sized ~62 GiB, D-state metric 0.
26. TODO_LIST.md sync — it was modified by a parallel session; reconcile my backlog entries with theirs before double-tracking.
27. Wifi-failover (parallel session's new module, deployed tonight): review + functional test of an actual failover — it shipped unverified by me.
28. Aw-watcher-window-wayland stale failed user-unit state: clears on next login; verify it does, else add to service-health-check's known-transient list.
29-45. Remaining items from the 03:39 report's list of 50 (§12-adjacent monitoring hardening, VM-test coverage for converted collectors, Gatus freshness, upstream filings) — unchanged, refer to that report rather than duplicating.

## g) QUESTIONS (cannot answer myself)

1. **Was the 03:42–04:12 DNS outage tonight a known network event** (modem/ISP flap, router reboot, failover switchover)? And is the wifi-failover module that deployed tonight its intended fix — should I functionally verify it, or is it experimental and off-limits for now?
2. **Resend key strategy + domain status:** the same new key now sits in both `mail-relay.yaml` and `pocket-id.yaml` — keep it shared, or issue dedicated keys per consumer? And is `larsartmann.cloud` verification done, in progress, or not started on your Resend dashboard?
3. **InboxClean consent screen:** is the Google OAuth consent screen already switched to "In production"? (Order matters — flip first, then re-auth both accounts — and I cannot see your Cloud Console.) If yes, should I re-enable `services.inboxclean.sync` in the same change?

---

**Waiting for instructions.** No further action taken beyond this report.
