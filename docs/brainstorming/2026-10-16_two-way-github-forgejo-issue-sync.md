# Two-Way GitHub↔Forgejo Issue Sync — raw idea (wave-1 #5, 2026-10-16)

**Owner ask:** "I would like a both way sync" for issues/PR metadata between GitHub
(LarsArtmann orgs) and Forgejo — forgejo-native issue flow for flipped (canonical)
repos without losing GitHub history or access.

**Why this is NOT a fresh build:** three existing LarsArtmann projects are the
building blocks; the design work is the MAPPING, not the transport.

| Project | Role in the design |
| ------- | ------------------ |
| `github-local-sync` | Local-first GitHub sync engine — the transport/queue layer candidate; owner: "should kinda be a backup product one day" (see `sales-landing-page`) |
| `go-github-kit` | GitHub API client kit — the GitHub-side adapter |
| `standard-bug-tracking-schema` | The normalized issue schema — conflicts/tombstones/field-mapping should be designed AGAINST this schema, not ad-hoc |

## Open design questions (answer before writing sync code)

1. **Directionality per repo class** — canonical repos (forgejo-primary, e.g.
   `eventcatalog-hub`, `domains`) get bidirectional; GitHub-primary mirrors stay
   read-only on the forgejo side. Does the sync engine encode repo class
   explicitly, or derive it from `canonicalRepos`?
2. **Conflict rules** — same issue edited both sides inside one window:
   last-writer-wins per FIELD (against the bug-tracking schema's field list), or
   whole-issue LWW? Tombstone semantics when GitHub closes + forgejo reopens.
3. **Identity mapping** — GitHub issue numbers ≠ forgejo issue numbers; the
   flip's FULL import preserves bodies but NOT numbers. Where does the
   number↔number map live (forgejo repo metadata? the schema store?), and what
   happens on the NEXT flip of a repo that already has synced issues?
4. **Lossiness accounting** — the flip import already drops reactions/review
   metadata; the sync layer must not re-create those as noise. Round-trip
   guarantee needed: sync(GitHub→forgejo→GitHub) == identity.
5. **Rate/burst shape** — webhooks both sides, or poll? GitHub Actions minutes
   are dead (billing), so GitHub-side triggers need either the forgejo runner
   polling or GitHub webhooks → home-lab endpoint.

**Next step when picked up:** schema-first mapping doc in
`standard-bug-tracking-schema`, then a spike in `github-local-sync`.
