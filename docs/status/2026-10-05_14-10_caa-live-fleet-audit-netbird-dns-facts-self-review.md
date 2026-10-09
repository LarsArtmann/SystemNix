# Status Report — CAA go-live, fleet audit, NetBird DNS facts + session self-review

_2026-10-05 14:10 CEST · session scope: the auth-flake/IP-DNS/NetBird exploration + execution run
(this file reports THIS session only, per operator instruction; repo-wide state lives in
TODO_LIST.md + docs/todo/\*.md)_

**Context in one line:** the session started as an architecture question (reusable Pocket ID
flake + two-instance sync), discovered mid-flight that a ratified plan
(`docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md`) had already
answered it, and pivoted to executing the genuinely-open IP/DNS hardening items — landing the
repo's own queued CAA task live, correcting two of my own unverified claims, and queueing the
deferred decisions.

---

## a) FULLY DONE

| # | What                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Evidence                                                                                                                                                                                                                                                                                                              |
| - | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 | **CAA records for `larsartmann.cloud` — APPLIED + LIVE**: `0 issue "letsencrypt.org"` + `0 iodef "mailto:security@artmann.tech"` via the domains repo's `caa-records` module (`allow_wildcards = false`, exactly 2 records)                                                                                                                                                                                                                          | scoped `-target` apply from evo-x2 (proven local recipe); live API verified via `nix run .#dns-prune -- --list CAA larsartmann.cloud`; authoritative NS dns1+dns2.registrar-servers.com AND public 1.1.1.1 both serve both records (dig, 2026-10-05 ~12:10Z); CHANGELOG entry landed; TODO row closed per repo legend |
| 2 | **Fleet CAA audit** — all 16 managed zones dug live; 8 carry NO CAA (artmann.foundation, artmann.group, artmann-technologies.com, baerenstein.ch, jetpackx.io, maumi.club, maumiu.club, skylines.one); row queued with per-zone decision framing                                                                                                                                                                                                     | domains TODO_LIST "Email & DNS hardening" (2026-10-05 row)                                                                                                                                                                                                                                                            |
| 3 | **NetBird DNS facts source-verified and documented** — nameservers are UDP-ONLY (API enum, `dns/nameserver.go`; no dot/doq/doh schemes), custom port supported, mesh-reachable-resolver queries ride INSIDE the WireGuard tunnel (plain :53 ≠ plaintext-on-wire) → runbook Phase-2 step 6 enriched (+ mandatory UDP-53 ACL toward 192.168.1.53, source-IP-preserving-route note), new step 9 (phone exit node = roaming adblock + encrypted off-LAN) | `docs/services/net-vpn.md` (grep-verified; parallel-session routes correction preserved intact)                                                                                                                                                                                                                       |
| 4 | **Stale "DoQ 853" fact corrected** in the ratified brainstorm doc — live `ss -lun` on evo-x2 shows plain :53 only, no encrypted listener                                                                                                                                                                                                                                                                                                             | dated correction inside `docs/brainstorming/2026-09-30_net-*.md` §2                                                                                                                                                                                                                                                   |
| 5 | **Todo-system rows landed** (both surfaces per house rules): security.md `[decision]` Dex→Pocket-ID convergence (kills the second password once Pocket ID is mesh-reachable; setup-key enrollment never touches the IdP); services.md `[blocked:user]` exit node + `[watch]` ULA (home has NO IPv6 at all — `dnsIPv6Enabled = false`); phase-2 row enriched with the DNS facts                                                                       | `bash scripts/check-todo-system.sh` → "OK: TODO queue/library structure clean"                                                                                                                                                                                                                                        |
| 6 | **domains README/FEATURES `caa-records` usage count corrected 4→5** (my module instance made it stale — live `rg` count = 5 domain files)                                                                                                                                                                                                                                                                                                            | README.md:95, FEATURES.md:48                                                                                                                                                                                                                                                                                          |
| 7 | Two parallel-session write races on `net-vpn.md` detected and handled (re-read, merge instead of overwrite)                                                                                                                                                                                                                                                                                                                                          | this session's edit tool errors + preserved foreign routes-fix                                                                                                                                                                                                                                                        |

## b) PARTIALLY DONE

| What works                                                      | What remains open                                                                                                                                         | Blocker                                                                                                         | Effort                  |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------- |
| Registrar is LIVE with the CAA records (local scoped apply)     | domains repo GitHub/runner state lags the working tree — daemon commits exist locally, nothing pushed; CI drift-check will see the change only after push | agent push ban (by design) — owner push closes it                                                               | S (user)                |
| CAA coverage: 1 of 9 bare zones fixed                           | 8 zones still bare — per-zone strictness (`issue ";"` lockdown vs usage sets) undecided                                                                   | owner product decision per zone (which zones are alive at all is itself open — ROADMAP "live sites vs zombies") | S per zone once decided |
| Phase-2 runbook guidance enriched (DNS/ACL/exit-node/source-IP) | the flip itself (setup key, sops, enable, dashboard config) is untouched                                                                                  | user-gated handover by design                                                                                   | M (user)                |
| Dex→Pocket-ID convergence framed + queued                       | not designed/executed; brainstorm §5 table unannotated until decision                                                                                     | `[decision]` — owner; also benefits from mesh being up first                                                    | M                       |

## c) NOT STARTED

1. **Reusable Pocket ID flake** (turn-1 design) — deliberately NOT started: the ratified
   net-vpn plan §5 already evaluated and rejected dual-instance/HA Pocket ID ("no dual-active
   ever", C3 analysis). Recorded here so nobody re-opens it without contradicting that decision
   first. The only survivor from that design: the extraction pattern itself, if Pocket ID ever
   needs to run on a second host for OTHER reasons.
2. **dnsblockd encrypted listener (DoT/DoQ/DoH)** — deliberately REJECTED this session:
   NetBird cannot express encrypted nameservers (UDP-only), and VPN queries are
   tunnel-encrypted by construction. Revisit trigger: a non-tunnel client needing the resolver
   (none exists).
3. **DNSSEC for larsartmann.cloud** — queued in domains TODO; gated on the nix-email/port-25
   timeline + a Namecheap DNSSEC-support check for the .cloud TLD.
4. **iodef mailbox sanity** (`security@artmann.tech` deliverability) — unverified; CAs rarely
   mail it; low value.
5. Push + CI reconciliation of the domains repo (user).

## d) TOTALLY FUCKED UP

Nothing production-harmful landed (the only live change was additive, scoped, verified
end-to-end). But three honest failures, all mine:

1. **Turn-1 answered an architecture question while the answer sat unread in the repo.**
   I designed a full reusable-flake + warm-standby sync architecture for Pocket ID and
   presented it — without discovering that `docs/brainstorming/2026-09-30_netbird-*.md`
   (owner-ratified five days earlier) had already analyzed exactly that (its §5 option C) and
   REJECTED it, deciding Pocket ID stays single-instance on evo-x2. One
   `rg -il "pocket-id|vps" docs/brainstorming docs/planning` before answering would have
   found it. Severity: the user's first answer was materially misleading; a full turn was
   wasted. Root cause: I searched the SERVICE layer (runbooks, sso-dns) but never the PLANNING
   layer.
2. **Turn-2 shipped unverified claims under a "Verified the load-bearing facts first" banner.**
   The verification was real — for Pocket ID upstream + the nixpkgs module. But three adjacent
   assertions rode along unverified and were FALSE: "artmann.tech has no CAA" (it had four
   records incl. letsencrypt.org since the 2026-09-16 incident), "dnsblockd already serves
   DoQ 853" (stale doc claim; live `ss` shows nothing on :853), "point the nameserver group at
   encrypted ports" (impossible — UDP-only enum). This is the repo's own
   "assert WHICH question your evidence answers" rule violated in conversational form: the
   verification label covered the facts I checked, not the facts I asserted. All three were
   corrected during execution — but only because execution forced live checks.
3. **Wrong expected-outcome in a queued TODO row.** I wrote "verify: dig CAA → 3 records" —
   the actual and correct result is 2 (`allow_wildcards = false` emits no `issuewild`). Caught
   at live verification before any dispatch rode on it. Root cause: counted by analogy with
   artmann.tech's 4-record shape instead of deriving from the module's conditional logic —
   which I had READ the same session.

## e) WHAT WE SHOULD IMPROVE

1. **Planning-layer pre-read is not a formal step for architecture questions** in this repo.
   Fix (landing with this report): an AGENTS.md Session Discipline bullet — before proposing
   or designing any architecture, `rg -il` the topic across `docs/brainstorming/` +
   `docs/planning/`; a ratified plan outranks a fresh design. Impact: prevents whole wasted
   turns (this session: 1 of 3).
2. **Live-state check before asserting a capability.** "Doc says X serves Y" is a hypothesis;
   `ss`/`dig`/config-grep is the answer. Same AGENTS bullet, second clause (the DoQ case).
3. **Derive expected outcomes from source conditionals, not sibling examples** (the 3-vs-2
   count). Cheapest fix: when writing a verification step, re-read the generator's
   conditional that produces the count.
4. **domains repo: `dns-audit` does not check CAA posture** — the weekly CI drift check
   covers records Terraform manages, but an out-of-band CAA removal (or the 8 bare zones)
   is invisible. Extension: assert per-zone expected CAA set (queued, item f.2).
5. **Process note:** status-report skill default is HTML; operator demanded `.md` — honored,
   flagged, NOT propagated back into the skill (per its own override rule).

## f) Next things (session-scoped; ranked, not padded — 16 honest items, not 50)

| #  | Task                                                                                                                                                                   | Impact | Effort | Status surface                                                                                                                                |
| -- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| 1  | Push domains repo → reconcile CI state with the live zone                                                                                                              | High   | S      | user; this report §b                                                                                                                          |
| 2  | Extend `dns-audit` to verify live CAA per zone (expected-set assertion; catches out-of-band removal + the MERGE blind spot)                                            | Medium | S      | NEW row (domains TODO, Module & code health)                                                                                                  |
| 3  | Watch: first LE renewal of `netbird.`/`relay.larsartmann.cloud` AFTER CAA introduction (due ~60–90d, ≈ 2026-12) stays green — CAA misconfig would only bite at renewal | Medium | S      | NEW row (domains TODO, watch)                                                                                                                 |
| 4  | Owner: per-zone CAA decisions for the 8 bare zones (lockdown vs usage sets)                                                                                            | High   | S/zone | queued during session (domains TODO)                                                                                                          |
| 5  | DNSSEC for larsartmann.cloud before nix-email MX go-live                                                                                                               | Medium | M      | queued during session (domains TODO)                                                                                                          |
| 6  | Owner: Resend link-tracking decision for larsartmann.cloud (adds `links` CNAME + `issue "amazon.com"` in one change if yes)                                            | Low    | S      | domains ROADMAP #10                                                                                                                           |
| 7  | NetBird Phase-2 flip (setup key → sops → enable → dashboard config incl. the new UDP-53 ACL requirement)                                                               | High   | M      | existing row (services.md)                                                                                                                    |
| 8  | Dex→Pocket-ID IdP convergence decision (post-mesh)                                                                                                                     | Medium | M      | queued during session (security.md)                                                                                                           |
| 9  | Exit node for the phone post-burn-in (roaming adblock + full-tunnel)                                                                                                   | Medium | S      | queued during session (services.md)                                                                                                           |
| 10 | AGENTS.md Session Discipline bullet: planning-layer pre-read + live-state verification before asserting capabilities                                                   | Medium | S      | landed with this report                                                                                                                       |
| 11 | ULA adoption watch (only when IPv6 ever lands at home; PTR rides it)                                                                                                   | Low    | M      | queued during session (services.md)                                                                                                           |
| 12 | SSL-expiry monitoring for pbx-issued certs (netbird/relay/mail.artmann.tech) — ROADMAP idea, now more relevant with CAA in the chain                                   | Medium | S      | domains ROADMAP                                                                                                                               |
| 13 | Annotate brainstorm §5 table when the Dex→Pocket-ID decision lands                                                                                                     | Low    | S      | folded into security.md row                                                                                                                   |
| 14 | iodef mailbox sanity check (`security@artmann.tech` receives)                                                                                                          | Low    | S      | parked here only (not queued — value too low)                                                                                                 |
| 15 | Consider `issuewild ";"` explicit wildcard-forbid on zones that should NEVER get wildcards (currently implied by the issue set)                                        | Low    | S      | parked (deliberately: LE wildcard via DNS-01 is a documented future upgrade path for larsartmann.cloud — don't forbid what the plan may want) |
| 16 | Fold "verify expected outcomes from generator conditionals" into the report-writing checklist for future sessions                                                      | Low    | S      | this §e.3                                                                                                                                     |

Harvest accounting (per the self-harvest rule): items 2+3 are NEW → landed as rows in the
domains repo TODO with this report as Source; 4/5/8/9/11 landed during the session (both
surfaces where applicable); 10 lands with this report (AGENTS.md); 1/6/7/12/13 pre-exist or
are owner-gated pointers; 14/15/16 are deliberately NOT queued (recorded here because their
value is below the queue bar or they are process notes).

## g) Questions I cannot answer myself

1. **Standing apply policy for the domains repo:** this session used the from-home scoped
   apply (your documented proven recipe, IP was allowlisted). The designed path is CI
   (push → runner). Which is the standing rule for agent sessions — local scoped applies
   when the IP is allowlisted, or repo changes only, applies always through CI? (I could not
   find a policy line either way in the domains AGENTS.md.)
2. **Which of the 8 bare-CAA zones are still alive publicly?** The per-zone CAA decision
   (lockdown vs LE/pki.goog sets) hinges on live-vs-zombie — and your ROADMAP itself lists
   "live sites vs zombies" as an open question (artmann-technologies.com firebase?,
   skylines.one fate, the four FWD domains). I can dig what RESOLVES, but not what you still
   WANT alive.
3. **Resend link tracking for `larsartmann.cloud`** — enable or keep OFF? (ROADMAP #10, open
   since before this session; ON would add the `links` CNAME + `issue "amazon.com"` CAA in
   one change, matching artmann.tech; OFF keeps the strict LE-only set that just went live.)

---

_Report format: `.md` at operator's explicit demand (skill default is HTML — override flagged,
not propagated). Auto-commit daemon owns the commit._
