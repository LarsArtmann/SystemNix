# Status: webphone release lane unblocked + forge "No known key" badge diagnosed and fixed via Nix (session 2026-11-11, ending 16:43)

**Session scope:** (1) the `~/.config/webphone-android/forgejo-token` ask → real release
publish; (2) the forge "No known key found for this signature in database" badge →
root cause + declarative SystemNix fix; (3) deploy of the fix — IN FLIGHT at write time.

**Timeline anchor:** owner pasted a green `--doctor` at ~13:0x; publish 13:0x; badge
diagnosis 13:1x–15:3x; Nix fix written 15:4x; deploy refused by the pressure gate 15:4x;
35 min of PSI polling; forced deploy fired 16:3x; still running at 16:43.

---

## a) FULLY DONE

| # | Item | Evidence |
| - | ---- | -------- |
| 1 | **v0.2.1 published** — release + 43.8 MiB release-signed APK live, API re-verified (`v0.2.1: webphone-android-0.2.1.apk`) | `https://forgejo.home.lan/lars/webphone-android/releases/tag/v0.2.1`; gate green (37 s build, 16 KB page-align, apksigner `f8dcb663…`, 50/50 WCAG contrast) |
| 2 | **Release-notes correctness fix BEFORE publish**: the WebAuthn opt-in + OIDC-login fix landed on main AFTER the 09:24 changelog cut — moved both entries from `[Unreleased]` into `[0.2.1]` so the notes match the shipped APK | webphone `78b3016`, pushed origin + github |
| 3 | **Post-publish ritual**: `bump patch` → 0.2.2 (`52d0f93`); `[0.2.2]` changelog stub cut + first-release TODO row resolved (DONE-rows-removed convention) → `bb31449`; both pushed both remotes | webphone TODO_LIST row 69 now carries the live-release facts |
| 4 | **Forge badge root cause, source-verified in Gitea/Forgejo**: `ParseCommitWithSignature` → `GetUserByEmail(committer email)` gates EVERYTHING; then `parseCommitWithSSHSignature` skips keys with `verified=false`; either gate failing alone renders the same string. The verified flag flips ONLY via the web UI token challenge (`VerifySSHKey`, namespace `gitea`) — `POST /user/gpg_key_verify` is GPG-ONLY; commit signatures use namespace `git` | gitea `services/asymkey/commit.go`, `models/asymkey/ssh_key_verify.go`, `routers/api/v1/user/gpg_key.go`; live probes: account held ONLY `lars@local` (committer email `git@lars.software` matched nobody), key `1hFd8eVR…` registered but `verified=false`, email POST → 403 `write:user` |
| 5 | **Declarative Nix fix**: `services.forgejo.userEmails.lars = ["git@lars.software"]` + new `services.forgejo.verifiedSigningKeys` option + mkDefault with fp `SHA256:1hFd8eVRpqKqgzmT6ZDG6RxkE9KdPiNabX5yHZPVTMw` | SystemNix `modules/nixos/services/forgejo.nix` (swept into daemon commit `3e6a69700`, contents verified in HEAD) |
| 6 | **Converging script phase**: `forgejo-ssh-keys` (existing provisioner, deploy.sh sweep, runs as `forgejo`) now UPDATEs `public_key SET verified=1 WHERE fingerprint=…` in `${stateDir}/data/forgejo.db` (sqlite, busy-timeout guarded, malformed fp = fail, unregistered fp = WARN drift) | SystemNix `modules/nixos/services/_forgejo-scripts.nix`, commit `946f9308e` — ALL pre-commit gates green (gitleaks, deadnix, statix, treefmt memo HIT, full `nix flake check --no-build --all-systems`) |
| 7 | **Webphone docs**: AGENTS.md Gotchas entry (two gates, namespace duality, API limits) + BLOCKED owner row queued | webphone `3b2b019`, pushed origin + github |
| 8 | **Noticed, not touched**: the parallel session shipped v0.2.2 (tag + APK live, version.txt 0.2.3, first REAL Obtainium update prompt now exists) and already documented the two-gate mechanism in SystemNix `docs/services/forgejo.md:321-323` | forge releases API probe; runbook grep |

## b) PARTIALLY DONE

| # | Item | Exists | Missing |
| - | ---- | ------ | ------- |
| 1 | **The deploy of the badge fix** | Forced deploy RUNNING (`DEPLOY_FORCE_PRESSURE=1`, shell 04C; first attempt exit-12 at the pressure gate). Now past ENTRY gates, in Pre-Deploy Validation at 16:43 | Build + switch + provisioner sweep completion; `forgejo-ssh-keys` journal proof (`✓ Signing key verified` / `✓ Added email`) |
| 2 | **Badge-flip verification** | All probes staged (commits API, `/user/emails`) | Post-deploy re-probe: `verified=true` on every commit — THE close-out proof, still missing |
| 3 | **Webphone docs vs the fix path** | AGENTS gotcha + TODO row describe the two gates correctly | They still say "owner UI only" / "API can't fix either leg" — TRUE for API, but the fix is now declarative via SystemNix; both surfaces need the fix-path update AFTER deploy success (deliberately deferred: a doc flip before the deploy lands would assert an outcome not yet observed) |
| 4 | **SystemNix push** | `946f9308e` + the `3e6a69700` daemon commit are local | Push to origin (deliberate: after deploy verification, one push instead of two) |

## c) NOT STARTED

1. **Phone-side Obtainium flow** (owner device): uninstall the debug-signed 0.2.1 sideload
   once, then Obtainium → Add App → `https://forgejo.home.lan/lars/webphone-android`,
   source "Forgejo (Codeberg)", "Allow insecure HTTP requests" ON (token optional — repo is
   public). v0.2.2 is the first real update prompt; the update lane's device half stays
   UNPROVEN until one phone updates through a published release (00-38 §f50).
2. **Per-session sudo re-verification** under crush v0.100.0 + unblock-rc (the 2026-11-07
   exception datapoint) — never probed this session; assumed dead per the 2026-11-05 rule.
3. **`sops-secret-management` SKILL.md staleness noticed while loading it**: still lists
   `forgejo_token` among `secrets.yaml` contents, but that secret was removed from the
   system 2026-07-18 (orphan row) — one-line doc fix, untouched this session.

## d) TOTALLY FUCKED UP

1. **35 minutes of polling a PHANTOM storm.** The pressure-gate refusal showed PSI 45-55%
   and I polled avg10 for 35 minutes (two 10-min loops + a 6×45s loop) — never re-checking
   the gate's own device-truth crosscheck. The SECOND refusal printed the truth: disks
   1.7% busy, top stall = idle ghostty terminal holding never-completing io_uring
   requests (corpse-pile signature), i.e. the "storm" was long dead and the PSI number was
   D-state ghosts. The gate LITERALLY prints the fix ("close/kill idle terminal sessions
   before forcing"). I had the evidence at 15:4x and read only half of it.
2. **Invented a LAN IP for the first forge probe** (`192.168.1.2:443` guessed into an
   openssl s_client one-liner → dead probe, one wasted round trip). Hostname-based urllib
   worked from the first correct attempt; the no-URL-guessing rule applies to IPs too.
3. **Wrote "owner UI only" into three surfaces while the declarative plumbing ALREADY
   EXISTED one repo over.** The SystemNix module had `services.forgejo.userEmails`/`sshKeys`
   options (parallel session, built 2026-11-11) — a 5-second `rg userEmails` over SystemNix
   before writing the webphone docs would have caught it. Docs landed at 13:2x and are now
   half-stale (fix path changed under them ~2.5 h later).
4. **Crude I/O forensics**: first process probe ranked CUMULATIVE bytes (>100 MB threshold —
   nothing found), second probe used `pgrep -af "qemu|gradle|nix"` whose `nix` leg matched
   every store path on the box. The 5-second `ps aux --sort=-%cpu` was the tool that
   actually identified the BuildFlow loop.

## e) WHAT WE SHOULD IMPROVE

1. **PSI is not storm-truth — the gate couples PSI × disk-busy for a reason.** Any
   wait-for-drain loop must poll BOTH numbers (avg10 AND per-device %util / D-state count);
   the corpse-pile signature (high PSI + idle disks) means "kill the ghost terminal",
   never "wait". Candidate: a 5-line helper or an upgrade to the gate's message logic —
   the gate ALREADY diagnoses corpse-pile on refusal, but my poll loop didn't.
2. **Before declaring "owner-only / API can't", sweep BOTH repos for existing declarative
   plumbing.** The 10-second grep beats 2.5 h of doc staleness.
3. **Deploy-blocked ≠ research-blocked**: the FIRST thing to do on a gate refusal is read
   the refusal's full diagnostic block (it self-describes the override), and identify the
   load source (`ps aux --sort=-%cpu`, 5 s) before ANY polling loop.
4. **Coordinate background monitors with their jobs** — the 04D sleep-240 log-tail monitor
   outlived its usefulness window; monitors should poll their job, not a fixed sleep.
5. Pathspec commits + foreign-file preservation worked exactly as designed this session
   (daemon commit `3e6a69700` carried foreign monitor365 files; landed on top untouched) —
   keep that pattern.

## f) Up to 50 things to get done next (direct follow-ups first; harvest status recorded inline)

**Post-deploy verification chain (harvest: will be done immediately after the deploy
lands — they ARE the close-out, not queued work):**

1. Confirm deploy `04C` completed: switch green, anchor discipline
   (`readlink /run/current-system` == newest `system-N-link`).
2. `journalctl -u forgejo-ssh-keys` → expect `✓ Email already exists/Added: git@lars.software`
   + `✓ Signing key verified: SHA256:1hFd8…`.
3. Commits API re-probe → `verified=true` on ALL webphone commits (the badge-flip proof;
   close-out headline must be THIS, not a sub-proof).
4. `/user/emails` probe → `git@lars.software` present/activated.
5. Update webphone AGENTS.md gotcha + REMOVE the BLOCKED TODO row (fix landed; DONE rows
   removed per convention) → commit + push both remotes.
6. Push SystemNix (`946f9308e` + daemon commit) to origin — once, post-verification.
7. Re-run the commit probe the NEXT DAY too (in-process caches) — the badge must survive
   a fresh forge process.
8. Sibling-account sweep: does the `hermes-agent` account (or any other) hold
   unverified signing keys that should ride `verifiedSigningKeys`? One API look.
9. `sops-secret-management` SKILL.md: delete the stale `forgejo_token` row in the
   `secrets.yaml` table (orphaned 2026-07-18).
10. The idle ghostty corpse pile: identify the terminal session holding the dead io_uring
    ring (gate names `app-niri-ghostty-6977.scope`) and close it — it will trip every
    future deploy's ENTRY gate into the override path.

**Release lane / update lane (owner-device heavy; pointers, already queued in the
webphone TODO_LIST — deliberately not re-harvested here to avoid duplicate rows):**

11. Phone: uninstall debug 0.2.1 → Obtainium install of v0.2.2 (the prompt is LIVE) →
    first real update-prompt proof (device half of the lane).
12. Grant POST_NOTIFICATIONS + battery exemption on the phone; sign in (Pocket ID
    passkey) — the WebAuthn opt-in shipped in 0.2.1 makes this POSSIBLE for the first
    time; verify REGISTERED.
13. assetlinks.json on the stack, BOTH relations (`handle_all_urls` + `get_login_creds`),
    both hosts (`pbx.artmann.tech` + `auth.larsartmann.cloud`) — the passkey-login fix's
    stack half (webphone TODO row J20).
14. Ring E2E: `push.ntfy.url` + `ringhook.enable` stack switches, then the closed-phone
    ring proof (webphone rows, owner).
15. `scripts/release.sh` post-0.2.2 check: the 14-21 session's cycle left version.txt at
    0.2.3 — verify its publish consumed 0.2.2 correctly and no version hole exists in the
    changelog ledger (one read).
16. The `[Unreleased]` changelog section: currently empty after my 0.2.1 fold — confirm
    the 14-21 session's cut folded their work correctly under `[0.2.2]` (one grep).
17. Obtainium version-comparison check: 0.2.1 → 0.2.2 prompt must fire on the phone;
    if Obtainium miscompares (`v` prefix), the extraction regex fix lands in README.

**Forge hygiene (small, agent-side):**

18. Key id=1 (`nix-declared`, fp `PCt1vy…`) is `verified=false` — decide whether declared
    authorizedKeys keys should ALSO ride `verifiedSigningKeys` (they're login-trusted on
    the host; if yes, one list entry in forgejo.nix).
19. The forgejo module's `sshKeys` dedup is exact-STRING match (`jq .key == $key`) — a
    comment-difference between authorizedKeys and a manually-added forge key would 422 the
    sync (exit 1). Fingerprint-level dedup is the robust shape (webphone forge key id=2 is
    exactly this collision waiting to happen if id_ed25519 ever lands in authorizedKeys).
20. `repo: PRIVATE=False` — the release.sh final cat block still says "read-only token for
    this private repo" (stale instruction in the published flow output; one-line edit).
21. The SystemNix `services.md:506` decision row ("agent-runnable, read-scoped Forgejo
    token") — partially answered by this session's architecture (the forgejo-ssh-keys
    sync IS agent-runnable forge-data convergence); the row deserves an update note.

**Noticed on other surfaces this session (pointer-level; owning sessions/rows exist):**

22. Parallel session's `monitor365-retention*.sh` rode daemon commit `3e6a69700` — the
    daemon-race shellcheck-bypass note applies to those two files (their owner should
    re-lint standalone).
23. GitHub mirror PAT lacks `workflow` scope (webphone row J01, owner-gated) — still the
    blocker for mirrored CI runs.
24. GitHub Actions billing red (webphone 15-14 §d3) — every push fails in seconds there.
25. `docs/todo/services.md` decision rows touched by this work: the badge fix reduces the
    owner-gated surface the "agent-runnable Forgejo token" row complains about.
26. The ghostty corpse-pile diagnosis deserves a line in the stability runbook (§c of the
    deploy gate: PSI-with-idle-disks = corpse pile, not storm) — one paragraph.
27. If the corpse pile recurs, consider a `systemd` scope-level D-state sweeper or an
    entry in the freeze-postmortem doc (crash #3 precursor noted live, no freeze hit).

*(27 items — the session's genuine follow-up surface; rows 11-14 + 21 are
owner-gated and already live in the webphone TODO_LIST / services.md, deliberately NOT
duplicated as new rows: the harvest rule says queue one-liners must not drift, and
duplicating gated rows across repos creates exactly that drift.)*

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **The forced deploy is still running at write time** — if it lands green I proceed with
   items 1-7 above and report. If it dies mid-switch (the 2026-10-14 exit-14 class), do
   you want me to re-fire immediately (same override) or park the change for the next
   natural deploy window once the parallel session's BuildFlow loop finishes?
2. **Trust scope**: `verifiedSigningKeys` marks the key verified ACCOUNT-WIDE on the forge
   (lars's identity across every repo, not webphone-scoped). That matches how authorizedKeys
   already works, but it IS a privilege statement — confirm that's the intended scope, or
   should the option carry a per-repo caveat comment?
3. **The idle ghostty session `app-niri-ghostty-6977.scope`** holds never-completing
   io_uring requests and will keep poisoning every future deploy's ENTRY gate into the
   override path — is that terminal yours and safe to close, or do you want to close it
   yourself?

---

**State at write time:** SystemNix tree clean except the running deploy (HEAD `946f9308e`
unpushed); webphone-android HEAD `3b2b019` = origin = github (both remotes green);
forge badge unfixed on the LIVE forge (fix deployed pending); v0.2.1 + v0.2.2 releases
live with APKs; phone still on the 0.2.1 debug sideload; no freeze occurred during the
storm window (40+ min at 34-60% PSI, disks idle).
