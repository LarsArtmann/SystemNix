# §22 dnsblockd CA-parity WARN — re-dispatch verification + steady-state encoding (2026-11-06 22:15)

**Trigger:** live §22 output — `WARN dnsblockd CA parity - trusted and identical, but the bundle appends the same CA 2x (benign for trust; two mechanisms write one PEM — find the second writer)`.

**Verdict: the 2026-10-30 resolution STANDS, re-verified live; the WARN is the designed tripwire and stays. The stale "find the second writer" message text was replaced with the known steady state, and the resolution's last un-landed follow-up (nix-flakes.md pointer) landed.**

## a) Re-dispatch verification protocol (docs/CONTRIBUTING.md, five steps)

1. **Footers + queue-surface closure** — the landed work's commit chain exists (`docs/status/tasks/2026-10-30_05-05_task-…md` §a.3); BOTH surfaces for the original second-writer row are `[x]` with matching RESOLVED text (TODO_LIST:263 + docs/todo/services.md:353). No drift.
2. **One load-bearing claim re-verified live** (this session, independent of the prior report):
   - `grep -c 'MIIFSzCCAzOgAwIBAgIUDqspDh2XW' /etc/ssl/certs/ca-certificates.crt` → **2**
   - bundle resolves to ONE store file: `…-nss-cacert-3.131.1/etc/ssl/certs/ca-bundle.crt`
   - p11-kit name line `cn=dnsblockd-CA:eea9e1be` present (bundle line 7890)
   - crl2pkcs7 enumeration → exactly 2 dnsblockd-CA copies, **both** `sha256 Fingerprint=EE:A9:E1:BE:…:49:88`, identical to the sops CA
   - `nix eval '.#nixosConfigurations.evo-x2.config.security.pki.certificates' --apply builtins.length` → **1** (no doubled option entry)
3. **Source-report §f sweep** — `docs/status/tasks/2026-10-30_05-05_…md` §f.1–7: §f.1 upstream filing (queued, TODO_LIST:1836 + upstream.md), §f.2 nix-flakes pointer (**landed THIS session**, row ticked), §f.3 pre-queued (TODO_LIST:197), §f.4 deploy-gated rows exist, §f.5 rpi3 dup probe (queued, TODO_LIST:1860 + services.md:738), §f.6 phrasing sweep (queued, TODO_LIST:1861 + services.md:739), §f.7 eval-time comment (queued, TODO_LIST:1862 + services.md:740). **Adversarial cross-check: CLEAN — every §f item of the prior fire is landed or queued on both surfaces.**
4. **Footer-bearing landing** — this session's commit amends the daemon sweep of its own work (see CHANGELOG 2026-11-06 entry); not a tq dispatch, no Task-Queue-ID footer owed.
5. **Stale BLOCKED reasons** — none touched by this scope.

## b) What landed (this session)

1. **`scripts/lib/ca-parity-smoke.sh`** — the duplicate branch split: `==2` copies → WARN naming the DOCUMENTED nixpkgs steady state (buildcatrust plain + p11-kit TRUSTED pair, pointer to the runbook duplicate-counter block); `>2` copies → WARN "a REAL second writer exists; hunt it". WARN verdict kept in both branches (tripwire per runbook doctrine: it fires if a future nixpkgs change ever makes the copies diverge). Header verdict table updated.
2. **`scripts/test-ca-parity-smoke.sh`** — leg 7 re-labeled (2x = documented steady state) + **new leg 9** (3 copies → WARN) pinning the >2 branch. 8→9 legs.
3. **`docs/services/dnsblockd.md`** — §22 verdict description + fixture-leg count synced to the new semantics (9 legs).
4. **`docs/agents/nix-flakes.md`** — "Packaging, store & CI cache notes" carries the ca-bundle mechanism paragraph (`security.pki.certificates` = `pkgs.cacert.override { extraCertificateStrings }`, duplicates invisible to subject-name greps, base64 counter + DER fingerprint audit method). Closes TODO_LIST:1837 (ticked RESOLVED 2026-11-06; queue-only row, no library twin).

## c) Verification runs

- `bash scripts/test-ca-parity-smoke.sh` → **PASS: all 9 legs**
- `nix build .#checks.x86_64-linux.dnsblockd-ca-parity-selftest --no-link` → realized green in-sandbox (runs the SAME prod lib against REAL openssl certs)
- Live driver of the modified lib against `/etc/ssl/certs/ca-certificates.crt` + `/run/secrets/dnsblockd_ca_cert` → renders the new steady-state WARN verbatim
- `shellcheck --severity=warning` on both edited scripts → clean (SC2329 info-level on the pre-existing indirection fixtures is below the repo gate's severity)

## f) Follow-ups at authoring time

- None new. Deliberate non-harvests: the §22 telemetry decision row (TODO_LIST:1866, `[decision]`, owner-gated) is unchanged and the 2-copy steady state it describes is now what the WARN itself names; the upstream buildcatrust filing row (TODO_LIST:1836) is a separate dispatch requiring verify-before-filing + github-voice and was not started here.

**Harvest log (2026-11-07, T03 wave — items HARVESTED):** already-tracked §f-1 · §f-2 carried as the 22-39 §f.7 proposal (old row not found post-prune); section states None new — WARN steady-state work landed (CHANGELOG.md:388)
