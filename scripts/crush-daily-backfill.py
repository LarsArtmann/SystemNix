#!/usr/bin/env python3
"""Backfill crush-daily reports for dates with zero-data or missing events.

The silent-zero-data bug (crush CLI schema drift + wrong SQLite DSN) caused
collections to produce zero sessions. This script finds those events, deletes
them, and re-runs the full collect + insights + report pipeline.

Usage:
    python3 scripts/crush-daily-backfill.py                    # all zero-data dates
    python3 scripts/crush-daily-backfill.py --from 2026-07-19 --to 2026-07-26
    python3 scripts/crush-daily-backfill.py --date 2026-07-25  # single date
    python3 scripts/crush-daily-backfill.py --collect-only      # skip insights/report
    python3 scripts/crush-daily-backfill.py --dry-run          # preview only

Prerequisites:
    - crush-daily service must be enabled (for config + binary in nix store)
    - The sops-rendered env file must exist at /run/secrets/rendered/crush-daily-env
    - Run as a user that can read /var/lib/crush-daily/crush-daily.db
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

DB_PATH = Path("/var/lib/crush-daily/crush-daily.db")
ENV_FILE = Path("/run/secrets/rendered/crush-daily-env")
HOME_DIR = "/home/lars"


def find_binary() -> str:
    candidates = sorted(glob.glob("/nix/store/*-crush-daily-*/bin/crush-daily"))
    if not candidates:
        print("ERROR: crush-daily binary not found in nix store. Deploy first.", file=sys.stderr)
        sys.exit(1)
    return candidates[-1]


def find_config() -> str:
    candidates = sorted(glob.glob("/nix/store/*-crush-daily.yaml"))
    if not candidates:
        print("ERROR: crush-daily config not found in nix store. Deploy first.", file=sys.stderr)
        sys.exit(1)
    return candidates[-1]


def read_api_key() -> str:
    if not ENV_FILE.exists():
        print(f"ERROR: env file not found: {ENV_FILE}", file=sys.stderr)
        sys.exit(1)
    for line in ENV_FILE.read_text().splitlines():
        if line.startswith("CRUSH_DAILY_LLM_API_KEY="):
            return line.split("=", 1)[1]
    print("ERROR: CRUSH_DAILY_LLM_API_KEY not found in env file", file=sys.stderr)
    sys.exit(1)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Backfill crush-daily zero-data reports")
    p.add_argument("--from", dest="from_date", help="Start date YYYY-MM-DD")
    p.add_argument("--to", dest="to_date", help="End date YYYY-MM-DD")
    p.add_argument("--date", help="Single date YYYY-MM-DD")
    p.add_argument("--dry-run", action="store_true", help="Preview without changes")
    p.add_argument("--collect-only", action="store_true", help="Skip insights and report steps")
    p.add_argument("--db", default=str(DB_PATH), help=f"Database path (default: {DB_PATH})")
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
    backup = db_path.with_name(f"crush-daily.db.backup_{ts}")
    shutil.copy2(db_path, backup)
    print(f"Backup: {backup}")
    return backup


def run_step(binary: str, step: str, target_date: str, config: str, api_key: str) -> tuple[bool, str]:
    env = {
        **os.environ,
        "GOEXPERIMENT": "jsonv2",
        "HOME": HOME_DIR,
        "CRUSH_DAILY_LLM_API_KEY": api_key,
    }
    cmd = [binary, step, "--date", target_date, "--config", config]
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


def verify_event(conn: sqlite3.Connection, target_date: str) -> int:
    rows = conn.execute(
        "SELECT payload FROM events WHERE event_type = 'DailyDataCollected'",
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

    binary = find_binary()
    config = find_config()
    api_key = read_api_key() if not args.collect_only else "unused"
    print(f"Binary:  {binary}")
    print(f"Config:  {config}")
    print(f"Mode:    {'collect-only' if args.collect_only else 'full (collect + insights + report)'}")
    print()

    backup_db(db_path)

    succeeded = 0
    failed = 0
    for event in zero_events:
        target_date = event["date"]
        idx = succeeded + failed + 1
        print(f"[{idx}/{len(zero_events)}] {target_date}")

        conn.execute("DELETE FROM events WHERE id = ?", (event["id"],))
        conn.commit()

        # Step 1: Collect (always required)
        ok, output = run_step(binary, "collect", target_date, config, api_key)
        if not ok:
            print(f"  COLLECT FAILED: {output[-200:]}")
            failed += 1
            continue

        sessions = verify_event(conn, target_date)
        if sessions < 0:
            print(f"  COLLECT FAILED: event not found after collect")
            failed += 1
            continue

        print(f"  collect: {sessions} sessions")

        if args.collect_only:
            succeeded += 1
            continue

        # Step 2: Insights (optional — failures are non-fatal)
        ok, output = run_step(binary, "insights", target_date, config, api_key)
        if ok:
            print(f"  insights: done")
        else:
            print(f"  insights: FAILED (non-fatal) — {output[-150:]}")

        # Step 3: Report (optional — failures are non-fatal)
        ok, output = run_step(binary, "report", target_date, config, api_key)
        if ok:
            print(f"  report: done")
        else:
            print(f"  report: FAILED (non-fatal) — {output[-150:]}")

        succeeded += 1

    conn.close()

    print(f"\n{'='*60}")
    print(f"Backfill complete: {succeeded} succeeded, {failed} failed out of {len(zero_events)}")
    if failed > 0:
        print("WARNING: Some dates failed. Check output above.")
        return 1

    print("\nRestart crush-daily service to rehydrate the in-memory read model:")
    print("  sudo systemctl restart crush-daily.service")
    return 0


if __name__ == "__main__":
    sys.exit(main())
