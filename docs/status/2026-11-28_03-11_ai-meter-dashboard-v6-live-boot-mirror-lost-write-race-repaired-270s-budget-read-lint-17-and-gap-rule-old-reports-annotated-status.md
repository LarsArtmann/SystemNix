# Status: the ai-meter dashboard v6 is live, the boot mirror was 15 hours stale and is repaired, the 270 s wait budget is read, two lint rules landed, four old reports are annotated

**Session window:** 2026-11-28 01:29 to 03:15 CET.
**Trigger:** the owner's loop instruction after the 16-54 report ("Break this down into multiple actionable steps … Keep going until everything works").
**Predecessor:** [the 16-54 report](./2026-11-27_16-54_ai-meter-follow-ups-landed-by-the-1027-deploy-embeddings-alert-viewer-range-drift-check-table-claim-refuted-boot-mirror-one-generation-behind.md).

## Scope line

**Verified here** (every command was run in this session; outputs are under `~/.cache/aimeter/r2/gates/`), repo at `git rev-parse --short HEAD` = `2818c0751`:

| Claim | Evidence |
| --- | --- |
| The boot mirror was one generation behind from 2026-11-27 10:29 to 2026-11-28 01:32 | Read at 01:31: the mirror's `loader.conf` preferred `nixos-f594b564…` (generation 1032) while `/boot` preferred `nixos-dca0a736…` (1033); `sudo -n diff -rq /boot/loader/entries /boot-mirror/loader/entries` printed two lines (1033's entry missing on the mirror, a `…+3.conftugyc86n.tmp` leftover there); `systemctl show boot-mirror-sync.service` read `ExecMainStatus=1` at 10:29:06 |
| Why the 10:28 copy stopped | `journalctl -u boot-mirror-sync.service`: two path-triggered runs at 10:27:57 and 10:28:28; the second copied the installer's temporary entry file (same 800 bytes and mtime as the final file) and missed the rename and `loader.conf`; its diff gate refused, exit 1, `OnFailure=` paged; nothing retried |
| The mirror is repaired | `sudo -n systemctl restart boot-mirror-sync` at 01:32:58, rc 0, 0.71 s; `ExecMainStatus=0`; `sudo -n diff -rq -x random-seed /boot/loader /boot-mirror/loader` printed nothing at 01:33 and again at 02:58; both `loader.conf` files prefer `nixos-dca0a736…`; the path unit is `active` / `waiting` |
| The boot chain | `nix run .#pre-reboot-check` at 01:33: 20 passed, 5 warnings, 0 failed (`gates/pre-reboot-check-0133.log`); §11 "mirror tree identical to /boot", §4 "profile anchored to running system" |
| What the 270 s wait budget does | Ledger, 10,758 calls from 09:28:02Z to 00:39:37Z (`gates/ledger-window-postdeploy.log`): 10,450 served, 241 not admitted (all `circuit`), 65 failed, 2 served without usage; 7,605 of the served calls waited at the gate (72.8 %); median gate wait 26.4 s, median time to first token 29.7 s, median provider time 2.4 s |
| The 200s without a usage block | 2 of 10,458 served calls in 15.2 h; both logged `stream read error` with `context canceled` (ai-meter journal at 13:29:25 and 17:47:47); 16 such lines in 48 h, all `context canceled`; served calls ran up to 952 s, so there is no 60 s wall (`gates/ledger-durations-postdeploy.log`) |
| The colors of the 13 threshold tiles over 15 h | `gates/red-census-postdeploy-15h.log`: Success Rate green 96.4 %; Failures, Not Metered, Spans Lost, Reachable, Metrics Freshness never red; Avg TTFT red 52.8 %; Quota Exhausted red 50.8 %; Not Admitted (5m) red 12.4 %; Waiting red 3.3 %; "Unauthorized (24h)" orange 100 % before, "Bad Keys (24h)" uncolored 100 % after (`gates/red-census-v6-15h.log`) |
| A two-column tile shows 17 characters at 1280 px | Two throwaway probe dashboards, rendered headless at 1280 px and deleted: 21 and more cut, 18 fits only with narrow letters ("Unauthorized (24h)" lost 2 px on the live page), 17 fits; wide letters (W, M, m) cut at 15 |
| Line charts drew lines across empty intervals | Kept copy of v5 at 1500 px: "Avg TTFT by Model" showed a straight hour-long ramp for glm-5.3-flash between a call at 00:25 and the next at 01:20; a probe dashboard with four variants of the same chart showed the break only with `spanGaps` in threshold mode; `lib/uPlotV2/utils/dataUtils.ts` (pinned frontend) documents that mode |
| Dashboard v6 is live and equals the tree | `dryrun.py` 201 with an identical read-back; `put.py` 200 at 02:07:23 and 02:10:29, id unchanged, spec identical, 55 panels; `put.py --check-only` at 02:12: equal |
| All ten live dashboards equal their files | `put-generic.py <slug> <file> --check-only` for nine, `put.py --check-only` for ai-meter, 02:12: "live spec already equals the file" ten times |
| The lint, its selftest and the negative legs | `nix build` of `signoz-query-lint`, `signoz-dashboard-lint-selftest`, `ai-meter-spend-promql`, `ai-meter-alert-promql`, `post-deploy-signoz-dashboards-selftest`: rc 0 three times (`gates/v6-checks-4.log`, `-5.log`); `CASES=aimeter,signozdash,signoz bash scripts/negative-test-lints.sh`: 44 passed, 0 failed at 02:14 (`gates/negtests-2.log`) |
| Formatters and static checks | `nix fmt -- <six files> --fail-on-change`: three files reformatted, parse-checked in the same step; shellcheck 0.11.0: 0 findings at every severity on the two new scripts, 0 at warning severity on `post-deploy-check.sh` and the harness; deadnix rc 0; statix silent |
| The flake check | `nix flake check --no-build --all-systems --keep-going`: "all checks passed!" twice, 02:17 to 02:32 and 02:55 to 03:07 (`gates/flake-check-1.log`, `-2.log`; the second started at `f9c41fe5c`) |
| The TODO gate | `bash scripts/check-todo-system.sh`: rc 0 before and after; entry drifts 133 and 133; unharvested reports 94 and 93; open queue rows 3555 and 3554 |
| The annotations | `go run …/annotate.go prose` and `rows` as listed in Appendix B; `check-rows` over the five touched reports: "5 file(s) complete" |

**NOT verified here:**

- **No deploy.** Generation 1033 (installed 2026-11-27 10:25) still runs the files of that morning. Everything of this session is in the tree: v6, both lint rules, the drift verdict, the AGENTS.md text. The post-deploy dashboards line has never run on the live host, and the provisioner has not yet skipped v6.
- **Gatus.** Its API answers 401 to an agent. Both conditions of "ai-meter viewer" were read by hand at 02:08; the verdict of gatus itself was not read.
- **The other nine dashboards were not rendered after their change.** They went through the API (ten PUTs, each read back identical) and the lint; only ai-meter and two probe charts were looked at in a browser.
- **The boot-mirror race rests on the files and the journal, not on the installer's source.** I did not read the `systemd-boot` binary; the temporary name, the equal size and mtime of the two files and the order of the journal lines are the evidence. The PID-1 inotify watch was not re-verified, and no reboot happened, so the bless-boot watch is open.
- **Upstream.** The fix for the race is not written; nixos-modules was read, not changed.
- **The nightly negative-test workflow** is red on authentication; no log names any group.
- **`buildflow -s test-race`** was not run (none of the dashboard sessions ran it).
- **The I/O storm** (io PSI `some` 38 to 60 % all session) was not investigated; it is other sessions' work.
- **The four queue rows the 17-59 report cited by line number** cannot be resolved today; they stay open.
- **The docs-gates battery** was started at 03:08 and had not answered when this report was written.

## TL;DR

- **The boot mirror was the top hazard of the 16-54 report and is repaired.** One sync took 0.71 s; the mirror equals `/boot`; the boot-chain audit reads 20 passed, 0 failed. The cause is a new defect: a sync that a gen-install triggers copies the installer's temporary file and misses the rename, and nothing retries. Rule and evidence are in AGENTS.md and `docs/agents/systemd.md`; the fix is queued.
- **The ai-meter dashboard has a sixth version, live.** A new tile "Avg Gate Wait" says why "Avg TTFT" is red: under the 270 s budget 73 % of the calls wait at the gate (median 26 s) while the provider answers in 2.4 s. "Unauthorized (24h)" was orange for 100 % of two days over one stray call; it is "Bad Keys (24h)" now and carries no color below 10.
- **Two lint rules.** Tile titles of two-column tiles are held to 17 characters (1280 px, measured), and every line chart must break at empty intervals: the chart default drew a straight hour-long ramp where a model had no calls, in all ten dashboards. All 62 line charts are changed and live.
- **Everything the owner's list asked that needs no deploy is done and verified:** 44 of 44 negative legs, formatters, shellcheck, deadnix, statix, the all-systems flake check twice, the TODO gate clean, four old reports annotated, the queue one row smaller.

## a) FULLY DONE

All of it is in daemon `chore: auto-commit` commits (I made no commits; harness rule). The names below are those commits.

1. **Boot mirror repaired and root-caused** (`95a94cb8e` for the rule text, `7c28a543a` for its row). Restart at 01:32:58; parity read twice; `pre-reboot-check` 20 / 5 / 0. The deaf-trigger fix is proven live by the same journal (two path-triggered syncs, no restart). The new rule in AGENTS.md and `docs/agents/systemd.md`: after any gen-install outside deploy.sh, restart the sync AND read the result; a failed sync unit right after a gen-install is a stale mirror.
2. **The 270 s wait budget read** (measurements in the scope line). Not admitted has one shape left: the quota circuit (241 of 10,758 calls). Quota windows ran out three times (resets 11:52, 16:52 and 21:54 CET).
3. **Dashboard v6** (`7daf05969`, `278eb87fd`, `3e92097ba`): the Latency row has four tiles of three columns, with "Avg Gate Wait" beside "Avg TTFT"; "Bad Keys (24h)" is orange past 10 and red past 100; five tiles carry names that fit a 1280 px window ("Not Admitted/min", "Bad Keys (24h)", "Spans Lost (24h)", "Rate 429s (24h)", "Quota 429s (24h)"); the "Requests by Model x Code" legend names the status first; the texts of "Not Admitted / min" and "Not Admitted (5m)" name the two shapes (a contended gate, a spent window); "Not Metered" says where its single calls come from; the reading guide has a paragraph on the queue inside the first-token time.
4. **Line charts break at empty intervals** (`278eb87fd`, `996fae96c`): `chartAppearance.spanGaps` in threshold mode with 15 minutes on all 62 line charts of the ten dashboards; the lint refuses the default (four selftest legs, two negative legs).
5. **Tile titles at 1280 px** (`7daf05969`): the lint's limit went from 22 to 17; seven tiles renamed (five in ai-meter, two in telemetry-coverage: "Logs Stale", "Logs Age (s)"); the live page at 1280 px has no cut tile title.
6. **Live equals tree for all ten dashboards.** Ten PUTs between 02:07 and 02:10, each read back identical. `pool-storage.json` adopted three tile positions that someone had moved by hand in the live dashboard at 12:33 on 2026-11-27 (`278eb87fd`); without that the next deploy would have put them back.
7. **"Streaming 200s without a usage block" is answered.** The clients cancel their streams after the first token; it is not a proxy defect. The count is 2 of 10,458 calls in 15 hours.
8. **Docs** (`ea0712b2f`, `95a94cb8e`, `6f2dd16c7`, `a4aefd40e`): `docs/services/ai-meter.md` (section table, tile list, the budget's measured effect, the embeddings rule, the viewer's range, the explorer link, the post-deploy verdict, four new "where each number comes from" bullets); `docs/agents/monitoring.md` (builder precision and step floor, validator against query API, align before comparing, tile titles at 1280 px, line charts at empty intervals, read the colors back); `docs/agents/systemd.md` (the lost-write race); `docs/agents/shell-devtools.md` (yolo blocks `env` and `xargs`; two stdin traps; the edit tool's refusal); `AGENTS.md` (the boot-mirror paragraph and the post-deploy row of the prevention table); three `CHANGELOG.md` entries.
9. **TODO bookkeeping** (`7c28a543a`, `a4aefd40e`): closed on both surfaces "SigNoz provisioning idempotency", "Fix the DEAF boot-mirror path trigger" and "Boot-mirror deaf-trigger FIX+DEPLOY chain"; closed the umbrella row "ai-meter follow-ups: gemini-via-proxy verification, hermes wiring, SigNoz dashboard" (its two open parts have their own rows); one title on both surfaces ("Owner visual check: ai-meter.home.lan embedded dashboard renders (LAN + off-LAN forward-auth path)", now narrowed to the off-LAN half); three new queue rows with their library twins (the lost-write race, the red-tile census command, the dashboard round-trip command); seventeen library-only rows in `monitoring.md` and `ai-stack.md` and one in `storage.md` (the natural-reboot bless watch); a premise note on "ai_meter_metering_errors_total increasing rule" (its counter's only source today is cancelled streams).
10. **Annotations** (`8bb213d78`, `2cc1d8574`, `f9c41fe5c`, `68ed2e7a0`): the 17-59 report's 15 follow-ups (13 struck, 2 routed); the 05-39 report's §b, §c, §f and §g (42 verdicts, 5 left open on purpose); the 23-28 report's claim that the `failed` column is inaccurate, corrected in its three places; the 06-25 report points at its successors; the 16-54 report's 32 follow-ups (13 struck, 19 routed) and its three questions.
11. **Gates on the final tree:** see the scope line. Scratch is cleaned (`sandbox` 134 MB and `helium-profile` 264 MB in the trash, after the last render).

## b) PARTIALLY DONE

1. **v6 and the nine other dashboards are live by hand PUTs, not by a deploy.** Works now; the running generation still carries the previous files, so a provisioner restart of generation 1033 puts them back, and `post-deploy-check.sh` reads ten dashboards as drift until the next deploy. Blocker: the deploy battery (I/O storm, other sessions' waves). Effort: one deploy.
2. **The post-deploy dashboards verdict** (`scripts/lib/signoz-dashboards-drift.sh`): in tree, 9 of 9 fixtures, wired, negative legs green; never ran on the live host. Blocker: the next deploy. Effort: S, then.
3. **The boot-mirror race:** repaired and explained; the fix is not written. It lives upstream (`nixos-modules`, `modules/boot-mirror`): settle and retry the mirror and verify legs while the source still changes, a trigger that bounds staleness, a watch on `loader.conf`. Blocker: an upstream change and a push, which I do not do. Effort: M.
4. **Provider time against queue time:** the dashboard half is done (the gate-wait tile); the metric half needs the proxy to export the provider's own first-token time (row in `docs/todo/ai-stack.md`). Effort: M, in the ai-meter repository.
5. **The nightly negative-test workflow:** the legs pass locally; the workflow is red on authentication. Blocker: the owner's token step (plan v6 T02).
6. **`buildflow -s test-race`:** not run by any dashboard session. Effort: S at a quiet moment.

## c) NOT STARTED

1. **The deploy of this tree.** Not fired by me: io PSI `some` read 38 to 60 % all session, and the standing rule is never to force the pressure gate. Path: `scripts/deploy-when-quiescent.sh --fire`. It carries: v6, the lint rules, the drift verdict, the boot-mirror rule, and the siblings' waves since 10:27.
2. **The repo commands** (dashboard round trip, red-tile census with a weekly run, alert replay): rows exist; nothing written. They need Go or shell, because `scripts/` carries no Python.
3. **The proxy proposals** (outcome counter, window counters from the ledger, provider first-token time, quota reset time, tokens of a cancelled stream, SigNoz model pricing): rows in `docs/todo/ai-stack.md`.
4. **Four owner decisions:** the dashboard builder; whether a spent usage window should page; a reference price for `syn:large:text`; keep, repair or retire the `bge-m3` route (it serves again: 1,592 of 1,622 calls since the 10:27 deploy).
5. **Boot-mirror observability** (the existing row: parity collector, rule, gatus check) and **the boot-entry anchor check on the second ESP** (the existing row). Today's 15 hours would have been visible with the first.

## d) TOTALLY FUCKED UP

1. **The mirror of the boot disk served a previous generation for 15 hours, and no check said so.** Severity: a reset in that window booted generation 1032 (the 270 s budget, the repaired failure-rate rule and every wave of 2026-11-27 gone). Root cause: the path-triggered sync copied the installer's temporary file and missed the rename and `loader.conf`; the diff gate refused and paged at 10:29:06; nothing and nobody retried. Mitigation: repaired; rule written; fix queued. Still open: nothing watches parity (the queued observability row).
2. **Every line chart of every dashboard joined whatever two points it had.** A model with a call at 00:25 and the next at 01:20 had a straight ramp across the hour. Fixed and live; it had been there since each dashboard was written.
3. **My own slips this session, each caught by a check, none shipped:** (a) the first layout adoption for `pool-storage.json` moved the wrong tile and escaped a non-ASCII character; the overlap assertion and the diff caught it, redone from HEAD; (b) three wrong nestings of the gap-rule fixtures cost three selftest builds; (c) a `python3 - <<EOF` script fed by a pipe read no rows (the heredoc takes stdin); (d) a typed `xargs` was blocked minutes after I had written the bullet that says so; (e) a "backup" taken in the same tool batch as the edit it was meant to precede; (f) the 32-row annotation was first invoked with an empty argument and wrote nothing; (g) the bookkeeping script's first run failed its own assertion on a non-chart panel before writing anything.
4. **Hand PUTs cut both ways.** Before updating `pool-storage` I compared live against the previous file revision and found a live edit (three tile positions, 12:33) that the file did not have. The other eight were equal to their previous revision. A PUT without that comparison would have erased it.
5. **Gatus cannot be read by an agent** (401 on the loopback API), so "the check is green" is a by-hand statement every time.
6. **A wrong hash in the 23-28 report.** It cites `a0d5ef4cd` for "v4 and the alert rules in the tree"; that commit holds one status report. The annotations of the 17-59 report cite the real ones (`0779937ac` for v4, `c83db52b2` for the repaired failure-rate rule and the quota rule).
7. **A process of another session ran at 99 % CPU for eight hours** (`python3 -`, PID 1444024, started about 18:19 on 2026-11-27 in `~/projects/go-taskqueue/internal/webui`, 1.1 MB read in all that time). It was gone at 02:58. Not touched; named here in case its owner missed it.

## e) WHAT WE SHOULD IMPROVE

1. **A sync that a writer triggers must tolerate that writer.** Impact: the class above. Fix: settle and retry upstream, a trigger that bounds staleness, and `loader.conf` in the watched set.
2. **Mirror parity should be a metric with a rule.** Impact: 15 invisible hours. Fix: the existing observability row (`boot_mirror_parity_ok`), and the boot-entry anchor check on the second ESP.
3. **Raw `nh os switch` outside deploy.sh skips every post-switch step** (the sync restart, the anchor checks). Fix: either sessions stop doing it, or deploy.sh is the only door; the path trigger alone is not enough.
4. **A dashboard change is done when the page was looked at.** Impact: the ramp and the three cut titles were invisible to the lint and to every query check. Fix: the round-trip command with the kept-copy render as its last gate (row), and a weekly census of tile colors (row).
5. **Gatus results where agents can read them.** Fix: a read-only token for scripts, or the results in a textfile collector.
6. **The dashboard pipeline lives in scratch.** Fix: the round-trip command (row) and the builder decision (owner).

## f) NEXT (ordered)

**Harvested at authoring time:** every item below is a row; the third column names it.

| # | Task | Where it lives | Impact | Effort | Category |
| --- | --- | --- | --- | --- | --- |
| 1 | Deploy this tree; read the provisioner's skip of `systemnix-ai-meter` and the first live run of the dashboards verdict | `docs/todo/monitoring.md` "After the next deploy: the provisioner skips systemnix-ai-meter and the post-deploy dashboards line reads 10 of 10" | Critical | S | Bug |
| 2 | Boot-mirror lost-write race: upstream settle-and-retry and a staleness bound, float, deploy, prove under load | queue, `docs/todo/storage.md` | Critical | M | Bug |
| 3 | Boot-mirror parity as a metric with a rule; anchor check on the second ESP | queue, `docs/todo/monitoring.md` and `docs/todo/pipeline.md` (existing rows) | High | M | Feature |
| 4 | At the first natural reboot: bless-boot marks the boot good and the mirror syncs with no restart | `docs/todo/storage.md` (watch) | High | S | Verification |
| 5 | Repo command for the red-tile census, and a weekly run | queue, `docs/todo/monitoring.md` | Medium | S | Quality |
| 6 | Repo command for the dashboard round trip with the kept-copy render | queue, `docs/todo/monitoring.md` | Medium | M | Quality |
| 7 | Proxy: provider first-token time, quota reset time, outcome counter, window counters, tokens of a cancelled stream | `docs/todo/ai-stack.md` | Medium | M | Feature |
| 8 | Four owner decisions (builder, spent-window paging, `syn:large:text` price, `bge-m3` route) | `docs/todo/monitoring.md`, `docs/todo/ai-stack.md` | Medium | S | Decision |
| 9 | Repo command to replay an alert expression over history; lint for the reading guide's links; Success Rate names the provider; 24-hour spend per model | `docs/todo/monitoring.md` | Low | S | Quality |
| 10 | `buildflow -s test-race` at a quiet moment | this report only | Low | S | Quality |

## g) QUESTIONS

1. **The deploy.** The tree holds v6, both lint rules, the drift verdict and the boot-mirror rule; generation 1033 runs the files of 2026-11-27 10:25; io PSI `some` read 60 % at 02:58. Do you want me to fire `scripts/deploy-when-quiescent.sh --fire` once the box calms (it waits for quiescence and never forces the pressure gate), or is another session's deploy carrying the tree?
2. **The pool-storage dashboard.** Someone moved three tiles in the live dashboard at 12:33 on 2026-11-27; I adopted those positions into the file so that the next deploy keeps them. If that edit was a mistake, the file is the place to undo it.
3. **The weekly census and the round-trip command** are queued as two rows. They need Go or shell under `scripts/`; say if you would rather have them as Nix.

## Appendix A: the numbers behind §a 2 and §a 3

- Ledger window 2026-11-27T09:28:02Z to 2026-11-28T00:39:37Z (15.2 h), 10,758 rows: served 10,450, not admitted 241 (`circuit` 241, `timeout` 0), failed 65 (llama-embeddings 503 ×28, z.ai 429 ×21, z.ai 499 ×11, llama-chat 502 ×4, z.ai 502 ×1), served without usage 2.
- Served streaming calls with a first-token sample at z.ai, 8,840: time to first token median 29.7 s, ninth decile 53.6 s; gate wait median 26.4 s, ninth decile 50.1 s; provider time (first token minus the call's own wait) median 2.4 s, ninth decile 5.2 s; 81.6 % of them waited more than 10 s.
- ai-meter journal since 10:27:52: "usage quota exhausted" three times (resets 11:52, 16:52, 21:54 CET); allowance changed 74 times (37 down, 37 up) between 5 and 8.
- Tiles over 15 h at five-minute steps: Success Rate green 96.4 %, orange 2.4 %, red 1.2 %; Failures never red; Not Admitted/min red 1.1 %, orange 0.6 %; Avg TTFT red 52.8 %, orange 4.7 %, no data 42.5 %; Quota Exhausted red 50.8 % (longest 4.0 h); Waiting orange 19.3 %, red 3.3 % (longest 20 min); Not Admitted (5m) red 12.4 % (longest 35 min), orange 1.1 %.
- At 1280 px, probe dashboard: 18 characters fit ("Traced Calls (1h)", "Not Admitted / min", "Not Metered (24h)" of 17, "Rate-Limited (24h)"), 21 and more are cut; "Www Mmm Www Mmm" (15 wide letters) is cut at 147 px of 121.
- Gap probe, "Avg TTFT by Model" at 1500 px: default joins 00:25 to 01:20; threshold 10m breaks it and keeps the short lulls joined; points alone show the dots and still the line.

## Appendix B: commands that worked here

```bash
# boot mirror
sudo -n diff -rq /boot/loader/entries /boot-mirror/loader/entries
sudo -n systemctl restart boot-mirror-sync.service
sudo -n diff -rq -x random-seed /boot/loader /boot-mirror/loader
nix run .#pre-reboot-check
# the budget
cd ~/.cache/aimeter/r2 && sudo -n tail -n 900000 /var/lib/ai-meter/usage.jsonl | python3 ledger-window.py --since='2026-11-27T09:28:00Z' --group=upstream
sudo -n tail -n 900000 /var/lib/ai-meter/usage.jsonl | python3 ledger-durations.py --since='2026-11-27T09:28:00Z'
python3 red-census.py v6-target.json --hours=15          # colors of every threshold tile
python3 tile-stats.py v6-target.json --start=<epoch> "Avg TTFT" "Avg Gate Wait"   # value distributions
# the dashboard
python3 build.py ./v6-raw.json && REPO_ROOT=/home/lars/projects/SystemNix ./render.sh "$PWD/v6-raw.json" "$PWD/v6-rendered.json"
python3 verify.py v6-rendered.json
python3 normalize.py fetch v6-rendered.json v6-dump.json && python3 normalize.py emit v6-dump.json v6-normalized.json
REPO_ROOT=/home/lars/projects/SystemNix ./render.sh "$PWD/v6-normalized.json" "$PWD/v6-target.json"
python3 dryrun.py v6-target.json [--keep]                # validator; a kept copy for a render
node shot.mjs "https://signoz.home.lan/dashboard/<id>" out --width 1280 --height 7600 --settle-ms 9000 --expr truncation-expr.js
python3 title-probe.py create | delete                  # the 1280 px title probe
python3 gap-probe.py create | delete                    # PANEL=<slug> python3 gap-probe.py create
python3 put.py v6-target.json && python3 put.py v6-target.json --check-only
python3 put-generic.py <slug> <file.json> [--check-only]
# gates
nix build .#checks.x86_64-linux.signoz-query-lint .#checks.x86_64-linux.signoz-dashboard-lint-selftest .#checks.x86_64-linux.post-deploy-signoz-dashboards-selftest --no-link -L
CASES=aimeter,signozdash,signoz bash scripts/negative-test-lints.sh
nix fmt -- <files> --fail-on-change
nix flake check --no-build --all-systems --keep-going
bash scripts/check-todo-system.sh
# annotations (docs-health writer)
cd /home/lars/projects/SKILLS/docs-health/assets && go run annotate.go prose [--dry-run] <file> "## f)" '<n>:<kind>:<verdict>'...
go run annotate.go rows [--dry-run] --section "## f)" <file> '<n>:<kind>:<verdict>'...
go run annotate.go check-rows <file>...
```

Traps met: `python3 - <<'EOF'` cannot read a pipe (write the script to a file); a typed `xargs` and `env` are blocked in a yolo session; the edit tool refuses a file changed since its last view (view again); take backups before the edit call.

## Appendix C: what changed in the tree (all daemon-committed)

| Commit | Files |
| --- | --- |
| `7daf05969` | `ai-meter.json` (v6 first form), `telemetry-coverage.json` (two titles), `lib/signoz-dashboard-lint.nix` (limit 17), `flake/parts/checks/lint-static.nix`, `scripts/negative-test-lints.sh` |
| `278eb87fd` | `ai-meter.json` (v6 with gap-breaking), eight other dashboards (gap-breaking), `pool-storage.json` (three positions) |
| `996fae96c` | `lib/signoz-dashboard-lint.nix` (gap rule), `flake/parts/checks/lint-static.nix` (four legs), `scripts/negative-test-lints.sh` (two legs) |
| `ea0712b2f` | `docs/services/ai-meter.md` |
| `95a94cb8e` | `docs/agents/monitoring.md`, `docs/agents/systemd.md`, `AGENTS.md` |
| `6f2dd16c7` | `flake/parts/checks/lint-static.nix`, `flake/parts/checks/selftests.nix`, `lib/signoz-dashboard-lint.nix` (formatter), `AGENTS.md`, `CHANGELOG.md`, `docs/agents/shell-devtools.md` |
| `3e92097ba` | `ai-meter.json` (legend order) |
| `7c28a543a` | `TODO_LIST.md`, `docs/todo/{monitoring,ai-stack,storage,services}.md` |
| `a4aefd40e` | `TODO_LIST.md` (umbrella row), `docs/agents/shell-devtools.md` |
| `8bb213d78`, `2cc1d8574`, `f9c41fe5c`, `68ed2e7a0` | the five annotated status reports |
