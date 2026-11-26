#!/usr/bin/env bash
# session-start-probe.sh — the three facts a session should know before it
# claims work (masterplan v6 T10). Read-only; always exits 0.
#
#   1. CI: the last green date per GitHub workflow, with the class of the
#      latest failure (--logs fetches the failed-step logs; off by default
#      because one log can be tens of megabytes). A workflow that is not
#      green is not a gate: do not cite it as one.
#   2. Backlog: open rows now and 7 days ago, the 7-day flow, the block
#      share and the TODO gate's WARN counts (scripts/backlog-flow.sh).
#   3. Pool and failed units: the daily budget spent, the outcomes of this
#      repo's pool tasks over 7 days, and `systemctl --failed`.
#
# Every probe degrades to a WARN line when its tool is missing, blocked or
# unauthenticated (gh without a login, no tq database, systemctl refused in a
# sandboxed shell). A probe that cannot fail cannot be cited as a gate
# either: it reports, the reader judges.
#
# Usage:
#   scripts/session-start-probe.sh [REPO] [--logs] [--tq-db PATH]
#   scripts/session-start-probe.sh --selftest
#
# REPO defaults to the directory above scripts/. The pool's project name is
# the repository directory name; --tq-db overrides the default database path
# of the tq pool module (/mnt/pool/services/tq/tq.db, absent = skipped).
set -euo pipefail

if [ "${1:-}" = "--selftest" ]; then
  exec python3 - "${BASH_SOURCE[0]}" <<'SELFTEST_EOF'
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile

script = sys.argv[1]
# Resolved before the PATH is narrowed to stubs: the probe and its stubs run
# through this bash even when no other tool is reachable.
BASH = shutil.which("bash")
PYTHON = shutil.which("python3")


def run(cmd, env=None, path=None):
    environment = dict(os.environ)
    if env:
        environment.update(env)
    if path is not None:
        environment["PATH"] = path
    return subprocess.run(cmd, capture_output=True, text=True, env=environment)


def fail(message, output=""):
    sys.exit(f"SELFTEST FAIL: {message}\n{output}")


def expect(condition, message, output=""):
    if not condition:
        fail(message, output)


def write_stub(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)
    os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


with tempfile.TemporaryDirectory(prefix="session-start-probe-selftest-") as scratch:
    bin_dir = os.path.join(scratch, "bin")
    bare = os.path.join(scratch, "bare-bin")
    repo = os.path.join(scratch, "repo")
    os.makedirs(bin_dir)
    os.makedirs(bare)
    for directory in (bin_dir, bare):
        os.symlink(BASH, os.path.join(directory, "bash"))
        os.symlink(PYTHON, os.path.join(directory, "python3"))
    os.makedirs(os.path.join(repo, ".github", "workflows"))
    os.makedirs(os.path.join(repo, "scripts"))
    for name in ("green.yml", "red-auth.yml", "red-content.yml", "never-ran.yml"):
        write_stub(os.path.join(repo, ".github", "workflows", name), "name: fixture\n")
    write_stub(os.path.join(bin_dir, "gh"), '''#!/usr/bin/env bash
case "$*" in
  "auth status") exit 0 ;;
  *"--status success"*"green.yml"*) echo '[{"createdAt":"2026-11-20T10:00:00Z","databaseId":"g1"}]' ;;
  *"--status success"*) echo '[]' ;;
  *"run view g1"*) echo "step	all good" ;;
  *"run view r1"*) echo "step	error: Failed to fetch git repository 'ssh://git@github.com/LarsArtmann/audiblesync'" ;;
  *"run view c1"*) echo "step	FAIL: secrets found in git history" ;;
  *green.yml*) echo '[{"conclusion":"success","createdAt":"2026-11-20T10:00:00Z","databaseId":"g1"},{"conclusion":"success","createdAt":"2026-11-18T10:00:00Z","databaseId":"g0"}]' ;;
  *red-auth.yml*) echo '[{"conclusion":"failure","createdAt":"2026-11-21T10:00:00Z","databaseId":"r1"},{"conclusion":"success","createdAt":"2026-06-01T10:00:00Z","databaseId":"r0"}]' ;;
  *red-content.yml*) echo '[{"conclusion":"failure","createdAt":"2026-11-22T10:00:00Z","databaseId":"c1"}]' ;;
  *never-ran.yml*) echo '[]' ;;
  *) echo "stub gh: unexpected arguments: $*" >&2; exit 3 ;;
esac
''')
    write_stub(os.path.join(bin_dir, "tq"), '''#!/usr/bin/env bash
case "$*" in
  "stats --project repo --json --db "*)
    echo '{"budget":{"spent_today":3},"consumer_lag":[{"consumer":"readmodel","seq":100,"lag":14654}]}' ;;
  "tasks --project repo --since 168h --limit 5000 --json --db "*)
    echo '[{"status":"completed","type":"agent"},{"status":"cancelled","type":"agent"},{"status":"pending","type":"review"},{"status":"dead","type":"status"},{"status":"completed","type":"review"}]' ;;
  *) echo "stub tq: unexpected arguments: $*" >&2; exit 3 ;;
esac
''')
    write_stub(os.path.join(bin_dir, "systemctl"), '''#!/usr/bin/env bash
echo '● inboxclean-sync.service loaded failed failed InboxClean - incremental Gmail sync'
echo '● service-health-check.service loaded failed failed Check critical services and notify on failure'
''')
    flow = {"head": "abc1234", "head_date": "2026-11-26T01:00:00+01:00",
            "revisions": [{"name": "now", "open": 3558, "ticked": 328, "tags": {"ready": 2428}},
                          {"name": "7d", "open": 3420, "ticked": 216, "tags": {"ready": 2312}}],
            "windows": [{"name": "7d", "added_open": 241, "added_closed": 20, "removed": 11, "ticked": 92, "reopened": 0, "net_open": 138}],
            "block": {"day": "2026-11-07", "open_now": 1504, "share_pct": 42.3},
            "gate": {"exit": 0, "unharvested_reports": 103, "queue_library_drifts": 133}}
    write_stub(os.path.join(repo, "scripts", "backlog-flow.sh"),
               "#!/usr/bin/env bash\necho '" + json.dumps(flow).replace("'", "") + "'\n")
    tq_db = os.path.join(scratch, "tq.db")
    open(tq_db, "w", encoding="utf-8").close()
    env_path = bin_dir
    base = [BASH, script, repo, "--tq-db", tq_db]
    result = run(base, path=env_path)
    out = result.stdout
    expect(result.returncode == 0, "the probe exits 0", out + result.stderr)
    for needle in (
        "1. CI",
        "green.yml",
        "2026-11-20",
        "1 of 4 workflows green, 2 red, 1 never ran",
        "never-ran.yml",
        "3. Pool and failed units",
        "budget spent today: 3",
        "cancelled 1, completed 2, dead 1, pending 1",
        "read model trails the journal by 14654 facts",
        "failed units: 2",
        "inboxclean-sync.service",
        "2. Backlog",
        "open rows now 3558 (ready 2428)",
        "7 days ago 3420, net +138 in 7 days",
        "block (rows added on 2026-11-07): 1504 open = 42.3 % of the open queue",
        "gate WARNs: 103 unharvested",
    ):
        expect(needle in out, f"the report must contain: {needle}", out)
    expect(out.count("WARN:") == 1, "a fully stubbed run prints only the read-model WARN", out)

    result = run(base + ["--logs"], path=env_path)
    out = result.stdout
    expect(result.returncode == 0, "the probe with --logs exits 0", out)
    expect("auth/fetch of a private input" in out and "content: secrets in history" in out,
           "--logs classifies the latest failure of each red workflow", out)
    expect(out.count("not read (use --logs)") == 0, "--logs leaves no unclassified red workflow", out)
    expect("1 of the 2 red workflows fail on auth/fetch" in out, "--logs counts the auth class", out)
    out = run(base, path=env_path).stdout
    expect("not read (use --logs)" in out, "without --logs the class of a failure is not guessed", out)

    write_stub(os.path.join(bin_dir, "gh"), "#!/usr/bin/env bash\n exit 1\n")
    result = run(base, path=env_path)
    out = result.stdout
    expect(result.returncode == 0, "an unauthenticated gh must not fail the probe", out + result.stderr)
    expect("WARN:" in out and "CI section skipped" in out, "an unauthenticated gh prints a WARN and skips the section", out)

    result = run(base, path=bare)
    out = result.stdout
    expect(result.returncode == 0, "a shell without gh, tq and systemctl must not fail the probe", out + result.stderr)
    expect(out.count("WARN:") >= 3 and "3. Pool and failed units" in out, "each missing tool degrades to a WARN", out)

    result = run(base, path=bare, env={"PROBE_TIMEOUT_SECONDS": "1"})
    expect(result.returncode == 0, "a slow tool must time out into a WARN, never a failure", result.stdout)

print("SELFTEST OK: CI last-green and failure classes (--logs), WARN on an unauthenticated gh, backlog from backlog-flow.sh, pool budget/outcomes/read-model lag, failed units, every missing tool degrades to WARN, exit 0 always")
SELFTEST_EOF
fi

exec python3 - "${BASH_SOURCE[0]}" "$@" <<'EOF'
import datetime
import glob
import json
import os
import re
import subprocess
import sys

DEFAULT_TQ_DB = "/mnt/pool/services/tq/tq.db"
AUTH_SIGNATURES = (
    "Failed to fetch git repository", "Repository not found", "could not read Username",
    "nix eval of input outPaths failed", "Resource not accessible by integration", "Bad credentials",
    "HTTP 401", "HTTP 403", "does not have the correct permissions",
)


def parse_options(argv):
    options = {"repo": None, "logs": False, "tq_db": DEFAULT_TQ_DB}
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--logs":
            options["logs"] = True
        elif arg == "--tq-db":
            options["tq_db"] = argv[index + 1] if index + 1 < len(argv) else ""
            index += 1
        elif arg.startswith("-"):
            print(f"session-start-probe: unknown option {arg!r}")
        elif options["repo"] is None:
            options["repo"] = arg
        index += 1
    if options["repo"] is None:
        options["repo"] = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1])))
    return options


def call(cmd, timeout):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (subprocess.TimeoutExpired, OSError):
        return None


def gh(args, timeout):
    return call(["gh", *args], timeout)


def classify(log):
    if "secrets found in git history" in log:
        return "content: secrets in history"
    for signature in AUTH_SIGNATURES:
        if signature in log:
            match = re.search(r"Failed to fetch git repository '([^']+)'", log)
            return "auth/fetch of a private input" + (f" ({match.group(1).rsplit('/', 1)[-1]})" if match else "")
    match = re.search(r"(FAIL: .{0,110}|error: .{0,110}|##\[error\].{0,110})", log)
    return "content: " + match.group(1).strip() if match else "unclassified (read the run log)"


def ci_section(repo, logs, timeout):
    print("1. CI: last green per workflow (gh run list, the last 100 runs per workflow)")
    workflows = sorted(os.path.basename(path) for path in glob.glob(os.path.join(repo, ".github", "workflows", "*.yml")))
    if not workflows:
        print("   no .github/workflows directory: nothing to read")
        return
    status = gh(["auth", "status"], timeout)
    if status is None or status.returncode != 0:
        print(f"   WARN: gh is not usable or not authenticated ({'timed out' if status is None else 'exit ' + str(status.returncode)}) — CI section skipped; "
              "no workflow may be cited as green on this evidence")
        return
    def workflow_row(workflow):
        """(name, last green date, runs, failures, verdict) for one workflow; gh calls run in parallel."""
        listing = gh(["run", "list", "--workflow", workflow, "--limit", "100", "--json", "conclusion,createdAt,databaseId"], timeout)
        if listing is None or listing.returncode != 0:
            return (workflow, None, 0, 0, "unclassified (gh run list failed)")
        try:
            runs = json.loads(listing.stdout)
        except ValueError:
            runs = []
        failures = [run for run in runs if run.get("conclusion") == "failure"]
        greens = [run for run in runs if run.get("conclusion") == "success"]
        last_green = greens[0]["createdAt"][:10] if greens else None
        if not runs:
            return (workflow, None, 0, 0, "never ran")
        if not greens:
            older = gh(["run", "list", "--workflow", workflow, "--status", "success", "--limit", "1", "--json", "createdAt"], timeout)
            if older is not None and older.returncode == 0:
                try:
                    found = json.loads(older.stdout)
                except ValueError:
                    found = []
                last_green = found[0]["createdAt"][:10] if found else None
        if not failures or failures[0] is not runs[0]:
            return (workflow, last_green, len(runs), len(failures), "green")
        verdict = "not read (use --logs)"
        if logs:
            log = gh(["run", "view", str(failures[0].get("databaseId")), "--log-failed"], max(timeout, 120))
            verdict = classify(log.stdout + log.stderr) if log is not None else "unclassified (the log fetch failed)"
        return (workflow, last_green, len(runs), len(failures), verdict)

    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(max_workers=6) as pool:
        rows = list(pool.map(workflow_row, workflows))
    green = sum(1 for row in rows if row[4] == "green")
    red = sum(1 for row in rows if row[4] not in ("green", "never ran"))
    never = len(rows) - green - red
    today = datetime.date.today()
    width = max(len(row[0]) for row in rows)
    for workflow, last_green, total, failures, verdict in rows:
        if last_green:
            age = (today - datetime.date.fromisoformat(last_green)).days
            stamp = f"{last_green} ({age} d ago)"
        else:
            stamp = "never"
        print(f"   {workflow.ljust(width)}  green {stamp:<21}  runs {total:>3}, failures {failures:>3}  {verdict}")
    print(f"   -> {green} of {len(rows)} workflows green, {red} red, {never} never ran. A red workflow is not a gate.")
    if logs:
        auth = sum(1 for row in rows if row[4].startswith("auth/fetch"))
        if auth:
            print(f"      {auth} of the {red} red workflows fail on auth/fetch of a private input (owner step: read-only PAT and deploy keys); "
                  "fixing that can uncover content failures underneath.")
    elif red:
        print("      run with --logs to classify the failures (downloads each failed step's log)")


def backlog_section(repo, timeout):
    print()
    print("2. Backlog (scripts/backlog-flow.sh)")
    flow_script = os.path.join(repo, "scripts", "backlog-flow.sh")
    if not os.path.isfile(flow_script):
        print("   WARN: scripts/backlog-flow.sh is missing — backlog section skipped")
        return
    result = call(["bash", flow_script, repo, "--json"], timeout)
    if result is None or result.returncode != 0:
        print("   WARN: scripts/backlog-flow.sh failed or timed out — backlog section skipped")
        return
    try:
        report = json.loads(result.stdout)
    except ValueError:
        print("   WARN: scripts/backlog-flow.sh printed no JSON — backlog section skipped")
        return
    revisions = {entry["name"]: entry for entry in report["revisions"]}
    now = revisions.get("now") or {}
    week = revisions.get("7d") or {}
    flow = next((entry for entry in report["windows"] if entry["name"] == "7d"), None)
    block = report["block"]
    ready = (now.get("tags") or {}).get("ready")
    head = f"open rows now {now.get('open')}" + (f" (ready {ready})" if ready is not None else "")
    if week.get("open") is not None and flow:
        head += (f", 7 days ago {week['open']}, net {'+' if flow['net_open'] >= 0 else ''}{flow['net_open']} in 7 days"
                 f" (+{flow['added_open']} open added, +{flow['added_closed']} added and closed, -{flow['removed']} removed, {flow['ticked']} ticked)")
    print("   " + head)
    print(f"   block (rows added on {block.get('day', '?')}): {block.get('open_now', '?')} open = {block.get('share_pct', '?')} % of the open queue"
          + (f" ({block['pool_visible_now']} visible to the pool)" if "pool_visible_now" in block else ""))
    gate = report.get("gate") or {}
    print(f"   gate WARNs: {gate.get('unharvested_reports', '?')} unharvested section-f reports, "
          f"{gate.get('queue_library_drifts', '?')} queue/library drifts"
          + (f" (gate exit {gate['exit']})" if gate.get("exit") not in (0, None) else " (gate exit 0)"))
    domain = (report.get("domains") or {}).get("now") or {}
    top = ", ".join(f"{os.path.basename(name)} {count}" for name, count in list(domain.items())[:4])
    if top:
        print(f"   largest libraries: {top}")


def pool_section(repo, tq_db, timeout):
    print()
    print("3. Pool and failed units")
    if not os.path.isfile(tq_db):
        print(f"   WARN: no tq database at {tq_db} — pool lines skipped")
    else:
        project = os.path.basename(os.path.abspath(repo))
        stats = call(["tq", "stats", "--project", project, "--json", "--db", tq_db], timeout)
        if stats is None or stats.returncode != 0:
            print("   WARN: tq stats failed or timed out — budget line skipped")
        else:
            try:
                payload = json.loads(stats.stdout[stats.stdout.find("{"):])
            except ValueError:
                payload = {}
            spent = (payload.get("budget") or {}).get("spent_today")
            print(f"   pool budget spent today: {spent if spent is not None else 'unknown'} (project {project}; the pool's cap is 30 a day, shared by its repos)")
            lag = next((entry.get("lag") for entry in payload.get("consumer_lag", []) if entry.get("consumer") == "readmodel"), None)
            if lag:
                print(f"   WARN: the tq read model trails the journal by {lag} facts — `tq stats` counters are empty until it catches up")
        tasks = call(["tq", "tasks", "--project", project, "--since", "168h", "--limit", "5000", "--json", "--db", tq_db], timeout)
        if tasks is None or tasks.returncode != 0:
            print("   WARN: tq tasks failed or timed out — outcome line skipped")
        else:
            try:
                items = json.loads(tasks.stdout[tasks.stdout.find("["):])
            except ValueError:
                items = []
            counts = {}
            for item in items:
                counts[item.get("status", "unknown")] = counts.get(item.get("status", "unknown"), 0) + 1
            line = ", ".join(f"{status} {count}" for status, count in sorted(counts.items()))
            print(f"   {project} pool tasks, last 7 days: {len(items)} ({line})" if line else f"   {project} pool tasks, last 7 days: none")
    failed = call(["systemctl", "--failed", "--no-legend", "--no-pager", "--plain"], timeout)
    if failed is None or failed.returncode != 0:
        print("   WARN: systemctl --failed is unavailable or refused — failed-unit line skipped")
    else:
        units = [line.split()[1] for line in failed.stdout.split("\n") if line.strip().startswith("●")]
        print(f"   failed units: {len(units)}" + (f" — {', '.join(units)}" if units else ""))


def main():
    options = parse_options(sys.argv[2:])
    try:
        timeout = int(os.environ.get("PROBE_TIMEOUT_SECONDS", "30"))
    except ValueError:
        timeout = 30
    repo = options["repo"]
    boot = ""
    try:
        with open("/proc/sys/kernel/random/boot_id", encoding="utf-8") as handle:
            boot = handle.read().strip()[:8]
    except OSError:
        pass
    now = datetime.datetime.now().astimezone().strftime("%Y-%m-%d %H:%M %Z")
    print(f"SESSION START PROBE  repo {repo}  {now}  boot {boot or 'unknown'}")
    print("read-only; every WARN is a probe that could not run, not an empty result")
    ci_section(repo, options["logs"], timeout)
    backlog_section(repo, max(timeout, 60))
    pool_section(repo, options["tq_db"], timeout)


try:
    main()
except Exception as error:  # a probe never fails the session that runs it
    print(f"WARN: the probe itself hit an error and stopped early: {type(error).__name__}: {error}")
sys.exit(0)
EOF
