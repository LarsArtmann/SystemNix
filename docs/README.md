# SystemNix Documentation

Documentation for the SystemNix cross-platform Nix configuration (macOS + NixOS).

## Directory Structure

| Directory          | Purpose                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| `architecture/`    | System architecture docs, ADRs, dependency graphs                      |
| `learnings/`       | Lessons learned from debugging and sessions                            |
| `operations/`      | Operational procedures and post-deployment checklists                  |
| `planning/`        | Roadmaps, planning documents, unimplemented proposals                  |
| `prompts/`         | Reusable debugging and analysis prompts                                |
| `status/`          | Status reports from work sessions (older reports in `status/archive/`) |
| `troubleshooting/` | Known issues and their solutions                                       |

## Key Documents

- **AGENTS.md** (repo root) — AI agent guide with architecture, patterns, and commands
- **README.md** (repo root) — Project overview, services table, and Nix flake command reference
- **docs/CONTRIBUTING.md** — Contributor setup, style rules, and verification commands
- **architecture/** — ADRs (Architecture Decision Records), DNS guide, monitoring plans
- **operations/manual-steps-after-deployment.md** — Post-deployment checklist

## Naming Convention

- Status reports: `YYYY-MM-DD_HH-MM_TOPIC.md` in `status/`
- Decisions: `ADR-NNN-title.md` in `architecture/`
- Planning: `descriptive-name.md` in `planning/`

## Adding New Documents

1. **Status report** → `status/YYYY-MM-DD_HH-MM_TOPIC.md`
2. **Architecture decision** → `architecture/ADR-NNN-title.md`
3. **Lesson learned** → `learnings/YYYY-MM-DD_HH-MM_topic.md`
4. **Planning doc** → `planning/descriptive-name.md`

## Cleanup Policy

- Status reports older than 30 days are moved to `status/archive/`
- Archive directories (`archive/`, `archives/`) contain historical docs
- Planning docs for completed or abandoned work stay in `planning/`
