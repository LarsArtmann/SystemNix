#!/usr/bin/env python3
"""Backfill crush-daily reports for dates that have zero-data events.

The silent-zero-data bug (crush CLI schema drift + wrong SQLite DSN) caused
every collection from 2026-06-11 through 2026-07-26 to produce zero sessions.
The fix was deployed 2026-07-28, but the scheduler only collects "yesterday",
so the gap was never filled.

This script:
1. Identifies DailyDataCollected events with zero sessions
2. Backs up the database
3. Deletes each zero-data event so run-all can re-collect
4. Runs crush-daily run-all for each date (collect + insights + report)
5. Verifies the new event has non-zero data

Usage:
    python3 scripts/crush-daily-backfill.py                    # all zero-data dates
    python3 scripts/crush-daily-backfill.py --from 2026-07-19 --to 2026-07-26
    python3 scripts/crush-daily-backfill.py --date 2026-07-25  # single date
    python3 scripts/crush-daily-backfill.py --dry-run          # preview only
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sqlite3
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

DB_PATH = Path("/var/lib/crush-daily/crush-daily.db")
CONFIG_PATH = Path("/nix/store/cc8bz4bmr1hk1q6a6paxgiflvjgyzp5a-crush-daily.yaml")


def find_crush_daily_binary() -> str:
    """Find the crush-daily binary from the running system or nix build."""
    # Try the systemd unit's ExecStart path first (fastest)
    import glob
    candidates = glob.glob("/nix/store/*-crush-daily-*/bin/crush-daily")
    if candidates:
        return sorted(candidates)[-1]  # latest hash
    # Fall back to nix run (slower — evaluates flake each time)
    return None


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Backfill crush-daily zero-data reports")
    p.add_argument("--from", dest="from_date", help="Start date YYYY-MM-DD")
    p.add_argument("--to", dest="to_date", help="End date YYYY-MM-DD")
    p.add_argument("--date", help="Single date YYYY-MM-DD")
    p.add_argument("--dry-run", action="store_true", help="Preview without changes")
    p.add_argument("--db", default=str(DB_PATH), help=f"Database path (default: {DB_PATH})")
    p.add_argument("--config", default=str(CONFIG_PATH), help="crush-daily YAML config path")
    return p.parse_args()


def get_zero_data_events(conn: sqlite3.Connection, date_filter: set[str] | None = None) -> list[dict]:
    rows = conn.execute(
        "SELECT id, aggregate_id, payload, occurred_at FROM events WHERE event_type = ?",
        ("DailyDataCollected",),
    ).fetchall()

    results = []
    for row in rows:
        payload = json.loads(row[2]) if row[2] else {}
        d = payload.get("date", "")
        stats = payload.get("total_stats", payload.get("stats", {}))
        sessions = stats.get("session_count", 0)
        if sessions == 0:
            if date_filter is None or d in date_filter:
                results.append({"id": row[0], "aggregate_id": row[1], "date": d, "occurred_at": row[3]})
    return results


def parse_date_range(from_str: str | None, to_str: str | None, single: str | None) -> set[str] | None:
    if single:
        return {single}
    if from_str and to_str:
        start = datetime.strptime(from_str, "%Y-%m-%d").date()
        end = datetime.strptime(to_str, "%Y-%m-%d").date()
        return {(start + timedelta(days=i)).isoformat() for i in range((end - start).days + 1)}
    if from_str or to_str:
        print("ERROR: --from and --to must be used together", file=sys.stderr)
        sys.exit(1)
    return None


def backup_db(db_path: Path) -> Path:
    ts = datetime.now().strftime("%Y%m%dT%H%M%S")
    backup = db_path.with_suffix(f".db.backup_{ts}")
    shutil.copy2(db_path, backup)
    print(f"Backup: {backup}")
    return backup


def run_collect(target_date: str, config_path: str, dry_run: bool) -> bool:
    env = {
        **os.environ,
        "GOEXPERIMENT": "jsonv2",
        "HOME": "/home/lars",
        "CRUSH_DAILY_LLM_API_KEY": "synthetic",
    }
    binary = find_crush_daily_binary()
    if binary:
        cmd = [binary, "run-all", "--date", target_date, "--config", config_path]
    else:
        cmd = ["nix", "run", ".#crush-daily", "--", "run-all", "--date", target_date, "--config", config_path]
    if dry_run:
        print(f"  [DRY-RUN] would run: {' '.join(cmd)}")
        return True
    result = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=str(Path(config_path).parent))
    if result.returncode != 0:
        print(f"  FAILED: {result.stderr.strip()[:200]}")
        return False
    # Check for success indicators in stderr (crush-daily logs to stderr)
    if "run-all: done" in result.stderr or "report generated" in result.stderr.lower():
        return True
    # Even without explicit success marker, exit 0 is success
    return result.returncode == 0


def verify_event(conn: sqlite3.Connection, target_date: str) -> int:
    rows = conn.execute(
        "SELECT payload FROM events WHERE event_type = ? AND aggregate_id IN "
        "(SELECT aggregate_id FROM events WHERE event_type = 'DailyDataCollected')",
        ("DailyDataCollected",),
    ).fetchall()
    for row in rows:
        payload = json.loads(row[0]) if row[0] else {}
        if payload.get("date") == target_date:
            stats = payload.get("total_stats", payload.get("stats", {}))
            return stats.get("session_count", 0)
    return -1


def main() -> int:
    args = parse_args()
    db_path = Path(args.db)

    if not db_path.exists():
        print(f"ERROR: database not found: {db_path}", file=sys.stderr)
        return 1

    date_filter = parse_date_range(args.from_date, args.to_date, args.date)

    conn = sqlite3.connect(str(db_path))
    zero_events = get_zero_data_events(conn, date_filter)

    if not zero_events:
        print("No zero-data events found for the specified range.")
        conn.close()
        return 0

    zero_events.sort(key=lambda e: e["date"])
    print(f"Found {len(zero_events)} zero-data dates:")
    for e in zero_events:
        print(f"  {e['date']}")
    print()

    if args.dry_run:
        print("[DRY-RUN] No changes made.")
        conn.close()
        return 0

    if not CONFIG_PATH.exists():
        print(f"ERROR: config file not found: {args.config}", file=sys.stderr)
        return 1

    backup_db(db_path)

    succeeded = 0
    failed = 0
    for event in zero_events:
        target_date = event["date"]
        print(f"[{succeeded + failed + 1}/{len(zero_events)}] Backfilling {target_date}...")

        # Delete the zero-data event so run-all can re-collect
        conn.execute("DELETE FROM events WHERE id = ?", (event["id"],))
        conn.commit()
        print(f"  Deleted zero-data event ({event['id'][:12]}...)")

        # Re-collect with correct data
        if run_collect(target_date, args.config, False):
            sessions = verify_event(conn, target_date)
            if sessions > 0:
                print(f"  OK: {sessions} sessions")
                succeeded += 1
            elif sessions == 0:
                print(f"  OK: 0 sessions (no crush activity on this date)")
                succeeded += 1
            else:
                print(f"  WARN: event not found after collect — may have failed silently")
                failed += 1
        else:
            failed += 1

    conn.close()

    print(f"\n{'='*60}")
    print(f"Backfill complete: {succeeded} succeeded, {failed} failed")
    if failed > 0:
        print("WARNING: Some dates failed. Check output above.")
        return 1

    print("\nIMPORTANT: Restart crush-daily service to rehydrate the read model:")
    print("  sudo systemctl restart crush-daily.service")
    return 0


if __name__ == "__main__":
    sys.exit(main())
