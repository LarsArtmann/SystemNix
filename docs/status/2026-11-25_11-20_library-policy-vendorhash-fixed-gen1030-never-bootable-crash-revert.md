# Library-policy vendorHash deploy blocker fixed — the first switch was never bootable, two crashes reverted the box to gen-1029

**Session:** 2026-11-25 04:30 → 19:30 CET (evo-x2, concurrent sibling sessions throughout; three turn boundaries, one per owner re-send)
**Trigger:** owner-pasted failed deploy (`DEPLOY_FORCE_PRESSURE=2 nix run .#deploy`, HEAD `3150a0050`, 01:35→01:53): `library-policy-e092b400-go-modules.drv` hash mismatch (specified `gYkUTyDk…`, got `UCnKnjhq…`), cascading through `man-paths` into `system-path`.
**HEAD at authoring:** `74763a8e7` (plus formatter-only diffs on `lib/lars-packages.nix` and `modules/nixos/services/system-health.nix`)
**Live system:** gen-1029 (`gwfgxm1v`, built 2026-11-24 23:33) from 11:06 until the 18:54 deploy below started switching to gen-1031 (`6q9jp84a`). Boot id `0737ecd7` (booted 11:06:51).

---

## a) FULLY DONE

1. **Root cause of the pasted failure.** The consumer-side vendorHash shim in `lib/lars-packages.nix` was pure treadmill: the overnight daemon float moved `library-policy` `8d2b87bf` → `e092b400` (commit `477059e19`, 00:32) while the shim still carried `gYkUTyDk…` (measured at `8d2b87bf` on 11-24). Upstream `e092b400` flake.nix:146 already bakes exactly the deploy's got-hash `UCnKnjhq…` (`a031de3` "refresh vendor hash for the go-datastar version bump"). got == bake is the documented drop-safety test (docs/agents/nix-flakes.md "Misattributed FOD hashes").
2. **Fix: shim dropped** to `library-policy = flakePkg inputs.library-policy;` with a history comment citing the deploy log (commit `89cba86fb`, renumbered by a sibling's history rewrite; was `c008ddc62`).
3. **First-hand proof.** Flake-attr toplevel `--keep-going` built 34/34 green (04:49:36→04:50:17); exactly ONE library-policy in the closure (no twin surface); the built go-modules FOD's content hash, recomputed with `nix hash convert --hash-algo sha256 --from nix32 --to sri`, equals `sha256-UCnKnjhqG+PmNkrzZMT3w/F5BAVaMPAGCzrYasbQi0M=`; the a60fda4 binary answers `--help`.
4. **Deploy #1 carried the fix** (`DEPLOY_FORCE_PRESSURE=1 nix run .#deploy`, 04:59:27 → rc=0 at 06:26:27, `/var/log/systemnix-deploys/2026-11-25_04-59-27.log`): §11 "all deploy go-modules FODs cached", build green, gen-1030 activated. Why it did not persist: §b.1.
5. **§11 gate hardened** (`scripts/lib/vendor-freshness.sh`, `scripts/test-pre-deploy-vendor.sh`, `scripts/pre-deploy-check.sh`; commit `6f06c8771` + follow-ups). A toplevel `--dry-run` that fails now FAILs with the raw output tail and a tree-move note instead of degrading to a context-free WARN; only the known-benign nix error classes (check #1's vocabulary) are read past; a non-zero exit that printed no plan fails closed; the unused WARN callback is gone. 33 fixture + stubbed-`nix` flow assertions green (`scripts/test-pre-deploy-vendor.sh`), strict-mode harness green, the new tests fail against the old lib, the `pre-deploy-vendor-selftest` builds green in the nix sandbox (awk IS on a `runCommand` PATH here; verified, not assumed). **First live verdict (11:36, `--section-11-only`) named the real error behind last night's WARNs:** nix exit 102 `store path … contents have changed … Make sure files do not change during evaluation` with `[tree 56c3a7d*] → [tree 56c3a7d*]` — a parallel session editing the tree during the ~50 s eval.
6. **deploy.sh gained the second anchor leg** (`boot_entry_anchor_status`, commit `b884174cf` + `8b40f7fc7`): on every switch it reads the loader's `preferred` entry and checks that the entry's `options init=` is the running toplevel; on mismatch it re-arms the boot entries with `sudo <running>/bin/switch-to-configuration boot` BEFORE the provisioner loop that restarts boot-mirror-sync, and the final assertion exits 14 on `UNANCHORED (boot entry)`; an unreadable ESP is a WARN, never a pass. Validated live against the real ESPs at 11:27 before the fix could land: running gen-1029 → `ok`; gen-1030 → `unanchored: /boot/loader/loader.conf prefers nixos-90cc59d1…a7fd.conf, which does not boot /nix/store/hggzirywc8…`. Fixture group G in `scripts/test-deploy-pipeline.sh` (71 assertions hold; two mutations each trip it).
7. **Docs and memory:** AGENTS.md "Build & Deploy" gained the two paragraphs (anchor second leg; §11 contract); CHANGELOG gained three entries; TODO harvest in §h; the sibling report's anchor claim annotated inline (docs/status/2026-11-25_06-19_…md, top blockquote).
8. **Lint:** shellcheck (warning severity, the hook's bar) clean on all six touched scripts; canonical formatter run on `lib/lars-packages.nix` (it rewrote three SIBLING shim sites that rode daemon commits unformatted: `invoices`, `io-surface`, `project-discovery-daemon`; my library-policy lines were already canonical).

## b) PARTIALLY DONE

1. **Deploy #1 did not survive the morning.** Activation ended with **exit 4** (failed units; `post-crash-calm-gate.service` held the 05:09→06:09 activation for its full 60-min calm wait, then refused). nh printed "Activation failed; the new generation will not be added to the bootloader" and skipped the boot entry; deploy.sh's exit-4 recovery still reported rc=0 with a new profile generation. ESP state read with sudo at 11:13 on BOTH `/boot` and `/boot-mirror`: newest entry still `Generation 1029` (`nixos-90cc59d1…a7fd.conf`), `loader.conf` `preferred` unchanged, both mtimes 11-24 23:33:54, **zero entries carrying gen-1030**.
2. **Two hard resets reverted the box to gen-1029:** boot `b4931451` died 08:57:47 (kernel: `Previous system reset reason [0x02000800]: hardware watchdog timer expired`), boot `8b31b428` died 11:05:51 (`[0x00080800]: software wrote 0x6 to reset control register 0xCF9`, the ledger's panic-reboot class; its journal ends mid-activity on redis BGSAVE lines, no shutdown ceremony). Each boot reached IO PSI some 65-99% within minutes (11:12 probes on boot `0737ecd7`: cvagent pid 2487 read 116 MB/s for one 6 s window then idled; `clickhouse.service` io.pressure some 68%; `llama-vlm-cap`'s llama-server in D-state on `blk_mq_get_tag`; `xfsaild/nvme0n1p9` D-state). Evidence pulls for both dying boots exist from a sibling (docs/status/tasks/2026-11-25_10-22_boot-{b4931451,8b31b428}-evidence-pull.md).
3. **A sibling report's anchor claim was refuted by the ESP state and is now annotated.** `docs/status/2026-11-25_06-19_self-review-supplements-weekly-print-deploy-and-fleet-blockers.md` item 8 lists `stc boot` + mirror sync as done for gen-1030. The sudo journal confirms two `switch-to-configuration boot` invocations for `hggzirywc8` at 05:27:16 and 05:27:36, each with its sudo session closed within the same second, while this deploy's own activation still ran (05:09→06:09). Neither wrote an entry or `loader.conf`. The profile half (05:27:16 `nix build --profile`) is real. Mechanism unverified (lock contention is the hypothesis); the observation stands.
4. **Deploy #2 (plain, no force) fired in a calm window at 18:54:42** (PSI some avg10 0.4%, trip gate clean, green-eval probe 38 s, tree == HEAD plus two formatter-only diffs): entry gate `OK`, battery `154 passed, 7 warnings, 0 failed`, §11 `all deploy go-modules FODs cached [tree 74763a8*]`, build green, activation started toward `6q9jp84a`. **The activation is being held by `bank-sync-qonto-corpus.service`**: `wantedBy = [ "multi-user.target" ]` with no `RemainAfterExit` makes the oneshot inactive after every run, so the switch transaction pulled it again at 19:05:18 (timer LastTrigger is 2026-11-22; the 04:59 activation did the same at 05:09:18, 2m08s). At 19:23 it was still activating (near-zero CPU), `TimeoutStartSec=2h`. Outcome in §b.5 below once the switch returns.

## c) NOT STARTED

- Crash autopsies and the stability ledger rows for `b4931451` / `8b31b428` (stability sessions own them; the evidence files exist).
- `nix flake check` (heavy eval): not run on purpose under the morning storms; the targeted evals (toplevel drvPath, selftest derivation, formatter) are the proof surface.

---

## d) TOTALLY FUCKED UP

**Nothing I authored broke the box, but my deploy "succeeded" without persisting, and I own that.** Ranked:

1. **I reported nothing wrong with deploy #1 because I only checked what the old discipline checks.** I waited for rc=0, saw the new profile generation, and the turn ended. The boot entry was missing the whole time and the 08:57 reset erased the deploy. The third-leg check exists now because of that miss, not in spite of it.
2. **I forced `DEPLOY_FORCE_PRESSURE=1` at 04:59 into a 36-49% PSI storm** on the strength of the owner's own `=2` in the pasted command. The activation then took an hour (calm gate) and ended exit 4. The deploy was not the cause of the 08:57 watchdog reset (3.5 h later), but a forced switch into a storm is the twice-fatal class in this repo's own ledger, and I should have waited for the 18:54-style calm window or handed the force decision back.
3. **My status report sat as a draft for seven hours** while the live system was reverted and sibling reports kept saying "LIVE as gen-1030". The draft did carry the facts, but the annotation on the sibling report and the TODO rows landed only at 18:10+.
4. Small ones: a mistyped hash in an edit (caught by the exact-match tool); two failed exact-match edits on the sibling report (fixed with a scripted insert); the canonical formatter on a shared file rewrote sibling lines (benign, canonical); an ad-hoc probe line with a quoting error (discarded, replaced by fixture coverage).

## e) WHAT WE SHOULD IMPROVE

1. **Boot-time tripwire "running generation != newest profile"** (a sibling already queued the idea, ai-meter report row 29): after a reset this is the one check that would have shown the revert at 08:59 instead of 11:05.
2. **Long oneshots must not sit in multi-user.target's want set without `RemainAfterExit`** (the corpus row in §f.4); the calm-gate row (§f.2) is the same shape one level up.
3. **`stc boot` is unproven until the ESP says so**: the hand repair procedure in AGENTS.md now carries that sentence; a `scripts/boot-entry-status` read-only helper would make the ten-second check one command.
4. **A status report that claims "LIVE" should pin the boot-entry evidence next to the profile evidence** (one line: `loader.conf` preferred entry + its `init=`).

## f) UP TO 50 THINGS TO GET DONE NEXT

**Deploy state**
1. Re-deploy after the crash revert and confirm both anchors (TODO_LIST row "Re-deploy after the crash revert" → docs/todo/pipeline.md; if deploy #2 lands this row closes with its own evidence).
2. Post-crash-calm-gate must not hold a deploy's activation for its 60-min wait (docs/todo/stability.md).
**Deploy pipeline**
3. Consolidate check #1's inline benign-class awk into `vendor_freshness_real_errors` (docs/todo/pipeline.md).
4. bank-sync-qonto-corpus: every switch restarts the 2h-cap oneshot (docs/todo/services.md).
**Stability**
5. Boot-time IO storm attribution data points for the two crash boots (docs/todo/stability.md, watch).
6. Crash ledger rows + autopsy for `b4931451` (WDT) and `8b31b428` (CF9) — stability sessions.
7. Boot-time "running != newest profile" tripwire — sibling row.

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. Was 08:57 an ordered reboot or a freeze? The kernel says hardware watchdog; nobody has answered the ai-meter report's identical question. If it was not ordered, it is a new freeze to ledger.
2. Should a switch that ends with exit 4 count as "deployed"? nh deliberately refuses to add such a generation to the bootloader; deploy.sh now re-adds it because the running system is the activated truth. If the owner prefers rollback-on-reboot for exit 4, the boot-entry repair needs an opt-out.
3. Do you want the forced-deploy doctrine written down for agents: never force (`=1` or `=2`) without an explicit per-deploy token from you, even when your own last command carried one?

## h) SELF-HARVEST DECLARATION

HARVESTED. Every §f item is in TODO_LIST.md and its domain library with a `**Source:**` back-pointer: f.1 → docs/todo/pipeline.md + queue one-liner `[blocked:deploy]`; f.2 → docs/todo/stability.md + queue `[ready]`; f.3 → docs/todo/pipeline.md + queue `[ready]`; f.4 → docs/todo/services.md + queue `[ready]`; f.5 → docs/todo/stability.md + queue `[watch]`. Deliberately NOT harvested: f.6 (owned by the stability sessions, evidence already pulled) and f.7 (already a sibling row).
