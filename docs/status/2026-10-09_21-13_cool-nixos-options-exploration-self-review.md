# Cool NixOS Options — Exploration Answer + Claims Audit (Self-Review)

**Date:** 2026-10-09 21:13 (Friday)
**Session scope:** one exploration question — "What NixOS (advanced) options did we never look into that are cool?" — answered with a presence scan + 9-option proposal table. This report audits THAT answer only (per instruction: no unrelated research).
**Tree pin at start:** `5d4bb3be` (clean; auto-commit daemon active).
**Files touched before this report:** none (pure read/exploration session). Edits made by this report: TODO harvest only.

**Format note:** user explicitly demanded `.md` at `docs/status/<ts>_*.md`, overriding the status-report skill's HTML canonical; brutal-self-review's question set is folded into this single report instead of a separate `docs/reviews/` HTML file (single-report instruction).

**What the session did:** keyword presence scan of ~32 candidate NixOS options across the tree (`rg -il` loop), planning-layer pre-read (docs/, TODO_LIST, ROADMAP — no ratified plan contradicted), context verification of boot.nix/steam.nix hits, then a 9-row table of absent options (scx, bees, sunshine, waydroid/libvirtd, irqbalance, confinement, nix-index/plocate, nftables+lockKernelModules) with per-row why/caveat and a top-3 pick (scx, nix-index, sunshine). Correctly stayed in exploration mode — propose, not implement.

---

## a) FULLY DONE

1. **Absence claims for all 9 proposed options — solid.** For every table item the grep used the exact option name (`services.bees`, `scx`, `sunshine`, `waydroid`, `libvirtd`, `irqbalance`, `confinement`, `plocate`, `nftables`, …) — absence-verification was rigorous.
2. **Planning-layer pre-read honored** (2026-10-05 rule): candidates scanned against `docs/` (incl. brainstorming/planning), TODO_LIST, ROADMAP before proposing; only attic-related hits surfaced; no owner-ratified plan contradicted.
3. **Strong verifications in the second round:** hardware watchdogd confirmed (boot.nix:534-556, sp5100 TCO; `docs/runbooks/wdt-reset.md` exists); binfmt confirmed (boot.nix:150-158, `emulatedSystems` + `preferStaticEmulators = true`).
4. **Claims re-verified during THIS report's authoring** (fix-on-sight for my own answer):
   - `steam-config.enable = true` (platforms/nixos/system/configuration.nix:624) + `gamemode.enable = true` (modules/nixos/desktop/steam.nix:27-28) — my "gamemode already in" claim: **TRUE**.
   - `attic-config.enable = true` (configuration.nix:503-506) — my "attic cache already in" claim: **TRUE** (though at answer time it rested on a docs/todo mention, not config).
   - `CONFIG_SCHED_CLASS_EXT=y` on the LIVE kernel (`zcat /proc/config.gz`, uname 7.2.9) — scx is kernel-side usable: **TRUE**.
5. **Mode discipline:** exploration detected, options proposed with tradeoffs, nothing implemented, no tree edits before this report.

## b) PARTIALLY DONE

1. **The "already covered" intro line mixed evidence tiers.** At answer time: 3 claims verified (watchdogd, binfmt, gamemode-ish), 2 WRONG (see d.1/d.2), 1 doc-claimed-only (attic — since verified true). The line read as uniformly verified. All six are now resolved (see a.4), but the delivered answer carried the errors.
2. **Live-state verification rule (2026-10-05) half-applied:** docs were scanned, but the live system was never probed — the answer asserted kernel capability from version arithmetic ("mainline since 6.12, you're on 7.2"). The probe took one command and was only run during this report.
3. **Table caveats asymmetric in depth:** doctrine tensions correctly flagged (Docker-removal vs VM hosts; lockKernelModules vs net-vpn), but the bees caveat was materially incomplete (see d.3).

## c) NOT STARTED (deliberate — exploration mode, owner picks)

1. Any spec/module/eval-gate/implementation work for the 9 options.
2. file:line citations in the delivered table (only the follow-up scan had them).
3. sunshine-on-niri capture-feasibility check (backend compatibility).
4. Time-sync backend check — noticed `chrony` absent, then dropped silently instead of checking what IS in use (default timesyncd presumed, never confirmed).

## d) TOTALLY FUCKED UP (claim-quality; nothing destructive — zero file/deploy/config impact)

1. **"auto-optimise-store" listed as already-in. It is deliberately FALSE** — platforms/common/nix-settings.nix:45-49 disables it with a comment: per-build dedup churn violates the IO-storm/freeze doctrine. Root cause: keyword-presence grep misread as option-assignment. Ickier: the bees row simultaneously praised the repo's IO-storm discipline while this claim misstated its most direct expression.
2. **"earlyoom" listed as already-in. It was REPLACED** — boot.nix:470: "systemd-oomd (replaces earlyoom)". The keyword hit was a tombstone comment. Same root cause as d.1.
3. **bees caveat named the wrong hard constraint.** I warned about PSI churn and said "scope to a subvol" — but the Samsung hot subvols are `+C` (nodatacow), and bees CANNOT dedup nodatacow extents; a dedup target must be a CoW subvol. An owner following my caveat verbatim could point bees at a subvol where it silently no-ops.
4. **"Wayland-native capture under niri" (sunshine) — unverified capability claim.** Sunshine's Wayland capture (wlr-screencopy/KMS backend) vs niri's portal surface was never checked.
5. **scx "swappable at runtime, no reboot" stated as fact** — partially true for scheduler override, but asserted without ever running it here (kernel-side now verified; runtime BPF switch still untested).

**Pattern worth naming:** three recent incidents (2026-09-18 browser-history gate, 2026-09-29 count-claim, this) are all "assertion outran evidence" — the repo's own critical-rule family ("a 'verified' label must cover every fact asserted") exists for exactly this, and I enforced it strictly on the 9 ABSENT claims while letting the 6 "already-in" claims ride keyword greps.

## e) WHAT WE SHOULD IMPROVE

1. **Evidence-tier every claim in exploration answers** — mark tree-verified / doc-claimed / unverified, or verify before asserting. Cheapest discipline that would have caught d.1+d.2 before delivery.
2. **Presence-grep is a candidate filter, never proof.** "Already in" needs an assignment grep — and multi-line attrset awareness: `attic-config = { enable = true; }` spans lines 503-506, which my single-line `attic-config.enable = true` grep missed entirely (first grep returned nothing).
3. **Kernel/hardware capability claims need a live probe** (`zcat /proc/config.gz`, `lsmod`) or a nixpkgs kernel-config check before asserting usability — version arithmetic is not verification.
4. **Constraint completeness for storage tooling:** on this box, any dedup/scheduling suggestion must be checked against BOTH the PSI doctrine AND the physical subvol flags (CoW vs +C) before it reaches the owner.

## f) Next things (session-derived; harvested at authoring time per AGENTS.md rule)

**Resolved during this report's authoring (no queue entries needed):**

1. ~~verify gamemode/steam enabled~~ — TRUE (configuration.nix:624 + steam.nix:27-28)
2. ~~verify attic-config enabled~~ — TRUE (configuration.nix:503-506; multi-line attrset, first grep missed it)
3. ~~verify sched_ext kernel support~~ — TRUE (CONFIG_SCHED_CLASS_EXT=y, live kernel 7.2.9)

**Harvested → domain libraries (queue row only for the [ready] item):**
4. **[decision→stability]** scx pilot spec: default-off module, `scx_lavd` first, SigNoz A/B (IO-PSI/loadavg/interactive latency), one-boot reversible
5. **[decision→stability]** irqbalance: pre-measure current IRQ affinity spread (`/proc/interrupts`) before/after — bundle with the scx measurement window
6. **[watch→stability]** `systemd.services.<n>.confinement` pilot on ONE service — next tier past `harden{}`
7. **[decision→storage]** bees feasibility: CoW subvols ONLY (the `+C` hot subvols are undeduppable — d.3 correction), PSI-gated scan window, dry-run dedup estimate on `/nix` first; collides with the same doctrine that set `auto-optimise-store = false`
8. **[decision→desktop]** sunshine spec: security model first (LAN-only vs OIDC vHost), verify niri capture backend BEFORE any spec work
9. **[decision→desktop]** waydroid/libvirtd doctrine ruling: does the 2026-10-08 runtime-removal extend beyond container runtimes to VM hosts?
10. **[watch→desktop]** kanata/keyd system-level key remapping evaluation
11. **[ready→desktop]** `programs.nix-index` + `services.plocate` enablement (low-risk QoL; index build via timer)
12. **[decision→security]** nftables migration for the firewall
13. **[watch→security]** `security.lockKernelModules` — only after net-vpn (WireGuard module-load order) lands

**Deliberately NOT harvested:** time-sync backend check (c.4) — trivia, no owner value; revisit only if monitoring ever shows timestamp drift. 14 items total, not 50 — padding a session this small would have manufactured noise (skill guidance: large-N §f is brainstorm fuel, and every extra row costs a real dispatch downstream).

## g) Questions I cannot figure out myself

1. **Which (if any) of the top-3 to spec first** — scx pilot, nix-index/plocate, or sunshine? (Gates f.4/f.8/f.11.)
2. **Doctrine ruling:** does the 2026-10-08 Docker/runtime removal extend to VM hosts (libvirtd/waydroid), or was it strictly the container-runtime + image-registry surface? (Gates f.9; my table flagged the tension but only you can rule.)
3. **scx risk appetite:** acceptable to A/B a non-CFS scheduler on the stability-first box during calm weather (one-boot, runtime-reversible), or park it until the freeze families are fully closed? (Gates f.4.)
