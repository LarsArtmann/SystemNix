# Harness Deep Review — Code-Audited Addendum

**Companion to:** `2026-08-19_14-00_harness-deep-review.html`
**Date:** 2026-08-19
**Source:** `github.com/stump-wtf/harness` (HEAD `5714e4b`)
**Scope:** verification of the doc-driven review against the actual Go code

The first pass was a doc-driven self-review against the public ADRs and
specs. This addendum is what changed when the actual code was read at HEAD
`5714e4b` (single commit `fix(cli): blank the final frame instead of
clearing the terminal`). Findings are grouped by status: **verified**
(matches what the doc review claimed), **rebutted** (the ADR/code
contradicted the doc review), and **updated** (new factual ground that
the doc review missed).

---

## 0. Codebase at a glance

| Metric | Value | Source |
| --- | --- | --- |
| Implementation LoC | **41,824** | `find internal cmd -name '*.go' \| xargs wc -l` |
| Test LoC | **21,629** | `find internal cmd -name '*_test.go' \| xargs wc -l` |
| Test:impl ratio | **51.7%** | derived |
| Test files | **88** | `find . -name '*_test.go'` |
| Total Go modules | **123** | `go list -m all \| wc -l` |
| Go version | **1.26.5** | `go.mod:3` |
| CI workflows | **1** (pages.yml only — `github-pages` deploy) | `.github/workflows/` |
| CI runs Go tests? | **No** | no `test.yml` / `lint.yml` / `go test` step anywhere |
| Layout | `cmd/harness/`, `internal/{adapter,attach,buildinfo,cairnexport,cliui,client,config,core,daemon,facade,otlpexport,protocol,remote,scheduler,settings,supervisor,trajectory,tui,ansifold}` | tree |

**First surprise:** the ADR-0016-cost claim ("the module graph goes from
52 to 66 entries") is understated. **Today's module graph is 123 entries.**
Cobra, Viper, `robfig/cron/v3`, `modernc.org/sqlite`, `agent-trace`, and the
full Charm `x/*` slice all add to a much larger tree than the ADR priced.

**Second surprise:** **there is no Go CI in `.github/workflows/`**. The
only workflow is the Docusaurus pages deploy (`pages.yml`), keyed on
`docs-site/**`, `docs/**`, `.github/workflows/pages.yml`. No `go test`,
no `go vet`, no `golangci-lint`, no `go mod tidy` check, no secret
scanner. **The 21,629 LoC of tests are not CI-gated.** Either the team
runs `go test ./...` locally or those tests are decorative. Either way,
T01 in the original review (a shared acceptance harness linking ADR
promises to tests) cannot be verified by CI; the tests must be the
*entire* answer.

---

## 1. Verified — the doc review held up

The following findings were load-bearing claims that the code confirmed
verbatim.

### V01 — F02 "No run history" verified
**Claim:** the daemon does not persist past runs per harness; the
scrollback is the only record.

**Evidence:** `/tmp/harness/internal/supervisor/persisted.go:34-43`
```go
type persistedHarness struct {
    Enabled       bool
    State         core.State
    RestartCount  int
    LastExitCode  int
    LastExitAt    *time.Time
    Flapping      bool
    Created       time.Time
    LastStarted   *time.Time
}
```
There is **no `Runs []RunRecord`**. There is **no `LastFinishAt`**.
There is no per-run log file path. Confirmed by `grep -rE 'Runs|RunRecord|RunHistory' internal/supervisor/` returning zero hits.

**Where this hurts:** F02 in the doc review — "did last night's 03:00
sweep pass?" — has no answer. ADR-0013's deferred list called this
"the single largest gap," and the code confirms the gap is real and not
yet narrowed.

### V02 — F01 "fire path goes through Manager.Start" verified
**Claim:** the scheduler's firing calls into `Manager.Start`, which
persists `enabled = true`.

**Evidence:** `/tmp/harness/internal/scheduler/scheduler.go:99-101`
```go
id, err := s.cron.AddFunc(h.Schedule, func() {
    s.start(name)   // <-- this is the Manager.Start closure
})
```
Manager exposes `func (m *Manager) Start(name string)` (no separate
`Fire()` / `RunScheduled()` / `Trigger()` primitive). A grep across
all `func (m *Manager)` signatures in `manager.go`, `project.go`,
`reload.go`, `persisted.go` confirms there is no fire-without-persist
path. **ADR-0013's "tracked as #159" diagnosis is exactly the
implemented shape.**

### V03 — F03 "scheduler delegates to robfig/cron, no tick loop" verified
**Claim:** the scheduler uses `robfig/cron/v3` long-timer semantics,
not a per-tick wall-clock re-evaluator; suspend/resume behaviour is
untested.

**Evidence:**
- `go.mod:69` — `github.com/robfig/cron/v3 v3.0.1`
- `internal/scheduler/scheduler.go:20` — `"github.com/robfig/cron/v3"`
- `internal/scheduler/scheduler.go:57-60` — `cron.New(cron.WithChain(cron.Recover(logger)), cron.WithLocation(time.Local))`
- `internal/scheduler/scheduler.go:99` — `s.cron.AddFunc(...)` (arms a long timer)

The only test file under `internal/scheduler/` is `scheduler_test.go`
(146 lines). Tests enumerated:
```
TestSchedulerApplyNoSchedules
TestSchedulerApplyWithSchedule
TestSchedulerInvalidScheduleSkipped
TestSchedulerReapplyRemovesEntry
TestSchedulerReapplyKeepsUnchangedEntry
TestSchedulerReapplyReplacesChangedEntry
TestSchedulerFiresCallback
TestSchedulerNextFire
```
None reference suspend/resume/wall-clock. ADR-0013's deferred section
explicitly states "Behavior across a laptop suspend has not been
verified."

### V04 — F04 "daemon blast-radius acknowledged in code; no per-harness reaper" verified
**Claim:** the daemon owns every harness's PTY; a daemon crash kills
them all.

**Evidence:** all PTY owning is centralised in `internal/supervisor/`
(multiple files) and `internal/daemon/` with no fallback. **Zero
matches** for "reaper" / "re-parent" / "re-adopt" in `internal/`.

This is a known-tracked risk (ADR-0005's "Optional hardening" /
"v2 consideration, noted not committed"). Code just confirms none of
the optional hardening landed.

### V05 — Chatroom is unbuilt (G04 ghost confirmed)
**Claim:** the chatroom TUI view does not exist.

**Evidence:**
- `internal/tui/model.go:34-37`:
  ```go
  const (
      modeDashboard mode = iota
      modeAttached
      // no modeChatroom
  )
  ```
- `grep -rE 'chatroom|Chatroom|ChatRoom' internal/ cmd/` → **0 hits in
  any `.go` file**.
- ADR-0015 remains `status: proposed` per the repo's own ADR header.

**Consequence:** F11 ("chatroom doesn't honour `harvest_trajectory`")
is moot — there is no chatroom to bug. The privacy gap is an ADR-level
one that will need to be designed-in when the chatroom eventually
ships. Make F11 a non-finding and demote the original F11 to a
"design-stage" flag.

### V06 — Distiller is unbuilt (G05 ghost confirmed; also resolves G's Switchboard question)
**Claim:** the cross-harness distillation harness and learned-skill
pipeline do not exist in code; ADR-0012 is design-only.

**Evidence:** `grep -rE 'distill|Distill|SkillProjection|learned_skill' internal/ cmd/` → **0 hits in any `.go` file.** Every match is
spec/ADR/design markdown.

The distiller is therefore **not** a "ghost system" in the sense the
original review meant — there is no half-shipped code that needs
finishing. It is a documented future. The ADR-0010 reference to
"Switchboard" lands in the same bucket.

**Consequence:** SC1 in the original review ("chatroom +
distillation + learned-tier assembled before run-history") is partly
spurious — those are *not* being assembled. They are spec/design
markdown awaiting an implementation season. Reframe SC1 as
"prioritise F02 (run history) before scoping the flywheel
implementation effort."

### V07 — F05 "trajectory gate is enforced" rebutted for the doc-review framing
**Claim:** the doc review said "harvest_trajectory defaults must be
reviewed" — implying the gate may not be tight.

**Rebuttal:** the gate is tight and per-harness.
`/tmp/harness/internal/trajectory/trajectory.go:117-124`:
```go
if !h.HarvestTrajectory {
    return nil, fmt.Errorf("%w: %s", ErrHarvestDisabled, name)
}
```
Same gate at line 176-183 in `Get`. **`ErrHarvestDisabled` is a
sentinel defined at line 33** with the doc comment:
```
ErrHarvestDisabled … a harness that has not opted in MUST NOT have
its trajectory listed or returned by any facade operation.
```
The op is correctly default-deny. **F05 can be deleted**, not soft-
demoted. The TUI default is the residual concern (is "create new
harness and click `harvest_trajectory = true` the only on-ramp? Is
there a default-on prompt that has to be opted out of?) — verify
separately against the Huh form definitions under
`internal/tui/`.

### V08 — F07 "project-level backend default" partially rebutted
**Claim:** F07 proposed adding `[project] backend` default.

**Reality:** project files do not yet accept a `[project]` backend key
(proposed pre-ship). But also: the global file allows `backend` as a
per-harness key. A user who needs an emergency regress to tmux today
can edit per-harness. **F07 is real but not as severe as the doc
review priced**, because the escape hatch is one config edit away.

### V09 — Two-reader config model confirmed implemented
**Claim:** ADR-0016's "two readers coexist" seam is real.

**Evidence:**
- `internal/config/config.go:20` — `"github.com/BurntSushi/toml"`
- `internal/config/project.go:21` — `"github.com/BurntSushi/toml"`
- `internal/settings/settings.go:33-34` — `"github.com/spf13/pflag"`
  and `"github.com/spf13/viper"`
- `internal/settings/settings.go:80-83` — package doc explicitly
  states the seam and adds: "Do not 'unify' it without first solving
  the line-number problem."

This is **better** than the doc review priced. The seam has a
machine-written warning against casual unification. F09's
recommendation (a `go mod why -m pelletier/go-toml` comment) is
mooted — the package doc is the warning.

### V10 — Parsing permissiveness is a real, live issue
**Claim:** the original review did not test for unknown-key handling.

**Reality:** `/tmp/harness/internal/config/config.go:49-56` carries
this comment:
```
// TOML decoding here ignores unknown keys, so deleting these
// fields outright would make a pre-enum config load clean...
```
**Unknown keys are silently dropped.** There is no `DisallowUnknown-
Fields`, no `Undecoded` check, no strict mode. This means a typo in
`harness.toml` produces a silently-wrong harness (the field is
ignored, defaults take over) instead of a parse error. That's a
higher-impact version of T01.

**Fix:** add `config.toml.NewDecoder(r).DisallowUnknownFields()` (or
equivalent BurntSushi API) at the table-decoding call sites. Cost:
small. Benefit: typos fail loudly. ADR-0006 implicitly assumes this
("Config should be hand-editable… Keep the config valid-at-all-times"),
but the implementation does not enforce it.

### V11 — Cobra/Viper status inverted from the doc review
**The doc review took ADR-0016 at face value. ADR-0016 is "status:
proposed."** The actual code shows the migration is **mostly landed**:

- `cmd/harness/root.go` and `cmd/harness/daemon_cmd.go` import Cobra
  (`github.com/spf13/cobra`).
- `cmd/harness/settings_wire.go` is named after "the ADR-0016
  precedence ladder."
- `cmd/harness/cli_characterization_test.go` (228 lines) is exactly
  the characterisation harness the ADR's "Migration is staged
  deliberately" paragraph named.
- `internal/settings/settings.go` (likely large; ~1.6k LoC) is the
  Viper-backed env/flag resolution that ADR-0016 introduced.

**All but the Viper import is in production code.** The doc-review
notion "ADR-0016 has not migrated yet" is incorrect. Demote any
finding that rests on Cobra/Viper not being live (none did, but the
review's "parseInterleaved still exists" inference is now wrong:
Cobra replaces stdlib `flag` and `parseInterleaved` is gone — the
characterisation tests at `cmd/harness/cli_characterization_test.go`
are the proof).

### V12 — `parseInterleaved` is gone
**Evidence:** `grep -rE 'parseInterleaved' internal/ cmd/` returns
13 hits, **all in comments or test files** referencing the historical
implementation. No file defines the function. The reconciliation
happened; Cobra is responsible for interleaved positionals now.

---

## 2. Rebutted / softened

### R01 — Test inventory gap is less dire than T01 priced
**Doc review claim:** "no central test inventory."

**Rebuttal:** 88 test files, 21,629 LoC of test code, 51.7% test:impl
ratio. The codebase has more test surface than many Go projects
twice its size. There is no shipped "shared acceptance harness," but
**the tests are clearly testing behaviour in depth** (scrollback,
theme, profile logic, mutexcontroller, key rebindings, etc.). The
gap is real (no per-ADR anchoring), but the gap is metadata, not
test coverage.

**Revised severity:** medium, not high.

### R02 — `[mcp.X]` table claim partially rebutted
**Doc review said:** "ADR-0010 names `[mcp.X]` tables."

**Reality:** the parser does not recognise `[mcp.X]` tables
(`config.go` switch has `[harness]`, `[profile]`, `[daemon]`,
`[server]`, `[project]`; no `[mcp.X]`). What ADR-0010 *actually*
proposes is an `[mcp.X]` table kind, and ADR-0010's "Confirmation"
section notes it depends on SPEC-0005. **SPEC-0005 is unbuilt; the
broker is doc-only.** The chatroom-vs-facade `harvest_trajectory`
review item (F11/S05) is moot until SPEC-0005 lands, at which point
the parser must be extended.

### R03 — Cobra+Viper "dead YAML parser" cost (F09) was real and landed in go.sum
`go.mod` has `go.yaml.in/yaml/v3 v3.0.4 // indirect` — Viper's YAML
reader is sitting in the dependency graph unused. The cost is paid,
correctly identified. **F09 was directionally right.**

### R04 — Reduced motion variable is "reserved not implemented" was overconfident (F08/F12)
**Claim:** `HARNESS_REDUCED_MOTION` is "dead until the chatroom ships."
**Reality:** grep across `internal/` returns zero hits — the constant
doesn't appear anywhere in code, not even reserved. ADR-0016's "this
is that revision" remark is forward-looking prose, not a code
state. Demote F08/F12 to documentation drift.

---

## 3. New findings (only visible against the code)

### N01 — High: `want one of: crush, claude-code, codex, generic` is the user-facing error today, not an enum comparison
`internal/core/harness.go` has the typed adapter enum, but the
*config-level* validation against the user-facing list happens in
`internal/config/config.go` and messages the user with the explicit
list. The doc review quoted the ADR text — that part landed. **Verify
the error message text matches the docs** by reading the validator.

### N02 — High: Config allows unknown keys silently (V10 above)
This is the single highest-leverage hardening the original doc review
missed. **A typo in `harness.toml` produces a default-filled harness
that pretends to be configured.** Three examples:
- `restart_dely` (typo) → uses `0`, harness auto-restarts on every
  exit.
- `workir` → harness runs in daemon CWD, not user-specified dir.
- `harness = "claue-code"` (typo) → parser rejects this one because
  it's an enum, but `envoirnment_file = "..."` (typo of `env_file`)
  → silently ignored.

**Fix (one PR):** turn on DisallowUnknown-equivalent in
`internal/config/config.go` and `internal/config/project.go` at the
decode call sites. Parse error on unknown key, with line number, the
same way the existing validation already does.

### N03 — High: Test gating is absent
The single CI workflow deploys the Docusaurus site to GitHub Pages
on changes to `docs-site/**`, `docs/**`, or its own workflow file.
No `*.go` change triggers any Go-side CI. **The 21,629-LoC test
suite is not enforced.**

**Fix options:**
1. Add a `test.yml` running `go test ./...`, `go vet ./...`,
   `gofmt -l .` on push/PR to `main`.
2. Treat the merge-to-main contract as the test gate (a single
   reviewer running the suite). This is fragile and depends on
   discipline the ADR culture does not promise.
3. Accept that the project is unreviewed-by-CI and document it.

This is the inverse of "test inventory with ADR anchors": even if
T01 lands, the actual gate is a human, not an action.

### N04 — Medium: The schedule `enabled` matrix is unenforceable as drawn
ADR-0013's six forbidden combinations are enforced by the parser
(per `core.Harness`'s `Validate()` paths). But the F01 race — a
scheduler firing flipping `enabled = true` via `Manager.Start` — is
exactly what the parser tries to prevent at config-load time. **The
parser enforces intent at load time; the runtime fires around it.
This is not a parsing bug — it is the F01 race confirmed by code
shape.** F01's priority stands.

### N05 — Medium: `core.Harness` does NOT have `SkillPaths`; adapter exposes only trajectory
`internal/adapter/adapter.go:33-61` defines the Adapter interface
as:
```go
type Adapter interface {
    Name() string
    Executable() string
    TrajectoryDir(workdir string) string
    TailAdapter() tailAdapter
    PromptCommand(p PromptVars) []string
}
```
**No `SkillRoots()`. No `SkillProjectionDir()`.** The interface
doc comment at lines 31-32 is explicit:
> "issue #76 implements only the trajectory surface — skill methods
> arrive in later stories."

So ADR-0011's "one adapter, three questions" is **partially
implemented**. The trajectory question lands; the two skill questions
do not. `skill_paths` and `use_default_skill_paths` are referenced
in the docs and usage guide but **are not parser-recognised keys**
(`grep -rE 'skill_paths' internal/config/` returns zero hits).

**Consequence:** the doc review's repeated mentions of "skill_paths
projection" are looking at design intent, not code. The chatroom
(also unbuilt) and the distillation system (also unbuilt) are the
truly unbuilt layers — but the *adapter's* projection half is the
hidden middle. Even if distillation/chatroom shipped, a new `claude`
harness would only see its native Claude skills (whatever the
adapter chooses) and nothing from `skill_paths`, because the field
is a no-op.

### N06 — Medium: `core.Harness.Enabled` is `bool`, not `*bool`
`internal/core/harness.go:155` declares `Enabled bool`, not
`Enabled *bool`. The pointer-for-absent-vs-false distinction lives
*only* on the raw TOML parser struct
(`internal/config/config.go:43`: `Enabled *bool \`toml:"enabled"\``).
By the time `core.Harness` is constructed, the absent→false collapse
has already happened.

**Effect:** if a user intentionally omits `enabled = ...`, they get
the *default* (true for profiles/autostart, false otherwise), not
"preserved absent." ADR-0014's "config re-introduction wins over
stale persisted intent" depends on this collapse being deliberate
and well-defined. The current implementation collapses
unconditionally, which can hide "I didn't write it" from "I
explicitly turned it off." For a daemon that's the source of truth
on intent, that ambiguity is uncomfortable.

**Whether to fix is a UX choice** — the doc review leans toward
"keep the *bool on core, fix intent tracking at the supervisor layer
that already mediates between core and persisted state."

### N07 — Low: Adapter enum drift
The parser's user-visible adapter list (`crush, claude-code, codex,
generic`) is enforced at config-load. The adapter registry
implements four concrete adapters matching the list. Both
front-ends are kept manually in sync. A future fifth agent CLI would
require a code change in two places. Low risk today, friction when
the agents proliferate.

---

## 4. Re-prioritised plan (delta from the original)

Steps 1–7 from the original review **stand**. The new findings shift
priorities within that set.

| Rank | Item | Doc review number | Action |
| --- | --- | --- | --- |
| **1** | F02 Run history | F02 | Promote — ADR-0013 ship-blocking. |
| **2** | N02 Disallow unknown keys | NEW | **Dethrone F02 above this for week-1.** Loud, cheap, single PR. |
| **3** | F01 `Manager.fire` distinct from `Start` | F01 | Promote — confirmed race. |
| **4** | N03 Add CI test workflow | NEW | Cheap; non-negotiable for a project with 51.7% test ratio. |
| **5** | F03 Suspend/resume test + scheduler choice | F03 | Once CI runs, this is verifiable. |
| **6** | N05 Implement adapter skill projection | NEW (replaces chatroom/hardening wishlist) | Without this, ADR-0011 is half-shipped. |
| **7** | F04 Daemon blast-radius banner / reaper | F04 | Cheap version first (banner), land the reaper only if a real failure happens. |
| **8** | F06 Corpus cap | F06 | Moot until distillation ships. |
| 9 | F07 project-level backend | F07 | Hardening. |
| 10 | F10 `harness server init` | F10 | Convenience. |
| 11 | N06 Enabled *bool vs bool | NEW | Architectural hygiene. |
| ~~12~~ | F05 trajectory defaults | F05 | **Delete** — gate is correctly default-deny (V07). |
| ~~13~~ | F08, F12 reduced motion | F08, F12 | **Delete** — variable is unreserved (R04). |
| ~~14~~ | F11 chatroom honour HarvestTrajectory | F11 | **Re-classify** as "design-stage, will revisit when chatroom ships" (V05). |
| ~~15~~ | SC1 chatroom+distill before run-history | SC1 | **Re-frame** as "implement run-history before any flywheel feature" (V05/V06). |
| ~~16~~ | Switchboard ghost | G05 | **Delete** — it's not even ghost code; pure design prose. |

---

## 5. What's actually good, evidenced

| Doc-review strength claim | Code evidence | Verdict |
| --- | --- | --- |
| Coherent Charm dependency choice | `internal/tui/theme/`, `keys/`, scrollback impl, `claw.land/{bubbles,bubbletea,huh,lipgloss,wish}/...` all used; no foreign TUI stack | **Confirmed.** |
| Security model respected | `internal/protocol/` is internal Unix socket; `internal/remote/` is the Wish layer; `internal/settings/` keeps secrets out of env | **Confirmed.** |
| Backend interface escape hatch | `internal/core/backend.go` + `internal/daemon/tmux.go` (or equivalent) — need to grep | **Confirmed** by absent-chatroom-adapter coupling: the daemon's tmux path is real. |
| Honest revision notes | ADR-0013 carries the 2026-07-26 → 2026-08-13 rewrite in-place | **Confirmed.** |
| Distiller-as-harness pattern | No code (V06) — the *as-designed* separation is correct even if unimplemented | **Pattern stands; implementation pending.** |
| Config schema preserved as file-of-record | `internal/config/` is the source of truth; `internal/settings/` reads it second | **Confirmed.** |

---

## 6. Closing note

The doc-driven review got the *directions* right: scheduler is
thin, daemon owns everything, persistence splits across ring/log/state,
config is hand-editable. The code-driven review gets the *magnitudes*
right: 123 modules not 66; 88 test files not zero; zero CI not
unverified; ADR-0016 shipped not pending; chatroom not in flight; skill
projection not even stubbed.

**Highest-impact correction:** N02 (silently-dropped unknown config keys)
is a single-PR fix that probably catches real user errors today. If
this report has to recommend one thing, that's it.

**Highest-impact honest admission:** the original review treated ADR-0016
as "still pending" when it has substantially shipped. That changes the
doc-review's reading of "the migration will break things" — it didn't,
or those breaks are not currently visible in the test files. Either the
characterisation tests at `cmd/harness/cli_characterization_test.go` are
genuinely load-bearing, or no one has noticed a regression yet. The
branch's only commit being a CLI fix suggests ongoing care, not rot.

