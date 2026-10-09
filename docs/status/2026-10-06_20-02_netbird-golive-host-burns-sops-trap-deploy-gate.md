# 2026-10-06 20:02 — NetBird go-live: three host burns fixed live, the sops gitignore trap, and the IO-gated deploy

Operator demand: brutal self-review + full a–g status. `.md` at operator demand (standing override, NOT propagated).
Scope: the arc segment since `2026-10-06_15-57_netbird-deploy-train-closeout-brutal-self-review.md` — the first provisioner host runs, the three live burns, the owner's sops step, the evo-x2 flip, and the currently IO-gated deploy. Everything asserted here is backed by command output captured in-session.

---

## Brutal answers first

### What did you forget?

1. **I "verified" the sops file as tracked when it was neither tracked nor visible** — after the owner's sops step I ran `git status | rg netbird` (empty) plus `git ls-files` (empty) and concluded "daemon committed it ✓". The truth: `.gitignore:144` (`secrets*`) HIDES new files in `platforms/nixos/secrets/` from status — the file existed, was ignored, and invisible to Nix. Absence of a status line is not presence of a commit. That false confirmation cost a full deploy cycle (first deploy run failed on flake-check + evo-x2 eval with "not tracked by Git").
2. **I truncated my own failure evidence** — the first deploy run was piped `| tail -15`, which cut off the two failing checks; I had to re-run the whole gate to see them. For a gate whose whole value is its failure detail, piping to tail was self-sabotage.
3. **Two of the three host burns were pre-checkable** — I read the auth middleware source before the first host run but stopped there; `setupkey.go`'s All-group rejection and the Go nil-slice `null` marshal were each one sourcegraph away. Both shipped green-checked by a mock that was more permissive than reality — twice.

### What could you have done better?

1. **Read handler validation source BEFORE the first host switch**, not after each burn. The pattern that finally worked (mock enforces 422 + null-marshal) should have been the starting bar: a mock is only a test if it is as strict as the real API.
2. **Check PSI before STARTING a deploy build**, not only inside the gate. I launched the build into an already-elevated IO environment; the gate caught it at switch time, but the build itself had already contributed load. Cheap pre-check, should be habitual.
3. **Verify git-visibility of every new path a module references** (`sopsFile`, `flake` sources) at edit time — `nix path` sees the TRACKED tree, `ls` sees the working tree. One `git check-ignore` beats a deploy cycle.

### Did you lie?

No fabricated claims. One evidence-strength failure, corrected above (the "sops tracked ✓" inference). Everything else is directly evidenced: three host journals (13:58 ECONNREFUSED, 14:01 422 body, 14:42 jq null), the 14:48:36 green run, key file `stat` (600 root:root 37 bytes — content never read by me), cloud-domain check green with the client ON, and two blocked deploy runs with their exact gate messages.

### Ghost systems / split brains / tests?

- **Ghost systems: none.** Every wired thing is live or deliberately deferred (router waits for enrollment; evo-x2 flip is staged-and-committed, deploy pending the IO gate).
- **Split brains: one real, now half-closed** — docs said "flip `services.netbird-client.enable = true`" as if a site existed; NO enable site existed anywhere (module was gated off with no flip point). I created the site (configuration.nix) and updated the test that asserted the OFF state. The net-vpn.md/runbook prose still describes the flip as future work — needs a completion annotation post-deploy.
- **Tests: the day's whole story.** The selftest was green through two host failures — mock fidelity was the gap, and it is now pinned: the mock enforces the All-group 422 AND returns JSON `null` for empty lists (Go nil-marshal), contract greps `$lan_gid` / `--retry-connrefused` / `(. // [])[]`. The check suite now encodes every burn the host taught us.
- **Scope creep: none.** I did not touch the parallel sessions' work (browser-history.nix, the docs-health audit, the Rust build train), the stalwart pair, or the voice-agent debt.

---

## a) FULLY DONE

1. **Burn #1 fixed + pinned** — push-restart race (13:58 ECONNREFUSED): `api()` curls now carry `--retry 10 --retry-connrefused --retry-delay 1` (connrefused-only retry is POST-safe).
2. **Burn #2 fixed + pinned** — v0.80.0 `setupkey.go` 422 ("can't add 'all' group to the setup key"): `auto_groups=[lan-route]` (peers join All automatically anyway); mock enforces the same 422; selftest asserts auto_groups == lan-route gid + a direct 422 probe; contract greps the `$lan_gid` binding.
3. **Burn #3 fixed + pinned** — Go nil-slice marshal (`jq: Cannot iterate over null`, 14:42): all five jq top-level iterations are `(. // [])[]`; mock now answers `null` for EMPTY lists (fidelity); contract greps the idiom; the cold-start scenario exercises every null path.
4. **Provisioner LIVE and GREEN on the pbx** — I switched the host through the fix trains myself (owner granted ssh-via-script; `/tmp/nb-hostrun.sh` never prints secret values). 14:48:36 run on train `5cwskknj`: setup key already-present+valid, resource `lan-subnet`, nameserver group `lan-dns`, policy `lan-access` created, router correctly deferred (evo-x2 not enrolled), rc=0. Key file: `600 root:root 37 bytes`, stat-ed only.
5. **Three pbx trains staged + baselined + FRESH** — `bd1qy86s` (422 fix) and `5cwskknj` (null-safety) both: staged, `-current` rotated to each verified-live predecessor, empty-story baseline blocks appended to the ledger (versionless script changes), deploy-freshness FRESH each time. CHANGELOG carries the full burn narrative.
6. **Owner completed the sops step** — `netbird_setup_key` in `platforms/nixos/secrets/netbird.yaml` (I never saw the value).
7. **evo-x2 flip landed in the tree** — enable site created (configuration.nix, with rationale comment), `test-cloud-domain.nix` gate assertion flipped from must-be-off to must-be-on, eval `true`, cloud-domain check green ("netbird client enabled OK").
8. **The gitignore trap fixed** — `git add -f platforms/nixos/secrets/netbird.yaml` past `.gitignore:144 secrets*`; evo-x2 eval green afterward (drvPath resolves).
9. **IO gate respected, not forced** — deploy blocked at PSI avg10 83%/disk 101% (freeze-precursor class); I diagnosed the storm (discordsync, clickhouse, 3× crush sessions, now a Rust cross-compile train on /mnt/buildcache + binfmt aarch64 with D-state flush workers), left a drain-watch running, and did NOT `DEPLOY_FORCE_PRESSURE`.
10. Tracking rows kept current through two parallel-session edit races on services.md (mtime-touch retries, per shared-tree discipline).

## b) PARTIALLY DONE

1. **evo-x2 deploy** — flip committed + eval-green + sops tracked, but the switch is PENDING the IO-pressure gate; storm has persisted for hours (avg300 ~60%), source = an active Rust build train that is not mine to kill. Drain-watch shell still running (exits when avg10 < 20%).
2. **Post-deploy convergence chain** — ready but not runnable: verify `netbird-evox2` enrollment → trigger provisioner on the pbx → expect "created router … converged". Script pattern proven (`/tmp/nb-hostrun.sh`), one command away.
3. **Close-out docs** — services.md rows 174/185 + net-vpn.md Phase-2 + SystemNix CHANGELOG entry for the flip: all pending deploy verification (writing them before the switch verifies would be claiming unfinished work).

## c) NOT STARTED

1. MacBook + phone enrollment (owner, reusable key — see g.3).
2. The 15:57 report's improvement items (docs-gates aggregation, preflight generate.sh derivation, deploy-freshness exit-2 UX, gremlin instrumentation) — untouched today, correctly deprioritized under the go-live.

## d) TOTALLY FUCKED UP!

Nothing irreversible. The ranked self-inflicted costs:

1. **The sops "tracked ✓" false confirmation** (detailed in Brutal answers) — one wasted deploy cycle, caught by the gate, root-caused to the ignore rule, fixed with `-f` and a queued permanent guard (§f).
2. **`| tail -15` on a failing gate** — discarded the evidence I needed most; re-ran to recover it. Dumb, cheap, avoidable.
3. **Two mock-fidelity burns shipped green** — the check suite said YES while reality said 422/null. The tests existed but tested a lie; fixed by making the mock as strict as the handler source. This is the day's real lesson: a permissive mock is a green light over a pothole.

## e) WHAT WE SHOULD IMPROVE!

1. **Mock-fidelity doctrine** (pbx-wide): a mock must enforce every handler-side validation and marshal quirk the real server has — 422 semantics, nil-slice `null`, auth scheme strictness. Encode from SOURCE, not from the OpenAPI spec alone (specs carry shapes, not semantics).
2. **sopsFile git-visibility gate**: eval-time or pre-deploy check that every module-declared `sopsFile` is TRACKED (git check-ignore) — the `secrets*` ignore rule makes this class invisible to status and it costs a deploy cycle every time it bites.
3. **Full-log discipline on gates**: never pipe a multi-check gate through `tail`; write to a file and read the failures section.
4. **Pre-deploy PSI pre-check** as habit, not just the in-gate assertion — the build phase contributes IO before the gate ever runs.
5. **Read the validation source before first contact with a new API** — one sourcegraph of `status.Errorf` sites in the handlers would have prevented both API burns.
6. **What went RIGHT and must stay**: loud per-stage FATALs with HTTP code + body head (turned each burn into a one-paste diagnosis), the ssh-via-script pattern with never-print-secrets discipline, refusing DEPLOY_FORCE_PRESSURE, and rotating GC roots only after live verification.

## f) Next things (harvested at authoring time → TODO_LIST.md + docs/todo/services.md)

1. [ready] **Deploy evo-x2 (netbird client flip) when IO PSI drains < 20%** — drain-watch running; then verify `netbird-evox2.service` + login oneshot enrolled, `netbird status` shows Connected/peer evo-x2.
2. [ready] **Post-enrollment: trigger provisioner on the pbx, expect "created router … converged"** — closes Phase 2 completely; then annotate rows 174/185, net-vpn.md, and write the SystemNix CHANGELOG flip entry.
3. [ready] **sopsFile git-visibility gate** (eval assertion or pre-deploy check: every declared sopsFile must be `git check-ignore`-clean) — the `.gitignore secrets*` trap cost a deploy cycle (2026-10-06).
4. [ready] **pbx AGENTS: mock-fidelity doctrine row** — a mock must never be more permissive than the real API: enforce handler validations (422s) AND marshal quirks (Go nil-slice → JSON `null`); encode from handler source, not just the OpenAPI spec.
5. [watch] **Eval warning "integration subdomain(s) without catalog entries"** appeared during evo-x2 eval (catalog, cache, banksync, … ~20 names) — pre-existing or parallel-session surface; verify it predates the netbird flip before touching.
6. [ready] **net-vpn.md Phase-2 completion annotation** after f.1/f.2 verify (docs currently describe the flip as future work — split brain c).
7. [blocked:user] **Enroll MacBook + phone** (reusable `evo-x2-enroll` key or per-device keys — g.3) + on-phone/mac split-DNS validation of `home.lan`/`larsartmann.cloud` through `lan-dns`.
8. [watch] **The Rust build train / IO storm** — once it ends, confirm PSI returns to baseline; if avg300 stays elevated afterward, escalate to the stability domain (docs/agents/stability.md class).
9. [ready] **Rotation of /tmp pbx roots post-verified-switch** (after f.1 lands, `-current` should point at the deployed evo-x2-irrelevant… no: pbx `-current` → `5cwskknj` once nothing further stages — fold into f.2's close-out).
10. [ready] **Kill or formalize the drain-watch pattern** — the background PSI watcher should become a `scripts/wait-io-drain.sh` utility if this recurs (second IO-gated deploy in recent history).
11. [watch] **Setup-key 30d clock** — started 2026-10-06 ~14:48; expires ~2026-11-05; enrollment of all desired devices must land inside the window (decision row from 15:57 report still open).
12. [ready] **SystemNix CHANGELOG entry for the Phase-2 flip** (configuration.nix enable site + test gate flip + sops file) — write post-deploy with evidence.

## g) Questions I cannot answer myself

1. **The IO storm**: the Rust cross-compile train (rustc on `/mnt/buildcache`, binfmt-aarch64 workers, D-state flush on the build disk) — is that YOUR build or a parallel session's I must not touch? And is `DEPLOY_FORCE_PRESSURE=1` ever acceptable to you, or is waiting always the answer? (I will not force it either way without your word.)
2. **The sops gitignore trap**: want the permanent guard (f.3 — eval/pre-deploy check that declared sopsFiles are git-tracked), or would you rather narrow `.gitignore`'s `secrets*` rule to explicit plaintext patterns so encrypted sops files are visible by default?
3. **Enrollment scope**: MacBook + phone — same reusable `evo-x2-enroll` key, or should the provisioner (or a one-off) mint per-device one-off keys? Affects the key's `usage_limit` posture and the 30d expiry math.

---

### Session evidence index (this segment)

- Host journals (owner paste + my ssh-script): 13:58:51 ECONNREFUSED → FATAL; 14:01:25 `POST /api/setup-keys -> HTTP 422` (body: "invalid auto groups: can't add 'all' group to the setup key"); 14:42:22 `jq: Cannot iterate over null`; 14:48:35–36 full green run, "run complete (router deferred)", unit inactive/not-failed
- `/tmp/nb-hostrun.sh` (ssh-via-script, owner-granted): switch to `5cwskknj` + reconciler start + journal + key-file stat (600 root:root 37 bytes — content never printed)
- pbx checks: `netbird-provision-selftest` "5 scenarios green … + All-group 422 pin"; `netbird-contract` "15 invariants hold" (+3 new build-time greps)
- pbx trains: `f85g340p` → `bd1qy86s` → `5cwskknj`, each deploy-freshness FRESH; ledger blocks appended (two empty-story entries, supersession noted)
- SystemNix: `services.netbird-client.enable = true` eval; `cloud-domain` check green ("netbird client enabled OK"); `git add -f platforms/nixos/secrets/netbird.yaml` (gitignore `secrets*`); evo-x2 drvPath resolves post-add
- Deploy gate: run 1 blocked (2 failures — untracked sops file), run 2 blocked (IO PSI 83%/disk 101%); NOT forced; storm attributed to discordsync/clickhouse/3× crush/Rust build train; memory PSI 0 throughout
