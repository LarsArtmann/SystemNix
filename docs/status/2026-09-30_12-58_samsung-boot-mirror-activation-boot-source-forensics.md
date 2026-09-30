# Status Report — Samsung Boot-Mirror Activation + Boot-Source Forensics

**Date:** 2026-09-30 12:58 CEST
**Session scope:** interactive advisory session (crush, SystemNix repo) — boot-chain investigation + owner-run Samsung boot-mirror cutover prep and execution. No Nix builds, no deploys, no config changes by the agent.

**Companion edits (this session, harvested):** `TODO_LIST.md` (storage queue row updated), `docs/todo/storage.md` (row 33 updated to ACTIVATED + [blocked:user]), `AGENTS.md` (Samsung 2nd-boot-disk section: activation state + boot-source forensics method).

---

## Session narrative

The owner asked "how can I figure out from which drive we booted?" on a box with a two-ESP setup (QLC `/boot` + Samsung `/boot-mirror`) that had been running the boot-mirror deploy since 2026-09-19 without ever actually booting from the mirror.

1. **Boot-source forensics.** Decoded the `LoaderDevicePartUUID` EFI variable → PARTUUID `846277c0-2119-4c58-9cf0-729b96731766` = `nvme0n1p7`, the QLC ESP. **Trap found and documented:** the variable's payload is UTF-16 *text*, not a binary GUID — a naive `bytes_le` GUID decode produces garbage (`00340038-0036-…`). Correct decode: `d[4:].decode('utf-16-le')` (4-byte attributes prefix, then the string). Cross-checked against `lsblk -o NAME,PARTUUID,MOUNTPOINTS`.
2. **`bootctl status` field explanations** (owner questions): `Measured UKI/OS` = TPM measured-boot indicators, correctly `no` on this box (no UKI, Secure Boot off, nothing PCR-sealed); `Boot into FW` = `systemctl reboot --firmware-setup` capability.
3. **Advisory for the cutover:** identified `nix run .#boot-mirror-activate` (flake.nix:3056 → `scripts/boot-mirror-activate.sh`) as the sanctioned path, then **read all 90 lines of the script before recommending it**: it mutates ONLY EFI NVRAM (entry + BootOrder), gates on mirror-mounted + `bootctl is-installed`, is idempotent (PARTUUID+loader-path match), self-verifies the order after write, and has trivial rollback. Verdict delivered: safe to run live.
4. **Owner executed (pasted transcript):**
   - `nix run .#boot-mirror-activate` → success. Entry `Boot000C` already existed (09-19 era) but **BootOrder had never led with it** — this run applied `BootOrder: 000C,0001,…` (Samsung first, QLC fallback; `BootCurrent: 0001` until reboot, i.e. this session still booted QLC).
   - `git sync` → pushed 7 accumulated commits (`cf1bd0b4..b9310217`) — the local-ahead backlog is cleared.
   - `nix run .#pre-reboot-check` → **22 passed, 3 warnings, 0 failed**, including §11 boot-mirror checks ALL GREEN **at FAIL grade** (mirror first, loader installed, tree identical). Verdict: SAFE TO REBOOT.

Notable warnings from §9 (all pre-existing, none introduced here): 3 failed units; `inboxclean-sync.service` failed WITH changed unit files → next deploy will exit-4 over it (deploy.sh reset-failed recovers); smoke-fail baseline 5 known FAILs, 0d old.

---

## a) FULLY DONE

| Item | Evidence |
|---|---|
| Boot-source diagnosis method + live answer (this boot = QLC `nvme0n1p7`, not the Samsung mirror) | efivar decode + `lsblk` match, this report §narrative |
| `LoaderDevicePartUUID` UTF-16 decode trap documented | AGENTS.md → Samsung 2nd boot disk section (edited this session) |
| Safety verification of `boot-mirror-activate` before recommending | full read of `scripts/boot-mirror-activate.sh` (90 lines); gates/idempotence/rollback confirmed |
| Samsung mirror activation EXECUTED (owner-run) | `BootOrder: 000C,0001,…` in pasted efibootmgr output |
| Pre-reboot boot-chain gate green at the strictest grade | pre-reboot-check: 22 pass / 0 fail; §11 all green at FAIL grade |
| Repo backlog pushed | `git sync`: `cf1bd0b4..b9310217 master -> master` |
| Memory + TODO surfaces updated (no drift) | AGENTS.md, TODO_LIST.md, docs/todo/storage.md edits this session |

## b) PARTIALLY DONE

| Item | Works now | Remains | Blocker | Effort |
|---|---|---|---|---|
| **Samsung 2nd-boot-disk cutover** | NVRAM ordered Samsung-first; §11 FAIL-grade green; sync unit keeps mirror byte-identical | the actual reboot + post-reboot verification (BootCurrent `000C`, `LoaderDevicePartUUID` = `023f66c0…`) | owner-decided reboot moment | S |
| **InboxClean grant-health chain** (surfaced via §9 warning, pre-existing) | upstream auth fix + dashboard banner landed in InboxClean master (unpushed) | push → flake lock bump → deploy; PLUS the human re-consent ceremony (Cloud Console "In production" flip, browser consent) | upstream push is agent-banned; re-consent is human-only | M |
| **Root cause: NVRAM BootOrder never held the Samsung** | mitigated — activation re-applied + §11 now FAIL-grade so drift is gated | WHY the 09-19-era entry never led BootOrder (firmware reset vs `-o` never run) | cannot inspect firmware/NVRAM history from OS | S (if owner remembers) |

## c) NOT STARTED

| Item | Why not started | Still wanted? |
|---|---|---|
| Post-reboot verification pass | blocked on the reboot itself | yes — closes the cutover |
| Boot-menu hygiene (13 EFI entries: inactive `VenHw` stubs `0002/3/5/7-000A`, Windows Boot Manager residue `0000`; active set is only `0001/0004/0006/000B/000C`) | cosmetic; needs root `efibootmgr -b -B` (agent-banned) | low priority, owner call |
| Booted-ESP boot-time metric (`booted_esp_is_mirror` from `LoaderDevicePartUUID`) | post-reboot one-command verify covers the immediate need; a permanent metric is a nice-to-have | candidate, not committed |

## d) TOTALLY FUCKED UP

**Nothing from this session.** Honest note: the nearest real breakage is pre-existing and user-gated —

- **`inboxclean-sync.service` failed on the live box** (§9 warning today; exit-75 `invalid_grant` drain-loop class since 2026-09-04, main Gmail token revoked; cursor frozen at 5152620). Severity: keeps OnFailure paging AND sets up the **next-deploy exit-4 hazard** (failed unit + changed unit file). Mitigation exists and is fully tracked: `sudo mv /var/lib/inboxclean/token.json …expired-*` unblock + re-consent runbook (docs/todo/services.md row, updated 2026-09-30 with the phantom-`already authenticated` upstream fix).
- **Process gap found (now closed):** the 09-19 deploy queue recorded the mirror as deployed-but-unactivated and today's earlier re-verification correctly identified `BootOrder` still leading QLC — but nothing had ever caught that the *activation half* sat unexecuted for 11 days. §11's grade escalation (WARN→FAIL once first) only guards the post-activation future; the pre-activation gap relied on the queue row. Acceptable for an owner-gated step, worth remembering for future "deployed + owner-step-pending" patterns.

## e) WHAT WE SHOULD IMPROVE

1. **Verify-before-recommend for owner-run commands worked well and should stay the standard** — reading all 90 lines of `boot-mirror-activate.sh` before saying "safe to run live" turned a trust question into a 30-second evidence answer.
2. **Owner-gated half-deployed features deserve a "state" marker in AGENTS.md, not just queue rows** — the Samsung section described the mechanism but not the execution state; today's edit fixes it. Pattern: after any owner-run step lands, update AGENTS.md the same session.
3. **Boot-chain forensics knowledge was tribal** — the `LoaderDevicePartUUID` UTF-16 trap cost one wrong decode attempt; now captured in AGENTS.md so the next session one-shots it.
4. **§9's "changed unit files on failed unit" warning is doing its job** — it converted the inboxclean mess into a visible exit-4 predictor. Keep treating it as a pre-deploy to-do, not noise.

## f) Up to 50 things to get done next (session-grounded; ~24, impact-ranked)

> Scoped per instruction: items observed in THIS session's run or already in project context. A literal 50-item list would require repo-wide research beyond this session's mandate. Items marked ✓ are harvested into the TODO system this session.

| # | Task | Impact | Effort | Category |
|---|---|---|---|---|
| 1 | Owner reboot into the Samsung mirror (at will; gate is green) | High | S | Owner step |
| 2 | ✓ Agent post-reboot verify: `LoaderDevicePartUUID` = `023f66c0…`, `BootCurrent` = `000C`, §10 gcroot flips to gen 808 (folded into storage.md row) | High | S | Verification |
| 3 | InboxClean pre-deploy unblock: `sudo mv /var/lib/inboxclean/token.json …expired-<date>` then re-consent `main` (kills the §9 exit-4 hazard + the OnFailure loop) | High | S | User ceremony |
| 4 | InboxClean deploy chain: push upstream (`1540a56`/`d23c48a`) → `nix flake lock --update-input inboxclean` → deploy → verify `gmail_aggregate` word | High | M | Deploy |
| 5 | Flip Cloud Console consent screen to "In production" BEFORE re-consenting (7-day token bomb) — part of #3, called out separately because order matters | High | S | User ceremony |
| 6 | Answer the NVRAM question: firmware reset between 09-19 and today, or `-o` never ran? Determines whether a persistence guard is needed | Medium | S | Investigation |
| 7 | Refresh the 5-entry smoke-fail baseline at the next deploy (0d old, reboot/deploy-clearable) | Medium | S | Cleanup |
| 8 | Prune dead EFI entries (`0000` Windows residue, `0002/3/5/7-9/A` inactive VenHw stubs) — keep `000C/0001/000B` minimum | Low | S | Cleanup |
| 9 | (Candidate) boot-time `booted_esp_is_mirror` metric — only if post-reboot verify shows repeated interest | Low | M | Feature |
| 10 | Known-tracked, untouched today: Wise SCA re-approval pending (deploy smoke red on the counter) — user OTP via dashboard flow | High | S | User ceremony |
| 11 | Known-tracked: `NIX_GITHUB_RO_TOKEN` secret still absent — weekly flake-update bot + CI stay dark on 32 private `github:` lock nodes | High | S | Infra |
| 12 | Known-tracked: Resend dashboard "Verified" confirmation for `larsartmann.cloud`, then non-owner delivery probe (closes mail-relay + pocket-id SMTP go-lives) | High | S | User step |
| 13 | Known-tracked: offsite-borg go-live inputs (StorageBox host/user + recovery-copy policy decision) — the 3-2-1 third leg is dormant | High | M | Owner decision |
| 14 | Known-tracked: /data EIO inode P0 — every nightly btrbk-data send aborts on it | High | L | Data repair |
| 15 | Known-tracked: scrub timers `Persistent=false` + serialization (freeze-#7 queued follow-up) | High | M | Stability |
| 16 | Known-tracked: deploy-authority decision (queue-fired vs user-manual `nix run .#deploy`) — blocking 3+ closeouts | High | S | Owner decision |
| 17 | Known-tracked: hot-db Phase-2 waves (gatus → dnsblockd → pocket-id → browser-history → discordsync), vehicle armed | High | L (windows) | Storage |
| 18 | Known-tracked: crush-hot-db interim module fold into ratified `services.hot-db` | Medium | M | Storage |
| 19 | Known-tracked: Samsung 2-device buildcache btrfs merge (awaiting maintenance window) | Medium | M | Storage |
| 20 | Known-tracked: Context7 key still LIVE in public history — rotation is the real fix (purge push is held by decision) | High | S | Security |
| 21 | Known-tracked: geometrikks MaxMind keys (geo-degraded banner since native migration) | Medium | S | User step |
| 22 | Known-tracked: dmarc@larsartmann.cloud mailbox creation, then `services.dmarc-monitor.enable` flip (final mail-go-live step) | Medium | M | User step |
| 23 | Known-tracked: architecture-catalog go-live (runner PATH gen must deploy first, then setup script + token paste) | Medium | M | Go-live |
| 24 | Known-tracked: InboxClean Turso plan decision (upgrade vs permanent local-only) — standing red Gatus check by design | Low | S | Owner decision |

## g) Questions I cannot answer myself (3)

1. **When do you want the reboot?** Everything downstream (post-reboot verify, gcroot flip, the §11 FAIL-grade regime going live in practice) keys off this moment, and only you can pick it.
2. **Do you know why NVRAM BootOrder never led with the Samsung entry despite it existing since ~09-19** — did any firmware update / CMOS clear / BIOS fiddling happen since, or was today the first time the activation's BootOrder step actually executed? If something resets NVRAM, we should know before trusting the mirror as primary.
3. **Shall I prep the full InboxClean unblock + deploy chain as the next dispatch** (mv-token unblock instructions + upstream push checklist + lock bump + deploy), or do you want the reboot to settle first? It needs your browser/Google login for the consent half either way.

---

## Harvest disposition (AGENTS.md TODO-system rule)

- **Harvested (edited this session):** TODO_LIST.md storage queue row + docs/todo/storage.md row → updated to "ACTIVATED 2026-09-30, owner reboot + post-reboot verify pending", tag `[blocked:deploy]`→`[blocked:user]`, with the verify recipe and the UTF-16 trap inlined.
- **Deliberately not harvested:** #3/#5/#10-24 are pre-existing tracked rows (docs/todo/services.md, storage.md, AGENTS.md persistent nags) — this session only surfaced fresh evidence for inboxclean (§9) and adds nothing new to their asks. #6-#9 are recorded inside the updated storage.md row / this report; boot-menu pruning and the optional metric are owner-call candidates, not [ready] agent work (root required / speculative value).
- **Memory:** AGENTS.md Samsung 2nd-boot-disk section updated with the activation state + forensics method.

*Report generated per status-report skill; format override honored: Markdown (`.md`) per explicit user instruction instead of the skill's default styled HTML dashboard.*
