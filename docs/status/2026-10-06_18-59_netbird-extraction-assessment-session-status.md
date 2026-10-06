# NetBird Extraction Assessment — Session Status

**Date:** 2026-10-06 18:59 CEST
**Session type:** advisory only — one architecture question answered, zero code changes, zero repo writes before this report
**Repos touched (read-only):** `pbx-artmann`, `SystemNix`
**Question under review:** *Both pbx-artmann and SystemNix have netbird — could it make sense to extract it into a dedicated flake-parts repo?*

---

## What this session actually did

| # | Action | Evidence base |
|---|--------|---------------|
| 1 | Dual-repo netbird grep (surface inventory) | 100+ matches per repo (both result sets truncated) |
| 2 | Read SystemNix client module in full | `modules/nixos/services/netbird.nix` (127 lines) |
| 3 | Read pbx control-plane module in full | `hosts/pbx/netbird.nix` (176 lines) |
| 4 | Flake-architecture verification | SystemNix `flake.nix` (flake-parts confirmed); pbx `flake.nix` inputs (no flake-parts — classic split `flake/*.nix`; sibling-input pattern: `telephony`, `mail`; `nixpkgs.follows = "telephony/nixpkgs"`) |
| 5 | Cross-repo input check | SystemNix has NO pbx-artmann flake input (eval-side coupling is via local checkouts only) |
| 6 | Size inventory of pbx netbird surface | 1012 lines total across 6 files (host modules 446, tests 566) |

**Verdict delivered: NO — not today.** Rationale: (1) the two surfaces are the SERVER and the CLIENT — disjoint nixpkgs option surfaces sharing essentially constants, not code; (2) the majority of each file is local doctrine (telephony-secrets / `pbx-alert@` vs `services.catalog` / `services.integration` / sops paths), which genericizing would only option-ize, growing net code; (3) one consumer each; (4) a third repo makes the F86 version-compat problem harder, not easier (own lockfile, cannot eval either consumer's closure); (5) phase-2 flipped the same day — mid-bring-up is the worst moment to move code. Cheaper alternatives offered: parameterize the hardcoded `evox2` client name when a second client joins; close F86 as already planned; revisit only if the provisioner outgrows one box. Noted pbx-artmann isn't flake-parts, so the extraction shape would be the telephony/mail classic-flake pattern anyway.

---

## a) FULLY DONE

1. **Complete role separation established** — pbx = control plane (`services.netbird.server` + `.relay` + Dex + nginx + alerts), SystemNix = client (`services.netbird-client` wrapper over `services.netbird.clients.evox2`). This is the load-bearing fact of the whole assessment and it is verified against source, not docs.
2. **Flake-architecture facts pinned** — SystemNix is flake-parts; pbx-artmann is a classic split flake; no cross-input exists between them; pbx pins nixpkgs through the telephony sibling.
3. **Recommendation delivered with explicit revival criteria** — not a flat "no": names the three events that would reopen it (second client host, provisioner growth, control-plane move off pbx — see §d.1 for the one I under-weighted).
4. **Extraction precedent check** — the fleet's actual extraction precedents (`nix-international-telephony`, `nix-email`) were distinguished from this case: those wrap substantial logic with their own assertions; these files are thin config over upstream nixpkgs modules.

## b) PARTIALLY DONE

1. **Evidence completeness: 2 of 7 pbx netbird files read.** The provisioner (`netbird-provision.nix` 70 lines, `netbird-provision-script.nix` 218 lines) and all three test files (`netbird-contract.nix` 187, `netbird-mock-mgmt.py` 206, `netbird-provision-selftest.nix` 155) were assessed from CHANGELOG/AGENTS prose + line counts, NOT source. For an advisory answer this was a defensible depth tradeoff — but see §d.2 for where it crossed into an unverified claim.
2. **"The cross-repo contract tests already live where they work"** — asserted from grep fragments of `tests/test-cloud-domain.nix` (lines 80–160 seen), never a full read. The SystemNix side was well-evidenced; I did not verify what the pbx `netbird-contract` check does and does not pin relative to the client side.
3. **"When a second client joins (workstation/macbook)"** — stated speculatively. Grep evidence that WORKSTATION is documented as a future mesh member (pbx CHANGELOG, netbird-deploy.md references) existed in this session's own output and was not cited or verified. Right conclusion, unsourced.

## c) NOT STARTED

1. **Any implementation** — none requested; the deliverable was the decision.
2. **F86 execution** (netbird version-compat eval grep, pbx closure server vs SystemNix client 0.80.0) — recommended as the cheap alternative, not run; it is an owned, tracked TODO row and was never this session's to execute.
3. **TODO_LIST harvest of this report's §f** — deliberately skipped: the user's instruction was report-then-wait. New §f items below are flagged as harvest candidates, not silently entombed.

## d) TOTALLY FUCKED UP

Brutal-honest list. None of these are believed to flip the recommendation — all of them weaken the evidence quality beneath it.

1. **I ignored the strongest counter-scenario sitting in my own first grep.** pbx TODO row 189: "RAM watch on cx23 (4 GB — telephony + mail + netbird + dex) after the next switch; decide the dedicated-VPS split if pressure shows." A dedicated-VPS split moves the control plane OFF pbx — which dissolves exactly the pbx-doctrine coupling (secrets path, `pbx-alert@`, shared nginx/cert, coturn coexistence) my "no" leaned on hardest, and would make a standalone control-plane module/repo materially more attractive. I read that row in the first tool result and never weighed it. The verdict survives only because the split is itself undecided (watch pending), but the report should have carried a "this decision has a live dependency" paragraph. This is the session's real miss.
2. **"The provisioner is the one genuinely reusable piece" — claimed without reading one line of it.** 288 module lines + 548 test lines judged from CHANGELOG descriptions. The claim was borrowed prose presented as assessment. (Doctrine: read before you judge.)
3. **"Zero shared lines of code" — overstated.** Verified only for the two files read. The provisioner demonstrably hardcodes the same class of constants as the client (grep hits: `larsartmann.cloud`, `192.168.1.53`, port family) — shared CONSTANTS exist today with no single owner. Correct phrasing: "no shared logic; a handful of duplicated constants."
4. **Recommended "follow the telephony/mail classic-flake shape" without `ls ~/projects`** — never confirmed those siblings exist locally or that no `nix-netbird` skeleton already exists. A ten-second check skipped in favor of inference from flake inputs.
5. **No `git status` on either repo before advising** — dirty working trees could have invalidated the file inventory the analysis rested on. (Both repos run an auto-commit daemon, which lowers but does not zero this risk.)

Self-review cross-check (per brutal-self-review): no ghost systems created (no code written); no scope creep (advisory only, no implementation); no lies beyond the three overstatements above, which §d.1–3 retract in place; the only genuine split-brain vector found is §d.3's constant duplication — pre-existing, not created by this session, and small (a cross-repo contract pin, not a repo, is the proportionate fix).

## e) WHAT WE SHOULD IMPROVE

1. **Cite-or-cut rule for futures:** any "when X joins / if Y grows" claim carries either a doc citation or an explicit `[assumed]` tag. This session violated it twice (§d.1, §b.3).
2. **Read-before-ranking:** files central to a verdict's supporting claims get read even when the verdict itself doesn't need them. Advisory ≠ exempt.
3. **Counter-scenario discipline:** when a grep surfaces an OPEN DECISION ROW that interacts with the question (the RAM split), weigh it or state in one line why it doesn't move the answer. Silently dropping it is how reports age badly.
4. **Proportionate fix instinct:** the session correctly resisted the big refactor, but should also have named the small real fix — the duplicated netbird constants across repos are the actual drift vector and a contract-test extension pins them for ~zero cost. Named here so it isn't lost.
5. **Environment hygiene:** `ls ~/projects` + `git status` are sub-second pre-flight checks for any cross-repo architecture answer; make them reflex.

## f) Things to get done next

Honest count: **3 new + 10 already-tracked.** Not padded to 50 — everything else noticed this session already owns a row in one of the two TODO lists, and duplicating rows here is the entombment anti-pattern.

**NEW (harvest candidates — no owning row exists yet):**

| # | Task | Impact | Effort | Status |
|---|------|--------|--------|--------|
| N1 | Write the RAM-split dependency note into the extraction decision: one paragraph in SystemNix's netbird planning doc stating the verdict reopens if the cx23 dedicated-VPS split lands (control plane off pbx dissolves the doctrine coupling) | Medium | 5min | 🔴 TODO |
| N2 | Pin the cross-repo shared netbird constants (management URL, port 51820, relay/STUN endpoint) in one contract check that evals BOTH local checkouts — closes the only real split-brain vector; natural extension of F86's mechanism | Medium | 30min | 🔴 TODO |
| N3 | [conditional] Parameterize SystemNix client module's hardcoded `evox2` (client name, unit name `netbird-evox2`, preStart target) → per-host option — prep only when a second client is actually committed (see §g Q2) | Low-Med | 1h | 🔵 BLOCKED (decision) |

**ALREADY TRACKED (noticed this session; owners elsewhere — do NOT duplicate):**

| # | Existing row | Owner |
|---|--------------|-------|
| T1 | F86 netbird version-compat eval grep (pbx server closure vs SystemNix client 0.80.0) + runbook pin note | pbx TODO §T17 |
| T2 | F87 post-enrollment probes (`netbird status` from evo-x2, tunnel DNS dig @192.168.1.53, Gatus eyeball) | pbx TODO §T17 |
| T3 | Post-flip verify: provisioner "converged" incl. router + `/api/peers` lists evo-x2 | SystemNix services.md |
| T4 | RAM watch on cx23 (4 GB) → dedicated-VPS decision — the §d.1 dependency itself | pbx TODO |
| T5 | roots-restore one-liner into netbird-deploy.md stage-first block | SystemNix services.md |
| T6 | secrets-preflight: derive expected-local names from generate.sh (cat-read secrets like `netbird_api_pat` invisible today) | SystemNix services.md |
| T7 | docs-gates: aggregate ALL 5 gates instead of first-exit | SystemNix services.md |
| T8 | Identify `/tmp/pbx-toplevel-*` deletion actor + inotify watch | SystemNix services.md |
| T9 | pbx AGENTS: staging-ritual gotchas (`--no-link` contradiction, symlink verify, cwd distrust) | SystemNix services.md |
| T10 | mail-SNI TLS note into mail-go-live.md (netbird-default cert on the mail vhost is not a missing mail cert) | pbx TODO |

## g) Questions I cannot figure out myself

1. **Is the cx23 dedicated-VPS split a live option or already dead?** The RAM-watch row frames it as "if pressure shows" — if you have privately already decided against ever splitting, the extraction question stays closed longer than my report implies; if it's likely, N1 should be upgraded from a note to planning input.
2. **Is a second mesh client (workstation? macbook? rpi3?) actually committed, or hypothetical?** I found references to WORKSTATION in the netbird-deploy context but no committed row — N3's prep is only worth queuing if this is real.
3. **Long-term ambition for the provisioner:** stay private plumbing, or be groomed toward a publishable sibling / upstream contribution? That decides whether its code should start accumulating repo-shape discipline (own README, tests as product, no pbx-relative assumptions) now, or stay a pbx-internal unit.

---

**Format note:** `.md` at an explicitly demanded `docs/status/` path (user instruction overrides the skill's HTML default; standing task-queue/dispatch precedent also `.md`). Report intentionally written to SystemNix per the established cross-repo root-docs pattern for netbird topics. No commit made — auto-commit daemon owns report commits per harness contract. §f NEW items are flagged as docs-health HARVEST candidates for the next maintenance pass.

---

## Appendix (2026-10-06 ~19:05 CEST — §g Q2 answered, same-session annotation)

The owner answered **Q2**: the mesh grows to **rpi3 + Lars's MacBook + (one day) KanyuNix** — the second-client question is no longer hypothetical, it is a three-client commitment. Verified this turn: rpi3 = in-repo SystemNix NixOS host; Lars's MacBook = `platforms/darwin` (and was ALREADY anticipated by net-vpn.md phase-2's "enroll MacBook + phone" — §b.3 of this report under-cited it, the intent existed); KanyuNix = separate darwin-only flake-parts repo for **Kanyu's** MacBook, status "Scaffolding" (formatting toolchain only, no nix-darwin/home-manager/secrets).

Consequences applied:

- **N3 BLOCKED→ready**: parameterization is committed work, rows routed to `docs/todo/services.md` → "netbird client-fleet expansion (2026-10-06 session)" (4 rows: parameterize, darwin enrollment mechanism decision, multi-peer keys + policy scoping for the non-Lars device, extraction trigger armed).
- **Verdict revised, not flipped**: extraction stays NO today (KanyuNix cannot consume anything yet), but the trigger is now concrete and named — the first cross-repo consumer. The darwin client code (Lars's MacBook) should be written extraction-clean because its second consumer is a different person's repo.
- **§d.1 upgrade**: the RAM-split scenario now compounds — a control-plane VPS split AND a growing client fleet both push toward netbird living outside pbx/SystemNix. Still not today.
- **§g Q3 (provisioner ambition) is now load-bearing**: multi-peer setup keys + policy scoping for a non-Lars device is the provisioner's first real growth; the private-plumbing-vs-publishable question decides how that growth is shaped.
- **Q1 (RAM split) still open** — unchanged.
