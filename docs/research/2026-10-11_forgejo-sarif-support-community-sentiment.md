# Forgejo SARIF Support — Status & Community Sentiment

**Date:** 2026-10-11
**Question:** Does Forgejo support SARIF (Static Analysis Results Interchange Format)?
**Method:** Codeberg API fetch (HTML scraping is 403-blocked) of the two relevant issues, all comments read.

## Short answer

**No.** Forgejo has no native SARIF support — no Security tab, no code-scanning alerts like GitHub. It is an open feature request with no milestone, no assignee, and no PR. Interim pattern: upload SARIF as a CI artifact and render findings into the job summary.

## Relevant issues

| Issue                                                                          | Title                                                | Opened     | State                                                                                                                             |
| ------------------------------------------------------------------------------ | ---------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [forgejo/forgejo#3669](https://codeberg.org/forgejo/forgejo/issues/3669)       | [FEAT] Security Tab                                  | 2024-05-08 | open, 7 comments, no milestone                                                                                                    |
| [forgejo/forgejo#12667](https://codeberg.org/forgejo/forgejo/issues/12667)     | enh: Support processing and storing security reports | 2026-05-21 | open, 5 comments, no milestone                                                                                                    |
| [forgejo/discussions#468](https://codeberg.org/forgejo/discussions/issues/468) | Security dashboard with vulnerability tracking       | —          | discussion (proposes `POST /api/v1/repos/{owner}/{repo}/security/sarif`, fingerprint dedup via rule ID + location + snippet hash) |

## What people say

### Demand is real but recurring without progress

- **npgo22** (opener, May 2024): wants GitHub/GitLab parity — a Security tab ingesting SARIF from SAST tools (flawfinder etc.), tracking CVEs. Mirror of the Gitea request go-gitea/gitea#24930.
- **bencurio** (Jul 2024): proposes OSV / OSV-Scanner integration as the implementation angle (public API has no rate limit; self-hosted option).
- **batleforc** (May 2026): "any news?" — SARIF injection from pipelines (opengrep, trivy) is "one of the features I'm missing."
- **alxndr42** (Jul 2026): built a reusable [OSV-Scanner workflow](https://codeberg.org/alxndr42/osv-scanner) that uploads SARIF as an artifact — "until the Security Tab exists."

### Maintainer stance is lukewarm

- **aahlenst** (May 2026), on "any news?": _"If there had been any news, you would have found it here. We welcome contributions."_ First step = gather requirements and draft a plan for community feedback before coding. Also warned: _"do not build something that relies on Microsoft/GitHub technologies. That usually ends badly because Microsoft has zero interest in supporting usage outside Microsoft/GitHub."_
- **mfenniak** (Jul 2026), skeptical of building it in-core: _"this sounds like introducing an entire new product inside Forgejo… I see many months of work being done on very tiny details. That makes me feel this belongs at an arms length from Forgejo."_ Suggests integrating [DefectDojo](https://github.com/DefectDojo/django-DefectDojo) instead.

### One active design effort, no PR

**sansmoraxz** opened `#12667` (May 2026, "I will be taking a dig at this"). Sketched flow (Jun 2026):

1. Upload API call → validate SAST artifact (SARIF first) → extract fingerprint + code reference per report → store in DB keyed on fingerprint → also store raw file (GitLab does, GitHub doesn't).
2. Report lifecycle: needs-triage / confirmed / dismissed / resolved (GitLab-style, not GitHub's simpler alerts).
3. Known hard part: SARIF fingerprints "move" (GitHub's own docs on duplicate-alert prevention); GitLab works around it with expensive language-specific tracking. Proposal: manual triage first (default needs-triage), belonging determined by commit-hash-in-history.

Stalled since Jul 2026 at the "draft a proposal for community buy-in" stage. His format note: SARIF isn't the only report format in play — CycloneDX/SPDX, CSAF, SCAP, SLSA — so the design should be format-generic.

## Bottom line

Users want it, nobody with merge rights is championing it, and the loudest maintainer opinion leans toward "don't build this in-core." For our CI: generate SARIF (e.g. OSV-Scanner, trivy, opengrep), upload as artifact + render to job summary; watch `#12667` for movement.
