#!/usr/bin/env bash
# backlog-flow.sh — census and flow of the TODO queue, read from git history.
#
# One command answers "where does the queue stand and how does it move", so
# the Pareto of the backlog stays measurable instead of resting on an ad hoc
# diff analysis (masterplan v6 T11). It reads git objects and the TODO gate
# only; it never writes.
#
#   open rows at five revisions (now, 7 days, 30 days, the day before and the
#     day after the block day), per lifecycle tag
#   row events per window (7 days, 30 days, since the day before the block):
#     added, added-and-already-closed, removed, ticked, reopened, net
#   per-tag flow, open rows per linked library
#   the block: rows whose line was ADDED to TODO_LIST.md on the block day
#     (default 2026-11-07, the bulk harvest): how many are still open, what
#     share of the open queue they hold, per library and per source month
#   the gate's WARN counts (unharvested §f reports, queue/library drifts)
#   the block rows' shape: body length class, pairing with the linked
#     library, and an optional seeded sample (--sample N --seed S) so a
#     staleness read is reproducible
#
# Usage:
#   scripts/backlog-flow.sh [REPO] [--json] [--no-gate]
#       [--block-day YYYY-MM-DD] [--rev NAME=REV]... [--window NAME=REV]...
#       [--sample N] [--seed S]
#   scripts/backlog-flow.sh --selftest
#
# REPO defaults to the directory above scripts/. A date-based revision whose
# name matches a --rev switch is replaced; any other --rev NAME adds a row.
# A window starts at its revision and ends at HEAD; --window NAME=REV pins
# one. The selftest builds a throwaway repository whose commits carry fixed
# dates, so every number it asserts is reproducible.
set -euo pipefail

if [ "${1:-}" = "--selftest" ]; then
  exec python3 - "${BASH_SOURCE[0]}" <<'SELFTEST_EOF'
import json
import os
import subprocess
import sys
import tempfile

script = sys.argv[1]


def run(cmd, env=None):
    return subprocess.run(cmd, capture_output=True, text=True, env=env)


def fail(message, output=""):
    sys.exit(f"SELFTEST FAIL: {message}\n{output}")


def expect(condition, message, output=""):
    if not condition:
        fail(message, output)


with tempfile.TemporaryDirectory(prefix="backlog-flow-selftest-") as scratch:
    root = os.path.join(scratch, "repo")
    os.makedirs(os.path.join(root, "scripts"))
    identity = {
        "GIT_AUTHOR_NAME": "selftest", "GIT_AUTHOR_EMAIL": "selftest@example.invalid",
        "GIT_COMMITTER_NAME": "selftest", "GIT_COMMITTER_EMAIL": "selftest@example.invalid",
    }
    stamp = run(["git", "init", "-q", root])
    expect(stamp.returncode == 0, "git init failed in the scratch directory", stamp.stderr)

    header = "# Queue\n\n### storage\n\n"
    rows = {
        "old": "- [x] [ready] **Old done row** — done\n",
        "r1": "- [ ] [ready] **R1 pipeline row** — body → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-10-20_10-00_x.md §f.1)\n",
        "r2": "- [ ] [ready] **R2 storage row** — body → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-10-21_10-00_x.md §f.2)\n",
        "r2done": "- [x] [ready] **R2 storage row** — body → [docs/todo/storage.md](docs/todo/storage.md) (Source: docs/status/2026-10-21_10-00_x.md §f.2)\n",
        "r3": "- [ ] [blocked:deploy] **R3 deploy row** — body → [docs/todo/services.md](docs/todo/services.md)\n",
        "r4": "- [ ] [decision] **R4 decision row** — body\n",
        "b1": "- [ ] [ready] **B1 block row** — body → [docs/todo/services.md](docs/todo/services.md) (Source: docs/status/2026-09-05_10-00_x.md §f.3)\n",
        "b1done": "- [x] [ready] **B1 block row** — body → [docs/todo/services.md](docs/todo/services.md) (Source: docs/status/2026-09-05_10-00_x.md §f.3)\n",
        "b2": "- [ ] [ready] **B2 block row** — body → [docs/todo/services.md](docs/todo/services.md) (Source: docs/status/2026-10-30_10-00_x.md §f.4)\n",
        "b3": "- [ ] [watch] **B3 block watch row** — body → [docs/todo/monitoring.md](docs/todo/monitoring.md) (Source: docs/status/2026-09-06_10-00_x.md §f.5)\n",
        "b4": "- [ ] [ready] **B4 title-only block row** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-10-02_10-00_x.md §f.6)\n",
        "b4done": "- [x] [ready] **B4 title-only block row** → [docs/todo/pipeline.md](docs/todo/pipeline.md) (Source: docs/status/2026-10-02_10-00_x.md §f.6)\n",
        "r5": "- [ ] [blocked:user] **R5 new row** — body\n",
        "r6": "- [ ] [ready] **R6 title-only row** → [docs/todo/pipeline.md](docs/todo/pipeline.md)\n",
        "r7": "- [ ] [ready] **R7 full-body row** — this row carries a body long enough to count as a full row because the class boundary sits at one hundred twenty characters of ask text → [docs/todo/storage.md](docs/todo/storage.md)\n",
    }

    def commit(date, *keys):
        with open(os.path.join(root, "TODO_LIST.md"), "w", encoding="utf-8") as handle:
            handle.write(header + "".join(rows[key] for key in keys))
        done = run(["git", "-C", root, "add", "TODO_LIST.md"], env=dict(os.environ, **identity))
        done = run(["git", "-C", root, "commit", "-q", "-m", "fixture " + date],
                   env=dict(os.environ, GIT_AUTHOR_DATE=date, GIT_COMMITTER_DATE=date, **identity))
        expect(done.returncode == 0, "fixture commit failed", done.stderr)
        return run(["git", "-C", root, "rev-parse", "HEAD"]).stdout.strip()

    pre = commit("2026-11-01T10:00:00 +0100", "old", "r1", "r2", "r3", "r4", "r6", "r7")
    post = commit("2026-11-07T10:00:00 +0100", "old", "r1", "r2done", "r3", "r4", "r6", "r7", "b1", "b2", "b3", "b4")
    head = commit("2026-11-20T10:00:00 +0100", "old", "r1", "r2done", "r4", "b1done", "b2", "b3", "b4done", "r5", "r6", "r7")
    os.makedirs(os.path.join(root, "docs", "todo"))
    with open(os.path.join(root, "docs", "todo", "services.md"), "w", encoding="utf-8") as handle:
        handle.write("# Lib\n\n" + rows["b2"].replace(" — body → [docs/todo/services.md](docs/todo/services.md)", ""))

    command = ["bash", script, root, "--json"]
    result = run(command)
    expect(result.returncode == 0, "the script must exit 0 on a clean fixture", result.stdout + result.stderr)
    try:
        report = json.loads(result.stdout)
    except ValueError:
        fail("stdout must be one JSON document", result.stdout + result.stderr)

    revisions = {entry["name"]: entry for entry in report["revisions"]}
    expect(list(revisions) == ["now", "7d", "30d", "pre-block", "post-block"],
           "five revisions in the default order", result.stdout)
    expect(revisions["now"]["open"] == 7 and revisions["now"]["ticked"] == 4, "open and ticked rows at HEAD", result.stdout)
    expect(revisions["7d"]["sha"] == post[:7], "the 7-day revision is the last commit before HEAD minus 7 days", result.stdout)
    expect(revisions["30d"]["sha"] is None and revisions["30d"]["open"] is None, "a date older than the history yields an empty revision", result.stdout)
    expect([entry["name"] for entry in report["windows"]] == ["7d", "pre-block"], "a window whose start predates the history is skipped", result.stdout)
    expect(revisions["pre-block"]["sha"] == pre[:7] and revisions["post-block"]["sha"] == post[:7], "block edges resolve by date", result.stdout)
    expect(revisions["pre-block"]["open"] == 6 and revisions["pre-block"]["ticked"] == 1, "census at the pre-block revision", result.stdout)
    expect(revisions["post-block"]["open"] == 9 and revisions["post-block"]["ticked"] == 2, "census at the post-block revision", result.stdout)
    now_tags = revisions["now"]["tags"]
    expect(now_tags.get("ready") == 4 and now_tags.get("decision") == 1 and now_tags.get("watch") == 1
           and now_tags.get("blocked:user") == 1 and now_tags.get("blocked:deploy") == 0, "per-tag census at HEAD", result.stdout)

    windows = {entry["name"]: entry for entry in report["windows"]}
    flow = windows["7d"]
    for field, value in {"added_open": 1, "added_closed": 0, "removed": 1, "ticked": 2, "reopened": 0, "net_open": -2}.items():
        expect(flow[field] == value, f"window 7d field {field}: want {value}", result.stdout)
    expect(flow["added_open_by_tag"] == {"blocked:user": 1}, "added rows by tag", result.stdout)
    expect(flow["ticked_by_tag"] == {"ready": 2}, "ticked rows by tag", result.stdout)
    expect(flow["removed_by_tag"] == {"blocked:deploy": 1}, "removed rows by tag", result.stdout)
    since = windows["pre-block"]
    for field, value in {"added_open": 3, "added_closed": 2, "removed": 1, "ticked": 1, "reopened": 0, "net_open": 1}.items():
        expect(since[field] == value, f"window pre-block field {field}: want {value}", result.stdout)
    expect(since["added_open_by_tag"] == {"blocked:user": 1, "ready": 1, "watch": 1}, "a longer window counts the rows it saw being added", result.stdout)

    pinned = {entry["name"]: entry for entry in json.loads(run(["bash", script, root, "--json", "--no-gate", "--window", "7d=" + pre]).stdout)["windows"]}
    expect(pinned["7d"]["added_open"] == 3 and pinned["7d"]["added_closed"] == 2 and pinned["7d"]["net_open"] == 1,
           "--window NAME=REV pins a window start", json.dumps(pinned["7d"]))
    expect(pinned["pre-block"]["added_open"] == 3, "a pinned window leaves the other windows on their dates", json.dumps(pinned["pre-block"]))

    block = report["block"]
    for field, value in {"day": "2026-11-07", "added": 4, "open_now": 2, "share_pct": 28.6, "closed_or_removed": 2,
                         "pool_visible_now": 1, "paired_in_library": 1, "without_library_row": 1, "unlinked": 0}.items():
        expect(block[field] == value, f"block field {field}: want {value}", result.stdout)
    expect(block["by_tag"] == {"ready": 1, "watch": 1}, "open block rows by tag", result.stdout)
    expect(block["by_body"] == {"title only": 0, "short body (under 120 chars)": 2, "full body": 0}, "open block rows by body class", result.stdout)
    expect("sample" not in block, "no sample unless --sample asks for one", result.stdout)
    sampled = json.loads(run(["bash", script, root, "--json", "--no-gate", "--sample", "5", "--seed", "7"]).stdout)["block"]
    expect(sorted(row["title"] for row in sampled["sample"]) == ["B2 block row", "B3 block watch row"], "a sample larger than the block returns every open block row", json.dumps(sampled["sample"]))
    expect(all(isinstance(row["line"], int) and row["line"] > 0 for row in sampled["sample"]) and sampled["sample_seed"] == 7, "sample rows carry their queue line number and the seed", json.dumps(sampled["sample"]))
    expect(block["by_library"] == {"docs/todo/monitoring.md": 1, "docs/todo/services.md": 1}, "open block rows by library", result.stdout)
    expect(block["by_source_month"] == {"2026-09": 1, "2026-10": 1}, "open block rows by source month", result.stdout)
    domains = report["domains"]["now"]
    expect(domains.get("docs/todo/services.md") == 1 and domains.get("docs/todo/monitoring.md") == 1
           and domains.get("docs/todo/pipeline.md") == 2 and domains.get("docs/todo/storage.md") == 1
           and domains.get("(unlinked)") == 2, "open rows per linked library", result.stdout)
    expect(report["gate"] is not None and report["gate"]["unharvested_reports"] == 0, "a repository without the gate script reports an empty gate", result.stdout)

    stub = os.path.join(root, "scripts", "check-todo-system.sh")
    with open(stub, "w", encoding="utf-8") as handle:
        handle.write("#!/usr/bin/env bash\necho 'WARN: 3 unharvested §f-bearing report(s) (CHECK_TODO_HARVEST=strict fails)'\n"
                     "echo 'WARN: 7 queue/library entry drift(s) (CHECK_TODO_PAIRING=strict fails)'\n")
    report = json.loads(run(command).stdout)
    expect(report["gate"] == {"exit": 0, "unharvested_reports": 3, "queue_library_drifts": 7}, "the gate's WARN counts are parsed", json.dumps(report["gate"]))

    moved = run(["bash", script, root, "--json", "--no-gate", "--block-day", "2026-11-01"])
    report = json.loads(moved.stdout)
    expect(report["gate"] is None, "--no-gate leaves the gate empty", moved.stdout)
    expect(report["block"]["added"] == 6 and report["block"]["open_now"] == 4 and report["block"]["share_pct"] == 57.1,
           "--block-day moves the block", moved.stdout)
    expect(report["block"]["by_body"] == {"title only": 1, "short body (under 120 chars)": 2, "full body": 1},
           "body classes: one title-only, two short, one full among the open rows of the moved block", json.dumps(report["block"]["by_body"]))
    expect(report["block"]["without_library_row"] == 3 and report["block"]["unlinked"] == 1 and report["block"]["paired_in_library"] == 0,
           "pairing is recomputed for the moved block", moved.stdout)

    text = run(["bash", script, root, "--no-gate", "--window", "7d=" + pre, "--sample", "2", "--seed", "7"])
    expect(text.returncode == 0, "text mode exits 0", text.stdout + text.stderr)
    for needle in ("Open queue rows per revision", "Flow since each window start",
                   "Block (rows added on 2026-11-07): 4 added, 2 still open (28.6% of the open queue), 2 closed or removed",
                   "pool-visible now (ready or blocked:deploy): 1", "sample (seed 7):", "    L"):
        expect(needle in text.stdout, f"text mode must print: {needle}", text.stdout + text.stderr)

    extra = run(["bash", script, root, "--json", "--no-gate", "--rev", "first=" + pre, "--window", "whole=" + pre])
    report = json.loads(extra.stdout)
    expect([entry["name"] for entry in report["revisions"]][-1] == "first", "an extra --rev NAME adds a revision row", extra.stdout)
    expect([entry["name"] for entry in report["windows"]][-1] == "whole", "an extra --window NAME adds a window row", extra.stdout)

    bad = run(["bash", script, root, "--json", "--rev", "now=no-such-revision"])
    expect(bad.returncode != 0 and "does not resolve" in bad.stderr, "an unknown revision must fail loudly", bad.stderr)
    bad = run(["bash", script, root, "--bogus"])
    expect(bad.returncode != 0 and "unknown option" in bad.stderr, "an unknown option must fail loudly", bad.stderr)
    plain = os.path.join(scratch, "plain")
    os.makedirs(plain)
    bad = run(["bash", script, plain])
    expect(bad.returncode != 0 and "not a git repository" in bad.stderr, "a non-repository must fail loudly", bad.stderr)
    before = run(["git", "-C", root, "status", "--porcelain", "--", "TODO_LIST.md"]).stdout
    expect(before == "", "the script never writes to the queue file", before)

print("SELFTEST OK: date-resolved revisions incl. a too-old date, per-tag census, window flow, per-tag flow, block share by tag, library, source month and body class, pairing, seeded sample, domains, gate WARN counts, --no-gate, --block-day, extra revisions and windows, text mode, loud refusals, read-only")
SELFTEST_EOF
fi

exec python3 - "${BASH_SOURCE[0]}" "$@" <<'EOF'
import collections
import datetime
import json
import os
import random
import re
import subprocess
import sys

QUEUE = "TODO_LIST.md"
POOL_TAGS = ("ready", "blocked:deploy")
ROW = re.compile(r"^- \[([ x])\] (?:\[([^\]]*)\] )?\*\*([^*]+)\*\*")
UNTITLED = re.compile(r"^- \[([ x])\] (.*)$")
LINK = re.compile(r"docs/todo/([a-z0-9-]+)\.md")
MONTH = re.compile(r"(20\d\d-\d\d)-\d\d")
TAGS = ["ready", "blocked:deploy", "blocked:user", "blocked:push", "decision", "watch", "untagged"]
DEFAULT_BLOCK_DAY = "2026-11-07"
UNLINKED = "(unlinked)"
WINDOW_NAMES = ["7d", "30d", "pre-block"]


def fail(message):
    sys.exit(f"backlog-flow: {message}")


def git(repo, *args, check=True):
    result = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    if check and result.returncode != 0:
        fail(f"git {' '.join(args)} failed: {result.stderr.strip()[:200]}")
    return result.stdout


def parse_options(argv):
    options = {"repo": None, "json": False, "gate": True, "block_day": DEFAULT_BLOCK_DAY, "rev": {}, "window": {},
               "sample": 0, "seed": 1}
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg in ("--json", "--no-gate"):
            options["json" if arg == "--json" else "gate"] = arg == "--json"
        elif arg in ("--block-day", "--rev", "--window", "--sample", "--seed"):
            value = argv[index + 1] if index + 1 < len(argv) else ""
            index += 1
            if arg == "--block-day":
                if not re.fullmatch(r"20\d\d-\d\d-\d\d", value):
                    fail(f"--block-day wants YYYY-MM-DD, got {value!r}")
                options["block_day"] = value
            elif arg in ("--sample", "--seed"):
                if not re.fullmatch(r"[0-9]+", value):
                    fail(f"{arg} wants a whole number, got {value!r}")
                options[arg[2:]] = int(value)
            else:
                name, separator, revision = value.partition("=")
                if not name or not separator or not revision:
                    fail(f"{arg} wants NAME=REVISION, got {value!r}")
                options["rev" if arg == "--rev" else "window"][name] = revision
        elif arg.startswith("-"):
            fail(f"unknown option {arg!r}")
        elif options["repo"] is None:
            options["repo"] = arg
        else:
            fail(f"unexpected argument {arg!r}")
        index += 1
    if options["repo"] is None:
        options["repo"] = os.path.dirname(os.path.dirname(os.path.abspath(sys.argv[1])))
    return options


def parse_rows(text):
    """title -> (open?, tag, library, source month, body chars, queue line). A
    title that appears open and ticked in one file counts as open (the ticked
    copy is a leftover). Body chars = the text between the title and the
    library link, dashes stripped: 0 means a title-only row."""
    rows = {}
    for number, line in enumerate(text.split("\n"), 1):
        if not line.startswith("- ["):
            continue
        match = ROW.match(line)
        if match:
            state, tag, title = match.group(1), match.group(2) or "untagged", match.group(3)
            rest = line[match.end():]
        else:
            match = UNTITLED.match(line)
            if not match:
                continue
            state, tag, title = match.group(1), "untagged", match.group(2)
            rest = ""
        if title in rows and rows[title][0]:
            continue
        link = LINK.search(line)
        month = MONTH.search(re.split(r"(?i)source", line)[-1]) or MONTH.search(line)
        body = len(re.split(r" → \[docs/todo/", rest, maxsplit=1)[0].strip(" —-").strip())
        rows[title] = (state == " ", tag, f"docs/todo/{link.group(1)}.md" if link else UNLINKED,
                       month.group(1) if month else "unknown", body, number)
    return rows


def body_class(body_chars):
    if body_chars == 0:
        return "title only"
    return "short body (under 120 chars)" if body_chars < 120 else "full body"


def sorted_counts(values):
    counter = collections.Counter(values)
    return dict(sorted(counter.items(), key=lambda item: (-item[1], str(item[0]))))


def census(rows):
    open_rows = [value for value in rows.values() if value[0]]
    return {
        "open": len(open_rows),
        "ticked": len(rows) - len(open_rows),
        "tags": {tag: sum(1 for value in open_rows if value[1] == tag) for tag in TAGS},
        "other_tags": sorted_counts(value[1] for value in open_rows if value[1] not in TAGS),
    }


def window_flow(start_rows, now_rows):
    added_open = [title for title, value in now_rows.items() if value[0] and title not in start_rows]
    added_closed = [title for title, value in now_rows.items() if not value[0] and title not in start_rows]
    removed = [title for title in start_rows if title not in now_rows]
    ticked = [(title, value) for title, value in start_rows.items() if value[0] and title in now_rows and not now_rows[title][0]]
    reopened = [title for title, value in start_rows.items() if not value[0] and title in now_rows and now_rows[title][0]]
    return {
        "added_open": len(added_open),
        "added_closed": len(added_closed),
        "removed": len(removed),
        "ticked": len(ticked),
        "reopened": len(reopened),
        "net_open": sum(1 for value in now_rows.values() if value[0]) - sum(1 for value in start_rows.values() if value[0]),
        "added_open_by_tag": sorted_counts(now_rows[title][1] for title in added_open),
        "ticked_by_tag": sorted_counts(value[1] for _, value in ticked),
        "removed_by_tag": sorted_counts(start_rows[title][1] for title in removed),
    }


def block_titles(repo, block_day):
    """Titles of open-row lines added to the queue on the block day."""
    titles = set()
    for line in git(repo, "log", "--format=%H%x09%cI", "--no-merges", "--", QUEUE).splitlines():
        commit, _, date = line.partition("\t")
        if not date.startswith(block_day):
            continue
        diff = git(repo, "diff-tree", "-p", "--root", commit, "--", QUEUE)
        for diff_line in diff.split("\n"):
            if diff_line.startswith("+- [ ] "):
                match = ROW.match(diff_line[1:])
                titles.add(match.group(3) if match else diff_line[7:])
    return titles


def gate_counts(repo):
    script = os.path.join(repo, "scripts", "check-todo-system.sh")
    if not os.path.isfile(script):
        return {"exit": None, "unharvested_reports": 0, "queue_library_drifts": 0}
    result = subprocess.run(["bash", script], capture_output=True, text=True)
    output = result.stdout + result.stderr
    unharvested = re.search(r"WARN: (\d+) unharvested", output)
    drift = re.search(r"WARN: (\d+) queue/library entry drift", output)
    return {
        "exit": result.returncode,
        "unharvested_reports": int(unharvested.group(1)) if unharvested else 0,
        "queue_library_drifts": int(drift.group(1)) if drift else 0,
    }


def resolve(repo, name, revision):
    sha = git(repo, "rev-parse", "--verify", "--quiet", f"{revision}^{{commit}}", check=False).strip()
    if not sha:
        fail(f"revision {name}={revision!r} does not resolve to a commit")
    return {"name": name, "rev": revision, "sha": sha[:7], "date": git(repo, "show", "-s", "--format=%cI", sha).strip()}


def read_revision(repo, entry):
    rows = parse_rows(git(repo, "show", f"{entry['rev']}:{QUEUE}"))
    entry.update(census(rows))
    return rows


def main(argv):
    options = parse_options(argv)
    repo = options["repo"]
    if git(repo, "rev-parse", "--git-dir", check=False).strip() == "":
        fail(f"{repo} is not a git repository")
    head_date = datetime.datetime.fromisoformat(git(repo, "show", "-s", "--format=%cI", "HEAD").strip())
    day = datetime.date.fromisoformat(options["block_day"])

    def stamp(when):
        return when.strftime("%Y-%m-%dT%H:%M:%S")

    defaults = {
        "now": "HEAD",
        "7d": stamp(head_date - datetime.timedelta(days=7)),
        "30d": stamp(head_date - datetime.timedelta(days=30)),
        "pre-block": stamp(datetime.datetime.combine(day - datetime.timedelta(days=1), datetime.time(23, 59, 59))),
        "post-block": stamp(datetime.datetime.combine(day, datetime.time(23, 59, 59))),
    }

    def dated(name):
        """Revision behind a default name: an explicit switch wins, a date default
        resolves to the last commit before it (empty when the history is younger)."""
        explicit = options["rev"].get(name) or options["window"].get(name)
        wanted = explicit or defaults[name]
        if wanted != defaults[name] or name == "now":
            return wanted
        return git(repo, "rev-list", "-1", f"--before={wanted}", "HEAD").strip()

    revisions = []
    rows_at = {}
    for name in defaults:
        revision = dated(name)
        if not revision:
            revisions.append({"name": name, "rev": None, "sha": None, "date": None, "open": None, "ticked": None, "tags": {}, "other_tags": {}})
            continue
        entry = resolve(repo, name, revision)
        rows_at[name] = read_revision(repo, entry)
        revisions.append(entry)
    for name, revision in options["rev"].items():
        if name in defaults:
            continue
        entry = resolve(repo, name, revision)
        read_revision(repo, entry)
        revisions.append(entry)

    now_rows = rows_at.get("now")
    if now_rows is None:
        fail("the HEAD revision is missing")
    windows = []
    for name in WINDOW_NAMES + [extra for extra in options["window"] if extra not in WINDOW_NAMES]:
        revision = dated(name) if name in WINDOW_NAMES else options["window"][name]
        if not revision:
            continue
        entry = resolve(repo, name, revision)
        windows.append({"name": name, "start": entry["date"], **window_flow(parse_rows(git(repo, "show", f"{revision}:{QUEUE}")), now_rows)})

    open_now = {title: value for title, value in now_rows.items() if value[0]}
    added = block_titles(repo, options["block_day"])
    still_open = [title for title in open_now if title in added]
    open_library_titles = set()
    for library in {value[2] for value in open_now.values()} - {UNLINKED}:
        path = os.path.join(repo, library)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as handle:
                open_library_titles.update(title for title, value in parse_rows(handle.read()).items() if value[0])
    paired = sum(1 for title in still_open if title in open_library_titles)
    block = {
        "day": options["block_day"],
        "added": len(added),
        "open_now": len(still_open),
        "share_pct": round(100.0 * len(still_open) / len(open_now), 1) if open_now else 0.0,
        "closed_or_removed": len(added) - len(still_open),
        "pool_visible_now": sum(1 for title in still_open if open_now[title][1] in POOL_TAGS),
        "by_tag": sorted_counts(open_now[title][1] for title in still_open),
        "by_library": sorted_counts(open_now[title][2] for title in still_open),
        "by_source_month": sorted_counts(open_now[title][3] for title in still_open),
        "by_body": {kind: sum(1 for title in still_open if body_class(open_now[title][4]) == kind)
                    for kind in ("title only", "short body (under 120 chars)", "full body")},
        "paired_in_library": paired,
        "without_library_row": len(still_open) - paired - sum(1 for title in still_open if open_now[title][2] == UNLINKED),
        "unlinked": sum(1 for title in still_open if open_now[title][2] == UNLINKED),
    }
    if options["sample"]:
        chosen = random.Random(options["seed"]).sample(sorted(still_open), min(options["sample"], len(still_open)))
        block["sample"] = [{"line": open_now[title][5], "tag": open_now[title][1], "title": title,
                           "library": open_now[title][2]} for title in chosen]
        block["sample_seed"] = options["seed"]
    report = {
        "repo": repo,
        "head": git(repo, "rev-parse", "--short=7", "HEAD").strip(),
        "head_date": git(repo, "show", "-s", "--format=%cI", "HEAD").strip(),
        "revisions": revisions,
        "windows": windows,
        "domains": {"now": sorted_counts(value[2] for value in open_now.values())},
        "block": block,
        "gate": gate_counts(repo) if options["gate"] else None,
    }
    if options["json"]:
        print(json.dumps(report, indent=2))
        return
    render(report)


def render(report):
    revisions = report["revisions"]
    windows = report["windows"]
    block = report["block"]
    print(f"TODO backlog flow  repo {report['repo']}  HEAD {report['head']} ({report['head_date'][:16]})")
    print()
    print("Open queue rows per revision")
    print("  " + "revision".ljust(12) + "open".rjust(6) + "ticked".rjust(8) + "".join(tag[:11].rjust(13) for tag in TAGS) + "  date")
    for entry in revisions:
        if entry["open"] is None:
            print("  " + entry["name"].ljust(12) + "(no commit before that date)")
            continue
        print("  " + entry["name"].ljust(12) + str(entry["open"]).rjust(6) + str(entry["ticked"]).rjust(8) +
              "".join(str(entry["tags"].get(tag, 0)).rjust(13) for tag in TAGS) + "  " + entry["date"][:10])
    for entry in revisions:
        if entry.get("other_tags"):
            print(f"    {entry['name']}: other tags " + ", ".join(f"{tag} {count}" for tag, count in entry["other_tags"].items()))
    print()
    print("Flow since each window start (rows; the window ends at HEAD)")
    print("  " + "window".ljust(12) + "+open".rjust(6) + "+closed".rjust(8) + "-removed".rjust(9) + "ticked".rjust(8) + "reopened".rjust(9) + "net".rjust(6) + "  since")
    for entry in windows:
        net = entry["net_open"]
        print("  " + entry["name"].ljust(12) + str(entry["added_open"]).rjust(6) + str(entry["added_closed"]).rjust(8) +
              str(entry["removed"]).rjust(9) + str(entry["ticked"]).rjust(8) + str(entry["reopened"]).rjust(9) +
              (f"+{net}" if net >= 0 else str(net)).rjust(6) + "  " + entry["start"][:10])
    for entry in windows:
        parts = []
        for label, key in (("+open", "added_open_by_tag"), ("ticked", "ticked_by_tag"), ("-removed", "removed_by_tag")):
            parts.append(label + ": " + (", ".join(f"{tag} {count}" for tag, count in entry[key].items()) or "none"))
        print(f"    {entry['name']:<11} " + " | ".join(parts))
    print()
    print("Open rows now, per linked library")
    for library, count in report["domains"]["now"].items():
        print(f"  {count:>6}  {library}")
    print()
    print(f"Block (rows added on {block['day']}): {block['added']} added, {block['open_now']} still open "
          f"({block['share_pct']}% of the open queue), {block['closed_or_removed']} closed or removed")
    print(f"  pool-visible now (ready or blocked:deploy): {block['pool_visible_now']}")
    for label, key in (("tag", "by_tag"), ("library", "by_library"), ("source month", "by_source_month"), ("body", "by_body")):
        print(f"  by {label}: " + (", ".join(f"{name} {count}" for name, count in block[key].items()) or "none"))
    print(f"  pairing: {block['paired_in_library']} open block rows also open in their linked library, "
          f"{block['without_library_row']} with no library row, {block['unlinked']} without a library link")
    if block.get("sample"):
        print(f"  sample (seed {block['sample_seed']}):")
        for row in block["sample"]:
            print(f"    L{row['line']} [{row['tag']}] {row['title']}")
    gate = report["gate"]
    if gate is None:
        print("Gate: skipped (--no-gate)")
    else:
        print(f"Gate: {gate['unharvested_reports']} unharvested §f report(s), {gate['queue_library_drifts']} queue/library drift(s)"
              + (f" (exit {gate['exit']})" if gate["exit"] is not None else " (no check-todo-system.sh here)"))


main(sys.argv[2:])
EOF
