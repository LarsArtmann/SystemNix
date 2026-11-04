# Offsite Borg go-live: owner decisions executed — /data dropped from paths (seed ~646 G), recovery copy printed to paper

**Authored:** 2026-11-04 07:19 CET · **Session window:** ~07:06 → 07:19 (continuation of the 07:05 self-review session)
**Trigger:** owner answered the three open questions from the 07:05 report §g.

## Owner decisions (verbatim essence)

1. **Existing box contents**: KEEP (`borg-repository/`, `pihole/`, `pvc-*` — no quota concern).
2. **Seed composition**: `/mnt/pool/backups` + immich (15 G) + paperless (4.4 G) + `/home/lars` post-exclude (~150 G) "seems like a good start".
3. **Recovery copy**: "store the password somewhere smart on this computer and print it on a paper via the connected printer".

## Executed + verified

1. **Paths edit** (`platforms/nixos/system/backup.nix`, daemon commit `99f8bffb0`): `/data` REMOVED from `paths` default → seed = `/etc` + `/home/lars` + `/mnt/pool/backups` + immich + paperless ≈ **646 G raw** (was 692 G). The `/data/*` excludes stay as guard rails with an owner-decision note in the option description. **Assumption kept and documented:** `/etc` stays (1.2 M — it carries `/etc/ssh/ssh_host_ed25519_key`, the sops-age DR bootstrap; dropping it would break the decrypt chain the recovery sheet itself references).
2. **Eval gate**: `nix flake check --no-build` **all checks passed** (07:1x, post-edit tree).
3. **Recovery copy executed + verified** (`~/.cache/borg-golive/recovery-copy.sh`, transcript-safe by construction — value only ever flows through pipes into root-owned files):
   - Local: `/root/borg-recovery/borg-offsite-password.txt` (0700 dir, 0400 file, root) + `README.txt` (what it opens, decrypt chain, drill pointers). **Byte-equality vs sops verified: MATCH, 64 chars** — displayed as MATCH/MISMATCH + length only, never content (sops skill block-scalar/leak discipline; `sops -d --extract '["borg_password"]'`).
   - Paper: sheet (repo identity + indented passphrase + restore/drill pointers) printed via the Canon MG2500 — printer was PAUSED since 11-01, `cupsenable` revived it, **job `Canon_MG2500_series-59` COMPLETED**. Intermediate sheet file shredded after CUPS took its copy. Physical paper storage = owner act (verify the sheet landed somewhere safe).
4. **Docs/todo surfaces synced**: runbook Paths row added (What-exists table), go-live checklist step 1 ticked ✅ with evidence; `storage.md:58` blocker tail now **deploy only**; seed-cut `[decision]` row + passphrase recovery row (storage.md:54 + TODO_LIST twin) ticked [x] with resolutions; `check-todo-system.sh` structure clean after each pass.
5. **Watcher still armed** (job 04D): sample 5 at 07:17 — PSI dipped to 33 briefly (sample 4) but the trigger needs <20 sustained ×2; storm persists (66–84% range at close). Deploy will fire on drain, carrying the owner's composition. Auto-start note: the 06:30 Persistent timer elapses on first activation → the ~646 G seed begins automatically post-deploy; the owner was informed (07:05 report §g.3) and did not request a hold — proceeding per committed default.

## Not started (unchanged, deploy-gated)

Deploy + anchor, §13/§16 gates, unit/timer/secret-render verification, seed run + journal watch, first-run `--stats` vs 800 G trigger, archive-vs-exclude runtime audit (verify `.snapshots` pattern class), `.last_success`/metrics/Gatus greens, restore drill + `offsite-borg-restore.md`, post-deploy docs flip, closing storage.md:58 + the two 2026-11-03 rows, box-password rotation reminder (owner, post-go-live).

## Harvest ledger

- No NEW rows needed — this session only RESOLVED existing ones (seed-cut decision row, passphrase recovery row ×2 surfaces, :58 blocker narrowing, runbook step-1 tick). All edits verified by `check-todo-system.sh` (structure clean; the 179 unharvested-§f WARNs are pre-existing repo drift, untouched).
- Deliberately NOT harvested: watcher liveness watch (session orchestration); paper-sheet physical storage confirmation (owner act, conversational).

*Every owner-gated input is now closed. The only thing between here and the first offsite archive is PSI drain.*
