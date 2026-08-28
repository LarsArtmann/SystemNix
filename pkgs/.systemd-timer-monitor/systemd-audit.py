#!/usr/bin/env python3
"""
systemd-timer-monitor: Audit systemd services and timers, report failures
and mis-scheduled timers as a clean HTML status page.

Zero external dependencies. Standard library only.

Usage:
    ./systemd_audit.py [options]

Options:
    -o, --output FILE   Write HTML report to FILE (default: systemd-report.html)
    --json FILE         Also write machine readable JSON to FILE
    --no-service        Skip failed-service audit
    --no-timer          Skip timer audit
    --no-health          Skip general health (failed units count)
    --timeout SEC       systemctl command timeout in seconds (default: 15)
    --quiet             Print nothing to stdout
    -h, --help           Show this help message

Exit codes:
    0  Report generated successfully
    1  Argument error
    2  systemctl not available or unreadable
"""

import argparse
import datetime
import html
import json
import os
import shutil
import subprocess
import sys
from html import escape

__version__ = "1.0.0"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def run_systemctl(args, timeout=15):
    """Run a systemctl command and return a CompletedProcess or None on failure."""
    systemctl = shutil.which("systemctl")
    if systemctl is None:
        return None
    try:
        return subprocess.run(
            [systemctl] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return None


def parse_list_output(text):
    """Parse `systemctl list-units --plain` style output into unit dictionaries.

    Columns: UNIT LOAD ACTIVE SUB DESCRIPTION
    """
    units = []
    if not text:
        return units
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        # systemctl uses columns with a trailing dot on the unit name
        if not stripped[0].isalpha() and stripped[0] not in ("*", "$", "@"):
            continue
        if stripped.endswith("loaded units listed.") or stripped.endswith("units listed."):
            break
        parts = stripped.split(maxsplit=4)
        if len(parts) < 4:
            continue
        unit_name, _load, active, sub = parts[0], parts[1], parts[2], parts[3]
        description = parts[4].strip() if len(parts) > 4 else ""
        if active.endswith("*"):
            active = active[:-1]
        if sub.endswith("*"):
            sub = sub[:-1]
        units.append(
            {
                "unit": unit_name,
                "active": active,
                "sub": sub,
                "description": description,
            }
        )
    return units


def color_for_state(active, sub):
    """Return a CSS color for a unit state."""
    if active == "failed" or sub == "failed":
        return "#c0392b"  # red
    if active == "active" and sub in ("running", "active", "waiting", "exited"):
        return "#27ae60"  # green
    if active == "inactive":
        return "#7f8c8d"  # gray
    return "#7f8c8d"  # gray for unknown / activating etc.


# ---------------------------------------------------------------------------
# Audits
# ---------------------------------------------------------------------------

def audit_failed_services(timeout):
    """Return a list of currently failed service units."""
    proc = run_systemctl(
        ["list-units", "--type=service", "--state=failed", "--plain", "--no-legend"],
        timeout=timeout,
    )
    if proc is None:
        return []
    units = parse_list_output(proc.stdout)
    return [u for u in units if u["unit"].endswith(".service")]


def audit_timers(timeout):
    """Return a list of timer units with their next and last run times."""
    # List all timer units
    proc = run_systemctl(
        ["list-units", "--type=timer", "--plain", "--no-legend"],
        timeout=timeout,
    )
    if proc is None:
        return []
    timers = parse_list_output(proc.stdout)
    enriched = []
    for timer in timers:
        unit = timer["unit"]
        info = {
            "unit": unit,
            "active": timer["active"],
            "sub": timer["sub"],
            "description": timer["description"],
            "next_elapse": "-",
            "last_trigger": "-",
            "overdue": False,
        }
        # Next/last trigger come from systemctl show
        show = run_systemctl(["show", unit], timeout=timeout)
        if show is not None and show.returncode == 0:
            props = {}
            for line in show.stdout.splitlines():
                if "=" in line:
                    key, _, value = line.partition("=")
                    props[key.strip()] = value.strip()
            nxt = props.get("NextElapseUSecRealtime", "")
            last = props.get("LastTriggerUSec", "")
            if nxt and nxt not in ("0", "n/a"):
                info["next_elapse"] = nxt[:25]
            if last and last not in ("0", "n/a"):
                info["last_trigger"] = last[:25]
            # Heuristic: active but waiting, and last trigger is empty and
            # timer has never fired => possibly stuck/overdue
            if (
                timer["active"] == "active"
                and (not last or last in ("0", "n/a"))
                and nxt not in ("", "0", "n/a")
            ):
                info["overdue"] = True
        enriched.append(info)
    return enriched


def audit_health(failed_services, timers, timeout):
    """Summarize overall system health for systemd-managed units."""
    total_failed_procnt = run_systemctl(["--failed"], timeout=timeout)
    failed_count = None
    if total_failed_procnt is not None:
        # `systemctl --failed` prints a summary line; parse the count
        for line in total_failed_procnt.stdout.splitlines():
            if "failed units found" in line.lower():
                digits = "".join(ch for ch in line.split()[0] if ch.isdigit())
                failed_count = int(digits) if digits else None
                break
    if failed_count is None:
        # Fall back to counting the failed service list
        failed_count = len(failed_services)
    active_timers = sum(1 for t in timers if t["active"] == "active")
    healthy = failed_count == 0
    return {
        "failed_units": failed_count,
        "active_timers": active_timers,
        "total_timers": len(timers),
        "healthy": healthy,
    }


# ---------------------------------------------------------------------------
# HTML report
# ---------------------------------------------------------------------------

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>systemd audit report</title>
<style>
  :root {{
    --bg: #0f1115;
    --card: #181b22;
    --text: #e8eaed;
    --muted: #9aa0a6;
    --green: #27ae60;
    --red: #c0392b;
    --amber: #e67e22;
    --accent: #4aa8ff;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      Helvetica, Arial, sans-serif;
    line-height: 1.5;
    padding: 2rem 1rem;
  }}
  .container {{ max-width: 960px; margin: 0 auto; }}
  header {{ margin-bottom: 1.5rem; }}
  h1 {{ font-size: 1.6rem; margin: 0 0 0.25rem; }}
  .meta {{ color: var(--muted); font-size: 0.9rem; }}
  .summary {{
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 1rem;
    margin-bottom: 2rem;
  }}
  .stat {{
    background: var(--card);
    border-radius: 10px;
    padding: 1rem 1.25rem;
  }}
  .stat .label {{
    color: var(--muted);
    font-size: 0.8rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }}
  .stat .value {{ font-size: 1.8rem; font-weight: 700; margin-top: 0.25rem; }}
  .badge {{
    display: inline-block;
    padding: 0.15rem 0.6rem;
    border-radius: 999px;
    font-size: 0.75rem;
    font-weight: 600;
    color: #fff;
  }}
  .badge.ok {{ background: var(--green); }}
  .badge.fail {{ background: var(--red); }}
  .badge.warn {{ background: var(--amber); }}
  section {{ margin-bottom: 2rem; }}
  h2 {{
    font-size: 1.2rem;
    border-bottom: 1px solid #2a2e38;
    padding-bottom: 0.4rem;
    margin-bottom: 0.8rem;
  }}
  table {{
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
  }}
  th, td {{
    text-align: left;
    padding: 0.55rem 0.7rem;
    border-bottom: 1px solid #23262e;
  }}
  th {{ color: var(--muted); font-weight: 600; }}
  td.mono {{ font-family: ui-monospace, SFMono, Menlo, Consolas, monospace; font-size: 0.85rem; }}
  .state {{ font-weight: 600; }}
  .empty {{ color: var(--muted); font-style: italic; padding: 1rem; }}
  a {{ color: var(--accent); text-decoration: none; }}
  footer {{ color: var(--muted); font-size: 0.8rem; margin-top: 2rem; }}
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>systemd audit report</h1>
    <div class="meta">Generated {generated_at} on {hostname}</div>
  </header>

  <div class="summary">
    <div class="stat">
      <div class="label">Failed units</div>
      <div class="value" style="color:{failed_color}">{failed_units}</div>
    </div>
    <div class="stat">
      <div class="label">Active timers</div>
      <div class="value">{active_timers}</div>
    </div>
    <div class="stat">
      <div class="label">Total timers</div>
      <div class="value">{total_timers}</div>
    </div>
    <div class="stat">
      <div class="label">Overall</div>
      <div class="value">{health_badge}</div>
    </div>
  </div>

  {failed_section}
  {timer_section}

  <footer>
    Generated by <a href="https://github.com/cappy-dev/systemd-timer-monitor">systemd-timer-monitor</a> v{version}.
    Runs entirely on the local machine. No data leaves this host.
  </footer>
</div>
</body>
</html>
"""


def section_failed(failed_services):
    if not failed_services:
        return (
            '<section><h2>Failed services</h2>'
            '<p class="empty">No failed services. All clear.</p></section>'
        )
    rows = []
    for svc in failed_services:
        color = color_for_state(svc["active"], svc["sub"])
        rows.append(
            "      <tr>"
            f'<td class="mono">{escape(svc["unit"])}</td>'
            f'<td class="state" style="color:{color}">{escape(svc["active"])}</td>'
            f'<td>{escape(svc["sub"])}</td>'
            f'<td>{escape(svc["description"])}</td>'
            "</tr>"
        )
    body = "\n".join(rows)
    return (
        '<section><h2>Failed services</h2>'
        '<table><thead><tr>'
        "<th>Unit</th><th>Active</th><th>Sub</th><th>Description</th>"
        "</tr></thead><tbody>\n"
        f"{body}\n"
        "</tbody></table></section>"
    )


def section_timers(timers):
    if not timers:
        return (
            '<section><h2>Timers</h2>'
            '<p class="empty">No timers found.</p></section>'
        )
    rows = []
    for t in timers:
        color = color_for_state(t["active"], t["sub"])
        overdue_badge = (
            '<span class="badge warn">overdue</span>' if t["overdue"] else ""
        )
        rows.append(
            "      <tr>"
            f'<td class="mono">{escape(t["unit"])}</td>'
            f'<td class="state" style="color:{color}">{escape(t["active"])}</td>'
            f'<td>{escape(t["sub"])}</td>'
            f'<td class="mono">{escape(t["next_elapse"])}</td>'
            f'<td class="mono">{escape(t["last_trigger"])}</td>'
            f"<td>{overdue_badge}</td>"
            "</tr>"
        )
    body = "\n".join(rows)
    return (
        '<section><h2>Timers</h2>'
        '<table><thead><tr>'
        "<th>Unit</th><th>Active</th><th>Sub</th>"
        "<th>Next run</th><th>Last run</th><th>Flags</th>"
        "</tr></thead><tbody>\n"
        f"{body}\n"
        "</tbody></table></section>"
    )


def build_report_html(failed_services, timers, health, generated_at, hostname, version):
    failed_color = "#c0392b" if health["failed_units"] else "#27ae60"
    health_badge = (
        '<span class="badge ok">healthy</span>'
        if health["healthy"]
        else '<span class="badge fail">issues found</span>'
    )
    return HTML_TEMPLATE.format(
        generated_at=escape(generated_at),
        hostname=escape(hostname),
        failed_units=health["failed_units"],
        failed_color=failed_color,
        active_timers=health["active_timers"],
        total_timers=health["total_timers"],
        health_badge=health_badge,
        failed_section=section_failed(failed_services),
        timer_section=section_timers(timers),
        version=version,
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="systemd_audit",
        description="Audit systemd services and timers, output an HTML report.",
    )
    parser.add_argument(
        "-o", "--output", default="systemd-report.html",
        help="Output HTML report file (default: systemd-report.html)",
    )
    parser.add_argument(
        "--json", dest="json_path", default=None,
        help="Also write machine readable JSON to the given file",
    )
    parser.add_argument("--no-service", action="store_true", help="Skip failed-service audit")
    parser.add_argument("--no-timer", action="store_true", help="Skip timer audit")
    parser.add_argument("--no-health", action="store_true", help="Skip health summary")
    parser.add_argument("--timeout", type=int, default=15, help="systemctl command timeout in seconds")
    parser.add_argument("--quiet", action="store_true", help="Print nothing to stdout")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {__version__}")
    args = parser.parse_args(argv)

    # Sanity check
    systemd_path = shutil.which("systemctl")
    if systemd_path is None:
        if not args.quiet:
            print("error: systemctl not found. This tool requires systemd.", file=sys.stderr)
        return 2

    # Gather data
    failed_services = [] if args.no_service else audit_failed_services(args.timeout)
    timers = [] if args.no_timer else audit_timers(args.timeout)
    health = audit_health(failed_services, timers, args.timeout) if not args.no_health else {}

    # Build the report
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    hostname = os.uname().nodename
    html_report = build_report_html(
        failed_services, timers, health, now, hostname, __version__,
    )

    try:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(html_report)
    except OSError as exc:
        if not args.quiet:
            print(f"error: could not write HTML to {args.output}: {exc}", file=sys.stderr)
        return 1

    if args.json_path:
        payload = {
            "generated_at": now,
            "hostname": hostname,
            "version": __version__,
            "failed_services": failed_services,
            "timers": timers,
            "health": health,
        }
        try:
            with open(args.json_path, "w", encoding="utf-8") as f:
                json.dump(payload, f, indent=2)
        except OSError as exc:
            if not args.quiet:
                print(f"error: could not write JSON to {args.json_path}: {exc}", file=sys.stderr)
            return 1

    if not args.quiet:
        status = "healthy" if health.get("healthy", True) else "issues found"
        print(
            f"Report written to {args.output} "
            f"({len(failed_services)} failed services, "
            f"{len(timers)} timers, status: {status})."
        )

    # Non zero exit if issues found, handy for cron alerting
    return 0 if health.get("healthy", True) else 1


if __name__ == "__main__":
    sys.exit(main())
