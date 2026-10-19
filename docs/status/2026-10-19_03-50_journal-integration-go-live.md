# Status Report: journal CLI integration — go-live, verification, and self-review

**Session:** 2026-10-19 ~02:00–03:50 CEST · **Author:** Crush session (journal integration)
**Scope:** add `/home/lars/projects/journal` to SystemNix as a properly integrated tool. This report covers ONLY this session's work and what it directly observed.

---

## a) FULLY DONE

1. **Research → design.** journal = interactive accounting-kernel CLI (no daemon/port/vHost) → the correct integration is the LarsArtmann tooling pattern, NOT a service module. Read integration-registry.md + go-ecosystem.md before touching anything.
2. **flake input** (`flake.nix`): `github:LarsArtmann/journal?ref=refs/heads/master`, master-tracking float, **non-follower** (own nixpkgs + own go-nix-helpers; journal's go.mod floor 1.27.2 == its own locked go_1_27).
3. **Probe-before-lock honored**: first-hand `nix build /home/lars/projects/journal#default` at ba60fe0d (clean tree == origin/master) BEFORE locking. Green.
4. **Lock-audit compliance**: fixed all 3 eval-gate findings — `journal.inputs.flake-parts.follows` + deep `journal.inputs.go-nix-helpers.inputs.treefmt-nix.follows` (eval-only, safe) + documented `deliberate` entry `"journal.nixpkgs"` in lib/lock-audit.nix (pdg toolchain-re-tool class). Lock mirrors journal's own lock (only private dep node: go-cqrs-lite — CI key already existed).
5. **Package** (`lib/lars-packages.nix`): `journal = flakePkg inputs.journal` — no shim needed; **identical store path** through our flake (7bbbjbcg…) = follows are bit-neutral, upstream vendorHash governs.
6. **PATH both hosts**: eval-verified in `evo-x2.config.environment.systemPackages` AND `packages.aarch64-darwin.journal` exists (version ba60fe0d).
7. **CI deploy key**: read-only key `systemnix-ci-readonly` (id 166885168) on LarsArtmann/journal, secret `NIX_DEPLOY_KEY_JOURNAL` set, wired into ALL auth blocks: nix-check.yml ×2 jobs, flake-update.yml, go-deps-audit.yml, negative-tests.yml. Keyfiles trashed. actionlint-clean on all 4 (verified post-hoc, exit 0).
8. **Docs**: `docs/services/journal.md` runbook (integration surfaces table, non-follower drift class, ops, deliberately-not-a-service rationale); CHANGELOG entry; go-ecosystem.md private-repo list gained journal.
9. **Verification battery**: `nix build .#journal` green · `nix flake check --no-build` all-green (lock-audit, pin-audit, ports, shape audits) · `nix fmt` canonical (one foreign file reformatted — see d.4).
10. **LIVE**: journal rode the shared-tree deploy (gen 9ypljx30, nixpkgs fe13242) — `/run/current-system/sw/bin/journal` present, `journal --version` → ba60fe0d, `journal doctor` correctly rejects (no journal.yaml in cwd — by design). **Anchor verified**: profile system → system-930-link → 9ypljx30 == /run/current-system. Journal's fish-completions derivation built in the toplevel path (deploy log evidence).

## b) PARTIALLY DONE

1. **CI end-to-end validation** — key + secret + YAML wiring done, but **7 local commits are ahead of origin/master** (incl. a00eecfa7 with the whole integration; the daemon commits, never pushes). Until the owner push, NIX_DEPLOY_KEY_JOURNAL is unexercised; first nix-check / go-deps-audit / flake-update runs will arbitrate. actionlint was run locally only after the daemon had already committed the edits (see e.1).
2. **Darwin full-surface check** — `nix flake check --no-build` locally skips aarch64-darwin by design (AGENTS); I eval-probed only `packages.aarch64-darwin.journal`. The --all-systems walk (checks/devshells with the new input in the graph) is CI-side only, post-push.
3. **Go-live rode the concurrent session's deploy** — my own `nix run .#deploy` never completed (flock-blocked twice, correctly). Their deploy built+activated a tree containing my committed changes; verification of MY surfaces was done against that live system. Their deploy exited 3 on **Monitor365 agent not connected** + 2 CV storm-suspect smokes — regression signal is THEIRS (Monitor365 re-enable first-fire), zero journal involvement (deploy log checked).
4. **journal usage surface** — binary live and sane; the production entity registry (journal.yaml) and any real books dir don't exist yet (owner data — see §g).

## c) NOT STARTED (deliberate or deferred)

1. journal.yaml production deployment (owner-side config; example exists in repo only) — deferred pending owner decision (§g.1).
2. journal DB backup automation (timer + backup-coordination freshness row) — deferred until a prod DB location exists (§g.2).
3. VM/negative tests — none owed: no new NixOS module, no new eval gates, no port.
4. GOPRIVATE addition for journal — decided Won't (main-module repo, never `go get`'d); documented in runbook.
5. Any Gatus/registry/catalog entry — N/A by design (CLI, not a service).

## d) TOTALLY FUCKED UP

Nothing of mine broke. Near-misses and own-goals, honestly:

1. **Wedge misdiagnosis detour (~15 min)**: read the concurrent deploy's slow activation (25 min, 0-CPU stc, momentarily empty job queue) as a possible pipe-deadlock wedge and started forensics. It was an IO-slow restart wave mid-phase (journal timestamps proved units were still starting at 02:51). Lesson: timestamp journal events BEFORE diagnosing wedge; activation phases have quiet gaps.
2. **jq cwd artifact**: the first flake.lock inspection of journal's lock printed SystemNix's lock nodes (shell cwd quirk). Caught only because bank-sync/buildflow nodes in "journal's lock" was implausible. Lesson: absolute paths for every file-arg jq, always.
3. **Lexical-sort trap**: `ls | tail` on profile links showed system-840 as "latest" (string sort, not mtime). Switched to `ls -t`. Minor, but it briefly muddied the anchor check.
4. **Foreign file swept by `nix fmt`**: the pinned formatter reformatted the parallel session's discordsync.nix shim. I read the diff (pure canonical reformat), kept it (pre-commit enforces the same form), and flagged it — correct per rules, but the deeper miss: I ran whole-tree `nix fmt` knowing it walks 3300+ files; a scoped alternative doesn't exist (documented), so the correct move was just this check, which I did.
5. **stc `test`-mode anchor scare**: mid-deploy I flagged exit-14 UNANCHORED (profile 929 vs current-system) — real per the checklist, but I observed it DURING the phased activation; the profile flip (system-930) landed minutes later. Not an error, but my interim read could have triggered an unnecessary sudo repair if I'd acted faster than I verified. The AGENTS anchor rule needs a "phased activation" caveat (test → profile flip → post-checks are sequential).

## e) WHAT WE SHOULD IMPROVE (systemic, observed this session)

1. **Workflow YAML edits ride unlinted into daemon commits** — pre-commit filetype legs cover .sh/.py, not .yml; my 4 workflow edits were committed by the daemon before any actionlint ran (I lint-verified after). An actionlint (or YAML-parse) leg for `.github/workflows/**` in pre-commit or nix-check would close the gap. → harvested (f.1).
2. **Deploy-lock waiting UX**: agents poll /proc (racy — one transient miss made me re-attempt too early). A `flock -n /tmp/.systemnix-deploy.lock true` probe, or deploy.sh gaining `--wait-for-lock`, is cheaper and authoritative. → f.2.
3. **Anchor check vs phased activation**: document in AGENTS.md deploy-anchor section that `switch-to-configuration` may flip /run/current-system BEFORE the profile link moves (observed ordering), so the anchor check is meaningful only at deploy-exit. → f.3.
4. **Absolute-path jq discipline** is already house doctrine for DIRENV_DIFF; extend the doc line to cover cwd-quirk artifacts generally (I hit a second failure mode with the same remedy).

## f) NEXT (harvested at authoring time — see Harvest Note)

1. **[ready]** actionlint/YAML-parse leg for `.github/workflows/**` edits (pre-commit or nix-check CI) — this session's key wiring shipped unlinted-by-a-gate. → docs/todo/pipeline.md
2. **[ready]** deploy.sh `--wait-for-lock` (or documented flock probe) replacing agent-side /proc polling. → docs/todo/pipeline.md
3. **[ready]** AGENTS.md anchor-discipline paragraph: phased activation ordering caveat (current-system flips before profile link; check at deploy-exit only). → docs/todo/pipeline.md
4. **[blocked:push]** Owner push window: 7 commits ahead of origin (journal integration + parallel sessions' work); CI then validates NIX_DEPLOY_KEY_JOURNAL end-to-end. → docs/todo/pipeline.md
5. **[watch]** First CI runs post-push: nix-check (input fetch + FOD), go-deps-audit (journal go.mod vs lock), flake-update (first journal node move → probe-before-lock if FOD re-stales). → docs/todo/pipeline.md
6. **[decision]** Production journal home: which dir/host owns journal.db + journal.yaml; owner-managed file vs sops-rendered config. → docs/todo/services.md
7. **[decision]** journal backup automation: nightly `journal backup --out --verify` timer into /mnt/pool/backups + backup-coordination freshness row, once f.6 lands. → docs/todo/services.md
8. **[decision]** darwin inclusion (auto via base.nix attrValues) — keep both hosts or gate to NixOS-only? → docs/todo/services.md
9. **[watch]** journal upstream go-cqrs-lite frozen-rev pin (7142e43) forward move → re-lock + probe-before-lock. → docs/todo/services.md
10. **[watch]** First real usage: once the prod dir exists, extend the runbook Ops section with the location + backup cadence; confirm `journal status`/`doctor` there. → docs/todo/services.md
11. **[watch]** Monitor365 agent-not-connected smoke failure (deploy exit 3, 02:51) — foreign session's re-enable first-fire; verify their queued row owns it (CHANGELOG 2026-10-18 entry says first-fire checks queued). Reference only — NOT re-queued to avoid duplication.
12. **[watch]** tq-agent-pool.service failed (exit-code) during the 02:51 activation — foreign session's in-flight unit edits (still uncommitted at 03:50). Reference only.
13. **[watch]** CV storm-suspect render smokes (io some avg60 69.74%) — re-verify when calm; already named in the deploy log's own advisory. Reference only.
14. **[roadmap-grade idea]** tier-3 proposal confirm/reject flows (journal `proposals list` → human decision) could ride a tq task type or daily digest — owner product idea, not engineering yet.

**Harvest note:** f.1–f.3 → TODO_LIST queue ([ready]) + full entries in docs/todo/pipeline.md; f.4–f.10 → domain libraries only ([blocked:push]/[decision]/[watch] are deliberately non-harvestable per the queue contract); f.11–f.13 are reference-only observations owned by the parallel sessions' existing queues — deliberately not duplicated.

## g) QUESTIONS FOR THE OWNER (cannot be figured out from the tree)

1. **Where does the production journal live?** Which directory + host should own `journal.db` + `journal.yaml` (the repo only has an example + a dogfood.db), and is journal.yaml owner-managed forever or should SystemNix own it via sops→rendered config?
2. **Backups: system timer or manual?** Once a prod DB exists, should a nightly `journal backup --out --verify` timer land in SystemNix (with a backup-coordination freshness row), or do you prefer running backups by hand for now?
3. **Push the 7 pending commits now?** CI is the only thing that can validate the deploy-key wiring end-to-end; I never push without instruction. Push now, or hold for your window?

---

**Verification evidence:** probe build ba60fe0d pre-lock; `nix build .#journal` = same store path 7bbbjbcg…; `nix flake check --no-build` all-green; actionlint exit 0 ×4 workflows; live `journal --version` = ba60fe0d; anchor system-930-link == /run/current-system (9ypljx30, fe13242); deploy log shows journal + fish-completions derivations building; smoke failures (Monitor365, CV-storm) journal-free.
