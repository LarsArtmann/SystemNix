# Task 000001a2012fe866 closeout — bootmetrics wiring attribution correction

**Date:** 2026-11-22
**Fix ticket:** 000001a2022ba94c896447ed94aa00000000 (reviewer finding, medium)

## Finding

The batch's item-5 commit (cc3c8f2ce372, `test(boot-metrics): fixture for the
transaction_open OPEN path`) asserts the negative-proven mutation legs in its
message, but the wiring that carries them — the `CASES=bootmetrics` legs in
`scripts/negative-test-lints.sh` and the `bootmetrics-openpath-selftest` block
in `flake/parts/checks/selftests.nix` — landed in the heuristic auto-commit
95fd92e8517 (`chore: auto-commit 3 changed file(s) (heuristic)`). The
daemon-race policy (`docs/CONTRIBUTING.md`, AGENTS.md "Multi-agent write
discipline") requires verifying daemon commit contents and amending them into
a properly-messaged commit; neither happened before the interleaved history
made the repair unavailable.

## Attribution record (verified)

| Surface                                       | Commit                              |
| --------------------------------------------- | ----------------------------------- |
| item-5 fixture + checks + negative-lint legs  | **95fd92e8517** (daemon, heuristic) |
| item-5 commit carrying the claim message      | cc3c8f2ce372                        |
| storm-wedge ioTier isolation                  | afecf20d6                           |
| monitor365-backup phantom-red purge           | 619939b7f                           |
| ci-watchdog BLOCKED row                       | 4357048d8                           |
| deploy-leg queueing                           | fd769ada4                           |
| dnsblockd runbook pointer (already satisfied) | 5b346bb8d                           |

`git show --stat 95fd92e8517`: `flake/parts/checks/selftests.nix` (+32),
`scripts/negative-test-lints.sh` (+14), `docs/services/monitor365.md` (1 line).

## Why history was not rewritten

The item commits and the daemon commit interleave with unrelated sibling work;
amend/rebase would rewrite shared history (violates the AGENTS.md
never-rewrite-interleaved-history discipline). Fix direction taken instead:
this report plus attribution notes appended to the TODO_LIST item-5 row and
the `docs/todo/stability.md:204` sibling row, in a follow-up docs commit.

## Verification of the tree (reviewer-confirmed, re-checked)

shellcheck: no findings in the daemon-commit hunks or fixture;
`audit-shell-nullglob`: fail=0; fixture passes live against the real rendered
script. The tree itself is sound — only the attribution was wrong.
