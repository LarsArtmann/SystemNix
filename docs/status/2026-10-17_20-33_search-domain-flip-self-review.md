# Status Report: Search-Domain Flip (`search home.lan` removal) — Diagnosis Review → Decision → Landing → Self-Review

**Date:** 2026-10-17 20:33 CEST
**Session scope:** Review of the dnsblockd-repo diagnosis `docs/research/2026-10-17_search-domain-wildcard-offline-resolution-diagnosis.md`, the owner decision to drop `search home.lan` (option B), and the landing of that decision in SystemNix. Nothing else. (Format note: `.md` at `docs/status/` per explicit user instruction — override of the skill's HTML default, flagged in the closing message.)

**One-line state:** the change is **committed and fully verified in git, NOT deployed** — it goes live with the next `nix run .#deploy`.

---

## a) FULLY DONE

1. **Diagnosis verified end-to-end before opining** — every load-bearing claim of the dnsblockd research doc was checked against primary sources, and all three operator observations were reproduced live:
   - O1 mechanism: `dig @127.0.0.1 wildcard-probe-20261017.home.lan` → `A 192.168.1.150` with owner synthesized to the queried name; `/etc/resolv.conf` live = `search home.lan`, no `ndots` override; dnsblockd `internal/dns/localzone.go:127-156` does exact-first + RFC 4592 rewrite (read in source).
   - O2: `dig forgeo` → NXDOMAIN, root SOA in AUTHORITY, `ad` set — byte-identical to the doc.
   - O3: bare SNI → `tlsv1 alert internal error (80)` from Caddy (`strict_sni_host on`, caddy.nix:450); FQDN SNI → dnsblockd-CA cert + branded 404.
   - Citations: wildcard + NB note (dns-blocker-config.nix:124-141), search line (dns-resolver.nix:39-43), catch-all (caddy.nix:465-482), gatus alert (gatus-config.nix:456-464), upstream fix `d5a22a4b` (exists, message matches), T356 harvest (landed in dnsblockd TODO_LIST.md).
   - Doc nits found: reverse name `forgejo.home.lan` comes from **/etc/hosts**, not DNS (`dig -x` has no PTR); O1's "forge.home.lan" exists nowhere; offline framing undersells the online typo case.
2. **Premise correction + evidence for the flip decision** — `dig forgeo` never used the search line (dig only expands with `+search`), so the owner's stated reason was inverted; the real value of `search` is getaddrinfo bare-label completion, and usage on evo-x2/rpi3 measured **zero** (fish history sweep: only `dig forgeo` itself; scripts/ sweep: FQDNs/IPs only; config grep: bare strings are all users/groups/subdomains/clientIds, never dialed hostnames). Blast radius confirmed: dns-resolver.nix imported by evo-x2 + rpi3 only, not darwin.
3. **`platforms/common/dns-resolver.nix` edited** — `search` line dropped, why-comment written, unused `config` arg removed. Verified: `nix eval --raw` on **both hosts** renders exactly `nameserver 127.0.0.1 / nameserver 9.9.9.9 / options edns0 trust-ad`; `nix flake check --no-build` → all checks passed, exit 0. Landed in daemon commit `cd8ddfed`.
4. **Alert-coupling pre-check** — `system_local_dns_resolves` probes the FQDN `auth.home.lan` via getent (system-health.nix:611), so the resolv.conf drift alert is structurally unaffected by the change. Checked BEFORE editing, not after.
5. **Runbook drift fixed on sight** — `docs/services/dnsblockd.md` still claimed "Wildcard `*.home.lan` does NOT resolve" (false since 2026-10-12, `d5a22a4b`); bullet rewritten to document the live wildcard + the search-domain consequence; resolv.conf bullet notes no-search.
6. **TODO + CHANGELOG** — `[decision]` row queued in `docs/todo/services.md` (LAN-clients half: MacBook/DHCP/routing domains); CHANGELOG entry with the full mechanism + deploy-pending marker.
7. **Daemon-race hygiene** — swept work rode pushed mixed-batch `cd8ddfed` (amend forbidden: pushed + non-exclusive); the skipped pre-commit legs were re-run standalone per CONTRIBUTING §270: deadnix, statix (dns-resolver.nix), shellcheck (both churned scripts), gitleaks (`cd8ddfed~1..cd8ddfed`) — all green.
8. **AGENTS.md falsified claim corrected** — the documented "scoped format of one file: `nix fmt . <path>`" walked 3395 files live; bullet now states there is NO effectively scoped form + the post-fmt `git status` habit. (Landed in `bddadc25` — see d2 for the crossed attribution.)

## b) PARTIALLY DONE

1. **The flip itself: verified in git, NOT live.** Deploy needs sudo and the tree carried a parallel session's in-flight edits (flake.lock/boot-mirror.nix, now committed; `scripts/test-deploy-pipeline.sh` still dirty at report time). Remaining: one `nix run .#deploy` + the 4 post-deploy probes below. Effort S. rpi3-dns rides its own (rarer) deploy — verify there too.
2. **Post-deploy probes defined, not run:** `/etc/resolv.conf` shows no search line; `getent hosts forge` FAILS (honest NXDOMAIN); `getent hosts forgejo.home.lan` still resolves; gatus "Local DNS System Resolver" stays green. CHANGELOG "deploy pending" flips to deployed in the same pass.
3. **dnsblockd-repo doc nits routed late** — the hosts-file-PTR and online-typo clauses were found at review time (~19:5x) but routed to dnsblockd's T356 only at this report's harvest (should have been immediate — see d3).

## c) NOT STARTED

1. **Post-deploy-check.sh assertion** — the "no search line" invariant has no machine gate yet (proportionate pin: one grep in §-structure; NOT an eval assertion — it's a static file). Queued [ready].
2. **Runbook pointer for the /etc/hosts zone shadow** — the `forgejo/catalog → lanIP` hosts entries (`platforms/nixos/system/networking.nix:37-40`) turned out DELIBERATE and documented in-config (nsswitch files-before-dns keeps unattended jobs resolving through dnsblockd restart windows — the 2026-10-14 catalog-sync deaths are cited right there); what's missing is only a pointer sentence in the dnsblockd runbook so future sessions stop re-discovering it as a split brain (this session did exactly that). Queued [ready]. Self-critique: I called it an "undocumented second truth source" at 19:57 without grepping the owning config — the grep happened only at harvest time.
3. **MacBook / other LAN clients** — owner `[decision]` row queued; deliberately not started.

## d) TOTALLY FUCKED UP

Nothing destructive: no data loss, no reverts, no secrets, no broken builds. But three real errors/near-misses, honestly:

1. **`nix fmt` tree-wide churn + self-masked detection.** I ran the documented scoped form and chained `git diff --stat <path>` scoped to MY file — which masked the churn (2 foreign scripts reformatted) for one full command cycle; a full `git status` one call later caught it. Kept (canonical form; shellcheck-green; pre-commit enforces the same), but the detection was luck-shaped, not discipline-shaped. Root cause: trusted a falsified doc claim AND used a scoped diff where only a full status answers the question.
2. **Dropped a live attribution mismatch.** `bddadc25` ("docs(agents): add busctl ListJobs…", 1+/1-) actually carries MY formatter-claim paragraph, while the other session's busctl line rode heuristic `ba60821e` — a message/content crossing exactly of the CONTRIBUTING §266 class. I noticed the ambiguity, ran ONE `git log -L` (silently empty), and shrugged for ~30 minutes until this report's greps settled it by accident. The immediate-settle tool was `git log -p -- AGENTS.md`, one command. Nothing repairable (both commits pushed), but the hesitation was wrong.
3. **Observation-routing failure (the repo's own cardinal sin).** I discovered the /etc/hosts second-truth-source live at 19:57, called it "worth knowing about" in chat, and routed nothing for an hour. Identified → discussed → NOT queued is the ghost-observation class TODO hygiene exists to kill. Fixed at this report's harvest. Compounding: the callout itself was under-researched — the owning config comment (networking.nix:28-36) answers the question I posed about it; I grepped the config only at harvest time.

## e) WHAT WE SHOULD IMPROVE

1. **After ANY `nix fmt`: full `git status --short` immediately** — never a path-scoped diff as the post-check. (Now also written into the AGENTS.md fmt bullet.)
2. **Attribution mismatches: settle with `git log -p -- <file>`, immediately.** `git log -L` can fail silently; deferring leaves a §266 specimen undocumented. Candidate clause for CONTRIBUTING's daemon-race policy (queued).
3. **Route observations at discovery time.** AGENTS TODO-rule violated by this very session; the fix is always "append the row now", never "mention it in prose".
4. **Verification-matrix discipline when reviewing diagnosis docs:** run the runnable rows (`dig +search forgeo` was runnable; I proved the mechanism with an equivalent direct query instead — acceptable, but the matrix row would have been free evidence).
5. **Grep the owning config BEFORE naming a split brain.** My /etc/hosts "undocumented second truth source" callout had the answer one `rg` away in its own config comment — naming drift that isn't drift costs the next reader a rediscovery loop (this session was that reader).

## f) Next tasks (harvested to TODO_LIST.md + domain libraries at authoring time — not entombed)

| # | Task | Impact | Effort | State |
|---|------|--------|--------|-------|
| 1 | Deploy evo-x2 (`nix run .#deploy`) once the parallel session's tree settles; run the 4 post-deploy probes; flip CHANGELOG deploy-pending; rpi3 verifies on its next deploy | High | S | `[blocked:deploy]` → library |
| 2 | Add resolv.conf no-search assertion to `scripts/post-deploy-check.sh` (grep live file; both hosts) | Medium | S | `[ready]` → queue + pipeline.md |
| 3 | dnsblockd runbook: one pointer sentence for the DELIBERATE /etc/hosts zone shadow (networking.nix:37-40, restart-window resilience for unattended jobs) so it stops being re-discovered as a split brain | Low | S | `[ready]` → queue + services.md |
| 4 | LAN-clients search policy (MacBook/DHCP/resolved routing domains) | Medium | M | `[decision]` already queued |
| 5 | CONTRIBUTING daemon-race: add the `git log -p` (not `-L`) immediate-attribution-settle clause, citing the bddadc25/ba60821e crossing | Low | S | `[ready]` → queue + pipeline.md |
| 6 | dnsblockd T356 amendment: hosts-file PTR naming + online-typo expansion clause (cross-repo) | Low | S | landed at harvest |
| 7 | Optional UX: `~/.ssh/config` Host aliases if bare-label ssh habit surfaces post-deploy | Low | S | observe first |

Deliberately not padded to 50: the honest count from this session's scope is 7 (queueing 43 filler rows would violate the TODO system's own anti-padding precedent).

## g) Questions (cannot be figured out myself)

1. **Deploy timing:** run the deploy for this now, or batch it with the pending boot-noise deploy (same "deploy pending" marker)? A parallel session is mid-flight on `scripts/test-deploy-pipeline.sh` — deploying while its work is half-landed risks sweeping it into activation.
2. **Withdrawn at authoring time:** the planned "/etc/hosts intent" question — the intent is documented in the owning config comment (networking.nix:28-36: restart-window resilience for unattended jobs, 2026-10-14 catalog-sync incident cited). I could have read it before posing the question; doing so moved task 3 from "decide" to "document the pointer".

(Third question withheld — the MacBook follow-up is already the queued `[decision]` row; asking it twice adds nothing.)

---

**Self-review checklist (brutal-self-review skill):** forgot = hosts-row routing (d3), matrix rows (e4); stupid = scoped-diff masking (d1); lies = none found (every §a claim re-checked against session evidence); ghost systems = none created, one "found" that turned out documented-in-config (my discovery was re-discovery — see e3); split brains = same item, resolved as deliberate shadow, runbook pointer queued (task 3); scope creep = none (stayed inside the DNS decision all session); removed-something-useful = the search line itself, evidenced zero-usage + replacement path (ssh aliases, task 7); tests = eval-render verification is the proportionate pin for a static file, machine gate queued (task 2).

**Landing commits:** `cd8ddfed` (my 5 files + formatter churn + foreign pareto doc, daemon batch), `bddadc25` (AGENTS.md formatter-claim fix under crossed message), `b3604255` (later heuristic sweep incl. flake.lock/boot-mirror from the parallel session).
