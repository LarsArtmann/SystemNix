#!/usr/bin/env python3
"""
Migrate .envrc files to the smart direnv library pattern.

After migration, each .envrc is reduced to minimal lines:
  use flake          # (if project has flake.nix)
  use_go_env         # (if project has go.mod or needed Go env vars)
  <extras>           # (project-specific code that can't be auto-detected)

All comments from old .envrc are stripped — the smart library is self-documenting.
Multi-line constructs (if/fi, function defs) are handled as atomic units.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

PROJECTS_DIR = Path("/home/lars/projects")

# ── Line classifiers ────────────────────────────────────────────────────────

def is_auto_handled(line: str) -> bool:
    """Lines whose functionality is provided by the smart library or nix-direnv."""
    s = line.strip()
    if not s or s.startswith("#"):
        return True
    auto = [
        r"^source_url\s",
        r"^if\s+.*nix_direnv_version",
        r"^if\s+.*has\s+nix_direnv_version",
        r"^fi\s*$",
        r"^else\s*$",
        r"^watch_file\s+flake\.nix\s*$",
        r"^watch_file\s+flake\.lock\s*$",
        r"^export\s+GOEXPERIMENT=jsonv2\s*$",
        r"^export\s+GOPRIVATE=.*$",
        r"^_nix_add_gcroot\s*\(\)",
        r"^local\s+storepath",
        r"^local\s+symlink",
        r"^if\s+\[\[.*storepath",
        r"^ln\s+-sfn",
        r"^_nix\s+build.*out-link",
        r"^\}\s*$",
        r"^use\s+flake\s*$",
        r"^use_go_env\s*$",
    ]
    return any(re.match(p, s) for p in auto)


def is_use_flake_attr(line: str) -> bool:
    """`use flake .#attr` (keep the attribute)."""
    return bool(re.match(r"^\s*use\s+flake\s+\.", line.strip()))


def needs_go_env(old_content: str, project_dir: Path) -> bool:
    if "use_go_env" in old_content:
        return True
    if (project_dir / "go.mod").exists():
        return True
    if re.search(r"GOEXPERIMENT|GOPRIVATE", old_content, re.IGNORECASE):
        return True
    return False


def has_flake(project_dir: Path) -> bool:
    return (project_dir / "flake.nix").exists()


# ── Multi-line construct detection ──────────────────────────────────────────

def find_block_end(lines: list[str], start: int, opener: str, closer_re: str) -> int:
    """Find the line index matching a closing token for a block opened at `start`."""
    depth = 0
    open_re = re.compile(opener)
    close_re = re.compile(closer_re)
    for i in range(start, len(lines)):
        s = lines[i].strip()
        if open_re.search(s):
            depth += 1
        if close_re.search(s):
            depth -= 1
            if depth == 0:
                return i
    return -1


def find_if_end(lines: list[str], start: int) -> int:
    """Find the `fi` matching an `if` at line `start`. Handles nested ifs."""
    return find_block_end(lines, start, r"\bif\b", r"^fi\s*$")


def find_func_end(lines: list[str], start: int) -> int:
    """Find the `}` matching a function `{` at line `start`."""
    depth = 0
    for i in range(start, len(lines)):
        s = lines[i]
        depth += s.count("{") - s.count("}")
        if depth <= 0 and i > start:
            return i
    return -1


# ── Core migration ──────────────────────────────────────────────────────────

def migrate_content(old_content: str, project_dir: Path) -> str:
    lines = old_content.splitlines()
    use_flake_attr = None
    extras: list[str] = []

    i = 0
    while i < len(lines):
        line = lines[i]
        s = line.strip()

        # ── Skip shebangs ──
        if s.startswith("#!"):
            i += 1
            continue

        # ── Function definition: _nix_add_gcroot() { ... } ──
        if re.match(r"^\s*_nix_add_gcroot\s*\(\)", line):
            end = find_func_end(lines, i)
            i = (end + 1) if end != -1 else (i + 1)
            continue

        # ── if/fi block ──
        if s.startswith("if ") and ("then" in s or "if " in s):
            end = find_if_end(lines, i)
            if end != -1:
                block = lines[i : end + 1]
                block_text = "\n".join(block)
                # If it's a nix_direnv_version guard → skip entirely
                if "nix_direnv_version" in block_text:
                    i = end + 1
                    continue
                # If it contains `use flake` and project has flake → skip (we add use flake)
                if has_flake(project_dir) and re.search(r"use\s+flake", block_text):
                    i = end + 1
                    continue
                # Otherwise keep the ENTIRE block intact as extras
                for inner in block:
                    inner_s = inner.strip()
                    if not inner_s or inner_s.startswith("#"):
                        continue
                    extras.append(inner.rstrip())
                i = end + 1
                continue

        # ── Standalone fi/else (orphan from removed if) ──
        if s in ("fi", "else"):
            i += 1
            continue

        # ── Capture use flake .#attr ──
        if is_use_flake_attr(line):
            use_flake_attr = s
            i += 1
            continue

        # ── Auto-handled single lines (including comments) ──
        if is_auto_handled(line):
            i += 1
            continue

        # ── Extra: project-specific code ──
        extras.append(line.rstrip())
        i += 1

    # ── Build the new .envrc ──
    out: list[str] = []

    if use_flake_attr:
        out.append(use_flake_attr)
    elif has_flake(project_dir):
        out.append("use flake")

    if needs_go_env(old_content, project_dir):
        out.append("use_go_env")

    if extras:
        out.append("")
        out.extend(extras)

    return "\n".join(out) + "\n"


def migrate_project(project_dir: Path, dry_run: bool = False) -> tuple[bool, str, str]:
    """Returns (changed, description, new_content)."""
    envrc = project_dir / ".envrc"
    if not envrc.exists():
        return False, "", ""

    old = envrc.read_text()
    new = migrate_content(old, project_dir)

    if old.rstrip() == new.rstrip():
        return False, "already optimal", new

    if not dry_run:
        envrc.write_text(new)

    old_n = len([l for l in old.strip().splitlines() if l.strip()])
    new_n = len([l for l in new.strip().splitlines() if l.strip()])
    return True, f"{old_n} → {new_n} lines", new


def main() -> None:
    dry_run = "--dry-run" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]

    changed = 0
    unchanged = 0

    for entry in sorted(PROJECTS_DIR.iterdir()):
        if not entry.is_dir():
            continue
        if only and entry.name not in only:
            continue

        did_change, desc, new = migrate_project(entry, dry_run=dry_run)
        if did_change:
            changed += 1
            tag = "DRY-RUN" if dry_run else "MIGRATED"
            print(f"  {tag:10s} {entry.name:45s} {desc}")
        elif desc:
            unchanged += 1

    print(f"\n{'='*60}")
    print(f"Migrated: {changed}  Already optimal: {unchanged}")
    if dry_run:
        print("(dry-run — no files modified)")


if __name__ == "__main__":
    main()
