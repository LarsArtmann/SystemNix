# tq 000001a20b44 — five-item services batch (2026-11-24)

One session, five TODO_LIST "services" items. Auto-commit daemon sweeps
interleaved twice; per-item footer-bearing commits carry the closures, the
daemon hashes carrying raw work are cited per item.

> **Post-rebase note (2026-11-24):** every SystemNix commit hash below is PRE-rebase —
> the session died in the 2026-11-24 z.ai outage and its uncommitted remainder was
> stash-lost by git-town's failed `git stash pop` (daemon index.lock race), then restored
> from the dropped stash commit `9c07aabf81b1`. Rebased equivalents: `77e79df5a` (CV
> unstick), `c0a98445b` (paperless alert); the mechanics daemon commits were replayed
> intact. InboxClean `37f56e44` is unaffected (other repo).

## Per-item outcomes

1. **InboxClean per-account `auth_expired` Gatus check** — mechanics LANDED
   (daemon `8efa52af6`): `services.inboxclean.perAccountAuthAlerts.enable`
   (default false) renders "InboxClean <slug> Gmail Auth" checks on /health.
   Verified BOTH directions via throwaway extendModules probe (default = 0
   per-account checks, enabled = main+work, All-Gmail-Dead untouched).
   DECISION STILL OPEN (paging/alert-fatigue call = owner); rows left
   unchecked with BLOCKED notes. §f sweep: none owed (decision row).
   Probe repro (one eval, both directions): throwaway
   `extendModules` expression via `nix eval --impure --raw --expr`
   comparing `config.services.integration.inboxclean.checks` filtered on
   "Gmail Auth" names — default 0 / enabled main+work.
2. **CV TODO_LIST unstick** — VERIFIED MOOT: fresh live probe, CV tree clean
   (0 status lines, 0 stashes, TODO_LIST.md committed at `2c432cd55`).
   Commit `44ee05ec8`. §f sweep of the Source report (2026-09-30 §d2): the
   referenced storm/deploy-freeze surface is historical; no un-landed
   follow-ups harvested.
3. **Paperless encrypted-tag consistency alert** — LANDED (daemon
   `8efa52af6`): collector emits `paperless_encrypted_tagged_docs` +
   `paperless_decrypt_password_configured` (LoadCredential copy of the
   root-0400 sops secret; PLACEHOLDER sentinel) + computed
   `paperless_encrypted_consistency_ok`; new Gatus check pats the computed
   verdict. Verified: eval probe + 3-case functional run of the REAL
   rendered script against a stubbed psql (PLACEHOLDER+7 → ok=1;
   real-pw+7 → ok=0 DETECTION; real-pw+0 → ok=1). Commit `9289e49cd`.
   §f sweep: the collector-fixture row (services.md paperless-tasks-collector
   fixture test) already exists separately — not duplicated.
4. **Attic-class follow-ups** — (1) sweep executed via eval enumeration
   (pool-bound units classified creators fail-loud vs bootstrap skip-class);
   THREE noise-class units converted to the ConditionPathIsDirectory skip
   treatment (daemon `8efa52af6`/`0ba84f6ea`): tq-bootstrap,
   bank-sync-fresh-start, media-atlas-archive-perms (whose in-script
   -d guard was defeated by its own RequiresMountsFor). Creators + qonto
   shadow-gates stay fail-loud deliberately. (2) post-deploy-check §22
   root-cause collapse landed (daemon `2a4d73ddd`): one ROOT CAUSE line +
   pool-bound probe SKIPs when /mnt/pool is unmounted (paperless stack +
   paperless-gpt gated; §19/tq deliberately NOT gated — their FAIL/WARN is
   signal). (3) VM wedge leg added to tests/test-attic.nix (leg 10: pool
   mounted + atticd stopped → bootstrap FAILS LOUD with 'did not become
   ready'; needed `reset-failed` — the boot+leg-9 starts exhausted
   startLimitBurst=3 within 300s and start-limit-hit DENIED the restart
   in 0.5s, script never ran). VM test result: see the item-4 closure
   commit. §f sweep: classification-audit pin queued as a follow-up.
5. **InboxClean gmail-verdict-cache regression test** — LANDED upstream-local
   InboxClean `37f56e44` (counting VerifyAuth fake; within-TTL leg waits on
   `health_as_of` publish to close the async-refresh race; mutation-verified
   — cache read neutered → 291 probes caught). Rides next upstream push.
   SystemNix closure `57695d0e4`. FOUND: pre-existing unrelated web-package
   failure `TestServedDatastarRuntimePinsCSPMode` (fails without the new
   file) — queued as a follow-up.

## §f / follow-ups harvested (this report's own obligations)

- Pool-bound classification eval audit → TODO_LIST (new [ready] row) +
  docs/todo/services.md library row.
- InboxClean CSP test failure → TODO_LIST (new [ready] row) +
  docs/todo/upstream.md library row.
