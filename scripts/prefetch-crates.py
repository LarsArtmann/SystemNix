#!/usr/bin/env python3
"""
Prefetch Rust crates from static.crates.io CDN to bypass crates.io API blocks.

crates.io may block IPs that download without a descriptive User-Agent header.
Nix's fetchurl uses curl's default UA, which triggers this block.
The static.crates.io CDN serves the same files without API restrictions.

Usage:
  python3 scripts/prefetch-crates.py path/to/Cargo.lock

This pre-populates the Nix store with crate tarballs so that subsequent
Nix builds don't need to hit the crates.io API at all.
"""

import json
import subprocess
import sys
import tomllib
from pathlib import Path


def parse_cargo_lock(path: Path) -> list[tuple[str, str]]:
    with path.open("rb") as f:
        data = tomllib.load(f)

    crates = []
    for pkg in data.get("package", []):
        source = pkg.get("source", "")
        if "crates.io-index" in source:
            crates.append((pkg["name"], pkg["version"]))

    return crates


def prefetch_crate(name: str, version: str) -> bool:
    store_name = f"crate-{name}-{version}.tar.gz"
    url = f"https://static.crates.io/crates/{name}/{version}/download"

    result = subprocess.run(
        ["nix", "store", "prefetch-file", "--hash-type", "sha256", "--name", store_name, url],
        capture_output=True,
        text=True,
        timeout=120,
    )
    return result.returncode == 0


def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} path/to/Cargo.lock", file=sys.stderr)
        return 1

    lock_path = Path(sys.argv[1])
    if not lock_path.exists():
        print(f"Error: {lock_path} not found", file=sys.stderr)
        return 1

    crates = parse_cargo_lock(lock_path)
    print(f"Found {len(crates)} crates.io dependencies in {lock_path}")

    done = 0
    failed = 0
    for i, (name, version) in enumerate(crates):
        if prefetch_crate(name, version):
            done += 1
        else:
            failed += 1
            print(f"  FAILED: {name}-{version}", file=sys.stderr)

        if (i + 1) % 50 == 0 or (i + 1) == len(crates):
            print(f"  [{i+1}/{len(crates)}] done={done} failed={failed}")

    print(f"\nComplete: {done} downloaded, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
