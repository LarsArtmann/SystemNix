# DNSBLOCKD Max-Adoption — Session-Resume Verification (W1–W4 confirmed, M10 not yet touched)

**Date:** 2026-09-30 13:34 · **Session scope:** resume of the interrupted execution of
`docs/planning/2026-09-30_12-13_DNSBLOCKD-MAX-ADOPTION.md` · **Report basis:** THIS
session's run only (todo-list correction + repo-state verification), plus what the
verification surfaced. The prior session's work is re-verified, not re-executed.

**Nothing is deployed.** dnsblockd still runs v0.9.2-32 (`dnsblockd-75b4ce9`) with the
OLD config (`p6s93ln6…-dnsblockd-config.yaml`). The allowlist data-loss window stays
open in prod until the user runs the M11 deploy window. M11/M22 remain user-owned.

---

## a) FULLY DONE (this session)

1. **Todo list corrected to true state.** The stale list (M04–M09 "pending") is fixed:
   M01–M09 completed, M10 in_progress, M12–M21 + close-out pending, M11/M22 marked
   user windows. Tracking now matches reality.
2. **Repo-state verification (all green):**
   - HEAD `37a06935` (daemon commit, `docs/todo/storage.md` only), **tree clean**.
   - M01 `485a4166`, M02 `d9556da2`, M03 `8165f8c1` confirmed ancestors of HEAD.
   - **M05 lock bump CONTENT live:** `flake.lock` dnsblockd rev = `f625cfee…` (see §d —
     the original commit SHA is dead; content verified via `git log -S`).
   - **M06+M07+M08 CONTENT live** in amended commit `b38dabbc`
     ("feat(dns-blocker): csrf protection + device/user registry").
   - M09 memo (`docs/services/dnsblockd-tracking-dial.md`) and the prior status report
     (`docs/status/2026-09-30_13-07_…W1-W4-EXECUTED.md`) exist on disk.
   - Spot-verified the shipped source keys: wrapper renders `allowlist_path`
     (dns-blocker.nix:274) and `csrf_enabled = true` (:295); host config carries
     `dnsRateLimitPerSec = 50` (dns-blocker-config.nix:64), the 5-device inventory
     incl. `lg-tv` (:98), and `users = [ { name = "Lars"; … } ]` (:104).

Net: **W1–W4 remain fully landed and verifiable at current HEAD.** The resume point
(M10) is exactly where the prior session left it.

## b) PARTIALLY DONE

- **M10 (post-deploy smoke additions):** research complete from the prior session,
  including the probe-design flaw — a grep-for-`name="csrf_token"` on the block page
  **phantom-greens** (pre-validated against the RUNNING v0.9.2 with csrf off: the block
  page already emits 2 csrf_token fields). Redesign decided: (a) config-key greps on
  the DEPLOYED YAML (extract its store path from
  `systemctl show -p ExecStart --value dnsblockd`), (b) discriminating POST-without-token
  → expect 403. **Zero edits to `scripts/post-deploy-check.sh` yet** — this session was
  interrupted before the first M10 edit.

## c) NOT STARTED (this session)

- M10 script edits + `bash -n` + pathspec commit
- Standalone lint/format verification pass on the touched .nix files (daemon-amend
  lint-bypass doctrine)
- M12 docs sweep (stale recursion comment `dns-blocker-config.nix:14-17`, blocklist
  count 25→23 header claim, AGENTS.md dnsblockd section, runbook pointer to the memo)
- M13 TODO queue/library annotations (in-tree-but-undeployed state)
- W7: M14 policies option + shadow-mode probe doc; M15 trial URLs + persistent cache
  dir + StateDirectory/ReadWritePaths audit; M16 ECS options (inert defaults); M17
  `tls_h3_enabled` option (inert default)
- W8: M18 migration design + surface-preservation baseline; M19 impl A (consume
  upstream module); M20 impl B (re-add SystemNix overlays); M21 verification
- M11 prep: toplevel pre-build for warm cache; dnsblockd config-validate/dry-run CLI
  check
- Final close-out report
- **M11 / M22: user windows — correctly untouched.**

## d) TOTALLY FUCKED UP

Nothing destructive this session. Two latent problems the verification surfaced:

1. **Two of the five "my commits" from the prior session are DEAD SHAs.** `accb0522`
   (M05 lock bump) and `40eeac48` (M06–M08) no longer exist in history. The lock bump
   was absorbed by the auto-commit daemon into `b9310217` ("chore: auto-commit 1
   changed file(s) (heuristic)") — the FOD-green-first narrative and attribution now
   ride a heuristic message; `40eeac48` was amended into `b38dabbc`. Consequence: the
   13-07 status report and my session summary cite SHAs that `git show` cannot resolve.
   Content is safe; the audit trail is partially degraded.
2. **I initially trusted the summary's commit list.** The first verification pass would
   have reported "M05 landed as accb0522" — only the
   `git merge-base --is-ancestor` loop + `git log -S f625cfee -- flake.lock` exposed
   the absorption. Caught before anything was written, but it cost an extra roundtrip
   and is exactly the class the multi-agent write discipline warns about.

Carried from the prior session (documented there, still true): csrf field-grep probe
flaw (caught pre-write — good), mapping-derivation mixup (newest-by-mtime vs the
deployed config's own reference), `rg -r` replace-flag mistake, listOf-concat
extendModules bug (fixed with `mkForce`).

## e) WHAT WE SHOULD IMPROVE

1. **Cite content, not SHAs, in surviving docs.** "flake.lock dnsblockd rev f625cfee"
   survives daemon rewrites; "commit accb0522" does not. Any doc that must cite a
   commit should verify SHA liveness (`git merge-base --is-ancestor <sha> HEAD`) at
   authoring time.
2. **Amend within the daemon window, before writing docs that reference the commit.**
   If the daemon wins the race, immediately update the references to content-based
   ones (this report's §a does that).
3. **Keep the session-start verification trio as standard procedure:**
   `merge-base --is-ancestor` per claimed commit, `git log -S` for critical content,
   `git show --stat` on daemon commits that may have absorbed my work. Cheap, and it
   caught both §d items in minutes.
4. **Probe-before-write stays mandatory for M10+** — pre-validating the csrf grep
   against the running v0.9.2 saved a permanently-green smoke assertion. Every new
   smoke condition gets validated against current live state BEFORE it ships.
5. **Audit the absorbing daemon commit** (`b9310217`) to confirm it carried ONLY
   flake.lock — if unrelated churn rode it, the lock-bump attribution is worse than
   "degraded" (queued in §f).

## f) NEXT — up to 50 things (ordered, resumable)

**M10 — smoke additions (resume point):**
1. Read `scripts/post-deploy-check.sh` dnsblockd section in full (the §-numbered block
   containing the memory check).
2. Insert `_dns_*` probes: extract deployed config path via
   `systemctl show -p ExecStart --value dnsblockd` → `/nix/store/…-dnsblockd-config.yaml`.
3. Assert `"allowlist_path":"/var/lib/dnsblockd/allowlist"` in the deployed YAML.
4. Assert `"csrf_enabled":true` (config-level — the ONLY csrf signal that cannot
   phantom-green).
5. Assert device registry rendered (`"id":"evo-x2"`, `"id":"pixel6"` …) and
   `"name":"Lars"` user.
6. Assert rate-limit 50/100 and log_sampling 500/100 keys present.
7. Discriminating csrf probe: POST to the allow endpoint WITHOUT token → expect 403
   (pre-validated only after M11 deploys csrf on; ship as config-gated).
8. Keep `report_pass/report_fail/report_skip` + skip-cleanly-on-absent-unit semantics.
9. `bash -n` the whole script; pathspec commit; amend fast.
10. Negative-proof the new greps against the OLD deployed config
    (`p6s93ln6…`) — they must FAIL there (proving they discriminate).
11. Decide WARN-vs-FAIL semantics for probes whose keys appear only post-M11 (they
    should fail only once the deploying generation carries them).

**Verification hygiene:**
12. Run `nix fmt --no-update-lock-file -- --ci`; fix drift on touched files only.
13. Standalone statix/deadnix on the three touched .nix files (daemon-amend bypass).
14. `nix flake check --no-build` at current HEAD (parallel sessions moved the tree).
15. `git show --stat b9310217` — confirm the absorbing daemon commit carried only
    flake.lock.

**M12 — docs sweep:**
16. Fix stale recursion comment `dns-blocker-config.nix:14-17` (T299 fixed in tree;
    forwarders are now a choice — keep them, update the comment).
17. Verify + fix blocklist count claim (25→23) in the header comment.
18. AGENTS.md dnsblockd section: deployed-rev claims (75b4ce9 until M11), allowlist
    persistence note, tracking-dial memo pointer, devices/users options.
19. `docs/services/dnsblockd.md` runbook: new options, smoke-probe inventory, memo link.

**M13 — TODO reconciliation:**
20. Annotate the 5 TODO_LIST.md queue rows + `docs/todo/services.md` library entries
    as "in-tree, awaiting M11 deploy" (do NOT mark `[x]` pre-deploy).
21. Re-check queue/library drift after annotations (edit-both rule).

**W7 — remaining upstream surface (author + inert defaults, owner-gated activation):**
22. M14: `policies` option in the wrapper (caps: 64 policies / 512 domains,
    lowercase-slug name assertions).
23. M14: shadow-mode probe doc (observe policy hits before enforcement).
24. M15: `blocklistTrialUrls` option + PERSISTENT `blocklistCacheDir` (PrivateTmp eats
    /tmp — T197 shadow-only trap).
25. M15: StateDirectory/ReadWritePaths audit for the cache dir.
26. M16: ECS options (`dns_ecs_enabled`, ipv4 prefix 24 / ipv6 56) — inert defaults.
27. M17: `tls_h3_enabled` option — inert default + UDP-443 check design.
28. Extend the render test for every new option (negative-proof via worktree mutation).

**W8 — upstream-module migration (LAST):**
29. M18: mapping table wrapper option ↔ upstream module option (core|dns|tracking|proxy-tls).
30. M18: surface-preservation baseline — `git worktree` at pre-migration commit, eval
    JSON of unit + config keys both trees, set-compare.
31. M19: impl A — consume upstream `nixosModules` in the wrapper.
32. M20: impl B — re-add SystemNix-only overlays (whitelist pre-filter, attach-ip,
    harden/oomd-exempt, sops env bridging).
33. M21: set-compare verification + VM test green.

**M11 prep (agent-safe parts only):**
34. Pre-build toplevel for warm cache
    (`nix build .#nixosConfigurations.evo-x2.config.system.build.toplevel`).
35. Check dnsblockd for a config-validate/dry-run CLI (upstream repo) for pre-deploy
    binary acceptance of the new keys.
36. Write the M11 runbook addendum (deploy → smoke → allowlist persistence verify →
    csrf 403 verify → device attribution spot-check).

**Close-out:**
37. Final execution report (supersedes/extends the 13-07 one) with dead-SHA corrections.
38. Update the tracking memo if the user answers the dial question (§g Q2).
39. Re-verify all five waves' tests green at final HEAD.
40. Sweep the plan doc with per-task disposition (done/deviation/user-gated).

**Discovered extras (from verification):**
41. Consider a `scripts/`-level guard that fails docs referencing non-ancestor SHAs
    (cheap git hook class) — candidate, not committed work.
42. Check whether rpi3's dnsblockd render (it inherits `extraDomains`) also needs the
    new options documented in its runbook section.

## g) QUESTIONS (cannot figure out myself)

1. **Device identities — confirm before M11:** is `pixel6` really `192.168.1.29`
   (owner-confirm comment: randomized WiFi MAC `2e:fd:a5…`) and `lg-tv` really
   `192.168.1.62` (Realtek NIC `00:e0:4c…`)? Wrong IPs silently misattribute Top
   Clients / per-device pauses.
2. **Tracking dial:** flip to `METADATA_AND_DNS` in the same M11 deploy (one-line +
   test-assertion update in one commit, memo recommends it), or hold
   `METADATA_ONLY`? Needs owner sanction — I will not flip it unilaterally.
3. **rpi3 parity:** should `rpi3-dns` also get the devices/users registry + rate
   limits, or stay minimal (it already inherits `extraDomains` via the shared module)?

---

**Resume point:** §f item 1 (read the smoke script, then M10 edits). Awaiting
instructions.
