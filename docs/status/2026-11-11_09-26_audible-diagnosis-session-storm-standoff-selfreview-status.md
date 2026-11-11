# Audible-diagnosis session: root-cause chain, PSI-gate standoff, sops verification — self-review

**When:** 2026-11-11 09:26 CET · **HEAD:** `49e54791d` · **Tree:** clean · **Live gen:** 999 (deployed 07:46 by the 09-13 close-out session — NOT this session)
**Session scope:** the owner-question window ("audible-sync worked?" → "audible-sync failing, why!?"): investigation of the dirs-unit failure chain, two refused deploy attempts, the I/O-storm standoff (~01:46–02:5x), sops secret integrity verification, storm delta-attribution — plus this report written at 09:26 after the parallel sessions resolved the arc (reports `2026-11-11_01-13_…storm-deploy-status.md` and `2026-11-11_09-13_…closeout-selfreview-status.md` cover the deploys and gen-999 verification; this report covers THIS session's run and adds findings neither of those reports carries).

**Parallel-session disclosure (mandatory):** while this session diagnosed and waited, at least two sibling sessions worked the same arc — the 01-13 report's session (their own diagnosis + deploys #1–4, two pressure overrides) and the close-out session (deploys #5–6, gen-999 live 07:46, full verification, 6 harvest rows via `49e54791d`). Nothing below re-claims their credit; the gen-999 landing, live verification, and paperless-gpt eval-proof are THEIRS. This session independently reproduced the same root-cause chain and contributed four findings they did not record (§ a.5–a.8).

---

## The failure chain THIS session diagnosed (01:0x–01:4x, independent of the 01-13 session)

| Window (Nov 10) | Symptom | Cause | Fix commit | Landed |
|---|---|---|---|---|
| 12:23 → 19:01 (×4) | `status=226/NAMESPACE` — `Failed to set up mount namespacing: /mnt/pool/services/audible: No such file or directory` | dirs unit `ReadWritePaths` pointed at the leaf it itself creates (systemd namespace setup precedes ExecStartPre) | `3d92a2ac4` 19:35 — parent `/mnt/pool/services` | gen 998 |
| 23:43 → Nov 11 (×2) | `chown: changing ownership of '…/library': Operation not permitted` | `harden{}`'s empty `CapabilityBoundingSet` strips `CAP_CHOWN` from root inside the namespace | `54faa31e1` 00:50 — `CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE` | gen 999 (07:46) |
| **gen 998 (built 00:43)** | carried the 226 fix but **empty** bounding set — built 7 min BEFORE `54faa31e1` landed | deploy raced the fix authoring | redeploy | 07:46 |

Evidence read fresh this session: journalctl for both units since 05:00; `grep CapabilityBoundingSet /run/current-system/…/audible-sync-dirs.service` → empty at gen 998, full set at gen 999; commit timeline `git log -1` on both fixes vs `ls -la system-99*-link` mtimes; `harden{}`/`mkPoolDirUnit` precedent at `lib/default.nix:93` (the caps set is exactly the proven `mkPoolDirUnit` invariant — the module hand-rolled its unit instead of using the lib function, which is how the bug escaped).

---

## a) FULLY DONE (this session, verified with fresh commands)

1. **Root-cause chain fully diagnosed with evidence** (table above): three-layer 226 → chown-EPERM → caps-not-deployed, each pinned to a commit time vs gen-link mtime. Independent of the parallel session; conclusions matched.
2. **`deploy.sh` provisioner coverage confirmed:** `scripts/deploy.sh:830` includes `audible-sync-dirs` in the post-switch restart loop — a deploy alone reruns the oneshot (no manual restart needed). Read from the script, not assumed.
3. **sops secret integrity PROVEN (finding the close-out report does not carry):** `sops -d --extract '["audible_sync_auth_json"]'` → `adp_token` first-10 `{enc:9nCDP` len 1501 + `device_private_key` PEM len 1679 — byte-match against the owner's source `~/.audible/audible.json`. The `{enc:9…` prefix is **audible-cli's own at-rest token encryption** (it decrypts it itself at runtime), NOT corruption — a config-check pass + clean runtime is therefore expected, now with evidence instead of assumption.
4. **Storm attribution with a delta sample:** 8s `/proc/*/io` delta → churners were a parallel `crush -y` (~11 MB/s), `bash codemod.sh` in cmdguard v4→v5 migration (~8 MB/s), projects-management daemon (~6 MB/s), two more crush sessions, a go-test binary. None killable, none mine — the gate refusals were correct.
5. **Runbook + module owner-facing filename bug FOUND (new, unharvested until now):** `docs/services/audible-sync.md:27` AND the module's config-check fail-loud echo (`audible-sync.nix:104`) instruct `jq … < ~/.audible/auth.json` — but the owner's quickstart wrote `~/.audible/audible.json` (profile `audible`, per their `~/.audible/config.toml`; the runbook's own advice produced it). The SERVICE is internally consistent (it renders its own config.toml with profile `default` + auth.json symlink), so this only misleads the next manual extraction/re-run — still a wrong instruction in a fail-loud message. Harvested this session (§ harvest.1).
6. **google-sync answer delivered from existing runbook** (no new research): dormant, 5-step ladder, shares the GCP console trip with pim-sync; `type = drive` per-remote trap + 1.9 TB seed sizing cited.
7. **Owner questions re-asked** (seed timing, deploy handoff) in the 02:5x status message.
8. **Todo list maintained across the session** (wave check → diagnosis → blocked-deploy tracking → report).

## b) PARTIALLY DONE

1. **Deploy of the caps fix:** this session fired it ONCE (01:46) → PSI-gate REFUSED (I/O `some avg10` 59% + nvme0n1 110%); correctly did NOT force; two poll-and-retry loops (15 min @20s, 40 min @60s) drained to ~45–65% flat, never below the 20% gate. The fix shipped via the PARALLEL session's forced deploy #6 (07:46, third override). Outcome live, but not by this session's hand.
2. **audible-sync go-live:** everything is live except the seed — first run is seed-timing-gated (owner decision, § g.1); timer next-fire Sunday 05:00+10min jitter, `LastTriggerUSec=0` (never fired).
3. **Owner's pending questions:** seed timing + handoff re-asked; the sops-nix float-intent question (fe7b4228 vs 89a234ce) from the prior session went STALE with the wave landed (gens 996–999) — deliberately dropped, superseded by reality.
4. **This report's harvest:** done for the genuinely-new items (§ harvest), NOT a re-harvest of the six rows the close-out session already landed (would duplicate).

## c) NOT STARTED (owned by others or owner-gated — listed for completeness)

1. **pim-sync flip** — all three owner gates open (GCP "In production" People client; Stalwart DAV account on pbx; 4 browser consents). Agent side is READY (scaffold + proven ingest recipe + config-check hardened).
2. **google-sync ladder** — owner-side (GCP Drive client + 3× `rclone authorize` + sops paste). Agent side ready to ingest + flip on owner values.
3. **Seed-gated legs** — three-phase journal proof, backup-coordination freshness row, books-count sanity. Not runnable before the seed decision.
4. **Persistent foreign failures** (forgejo-github-sync exit 6/NOTCONFIGURED; tq-agent-pool cgroup escape) — the close-out session harvested the forgejo row; fixes not started by anyone yet.

## d) TOTALLY FUCKED UP (this session's own failures, no mitigation offered)

1. **sops skill loaded only AFTER the first sops command failed.** `ssh-to-age` was typed WITHOUT `-private-key` → convert failure → wasted round-trip + a wrong-skill-path detour. The skill-load-first rule exists precisely for this; the failure was the rule's textbook case.
2. **A fake "corrupted secret" scare was manufactured and then walked back.** The first shape check grep'd the RAW decrypted YAML line and jq'd the remainder — the leading `'` is YAML quoting, not value content. For ~2 minutes the working theory was "the ingested creds are corrupt"; `sops --extract` killed it in one command. Root error: parsing a quoted scalar as if it were the raw value — the exact quote-scrutiny class AGENTS.md warns about ("would I quote this number? sanity-check one known value through the same pipeline first" — here: the KNOWN value was the source file, and the source-compare step was what exposed the pipeline artifact, by luck of ordering rather than design).
3. **The 8s I/O delta pipeline printed swapped/mangled fields** (`read kb pid` against a 3-field line; `KB/s` treated as a PID). Recovered by resolving the surviving PIDs directly, but the output as first displayed was garbage — same class as the `rg -r` and awk-offset incidents in AGENTS.md.
4. **`busctl get-property … Unit Result`** — `Result` lives on `.Service`, not `.Unit` (the mirror image of the documented ActiveState trap). One wasted probe; the AGENTS.md busctl note even hints at the interface split.
5. **The storm was waited out for ~1 h before being attributed.** The 8s delta attribution (which settled wait-vs-act in one command) ran only after two exhausted poll loops. Attribution-first would have surfaced "foreign workloads, will outlive any reasonable wait" at 02:00 instead of 02:50.
6. **`54faa31e1` — the caps fix — rides a daemon heuristic commit ("chore: auto-commit 2 changed file(s)").** Per the daemon-race policy it should have been verified (`git show --stat`) and amended into `fix(audible-sync): …` while HEAD was still that commit. Never checked, never amended; the history now carries a real production fix under a message that describes nothing.

## e) WHAT WE SHOULD IMPROVE

1. **Hand-rolled `harden{}` dirs units should not exist where `mkPoolDirUnit` covers the shape.** The module hand-rolled the unit; the lib function bakes exactly the caps set the bug lacked. Adopting it (or an audit forcing `CapabilityBoundingSet` on any unit whose script calls `chown`) closes the class. Harvested (§ harvest.2).
2. **Pre-deploy unit-render review for newly-enabled modules:** render the unit (extendModules throwaway) and grep the critical lines (`ReadWritePaths`, `CapabilityBoundingSet`, `User=`) BEFORE a deploy — the eval audits caught mount-gating and ioTier but nothing renders-and-asserts unit TEXT. Both shipped bugs were visible in a rendered unit file for hours before any deploy.
3. **Attribute before waiting:** gate-blocked deploys get an immediate 8s delta attribution (cheap, read-only) before any poll loop — the attribution decides wait-vs-ask, the polling cannot.
4. **sops VALUE inspection = `sops --extract`, never raw-line parsing** — added to the in-repo sops SKILL.md this session (§ harvest.3).
5. **Daemon-swept fixes get amended-forward with real messages** (with `git show --stat` first) — the policy exists; this session skipped it under storm pressure.
6. **Status-report pre-read worked as designed** — the 09:26 sweep (`ls -t docs/status` + `git log`) caught the parallel close-out before this report claimed a stale blocker as current. Keep as first step on every resume.

## f) NEXT — grouped, deduplicated against the six rows the close-out session already harvested (authority rule, is-failed sweep, deploy pre-flight, float-ceremony gating, forgejo row, crm pin-lift follow)

**Decision-gated (owner):**
1. **Seed timing** — start the first audible seed NOW (48h timeout, occupies the pool through the weekend) or let Sunday 05:00 fire it. § g.1.
2. **google-sync + pim-sync GCP console trip** — one sitting: People API client (pim-sync) + Drive API client (google-sync), both "In production"; then 3× `rclone authorize "drive"`; sops pastes for `google-sync.yaml` (`type = drive` in ALL three remotes) and pim-sync values; Stalwart DAV account on pbx; 4 pim-sync consents.
3. **Ratify the force-authority rule** the close-out session queued (three overrides now exist; policy still doesn't). § g.2.

**Agent-ready, queued this session (§ harvest):**
4. Fix the owner-facing `~/.audible/auth.json` filename in runbook:27 + module echo:104 (actual quickstart output: `~/.audible/audible.json`, profile `audible`).
5. Refactor `audible-sync-dirs` onto `mkPoolDirUnit` (caps invariant single-sourced; prevents the next hand-rolled chown bug).
6. Attribute the unexplained dirs re-fire triggers (12:23, 18:00 — no matching gen links; close-out's 08:47:26 unattributed instance joins the same question).
7. (Done inline this session, not queued:) sops SKILL.md `--extract` row.

**Seed-gated (blocked on § g.1):**
8. Three-phase journal proof (`exporting full library listing` / `downloading full library` / `decrypting to DRM-free M4B`).
9. backup-coordination `audible-sync` freshness row appears in Gatus after first success.
10. Books sanity: non-zero M4B sizes, dated library snapshots pruning at 13.
11. Pool headroom check before the seed (`/mnt/pool` free vs expected library size).
12. Post-first-seed runbook STATUS re-stamp + CHANGELOG entry.

**Follow-through from the gen-999 arc (other sessions' rows, untouched here):**
13. forgejo-github-sync exit-6 root cause (row exists).
14. tq-agent-pool cgroup escape + swap peak audit (named in close-out §b).
15. Post-provisioner is-failed sweep in deploy.sh (row exists).
16. DEPLOY_FORCE_PRESSURE authority definition (row exists).
17. Deploy pre-flight codification: PSI read + drv-equality every deploy (row exists).
18. Poll loops gate on float-ceremony quiescence, not just eval green (row exists).
19. Persistent-vs-self-healed re-probe pass for smoke batteries (close-out § improvement).
20. Unit-shape audit class: cgroup-escape patterns like tq-agent-pool's (close-out).

**This session's smaller residue:**
21. `sops-nix` float-intent question formally closed as moot (wave landed; registry/lock agree on crm `f2d1726` per close-out verification).
22. Owner question "deploy handoff" — answered by reality: the wave/closing sessions ran post-deploy verification; this session stood down. Record it as resolved-by-precedent unless the owner wants a standing rule. § g.2 adjacent.

## g) QUESTIONS ONLY THE OWNER CAN ANSWER

1. **First seed: NOW or Sunday 05:00?** The unit is verified green, the library export + download + decrypt chain is unproven in production until the first run. Now = validation today but a 48h-timeout job sitting on the pool through the weekend; Sunday = the designed cadence, validation a week later. (If NOW: progress pings or silence?)
2. **Force-authority: ratify or restrict?** Three `DEPLOY_FORCE_PRESSURE=1` overrides have now shipped (trivial-delta reasoning, eval-green, all landed clean — and one of them is the only reason your audible fix is live). Do you ratify "sessions may force under stated conditions" or make it owner-escalation-only?
3. **The two persistent foreign failures — mine to take?** forgejo-github-sync (exit 6/NOTCONFIGURED, still failing after gen-999) and tq-agent-pool (cgroup escape, 32.7G swap peak). Both are harvested but unowned. Want me to pick up the forgejo root-cause next session, or is the shipping session still on them?

---

## Harvest record (self-harvest obligation, done at authoring time 09:26+)

- **harvest.1** → `TODO_LIST.md` + `docs/todo/services.md`: *Fix owner-facing audible auth filename (`~/.audible/auth.json` → actual quickstart output `audible.json`) in runbook go-live step 2 + module config-check echo.* `[ready]`
- **harvest.2** → `TODO_LIST.md` + `docs/todo/services.md`: *Refactor `audible-sync-dirs` onto `mkPoolDirUnit` (caps invariant single-sourced).* `[ready]`
- **harvest.3** → `.crush/skills/sops-secret-management/SKILL.md` Common Mistakes: *inspect decrypted VALUES via `sops -d --extract '["key"]'`, never raw-line grep+jq (YAML quoting pollutes the line).* (skill file edit, in-repo)
- **harvest.4** → `TODO_LIST.md` + `docs/todo/services.md`: *Attribute audible-sync-dirs re-fire mechanism (12:23 + 18:00 runs match no gen link; 08:47:26 instance same question).* `[ready]`
- **Deliberately NOT harvested:** § f.1–3 (owner-gated decisions — they live in § g of this report and the existing blocked:user rows); § f.13–20 (already queued by the close-out session — re-adding would duplicate); § f.21–22 (closed/moot, record-only). Re-harvesting the six landed rows would violate the no-drift rule in reverse.
