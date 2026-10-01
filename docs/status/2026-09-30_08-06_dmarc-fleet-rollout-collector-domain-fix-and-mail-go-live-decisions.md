# DMARC Fleet Rollout, Collector-Domain Fix, and Mail Go-Live Decisions

Session: 2026-09-30 ~06:00–08:06 CEST (continuation of the 2026-09-29 mail-stack session, resuming from its handoff)
Repos touched: `~/projects/domains` (Terraform DNS), `~/projects/SystemNix`, `~/projects/pbx-artmann`
All work daemon-committed; all three repos' gates green at close.

---

## 0. One-paragraph summary

The owner answered the 2026-09-29 status report's §g questions: (Q1) "dmarc@ for all
my mailboxes — make sure they are superb" (source of truth: the domains repo),
(Q2) asked how likely direct-to-MX is (answered with verified research; decision:
stay on the Resend relay with a dated revisit trigger), (Q3) republish the
installer release BEFORE the mail go-live. While executing Q1 I found the inherited
design was **broken**: the planned collector `dmarc@artmann.tech` can never receive
a single report because artmann.tech's MX points at Google Workspace. The collector
moved to **`dmarc@larsartmann.cloud`** (the only fleet domain whose MX is ours), and
the full 17-domain DMARC rollout is now wired in the domains repo: per-domain rua,
the sole MX, 16 RFC 7489 §7.1 external-destination verification TXTs, two extended
Terraform modules with new test runs, and regenerated docs. SystemNix's parsedmarc
login and every living doc now name the correct collector. Apply (terraform) and
the rest of the go-live ladder remain owner-run.

---

## a) FULLY DONE

1. **Handoff verification (both repos)** — every claimed file change from the
   2026-09-29 handoff confirmed present and committed: SystemNix
   `dmarc-monitor` wiring (`enable = false`, configuration.nix), AGENTS.md
   §nix-email, TODO harvest row, status report; pbx-artmann flake input,
   `hosts/pbx/mail.nix`, backup.nix stalwart export, generate.sh secrets,
   mail-go-live runbook, TODO §9. Trees clean.
2. **Gate re-verification, both repos** — SystemNix `nix flake check --no-build
   --all-systems` and pbx full `nix flake check` green at session start (after
   waiting out a parallel session's untracked `journal-hot.nix`, which briefly
   blocked every SystemNix eval — the tracked-files trap; I did not touch their
   files and re-verified at quiescence).
3. **pbx format-safety drift fixed** — the gate flagged `TODO_LIST.md` dprint
   table-padding drift (sandbox "Permission denied" = dirty-file signal per the
   repo's documented incident); formatted, daemon committed.
4. **Owner decisions collected** — all three §g questions answered via the
   question tool; Q3 recorded in pbx TODO §6 row (republish-before-g0-live).
5. **Collector-domain defect found before it shipped** — artmann.tech is
   Google-Workspace-served (`google-workspace` module, MX → aspmx.l.google.com);
   helpless.ai is Gmail-served (`simple-gmail`). A Stalwart-side
   `dmarc@artmann.tech` would have received NOTHING and parsedmarc would have
   polled an empty inbox forever. Decision: collector = `dmarc@larsartmann.cloud`
   (only fleet domain whose MX we control).
6. **Domains repo — full 17-domain DMARC rollout WIRED** (commits `1a6b8d2`,
   `08eda79`, `84f0314`, `5dcda3a`, `251d65c`):
   - `modules/non-sending-domain`: new `dmarc_rua` variable (validated bare-email
     input, default "") rendering `rua=mailto:...` into the strict `_dmarc`
     record; test run added asserting the exact rendered string
     (`v=DMARC1; p=reject; rua=mailto:...; sp=reject; adkim=s; aspf=s`) — 2/2 green.
   - `modules/email-forwarding`: new `ttl`, `dmarc_rua`, `dmarc_policy`
     (default `none`) variables + a `records` output publishing one `_dmarc` TXT
     when rua is set. The 4 forwarding domains previously had ZERO DMARC
     (spoofable, no visibility). `p=none` + rua = zero deliverability risk for
     forwarded mail (forwarding breaks SPF; SPF deliberately untouched). 4/4
     test runs green (defaults, MERGE passthrough, rua-publishes, policy-renders).
   - 16 domain files wired with `dmarc_rua = "dmarc@larsartmann.cloud"`:
     google-workspace (artmann-holding.com, artmann.tech, issue-shield.com,
     lars.software, larsartmann.com), simple-gmail (helpless.ai, jetpackx.io,
     skylines.one), non-sending (artmann-technologies.com, baerenstein.ch,
     extract-metadata.tech), email-forwarding (artmann.foundation, artmann.group,
     maumi.club, maumiu.club — these also gained the records dynamic block +
     locals flatten they never had), plus larsartmann.cloud itself (non-sending
     module, same-domain rua — no verification TXT needed for it).
   - `larsartmann.cloud.tf`: the SOLE MX of the fleet (→ `mail.artmann.tech.`
     prio 10) + 16 RFC 7489 §7.1 external-destination verification TXTs
     (`<domain>._report._dmarc TXT "v=DMARC1"`, nobletary.com included, inert
     until its Google-Cloud-DNS zone gains the rua tag).
   - Module READMEs regenerated via terraform-docs (new inputs/outputs
     documented); repo TODO row added for the user-run apply.
   - `terraform validate` green; module test suites green; dprint clean.
7. **SystemNix updated** (commits `a338e3d9`, `c353200c`):
   `configuration.nix` `settings.imap.user = "dmarc@larsartmann.cloud"` + a
   comment block explaining WHY (Google-Workspace catch, rollout pointer);
   AGENTS.md §nix-email bullet extended with the collector-domain decision;
   `docs/todo/services.md` harvest row rewritten (collector domain, new owner
   sequence incl. the republish-first step). Queue one-liner and library entry
   edited together per the TODO-system drift rule.
8. **pbx-artmann runbook rewritten** (commits `bef58bd`, `0d22030`):
   new step 0 (installer republish FIRST — owner decision Q3), §4 fully rewritten
   (MX on larsartmann.cloud ONLY, per-domain rua, verification TXTs, SPF
   unchanged, apply instructions), §5 provisioning account renamed to
   `dmarc@larsartmann.cloud` (+ personal-mailbox example fixed to
   `@larsartmann.cloud` — an `@artmann.tech` mailbox there would receive
   nothing), §6 carries the relay-now decision with VERIFIED numbers (Resend
   free 100/day, 3,000/mo; Pro $20/mo 50k/mo) and a dated revisit trigger
   (~80 mails/day sustained or Pro-pricing distaste) plus the verified
   direct-MX pain ladder (Spamhaus PBL policy listing, 1-year expiring
   self-delist, Microsoft S3150/olcsupport reality). TODO §9 rows 4–5 rewritten
   to match. Full `nix flake check` green (includes format-safety + all docs
   gates).
9. **Outbound claims verified before use** — Resend tier limits and the
   Hetzner/Spamhaus-PBL/Microsoft deliverability picture researched live (both
   from primary sources: resend.com/pricing, spamhaus.org, docs.hetzner.com)
   before encoding into the runbook.

## b) PARTIALLY DONE

1. **The DMARC fleet rollout is WIRED, not APPLIED** — DNS is unchanged until
   the owner runs `nix run .#plan` → `.#apply` → `.#dns-audit` in
   `~/projects/domains`. Until then: no rua anywhere live, no MX on
   larsartmann.cloud, no verification TXTs.
2. **dmarc-monitor on evo-x2: still `enable = false`** — correct-by-design;
   the flip remains the FINAL go-live step (runbook §7) after the
   `dmarc@larsartmann.cloud` mailbox exists.
3. **TLS-RPT silently dropped from runbook §4 during my rewrite** — the old
   text had an "Optional hardening: `_smtp._tls` TLS-RPT + MTA-STS" bullet; my
   rewrite removed it while fixing the collector domain and I did not re-add it
   anywhere. parsedmarc can process SMTP-TLS reports too, so this is a real
   (optional) gap, now tracked as a next step.
4. **email-forwarding README "Usage" section not extended at rollout time** —
   terraform-docs updated the Inputs/Outputs tables, but the hand-written Usage
   example still showed the old resource shape. FIXED during report authoring
   (the records dynamic-block wiring example is in place now); recorded here
   for timeline accuracy.
5. **The 2026-09-29 status report not annotated** — its §b/§e/§g lines still
   say `dmarc@artmann.tech` (historical snapshot doctrine: living docs updated,
   dated report left as-is). A docs-health-style supersession annotation is
   queued as a next step.
6. **nobletary.com's `_dmarc` rua** — its zone lives on Google Cloud DNS
   (out of the repo's reach; the resource there only pins NS). The
   verification TXT is in place (inert); the rua itself needs a manual
   Google-Cloud-DNS edit (owner).
7. **Receiver-alignment data collection** — the Google-served domains
   (helpless.ai, jetpackx.io, skylines.one) stay `p=none` and the 4 forwarding
   domains start `p=none` deliberately; tightening is data-driven and later.

## c) NOT STARTED

1. tflint (`nix run .#lint`) and trivy (`nix run .#security`) over the new HCL.
2. The full 12-module test-suite loop (`nix run .#test`) — I ran only the two
   edited modules' suites.
3. Verifying the RFC 7489 §7.1 verification-record NAME format against the RFC
   text itself (I encoded `<reporting-domain>._report._dmarc.<collector-domain>`
   from working knowledge; the shape matches common practice, but the
   verify-external-claims doctrine wants the primary source checked before the
   user pays an apply cycle on it — inert-if-wrong, but still).
4. Root-causing the terraform-fmt disagreement (the pre-commit hook's pinned
   terraform vs the devShell terraform formatted the same tree differently —
   alignment on `source`/`ttl` blocks; resolved by re-running devShell fmt, but
   WHICH binary/version diverges and why is unknown; risks recurring
   daemon-commit vs flake-check fights on every future HCL edit).
5. `--all-systems` flake check in the domains repo (SystemNix's 2026-09-28
   lesson: a plain check silently omits foreign systems).
6. The entire owner go-live ladder (runbook §0–§7): installer republish,
   Hetzner :25/:465 limit request, secrets, A record, pbx deploy, DMARC apply,
   Stalwart provisioning, outbound smoke, sops paste + flip.
7. Assistant TODOs already queued in pbx TODO §9: nix-email eval-contract test
   (~30 lines), ACME-bootstrap OnFailure alerting, post-cutover Gatus external
   checks (only after MX lands), stalwart restore-drill arm.

## d) TOTALLY FUCKED UP (honest self-critique)

Nothing catastrophic landed — everything shipped is gated green and dormant —
but four things were sloppy or came too close:

1. **I claimed "FMT-CLEAN" from a broken pipeline** — `terraform fmt -check
   -recursive 2>&1 | head -10; echo "fmt-rc=$?"` measures `head`'s exit code,
   not terraform's. That exact run had listed 5 dirty files; my "rc=0" reading
   was noise. The house rule ("a `| tail` chain masks exit codes — always
   capture rc or pipefail") exists precisely for this and I re-committed it
   mid-session. The flake-check hook caught the residue; I then re-ran fmt
   properly. Discipline failure, zero shipped damage.
2. **My bulk perl insert produced misaligned HCL in 8 files** — the alignment
   must follow each block's longest key; the pre-commit terraform-fmt hook
   caught it on the next gate run and a second fmt pass fixed it. A two-round
   fix for a one-round job; a per-file careful edit (or running the hook's own
   formatter BEFORE the gate) was the right move.
3. **terraform-docs first invocation created nested junk dirs**
   (`modules/<m>/modules/<m>/README.md`) because I passed a parent-relative
   path; cleaned and re-run from inside each module dir (end state verified
   clean), but I shipped garbage paths to disk on the first try.
4. **The inherited plan itself was broken and I verified claims before acting —
   but only via the user's "make it superb" prompt.** The previous session
   wired `dmarc@artmann.tech` as collector without checking artmann.tech's MX
   (Google Workspace). I ran the question round and read the domains repo
   because of the user's nudge, not because my own checklist demanded it. A
   "verify every DNS assumption against the domains repo" step belonged in the
   original bring-up. (Catch credit: the defect never reached an apply.)

## e) WHAT WE SHOULD IMPROVE

1. **Verify external/RFC claims against the primary source before encoding
   them into DNS or docs** — the §7.1 record format went in from memory; a
   2-minute RFC fetch would make the apply cycle risk-free.
2. **Check the domains repo BEFORE designing mail topology** — MX ownership
   per domain (Google Workspace / Gmail / ours) is THE input to any
   mailbox-location decision; it should have been step 1 on 2026-09-29.
3. **pipefail/rc-capture discipline** — capture exit codes directly or
   `set -o pipefail`; never read `$?` after a pipeline stage.
4. **Apply-ordering-sensitive Terraform changes should be split into separate
   commits** — the rollout wires the larsartmann.cloud MX together with the
   DMARC records, but the runbook says MX only AFTER the Hetzner unblock.
   Nothing stops the owner from one `apply` of everything today (harmless for
   a brand-new receiving domain — reports just bounce until the stack lives —
   but it violates the runbook's own ordering doctrine). Either split the MX
   into a follow-up commit or make the TODO row scream the ordering.
5. **One formatter per surface, resolved before the gate** — run the same
   terraform binary the pre-commit hook pins before declaring a tree
   format-clean.
6. **Annotate superseded status reports** when a decision invalidates them
   (docs-health doctrine) instead of leaving stale lines for the next reader.
7. **Record optional-hardening removals explicitly** — the TLS-RPT bullet
   vanished from §4 in a rewrite without a trace; removals need a breadcrumb
   (TODO row or "deferred" note), not silent deletion.

## f) NEXT (up to 50, ordered: owner-gated go-live ladder first, then
assistant-executable, then hardening/polish)

**Owner — mail go-live ladder (pbx TODO §9 / runbook §0–§7):**
1. Republish the installer release: `./installer/publish-release.sh`, then
   `nix run .#release-freshness` (expect FRESH) — decision: BEFORE go-live.
2. File the Hetzner limit request for :25/:465 (Console → Limits).
3. Create `stalwart_fallback_admin` + `stalwart_relay_password` in
   `~/.pbx-prod-secrets`, add both to `push-secrets.sh`, push.
4. Add `A` `mail.artmann.tech` → VPS IP in the domains repo and apply JUST
   that (see item 33 for the split), then deploy pbx (user-run) and verify
   `acme-mail.artmann.tech.service` + `stalwart.service` active.
5. Apply the DMARC fleet rollout: `nix run .#plan` → review → `.#apply` →
   `nix run .#dns-audit` (ordering vs the Hetzner unblock: item 33/question g1).
6. Provision Stalwart over the SSH tunnel: domains `artmann.tech` +
   `larsartmann.cloud`; account principal NAME `dmarc@larsartmann.cloud`;
   personal mailbox (question g2).
7. Outbound smoke `From: lars@larsartmann.cloud` → journal + Resend dashboard.
8. Resend scoping decision for `@artmann.tech` envelopes (verify artmann.tech
   in Resend or commit to larsartmann.cloud as the sole sending identity).
9. Paste `dmarc-imap-password` into SystemNix sops
   `platforms/nixos/secrets/nix-email.yaml`, flip
   `services.dmarc-monitor.enable = true`, `nix run .#deploy` (FINAL).
10. Verify end-to-end: parsedmarc active; first report parsed into
    `/var/lib/parsedmarc/reports`; dmarc-monitor backup-freshness row green.
11. Watch the Resend daily-send volume against the ~80/day revisit trigger
    encoded in runbook §6.
12. nobletary.com: add `rua=mailto:dmarc@larsartmann.cloud` to its `_dmarc` in
    Google Cloud DNS manually (verification TXT already wired, inert).

**Assistant-executable (queued/ready):**
13. Split-or-annotate the domains rollout so the larsartmann.cloud MX carries
    an explicit "apply only post-unblock" marker (commit split or loud TODO
    note + plan-time comment).
14. Verify the RFC 7489 §7.1 record name format against the RFC text before
    the apply (5 minutes; encode the citation in the Terraform comment).
15. Re-add TLS-RPT as explicit optional hardening (runbook §4 note + a wired
    `_smtp._tls TXT "v=TLSRPTv1; rua=mailto:dmarc@larsartmann.cloud"` on the
    two sending domains, or a deliberate decision to skip).
16. Extend the email-forwarding README Usage section with the records
    dynamic-block wiring example the 4 domain files now use.
17. Annotate the 2026-09-29 status report (§b/§e/§g) with the
    collector-domain supersession per docs-health doctrine.
18. nix-email eval-contract test in pbx-artmann (~30 lines, SystemNix
    `tests/test-nix-email.nix` shape).
19. ACME-bootstrap alerting: OnFailure on `acme-mail.artmann.tech.service`
    (today a typo'd DNS record is silent ~5-min journal noise forever).
20. Post-cutover Gatus external checks on evo-x2
    (`starttls://mail.artmann.tech:25`, `tls://mail.artmann.tech:993`,
    `CERTIFICATE_EXPIRATION > 720h`) — add ONLY after MX lands (red-until-live
    by design).
21. stalwart-store restore drill: extend backup-restore.md with the
    `stalwart-store.tgz` arm once real mail exists.
22. Root-cause the terraform-fmt hook vs devShell terraform divergence
    (identify the hook's pinned binary/version; align them or document the
    difference so trees stop flipping between two formattings).
23. Run `nix run .#lint` (tflint) and `nix run .#security` (trivy) over the
    new HCL.
24. Run the full 12-module test loop (`nix run .#test`) in the domains repo.
25. Add `--all-systems` to the domains repo's flake check (SystemNix
    2026-09-28 lesson).
26. Make the domains devShell pin the SAME terraform the pre-commit hook uses
    (single formatter arbiter doctrine, ports cleanly from SystemNix).
27. SigNoz: a DMARC-reports panel/rule once reports flow (parsedmarc output
    rate; zero-reports-in-7d alert on the collector).
28. Confirm at flip time that parsedmarc's monitoredServices entry + the
    reports-freshness backup row are actually live in system-health (the
    wrapper wires them; verify on the deployed generation, not the eval).
29. Stalwart DKIM keys for larsartmann.cloud (store data; provisioning step
    extension in runbook §5 if relay DKIM alignment is wanted later).
30. Pin Hetzner rDNS for the VPS IP → `mail.artmann.tech` early (harmless
    now, required the day direct-MX is ever revisited).
31. Data-driven DMARC tightening review after ~30 days of reports:
    helpless.ai / jetpackx.io / skylines.one `p=none` → quarantine candidates.
32. Same review for the 4 forwarding domains (`p=none` → quarantine) + decide
    whether forwarding SPF/SRS investment is ever worth it (question g3).
33. If g1 answers "split": carve the MX record into its own commit gated on
    the unblock; if "apply now": fix the runbook TODO wording to bless early
    apply explicitly.
34. Sweep `docs/` + both repos' AGENTS.md for any remaining
    `dmarc@artmann.tech` references once the flip is done (the historical
    status report keeps them by design; nothing else should).
35. pbx TODO row 153 (Resend scoping) closes with item 8's decision — link
    the two rows so one close closes both.

**Hardening/polish (lower priority):**
36. parsedmarc `mailbox.watch = true` behavior check in VM (IMAP IDLE vs
    poll cadence) at flip time.
37. DMARC report volume sizing: estimate expected reports/day from 17 domains
    after first week; tune parsedmarc retention + the reports backup window.
38. Add the collector mailbox to Stalwart's backup verification checklist
    (backup-restore.md) — the dmarc principal's inbox is now operationally
    load-bearing.
39. Consider `sp=reject` → `sp=quarantine` review for larsartmann.cloud once
    subdomain sending patterns are known (currently inherits reject).
40. README (domains repo): add the DMARC collector convention (one
    MX-controlled collector domain + per-domain rua + verification TXTs) to
    the module-catalog docs so the pattern survives repo churn.
41. upstream nix-email: contribute the collector-domain gotcha
    ("put the rua mailbox on an MX-controlled domain; check what already owns
    the MX") to the upstream README (docs/todo/upstream.md row).
42. Upstream nix-email: the dmarc-monitor module could eval-assert that
    `settings.imap.host` resolves to a domain the module itself does not own
    an MX for — soft warning, prevents the exact class this session caught.
43. domains repo: consider a `terraform test` at the ROOT level asserting the
    larsartmann.cloud zone renders exactly ONE MX + 16 verification TXTs
    (fleet invariant, currently only implied by the HCL).
44. Domains TODO: the drift-report app row (already queued) would have made
    the apply preview of this rollout trivially reviewable — bump its
    priority when the apply happens.
45. Namecheap API: confirm the verification TXT records render with the
    dotted hostname intact (`<domain>._report._dmarc`) in `#dns-audit` after
    apply (provider quirks with multi-label TXT hostnames are a known genre).
46. After the flip: add `dmarc@larsartmann.cloud` to the SystemNix mail-relay
    postmaster/canonical map story only if system mail should DMARC-report
    (probably not — note why not, one line, in mail-relay.md).
47. Keep an eye on the parallel session's journald-hot work (journal-hot.nix)
    for its own follow-ups — unrelated, but it entered every eval this
    session.
48. pbx: consider moving the relay-password placeholder warning into
    pre-deploy-check-style gating when this repo grows one (currently
    generate.sh FATALs — sufficient; revisit only on touch).
49. House-keeping: the 2026-09-29 status report §f.18 flagged a foreign
    flake-update.yml provenance question — still unresolved upstream of this
    session; leave flagged.
50. Celebrate when the first aggregate report lands in
    `/var/lib/parsedmarc/reports` — then tighten policies with real data.

### f-harvest ledger (self-harvest rule, 2026-09-30)

Direct follow-ups landed in TODO systems at authoring time: items **13 + 14**
→ the domains repo `TODO_LIST.md` DMARC-rollout row (ordering warning + RFC
check appended); **15 + 17 + 28 (+27's panel half)** → SystemNix
`TODO_LIST.md` queue row + `docs/todo/services.md` library row; item **16**
was fixed on sight during authoring (report §b.4 updated). Deliberately NOT
harvested into SystemNix: items 1–12 and 35 (already live as pbx TODO §9 /
domains TODO rows — queueing them again would duplicate), 18–21 (already
queued in pbx TODO §9 by the previous session), 22–26 + 43–45 (domains-repo
tooling improvements — they belong in the domains repo's TODO on its next
touch; not parked in a foreign repo's queue), 29–31 + 39–40 (gated on real
mail/report data — premature as queue rows), 42 (upstream contribution —
routed to docs/todo/upstream.md doctrine on next touch), 47 (parallel
session's work), 48–50 (no-ops/revisit triggers already encoded in the
runbook).

## g) Questions for the owner (cannot figure out myself)

1. **Apply ordering for the DMARC rollout:** the Terraform wires the
   larsartmann.cloud MX together with the rua/verification TXTs, but the
   runbook says MX only after the Hetzner unblock. Apply everything NOW
   (early reports bounce harmlessly — the collector doesn't exist yet — but
   it breaks the runbook's own ordering rule), or should I SPLIT the MX into
   a second apply gated on the unblock?
2. **Personal mailbox on Stalwart:** do you want a real personal mailbox
   (e.g. `lars@larsartmann.cloud`) provisioned on the pbx server during
   runbook §5, or does all personal mail stay on Google Workspace/Gmail for
   now (making Stalwart a DMARC-collector + future-purpose server)?
3. **Forwarding-domain risk appetite:** artmann.foundation, artmann.group,
   maumi.club, maumiu.club now carry `p=none` + rua (visibility only). After
   ~30 days of report data: keep `p=none` forever (forwarding is
   SPF-hostile; quarantine/reject risks eating legit forwarded mail), invest
   in SRS/proper forwarding later, or tighten to quarantine on data?

### Answers (owner, 2026-09-30 08:15, via question tool)

1. **Apply everything NOW** — the early-MX concern is blessed away; runbook
   §4 and the pbx TODO row updated to bless early apply explicitly (pre-unblock
   reports bounce harmlessly; no existing mail affected).
2. **Personal mailbox YES, provision at go-live** — runbook §5.3 now names
   `lars@larsartmann.cloud` as the provisioning item.
3. **Decide on data** — the p=none + rua start stands; revisit after ~30 days
   of report data (items f.31/f.32).

---

## Verification summary (what proves the above)

- SystemNix: `nix flake check --no-build --all-systems` → all checks passed
  (includes `checks.nix-email-contract` against the upstream module).
- pbx-artmann: `nix flake check` → all checks passed (includes format-safety,
  docs-annotate, docs-freshness, docs-numbers).
- domains: `nix flake check` → all checks passed (pre-commit parity incl.
  terraform-fmt, typos); `terraform validate` → Success; module suites:
  non-sending 2/2, email-forwarding 4/4; `terraform fmt -check -recursive` →
  clean (after the second, correct pass).
- Everything daemon-committed at close: domains `5dcda3a` (HEAD),
  SystemNix `a338e3d9`+`c353200c`, pbx `0d22030`. Working trees clean except a
  parallel session's in-flight indexer-web harvest (not mine, untouched).
