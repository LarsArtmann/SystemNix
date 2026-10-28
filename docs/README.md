# SystemNix Documentation

Documentation for the SystemNix cross-platform Nix configuration (macOS + NixOS).

## Directory Structure

| Directory          | Purpose                                                                |
| ------------------ | ---------------------------------------------------------------------- |
| `agents/`          | Agent knowledge library: domain references split from AGENTS.md        |
| `architecture/`    | System architecture docs, ADRs, dependency graphs                      |
| `brainstorming/`   | Design notes, ratified and half-formed — **read before designing anything**, a ratified plan here outranks a fresh design |
| `learnings/`       | Lessons learned from debugging and sessions                            |
| `operations/`      | Operational procedures and post-deployment checklists                  |
| `planning/`        | Roadmaps, planning documents, unimplemented proposals                  |
| `prompts/`         | Reusable debugging and analysis prompts                                |
| `services/`        | **Per-service runbooks** — ports, secrets, traps, verification; one per enabled service |
| `status/`          | Status reports from work sessions (older reports in `status/archived/`) |
| `todo/`            | TODO domain libraries (`storage`, `monitoring`, `services`, …) — the detail behind `TODO_LIST.md` |
| `troubleshooting/` | Known issues and their solutions                                       |

## Key Documents

- **AGENTS.md** (repo root) — lean need-to-know agent guide + routing table (domain depth: `docs/agents/`, services: `docs/services/`)
- **README.md** (repo root) — Project overview, services table, and Nix flake command reference
- **docs/CONTRIBUTING.md** — Contributor setup, style rules, and verification commands
- **architecture/** — ADRs (Architecture Decision Records), DNS guide, monitoring plans
- **docs/status/archived/manual-steps-after-deployment.md** — Post-deployment checklist
- **dnsblockd OIDC recovery runbooks** — secret-desync vs client-row-vanish diagnosis + fix chain: `status/archived/2026-08-22_02-46_dnsblockd-oidc-secret-desync-diagnosis.md` and `status/archived/2026-08-22_03-49_dnsblockd-oidc-outage-fixed-self-review.md` (recovery = one provisioner run + the bridge-then-daemon restart order from deploy.sh)

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

- Status reports older than 30 days are moved to `status/archived/`
- Archive directories (`archive/`, `archives/`) contain historical docs
- Planning docs for completed or abandoned work stay in `planning/`
