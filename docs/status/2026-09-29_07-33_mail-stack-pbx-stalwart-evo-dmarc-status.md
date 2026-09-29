# 2026-09-29 07:33 — Mail stack: Stalwart on pbx-artmann + evo-x2 DMARC wiring

**Session scope:** the user asked "can we enable what needs to be on the public
internet on ~/projects/pbx-artmann, and services.dmarc-monitor + everything
else that makes sense on evo-x2?" — i.e. wire the long-dormant `nix-email`
plumbing into two live hosts. One agent session on evo-x2; the SystemNix tree
was shared with at least one parallel session (foreign daemon commits observed
and left untouched).

**Headline:** the entire nix-email chain is now BUILT and GATE-VERIFIED on both
sides — but **nothing is switched on at runtime anywhere**, deliberately. The
public-internet piece (Stalwart on the Hetzner VPS) is fully configured yet
blocked on external gates the assistant cannot move (Hetzner :25/:465 unblock,
DNS records, runtime secrets, mailbox provisioning), and evo-x2's
`dmarc-monitor` is fully wired with `enable = false` because flipping it
before the mailbox exists wedges every subsequent deploy.

---

## Research that shaped the design (all verified this session, no recycling)

1. **Upstream module surface** (`github:LarsArtmann/nix-email` at lock
   `3b889c71`): `services.mail-server` owns ONE RFC listener set (25/587/465/993
   + loopback-only HTTP admin, plain-priority firewall definition), relay /
   certificate (self-signed|acme|manual) / DNSBL / rate-limit / negative-cache
   options, and eval-time assertions encoding v0.15.5 behavior (bare-IP relay
   refusal, loopback SSRF guard, SASL all-or-nothing). `services.dmarc-monitor`
   wraps nixpkgs parsedmarc with two upstream-bug workarounds (py3.14
   imapclient pin, elasticsearch-section strip) and a Stalwart LOGIN-by-principal-
   NAME gotcha.
2. **Hetzner blocks ports 25 AND 465 by default on ALL cloud servers, both
   directions, per account** (upstream README go-live runbook, verified against
   Hetzner docs 2026-09-14). Only a Console limit request (granted ~1 month +
   first invoice) lifts it. :587 is never blocked. ⇒ Outbound MUST ride the
   Resend smarthost on :587; inbound MX must NOT be published until unblocked.
3. **nginx owns :80/:443 on pbx** (telephony web vhost, nixpkgs ACME). Stalwart's
   built-in ACME client cannot bind the challenge port ⇒ certificate issued via
   the SAME nixpkgs nginx-ACME path (`enableACME` vhost, :80 challenge only, no
   TLS on that vhost) and fed to Stalwart in `certificate = manual` mode through
   LoadCredential + the `%{file:...}%` macro; cert renewal reaches stalwart via
   `security.acme.certs.postRun = "systemctl try-restart stalwart.service"`.
4. **pbx nixpkgs drift vs SystemNix nixpkgs**: this repo's acme module names the
   renewal hook `postRun`, NOT `postRunHook` (SystemNix-era name) — first eval
   caught it ("Did you mean … postRun"). Live proof the compat gate is the
   consuming flake's own eval.
5. **Stalwart local domains / accounts / DKIM keys are STORE data** provisioned
   via webadmin/API (`POST /api/principal {"type":"domain",…}` in the upstream
   relay E2E) — config.toml cannot declare them. The fresh-host 1h
   negative-cache trap is why `directoryCacheTtlNegative = 60` is set for
   bring-up.
6. **parsedmarc cannot succeed until the mailbox exists**: no IMAP login ⇒
   failing unit ⇒ (AGENTS doctrine) a permanently-failing unit inside an
   activation exit-4s the deploy and skips the profile bump. This is the whole
   reason `enable = false` ships instead of a hopeful `true`.
7. **`telephony-alert@` name collision** (existing TODO row): the sibling module
   defines the same template gated on `alerts.url` (unset here → dormant). My
   stalwart `onFailure = [ "telephony-alert@stalwart.service" ]` joins the
   repo-side template as a second consumer — harmless today, same future
   conflict; the TODO row now records stalwart as a consumer.

## a) FULLY DONE

SystemNix (evo-x2):

- `services.dmarc-monitor` fully wired in `platforms/nixos/system/
  configuration.nix`: `enable = false` (loud comment: flip as the FINAL
  go-live step and why) + `settings.imap` (host `mail.artmann.tech`, port 993,
  ssl, user `dmarc@artmann.tech`).
- Wrapper module comment (`modules/nixos/services/nix-email.nix`) rewritten:
  deployment state is no longer "enabled NOWHERE"; records the flip procedure
  and that mail-server consumption moved to pbx-artmann directly.
- AGENTS.md gained a compact `### nix-email` section (contract doctrine, the
  enable=false rationale, the Stalwart store-data fact).
- Owner-gated follow-up harvested into `docs/todo/services.md`
  (blocked:user dmarc flip + secret paste, with the Source pointer).

pbx-artmann (the public-internet host):

- flake input `nix-email` (`?ref=master`, `nixpkgs.follows`) added and
  `nix-email.nixosModules.default` imported into BOTH arch toplevels.
- **`hosts/pbx/mail.nix`** (new, 115 lines): `services.mail-server` enabled
  (`mail.artmann.tech`), Resend smarthost relay (:587, username `resend`,
  password via runtime file), certificate manual-mode fed from the nginx-ACME
  cert, `directoryCacheTtlNegative = 60`, declarative break-glass admin
  (`admin` + LoadCredential macro), cert-wait ExecStartPre (5 min loop),
  generous start limit at the TOP LEVEL (serviceConfig StartLimit* is silently
  ignored — SystemNix doctrine), `onFailure` → `telephony-alert@stalwart`.
- `hosts/pbx/default.nix` imports mail.nix.
- `hosts/pbx/backup.nix`: nightly staging now archives the Stalwart store
  (stop → tar → start with `--no-block`; RocksDB has no hot-consistent copy
  and ext4 has no snapshot fallback). Extracted script `bash -n`-verified
  (raw nix script strings are not linted — architecture-catalog lesson).
- `cloud-init/generate.sh`: `stalwart_fallback_admin` +
  `stalwart_relay_password` added to the secret list (both flows covered;
  real mode FATALs on missing/empty — verified by reading the loop).
- `docs/runbooks/mail-go-live.md` (new): the ordered 8-step go-live runbook —
  Hetzner unblock → secrets → A-record + cert verify → MX/DMARC (post-unblock
  only) → SSH-tunnel provisioning (principal NAME = address) → outbound smoke
  (`From lars@larsartmann.cloud` — artmann.tech is not Resend-verified) →
  SystemNix flip → post-cutover hardening.
- AGENTS.md: mail.nix + backup.nix + runbooks rows updated.
- TODO_LIST.md: new §9 (9 rows, owner-gated go-live ladder + 2 assistant
  follow-ups); the telephony-alert collision row extended with stalwart.

Verification (all green):

- SystemNix: `nix eval` of the toplevel drvPath + the rendered
  `services.dmarc-monitor.settings.imap.host`; **`nix flake check
  --no-build` → all checks passed** (includes `checks.nix-email-contract`
  against the real pinned upstream module — re-verified live at session
  start).
- pbx-artmann: both arch toplevels eval; rendered unit spot-checks —
  `LoadCredential` = exactly the 4 expected credentials (fallback-admin, cert,
  cert-key, relay), `ExecStartPre` order = wait-cert BEFORE the module's
  mkdir, firewall ports = `[22 25 80 443 465 587 993 3478 5060 5061 5080]`
  (mail ports additive to telephony's), smtp listener `[::]:25`, acme
  `postRun` hook present; dry-run shows only 38 derivations to build
  (stalwart itself binary-cached); **`nix flake check` → all checks passed**
  (this BUILDS the x86 toplevel closure + installer bundle + format-safety +
  all docs gates).
- The aarch64 toplevel eval-gates green (a real CAX build stays the existing
  TODO row).

## b) PARTIALLY DONE

- **pbx `nix flake check` was RED twice en route, both fixed in-session**:
  (1) `postRunHook` vs `postRun` (nixpkgs-drift, see research #4); (2) after
  my TODO_LIST §9 append, the docs-freshness audit went 1 → 3 unharvested:
  my rows pushed common tokens over the matcher's GENERIC_DF=8 rarity
  threshold, un-harvesting two historical items that had only ever matched
  accidentally. Baseline worktree proof: the gate was ALREADY red at the
  pre-session commit (1 unharvested = DRIFT), so this was pre-existing drift
  my edit exposed, not caused. Fixed the honest way (docs-health ANNOTATE):
  struck the three stale items in their reports with evidence-carrying
  verdicts — each claim first verified against TODO_LIST (deploy LIVE per §1,
  aarch64 row at §6:109, release-freshness rows at §6). `docs-annotate`
  CLEAN + `--audit-all` FRESH afterwards.
- **Secrets are wired but placeholder/absent by design**: the runtime files
  don't exist in `~/.pbx-prod-secrets` yet (owner), the SystemNix sops
  `nix-email.yaml` values are placeholders (owner pastes at flip time).
- **Monitoring for the mail endpoints is not wired** (external Gatus
  smtp-mx/imaps checks) — deliberately deferred to post-cutover: they are
  red-until-live by design and would page from the moment they're added.

## c) NOT STARTED (deliberately out of scope, tracked)

- Everything behind the external gates: Hetzner limit request, real secrets,
  DNS records (A now; MX/DMARC post-unblock), Stalwart provisioning (domains,
  dmarc mailbox, DKIM keys), outbound/inbound smoke, the evo-x2 enable flip,
  post-cutover Gatus checks, the stalwart restore-drill arm in
  backup-restore.md. All live as ordered rows in pbx TODO §9 + the runbook.
- evo-x2 runtime deploy: the SystemNix toplevel changed (drvPath moved) but
  nothing runtime-active did (everything rides `mkIf …enable`); deploy is
  safe anytime, urgent never.

## d) TOTALLY FUCKED UP

- Nothing. Two eval/gate failures (postRun name, docs-freshness drift) were
  caught by the gates and fixed in-session; no deploy was attempted; no
  runtime state anywhere was touched; no secret material was handled or
  printed (runbook uses `<RESEND-API-KEY>` placeholder form per the
  Critical Rules).
- Flagged, not mine: the daemon batched a foreign
  `.github/workflows/flake-update.yml` (parallel session) into a commit that
  also carries my SystemNix AGENTS.md section; and `docs/todo/pipeline.md`
  sits dirty from another session — both left untouched.

## e) WHAT WE SHOULD IMPROVE

1. **The nix-email pin-discipline tension is now TWO consumers wide**: upstream
   README demands hard rev/tag pins (nixpkgs-version-sensitive contract);
   both SystemNix (2026-09-16 directive) and now pbx-artmann ride
   `?ref=master` with eval as the only gate. pbx has NO contract test — its
   "gate" is the toplevel eval, which caught the postRun drift but would NOT
   catch a semantic stalwart-module drift that still evals. A tiny
   eval-contract test (SystemNix's `test-nix-email.nix` shape) in pbx would
   close that at ~zero cost.
2. **Cert bootstrap UX**: the stalwart cert-wait loop is journal-visible but
   nothing ALERTS on "cert still missing after N hours" — pre-go-live noise
   is fine, but post-DNS a silently-failing ACME (typo'd record) would sit
   unnoticed until a human looks. A telephony-alert@acme OnFailure on the
   acme unit (or a stalwart journal-age metric) would close it.
3. **`telephony-alert@` collision is now 2 consumers deep** and the sibling's
   alerts activation would hard-conflict the eval. The resolution (module
   option or rename) is already TODO'd; every new consumer raises the cost.
4. **The docs-freshness GENERIC_DF matcher is fragile against TODO growth** —
   today's 1→3 flap shows harvest status depends on how often common words
   appear elsewhere in the living docs. Not fixable by me today, but the
   matcher (or its threshold) deserves a look upstream in the gates family
   (TODO §8's "extract docs-gates into shared fleet tooling" row is the
   right vehicle).
5. **Resend relay scope is unverified for artmann.tech**: the runbook tells
   the owner to verify or scope keys, but the OUTBOUND smoke cannot pass for
   `@artmann.tech` envelopes until then. If personal mail will primarily be
   `@larsartmann.cloud`, nothing to do; otherwise add artmann.tech to Resend
   at go-live.

## f) Up to 50 things we should get done next

Grouped; ✅ = already harvested this session (location noted).

**Go-live critical path (owner; harvested ✅ pbx TODO §9 / runbook):**
1. ✅ File Hetzner :25/:465 limit request (runbook §1).
2. ✅ Create + push `stalwart_fallback_admin`, `stalwart_relay_password`
   (runbook §2).
3. ✅ DNS `A mail.artmann.tech` → VPS IP; deploy pbx; verify cert+stalwart
   active (runbook §3).
4. ✅ Provision Stalwart: domains, `dmarc@artmann.tech` (principal NAME =
   address), personal mailbox (runbook §5).
5. ✅ Outbound smoke via Resend, `From lars@larsartmann.cloud` (runbook §6).
6. ✅ Post-unblock: MX + `rua=mailto:dmarc@artmann.tech` on both `_dmarc`
   records (runbook §4).
7. ✅ SystemNix flip: sops-paste `dmarc-imap-password`, `enable = true`,
   deploy, verify parsedmarc + backup freshness (runbook §7; harvested ✅
   docs/todo/services.md).

**Assistant follow-ups (harvested ✅ pbx TODO §9):**
8. ✅ Post-cutover Gatus external checks smtp-mx/imaps with
   CERTIFICATE_EXPIRATION > 720h (runbook §8).
9. ✅ Stalwart-store restore drill + backup-restore.md stalwart arm.

**Design debt (harvested ✅ pbx TODO §9 at authoring time):**
10. ✅ pbx eval-contract test for nix-email (e.1) — SystemNix
    `tests/test-nix-email.nix` shape, ~30 lines.
11. ✅ Cert-bootstrap alerting (e.2) — OnFailure on
    `acme-mail.artmann.tech.service` or a stalwart journal-age metric.
12. ✅ Resolve `telephony-alert@` collision for real (pre-existing TODO row,
    extended this session with the stalwart consumer note).
13. ✅ Verify/scope the Resend key for artmann.tech envelopes (e.5) — owner
    decision row added (blocked:user).
14. After direct-to-MX someday: rDNS pin + `relay = null` flip + SPF
    `v=spf1 mx -all` + Stalwart DKIM keys + DNS TXT (upstream runbook §3
    shape).
15. MTA-STS + TLS-RPT records (runbook §4 optional hardening).
16. Mail-server Gatus checks belong in a registry entry once any SystemNix
    host consumes it — the wrapper's dmarc entry has `checks = []` today.

**Same-session adjacent items noticed but not touched (pre-existing):**
17. SystemNix `docs/todo/pipeline.md` sits dirty from a parallel session —
    coordinate before the next deploy batches it.
18. The foreign `.github/workflows/flake-update.yml` that rode my AGENTS.md
    commit — verify the parallel session intended it (auto flake-update on
    a repo with 46+ follows is behavior-relevant).
19. pbx AGENTS.md is ~2.2x over its own 377-line budget (existing TODO row;
    my rows added ~5 lines — net worth a slimming pass soon).
20. The docs-freshness GENERIC_DF fragility (e.4) — upstream in the
    gates-family extraction row.

**Deliberately NOT harvested (with reasons):**
21. "Deploy SystemNix to land the dmarc wiring" — nothing runtime-active
    changes until the flip; batching decision is the owner's (parallel
    sessions active).
22. "Add dmarc-monitor to SigNoz coverage" — no OTel env on parsedmarc;
    per doctrine nothing to register.
23. "VM test for pbx mail.nix" — upstream owns runtime E2E (stalwart-e2e,
    relay-e2e); the consumer wiring is eval-gated; a SystemNix-style VM test
    would duplicate upstream's suite. Revisit only if a second Stalwart host
    appears.
24. Anything outward-facing (Resend domain verification for artmann.tech,
    mailbox creation) — user-held values and portals, per repo doctrine.

## g) Questions for the owner (cannot figure out myself)

1. **Which identity domain is THE mailbox domain?** I configured the server
   to serve both `artmann.tech` and `larsartmann.cloud` and pointed DMARC
   rua + the parsedmarc login at `dmarc@artmann.tech`. If you'd rather the
   rua mailbox (and/or your personal mailbox) live on `larsartmann.cloud`,
   say so before step 5 — it's a 2-line change in the runbook +
   configuration.nix, but wrong-after-provisioning means principal renames.
2. **Outbound posture after the Hetzner unblock**: stay on the Resend relay
   (zero reputation risk, but Resend daily limits + artmann.tech needs
   verifying there), or flip to direct-to-MX (needs rDNS pin + warmup + DKIM
   DNS)? I wired relay; the flip is documented but is an owner decision.
3. **Should the published installer release be refreshed before or after the
   mail deploy?** TODO §6 shows the published `pbx-kexec-installer` is STALE
   vs the tree; a recreate before republish boots pre-mail code. If a
   recreate is plausible before go-live completes, republish first (user-run
   `./installer/publish-release.sh`).
