#!/usr/bin/env python3
"""
fix-versions.py — Fix git-rev version anti-pattern across all LarsArtmann projects.

Usage:
  python3 fix-versions.py --dry-run    # Preview changes
  python3 fix-versions.py              # Apply changes
"""

import argparse
import re
import subprocess
from pathlib import Path

PROJECTS_DIR = Path.home() / "projects"

SKIP_PROJECTS = {
    "dnsblockd",
    "go-auto-upgrade",
    "golangci-lint-auto-configure",
    "SystemNix",
    "crush-config",
    "nix-ssh-config",
}

VERSION_OVERRIDES = {
    "mr-sync": "0.1.0",
}


def get_latest_semver(repo_path: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "tag", "-l", "--sort=-version:refname"],
            cwd=repo_path, capture_output=True, text=True, timeout=5,
        )
        for tag in result.stdout.strip().split("\n"):
            tag = tag.strip()
            m = re.match(r"^v?(\d+\.\d+\.\d+)", tag)
            if m:
                return m.group(1)
    except Exception:
        pass
    return None


def find_affected_files(repo_path: Path) -> list[tuple[Path, list[tuple[int, str]]]]:
    affected = []
    for nix_file in repo_path.rglob("*.nix"):
        if any(skip in str(nix_file) for skip in [".git", "result"]):
            continue
        if nix_file.is_symlink():
            continue
        try:
            content = nix_file.read_text()
        except Exception:
            continue

        matches = []
        for i, line in enumerate(content.split("\n"), 1):
            if "version" not in line:
                continue
            has_version_assign = "version" in line and "=" in line
            has_self_ref = bool(re.search(
                r'self\.(rev|shortRev|dirtyRev|dirtyShortRev)|'
                r'inputs\.self\.(rev|shortRev|dirtyRev|dirtyShortRev)|'
                r'builtins\.substring.*self\.rev',
                line,
            ))
            if has_version_assign and has_self_ref:
                matches.append((i, line))

        if matches:
            affected.append((nix_file, matches))
    return affected


def fix_line(line: str, version: str) -> str:
    """Replace the version value on this line with hardcoded semver."""

    # Match: version = <expr>;
    # We replace everything between 'version = ' and the trailing ';'
    m = re.match(r'^(\s*version\s*=\s*)(.+)(;\s*)$', line)
    if not m:
        return line

    prefix = m.group(1)
    old_value = m.group(2)
    suffix = m.group(3)

    # Check if the value contains the anti-pattern
    has_anti = bool(re.search(
        r'self\.(rev|shortRev|dirtyRev|dirtyShortRev)|'
        r'inputs\.self\.(rev|shortRev|dirtyRev|dirtyShortRev)|'
        r'builtins\.substring',
        old_value,
    ))

    if not has_anti:
        return line

    return f'{prefix}"{version}"{suffix}'


def fix_ldflags_line(line: str, version: str) -> str:
    """Fix inline ldflags like -X main.version=${self.rev or ...}."""
    # Replace ${self.rev or self.dirtyRev or "dev"} with the version variable reference
    if re.search(r'-X\s+\S+\.version=\$\{self\.(?:rev|shortRev)', line):
        return re.sub(
            r'\$\{self\.(?:rev|shortRev)\s+or\s+self\.(?:dirtyRev|dirtyShortRev)\s+or\s+"[^"]*"\}',
            '${version}',
            line,
        )
    return line


def process_project(repo_path: Path, dry_run: bool) -> bool:
    name = repo_path.name
    affected = find_affected_files(repo_path)
    if not affected:
        return False

    version = VERSION_OVERRIDES.get(name) or get_latest_semver(str(repo_path)) or "0.1.0"
    any_changed = False

    for nix_file, matches in affected:
        content = nix_file.read_text()
        lines = content.split("\n")
        changed = False

        for line_no, _ in matches:
            idx = line_no - 1
            new_line = fix_line(lines[idx], version)
            new_line = fix_ldflags_line(new_line, version)

            if new_line != lines[idx]:
                rel = nix_file.relative_to(repo_path)
                if dry_run:
                    print(f"  {rel}:{line_no}")
                    print(f"    -{lines[idx].rstrip()}")
                    print(f"    +{new_line.rstrip()}")
                lines[idx] = new_line
                changed = True

        if changed:
            any_changed = True
            if not dry_run:
                nix_file.write_text("\n".join(lines))

    return any_changed


def main():
    parser = argparse.ArgumentParser(description="Fix version anti-pattern in LarsArtmann projects")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without writing")
    args = parser.parse_args()

    if args.dry_run:
        print("=== DRY RUN ===\n")

    changed_projects = []
    skipped_projects = []

    for entry in sorted(PROJECTS_DIR.iterdir()):
        if not entry.is_dir() or not (entry / ".git").exists():
            continue
        if entry.name in SKIP_PROJECTS:
            continue

        affected = find_affected_files(entry)
        if not affected:
            continue

        version = VERSION_OVERRIDES.get(entry.name) or get_latest_semver(str(entry)) or "0.1.0"
        print(f"\n{'='*60}")
        print(f"  {entry.name}  →  {version}")

        if process_project(entry, args.dry_run):
            changed_projects.append((entry.name, version))
        else:
            skipped_projects.append(entry.name)

    print(f"\n{'='*60}")
    print("DRY RUN SUMMARY" if args.dry_run else "CHANGES APPLIED")
    print(f"  Fixed: {len(changed_projects)} projects")
    for name, ver in changed_projects:
        print(f"    {name} → {ver}")
    if skipped_projects:
        print(f"  Skipped (no changes needed): {', '.join(skipped_projects)}")


if __name__ == "__main__":
    main()
