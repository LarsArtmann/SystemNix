# 2026-11-13 22:20 — A1b: four audit gates delegated, parity green, full sweep green

Session continuation of the 21:45 report. Wave A1b of
`docs/planning/2026-11-10_05-07_SUPERB-nixos-module-collection-extraction.md` executed end-to-end:
mount-gating, memory-watermark, dynamic-user, capability-grant. Times CET.

## a) Verdict

**A1b LANDED tree-side, both repos.** Collection 176bcf9 (pushed; 4 contract checks probed green
FROM the pushed rev), SystemNix layers + lock + parity green, full
`nix flake check --no-build --all-systems` **rc=0** — which also clears the morning session's
A1c-sweep debt (the immich eval break was repaired by its owning session; verified green at 21:12
before the burst).

## b) What shipped

- **Collection** (`ae21af8` + daemon-swept `727e738`/`342570a`, pushed as `176bcf9`):
  4 modules + READMEs, 4 contract checks (flag/pass/allow/silent legs each), 4 negative groups
  (14 mutation legs, **14/14 PASS**), flake wiring, CHANGELOG entry.
- **SystemNix** (daemon commits `38fd412f4` + `32748ec4a`): 4 thin delegation layers,
  `tests/test-mount-gating-audit.nix` import converted to the applied form,
  `flake.lock` nixos-modules → 176bcf9, **2 new infra-follows overrides**
  (`nixos-modules.inputs.docs-gates.inputs.nixpkgs.follows = "nixpkgs"` +
  `…docs-gates.inputs.erraudit.inputs.go-nix-helpers.inputs.treefmt-nix.follows = "treefmt-nix"` —
  the lock-audit gate blocked EVERY eval until followed; both are eval-only deps).
- **Parity**: evo-x2 2686/0 vs baseline 2685/0; rpi3-dns **byte-identical** 1809/0.
  SystemNix checks green under the new lock: mount-gating, geometrikks-caps (pins the
  capability wiring through evo), systemd-shape, tmp-cleaner.

## c) Findings worth keeping

1. **tryEval cannot guard missing options under Nix 2.34** — `builtins.tryEval
   config.sops.secrets` on a sops-less host DIES (the attribute-missing error escapes through
   the seq-checked config fixpoint; isolated repro + the contract's bare-host leg). The
   dynamic-user guard is now the canonical `options ? sops.secrets`. The SystemNix original was
   latently broken — both fleet hosts import sops-nix, so the path never ran. Generalization:
   **tryEval is useless for forcing module-system option reads; use `options ?`** — same family
   as the integration-registry recipe's own guard note.
2. **The +1 assertion attribution**: post-burst evo-x2 showed 2686 vs baseline 2685 (0 failed
   both). Proven NOT delegation drift: pre-burst rev `73793638a` evaluates 2685; the only
   commit in the window (`38fd412f4`) carried exactly this wave's 6 files; the lock range
   `59dbd3a..176bcf9` includes a **foreign boot-mirror eval-time self-assertion** (a parallel
   session's diff-gate pin, riding my lock move). Legitimate content; noted so the next parity
   session doesn't chase it.
3. **tryEval also cannot force assertion MESSAGES** (the fileSystems cycle-message class) —
   per-prefix message counting on any real host is impossible; assertion-parity stays
   total+failed only.
4. The collection's negative-harness now duplicates each PASS line once (the parallel session's
   per-group logging, uncommitted when my groups ran) — cosmetic, theirs.

## d) Mistakes owned

1. Two more masked-output lapses (probe through `2>/dev/null` twice) — caught both within one
   command; the no-mask rule keeps winning.
2. The capability-grant contract shipped with a one-paren-short chain (the A1a paren-bug class,
   THIRD strike this wave family) — caught by `nix fmt`'s alejandra parse.
3. First holder-spawn attempts for the morning live-skip test were reaped/mis-shaped (documented
   in the 21:45 report §h) — no new instances this arc.
4. `git add -A` in the collection staged a foreign in-flight `run.sh` edit; unstaged it
   immediately and deferred my group insert until their edit quiesced (~15 min). The final
   run.sh commit intentionally carries both changes (attribution here).

## e) Next

A1c close-out (the "delete originals" step is inherently done — the layers replaced the bodies
in place; remaining = this sweep, done, + deploy), A2b/A2c option-ifications (A2a's
port-registry + gatus-coverage halves already landed by the parallel bridge `8c108bdef`),
A3 harness re-point, then P1. A1a+A1b deploy at the next quiescent window; cvagent serve
restarts on that activation — the standing watch-and-stop row owns it.
