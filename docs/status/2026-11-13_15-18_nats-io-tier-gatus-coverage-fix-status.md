# Status: nats io-tier + gatus coverage fix (the pasted deploy-battery failures)

**Session window:** 2026-11-13 ~14:2x–15:18 CET
**Trigger:** Owner pasted a pre-deploy battery output — `nix flake check --no-build` ✗ with two eval assertions: (1) `io-tier-coverage-audit: boot-gated unit(s) without an IO tier: nats`, (2) `gatus-coverage-audit: registered port(s) referenced by live units but never probed: 4222 (journal-mesh)`.
**Tree at start:** HEAD `472b84e4a` (short form of `472b84e4a…`), clean except an untracked foreign status report. **Tree at end:** HEAD `d5a0a894c`, clean.
**Parallel sessions:** ACTIVE throughout (the gen-1005 deploy arc: staged TODO/todo edits at session start, gen-1005 landed+verified report 14:40, then shadow-split-gate + signoz-scripts waves landing via daemon sweeps while I worked).

---

## §a What was done (fully)

### A1. io-tier fix — nats broker tiered BE/5
`journal-mesh.nix` (the enabling module) now overlays `ioTier.heavyDB` onto the nixpkgs-rendered `systemd.services.nats.serviceConfig` — the audit's sanctioned stock-unit overlay pattern. Reasoning recorded in-file: JetStream fsyncs every message batch to `/var/lib/nats` (QLC root); the broker is the mesh's latency-critical transport, so it queues **above its own BE/6 consumer** (journal-mesh runs `ioTier.background`) but **below desktop (BE/3)** and SSH (BE/1).

- Alternatives rejected: allowlist entry (redis-immich precedent — rejected because JetStream does fsync-per-batch *real* write pressure; redis-immich is snapshot-periodic), BE/6 pairing (rejected: transport must not queue behind its own consumer).
- Allowlist NOT touched; the audit's contract satisfied by a real tier, which is the stronger form.

### A2. gatus fix — NATS JetStream TCP probe
Raw TCP check added in `gatus-config.nix` immediately after the Redis precedent: `tcp://127.0.0.1:${toString ports.nats}` (4222), group Infrastructure, 60s interval, `[CONNECTED] == true`, Discord alert naming the break-glass file pipeline + `journalctl -u nats` inspect command. Port-coverage audit satisfied by a real probe, not an `allowPorts` exemption.

### A3. Two hidden HEAD blockers surfaced and cleared (both pre-existing, neither mine)
The audits fixed, the gate walk then failed on layers the pasted run never reached (its eval threw before the checks section):

1. **`flake-input-pin-audit-selftest` "path not valid"** — `865e27458` (11:34 today) changed `lib/flake-input-pin-audit.nix` + `flake.lock`, so the selftest's intermediate gate derivation changed and was never built locally; `--no-build` refuses unbuilt paths. Remedied by building the fixture-only selftest (`nix build .#checks.x86_64-linux.flake-input-pin-audit-selftest`). Net effect: HEAD had been `flake check --no-build`-red since 11:34 for anyone reaching the checks section; now green.
2. **`doc-counts` drift ×2** — `README nixosModules asserts 154, eval truth is 155`. The unstamped 155th module was **`journal-mesh.nix`** (added 11:29 today, ADR-0009 wave — verified via `git log --diff-filter=A`; NOT the suspected `immich-api-key-provision.nix`, which lives in `lib/` and is not auto-discovered). My own NATS check made endpoints 298→299. All four counts re-derived live with the README-embedded commands (modules 155, endpoints 299, packages 53) before stamping; README (header 298→299 + both anchors with dated attribution clauses) and FEATURES (155 modules / 160 files, journal-mesh attribution) re-stamped.

### A4. Verification ladder (all green)
| Gate | Result |
| --- | --- |
| `nix eval` evo-x2 toplevel (both audits fire there) | green, drv `nrvzhygh7…` |
| `nix flake check --no-build` | **all checks passed** |
| `nix flake check --no-build --all-systems` (pre-commit/CI form) | **all checks passed, exit 0** |
| Formatter `nix fmt -- <2 files>` | 0 changed (already canonical) |

### A5. Live-state probes (decisive facts)
- `/etc/systemd/system/nats.service`: **NO IOSchedulingClass** — tier not live.
- gatus service config: **no 4222** — probe not live.
- Live `system-1005-link` = `d825m2l3…`; my toplevel drv = `nrvzhygh7…` → **gen-1005 predates the fixes**.
- Runbook updated: `docs/services/journal.md` broker row now records the tier + probe posture.

### A6. Concurrency handling (per CONTRIBUTING/AGENTS doctrine)
- Daemon swept my 2 module edits into `891c68ea4` mixed with 4 foreign files; a foreign commit sat on top → **no amend** (land-on-top). Later sweeps: my `journal.md` rode `bd5ed589f` mixed with foreign shadow-split-gate work; README+FEATURES landed cleanly alone in `fb113a841`.
- Did **not** deploy (see §c-1), did **not** touch the foreign session's staged/unstaged files, flagged the parallel activity in narration.

## §b Partially done
- **Nothing half-landed.** Every change this session is complete and committed (via daemon sweeps `891c68ea4`, `bd5ed589f`, `fb113a841`).

## §c Not started (deliberately)
1. **The re-deploy.** Live host lacks both fixes (§A5). Not deployed because the parallel session was demonstrably mid-arc in THIS deploy's own tooling (their unstaged `scripts/pre-deploy-check.sh` edit landed in `bd5ed589f` only at ~15:0x; gen-1005 report 14:40; signoz-scripts + post-deploy-check wave `532b0d615` after). Deploying over an active executor's tooling is the documented two-battery-loss race class.
2. **Post-deploy runtime verification** (gatus parses the new check without the 2026-11-02 panic class; nats.service shows `IOSchedulingClass=best-effort` priority 5 live; NATS check green) — impossible before the deploy.
3. **`scripts/negative-test-lints.sh CASES=iotier`** — not run locally; CI owns it (nightly + paths pushes). Positive path proven by eval; audit logic itself untouched.
4. **TODO rows for the follow-ups** — deliberately not harvested at authoring time: the owner's instruction for this session was report-then-wait, so the §f list below carries them instead; queued rows would be re-edited the moment instructions arrive.

## §d What went wrong / near-misses (honest)
1. **Two failed edit round-trips on README/FEATURES** ("read the file before editing") — I edited from grep output instead of viewing first, then burned another call on 0-based offset confusion. No damage; pure process friction. The read-before-edit rule exists for exactly this.
2. **`--raw` misuse on the count evals** — one wasted background eval cycle returning empty. The README-embedded command (no `--raw`) was the authority; should have used it verbatim first try (same lesson as the quote-scrutiny rule: run the doc's own command, not a paraphrase).
3. **Near-miss caught before landing: wrong attribution of the 155th module.** My first hypothesis was `immich-api-key-provision.nix` (new in `472b84e4a`). The `ls` disproved it before any stamp landed (lib/ file, not auto-discovered); `git log --diff-filter=A` pinned `journal-mesh.nix` (11:29). Had I stamped the wrong attribution, the doc-counts prose would carry a false provenance — the exact class the repo's attribution rules guard against.
4. **Not a fuckup but worth naming:** I evaluated gen-1005's history enough to prove it lacks the fixes, but did not reconstruct WHY it landed despite the pasted failing gate (candidate explanations: deploy arc ran from a pre-audit-failure tree state, or its battery hit the audits only after my wave). Immaterial to correctness of the fix; left unexplained.

## §e What we should improve (process level)
1. **Unstamped-wave class keeps firing** (journal-mesh today, mail-relay-verdicts yesterday, and ~10 more catches in the README ledger). The doc-counts gate catches at check time, but always *after* the wave. A pre-commit leg grepping `modules/nixos/services/*.nix` additions vs the stamped counts would catch it at commit time.
2. **`flake check --no-build` goes silently red after any audit-lib change** until someone builds the check once — and deploy batteries hit eval errors first, so the red layer stays invisible for hours (11:34→15:0x here). Consider: pre-deploy §1 pre-building the checks closure, or a WARN leg naming unbuilt check paths instead of the raw "not valid" error.
3. **Daemon-race mixing remains the norm** — 2 of my 3 sweeps landed mixed with foreign files; only README/FEATURES got a clean commit. The PATHSPEC-commit option exists but needs explicit go-ahead (never commit without the owner's word); worth a standing decision from the owner on whether fix-wave authors should always PATHSPEC-commit.
4. **Tier decisions are judgment calls with no review trail beyond the code comment** — A1's BE/5 choice is reasoned in-file but nowhere ratifiable. If the owner disagrees, the fix is a one-line change; the comment makes it findable.

## §f Next tasks (evidence-backed; ordered by impact)
1. **Deploy evo-x2** — carries the nats BE/5 tier + NATS gatus check to the live host (gen-1005 lacks both, proven §A5). Coordinate with the parallel arc first.
2. **Post-deploy verify** — `grep IOScheduling /etc/systemd/system/nats.service` (expect best-effort/5); gatus journal clean parse (the 2026-11-02 duplicate panic class); NATS JetStream endpoint green on the dashboard.
3. **PATHSPEC-commit attribution cleanup decision** — §e-3; needs owner word either way.
4. **Pre-commit doc-counts leg** — §e-1; converts the recurring catch class from check-time to commit-time.
5. **Pre-deploy §1 unbuilt-check handling** — §e-2; either pre-build checks or WARN-classify "not valid".
6. **Run `negative-test-lints.sh CASES=iotier` once locally** — closes §c-3 cheaply; also `CASES=tilecoverage` etc. would ride the same run if desired.
7. **Review the nats tier choice** (BE/5 vs allowlist/BE/6) — one-line change if the owner prefers different semantics; §e-4.
8. **Eval-warning backlog noticed in passing (NOT investigated this session):** (a) catalog integration subdomains without catalog entries — 22 named subdomains will vanish from derived DNS if `dns-local.nix` is deleted; (b) caddy ghost subdomains `nsfw`, `llama` (no vHost, no registry entry); (c) `services.pipewire.jack.enable` deprecation warning.
9. **Do NOT conflate with the opencloud NATS rows** — `docs/todo/services.md` "HTTP-to-NATS prober" (9233/9234) and "storage-users NATS reconnect noise" concern opencloud's *embedded* NATS; this session's fix is the journal-mesh broker on 4222. Neither row is closed or touched.
10. **Standing pin-LIFT conditions** (printed at every eval; lift when each condition clears): hermes-agent (upstream patchelf resync), nixpkgs (patchelf ≥ 0.19 + tools green), nixpkgs-hermes (same condition, then collapse follows), nixpkgs-llama-rag (0.4.0 spin regression fixed + re-verified), paperless-gpt-src (deliberate tag pin), qmd (deliberate tag pin).
11. **Foreign-arc residue watch:** gen-1005 self-review report landed `d5a0a894c`; shadow-split-gate landed `bd5ed589f`; signoz-scripts wave landed `532b0d615` — their follow-up rows are theirs to harvest, not listed here (no research done on them).

*(Stopping at 11 — the honest, evidence-backed set from THIS session; padding to 50 would be fabrication.)*

## §g Questions only the owner can answer
1. **Deploy now, or hold for the parallel arc?** The fixes are inert until a deploy. I cannot know whether the gen-1005/shadow-split-gate session considers its arc closed; deploying activates a toplevel built from a tree that just absorbed their `pre-deploy-check.sh` + `post-deploy-check.sh` edits (committed, but not deploy-proven by them).
2. **Ratify the nats tier:** BE/5 `ioTier.heavyDB` (my pick: latency-sensitive transport above its BE/6 consumer), or would you rather see the redis-immich-style allowlist entry, or BE/6 pairing?
3. **Commit hygiene going forward:** should fix-wave authors PATHSPEC-commit their own files immediately (clean attribution, pre-empting daemon mixing), or keep relying on the daemon sweep?

— *Arte in Aeternum; awaiting instructions.*
