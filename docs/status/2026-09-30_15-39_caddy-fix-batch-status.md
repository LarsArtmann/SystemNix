# Caddy Fix-Batch Status Report (2026-09-30 15:39 CEST)

**Session scope:** execute the full fix batch from the 2026-09-30 caddy config
review (`docs/status/2026-09-30_11-33_caddy-config-review-status.md` — 14
findings, 12 harvested rows) after the user's "go fix everything about Caddy
properly" mandate. Read → research → reflect → execute → verify, one step at a
time. **All 14 findings closed, every gate green, nothing deployed yet.**

---

## §0 Self-critique — what I forgot, what I'd do better

1. **The queued §g Q1 live-probe step was never completed.** The QUIC row said
   "step 1 regardless: read-only nft/iptables probe to confirm the drop live".
   `sudo` is blocked in this sandbox; I let the probe die instead of finding a
   sudo-free equivalent. The drop is proven by config-reading only (firewall
   UDP allowlist lacks 443; `trustedInterfaces = [eno1]` means LAN was never
   affected — only VPN/external paths), plus the live `UNCONN 192.168.1.150:443`
   QUIC listener (h3 IS served). Honest label: statically confirmed, not
   nft-confirmed.
2. **A sudo-free live cert probe existed and I missed it.** The direct
   `openssl x509 -in /run/dnsblockd-certs/server.crt` probe failed (0750 dir)
   and I skipped it — but `openssl s_client -connect <vhost>:443` needs no file
   access and would have shown the live SANs/chain. The VM test covers SANs
   declaratively, so nothing was lost, but "probe failed → skip" is the wrong
   reflex; the sops-secret-management skill's "root has no age identity" lesson
   rhymes: find the unprivileged path before abandoning.
3. **The smoke's FALLBACK branch is untested.** I dry-run-verified the derived
   branch (real file content through the real parse loop: 21 protected / 14
   plain, correct P2 target) and linted the script, but the
   file-missing fallback (hand list + `|-` ports) has only `bash -n` +
   shellcheck. A typo there surfaces at the NEXT deploy as a smoke break.
   Queued as a pre-deploy test.
4. **`checks.caddy-mint` does NOT exercise QUIC.** The VM proof does real TLS
   handshakes — over TCP. The dropped `CAP_NET_ADMIN` + NNP=true posture is
   proven for TCP binds, but the UDP/443 QUIC listener under the new cap set is
   unverified until a live post-deploy probe. Low risk (UDP <1024 binds need
   only NET_BIND_SERVICE) but it is a live-pending leg, and I should have
   flagged it at fix time, not harvest time.
5. **I ran a nonexistent harness case.** The harvested row said "re-run the
   negative-test-lints caddy-mutant case"; I ran the harness twice (several
   minutes each) before grepping for the case name — it does not exist. A
   5-second grep would have saved the first run and surfaced a stale reference
   in the queue row itself (now harvested as its own row).
6. **Two fumbled negative-probe attempts.** My first extendModules probes used
   `builtins.length config.systemd.units` (a set, not a list) and didn't force
   the toplevel (NixOS assertions only throw at `system.build.toplevel` —
   house-documented in Critical Rules). Cost two wasted eval rounds before the
   correct probes fired. Read the forcing contract first, write the probe once.
7. **Two scope errors in the caddy.nix let-bindings** (referencing
   `homeLanVHosts` from the module-level let where it doesn't exist, then the
   cycle risk of warn-wrapping the option value). Landed clean on the third
   shape, but the first binding draft should have been written against the
   option value with the warn attached to a leaf surface from the start.
8. **Owner-gated calls made autonomously.** The report's three §g questions
   were never answered; under "fix everything properly" I took the recommended
   branch of each (open UDP/443; add Requires; document 10GB rather than
   change it). Each is reversible and flagged in §g of this report for
   ratification — but they were mine to make only because the mandate was
   broad, and the report that asked the questions was mine too.
9. **What went right (kept honest):** negative tests for both new assertions
   (extendModules, correct messages fired); live probes before editing
   (rendered Caddyfile, log dir, listeners); git archaeology BEFORE touching
   the caps (the da147df6 lore was refuted, not guessed); the daemon-swept
   batches verified with `git show --stat` per the multi-agent doctrine.

---

## §a FULLY DONE (verified)

| # | Item | Evidence |
| - | ---- | -------- |
| a1 | **S1 — HTTP/3 QUIC blackhole fixed**: UDP/443 opened in the firewall | eval: `allowedUDPPorts == [53 443 853]`; live `UNCONN .150:443` listener pre-existing |
| a2 | **S2 — fail-closed claim now literal**: `requires = dnsblockd-cert-mint.service` | eval: requires list; comment + AGENTS.md aligned + code-anchored |
| a3 | **S3 — `NoNewPrivileges = mkForce false` REMOVED** (stale lore, `da147df6`) | eval: `NoNewPrivileges == true`; rationale comment cites the refuted commit |
| a4 | **S4 — `CAP_NET_ADMIN` dropped from bounding + ambient sets** | eval: both == `CAP_NET_BIND_SERVICE`; **`checks.caddy-mint` VM test GREEN (rc=0)** — real mint + TLS handshakes both zones |
| a5 | **S5 — `default_bind` documented**: syntax-fix origin (`f43a28a3`), dnsblockd block-page collision (live-verified: .200:80/443 = dnsblockd, .150 = caddy), NetBird routing model | module comment; live `ss` evidence in report |
| a6 | **S6 — registry `port`+`root` XOR-tightened** + vestigial `protectedVHost _subdomain` param dropped (5 call sites) + `monitor365.enable or false` guard | negative probe: both-set entry fails eval with "EXACTLY ONE of port / vHost.root: probe" |
| a7 | **S7 — double-logging verified ABSENT** (global access.log = default/runtime logger; per-vhost files are the access path; Caddy defaults 100MiB×10/file) | rendered Caddyfile (global block + per-site `output file`), live log dir listing, 96MB runtime file vs per-vhost files |
| a8 | **S8 — mint SAN self-assert**: four SANs asserted on the signed leaf BEFORE install; missing SAN fails the MINT into OnFailure | script edit; VM test ran the mint green (assert passed on the happy path) |
| a9 | **S9 — hand-written vHost DNS assertion + ghost sweep** | negative probe: `typo.home.lan` fails eval with "missing from platforms/common/dns-local.nix"; ghost warning live-observed for `alerts`, then allowlisted (deliberate legacy alias) |
| a10 | **S10 — `docs/services/caddy.md` runbook** (161 lines: vHost map, layer doctrine, cert flow, ops, logs, cloud mirroring, HSTS-preload note, verdict table) | file in tree, swept in `413938a7` |
| a11 | **P1 — smoke auth probes DERIVED from `/etc/caddy/vhost-layers`** (eval-emitted `layer sub port` from the rendered set; hand list demoted to fallback) | 3-column file eval-verified; parse dry-run: 21 protected / 14 plain, zero bad fields; non-listening backend → SKIP (no false-FAIL for deploy-pending nsfw) |
| a12 | **P2 — plain-vHost TLS probe** added (first derived plain vHost = auth/pocket-id; any answered status passes, 5xx with listening backend fails) | smoke edit; shellcheck clean |
| a13 | **Todo hygiene**: all 12 harvested rows closed — 24 lines pruned from TODO_LIST/services/pipeline libraries; CHANGELOG entry landed | surgical diff (exactly the 24 rows); `check-todo-system.sh` OK |
| a14 | **Global gates**: `nix flake check --no-build` green (twice); `nix fmt --ci` 0 changed; both new guards negative-tested | command outputs in §provenance |

## §b PARTIALLY DONE (code-verified, live legs pending the deploy)

| # | Item | Done | Pending |
| - | ---- | ---- | ------- |
| b1 | QUIC posture | firewall + config shipped | live nft confirmation + an h3 request from a VPN client (VM test is TCP-only) |
| b2 | Derived smoke mode | file emit + parse logic dry-run green | `/etc/caddy/vhost-layers` on the LIVE system + one real derived-mode smoke run |
| b3 | Mint SAN self-assert | script + VM-test happy path | live boot journal line (fires every boot after deploy) |
| b4 | Caps/NNP tightening | VM proof (TCP) | first real caddy restart on evo-x2 — watch the first post-deploy boot |
| b5 | Owner ratification of the three autonomous calls (UDP/443 open; Requires added; 10GB documented-not-changed) | implemented on the recommended branch | §g answers below |

## §c NOT STARTED

Nothing from the caddy batch scope — all 12 harvested rows were executed or
explicitly dispositioned. The §f list below is the not-started backlog going
forward.

## §d TOTALLY FUCKED UP

**Nothing from this session.** No gate regressed; the tree evals clean on both
hosts; the VM test passes. Nearest candidates, honestly labeled:

- **Pre-existing lint debt surfaced, not caused** (surfaced while re-running
  `negative-test-lints.sh` per the queue row): `dead-guard-lint` finds
  `cv.nix:555` (`leftover=$(...)`) + `hermes.nix:161` (`stray=$(...)`) missing
  `|| true` under errexit, and `signoz-query-lint` + `binary-coverage-lint`
  fail their PRISTINE-tree controls (the harness cannot validate them at all —
  18 passed / 5 failed). None of these files were touched by this session.
- **Daemon batch mixing (process risk, not breakage):** the auto-commit daemon
  swept this session's files into heuristic commits mixed with a PARALLEL
  session's work (`413938a7` = 11 files: my caddy batch + foreign status
  reports; `432e193e` = my caddy.nix edits + foreign geometrikks.nix/.md +
  docs/todo/storage.md). Contents verified with `git show --stat`; foreign
  files untouched and flagged. The geometrikks.nix edits (11 lines) are
  unreviewed foreign work riding commits that also carry my module.
- **The queue row that sent me to a nonexistent harness case** — a stale
  reference cost one wasted harness run (queued for correction).

## §e WHAT WE SHOULD IMPROVE

1. **Probe-first discipline for queued asks**: execute the "step 1 regardless"
   live-probe clauses or explicitly record the blocker (sudo-blocked) in the
   close-out — not discoverable by diff.
2. **Unprivileged-path reflex**: when a probe needs root, look for the
   non-root equivalent (s_client vs cert file) before shelving.
3. **Verify harness case names before running** (grep the case list, then
   run).
4. **Test every new branch shape** — the smoke got bash -n + shellcheck +
   derived-branch dry-run but the fallback branch got neither; "syntax-checked"
   is not "tested" for shell.
5. **Write let-bindings against the option value with warns on leaf surfaces**
   — the third shape was the first correct one; the first two paid scope/cycle
   tax.
6. **Negative probes: force `system.build.toplevel`** — house rule, should be
   muscle memory.
7. **Per-file log-churn spotting**: 1.7G of caddy access logs on the QLC root
   (snapshot-pinned, CoW-churning) sat unnoticed until this session's S7 dig —
   service log LOCATIONS deserve the same storage-doctrine sweep the session
   DBs got (harvested below).

## §f Up to 50 things to get done next

Sorted by impact; `H` = harvested this report (direct follow-up), `D` =
dispositioned brainstorm/ROADMAP fuel (not harvested — see Harvest Log).

| # | Item | Impact | Effort | Cat |
| - | ---- | ------ | ------ | --- |
| 1 | **H [blocked:deploy] Deploy the caddy batch + post-deploy verify**: caddy restarts under NNP=true/NET_BIND_SERVICE-only; live QUIC probe (UDP/443 + h3 request via VPN); `/etc/caddy/vhost-layers` live + derived smoke run; mint journal SAN-assert line | HIGH | 30m | services |
| 2 | **H [ready] Test the smoke's fallback auth branch** (simulate missing vhost-layers file) before the next deploy rides it | MED | 15m | pipeline |
| 3 | **H [ready] geometrikks × global access.log**: verify the tailer/parser handles DEFAULT-logger runtime-JSON lines (they are not access records — the geometrikks comment claims "unmatched traffic", which S7 falsified) | MED | 30m | services |
| 4 | **H [decision] Caddy file logs on QLC root**: `/var/log/caddy` 1.7G (growing) under `@` → snapshot-pinned 2w + CoW churn; move to `/mnt/hot` (journal-hot precedent) or bound retention | MED-HIGH | 1-2h | services |
| 5 | **H [decision] Per-vHost log roll bounds**: explicit rolls on registry vHosts vs Caddy defaults (100MiB×10/file, aggregate unbounded) | MED | 30m | services |
| 6 | **H [ready] Fix the pre-existing negative-test-lint failures** (cv.nix:555 + hermes.nix:161 `|| true`; signoz-query-lint/binary-coverage pristine controls) — restores the harness to fully green | MED | 1h | pipeline |
| 7 | **H [ready] Add (or de-reference) the `caddy-mutant` negative-test case** — the queued ask named a case that doesn't exist | LOW | 30m | pipeline |
| 8 | **H [ready] Refresh AGENTS.md SSO-layer table** vs the registry (Layer 1/2 fleet drifted: rss/geo/cv/miniflux L1; dash/signoz/searxng/index/tq/health L2) | MED | 45m | pipeline |
| 9 | **H [watch] voice/whisper dns-local exemption**: add both to dns-local + drop the assertion exemption when voice-agents first lands | LOW | 10m | services |
| 10 | **H [watch] Layer classification robustness**: the derived file keys on `forward_auth` substring; a future non-forward-auth gate (basic_auth/IP allowlist) misclassifies plain | LOW | — | services |
| 11 | **H [decision] Explicit `servers { protocols h1 h2 h3 }` pin** — makes the h3 posture declarative and the firewall dependency greppable | LOW | 5m | services |
| 12 | Review the parallel session's unreviewed geometrikks.nix/.md edits riding the mixed daemon commits (`432e193e`) | MED | 20m | services |
| 13 | nsfw/index vHosts render while services are deploy-pending — verify their Gatus checks carry the 502 window cleanly (noticed, pre-existing) | LOW | 15m | services |
| 14 | `alerts` alias: consider an explicit redirect vHost instead of relying on the catch-all + dns-local ghost allowance | LOW | 15m | services |
| 15 | Post-deploy: confirm h3 Alt-Svc reachable end-to-end from a NetBird client (route 192.168.1.0/24 → LAN IP → UDP/443) | MED | 20m | services |
| 16 | Caddy `caddy validate` add to pre-deploy gate §1? (config-syntax leg currently only fires via unit start in VM tests) | LOW | 20m | pipeline |
| 17 | Consider emitting the layers file with cloud-zone entries too, for a future cloud-zone smoke | LOW | 15m | services |
| 18 | Gatus: is there a check that would catch a caddy running with WRONG cert (right CA, stale SANs)? SAN assert covers mint; a live handshake-with-SAN-verify check would close the runtime half | MED | 30m | monitoring |
| 19 | D
ocument the `oauth2-proxy` restart ordering contract (caddy-first doctrine) in the runbook — currently only in module comments | LOW | 10m | services |
| 20 | Access-log JSON schema: consider a shared field contract doc (geometrikks + future log consumers) | LOW | 30m | services |
| 21 | ROADMAP: caddy OTel access-log → trace correlation (spans exist for dnsblockd class; caddy itself emits only metrics today) | LOW | — | upstream/ROADMAP |
| 22 | ROADMAP: per-vHost rate limiting for external (VPN) paths | LOW | — | ROADMAP |
| 23 | ROADMAP: caddy HA/failover story (currently single proxy = fleet-wide SPOF; rpi3 runs dnsblockd only) | MED | — | ROADMAP |
| 24 | Sweep `docs/todo/services.md` for other hand-maintained lists that duplicate registry data (the AUTH_VHOSTS class) | MED | 45m | pipeline |
| 25 | Consider `caddy reload` recovery: if PrivateTmp ever gets relaxed upstream, retire the deploy.sh restart hack (watch nixpkgs) | LOW | — | upstream/watch |

(25 rows: 11 harvested H, 14 dispositioned D with reasons in the Harvest Log.
The earlier "up to 50" headroom stays unspent — padding the list with filler
would dilute the ranked signal; rows 21-25 already cross into ROADMAP fuel.)

## §g Three questions I can NOT figure out myself

1. **Ratify the HTTP/3 direction?** I opened UDP/443 (the review's recommended
   branch; DoQ precedent at 853/UDP). The alternative — pin caddy to
   `h1 h2` — removes the Alt-Svc advertisement entirely and keeps the firewall
   closed. Is VPN-client h3 actually WANTED (QUIC through the NetBird tunnel),
   or was the finding better closed the conservative way?
2. **`request_body max_size 10GB` (global, `commonConfig`)** — I documented it
   as deliberate (Immich-upload sizing theory) and changed nothing. Is 10GB
   the intent, and should it stay GLOBAL (every vHost accepts 10GB bodies) or
   move per-vHost (only immich gets 10GB, everyone else 100MB-ish)?
3. **Caddy file logs: stay on QLC root, move to `/mnt/hot`, or bound + keep?**
   1.7G today, growing with vHost count, snapshot-pinned ~2w on `@`, CoW
   churn on the QLC NVMe. Storage calls are owner territory (hot tier is
   unsnapshotted — dump-only RPO doctrine would apply, same as journal-hot).

---

## Harvest Log (self-harvest at authoring time)

**Harvested (11 rows → TODO_LIST.md + domain libraries):**
§f rows 1-11 — one-liners in `TODO_LIST.md` (new `### services / pipeline
(harvest 2026-09-30 15-3x caddy fix batch)` section) + full entries in
`docs/todo/services.md` (rows 1, 3, 4, 5, 9, 10, 11) and
`docs/todo/pipeline.md` (rows 2, 6, 7, 8). Queue one-liners and library
entries must not drift — both edited in this pass.

**Deliberately NOT harvested (dispositioned):**
- §f rows 12-20: actionable but second-order — they ride the deploy window
  (row 15) or are small UX/docs polish; they live in this report's table for
  the next dispatch cycle rather than the queue (a `[x]` covers the row's own
  scope, and queueing 20 more LOW rows buries the HIGH ones).
- §f rows 21-23: ROADMAP fuel (explicitly the skill's guidance for >25-item
  brainstorm lists) — HA/failover and rate-limiting are design decisions, not
  dispatchable tasks.
- §f rows 24-25: watch items with revisit triggers documented inline.

## Provenance

- Report moment: `date` → 2026-09-30 15:39 CEST.
- Session commits (daemon-swept, contents verified via `git show --stat`):
  `0da82794` (caddy.nix + integration.nix + networking.nix + AGENTS/todo),
  `432e193e` (caddy.nix log-comment round + FOREIGN geometrikks edits),
  `2c37fe27` (caddy.nix + post-deploy-check.sh), `568f471e` (AGENTS.md
  Requires anchor), `413938a7` (runbook + CHANGELOG + todo prunes + foreign
  status reports).
- Verification evidence: `nix eval` renders (NoNewPrivileges=true;
  `CAP_NET_BIND_SERVICE` ×2; requires list; `allowedUDPPorts == [53 443 853]`;
  vhost-layers 35 entries / 3 columns), extendModules negative probes (XOR +
  typo-vhost, both messages fired), `checks.caddy-mint` rc=0, `nix flake
  check --no-build` green ×2, `nix fmt -- --ci` 0 changed,
  `scripts/shellcheck.sh` clean, `check-todo-system.sh` OK, parse dry-run 21
  protected / 14 plain / 0 bad fields.
- Live probes (pre-edit): rendered Caddyfile at `/etc/caddy/caddy_config`
  (`default_bind 192.168.1.150`, global log block, per-vhost log blocks);
  `/var/log/caddy` listing (per-vhost files + 96MB global); `ss -tln/-uln`
  (.200:80/443 vs .150:80/443 + `UNCONN .150:443`); `openssl x509` on the mint
  cert FAILED (0750 dir — the s_client alternative was missed, §0.2).
- Pre-existing failures surfaced (not mine): `negative-test-lints.sh` 18/5
  (dead-guard cv.nix:555 + hermes.nix:161; signoz-query-lint +
  binary-coverage-lint pristine controls).
