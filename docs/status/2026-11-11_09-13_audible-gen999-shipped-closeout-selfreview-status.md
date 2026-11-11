# Audible-sync fix SHIPPED (gen-999) — close-out + self-review

**When:** 2026-11-11 09:13 CET · **HEAD:** `ba2909528` · **Tree:** clean · **Live gen:** 999 (`y4nrx9n6fmpzy4wz1r002c1fgmkjpyyp…`)
**Session:** continuation of the audible-dirs fix arc (report `2026-11-11_01-13_audible-dirs-two-layer-226-eperm-fix-storm-deploy-status.md` + its §h close-out); this report covers what happened after that close-out was written, and answers the owner's three questions directly.

**Owner's opener answered in one line each:**
- **Forgot:** the deploy's own lock-float step invalidates a pre-float eval probe (deploy #5 burned on exactly that), and to re-check MY OWN deploy's process tree after rc — it lingered ~53 min and blocked a foreign session's 08:26 deploy attempt.
- **Could have done better:** written the paperless-gpt eval-proof claim only AFTER the eval returned (I wrote it first, got lucky), gated the poll loop on float-ceremony quiescence instead of toplevel-eval green, and attributed the 08:47:26 dirs re-fire instead of waving it off as "harmless".
- **Can still improve:** smoke batteries need an automatic persistent-vs-self-healed re-probe pass; the pressure-gate authority rule still doesn't exist; tq-agent-pool's cgroup escape is an un-audited unit-shape class.

**Scope of this report — VERIFIED here (fresh commands, this session):**
- gen anchor: `readlink /run/current-system` == `system-999-link` == `y4nrx9n6…` (read back 07:5x and re-read 08:5x after the 08:26 foreign refusal log surfaced).
- Live unit content: `grep CapabilityBoundingSet\|ReadWritePaths /etc/systemd/system/audible-sync-dirs.service` → both fixes present.
- Dirs unit runs: `journalctl -u audible-sync-dirs.service --since "2026-11-11 07:30"` → "Finished" at 07:46:40 + 08:47:26, zero errors.
- Filesystem: `stat` all three leaf dirs → `audible-sync:audible-sync` 0755; `books`+`downloads` ctime 07:46; `library` chowned from root (mtime unchanged 23:43 — chown doesn't touch mtime).
- Unit result: busctl `Result=success`, `ExecMainStatus=0`, active(exited); main unit inactive/dead, no journal entries.
- Paperless-gpt eval-proof: `nix eval --impure --file ~/.cache/audible-fix/pgpt-proof.nix` → `{"enabled":true,"upstream":"llama-chat"}` (output captured in `~/.cache/audible-fix/pgpt-proof.out`).
- Deploy #5 failure mode: read from `~/.cache/audible-fix/deploy5.log` (§13/§14 float drift) + registry/lock/allowlist agreement post-wave via jq + grep (all crm `f2d1726`).
- Deploy #6: full log read (`~/.cache/audible-fix/deploy6.log`, 4860 lines) — activation, failed-units list, smoke battery tally (168 PASS / 8 FAIL / 1 STORM-SUSPECT / 4 SKIP), anchor repair line.
- Persistent failures: busctl ActiveState for 8 units at ~08:5x + journal tails for forgejo-github-sync (exit 6/NOTCONFIGURED) and tq-agent-pool (cgroup-escape lines, 32.7G swap peak).
- Commits: `git show --stat` on `2637e8719` (report §h, 23 insertions) and `ba2909528` (4 queue-row lines); final `git status --short` empty.

**Scope — NOT verified here (named gaps):**
- Gatus live UI / SigNoz dashboards: not probed (eval gates green in #6's battery is the only Gatus evidence; audible has no HTTP surface).
- The three persistent foreign failures' ROOT CAUSES: journal tails read, no deeper investigation (foreign-owned; not started).
- tq-agent-pool swap state after 08:56: not re-probed (it was mid auto-restart at last check).
- The 08:47:26 dirs stop→start re-fire: clean outcome verified, MECHANISM unattributed.
- Why my deploy #6 process tree lingered past rc=3: inferred from the 08:26 refusal log's holder PID (started 07:33, alive 52:45 at 08:26), mechanism not traced.
- pma library-reports session progress since 01:13: no new datapoint (deliberately out of scope per owner's "don't research unrelated").
- Whether any deploy landed between 08:26 and 09:13 besides mine: gen-999 still newest at 08:5x read; no deploy log newer than 08:26 seen, but I did not re-`ls` the deploy-log dir at write time.

---

## a) FULLY DONE

1. **Deploy #6 → gen-999 LIVE, anchor discipline satisfied.** Fired 07:33 after full pre-flight (eval green; drv-equality proved REAL drift: current-system deriver `glidwahg…` ≠ tree `xw40s431…`; eval-relevant files quiet 5+ min; `DEPLOY_FORCE_PRESSURE=1` third override, same justification). Switch completed 07:46:40; deploy auto-repaired the nh exit-4 unanchor ("anchor repaired: system profile now points at the running system"). Evidence: `deploy6.log:4479-4495`, readlink chain above.
2. **Both audible-sync-dirs fixes live on the host.** `CapabilityBoundingSet=CAP_CHOWN CAP_FOWNER CAP_DAC_OVERRIDE` + `ReadWritePaths=/mnt/pool/services` in `/etc/systemd/system/audible-sync-dirs.service` (the 226 class AND the chown-EPERM class both closed).
3. **Dirs unit proven clean in production.** Two runs (07:46:40 activation + 08:47:26 re-fire), both "Finished", no chown error, no 226; `Result=success`, `ExecMainStatus=0`, active(exited).
4. **Filesystem outcome verified, §f.35 of the 01:13 report closed.** `books` + `downloads` CREATED by the 07:46 run; `library` (left root-owned by the EPERM runs) now `audible-sync:audible-sync` — verified, not assumed.
5. **Paperless-gpt follow eval-proof: GREEN.** Throwaway `extendModules` (mkForce `llama-chat.enable=true`) → `paperless-gpt.enable=true` via the auto-follow at `configuration.nix:698`; the `ocrProvider="llm"` throw is opt-in-only (default `"off"`), so the auto-follow branch is not booby-trapped. Never touched the tree.
6. **Tile + Gatus legs closed.** `openaudible.png` tile at `audible-sync.nix:395`; §16 tile-pack gate + gatus-coverage-audit green in #6's battery (the switch completing proves every blocking pre-deploy gate passed).
7. **Deploy #6 smoke battery fully attributed — zero items mine.** 4 activation-failed units are the deploy3 storm-casualty set (pre-existing on gen-998); inboxclean-sync / calm-gate / service-health-check / geometrikks-log-pull-pbx self-healed to clean; bank-sync active/running again; CV render was STORM-SUSPECT (proxy-path render PASSed).
8. **Deploy #5 post-mortem complete.** Its own lock float (deploy floats by design) hit §13/§14 drift because the foreign wave was mid-ceremony at 02:17; the wave landed ~03:00 (lock == registry == allowlist, crm `f2d1726` everywhere); four foreign gate-refusals (03:36–03:59, code=12, no override) kept the box quiet until #6.
9. **Close-out landed on all surfaces.** Report §h appended (`2637e8719`, 23 insertions); 4 queue rows updated across `TODO_LIST.md` (425, 3431) + `docs/todo/services.md` (679, 1069) — no drift, single physical lines full-matched; committed `ba2909528`; tree clean.
10. **Deploy5's poll loop worked as designed and its failure was diagnosed, not retried blindly** — eval probe → auto-fire → rc=1 → log read → root cause named → wave waited out.

## b) PARTIALLY DONE

1. **Audible-sync mission — fixes SHIPPED and verified; seed-gated legs remain.** Works: everything in §a. Remains: first seed run (owner decision §g1) → then journal three-phase check (`exporting full library listing` / `downloading full library` / `decrypting to DRM-free M4B`) + backup-coordination freshness row. Blocker: owner answer only. Effort to finish after green light: S (start) + M (post-seed verification over hours of run time).
2. **Deploy #6 smoke triage — attributed but 3 foreign issues unresolved.** Works: every FAIL mapped to storm-casualty / self-healed / persistent-foreign. Remains: the three persistent ones (below) are flagged, not fixed — ownership outside this session's mission. Blocker: not mine to fix without owner steer.
3. **forgejo-runner-evo-x2 triage — contradiction named, cause not pulled.** Works: live state (inactive/dead at ~08:5x, 60+ min after the smoke claimed "5-min runner-ensure timer converges it") contradicts the check's own message. Remains: read the timer's journal + last ensure run. Blocker: foreign-owned service. Effort: S.
4. **Dirs-unit 08:47:26 re-fire — outcome clean, mechanism unknown.** Works: verified Finished + Result=success. Remains: WHO/WHAT triggered the same-second stop→start between deploys (no gen change, no deploy log in window). Effort: S. Value: closes a ghost.
5. **tq-agent-pool crash-loop — failure shape captured, root cause untouched.** Works: journal shows `.postgres-wrapp` ×4 + `mariadbd` children REMAINING RUNNING after unit stop, 8G memory peak, 32.7G SWAP peak, auto-restart loop. Remains: unit KillMode/cgroup-hygiene fix + why children escape; also whether it is swap-thrashing RIGHT NOW. Blocker: foreign infra (tq pool). Effort: M.

## c) NOT STARTED

1. **First seed run** (`audible-sync.service`) — owner-gated (§g1); unit is root-gated so start goes through the owner or a deploy provisioner path.
2. **forgejo-github-sync NOTCONFIGURED root cause** — exit 6 = missing credential/config; not started (foreign-owned).
3. **tq-agent-pool cgroup-escape fix** — not started (foreign infra).
4. **forgejo-runner ensure-timer diagnosis** — not started (foreign infra).
5. **Pressure-gate override authority rule** — queued row exists (`TODO_LIST.md` ~3458 / pipeline.md), zero work done.
6. **Post-provisioner is-failed sweep in deploy.sh** — queued row exists (dirs oneshot failures were silent through 6 deploys), not started.
7. **Deploy pre-flight codify (PSI read + drv-equality before every deploy)** — queued row exists, not started.
8. **Poll-loop deploy-gate hardening (float-ceremony quiescence)** — NEW this session (deploy #5 lesson), identified, not implemented.
9. **Lingering-deploy-tree reap/verify in deploy.sh** — NEW this session (§d.2), identified, not implemented.
10. **Persistent-vs-self-healed smoke re-probe pass** — NEW this session, identified, not implemented.
11. **pma session adjudication** — owner-gated (§g2), storm continued through deploy #6 (entry gate read 43-53% IO PSI).
12. **pim-sync sops scaffold enable flip** — queued adjacent row (audible precedent complete), not started.
13. **/data/docker (~15.5G) + gcs-staging (24G) owner reclaim** — owner decisions, untouched.
14. **google-sync + pim-sync GCP/OAuth console unblock** — shares the owner console session with audible (done for audible only), not started.

## d) TOTALLY FUCKED UP

*(radical honesty; this session's own misses first — the earlier arc's five are recorded in the 01:13 report §d and are NOT re-litigated here)*

1. **I wrote a proof claim BEFORE its proof existed.** §h of the 01:13 report was appended while the paperless-gpt eval (background shell 056) was still running; the "GREEN" line entered the report ~2 minutes before the eval returned `{"enabled":true,…}`. It happened to be true and the captured output now backs it — but the sequencing is the exact "assert WHICH question your evidence answers" violation class. Severity: low (self-caught within the session, evidence captured). Workaround: none needed post-hoc; the rule is behavioral.
2. **My deploy #6 process tree lingered and blocked a foreign session.** The 08:26 deploy log shows holder PID 3216162 (started 07:33 — my deploy) ALIVE at 52:45 elapsed; the foreign session's attempt died code=13 on the flock. I never checked my own deploy's FULL process tree after rc=3 — the "wait for the FULL process tree, not one PID" discipline (2026-10-23) was applied by me to OTHERS' deploys, not mine. Severity: medium (blocked a peer session ~10 min of attempt cycles; flock auto-releases on death). Root cause: unknown — either nh lingers post-smoke or a detached child held the lock; not traced.
3. **Deploy #5's wasted run was foreseeable and not prevented.** I KNEW deploys float the lock by design and that deploy #4b died on the lock-commit step — yet the poll loop gated only on toplevel-eval green, which validates the PRE-float tree. ~17 min + a validation battery burned on an abort the moment the float ran into a mid-ceremony foreign wave. Severity: low (cost only). Root cause: gate designed on the wrong predicate.
4. **False drift alarm from a grep.** A 40-char rev grep against `flake.lock` returned no match (pattern typo'd) and I nearly read registry drift into a negative grep; jq resolved the true state (consistent) in one command. Severity: low (one round-trip). Lesson: jq is the authority for lock/registry rev comparisons; grep is the rough cut — this is the quote-scrutiny rule (2026-10-26) applied to negatives.
5. **The 08:47:26 re-fire was waved off.** A same-second stop→start of a oneshot between deploys is anomalous behavior I labeled "harmless" from its clean Finish alone. Unattributed runtime behavior = a ghost I chose not to chase mid-task. Severity: low; moved to §b.4 so it doesn't die here.
6. **Commit-time mental model wrong during the daemon race.** My amend's stat (2 files) contradicted my expectation (3 files) and I burned a verification round establishing the true chain (daemon swept the queue files mid-flight; amend reworded its commit; outcome verified clean). Severity: none landed; cost: one round-trip + the risk I DIDN'T notice if the contents had been foreign.

## e) WHAT WE SHOULD IMPROVE

1. **Report-before-evidence sequencing (from §d.1).** Rule proposal: a proof claim enters any report/close-out only AFTER its command has returned. Concrete fix: when composing close-outs, write proof lines LAST, after re-reading each proof's captured output.
2. **Poll-loop / auto-deploy gates must validate the FLOAT state, not just the tree (from §d.3).** Concrete fix: before auto-firing a deploy, require (a) toplevel eval green AND (b) `flake.lock` mtime quiet AND (c) float-register dry-run green ("no drift") — the same predicate the deploy itself will enforce post-float.
3. **deploy.sh should reap its own process tree before exiting (from §d.2).** The flock-holder design assumes the tree dies with rc; it demonstrably doesn't always. Concrete fix: post-rc `pgrep -f` sweep of the deploy's own PID family (or `setsid` + kill-on-exit), so a lingering nh never blocks the next session.
4. **Smoke battery: add a persistent-vs-self-healed re-probe pass.** Concrete fix: after an rc=3 battery, schedule a ~30-min-later re-probe of ONLY the FAIL set and log which recovered; kills the "NEW smoke failures" ambiguity that left me hand-classifying 8 failures against a stale baseline.
5. **tq-agent-pool unit-shape audit (from §b.5).** DB children escaping a unit stop is a systemd-hygiene bug class; if it generalizes, add a `systemd-shape-audit.nix` leg (KillMode control-group presence for units owning DB daemons).
6. **Our own scripts' claims get verify-before-filing too.** The smoke check's "5-min runner-ensure timer converges it" was live-false for 60+ min. Concrete fix: comment claims about timers/convergers get a journal evidence cite or get dropped.
7. **Oneshot convergence re-fires need attribution by design.** A same-second stop→start with no deploy should be traceable (journal `MESSAGE_ID` or an explicit trigger log line in the unit); today I could only say "it happened".
8. **Pressure-gate authority keeps being decided ad hoc.** Three overrides this arc (gen-998, deploy #6, plus #5's entry override), same justification each time, still no codified rule — the queued row is the right home; it needs an owner verdict (§g3).

## f) NEXT — up to 50 things to get done

*(ranked by impact; NEW = born from this session, queued = row already exists in TODO_LIST/docs/todo — HARVEST: the four NEW pipeline items are appended to `docs/todo/pipeline.md` at authoring time per the standing self-harvest rule; the rest are already-queued, owner-gated, or roadmap-class with reasons recorded)*

1. **Owner: pick seed timing — start `audible-sync.service` now vs Sunday 05:00** — Critical / S / Feature (owner-gated; unblocks the last audible legs).
2. **After seed: journal three-phase check + `last_success` freshness row appears in backup-coordination** — Critical / M / Verification (seed-gated).
3. **Root-cause tq-agent-pool crash-loop** (children escape cgroup stop; 32.7G swap peak — active freeze-risk contributor under storm) — Critical / M / Bug (NEW).
4. **Root-cause forgejo-github-sync exit 6/NOTCONFIGURED** (missing credential/config) — High / M / Bug.
5. **Diagnose forgejo-runner ensure-timer non-convergence** (smoke claim live-false 60+ min) — High / S / Bug (NEW observation).
6. **Harden auto-deploy poll-loop gates: + lock mtime quiet + float-register dry-run** — High / S / Quality (NEW; deploy #5 lesson).
7. **deploy.sh: reap/verify own process tree post-rc so the flock never outlives the deploy** — High / M / Quality (NEW; §d.2).
8. **Smoke battery: automatic ~30-min persistent-vs-self-healed re-probe of the FAIL set** — High / M / Quality (NEW).
9. **Attribute the 08:47:26 audible-sync-dirs stop→start re-fire** — Medium / S / Verification (NEW ghost).
10. **Codify DEPLOY_FORCE_PRESSURE authority rule** (who may force, what delta qualifies) — High / S / Policy (queued).
11. **Post-provisioner is-failed sweep in deploy.sh** (dirs oneshot failures silent through 6 deploys) — High / M / Quality (queued).
12. **Codify deploy pre-flight: PSI read + drv-equality before EVERY deploy** — High / S / Quality (queued).
13. **Re-probe tq-agent-pool swap pressure NOW and add it to stability watch if thrashing** — High / S / Bug (NEW, follows from 3).
14. **pma library-reports session: pause/kill vs let-finish decision** (storm source; 5h+ no output as of 01:13) — High / S / Owner call (§g2).
15. **pim-sync: paste placeholder + flip enable** (audible precedent complete) — Medium / S / Feature (queued).
16. **Fix audible-sync.md quickstart line** (`jq … auth.json` → real file `audible.json`) — Medium / S / Documentation (queued adjacent).
17. **Check google-sync + paperless runbooks for the same parent-vs-leaf RWP wording bug** audible's had — Medium / S / Documentation (queued adjacent).
18. **Add the "caps go INSIDE harden{} args" one-liner to AGENTS.md critical rules** (hardened{} throws only covers lifecycle keys) — Medium / S / Documentation (roadmap 33).
19. **GoogleDrive/OAuth console visit to unblock google-sync + pim-sync** (audible already done there) — Medium / S / Owner action (queued adjacent).
20. **/data/docker ~15.5G + gcs-staging 24G owner-reclaim decisions** — Medium / S / Owner call (queued).
21. **PSI-aware fast-path for the deploy battery** (defer non-§11 legs when the entry gate was force-overridden; §15/§16/§19 cost ~68 min under storm) — Medium / M / Quality (roadmap 32).
22. **Per-provisioner result summary in the provisioner sweep** (silent-failure legibility) — Medium / S / Quality (roadmap 31).
23. **service-health-check storm tolerance/backoff** (failed during exactly the multi-service window it exists for) — Medium / M / Bug (roadmap 38).
24. **audible-sync startLimitBurst note for the provisioner-sweep design** (rapid-flapping deploys could hit 5/300s) — Low / S / Quality (roadmap 39).
25. **Heartbeat file per long-running foreign session** (pma ran 5h+ with zero output; storm triage was blind) — Medium / S / Quality (roadmap 36).
26. **nvme0/nvme1 re-resolve discipline for SMART/attribution probes** (perishable enumeration, flipped 2026-10-22) — Low / S / Quality (queued adjacent).
27. **Skim the 773-file daemon sweep (`9ff1d1645`) by its owning session** — Low / S / Cleanup (queued adjacent; possibly stale now).
28. **eval-cache SQLite "busy" degradation under concurrent nix** — Low / S / Watch (roadmap 40, observation only).
29. **jq-in-direnv + midnight-trap recurrence check in next docs-health VERIFY pass** — Low / S / Documentation (roadmap 37).
30. **Re-audit remaining sibling dirs units' runbook wording against the parent-RWP shape** (generalization of 17) — Low / S / Documentation (NEW, follows from §e.6).

*(deliberately NOT harvested into queue files: items 1, 2, 14 are owner-gated asks already carried in §g and the existing go-live row; items 3-9, 13 are NEW and the four pipeline-shaped ones — 6, 7, 8, 11-adjacent — are appended below; items 15-20, 26-27 already have queue rows; items 21-25, 28-29 are roadmap-class per the TODO-system split.)*

## g) Questions I can NOT figure out myself

1. **Seed timing (asked 01:13, still unanswered — the ONLY remaining audible leg):** start `audible-sync.service` immediately (full-library download runs up to 48h; HDD pool idle overnight) or wait for Sunday 05:00? If "now": the unit is root-gated — do YOU want to run `systemctl start audible-sync.service`, or shall I route it through a deploy provisioner path?
2. **The pma library-reports session** (PID 321653 at 01:13; "do we use <20 libs>" reports → docs/review/libs/): still saturating the disk through deploy #6 (entry gates read 43-53% IO PSI at 07:33). Do you know whether it produces real output eventually, and should it be paused/killed and re-run in a quiet window? I won't kill foreign work without your call — but it is the storm every deploy this arc had to override.
3. **DEPLOY_FORCE_PRESSURE authority (asked 01:13, now THREE overrides deep):** is the precedent right — agent may force when (a) delta trivial AND (b) storm foreign AND (c) documented override exists — or owner-only from now on? Tonight it shipped a 4-day-old fix under a foreign storm; the same rule also waved #5 into a wasted battery, so the rule needs both the authority AND the quiescence predicate (§e.2).
