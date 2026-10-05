# SystemNix Status 2026-10-05 13:51 — Helium passkeys via KeePassXC: shipped config, honest self-review, dp-profile gap found

**Task:** user ask "Find the best way to easily deal with passkeys in Helium in a more native way" → research + implementation session, then this full status + brutal self-review.
**Scope:** this session's run and what was noticed along the way (user instruction: no unrelated research).

**Format note:** `.md` per explicit user instruction — status-report skill canonical is HTML; override flagged, not propagated.

---

## Verdict

The best passkey path for Helium is **KeePassXC-Browser passkeys** — not anything browser-builtin, because browser-builtin passkey storage does not exist on this stack (verified: GPM requires Google sign-in, stripped in ungoogled-chromium; Chromium profile-local passkey storage is macOS-only; out-of-the-box Helium offers only YubiKey CTAP2 + phone hybrid QR, and the wrapper already enables `WebAuthenticationHybridTransport`). Everything needed was already installed (KeePassXC 2.7.12, KeePassXC-Browser 1.10.4.1 in the main profile, native messaging live since 2026-09-14) — the feature is just disabled by default in the extension. The session shipped a declarative enablement via `chrome.storage.managed` (3rdparty enterprise policy), verified eval-green — and the self-review then caught a real gap in what I claimed: **the dp1/dp2 browser windows can never reach KeePassXC at all** (native-messaging manifests exist only in the main profile dir). All doc surfaces corrected; fix queued.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **Passkey landscape research (multi-source)** | Linux/ungoogled has no builtin passkey storage; GPM-needs-signin + macOS-only-profile-storage confirmed against Google docs, Bitdefender 2025 Linux-browser passkey testing, ungoogled-chromium issues. KeePassXC passkey support verified: 2.7.7 introduced (2.7.12 in nixpkgs — eval'd), extension 1.9.0+ finalized (1.10.4 = PRF + cross-origin iframes), managed storage schema keys found |
| 2 | **`extraChromiumPolicies` option** (`modules/nixos/desktop/browser-policies.nix`) | Generic attrsOf-anything option merged verbatim into `programs.chromium.extraOpts`; consumed by configuration.nix for the 3rdparty policy |
| 3 | **KeePassXC passkey policy** (`platforms/nixos/system/configuration.nix`) | `3rdparty.extensions.oboonakemofpalcgghocfoadofidjkkk.policy.settings.{passkeys,passkeysFallback} = true` — managed storage applies to ALL Helium profiles (extension options are per-user-data-dir; the policy is the only way main/dp1/dp2 get it at once) |
| 4 | **Render-verified** | `nix eval` of `environment.etc."chromium/policies/managed/extra.json".text` shows the exact 3rdparty JSON; all pre-existing policies (search provider, ExtensionSettings, MV2) intact |
| 5 | **Checks green** | `nix flake check --no-build` passed on the final nix state; alejandra-formatted both edited nix files; `check-todo-system.sh` structure OK |
| 6 | **Docs** | desktop.md Helium section (design + rationale + dp-gap caveat), FEATURES.md KeePassXC row, CHANGELOG entry |
| 7 | **TODO hygiene** | `[blocked:deploy]` verify row + 8 follow-up rows in docs/todo/desktop.md; 5 `[ready]` rows harvested into TODO_LIST.md queue |
| 8 | **Live facts pinned before claiming** | KeePassXC 2.7.12 (eval), extension 1.10.4.1 in main profile Extensions dir, keepassxc.ini live settings, managed-storage race fix (#2969) landed in extension 1.10.2 < installed 1.10.4.1 |

## b) PARTIALLY DONE

| # | Item | What remains |
|---|------|--------------|
| 1 | **Passkey enablement itself** | Config landed, committed (daemon), NOT deployed, NOT live-verified. One real ceremony post-deploy is the acceptance test (`[blocked:deploy]` row carries the full probe protocol incl. chrome://policy render + a `.home.lan` RP probe) |
| 2 | **"All three profiles" coverage** | TRUE for the policy (global /etc/chromium/policies), FALSE for the chain: dp1/dp2 native messaging is missing (see §d.2). Corrected on all surfaces this session |
| 3 | **Managed-storage key names** | `settings.passkeys`/`passkeysFallback` sourced from an AI sub-agent reading the extension repo (direct fetch 404'd). If a key name were wrong, chrome.storage.managed would SILENTLY ignore it. Verification row queued (read managed_storage.json out of the installed CRX) |

## c) NOT STARTED

1. dp1/dp2 native-messaging manifests (`xdg.dataFile` fix — queued `[ready]`).
2. Eval-check pinning the 3rdparty policy render (queued `[ready]`).
3. Extension-ID single-source constant (queued `[ready]`; the ID is now in THREE places — I widened a 2-way split brain).
4. Conditional UI (autofill webauthn) support check for 1.10.4.1 (queued `[ready]`).
5. macOS parity (darwin has its own extension list; `[decision]` queued — resurfaces the never-answered 2026-09-14 Q3).
6. Passkey migration/import of EXISTING credentials (`.passkey` exports; `[decision]` queued — needs owner knowledge of where today's passkeys live).
7. Second authenticator on Pocket ID before consolidating (`[decision]` queued — break-glass against DB loss locking out SSO).

## d) TOTALLY FUCKED UP (and what it cost)

1. **First module edit broke evo-x2 eval.** I wrote `extraOpts = cfg.extraChromiumPolicies` as a SEPARATE definition next to `extraOpts.ExtensionSettings = ...` — the option doesn't merge two plain definitions that way. One dead eval round trip. Root cause: guessed the module merge shape instead of reading the option definition first. The failure mode is exactly what my queued eval-check would pin against future repeats — I proved the fragility on myself.
2. **Docs shipped an overclaim I had not verified.** "one DB across all THREE Helium profiles" — the self-review fact-check (2 `ls` commands) proved the dp user-data-dirs have EMPTY `NativeMessagingHosts/` and there is NO system-wide `/etc/chromium/native-messaging-hosts`, so the extension in dp windows can never reach KeePassXC. Password fill has been dead in dp windows since they were created (2026-09-29) and nobody noticed (dp profiles hold ~6 urls). Corrected on ALL surfaces per the correction-claim rule: desktop.md bullet, CHANGELOG entry, and the deploy-verify row (now expects dp to fail until the manifests land). What it exposed: a pre-existing integration gap, found only because a self-review demanded proof of a comfortable claim.
3. **Session Discipline skipped at the start.** No content-pin (`git rev-parse HEAD` + `git status`) before the first write. The daemon committed my work THREE times mid-session (0f117333, 1c81d50d, d1ade48d) and a parallel session's flake.nix `systems`-follow cleanup rode the same commit window. I flagged the foreign change to the user and inspected it post-hoc (`git show`), but the pin would have made the batch contents predictable instead of discovered.

## e) WHAT WE SHOULD IMPROVE (brutal self-review answers)

**What did you forget?**
- The dp-profile plumbing question until the self-review forced it ("does my claim hold for all three profiles?"). I verified the POLICY scope but never the CHAIN it rides on.
- That the session-added policy widened the extension-ID split brain (2 → 3 surfaces).
- macOS entirely (the standing open question from 2026-09-14 Q3 was never resurfaced until this review).

**What is stupid that we do anyway?**
- Research findings from AI sub-agens flow into config/docs with keys and semantics I did not read from primary sources — in THIS repo, whose whole prevention-layer philosophy is "verify the claim, not the vibe". The `verify-external-claims` skill exists for exactly this and I did not invoke its discipline on the managed-storage keys.
- The KeePassXC native-messaging manifest is deployed to exactly ONE browser profile dir with no system-wide host — a shape whose coverage was never mapped when the dp instances were created. (Not mine, but I shipped docs ON TOP of it without checking.)

**What could you have done better?**
- Pin before write; read the option definition before wiring module merges; run `alejandra --check` before the first daemon window, not after (the daemon can commit unformatted files and my final formatting pass churned 265 lines of browser-policies.nix — formatting noise mixed into a semantic diff, worse reviewability).
- Fact-check comfortable claims against the machine BEFORE they land in docs, not during the self-review. Two `ls` commands took ten seconds.

**Did you lie?**
- No claim was fabricated. One claim was OVERBROAD ("all three profiles") — true for the policy, false for the underlying chain; it was corrected on all surfaces the moment the fact-check falsified it. The live-verified facts (versions, rendered JSON, flake check) all hold at HEAD.

**Ghost systems / split brains?**
- No ghost systems (everything wired; the new option has one consumer by design).
- Split brain WIDENED: extension ID now in 3 places (queued fix). Doc restatement across desktop.md/FEATURES/CHANGELOG is repo convention, not a split brain.

**How are we doing on tests?**
- This session added config without a regression check — below this repo's own bar (the tree has eval-guard + selftesting-check patterns for exactly this class). The queued eval-check + negative case closes it.

**Scope creep?** No — the session stayed on the ask; the follow-ups are all passkey-adjacent or direct self-review findings.

## f) Next (session-scoped; honestly ~20, not padded to 50 — the instruction forbids researching unrelated work)

| # | Task | State | Gate |
|---|------|-------|------|
| 1 | Deploy + live passkey ceremony verify (chrome://policy render, KeePassXC dialog, fallback path, `.home.lan` RP probe) | queued `[blocked:deploy]` | deploy |
| 2 | dp1/dp2 native-messaging manifests (`xdg.dataFile`, ONE manifest def, three targets) | queued `[ready]` | — |
| 3 | Verify managed-storage keys against installed CRX's managed_storage.json | queued `[ready]` | — |
| 4 | Eval-check pinning the 3rdparty policy (+ negative case) | queued `[ready]` | — |
| 5 | Extension-ID single-source constant | queued `[ready]` | — |
| 6 | Conditional-UI support check (1.10.4.1) → UX expectations for login pages | queued `[ready]` | — |
| 7 | YubiKey CTAP2 ceremony as fallback-path proof (key attached, udev shipped) | notice | post-deploy |
| 8 | Second Pocket ID authenticator (YubiKey) before consolidating passkeys | queued `[decision]` | owner |
| 9 | Migrate/import existing passkeys into KeePassXC (`.passkey` files)? | queued `[decision]` | owner |
| 10 | macOS passkey parity for darwin browsers | queued `[decision]` | owner |
| 11 | KeePassXC DB-unlock UX: locked DB = failed ceremony; document/verify autostart path | notice | — |
| 12 | flake.nix `systems`-override warnings: confirm gone after the parallel session's cleanup (foreign change completeness — unverified by me) | notice | — |
| 13 | 92 unharvested §f-bearing status reports (`check-todo-system.sh` WARN, pre-existing process debt noticed during final guard run) | notice | docs-health HARVEST pass |
| 14 | PasswordManagerEnabled=false policy question (open since 2026-07-29 item 31) — sharper now that KeePassXC would own secrets + passkeys | notice | owner |
| 15 | Post-deploy: confirm extension auto-updates reach dp profiles via the Helium proxy too | notice | post-deploy |

## g) Questions I cannot figure out myself

1. **Where do your EXISTING live passkeys live today (phone? YubiKey? which ceremonies used what)?** This decides whether to migrate them into KeePassXC (`.passkey` import), leave them device-bound, or re-enroll fresh — and it feeds the Pocket ID second-authenticator decision (§f.8).
2. **Should the dp1/dp2 monitor windows get the full KeePassXC chain (manifests land via the queued fix), or is main-profile-only what you actually use?** dp password fill has been dead since 2026-09-29 and nobody noticed — maybe the dp windows are read-only-by-design for you.
3. **macOS: want passkey enablement on the MacBook's browser(s) too, or is this Linux-only for now?** (Same shape as the never-answered 2026-09-14 Q3 about KeePassXC-Browser on darwin.)

---

**Surfaces touched this session:** `modules/nixos/desktop/browser-policies.nix`, `platforms/nixos/system/configuration.nix`, `docs/agents/desktop.md`, `FEATURES.md`, `CHANGELOG.md`, `docs/todo/desktop.md`, `TODO_LIST.md`, this report. All committed by the daemon (d1ade48d + successors); nothing pushed.
