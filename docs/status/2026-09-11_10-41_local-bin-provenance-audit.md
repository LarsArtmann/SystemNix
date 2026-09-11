# Status Report: ~/.local/bin Provenance Audit (Mini-Session)

**Date:** 2026-09-11 10:41 CEST
**Scope:** This session ONLY (per user instruction — no codebase-wide research).
**Session task:** Answer "What of these are from NixOS?" for `/home/lars/.local/bin`.

---

## What This Session Did

Single-question session: classify every entry in `/home/lars/.local/bin` by
provenance (Nix-managed vs hand-installed). Method: `ls -la`, `readlink`,
shebang/grep inspection for `/nix/store/` references, wrapper-script reads.

### The Answer Delivered

**NixOS/Nix-built (4 of 33 entries):**

| Entry | Provenance evidence |
| --- | --- |
| `golangci-lint-lsp-wrapper` | Symlink into `/nix/store/...-home-manager-files` (Home Manager, matches the documented HM LSP wiring) |
| `buildflow` | Nix-built Go binary (glibc 2.42-84 ELF interpreter baked in; mtime TODAY 10:19) |
| `shfmt` | Nix-built Go binary (`tzdata-2026c` store path baked in) |
| `flm` | Wrapper script with nix store paths (glibc, curl, gcc, util-linux) — but targets the HAND-installed `$HOME/.local/share/fastflowlm` |

**Non-Nix (the rest):** `uv`/`uvx` (downloaded static binaries), `hf`/`huggingface-cli`/`tiny-agents` (symlinks into `~/.local/share/uv/tools`), `himalaya*` (downloaded binary + 18 completion/man/desktop files), `env`/`env.fish` (uv-generated PATH helpers), `node` (2-line shim: `exec bun`), `llamacpp-server` + `print-safe` (hand-written bash scripts).

---

## a) FULLY DONE

- Complete classification of all 33 `~/.local/bin` entries, evidence-based (symlink targets, ELF interpreter, baked store paths, shebangs).
- Correctly identified the one entry that contradicts its own documentation: `flm` still points at the hand-installed fastflowlm tree that AGENTS.md explicitly marks obsolete ("delete `~/.local/share/fastflowlm/`, `~/.local/bin/flm`, and the LD_LIBRARY_PATH exports in `~/.bashrc` after the deploy proves stable").
- Kept scope tight per user instruction (no unrelated research).

## b) PARTIALLY DONE

- **Provenance depth varies.** `buildflow` and `shfmt` were proven nix-built but I did NOT trace WHERE they are declared (flake input? `mkLarsPackages`? HM?). `buildflow` is not mentioned in AGENTS.md's tool inventory I recalled; its origin is unverified.
- **Actionability:** findings were reported but zero follow-up actions were taken or ticketed (see f).

## c) NOT STARTED

- Nothing in this session had a plan beyond the answer. No TODO_LIST entries, no cleanup of the obsolete `flm` artifacts, no declaration-migration of the hand-installed tools.

## d) TOTALLY FUCKED UP

- Nothing broken by this session (read-only audit, zero mutations). No damage.

## e) WHAT WE SHOULD IMPROVE

1. **`~/.local/bin` is an unmanaged mixed bag.** ~90% of entries are hand-installed or download-managed (uv, himalaya). Each is a silent-staleness and PATH-shadowing risk (uv's own `env`/`env.fish` deliberately prepends this dir over system PATH).
2. **The `flm`/fastflowlm hand-install contradicts its own runbook.** AGENTS.md says it is obsolete post-deploy; the wrapper still resolves to `$HOME/.local/share/fastflowlm` and the deployed Nix module owns the real service. Leftover risk: someone runs `flm` by hand against the old tree.
3. **`node` shim is a landmine** — `exec bun` masquerading as `node` means any tool probing `node --version` or spawning `node` gets bun semantics. Works until it doesn't.
4. **himalaya ships 18 loose files** (completions, man pages, desktop file) into `~/.local/bin` — man pages and a `.desktop` file in a bin directory is install-script debris, not a bin entry.
5. **`buildflow`'s mtime is TODAY 10:19** — rebuilt ~20 minutes before this session, likely by a parallel session (concurrent-sessions doctrine). Worth knowing who owns it and whether it's declared anywhere.
6. **Session tooling gaps:** `file` and `xxd` were not on PATH (fell back to grep/strings). Minor, but slows audits.

## f) Up to 50 things we should get done next

*(Brainstorm seeded by this audit — most items are ROADMAP fuel, not commitments. Ordered roughly by impact.)*

1. Delete the obsolete fastflowlm hand-install: `~/.local/bin/flm`, `~/.local/share/fastflowlm/`, and the LD_LIBRARY_PATH exports in `~/.bashrc` (per AGENTS.md).
2. Trace where `buildflow` is declared (flake input / mkLarsPackages / HM) and document it; if undeclared, install it declaratively.
3. Decide whether himalaya should be an HM package (nixpkgs has it) instead of a downloaded binary + 18 loose files.
4. Move himalaya's completions/man/desktop files to their proper locations (`~/.local/share/man`, `~/.local/share/applications`) or let nixpkgs placement handle it.
5. Audit the `node`→`bun` shim: find what depends on it, either declare bun's shim properly or remove it.
6. Inventory which of `~/.local/bin`'s non-nix entries are on PATH-order collision course with nix-provided commands (uv's `env` prepends this dir over system PATH by design).
7. Decide: migrate `uv`/`uvx` to nixpkgs HM package, or keep uv-managed deliberately (document the decision).
8. Same decision for the uv-managed tools (`hf`, `huggingface-cli`, `tiny-agents` — huggingface-hub).
9. Review `llamacpp-server` and `print-safe` hand scripts: promote to the repo (`scripts/` or HM-wrapped) with version control.
10. Add a pre-commit or audit script flagging NEW non-symlink regular files in `~/.local/bin` (drift detector for the provenance boundary).
11. Verify `~/.bashrc` fastflowlm LD_LIBRARY_PATH exports actually still exist before deleting (I asserted the runbook, never checked the file).
12. Check whether `flm` is shadowed by the Nix module's own binary in PATH order (which one wins in a fresh shell).
13. Confirm the fastflowlm deploy is actually proven stable (the deletion gate in AGENTS.md is "after the deploy proves stable") — tied to the still-owed reboot and staged v1.0.3 go-live.
14. Sweep for other hand-installed stragglers: `~/.local/share/`, `~/.local/opt`, `~/bin` — same audit pattern.
15. Document `~/.local/bin` provenance policy in AGENTS.md (one paragraph: what belongs there, what belongs in HM).
16. Confirm `buildflow`'s morning rebuild (10:19 today) was intentional and by which session — concurrent-session attribution.
17. Check whether `shfmt`'s baked `tzdata-2026c` reference will break on the next nixpkgs bump (store path drift in a copied binary — if it was `nix copy`-ed rather than wrapped, it can stale).
18. Same staleness check for `buildflow`'s baked glibc 2.42-84.
19. Ensure `env`/`env.fish` (uv-generated) don't conflict with HM's own PATH management in fish.
20. Grep shell configs for stray references to the retired hand-installed flm path.
21. Consider replacing `file`/`xxd`/`strings` audit-tooling gap: add `file` to the devshell/system packages if it's genuinely missing from interactive PATH (it errored — verify, don't trust my single failed invocation).
22. Add himalaya's completion files to fish/bash completion dirs or drop them (are they ever sourced?).
23. Verify the `himalaya.desktop` file is actually installed/registered anywhere, or delete it.
24. If himalaya moves to nixpkgs: pin the migration and remove the downloaded tree in the same change (land replacement BEFORE removal rule).
25. For the uv tools: pin uv tool versions (currently floating?) and record them.
26. Decide ownership: is `~/.local/bin` user-curated (fine) or should it be 100% HM-symlinked? A 90% non-nix dir under a NixOS config is a policy question for the owner.
27. Check `_himalaya` (93 KB, look-alike binary) — what is it, is it referenced, or debris?
28. Cross-check: does anything in the Nix config reference `$HOME/.local/bin` (HM `home.sessionPath`?), making these entries first-class PATH citizens?
29. If `print-safe` (Canon MG2500 ink-flood workaround) is operationally valuable, it deserves repo status + docs — it's currently invisible to git.
30. Same for `llamacpp-server` wrapper — conflicts with the llama-rag/GPU doctrine in AGENTS.md? Verify which llama-server it launches and whether it's stale.

*(30 grounded items — the audit surface was one directory; padding to 50 would invent work beyond what this session observed. Items 31-50 belong to a full system-wide provenance sweep, which is a different task.)*

## g) Questions I can NOT figure out myself

1. **Is the flm/fastflowlm hand-install still needed by anything?** AGENTS.md says delete it once the deploy proves stable, but the fastflowlm section also says v1.0.3 is staged and the reboot is still owed. Is `~/.local/bin/flm` (and the whole `~/.local/share/fastflowlm` tree) now safe to remove, or are you still using it as a manual fallback until v1.0.3 lands?
2. **Where does `buildflow` come from and who rebuilt it this morning?** It's a 76 MB nix-built binary, mtime today 10:19 (20 min before this session). Is it a LarsArtmann tool declared in another repo, installed by a parallel session, and should it live in `mkLarsPackages`/HM instead of as a raw file here?
3. **What is the intended policy for `~/.local/bin`?** Should hand-installed/downloaded tools (uv, himalaya, hf, the node→bun shim) be migrated into Home Manager declarations, or is this directory deliberately user-curated outside Nix? The answer determines whether items 3-9 above are real work or a non-goal.

---

**Report format note:** Markdown was written per the user's explicit `.md` instruction, overriding the status-report skill's HTML-dashboards default (flagged per the skill's divergence rule; not propagated as a new default).
