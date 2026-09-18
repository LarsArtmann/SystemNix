# 2026-09-18 20:06 — Miniflux Pocket-ID SSO live-verified + llama-rag fetch cascade hardening (continuation session)

**Session type:** continuation of the rate-limit-killed 2026-09-17 miniflux session. The pasted terminal log carried (a) the user's OIDC callback that 400'd "This user already exists.", (b) a failed manual `nh os switch` at 08:36 (exit 4), and (c) the dead session's 7-item TODO at 4/7.

**Environment constraint hit immediately:** this Crush session's bash tool BLOCKS `sudo`, `systemctl`, and `curl`. All verification below was done with `journalctl`, world-readable `/etc/systemd/system/*.service` unit files, the `fetch` tool for loopback HTTP, and pure `nix eval` — worth knowing for future sessions on locked-down permission modes.

---

## a) FULLY DONE

1. **State survey / timeline reconstruction** — the 08:36 failure was NOT the end of the story: three clean deploys followed (system-783 @ 11:28, 784 @ 14:11, 785 @ 16:32), a reboot happened at 15:33, a second at ~19:31. `/run/current-system` == `system-785-link` target → **profile anchoring is healthy** (the exit-4 "generation skipped" hazard from the 08:36 switch was already healed by the later deploys' `reset-failed`).
2. **Miniflux OIDC link verified CONVERGED AND LIVE (the user's actual ask):**
   - `miniflux-oidc-setup.service` runs at every boot + deploy; current boot 19:31:57 journal: `already linked (user=lars sub=88bec46e-57cd-41c3-b768-e1a9e00425fb)` — it reads BOTH the Pocket ID sqlite (as root `+` ExecStartPre) and PG (as postgres, peer auth) directly, so this is authoritative DB truth, not a stale claim.
   - The "This user already exists." error requires `users.openid_connect_id IS NULL` (source-verified 2026-09-17). That state is gone. The user's pasted callback proves code-exchange + userinfo already succeeded; only the resolution step was missing.
   - Deployed unit env verified: `OAUTH2_CLIENT_ID=miniflux`, discovery endpoint, `OAUTH2_REDIRECT_URL=https://rss.home.lan/oauth2/oidc/callback` (byte-matches the pocket-id.nix callbackURL), `OAUTH2_USER_CREATION=1`.
   - Boot gate passed (`miniflux-wait-oidc`: "OIDC endpoint ready (TLS verified)"), migrations current (132/132), `/healthcheck` → `OK` (loopback fetch).
   - **User action remaining: click "Login with Pocket ID" once — first SSO login should now succeed.** Only then flip `DISABLE_LOCAL_AUTH` (the documented go-live gate).
3. **Root cause of the 08:36 exit-4 identified + cascade amplifier CLOSED (committed `8a999bcb`):**
   - `llama-rag-model-fetch.service` ran SUCCESSFULLY at 08:37:09, then "Start request repeated too quickly" 10 s later → start-limit-hit → activation exit 4. Mechanism: the fetch unit had NO `RemainAfterExit`, so after every success it went INACTIVE again — and each `llama-embeddings`/`llama-reranker` start re-satisfied `Requires=` by RE-RUNNING it. Combined with a nonstandard `startLimitBurst = 3` (house default is 5), enough starts pile up inside the window and the fetch start-limits, failing the servers transitively and exit-4'ing the whole activation. This is the same amplifier AGENTS.md documented in the 2026-09-18 rogue-orphan incident; `portGuardScript` fixed the rogue but not the amplifier, and it fired AGAIN at 08:36.
   - Fix: `RemainAfterExit = true` + `startLimitBurst 3→5` on the fetch unit (llama-rag.nix). All `Requires=` pulls become no-ops; convergence preserved (boot start + deploy.sh's provisioner-list restart — `llama-rag-model-fetch` is already in the line-438 list, deploy-restart-audit-clean since there are no restartTriggers).
   - Verified: throwaway `extendModules` eval (impure, per the sanctioned no-activation pattern) → `{remainAfterExit = true; burst = 5; interval = 300;}`; formatter clean (0 changed).
4. **AGENTS.md updated** — llama-rag section's rogue-orphan bullet now documents "Cascade amplifier CLOSED" with the why (daemon-committed in `566649e0` batch).
5. **Cleanup of the dead session's leftovers:** `git worktree prune` removed 4 stale prunable worktree records (`/tmp/mf-bisect`, `/tmp/pre-mig`, `/tmp/sysnix-base`, `/tmp/systemnix-base`); the empty `/tmp/mf-bisect` husk rmdir'd (plain deletion is the honest verb under /tmp). Background shells 03D/081 died with the dead SSH session — nothing to kill.
6. **Corrected a false alarm during survey:** llama-embeddings/reranker "not running and not in wants" initially looked broken — they are **deliberately disabled** (`llama-rag.enable = false`, configuration.nix:625, post-freeze-5 escape condition). Not touched.

## b) PARTIALLY DONE

1. **Deploy of the fetch-unit hardening — QUEUED, deliberately not run.** IO storm live during the session (PSI some avg60 peaked ~71%, load 27, 5+ `crush -y` agent sessions churning — the freeze-5 driver class; a second abrupt boot transition at ~19:28→19:31 happened mid-session). Racing a deploy into that is exactly what died at 15:27 today. The tree change is committed; it lands with the next `nix run .#deploy` once the storm drains. Storm was ALREADY draining at report time (avg10 42→, avg60 32).
2. **End-to-end SSO proof** — everything programmatically verifiable is green, but the actual passkey login needs the user's browser (no non-interactive way to mint an OIDC code). The 19:31 boot-time provisioner run proving the link + green healthcheck is the strongest signal available without the user.
3. **19:31 reboot nature** — previous boot's journal ends MID-ACTIVITY at 19:28:11 (signoz rule evals, niri metrics — no shutdown sequence), which matches the freeze signature; but `last -x` through my truncated view showed no conclusive `crash` record, and I did NOT run full freeze forensics (out of scope per "don't research unrelated"). Flagged, not diagnosed.

## c) NOT STARTED

- Freeze-#6-style forensics for the 19:28 abrupt end (if it was a crash) — deliberate scope cut this session.
- InboxClean `main`-account recovery — is a USER action (see g), not mine to start: re-consent is an interactive browser OAuth flow.
- The systemic sweep for OTHER `Requires=`-targeted oneshots lacking `RemainAfterExit` (the class my fix closes) — listed in (f).

## d) TOTALLY FUCKED UP

Nothing. Honest blemishes, all self-caught within one step:
- First `extendModules` eval failed with a priority collision (`enable` set plainly `false` in configuration.nix vs plainly `true` in my throwaway module) — fixed with `mkForce` on retry; negative-control value: it proved the eval actually forces the option rather than silently passing.
- Initially read "llama servers not running" as breakage; corrected to deliberate disable after checking `multi-user.target.wants` + configuration.nix.
- The `fetch` tool call without `format` errored once (tool-contract miss, retried correctly).

## e) WHAT WE SHOULD IMPROVE

1. **The user ran raw `nh os switch .` at 08:36** — bypassing `nix run .#deploy` means pre-deploy checks and post-switch provisioner restarts never ran, and the exit-4 left the un-anchored-generation hazard standing until the next proper deploy. The repo rule exists for exactly this; worth a fish alias/alias-warning or just discipline.
2. **`systemctl`/`sudo` blocking in this Crush permission mode cost round-trips** — future sessions on this box should know journalctl + `/etc/systemd/system` reads + `nix eval` suffice for most verification. Candidate for a short AGENTS.md note (not added this session — AGENTS.md was under concurrent daemon edits; do it on the next touch).
3. **Class sweep not yet automated:** the "Requires=-targeted oneshot without RemainAfterExit" shape could join `systemd-shape-audit.nix` so the cascade class is caught at eval time repo-wide, not per-incident.
4. **No live re-verification of the hardening yet** — after the next deploy, confirm the fetch unit sits in `active (exited)` and that a `systemctl restart llama-embeddings` does NOT re-run the fetch (journal proof, one command pair).
5. **Storm driver visibility:** 5+ concurrent `crush -y` sessions are the recurring IO-storm driver (freeze-5, today's 19:28 event, this session's 70% PSI). The tq-pool budget caps exist but IO-pressure admission for agent sessions does not. `heavy-job` wrapping or an admission gate keyed on PSI for pool-spawned agents is the structural fix (crush-hot-db migration helps the QLC side; concurrency is the other half).

## f) NEXT THINGS (ordered, most impact first)

**Immediate (today/tomorrow):**
1. Retry SSO login at `https://rss.home.lan` — proves the fix end-to-end.
2. InboxClean: flip Google OAuth consent screen to "In production" FIRST, then re-consent `main` (runbook in AGENTS.md InboxClean section); verify `/health` shows both accounts `connected`.
3. When PSI drains: `nix run .#deploy` → lands the fetch hardening (+ whatever else the daemon batched).
4. Post-deploy: verify `llama-rag-model-fetch` shows `active (exited)` and a server restart doesn't re-run it (journal).
5. Determine whether the ~19:31 boot was a crash (check `last -x` reboot records properly, guard Zone-6 trip counters around 19:28, wtmp) — if crash, run the freeze-forensics template.
6. After ONE proven SSO login: set miniflux `disableLocalAuth` (go-live gate per runbook).
7. Update `docs/services/miniflux.md` runbook status line: link converged 2026-09-17, SSO live 2026-09-18.
8. Check `buildcache-usb-recovery` post-deploy (it failed "still failing I/O" at the 19:31 boot but the mount answered real I/O 8 min later; deploy.sh re-runs it — confirm it converges or the enclosure flapped again).
9. Confirm sev1/Zone-6 guard behaved during today's storm window (trip counters, no false silences) — the 19:28 event is a live calibration sample.

**Hardening / class closure:**
10. Eval-time shape audit: flag any `Requires=`-targeted `Type=oneshot` unit lacking `RemainAfterExit` (generalizes today's fix).
11. Sweep existing modules for the same shape (grep `requires =` + oneshot defs) and fix any other amplifier.
12. Consider PSI-aware admission for tq-pool/agent-spawned `crush -y` sessions (wrap in `heavy-job` or gate on IO PSI).
13. Add the "sudo/systemctl blocked → use journalctl/unit-files/nix eval" verification recipe to AGENTS.md on next touch.
14. VM-test note for the fetch unit: pin `RemainAfterExit = true` in `tests/test-*` if a llama-rag test exists, so the amplifier can't silently return.
15. Re-check `inboxclean-sync` exit-75/OnFailure noise AFTER re-consent (it pages every 30-min tick until then — expect Discord noise).
16. When llama-rag is re-enabled (post root-cause): the new RemainAfterExit + burst-5 wiring goes live; re-run the unit-context soak discipline from AGENTS.md (direct-run green is NOT unit evidence).
17. Root-cause the 2026-09-18 llama.cpp spin (ROCm/kernel/GPU-state suspect per AGENTS.md) — prerequisite for re-enabling llama-rag at all.
18. Miniflux: after go-live, consider retiring the sops break-glass ADMIN_PASSWORD rotation docs to "rotation = UI only" (env rotation is inert for existing users).

**Standing items I noticed but did not touch (scope discipline):**
19. `/var/lib/forgejo/repositories/lars/{golangci-lint,DynamicMinecraftNetwork}.git` stale commit-graph.lock cleanup (needs forgejo user).
20. Forgejo mirror: the 2 transferred-to-org repos (DarkBlocks, DialogesWebInterface) still need the owner decision (delete or re-mirror).
21. CV branch-ref-governed hold — `nix build github:LarsArtmann/CV/master#default.goModules` probe when upstream moves.
22. Two Artmann-Minecraft transfers + 32 archived-only mirrors: pool-size measurement after first mass migration (forgejo user needed).
23. Pocket ID groq key decision (ChatService warn is owner-visible in AGENTS.md; no paging) — wire key or disable provider.
24. Resend domain verification (SPF include replace, not add) — gates paperless/forgejo outbound mail beyond owner-address.
25. Offsite leg (Hetzner BX11 + BorgBackup) — decided, not deployed.
26. TODO_LIST P0: /data EIO inode repair (btrbk-data still aborts on it).
27. Crush-hot-db: confirm first migration ran post-storm (symlink sweep + PSI baseline vs 40-60%).
28. `nixpkgs-llama-rag` pin retirement path: document the ROCm-runtime bisect plan once the spin is root-caused.
29. Old crush session DBs with pre-migration key residue — inert until rotation; rotation tracked in the persistent-nag TODO.
30. Sweep `scripts/post-deploy-check.sh` for any remaining probes of retired services (homepage smoke was removed; do a one-pass audit on next touch).

## g) QUESTIONS I CANNOT ANSWER MYSELF

1. **Was the ~19:31 reboot deliberate (you power-cycled) or another freeze?** The journal cut mid-activity at 19:28:11 with no shutdown record — if it crashed, that's a 3rd abrupt end today and deserves forensics; if you rebooted, I'll stand down.
2. **Is the InboxClean Google OAuth consent screen now "In production"?** If yes, one re-consent fixes `main` permanently; if it's still Testing, any re-consented token dies again in 7 days and the flip must come first (I cannot see your Google console).
3. **Are the 5+ concurrent `crush -y` sessions intentional (tq-pool workload you want running) or leftovers to close before the queued deploy?** They are the IO-storm driver; the deploy waits on them either way, but if they're unintended, closing them drains PSI faster.

---
*Session verification summary: link row = DB truth via provisioner journal (every boot since 2026-09-17); OAUTH2 env = deployed unit file; healthcheck = loopback fetch `OK`; hardening = committed + eval-verified + formatter-clean; anchoring = readlink equality; worktrees = pruned. No deploy executed (storm). No secrets written anywhere; the sub UUID quoted is a Pocket ID internal identifier, already public in AGENTS.md.*
