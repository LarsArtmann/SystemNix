# systemd-appd — NixOS / SystemNix Review (PRO / CONTRA)

**Date:** 2026-10-09 · **Kind:** technology evaluation, decision-support · **Verdict: WATCH — do not adopt, do not build against it yet.** Nothing actionable for SystemNix today; re-evaluate when the revisit triggers in §7 fire.

## Summary (TL;DR)

- **systemd-appd is an unmerged draft PR** (systemd#43885, opened 2026-09-24 by Adrian Vovk, milestone v263, still `[DELETEME]`-carrying draft state). It is **not in any systemd release** — latest release is v262 (2026-09-22); evo-x2 runs **261.3**.
- It is a **per-user app-identity + entitlement-metadata daemon** for graphical sessions: apps self-register over Varlink, PID 1 tags their cgroup with a `user.app_id` xattr, and session services (PipeWire, portals, D-Bus, compositors) query/synchronize per-app runtime permissions. It is the plumbing layer for **Flatpak-Next / Flatpak 2.0** sandboxing.
- It is **NOT an app installer, app store, image format, or container runtime** — despite the "appd" name inviting confusion with `portabled`/`sysext`. It does not touch packaging or distribution at all.
- **NixOS integration: zero.** No nixpkgs package/module/issue/PR mentions it (verified 2026-10-09 via `gh search`). Nothing for SystemNix to consume, and no current SystemNix pain it solves (single-user niri/DMS desktop, no Flatpak in the tree, Docker-adjacent questions settled by the 2026-10-08 removal).
- **Why watch instead of ignore:** it is the first credible, launcher-agnostic mechanism for per-app permissions on the free desktop, and — unlike today's Flatpak-centric portal app-ids — its identity layer would also cover **natively-packaged (nix/HM) apps** launched in `app-*` units. If PipeWire/portals/Flatpak 2.0 adopt it, it becomes the missing piece for desktop sandboxing UX on NixOS too.

## 1. What it IS — and is NOT

| Claim                                        | Verdict                                                                                                                                            |
| -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| App identity service for graphical sessions  | **Yes** — "a centralized place to keep track of the user's apps… allows all session services (dbus, pipewire, portals, Wayland compositors) to reliably identify apps and learn about their current permissions" (PR body) |
| Per-app runtime permission/entitlement store | **Yes** — metadata on top of identity; enforcers (e.g. PipeWire) are told about changes and must apply them before `SetPermissions()` returns       |
| User-session scoped                          | **Yes** — `units/user/systemd-appd.service.in`, `PartOf=graphical-session.target`, `Slice=session.slice`. No system-level daemon, no server relevance |
| Packaging / install / update mechanism       | **No** — it explicitly does not install, package, or update apps (common misconception given the name)                                              |
| Container/image runtime (like portabled)     | **No** — unrelated to portable services, sysext, confext, sysupdate despite the `-d` naming family                                                  |
| Merged / released                            | **No** — draft PR #43885, milestone v263 (RC1 2026-11-19, due 2026-12-17). No NEWS entry, no man page yet                                            |

## 2. Verified fact base

All primary-source verified 2026-10-09 (gh API against systemd/systemd unless noted):

- **PR #43885** "New component: systemd-appd" — OPEN **draft**, author `AdrianVovk`, created 2026-09-24, labels `tree-wide` + `claude-review`, milestone **v263** (RC1 2026-11-19 … RC4 2026-12-10, due 2026-12-17), 30 `COMMENTED` review threads open, debug commit (`[DELETEME] [SKIP] Debug stuff`) still in series.
- **Depends on #43850** "io.systemd.Unit.AddTransient: Add support for scopes and unit dependencies" — also OPEN, also v263: Varlink `StartTransient` gains scopes + unit deps (core-surface change, so the review blast radius is bigger than one daemon).
- **Upstream releases:** latest = **v262** (2026-09-22). `appd` appears **zero** times in NEWS (grep over the full 1.27 MB file). No man page in the PR file list (only `DESKTOP_ENVIRONMENTS.md` doc refreshes).
- **File surface of the PR:** `src/app/{appd-manager,appd-instance,varlink glue}` · `src/shared/varlink-io.systemd.AppInstance{,Monitor}.c` · `units/user/systemd-appd.service.in` · drop-ins `units/user/app-.service.d/10-defaults.conf` + `app-.scope.d/10-defaults.conf` · core changes (`src/core/cgroup.c`, `unit-name`, `varlink-unit`) · integration test `TEST-96-APPD`.
- **Local state (evo-x2):** systemd **261.3** (`/nix/store/l5hiab…-systemd-261.3`), nixpkgs lock `a7868a7` (2026-10-04). No appd binary anywhere; `portabled`/`sysext` present as expected.
- **NixOS:** `gh search issues --repo NixOS/nixpkgs "systemd-appd"` and `"appd flatpak sandbox"` → **zero results**. No module, no packaging, no discourse thread found.
- **Ecosystem demand (secondary, verified fetch):** Phoronix 2026-10-02 ("Out For Review…"; component originally planned ~a year earlier by Flatpak developers for Flatpak-Next/2.0); third-party `Kraftland/portable` explicitly blocks Portal support on appd landing.

## 3. Mechanics (as designed in the draft)

1. **XDG app unit naming convention** (`DESKTOP_ENVIRONMENTS.md`, refreshed by this PR): desktop launchers place apps in `app-<appid>@…` user `.service`/`.scope` units; a `.desktop` opt-out escape hatch exists for short-lived/self-moving processes. Ship defaults: `CollectMode=inactive-or-failed` for scopes, terminate-with-session, default stop timeout so apps can't hold logout hostage.
2. **Identity tagging in the kernel, not in string parsing:** units following the convention get a **`user.app_id` xattr on their cgroup**, set by PID 1 — observers read identity off the cgroup without IPC or unit-name/alias parsing.
3. **Registration:** apps (or whatever exec()s into them) register at startup via the **`io.systemd.AppInstance` Varlink interface**; appd verifies the caller actually runs in a convention-compliant unit.
4. **Metadata:** appd stores/retrieves per-instance runtime permissions & entitlements (`Query()` / `SetPermissions()`), so session services can decide whether to grant privileged actions.
5. **Race-free enforcement:** a dedicated notification mechanism (sockets in a drop-in directory, deliberately NOT plain Varlink subscriptions) lets enforcers acknowledge — `SetPermissions()` returns only after monitors (e.g. PipeWire for a camera grant) applied the change, closing the grant-then-denied race.
6. **Daemon shape:** `Type=notify`, heavily hardened (NoNewPrivileges, MemoryDenyWriteExecute, PrivateNetwork, `AF_UNIX`-only, `@system-service` syscall filter) — close to the SystemNix `lib/systemd` hardening defaults, which is a good sign for module authoring later.

## 4. Maturity & timeline

- Draft, 15 days old at review time, core-touching dependency also unmerged; review comments still finding assert-class bugs (e.g. abort-on-missing-job-object in a pending `Register()`).
- Daemon state is **in-memory only** — restart loses the registry (early code; persistence story undecided).
- Best case: merged for **v263** (due 2026-12-17) → nixpkgs/unstable carries it weeks-to-months later → consumer adoption (PipeWire/portals/Flatpak 2.0/DMS launchers) is the real gate, historically 1–2 release cycles behind. Realistic "useful on NixOS": **2027+**.

## 5. NixOS integration status (what adoption would need)

Nothing exists today. When it lands, the chain is:

1. **nixpkgs systemd**: enable the meson option, ship the user unit + drop-ins (pattern: how `systemd-portabled`/user units already ship).
2. **NixOS module**: an option to enable appd + install the `app-*` drop-ins into the user environment (low complexity; the unit is self-contained).
3. **Home Manager / launcher**: the desktop launcher (for SystemNix: DMS) must spawn apps as `app-<id>…` units per the XDG convention — this is where the real integration work sits, and it is upstream (DMS/niri ecosystem), not NixOS.
4. **Consumers**: PipeWire / xdg-desktop-portal / Flatpak 2.0 releases that actually query `io.systemd.AppInstance`. Without these, the daemon is inert.

## 6. PRO / CONTRA

### PRO

- **Solves a real, long-standing fragmentation problem.** App identity on the free desktop today is a mess of Flatpak app-ids, portal app-ids, window `app_id`s, and cgroup-name guessing. A cgroup xattr set by PID 1 is the most robust substrate possible (kernel-visible, works for any observer incl. non-systemd-aware code paths).
- **Launcher- and runtime-agnostic — covers native nix apps.** Identity attaches to any app launched in an `app-*` unit, not just Flatpak sandboxes. For NixOS this is the interesting part: declaratively-managed native apps could eventually get the same permission UX as Flatpak apps, closing a gap where NixOS desktop users today choose between "native but unsandboxed" and "sandboxed but Flatpak".
- **Race-free permission-change protocol.** The synchronized notify/ack design (enforcers confirm before the setter returns) is the correct shape; the camera-grant/PipeWire race it closes is a real bug class in today's portal flow.
- **Small, hardened, user-scoped surface.** One user unit, AF_UNIX-only, `PartOf=graphical-session.target`, no system daemon, no new packaging format, no kernel requirements beyond cgroup xattrs (btrfs/ext4 fine; note xattrs on some filesystems — e.g. naive NFS/FUSE setups — are a historical pain point, irrelevant to evo-x2's btrfs).
- **Right layering.** appd only establishes identity + metadata; enforcement stays with the services that own the resource (PipeWire for audio/camera, portals for files). No new permission brain, no broker-of-everything.
- **Ecosystem pull is real.** Flatpak 2.0 planning is the driver; portable-app tooling (Kraftland/portable) is already blocked on it. If it merges, adoption is likely, not speculative.
- **Server fleet: zero blast radius.** User-session-only; no interaction with any SystemNix server module, port registry, or the systemd-shape/eval-guard surface (AF_UNIX, PrivateNetwork — actually exemplary).
- **In-tree integration tests** (`TEST-96-APPD`) — a nixpkgs systemd bump would inherit upstream coverage rather than shipping blind.

### CONTRA

- **Unmerged draft with core-surface dependencies.** 30 open review threads, `claude-review` label, `[DELETEME]` commits, assert-class bugs still being found, and the prerequisite #43850 changes `StartTransient`/core Varlink. Design may shift materially or stall — building anything against it now means tracking a moving target.
- **No release, no consumers, no benefit today.** Earliest release v263 (~Dec 2026); PipeWire/portals/Flatpak 2.0 consumer adoption realistically 2027+. Until consumers exist, enabling appd costs a daemon and delivers nothing.
- **Zero NixOS packaging/module work exists.** First adopters pay the meson/unit-shipping/module tax for a feature whose payoff is downstream of other projects' adoption.
- **Threat model explicitly excludes unsandboxed apps.** Upstream commit: "our security model on the desktop makes no attempt to defend against unsandboxed apps, and sandboxed apps will not be allowed to edit their own cgroups." The `user.app_id` xattr and permission metadata are only as trustworthy as the app's sandbox. Native nix/HM apps are unsandboxed by default — the permission layer initially benefits Flatpak-style packaged apps, and the "permissions for native apps" upside arrives only if/when those apps opt into sandboxing (bubblewrap etc.).
- **In-memory state; restart wipes the registry.** Early-days limitation, but a durability/UX question that must be answered (persist where? declaratively? interaction with NixOS's imperative-runtime-state boundaries).
- **One more identity indirection to coexist with.** DEs/launchers/portals must migrate to (or dual-track) the XDG app-unit convention; the PR itself soft-deprecates its own earlier `<launcher>` convention element — evidence the conventions are still churning.
- **Single-driver patchset.** Adrian Vovk is effectively the sole author of a large series touching `core/` and `libsystemd` — review bandwidth and bus-factor risk on the critical path.
- **Declarativity tension (mild, honest scope note).** Runtime permission state is imperative session state; there is no declarative story yet. Fine for its scope, but NixOS integration should eventually be able to seed/pin permissions declaratively rather than only mutate them at runtime.

### SystemNix-specific fit

- **Desktop:** evo-x2 runs niri + DMS/Quickshell, single-user, **no Flatpak anywhere in the tree** (only an archived niri-session doc mentions it). No per-app permission pain exists today that appd would relieve.
- **Server:** irrelevant by construction (user-session daemon).
- **Not the Docker question.** The 2026-10-08 Docker removal settled app/runtime distribution for this fleet. appd is not a distribution mechanism and reopens nothing — important to state explicitly because the name suggests "app manager".
- **Nothing to build now.** No module to write, no eval-guard impact, no monitoring surface. The only correct action is the `[watch]` row (harvested, §8).

## 7. Decision & revisit triggers

**Decision: WATCH.** Re-run this review when ANY of:

1. PR #43885 (and #43850) merge into a tagged release ≥ v263;
2. nixpkgs ships a systemd carrying appd (check `NEWS` grep + `units/user/systemd-appd.service.in` presence in the store path);
3. a PipeWire or xdg-desktop-portal release actually consumes `io.systemd.AppInstance`;
4. Flatpak 2.0 or DMS-side launcher support for the XDG app-unit naming lands on this desktop.

At that point the evaluation question changes to: "do we want per-app permission UX for natively-packaged apps on the niri/DMS desktop, and does the launcher spawn `app-*` units?" — a desktop-domain decision, not an infra one.

## 8. Harvest record

- **`docs/todo/upstream.md`:** added one `[watch]` row (time-gated on the triggers above).
- **`TODO_LIST.md` (dispatch queue): deliberately not touched** — nothing `[ready]`/agent-actionable exists; the queue harvests only actionable one-liners by design.

## Sources

- systemd PR **#43885** (draft, v263) — body, commit messages, file list, unit file, review state (gh API, 2026-10-09)
- systemd PR **#43850** (dependency, v263 milestone schedule)
- systemd releases API: latest = v262 (2026-09-22); NEWS full-file grep: zero `appd` mentions
- Phoronix, 2026-10-02: "systemd-appd Out For Review To Centralize Tracking Of User's Apps" (+ 2025 prior coverage: planned by Flatpak devs for Flatpak-Next/2.0) — fetched 2026-10-09
- NixOS/nixpkgs issue search (`gh search`): zero hits — verified 2026-10-09
- Local: evo-x2 systemd 261.3 store path; nixpkgs lock `a7868a7` (flake.lock)
