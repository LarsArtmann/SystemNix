# 2026-11-18 11:35 — qmd close-out + 9-FOD storm stamps + deploy in flight

**Session window:** 2026-11-18 ~07:30 → 11:35 CET (continuation of the 06:42 qmd-iGPU session; third session on today's deploy arc).
**HEAD at authoring:** `f9b337e1f` (my upstream drafts) + uncommitted stamp wave in the working tree (lars-packages.nix ×6, cv.nix 23rd ledger, browser-history.nix shim, flake.lock crm rollback, flake.nix crm note).
**Boot:** `cd60fc6b` unchanged (no freeze #58); io PSI at authoring avg10=26.5 / avg300=49.6 (storm draining; was 87.5/87.5 at 07:40).
**The deploy:** NOT fired yet — the warm keep-going build (`0BB`) is running and **0 hash mismatches so far** (downstream drvs of stamped FODs building = stamps effective). Deploy fires with `DEPLOY_FORCE_PRESSURE=2` immediately after it lands and the wave commits.

## 0. The state in one paragraph

The qmd iGPU fix (06:42 session) is fully closed out: CHANGELOG, gotchas row, §f harvest (13 queue one-liners + 11 domain rows across 5 libraries), prototypes trashed (~1.5G), float vetted, and BOTH upstream drafts written + verify-before-filing gated + voice-checker clean (posting awaits the banner review). The deploy path hit the **documented erraudit FOD wall** (two sibling sessions' work, read per pre-read discipline) and went through it properly: one `--keep-going` enumeration enumerated **9 distinct go-modules FOD re-stales** (erraudit, browser-history-server, golangci-lint-auto-configure, cv, project-meta, kith-crm, project-discovery-daemon, project-dependency-graph, projects-management-automation — a mass module-graph re-serve day), all 8 stampable surfaces stamped with first-hand got-hashes from that single enumeration, and **kith-crm rolled back to b7f8615** (the 11-04 session's green rev — the re-float to tip b3b1382 re-carried the 3 dead-API templ compile break; tip has NO templ regen, verified live at upstream). The 08:50 deploy's "erraudit is the real blocker" finding was correct but incomplete: erraudit was one of NINE.

## a) FULLY DONE

1. **qmd §f harvest** (the 06:42 report's §f.22, owner-authorized): 13 `[ready]` one-liners into TODO_LIST + full rows into ai-stack.md (8), upstream.md (4: watch ×2, decision ×1, glibc-ask draft-batch row), services.md (2), pipeline.md (2), monitoring.md (1, ai-meter `[blocked:user]`). Committed via daemon wave + my pathspec commit (`7e058bc97` carries the report ledger).
2. **CHANGELOG entry** — qmd-gpu landing, house-style single bullet, deploy-pending noted (committed `056c87ade` via daemon).
3. **gotchas-archive row** — the 4-layer silent-CPU incident with rules (positive-probe doctrine, prebuilt-artifact distrust, wrapper-glibc collision, fork-trap interpreter patch, the cheap `QMD_LLAMA_GPU=vulkan` gate).
4. **Prototype cleanup** — ~1.5G trashed (qmd-tree-copy 1.3G + qmd-vk-fixed 77M + nlc3223 73M + shim sources + 9 session logs); the real `~/.cache/qmd` state untouched. BTRFS verdict: incompressible binaries (794M apparent ≈ 793M physical; gpu build +96M for the bun copy) — §f.36 closed as no-op.
5. **Float vetted** (§f.1): cvagent + go-nix-helpers (8 nodes) owner-input FORWARD floats — policy-clean, no third-party pins touched.
6. **Upstream drafts** (`f9b337e1f`, docs/drafts/): (A) withcatai/node-llama-cpp — the vulkan prebuilt missing the `ggml_backend_score` export, framed as same-class-as-#579 (fixed b8179 link chain; current packages fail a different link), with fresh readelf A/B evidence (all 14 CPU variants export it, zero vulkan-package libs do), verbatim b10361 loader source, the live `NoBinaryFoundError` + GGML_LOG_LEVEL=info silence proof, and the one-line-shim-makes-it-work end-to-end proof. (B) tobi/qmd — undiagnosable fallback (warning names no cause; doctor's "install/configure Vulkan" advice is unactionable when the SHIPPED backend is broken; MCP path doubly silent via the wrapper's `GGML_BACKEND_SILENT=1`), plus the wrapper env defects (no `libvulkan.so.1`; injected glibc-2.42 breaks `uname` INSIDE doctor itself — self-contained repro). Both: verify-before-filing gates passed (Gate 5 searches clean — no duplicate for A; #739/#957 referenced as related for B), `check-draft.go --kind body-issue --ai-drafted --unsolicited` → **0 FAIL 0 WARN both**. Banners UNCHECKED — posting awaits owner review per the banner protocol.
7. **§f no-op verdicts recorded in the report ledger**: 21 (no other 11-17/18 report mentions qmd), 35 (sole node-llama-cpp consumer = the qmd wiring itself), 41 (repo-root `result` symlink is FRESH — another session rebuilt it 07:36 onto a cv drv; foreign, left alone), 42 (foreign CHANGELOG edit committed in 68cdfca51), 44 (no pin needed), 45 (no secrets typed).
8. **Artifact re-verified post-foreign-fix**: the sibling session's `${kept}` wrapper fix is output-identical for non-empty `kept` (same store path `3a3f9mw5…` rebuilds); shim NEEDED + `ggml_backend_score` GLOBAL FUNC export + wrapper env re-verified in the built tree (`~/.cache/qmd-gpu/qmd-gpu-link` per the new --out-link convention).
9. **The 9-FOD storm mapped + stamped in one wave** (the §d.1 keep-going lesson, executed FIRST this time): exact (drv, specified, got) triples python-parsed from one enumeration log; stamps: erraudit `Y0go8KKA`, golangci-lint-auto-configure `QLQWBZhx`, project-dependency-graph `nMgP22rT`, project-meta `ZzTU3Ja3`, project-discovery-daemon `5B2hM6qB`, projects-management-automation re-added `bW3OHQ3D` (was bare flakePkg), cv 23rd ledger `hDAVgn6` (cv floated TWICE more mid-day: ffb48b7→7e89bf3→178ccec), browser-history-server shim re-added `BdJyCEvl` (consumed bare at browser-history.nix:68). Every entry carries the dated RE-STALE ledger line + first-hand evidence pointer per the nix-hash-fix protocol.
10. **kith-crm lock rollback replayed** — b3b1382 → b7f8615 verbatim from the 11-04 session's rollback commit (`0f6af1a46` node values), flake.nix comment documents the replay + the upstream regen path. Verified at upstream first: tip b3b1382 is pin-convergence only (wave2, `git show` — no templ file changes), so the dead-API compile break still governs; the only deploy path today is the green rev (upstream templ regen is push-gated).

## b) PARTIALLY DONE

1. **THE DEPLOY** — unblocked through the entire FOD wall; warm build in flight (`0BB`, 0 mismatches at poll #1); next: commit wave → `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` → anchor discipline → the full post-deploy batch (§f below).
2. **§f.2 push** — deliberately skipped (never-push-without-explicit-ask; deploy needs no push). The wave is local-only; owner pushes when ready.

## c) NOT STARTED (queued behind the deploy)

- The post-deploy verification set (§f.4-10 of the 06-42 report + the css session's services.md `[blocked:deploy]` row + the 11-04 session's §f.6-9): qmd-gpu live identity + vulkan probe + MCP spawn + escape hatches + doctor; CV embed backfill (1680 docs) with `gpu_busy` sampling from the BUILT binary (closes b.1); timesheets css probes; collector live-verify; cv-server boot-rehydration watch; failed-units triage.

## d) TOTALLY FUCKED UP (honest)

1. **The draft's dlopen mechanism was over-compressed and I caught it only by re-verification.** The session notes said "libggml-vulkan.so fatals on dlopen with `undefined symbol: ggml_backend_score`" — fresh forensics today showed the .so loads CLEAN under ctypes RTLD_LAZY/RTLD_NOW with a satisfied chain (gcc + vulkan-loader), and nothing in the vulkan package references the symbol at all. The defensible mechanism is narrower: the export is missing, the loader requires it, and the real-binary path ends in `NoBinaryFoundError` with zero diagnostics. The drafts were corrected to the evidence BEFORE any filing — no false claim shipped — but the original session record carries an unverifiable error-text claim now (corrected here; the trashed prototype logs held the original context).
2. **Five consecutive edit-tool failures from reading files via bash `tail` instead of the view tool** — the read-before-edit gate is tool-specific, not content-specific. Cost: one round-trip, zero damage, but the reflex (bash-read = "I've read it") is exactly what the gate exists to block.
3. **paste-merge hash mapping nearly shipped misassigned pairs** — the quick `paste - -` extraction interleaved 4 pairs ambiguously; caught by the quote-scrutiny rule (one known-value check: erraudit's pair matched deploy #4's log), replaced with python triple-parsing before any stamp. The stamps are all first-hand-verified against the parse.
4. **A background poll (`sleep 120; tail`) auto-backgrounded mid-report-request** — harmless (job `0BC` just re-polls the same log) but it duplicated poll state; the report pull superseded it.

## e) WHAT WE SHOULD IMPROVE

1. **FOD-storm playbook is now PROVEN end-to-end**: keep-going FIRST (one enumeration, all root failures) → python-parse exact triples → stamp ALL surfaces in one wave → warm rebuild → single deploy. The two sibling sessions' one-failure-per-deploy-cycle pattern (3 sequential ramps, ~40 min) is closed; codify this as the go-ecosystem.md FOD-storm section.
2. **Mass-re-serve days need a stamp-batch commit convention** — 8 files + lock surgery in one wave with one evidence log; today's wave is the template.
3. **The §11 FOD preview blind spot** (erraudit/PMA outside its batch) is now triply-proven — the keep-going toplevel probe IS the preview; §11's subset ✓ should say so loudly (queued pipeline row).
4. **crm's "FLOATS ON MASTER / never a shim" comment vs the templ-compile reality** — the comment's "stale hash surfaces as FOD mismatch, fixed upstream" doctrine doesn't cover the compile-break class; the rollback-replay note now in the block is the pattern for it.

## f) NEXT (in execution order; the deploy arc completes THIS session unless the build fails)

1. Warm build lands clean → commit the stamp wave (lars-packages.nix, cv.nix, browser-history.nix, flake.lock, flake.nix — pathspec, one commit).
2. `DEPLOY_FORCE_PRESSURE=2 nix run .#deploy` (owner order stands from the 11-04 arc; PSI avg10 26.5 at authoring — draining, not calm).
3. Anchor discipline: full process-tree wait, gen-N compare BY NUMBER.
4. qmd-gpu live batch: `which qmd` → gpu store path · `QMD_LLAMA_GPU=vulkan qmd vsearch` → zero fallback warnings · `qmd doctor` → device probe green + `uname` works · MCP spawn handshake (`qmd mcp` JSON-RPC initialize) · escape hatches (`QMD_FORCE_CPU=1`, `--no-gpu`).
5. CV embed backfill (`qmd embed`, 1680 docs) with `gpu_busy_percent` sampling from the BUILT binary — closes the 06-42 report's §b.1.
6. `qmd status` gap re-check after backfill.
7. css-fix probes (their services.md row): /health links /health/dashboard.css, no cdn.tailwindcss.com, css 200 ~128,890 B, /version = 0372bb8.
8. Collector live-verify: system-health-metrics green (no 2-min crash loop), node_textfile_scrape_error clears, no value-less leaks.
9. cv-server boot-rehydration SIGSEGV watch + /health/live probe (their §f.6).
10. `nix run .#post-deploy-check` re-baseline + failed-units triage (the 17-unit list from their §f.9).
11. Status-report cross-link updates (06-42 report §b.1 close + this report's EXECUTED flip).

**Owner-gated (NOT executed):** push (never-push rule) · upstream filing of drafts A/B (banner review) · crm upstream templ regen push · the erraudit/PMA/cv/browser-history paste-upstream legs (hash pastes to 4 repos, push-gated) · SystemNix qmd collection scope (blocked:user row) · PSI policy formalization (the css session's §g1 — today ran on the owner's explicit "no matter the pressure" order; a standing bar is still unset).

## g) QUESTIONS FOR YOU

1. **PSI standing bar** — today's deploys ran on ad-hoc overrides (yours: "no matter the pressure"; btrbk doctrine: "<80 fine"; the watcher bar: <20 never opened in 3h). Pick ONE number for deploy.sh's gate so the three surfaces stop disagreeing.
2. **The stamp treadmill's upstream half** — 8 of today's 9 FODs are follower-class re-stales of YOUR repos (hash pastes + pushes would let the shims drop). Want the paste-upstream batch as its own dispatch (it touches erraudit, browser-history, cv, projects-management-automation, golangci-lint-auto-configure, project-meta, pdd, pdg), or keep consuming shims?
3. **Upstream filings** — drafts A/B are checker-clean and evidence-fresh; on your review, tick the banners and I file both (node-llama-cpp issue + tobi/qmd issue).
4. **crm templ regen** — the upstream fix is a mechanical `templ generate` + commit + push in ~/projects/crm; it retires the b7f8615 lock rollback. Authorize the push?

---
*Evidence: `~/.cache/lockfloat/keepgoing-1118.log` (9-FOD enumeration) + `keepgoing2-1118.log` (warm build, in flight) + deploy logs 08-13/08-50 + the drafts' inline readelf/probe transcripts.*
