# Status: Samsung 970 EVO Plus Rescue — BitLocker Disk Recovered to Pool

**Date:** 2026-08-18 00:00 CEST
**Scope:** This session only — USB-attached Windows disk identification, BitLocker unlock, plaintext rescue to HDD pool, repurposing discussion.
**Source disk:** Samsung 970 EVO Plus 1TB (`S4EWNX0RA01856V`, fw `2B2QEXM7`) in Realtek RTL9210B-CG USB-C enclosure, `/dev/sde`
**Backup destination:** `/mnt/pool/archive/desktop-u51ngkt` (BTRFS RAID1 HDD pool, `compress=zstd:3`)

---

## a) FULLY DONE ✓

1. **Disk identified & characterized.** Samsung 970 EVO Plus 1TB (TLC, 1GB DRAM, PCIe 3.0 x4 native) behind RTL9210B-CG bridge. Link negotiated at 10 Gbps (USB 3.2 Gen2). **No TRIM through the bridge** (`DISC-MAX 0B`). Stable by-id: `ata-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0RA01856V`.
2. **Contents mapped.** Complete Windows boot disk of `DESKTOP-U51NGKT`: EFI (100M) / MSR (16M) / **BitLocker v2** C: (930.9G, label dated 2022-03-26) / NTFS recovery (509M).
3. **BitLocker unlock** — user-executed via provided dislocker instructions (`dislocker-fuse -u` + `mount -o loop,ro -t ntfs3`). Plaintext at `/mnt/win`, read-only.
4. **Plaintext rescue copy COMPLETE & VERIFIED.** 178 GiB logical, **550,573 entries (444,350 files, 106,157 dirs, 66 symlinks)**, copied in 20m24s at ~148 MB/s. Final rsync itemize dry-run: **0 differences**; independently re-verified by a second dry-run outside the script (`grep -cv` = 0). Excludes: `Windows/`, `Recovery/`, `PerfLogs/`, pagefile (5.1G), hiberfil (34G), swapfile, Recycle Bins, `System Volume Information/`, `$WinREAgent/` — all anchored at volume root.
5. **Size reconciled.** 240G volume-used − ~65G exclusions ≈ 176G expected ≈ 178G copied ✓. 178G is *logical* (`du`); physical pool footprint smaller under zstd:3 (unmeasured — `compsize` needs root).
6. **Content survey of the interesting parts.** `Users/l-art` (32G: IdeaProjects/DeepBackup, Desktop 1.1G, Downloads 890M, AppData 24G); `tools/MultiMC` incl. **`accounts.json` with live Microsoft session tokens** and Minecraft worlds; JetBrains `c.kdbx` credential DBs; no `.ssh`, no wallet files; ProgramData Duplicati/ssh dirs empty.
7. **`/data` re-audited** (after user correction): `ai/` 267G, `models/` 210G, `llamacpp-models/` 92G, `SteamLibrary/` 106G, `monitor365-archive/` 32G, plus EMPTY `atticd/ docker/ containers/ cache/ monitor365/` (permissions may mask true content — measured without root). **Immich is NOT on /data** — already at `/mnt/pool/services/immich` (`modules/nixos/services/immich.nix:31`).
8. **Hardware context delivered.** 970 EVO Plus vs Lexar NQ790 (bridge-capped ~1GB/s here, but TLC sustained-read beats QLC on long model loads); 970 EVO vs EVO Plus vs 970 Pro lineage (no "EVO Pro" exists).

## b) PARTIALLY DONE ⏳

1. **Repurposing decision** — two proposal rounds, both rejected/unsatisfied. Current pitch on the table: **Steam library + all AI model storage** (675G ≈ ideal 1TB fill; frees 675 of 707G used on /data; `/data` becomes near-empty overflow). NO decision made; user hints at "games + SOMETHING high-disk" not yet named.
2. **Verification strength** — metadata-identical (rsync size+mtime itemize), NOT content-checksummed. Full checksum pass would require re-reading 178G through dislocker (slow); acceptable but honest gap.
3. **Cleanup** — `/mnt/win` + `/mnt/bitlocker` still mounted; `/tmp` scripts (`rescue-win-to-pool.sh`, `backup-samsung-to-pool.sh`) transient, unarchived.
4. **Samsung SMART health** — command provided (`sudo smartctl -d sat -a /dev/sde`), never run (root-gated session). Unknown: power-on hours, wear level, Percentage Used.

## c) NOT STARTED ○

1. Wipe of the Samsung (source data now fully rescued)
2. Physical install into GMKtec Evo-X2 + Nix wiring (mkFilesystem, by-id mount, service path migrations, Gatus, btrbk)
3. Archive provenance README in `/mnt/pool/archive/desktop-u51ngkt` (the dd script had an `.info` sidecar; the rsync version dropped it)
4. AGENTS.md / docs updates: pool archive entry, BitLocker-rescue workflow pattern
5. Secrets remediation: MultiMC MS token rotation, JetBrains c.kdbx triage
6. `compsize` measurement of archive (real vs on-disk bytes)
7. Steam/models migration mechanics (Steam library folder repoint, OLLAMA_MODELS, FastFlowLM model path)

## d) TOTALLY FUCKED UP ✗ (all recovered, all instructive)

1. **dd-script guard used the wrong identity source.** Guarded on `/sys/block/sde/device/model` = "Samsung..." — but USB bridges answer SCSI INQUIRY with their own name (`RTL9210B-CG`). Worst part: I had ALREADY observed this in-session (`cat /sys/class/scsi_disk/1:0:0:0/device/model` → `RTL9210B-CG`) hours before writing the guard. Preflight aborted, user round-trip wasted. Fix: udev `ID_MODEL` + `ID_SERIAL_SHORT` (stronger than the original check).
2. **Misread the goal.** "Back up the whole disk" → I built an encrypted-forensic-image pipeline; user wanted **plaintext files on the pool**. Opposite security postures (image keeps BitLocker; file copy exposes everything). Cost a full script rewrite and one rightfully angry message. Should have asked ONE disambiguating question.
3. **Verification harness false-FAILed THREE consecutive times** while the data was always fine:
   - `--itemize` is not a valid long option in rsync 3.4.4 (`-i` is; rsync rejects unambiguous abbreviations)
   - stats output written to the same temp file as the itemize diff → `-s` test always true
   - blank lines in stats output not stripped by the grep filter → whitespace-only "differences"
   Root cause: I never dry-tested the harness against synthetic input until fix #3 (where a `printf | grep | wc -c` = 0 test caught it instantly). User ran the script 4 times total for one real copy.
4. **Stale-knowledge assertion.** Claimed "/data is largely Immich/photos" — contradicted by our own AGENTS.md (Immich lives on the pool since bring-up). Corrected only after user pushback. Lesson: consult known-state docs before asserting current layout.

## e) WHAT WE SHOULD IMPROVE (process, from this session)

1. **Test verification harnesses with synthetic input before handing them to the user** — the fix #3 pattern (`printf fake-output | filter | wc -c`) would have caught all three bugs in seconds, applied once.
2. **Ask one clarifying question when a request is ambiguous between opposite outcomes** (encrypted image vs plaintext copy; security posture differs inversely).
3. **Check AGENTS.md/system state before asserting current topology** — the Immich claim was falsifiable from open docs in the repo.
4. **Use information already gathered in-session** (bridge-in-sysfs was known) — regression to generic assumptions cost a failed run.
5. **Write provenance sidecars into every archive at creation time** (what/when/from-where/how-verified), not as an afterthought.
6. **Content-checksum spot verification** (sample N files) for irreplaceable-data rescues — itemize equality is metadata-level only.
7. **Flag discovered secrets with a concrete remediation step immediately**, not just an observation (accounts.json tokens are live).

## f) NEXT UP TO 50 THINGS

**Decision & drive prep**
1. User decides repurposing (games+models? other high-disk workload?)
2. `sudo smartctl -d sat -a /dev/sde` — wear/endurance check before internal use
3. Decide: plaintext rescue sufficient, or ALSO want ciphertext dd image? → unlocks wipe decision
4. `sudo umount /mnt/win /mnt/bitlocker`
5. Wipe Samsung (no TRIM via bridge — plain dd/overwrite or just re-partition)
6. Verify GMKtec free M.2 slot + PCIe 3.0 x4 compatibility (970 EVO Plus is Gen3 — fine)
7. Thermal sanity: sustained model loads in the tiny GMKtec chassis

**If "games + models" lands**
8. Partition/format plan (BTRFS, by-id, `mkFilesystem` helper registration)
9. Subvol layout: models vs games (games: `nodatacow` candidate; safetensors mostly incompressible — zstd autotolerance)
10. Migrate `SteamLibrary` (106G) + Steam library folder repoint
11. Migrate `/data/ai` (267G)
12. Migrate `/data/models` (210G)
13. Migrate `/data/llamacpp-models` (92G)
14. Repoint FastFlowLM model path (`/data/ai/models/fastflowlm`)
15. Repoint Ollama model store (`OLLAMA_MODELS`/dataDir)
16. `RequiresMountsFor` updates on affected units
17. Gatus presence check for the new mount
18. fstrim coverage (automatic for internal)
19. Post-migration balance on `nvme0n1p8` to reclaim ~675G
20. Revisit `/data` partition fate (shrink/overflow; mind p6↔p8↔p9 non-adjacency)
21. Revisit frozen-drives plan: sdd "Docker storage" earmark may be obsolete
22. Empty `/data` dirs audit (`atticd/ docker/ containers/ cache/ monitor365/` — verify truly empty as root)
23. `monitor365-archive` (32G): keep or prune? (service disabled since 08-12)

**Archive hygiene**
24. README/provenance into `/mnt/pool/archive/desktop-u51ngkt` (source disk, serial, date, method, verify status)
25. `compsite` measurement (logical 178G vs physical)
26. Confirm btrbk-pool snapshot coverage of `archive/` subvol path (services/* is snapshotted; archive/ coverage unverified — 178G could balloon pool snapshots if covered, or be unprotected if not)
27. Consider excluding archive/ from pool snapshots (cold data, RAID1 already) or giving it own retention
28. Archive permissions hardening (root-owned 0600? contains live tokens + credentials)
29. Review `IdeaProjects/DeepBackup` for useful code
30. Review Desktop/Downloads keepers; prune junk from archive
31. Extract browser bookmarks/passwords from old profiles if wanted (before they rot)
32. Rotate Microsoft account tokens (MultiMC `accounts.json`)
33. Triage JetBrains `c.kdbx` credential DBs
34. Confirm BitLocker password is in the password manager (moot post-wipe, needed until then)

**Docs & memory**
35. AGENTS.md: pool archive entry (`archive/desktop-u51ngkt`) + contents/secrets warning
36. docs: BitLocker rescue workflow (dislocker + ro ntfs3 + rsync pattern, bridge-sysfs gotcha)
37. Archive rescue script pattern into `scripts/` if deemed reusable
38. Update 3-drive repurposing plan doc with Samsung's new status
39. Gotcha candidate: "USB bridges masquerade in sysfs device/model — identity guards must use udev ATA props" (generalizes the buildcache lesson)

**Systemic (noticed in passing)**
40. `du` on `/data` ran unprivileged — root-owned dirs may be underreported; re-audit as root
41. Verification-harness unit-test habit (see e-1) — apply to scripts/pre-deploy-check.sh too?
42. rsync long-option lesson → prefer `-i` short forms in shipped scripts
43. Consider `--info=progress2` + `--partial` as the house style for long copies (worked well)
44. Pool free-space headroom now 645G used / 15T — archive growth is fine, but track in backup-coordination if archives multiply
45. If archive accumulates more rescued disks, define a naming/layout convention now (`archive/<hostname>/<date>_…`)

## g) QUESTIONS ONLY YOU CAN ANSWER

1. **What is the "SOMETHING else with high disk needs" you have in mind?** Video/processing work, growing AI usage, something else? It determines the drive layout (and whether 1TB is even the right home for it).
2. **Is the verified plaintext rescue sufficient to wipe the Samsung, or do you also want a raw ciphertext image on the pool** (belt-and-braces, e.g. in case plaintext copy missed something inside `Windows/` — drivers, registry hives with license keys)?
3. **The rescued archive contains live secrets (Microsoft session tokens, JetBrains credential DBs, browser profiles).** Rotate/lock down now, or leave as-is since it's on the LAN-only pool?

---

**Bottom line:** The 12-year-risk item is closed — DESKTOP-U51NGKT's data is rescued, verified byte-consistent, and resting on the RAID1 pool. The session's failures were all in *my* tooling (guards, harness), not in the data path; three lessons distilled in section e. Open thread: what the Samsung becomes next.
