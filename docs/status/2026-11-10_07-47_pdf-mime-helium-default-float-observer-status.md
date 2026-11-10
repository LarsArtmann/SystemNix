# PDF MIME default (Helium) — session status + float-fight observation

**Session:** 2026-11-10 04:2x → 07:47 CET (single agent session, SystemNix)
**Trigger:** `open Plan-Jahresabschluss-2024-2025.pdf` failed with "no default application registered for 'application/pdf'"; owner asked "Internet Browser?"

**Scope line — what this report VERIFIED vs did NOT:**
Verified live this session: the MIME association query chain (`xdg-mime query default` with/without the niri prefix file), the actual document open (niri window title read via `niri msg --json windows`), the running generation and its build inputs (`readlink /run/current-system`, profile mtime, HM store `mimeapps.list` content), the lock/registry drift state across commits (`git show <rev>:flake/expected-locks.nix` family diffs), and float-register proof logs/roots in `~/.cache/lockfloat/` (00:05 → 07:19). NOT verified: the parallel float session's liveness/intent (inferred from commit cadence only), darwin-side PDF handling (one grep only — no mimeApps exists there), and anything about the other four sessions' work whose commits/logs I merely glimpsed (timesheets, SUPERB, money-flow, pim-sync — their reports own their state).

---

## a) FULLY DONE

1. **Owner question answered and effective: yes — internet browser.** No dedicated PDF viewer exists in any package list (zathura/okular/evince grep: zero); Helium is the established default-app pattern (owns text/html, images, videos in `mimeApps`) and Chromium's PDFium renders PDFs natively.
2. **Declarative fix landed:** `application/pdf` + `application/x-pdf` → `helium.desktop` in `platforms/nixos/users/home.nix:1071-1073` with section comment. Parse-checked (`nix-instantiate --parse`); committed (rode daemon commit `6614dbec9`, 04:32). Full eval verification is impossible while the lock-float gate is red (see d/§float) — parse + pattern-identity with sibling entries is the achieved proof level.
3. **Immediate-use bridge live:** `~/.config/niri-mimeapps.list` (desktop-prefixed, top xdg precedence, PDF-only entries). Both regular `mimeapps.list` paths are read-only HM store symlinks, so this was the only non-deploy mechanism. Verified: `XDG_CURRENT_DESKTOP=niri xdg-mime query default application/pdf` → `helium.desktop`.
4. **End-to-end acceptance test passed with the owner's actual file:** `/etc/profiles/per-user/lars/bin/open ~/Documents/Jahresabschluesse/.../Plan-Jahresabschluss-2024-2025.pdf` → niri window **"Plan-Jahresabschluss 2024 und 2025 – Artmann Technologies GmbH - Helium"** live on the desktop. Asserted WHICH entity served it, not just exit 0.
5. **Follow-up obligation harvested at authoring time:** shadow-file removal row in `TODO_LIST.md` + `docs/todo/desktop.md` (commit `baf369402`), including the exact post-removal verify command and the "deleting before the deploy re-breaks PDFs" trap.
6. **Load-bearing-ness of the bridge RE-verified at 07:45:** running system is gen-995 (profile mtime 03:24, predates this session's edit), and the deployed HM store `mimeapps.list` contains NO pdf lines — the shadow file is currently the ONLY reason `open *.pdf` works. Removal before a deploy carrying the home.nix change would re-break it.

## b) PARTIALLY DONE

1. **Declarative PDF fix — committed but NOT live.** Requires a deploy; every deploy is gated behind the in-flight lock-float repair (see d.3). Shadow file carries the behavior meanwhile.
2. **Shadow-file removal — queued but condition NOT met** (deploy hasn't landed; float proof still red at 07:19). This item stays open through no fault of this session's execution.
3. **Eval-level verification of the mimeApps change** — parse-only. The gate throws on any `nixosConfigurations.*` eval while lock ≠ registry, so the attr-level query (`home-manager.users.lars.xdg.mimeApps...`) could not run. The pre-commit/CI evals will exercise it on the next green tree.

## c) NOT STARTED

1. Post-deploy verification of the declarative path (xdg-mime resolving WITHOUT the shadow).
2. Darwin-side PDF default (macOS `open` uses LaunchServices; the darwin HM config has no mimeApps at all — relevance unassessed, one grep only).
3. Broader PDF-adjacent MIME coverage (`application/x-bzpdf`, `application/x-gzpdf`, `application/acrobat` — rare; deliberately not added to keep the mapping minimal).

## d) TOTALLY FUCKED UP (honest ledger)

1. **Direction misstatement in my end-of-turn summary (corrected here):** I told the owner "flake.lock rolled back 2026-11-07". Inverted. The lock floated FORWARD (nixpkgs `f4a03c00` dated 2026-11-07) past the registry's registered wave (`f9a75f41`, dated 2026-11-05 — also what running gen-995 uses); the registry is the STALE surface, the gate is doing its job. The corrected claim is recorded here; the wrong version lives only in chat, in no repo file.
2. **`rg -rn` — I hit the documented third-strike hook myself.** The rule is in AGENTS.md verbatim; muscle-memory grep flags overrode it. Hook caught it. Zero damage, one wasted round-trip.
3. **Edit-attempted a read-only symlink target:** tried to edit `~/.local/share/applications/mimeapps.list` without stat'ing it first (both mimeapps.list paths are store symlinks). The edit tool's read-first contract also forced one re-read. Should `ls -la` any dotfile before touching it.
4. **Commit subject 76 chars vs house limit 72** — rejected by hook, retried shorter. Count before committing.
5. **Float-direction theory loop (~5 probes before the decisive one):** I reconstructed the timeline through increasingly contrived hypotheses before running the OBVIOUS decisive probe (diff registry rows across `git show <rev>:flake/expected-locks.nix`). That diff, run second, would have collapsed the whole mystery in one call. Lesson re-confirmed: when two files disagree, diff each across commits before theorizing.

## e) WHAT WE SHOULD IMPROVE (from this session's observations)

1. **`open`'s failure message teaches only the slow path.** It says "Add it to xdg.mimeApps.defaultApplications in home.nix" — correct but deploy-gated. The desktop-prefixed override (`~/.config/<desktop>-mimeapps.list`) is a legitimate instant bridge and deserves a mention (with the "remove after deploy" caveat), or a `--now` flag that writes it.
2. **No eval-time guard that mimeApps defaults reference desktop files that ADVERTISE the MIME type.** `helium.desktop` declares only web MIME types; an explicit default association still routes `xdg-open`, but file managers will never OFFER Helium for PDFs (no "open with" entry). A lint could WARN when the default app's desktop file lacks the mimetype in `MimeType=` — with an allow escape hatch.
3. **The instant-bridge pattern is an acknowledged temporary split brain.** Two surfaces now define the PDF default (declarative config + shadow file, identical today). If home.nix's PDF target ever changes, the shadow silently wins. The TODO row says this; a recurring use of this pattern would deserve a repo rule (allowed-as-bridge + mandatory removal row), not ad-hoc judgment.
4. **Multi-surface vendorHash pinning made the float fight harder than it needed to be** (observed from proof roots): bank-sync's go-modules hash is pinned in more than one module surface, so fixing one surface re-fails the proof on the next. Single-sourcing FOD hashes per input would cut float-marathon cycles.
5. **Scope honesty in §f:** the user asked for up to 50 next items; this session legitimately noticed ~15. Padding the rest would be brainstorm noise — the list below is what was actually observed.

## f) NEXT THINGS (observed this session, honest count: 15)

1. **Remove `~/.config/niri-mimeapps.list` once a deploy carries the home.nix PDF mapping** — queued (`baf369402`), verify command in the row. [ready, blocked only on deploy]
2. **Deploy carrying the PDF mapping** — rides the first green post-float deploy. [owner/float-gated]
3. **Lock-float repair completion** — 7.5+ h of proof treadmill (00:05→07:19, rc=1 each round; roots fixed in sequence: bank-sync vendorHash, go-taskqueue vendorHash, patchelf 0.15.2 nixpkgs regression via overlay `7ec79a208`, hermes-agent family, eval-lambda error at `customisation.nix:873`); registry re-refreshed 07:22 (`79b6b817c`). Owned by the active parallel session — deliberately NOT harvested by this report. [external]
4. **helium.desktop `MimeType=` gap for PDFs** — file managers can't offer Helium as PDF handler; either patch the desktop file upstream-style or document the explicit-default pattern. [ready, desktop]
5. **`open` error-message improvement** — mention the desktop-prefixed instant bridge (see e.1). [ready, desktop]
6. **mimeApps eval-lint** — WARN when defaultApplications target a desktop file that doesn't advertise the MIME type (see e.2). [decision, desktop]
7. **Single-source bank-sync (and siblings') vendorHash pins** — multi-surface pins dragged the float proofs (see e.4). [ready, services]
8. **Darwin PDF default parity check** — no mimeApps exists in platforms/darwin at all; assess whether macOS needs anything. [decision, desktop]
9. **PDF MIME alias coverage** — x-bzpdf/x-gzpdf/acrobat unmapped (rare). [decision, desktop]
10. **Annotate the 04:27 pimsync report's "float posture stays green" claim** — the gate had been red since before 00:05; whether the claim was true at its authoring instant needs a timeline check first. [watch, needs verification before touching]
11. **Post-deploy: verify `xdg-mime` resolves via the HM file with the shadow removed** (the baf369402 row's verify step — listed separately because it is this session's acceptance gate for the declarative path). [ready, blocked on deploy]
12. **Glimpsed in the queue (other owners, not re-verified here):** SigNoz 52/10-vs-54-mkRule count reconciliation row; AGENTS.md close-out count-citation rule row; three pim-sync fixture/rehearsal rows (blocked:user). Their Source rows own them. [external]

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Is browser-as-PDF-viewer the permanent doctrine, or should a dedicated viewer (zathura-class) be added someday?** Affects whether the x-pdf aliases and future MIME coverage are worth extending, and whether the niri shadow pattern ever recurs for other document types.
2. **The float fight has run 7.5+ hours. Do you want a fresh session to take it over (coordinated handoff), or is the current owner close?** I cannot see other sessions' liveness/intent — only their commit cadence (last registry refresh 07:22, last proof 07:19, quiet at 07:46).
3. **Is the `niri-mimeapps.list` instant-bridge pattern acceptable as a recurring tool** (deploy-gapped fixes, always with a mandatory removal row), or should it be forbidden repo-wide so only declarative state ever serves?

---

**Artifacts this session produced:** `platforms/nixos/users/home.nix` PDF block (rode `6614dbec9`), `~/.config/niri-mimeapps.list` (untracked home state, deliberate bridge), TODO rows (`baf369402`), this report.
**Parallel sessions active during this window (not mine, not assessed):** SUPERB P5+P6 (gen-995 deploy 03:24/05:34 close-out), timesheets + invoices-dashboard runbooks (`79b6b817c`), money-flow docs, pim-sync scaffold (00:2x→04:2x).
