# P2 Registry Migration COMPLETE — batch 3 + full-surface verification (2026-09-15 09:50)

> **[docs-health 2026-09-19] RESOLVED + ARCHIVED:** migration deployed 2026-09-16 20:57 (gen bbb931a8); the caught paperless vHost-override regression is fixed (vHost.layer=none rule in AGENTS.md).


**Task:** finish the P2 service-integration-registry migration (batch 3 of 3) and verify every
migrated surface against a true pre-migration baseline.
**Tree:** SystemNix, branch master. ~~All work uncommitted at write time~~ committed and deployed 2026-09-16 20:57 (gen bbb931a8).

---

## a) FULLY DONE

### Batch-3 registry entries (13 entries in 12 files)

| Module                                                                | Entry                                                           | Surfaces carried                                                                                                                |
| --------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `twenty.nix`                                                          | `twenty`                                                        | vHost crm (protected), Gatus check, tile, backup (31h)                                                                          |
| `manifest.nix`                                                        | `manifest`                                                      | vHost manifest (protected), Gatus check, tile, backup (31h)                                                                     |
| `google-sync.nix`                                                     | `google-sync`                                                   | tile only (no href; module-level backup row kept — no dup)                                                                      |
| `wifi-failover.nix`                                                   | `wifi-failover`                                                 | monitored only                                                                                                                  |
| `forgejo.nix`                                                         | `forgejo`                                                       | vHost (plain), 2 Gatus checks (Forgejo + Mirror Sync), backup (*.zip, 25h), monitored, OIDC client                              |
| `dns-blocker.nix`                                                     | `dnsblockd`                                                     | monitored + OIDC client (vHosts stay hand-written redirect pair)                                                                |
| `overview.nix`                                                        | `overview`                                                      | vHost (protected), Gatus check, tile                                                                                            |
| `crush-daily.nix`                                                     | `crush-daily`                                                   | vHost daily (protected), Gatus check, tile                                                                                      |
| `fastflowlm.nix`                                                      | `fastflowlm`                                                    | tile + monitored (no href — API-only endpoint)                                                                                  |
| `hermes.nix`                                                          | `hermes`                                                        | tile (Infrastructure) + monitored                                                                                               |
| `paperless.nix`                                                       | `paperless` + 6 unit entries                                    | backup (25h), OIDC client (pkce, allauth callback); paperless-{consumer,scheduler,task-queue,web,tika,gotenberg} monitored-only |
| `gatus-config.nix`                                                    | `gatus`                                                         | vHost status (plain), monitored, OIDC client, tile; self-check stays in core                                                    |
| `homepage.nix` / `networking.nix` / `system-health.nix` / `caddy.nix` | `homepage-dashboard`, `nix-daemon`, `lan-nic-watchdog`, `caddy` | monitored-only self-registrations                                                                                               |

Also: `dozzle.nix` entry extended with its Gatus check; `monitor365.nix` monitor365-server entry
extended with the OIDC client field.

### God-file removals (all verified)

- **pocket-id.nix default OIDC list → `[oauth2-proxy]` only** (cv+immich removed first as dupes, then forgejo/gatus/monitor365/dnsblockd/paperless as their entries landed).
- **configuration.nix `backup-coordination.backups` → empty** (all 9 rows module-owned).
- **system-health default `monitoredServices` → `[monitor365, monitor365-server]`** (31-unit union unchanged, from entries).
- **homepage.nix → 8 flags + 8 tiles removed** (twenty/manifest/crushDaily/gatus/hermes/overview/fastflowlm/googleSync) + dead `signozEnabled`/`dozzleEnabled`/`hasContainer` bindings; `searxEnabled` kept by design (bookmark/widget gate).
- **caddy.nix → 7 vHosts removed** (immich/forgejo/crm/manifest/status/daily/overview); justified hand-written vHosts commented.
- **gatus-config.nix → 7 service checks removed from core** (Twenty CRM, Manifest, Forgejo, Forgejo Mirror Sync, Crush Daily, Dozzle, Overview).

### Verification (against a PRE-MIGRATION GIT WORKTREE baseline, `a6b4b2ff`)

- **Caddy vHosts: BYTE-IDENTICAL** (31 vHosts, zero content diffs) — after catching a regression, see (d).
- **Gatus settings non-endpoints: IDENTICAL; endpoints set-equal** — the 162→165 drift is exclusively
  the parallel session's committed niri/BTRFS-scrub-split/Memory-Guard-Fresh/CV-Auto-Apply check changes,
  none of them mine (proven by name).
- **backup-coordination backups: IDENTICAL.**
- **Monitored union 31=31, set-identical, ZERO duplicates.**
- **OIDC union: identical** except two explained deltas: (1) `monitor365` client left the desired
  provision set (deliberate: enable-gated entry + disabled service; the provisioner does NOT prune —
  the Pocket ID row stays as a harmless orphan and auto-resumes on re-enable); (2) `immich` "diff" was
  baseline store-path noise (old-lock `logoFile` source hash), not a real change.
- **Homepage tiles: per-group sets set-identical AND tab order preserved** (8 canonical groups).
- **All 19 integration-relevant flake checks eval clean** (attic, browser-history, cv, hermes,
  mail-relay, paperless, searxng, tq-agent-pool, miniflux, integration-registry, bank-sync-paperless,
  inboxclean-paperless, gatus-patterns, gatus-pattern-lint, module-shape-lint, port-registry-audit,
  systemd-shape-audit, mount-gating-audit, deploy-restart-audit). Repo-wide `nix flake check` still
  blocked by the parallel session's broken `tests/test-hot-db.nix` (NOT mine).
- **`nix fmt --no-update-lock-file -- --ci`: 0 changed.**
- test-cv needs NO pocket-id mock: it imports only cv+integration; the `options ? services.pocket-id-config`
  guard skips the OIDC fan-out (the midflight report's known-issue #2 is moot).

### Docs

- `TODO_LIST.md` P2 checklist: all 5 items stamped DONE with evidence + the two new coupling rules.
- `AGENTS.md`: step 9 rewritten to registry-owned checks (pat() doctrine preserved verbatim); 3 new
  gotchas added (vHost override trap, monitored-duplicate trap, worktree-baseline method).

## b) PARTIALLY DONE

- **Nothing in the P2 scope.** The only partial: repo-wide `nix flake check` cannot run green until the
  parallel session fixes `tests/test-hot-db.nix` (`nodes.machine.entryPath` breakage at HEAD) — all
  verification therefore used per-check evals, which is adequate but not the full gate.

## c) NOT STARTED

- Deploy (`nix run .#deploy`) — this session's work is tree-only; the machine still runs the pre-migration
  generation. Post-deploy the provisioner converges OIDC clients; no service restarts are required by
  this migration (rendered surfaces are identical).
- The Immich Gatus check (`/api/system-config`, 401) and Homepage check remain in gatus-config's core
  list — deliberately left (infra/meta classification per plan), noted here so the choice is visible.

## d) TOTALLY FUCKED UP (caught + fixed, recorded for the lesson)

1. **Registry vHost override deleted paperless's `/admin/*` 403 hard-block** — my paperless entry used
   `vHost.layer = "plain"`, so the registry rendered a `paperless.home.lan` vHost that silently REPLACED
   the hand-written one (attrset merge order), deleting the admin hard-block AND the handle structure.
   Eval green, vHost count unchanged — only the byte-level baseline diff caught it. Fixed: entry now
   `layer = "none"` with an explanatory comment; caddy re-verified byte-identical. **Lesson: "evals
   green" is not "surfaces preserved"; custom-block vHosts MUST be `layer = "none"` in entries.**
2. **Live duplicate in the monitored union mid-migration** — pocket-id's entry (`monitored = true`,
   earlier batch) + the default-list `pocket-id` row = duplicate metric series = whole-textfile
   Prometheus rejection class. Caught by audit before deploy; fixed by removing the default row.
3. **Two entry-script failures before the working run** (stale assert on files whose comments mention
   `services.integration`; an indentation-doubling bug in my own first script) — fixed by asserting on
   `services.integration = lib.optionalAttrs` instead of the bare string and rewriting bodies at final
   indentation.
4. **multiedit injected a literal `\n` into caddy.nix module args** (JSON-escaped newline in my edit
   string) — first eval after caught it (`syntax error, unexpected invalid token`); fixed by re-edit.

## e) WHAT WE SHOULD IMPROVE

- **The registry fan-out has no eval-time collision guard for hand-written vHosts**: caddy should
  ASSERT that a registry vHost subdomain does not collide with a hand-written `virtualHosts` key
  (the paperless trap was pure luck to catch). Candidate: extend caddy-config with a
  `handWrittenSubdomains` list + `builtins.intersectAttrs` assertion.
- **No eval-time duplicate guard on `monitoredServices ++ extraMonitoredServices`** — a one-line
  assertion (`lib.unique` length check) would have made the pocket-id dup fail `nix flake check`
  instead of relying on my audit.
- **The baselines-in-/tmp workflow is fragile** (tmp cleaner ate them mid-session; I had to reconstruct
  via worktree). The worktree method is strictly better — consider persisting it as a tiny script
  (`scripts/verify-surface-parity.sh <pre-commit>`) next time a large refactor looms.
- **Homepage tab-order preservation relies on the always-emit+filter restructure** — works, but a
  negative test (`tests/test-integration.nix` extension) asserting tab order for registry-only groups
  would lock it in.
- The monitor365 enable-gating consequence deserves an explicit decision record (orphan client is
  benign, but "disabled service loses SSO client provisioning" is a semantic worth an AGENTS.md line
  on the monitor365 section — TODO f.10).

## f) NEXT (up to 50, highest-impact first)

1. **Deploy** the migration (`nix run .#deploy`) — rendered surfaces identical, so it should be a
   no-op generation; run pre-deploy gate as usual.
2. **Fix `tests/test-hot-db.nix`** (parallel session owns it — coordinate) to unblock repo-wide
   `nix flake check`.
3. **Add the caddy hand-written/registry vHost collision assertion** (see e.1).
4. **Add the monitored-duplicate assertion** in system-health (see e.2).
5. **Decide + document the monitor365 orphan-client semantics** (accept orphan / add prune list /
   add a keep-disabled-provision allowlist).
6. Persist the worktree-baseline verification as `scripts/verify-surface-parity.sh`.
7. Migrate the Immich check into `immich.nix`'s entry (401-on `/api/system-config` is service-specific;
   I left it per plan scope — cheap follow-up).
8. Homepage tab-order negative test in `tests/test-integration.nix`.
9. Sweep the 19 checks as BUILD (not just eval) once hot-db is fixed — eval green ≠ build green for VM tests.
10. Fold the two new coupling rules into `docs/CONTRIBUTING.md`'s registry checklist (AGENTS.md has them; CONTRIBUTING is the contributor-facing copy).
11. Consider a `services.integration.<name>.vHost.extraConfig` seam for the "custom block" class (paperless /admin, seo GSC) so those last hand-written vHosts can also move — then re-evaluate which vHosts remain.
12. Post-deploy: verify Pocket ID provisioner journal shows exactly the expected client set (oauth2-proxy + 9 module-owned; monitor365 absent).
13. Post-deploy: confirm gatus endpoint count and names via the API (the 3 parallel-session checks + all migrated ones).
14. Grep the repo for any remaining `*Enabled = config.services.` homepage-flag patterns to confirm zero stragglers.
15. Confirm `dns-local.nix` needs no new entries (it doesn't — all batch-3 subdomains pre-existed).
16. Consider extracting the monitored-only entry boilerplate (`vHost.layer = "none"; monitored = true;`) into a registry-level default or helper — 7 entries are exactly that shape.
17. Same for the 6 paperless unit entries — they could be generated from a list.
18. Review `backup-coordination`'s now-empty `backups` attrset: with all rows module-owned, the option in configuration.nix is documentation-only — fine, but note it.
19. Re-run `nix eval` of `provision.extraOidcClients` on a MINIMAL host (test-integration pattern) to assert the union shape as a regression test.
20. Audit whether any OTHER `//`-merged fan-out remains anywhere (grep `optionalAttrs (options ? services.integration)` for shapes that deviate from the mkIf+optionalAttrs guard).
21. Sweep for checks still referencing `config.services.<x>.port` in gatus-config (any that should have moved but were missed) — TaskChampion is known-remaining (sync-server has no registry entry at all).
22. TaskChampion/taskchampion-sync-server: decide whether it gets a registry entry (TCP check, tile, vHost are all still god-file rows).
23. openseo: same decision (vHost stays hand-written for the GSC exemption until an extraConfig seam exists — see f.11).
24. oauth2-proxy: it has no registry entry (no owning service module in this repo shape?) — document why the last default-list OIDC client is legitimate.
25. Verify the three `enable = cfg.lanInterface != ""`-style conditional entries behave right on hosts where the gate is false (rpi3 evals) — quick extendModules probe.
26. Confirm rpi3-dns host still evals (it imports dns-local + some modules; the registry assertion runs there too).
27. Add `tests/test-integration.nix` coverage for a `unit =`-override entry (mail-relay/postfix pattern) to lock the monitored fan-out naming.
28. Re-check pre-deploy-check §10 metric loans: `BANKSYNC_METRICS`/`MONITOR365_METRICS` etc. still correct post-migration (monitor365 remains disabled).
29. Update the midflight status report (`2026-09-15_06-51`) with a "SUPERSEDED — see 09-50 report" header.
30. Grep AGENTS.md for stale claims of "rows in caddy.nix/gatus-config.nix/..." for migrated services (step 6 already says the registry owns them; spot-check service sections).
31. Consider signing the entry-insertion script into `scripts/` if more services ever need bulk entries (probably not — migration is complete).
32. Delete the `/tmp/pre-mig` worktree when confident (it holds a full checkout; `git worktree remove`).
33. Confirm no sops key-audit regressions: none of the entries added sops keys (checked — all secret wiring pre-existing).
34. Run `nix flake check --no-build` the moment hot-db is fixed and archive the green run in the next status report.
35. SigNoz dashboards: no changes needed (registry migration doesn't touch dashboards) — verify no provisioner diff appears on next deploy anyway.
36. Check whether `services.caddy-config.extraVHosts` ordering (mapAttrs over entries) can ever reorder vHost declaration order in rendered Caddyfile (Caddy is order-insensitive for distinct hosts — note it).
37. Homepage: verify the `Review Tools` empty group still filters out correctly (all its tiles are module-owned).
38. Gatus: confirm `withPapIngest` still maps over registry endpoints (the fan-out appends inside the PapDashboard pass — batch-1 design; re-verify after batch-3 additions).
39. Post-deploy: Discord alerting smoke for one migrated check (resolve/trigger path unchanged in theory).
40. Documentation: add the monitor365 case to the AGENTS.md SSO section as the canonical "OIDC client enable-gating" example (part of f.5).
41. Battery: grep for `homepage = null`-style entries that could now claim tiles (none exist — audit was clean).
42. Consider deleting the now-unused `hasContainer` helper if it reappears unused after the parallel session's homepage edits (it was removed this session; verify it stays gone).
43. `tests/test-caddy-auth.nix`: confirm it still passes with the new caddy self-entry (it evals the caddy module).
44. Evaluates `configs` for hosts other than evo-x2 (rpi3-dns) with the new networking.nix `options ?` guard — verify no eval surprise on hosts importing networking.nix without integration.nix (rpi3 doesn't import networking.nix — confirm).
45. Mail-relay entry uses `unit = "postfix"` — add one eval assertion that `unitOf` overrides actually land in extraMonitoredServices as "postfix" (test-integration may already; verify).
46. Time-box a review of the parallel session's signoz.nix restructure for interaction with the registry fan-out (signoz entries exist in both worlds).
47. Gatus `alerts = discordAlert` vs registry `alert = "..."`: verify the auto-generated alert path (alert=null) is exercised by at least one entry (Immich check historically had NO alerts — if it migrates per f.7, it becomes the auto-alert case: deliberate choice needed).
48. Consider an integration-registry lint that every entry with `checks` has `port` OR all checks carry `url` (the assertion exists: `checkWithoutPort` — verify it covers the url-only case).
49. Extend `docs/CONTRIBUTING.md` "Adding a Service" to point at the registry entry as step 1 (currently AGENTS.md-centric).
50. After the owed reboot + crush-hot-db deploy, re-run the full check battery as the final P2 sign-off and archive the transcript.

## g) QUESTIONS FOR THE OWNER (not answerable from the repo)

1. **Monitor365 orphan OIDC client**: acceptable to leave the client provisioned-but-unreferenced in
   Pocket ID while monitor365 is disabled (current behavior, auto-resumes on re-enable), or do you want
   a `disabledClientAllowlist`/prune so Pocket ID's client list mirrors the desired set exactly?
2. **Deploy timing**: the migration is render-identical; deploy immediately, or hold for the
   /nix-soak window (~2026-09-17) already gating the crush-hot-db work so the machine takes one
   generation instead of two?
3. **Scope of "service-specific"**: Immich (`/api/system-config` 401 probe), Homepage, and
   TaskChampion checks remain in gatus-config's core list under the infra/meta classification.
   Confirm that's the intended final state (option B: everything service-named moves, leaving core
   with only true infra/meta checks).

---

_Verification transcript: all evals this session ran against `git+file:///home/lars/projects/SystemNix`
(current tree) and `git+file:///tmp/pre-mig` (worktree at `a6b4b2ff`, the commit before integration.nix
landed). Baseline JSONs: `/tmp/base-*.json`; current dumps: `/tmp/now-*.json`. 19/19 check evals OK;
fmt 0-changed. Uncommitted at write time — per-pathspec commits follow this report._
