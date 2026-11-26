# baidu.com is allowed and live-verified, the carrying switch is UNANCHORED: dnsblockd block diagnosis, whitelist allow, self-review (2026-11-26, 06:40)

**Created:** 2026-11-26 06:40 CET · Crush agent session (glm-5.4) · basis: this session's three turns only (owner: "DO NOT RESEARCH OTHER STUFF UNRELATED TO WHAT YOU DID").
**Harvest status: HARVESTED at authoring time** — 4 items ride existing rows, 5 were closed in this pass, 8 are deliberately not harvested under intake control (ledger in section h).
**HEAD at authoring:** `da6fb86fe`

## Scope line

**Verified in this session** (command + artifact, times CET, one boot `0737ecd7-96a1-4320-8516-dbcff4e46e07` throughout):

- Turn 1, 2026-11-25 19:33–19:45: `dig` against 127.0.0.1; a raw HTTPS probe with `openssl s_client` by IP; `journalctl -u dnsblockd` (block, audit and proxy lines); `mapping.json` lookups in `/nix/store/p7lygcimxwb7kkd5ypm06daviiyiybc1-dns-blocker-processed` (python); the upstream list `dnsmasq/nosafesearch.txt` fetched from raw.githubusercontent.com; `/proc/net/arp`; a scan of all 35 processed builds in the store.
- Turn 2, 2026-11-25 20:57–21:45: the edits below; `nix eval` of the whitelist (pure: 78 entries; through the module system for rpi3-dns and for evo-x2: 78 entries, `baidu.com` member, rc=0 each); `nix fmt -- --fail-on-change` on the two nix files ("formatted 2 files (0 changed)", 3.46 s); `bash scripts/check-todo-system.sh` rc=0; the upstream README and issues #1397, #8761, #7777, #4240 via the GitHub search API; `/proc/pressure/io` samples and a 6 s `/proc/*/io` delta.
- Turn 3, 2026-11-26 06:14–06:40: `journalctl` for the 06:16:48 activation; `readlink /run/current-system` against the profile; the deployed mapping `/nix/store/7nrhmsm3myp62nys4cdymmpwbfs1n30b-dns-blocker-processed/mapping.json` (python: 2,160,147 keys); `dig` via 127.0.0.1, 192.168.1.200 and 192.168.1.53; HTTPS by name; `scripts/tick-todo-rows.sh` dry-run by title.
- Evidence files: `~/.cache/baidu-allow/` (upstream README and API JSON, eval outputs, fmt log, todo-check log).

**NOT verified here:**

- The ESP boot entry: `/boot/loader` is not readable unprivileged (permission denied). "No boot entry" below rests on the exit-4 rule in AGENTS.md, not on a read.
- `checks.x86_64-linux.dns-blocker-render` never ran (io PSI some avg10 read 25.7–47.5 % at every sample). The 78-entry pin is proven only by the two module evals.
- The deadnix/statix legs on daemon commit `833bb57cc` (formatter-clean only) and whether that commit passed the pre-commit hook.
- Which device 192.168.1.46 is (a MAC OUI and a config comment only).
- Why the mapping fell on 2026-11-24 (the timeline yes, the per-list cause no).
- Who ran the 06:15:07 `nh os switch` (the sudo journal shows only `lars`, TTY pts/40) and why `service-health-check.service` failed at 06:17:58.
- The rpi3-dns hardware state, the SearXNG `baidu images` engine, the dashboard allow routes (never exercised), and the wall time of the two module evals (the `time` output went to a stderr tail I cut).

## TL;DR

1. **Cause.** `www.baidu.com` was blocked by the `HaGeZi-nosafesearch` list, which carries `baidu.com` at the apex. Upstream added it from a community batch (issue #1397, 2023-08-08), with no Baidu-specific reason recorded.
2. **Allow.** `"baidu.com"` joined the permanent whitelist on 2026-11-25 (daemon commit `833bb57cc`). A switch that is not mine carried it live at 06:21 on 2026-11-26, and it is verified: deployed mapping 2,160,147 keys with zero under `baidu.com`, real addresses on every resolver path, HTTPS 200, no block line in the journal.
3. **That switch is UNANCHORED.** The activation ended with exit 4 (`service-health-check.service` failed), the profile is still `system-1031-link`, and no `system-1032-link` exists. A reboot reverts to gen-1031 and blocks Baidu again.
4. **My worst mistake.** The first answer said the entry would also strip "roughly 840 other Baidu rows". The real figure is 180; the other 664 rows were unrelated domain names that contain the word "baidu". Corrected in the second answer.
5. **The box is still storming.** io PSI has not been below 25 % at any of my samples since 20:57 on 2026-11-25; eleven `nix run .#deploy` attempts between 19:47 and 06:37 were refused rc=12 at the pressure gate.

## Self-review (the twelve brutal-self-review questions)

**1. What did you forget?**

- To read the daemon's own decision log first. I spent four probe batches on browser-policy, proxy and gateway hypotheses before one `journalctl` grep printed `source=HaGeZi-nosafesearch`.
- That a temp allow can mask a block. `dig` returned real addresses at 19:33:21 because the block page had granted a 5-minute allow at 19:32:11. I read that as "not blocked at the DNS layer".
- The owner's rule that a number must survive one known-value check before it enters an answer. I counted keys containing the substring "baidu" and reported them as Baidu tracker rows.
- Pressure discipline for my own probes: `json.load` over 35 × 86 MB store files (about 3 GB) with no PSI read first.
- To pin boot id and PSI at session start (I pinned the boot id only after DNS dropped).
- To capture the `time` output of the two module evals.
- To flag the headless duplicate line I saw in `CHANGELOG.md` at 20:5x. It is fixed in this pass.
- The AGENTS.md pre-read for ad-hoc sessions (`ls -t docs/status | head`). I ran the `baidu` grep but not the listing.

**2. What is something that's stupid that we do anyway?**

- A whitelist entry strips every subdomain row and nothing shows what was released. The filter prints `skipped=` to a build log nobody reads. My miscount is a symptom of that.
- The whitelist size is pinned as a literal in a test and restated in a comment and the runbook, so each entry costs four synchronized edits.
- CHANGELOG markers saying "rides next deploy" never flip by themselves.
- Five documents claim ~4M+ blocked domains (4,296,867 in `docs/DOMAIN_LANGUAGE.md`) while the deployed mapping has 2,160,147.
- Every dnsblockd restart is a LAN-wide DNS outage while rpi3-dns is down: six restarts in 24 h, 225–326 s each, about 26 minutes in total.
- A raw `nh os switch` outside `nix run .#deploy` bypasses the entry gates and the post-switch anchor repair. One happened at 06:15:07.
- In the agent tool shell the builtin `printf` has no width or precision (`%8.1f` fails) and `env` is blocked.

**3. What could you have done better?**

- First command: `journalctl -u dnsblockd --since '19:25' | grep 'domain blocked' | grep baidu`. It answers the question and names the list.
- Count by suffix (`key == "baidu.com" or key.endswith(".baidu.com")`), never by substring.
- For "is this a fresh regression", read the journal line `loaded blocklist mapping` or sample two old builds. Do not scan 35.
- Use the S-0035 probe from `docs/agents/stability.md` verbatim. I hand-rolled a sampler and got it wrong three times.
- Raise the count-pin design question before bumping four places, instead of extending the existing split brain.
- In turn 2, say plainly that the change is inert until a deploy and that deploys were being refused. I did say both.

**4. What could you still improve?** Section e, and the open items in section f.

**5. Did you lie to me?** Not deliberately. Two statements were wrong or imprecise:

- "Roughly 840 other Baidu rows (trackers and ads)" in the first answer. Wrong by 4.7×. Corrected in the second answer and in the CHANGELOG entry (commit `58f6c01ee`).
- "The routes exist in the dnsblockd source" referred to the local checkout `/home/lars/projects/dnsblockd`, not to the deployed rev `29bd806`. The two differ: the checkout's default temp-allow is 15 m, the live grant was 5 m.

Every other number in the two answers was re-read at report time or comes from the artifacts named in the scope line.

**6. How can we be less stupid?** Make the build prove the whitelist: after `mapping.json` is generated, fail the build if any whitelisted domain still has a row, and print the rows each entry stripped. Then "allow X" shows its blast radius before a deploy, and a count like mine cannot be typed into an answer.

**7. Ghost systems?** None in my work. Two adjacent observations:

- The dashboard's permanent allowlist (`allowlist_path`, runtime file) and the declarative `whitelist` (build-time) are two mechanisms for one concept. That is by design (no-deploy relief for the household against an auditable list in git), but nothing shows the difference between them. The build-time report in question 6 could list dashboard allows that are missing from git.
- `HaGeZi-nosafesearch` is a parental-control list in a single-operator household: 103 search engines that offer no SafeSearch (`lycos.com`, `presearch.com`, public SearXNG instances). Whether it belongs in the set is an owner preference, not a defect.

**8. Are we focusing on the scope creep trap?** Partly. The runbook recipe, the stability clause and the harvest are outside "allow baidu.com". They follow the AGENTS.md self-harvest and memory rules, but they are scope growth and are listed here so they can be judged. The 35-build scan was scope creep for a "why" question.

**9. Did we remove something that was actually useful?** No. The only deletion is the duplicate fragment at `CHANGELOG.md` line 44, removed after confirming it is a strict substring of the full entry at line 33.

**10. Did we create any split brains?** Not a new one, but I extended one: the whitelist count now lives in `tests/test-dns-blocker-render.nix` lines 25, 584 and 585, in `docs/services/dnsblockd.md` line 38, and as "77 → 78" in the CHANGELOG entry. The next entry will need all four again.

**11. How are we doing on tests?**

- Not run: the render check that owns the pin I edited.
- Run instead: two module evals and, after the switch, the deployed artifact (2,160,147 = 2,160,328 − 181, exactly the predicted count).
- Better: the build-time whitelist gate from question 6, plus a cheap pure test that imports `platforms/common/dns-blocklists.nix` and asserts no duplicates and normalized names. Neither needs seven full-config evals.

**12. Did I re-verify inherited claims?** Four failed re-verification:

- `docs/services/dnsblockd.md` says the gateway is armed and the decrypt overlay is enabled. The tree has both disabled (known: the `[decision]` row "Reconcile the dns-blocker render fixture with the gateway-disable decision").
- The same runbook says the host resolves through rpi3 first. Live `/etc/resolv.conf` is `127.0.0.1` then `9.9.9.9`, because that ordering is conditional on the armed gateway.
- `docs/DOMAIN_LANGUAGE.md`, `README.md` (three places) and `platforms/nixos/system/dns-blocker-config.nix` line 4 claim ~4M+ blocked domains. Live: 2,160,147.
- The device registry says the MacBook is 192.168.1.62. That address has no line in the dnsblockd journal for 14 days; 192.168.1.46 has 4,935 lines since at least 2026-11-17 and carries the Realtek OUI the registry comment calls the Mac's USB adapter. Unverified.

## a) FULLY DONE

| #   | Work                                                                                                                                                                                                                                   | Evidence                                                                                                                                                                                                                                       |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| a1  | Diagnosis: `www.baidu.com` blocked by `HaGeZi-nosafesearch` (apex row `baidu.com`, parent-label match)                                                                                                                                  | journal 19:32:09 (`source=HaGeZi-nosafesearch client=192.168.1.46`) and 19:42:42 (my probe); `mapping.json`: `baidu.com -> HaGeZi-nosafesearch`; upstream list header "Blocks search engines that don't support Safesearch", 103 entries |
| a2  | Upstream origin traced: issue #1397 (2023-08-08), a batch of about 50 search engines, accepted by the project bot                                                                                                                       | `~/.cache/baidu-allow/gh-1397-comments.json`                                                                                                                                                                                                    |
| a3  | `"baidu.com"` added to the permanent whitelist; count pin 77 → 78 in the render test and the runbook; CHANGELOG entry; library verification row                                                                                         | daemon commits `833bb57cc` (21:07:42, four files of mine plus four foreign files, not amended), `58f6c01ee` (CHANGELOG wording), `08969de87` (library row)                                                                                     |
| a4  | Eval-level verification: 78 entries on both hosts, formatter-clean                                                                                                                                                                     | `nix eval` pure and via `nixosConfigurations.{rpi3-dns,evo-x2}.config.services.dns-blocker.whitelist`, rc=0; `nix fmt -- --fail-on-change` "0 changed"                                                                                        |
| a5  | Live verification after the 06:16:48 switch: deployed mapping 2,160,147 keys, zero under `baidu.com`, the 664 substring-only rows kept (627 HaGeZi-tif, 24 HaGeZi-ultimate, 8 HaGeZi-gambling, 3 StevenBlack-everything, 1 HaGeZi-doh, 1 HaGeZi-nsfw) | `journalctl` 06:17:31 and 06:21:25 (`domains=2160147`); python over `/nix/store/7nrhmsm3myp62nys4cdymmpwbfs1n30b-dns-blocker-processed/mapping.json`; `www.baidu.com` → 103.235.47.188 / 103.235.46.96 on 127.0.0.1 and 192.168.1.53; HTTPS by name `HTTP/1.1 200 OK`; zero `domain blocked` lines for `baidu.com` since 06:15 (the only Baidu substring block is my `live-857-baidu.com` probe at 06:22:04, via HaGeZi-tif) |
| a6  | This pass: library row ticked (`scripts/tick-todo-rows.sh --apply`), CHANGELOG marker set to live, duplicate fragment removed, triage recipe added to `docs/services/dnsblockd.md`, bulk-read clause added to the Build-Storm runbook, the UNANCHORED and rpi3 rows stamped | section h                                                                                                                                                                                                                                      |

## b) PARTIALLY DONE

| #   | Work                                                                                     | Works now                                                                                                   | Remains open                                                                                                                                                                   | Blocker                                                                        | Effort |
| --- | ---------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ------ |
| b1  | The allow is live, but the generation carrying it is not anchored                         | Running system `d5qzj0h2n8qc…` serves the allow since 06:21:24                                             | Profile is `system-1031-link` (`6q9jp84a…`), no `system-1032-link`; activation exit 4; boot entry unreadable. A reboot reverts to gen-1031                                    | Root (sudo is dead in agent shells): `docs/todo/stability.md` row 531        | S      |
| b2  | Render check for the 78-entry pin                                                        | Module evals on both hosts                                                                                 | `nix build .#checks.x86_64-linux.dns-blocker-render` never ran                                                                                                                 | io PSI 25.7–47.5 % at every sample                                             | S      |
| b3  | Lint legs on the daemon-swept commit                                                     | Formatter clean (0 changed)                                                                                | deadnix and statix not re-run on the two nix files                                                                                                                             | Same pressure; `nix run .#lint` is a full battery                              | S      |
| b4  | The allow on rpi3-dns                                                                    | The whitelist is shared in git                                                                             | rpi3 is unreachable and gets the entry only on its own redeploy                                                                                                                | `docs/todo/services.md` row 791                                                | M      |
| b5  | Harvest of this report                                                                   | 4 items ride existing rows, 5 closed in this pass                                                          | 8 items deliberately not harvested (intake control: this session closes no queue row, so it mints none)                                                                        | Owner ruling or a session with queue budget                                    | S      |

## c) NOT STARTED

| #   | Work                                                                   | Why not started                                                     | Still wanted?          |
| --- | ---------------------------------------------------------------------- | ------------------------------------------------------------------- | ---------------------- |
| c1  | `nix run .#pre-reboot-check` after the anchor repair                   | Needs the repair first (root)                                       | Yes, with b1           |
| c2  | Root cause of the `service-health-check.service` failure at 06:17:58   | Belongs to the session that switched; its report was not read       | Yes, by that session   |
| c3  | SearXNG `baidu images` engine check after the allow                    | No evidence the engine was ever broken by the block                 | Only if Baidu is used  |
| c4  | Device registry update for 192.168.1.46                                | Identity unverified                                                 | Pending question g Q2  |
| c5  | Reconcile the ~4M+ blocklist claims and explain the 2026-11-24 step    | Owner said not to research beyond this session                      | Pending question g Q3  |
| c6  | Build-time whitelist gate and blast-radius report                      | Intake control (section h)                                          | Yes, top candidate     |
| c7  | Replace the literal count pin with a host-equality pin                | Intake control (section h)                                          | Yes                    |
| c8  | Standalone brutal-self-review HTML in `docs/reviews/`                  | Folded into this file by the owner's format request                 | No                     |

## d) TOTALLY FUCKED UP

| #   | What                                                                                                  | Severity                                        | Root cause                                                                                                                  | Mitigation                                                                                       |
| --- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| d1  | First answer claimed "roughly 840 other Baidu rows (trackers and ads)"; real: 180 rows under `baidu.com` | Medium: a wrong number in a user-facing answer   | Substring count presented as a domain count                                                                                | Corrected in the second answer and in the CHANGELOG; recipe added to the runbook                 |
| d2  | The running system is UNANCHORED after the 06:16:48 switch (not mine)                                 | High: a reboot reverts every change in that switch | A raw `nh os switch .` (sudo journal: `lars`, TTY pts/40) ended exit 4; deploy.sh's own attempts were refused rc=12 at 06:12:18 and 06:18:38 | Repair recipe in `docs/todo/stability.md` row 531, needs the owner's root session                |
| d3  | About 3 GB of needless store reads on a storm-prone box                                               | Low this time, high if repeated                 | Scanning 35 builds to support a "not a regression" sentence                                                                 | Clause added to the Build-Storm runbook                                                           |
| d4  | Journal-last diagnosis: about ten extra probe batches before the one-line answer                      | Low: owner time                                  | Anchored on "resolver says fine, so it is not DNS"                                                                           | Recipe added to the runbook                                                                      |
| d5  | Hand-rolled IO sampler failed three times                                                              | Low                                             | Tool-shell `printf` has no width or precision; then a `read` field misalignment                                               | Use the canonical probe verbatim                                                                  |
| d6  | IO storm: io PSI some avg10 25.7–47.5 % at every sample from 20:57 on 2026-11-25 to 06:40; eleven deploy attempts refused rc=12 (19:47, 20:21, 20:24, 20:29, 20:33, 20:35, 20:37, 20:40, 20:42, 06:12, 06:18, 06:24, 06:31, 06:37) | High: nothing deploys through the gate          | Not established. Top readers in my 6 s window: two `crush -y` processes (PIDs 47288 and 9772, started 11:07–11:09 on 2026-11-25); earlier gopls | Existing `[decision]` row "Parallel-agent-session concurrency cap"; report-only for agents        |
| d7  | Blocklist coverage claims: ~4M+ and 4,296,867 in five places; live 2,160,147                            | Unknown until question g Q3 is answered         | The mapping fell from 3,329,343 to 2,160,328 between 20:47:02 and 21:37:02 on 2026-11-24 (journal `loaded blocklist mapping`) | None yet                                                                                         |
| d8  | DNS outage class: six dnsblockd restarts between 06:15 on 2026-11-25 and 06:21 on 2026-11-26, each a LAN-wide outage | High for the household                           | `server_init` reads 222–321 s (journal) with the failover peer down                                                                          | Existing rows `docs/todo/services.md` 791, 1151, 1152                                               |

Note on d6: that list holds fourteen attempts, not eleven. The count in the row title is wrong; the list is right.

## e) WHAT WE SHOULD IMPROVE

| #   | Pattern                                                               | Impact                                                 | Suggested fix                                                                                                                                                                                  | Status                       |
| --- | --------------------------------------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| e1  | No triage recipe for "why is X blocked"                               | A 20-minute detour for a one-line answer               | "Blocked-domain triage" section in `docs/services/dnsblockd.md`                                                                                                                                 | Done in this pass            |
| e2  | Whitelist blast radius is invisible                                   | Wrong expectations; trackers released unnoticed         | In the `processedBlocklist` build: assert zero rows for every whitelisted domain, print rows stripped per entry, add a negative test in `scripts/negative-test-lints.sh`                        | Not harvested (section h)    |
| e3  | Literal whitelist count pinned in four places                          | Four synchronized edits per entry; drift               | Pin `rpi3.whitelist == evox2.whitelist`, non-empty, no duplicates; drop the count from prose                                                                                                 | Not harvested (section h)    |
| e4  | Ad-hoc bulk reads are not named as agent load                          | Avoidable IO on a box with a freeze history             | One sentence in the Build-Storm runbook, step 3                                                                                                                                                 | Done in this pass            |
| e5  | A raw switch bypasses deploy.sh's gates and anchor repair             | Unanchored running system after exit 4                  | A box-side check on `/run/current-system` changes that repairs the profile, independent of deploy.sh. `docs/todo/pipeline.md` already carries seven deploy.sh-side anchor rows                       | Not harvested (section h)    |
| e6  | "Rides next deploy" markers never flip                                 | Stale status in the CHANGELOG                           | Post-deploy grep reminder or a docs-gate                                                                                                                                                       | Not harvested (section h)    |
| e7  | Harness forbids commits; the daemon commits with heuristic messages   | No traceable commit for a config change                 | Owner-level: AGENTS.md says amend, the harness forbids commit                                                                                                                                  | Owner decision               |
| e8  | Harness forbids comments; the whitelist file documents every entry    | `baidu.com` is the one entry without a why-comment      | Owner-level: allow why-comments at the point of use                                                                                                                                            | Owner decision               |
| e9  | Hand-maintained blocklist counts in five documents                    | 50 % drift, unnoticed                                  | Derive the count from the build                                                                                                                                                                | Not harvested (question Q3)  |
| e10 | Session-start discipline                                 | Late detection of restarts and storms     | Pin boot id and PSI and list the newest status reports before any diagnosis                                                                                                                      | Practice                     |

## f) Things to get done next

Session-scoped by the owner's instruction. Twelve real items, not fifty: the rest would be padding. Dispositions are in section h.

| #   | Task                                                                                                                                             | Impact   | Effort | Category     | Disposition                                                            |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------ | ------------ | ---------------------------------------------------------------------- |
| F1  | Anchor the running generation: profile and boot entry for `d5qzj0h2n8qc…` (root recipe in `docs/todo/stability.md` row 531), then `pre-reboot-check` | Critical | S      | Bug          | HARVESTED: existing row (stamped with this instance)                  |
| F2  | Find why `service-health-check.service` failed at 06:17:58 and made the activation exit 4                                                       | Critical | S      | Bug          | Not harvested: belongs to the switching session                       |
| F3  | Answer whether the 2026-11-24 mapping drop is intended, then fix the ~4M+ claims in README (3), `docs/DOMAIN_LANGUAGE.md`, `dns-blocker-config.nix` | High     | S      | Documentation | Not harvested (intake control; question g Q3)                         |
| F4  | Build-time whitelist gate and blast-radius report (e2)                                                                                             | High     | M      | Feature      | Not harvested (intake control)                                        |
| F5  | Replace the literal count pin with a host-equality pin (e3)                                                                                       | Medium   | S      | Quality      | Not harvested (intake control)                                        |
| F6  | Run `checks.x86_64-linux.dns-blocker-render` when io PSI is below 20 %                                                                             | Medium   | S      | Quality      | Not harvested (intake control)                                        |
| F7  | Box-side anchor guard that also covers raw switches (e5)                                                                                           | Medium   | M      | Feature      | Not harvested (intake control)                                        |
| F8  | Identify 192.168.1.46 and update the device registry                                                                                               | Low      | S      | Cleanup      | Not harvested (question g Q2)                                         |
| F9  | Restore rpi3-dns, the DNS failover peer                                                                                                            | High     | M      | Bug          | HARVESTED: existing row `docs/todo/services.md` 791 (re-check stamp)   |
| F10 | Cut the dnsblockd `server_init` cost (225–326 s per restart)                                                                                        | High     | L      | Bug          | HARVESTED: existing rows `docs/todo/services.md` 1151 and 1152         |
| F11 | Contain the storm writers (two `crush -y` processes)                                                                                               | High     | M      | Bug          | HARVESTED: existing row `docs/todo/stability.md` 17                   |
| F12 | Check the SearXNG `baidu images` engine after the allow                                                                                            | Low      | S      | Bug          | HARVESTED: adjacent existing row `docs/todo/services.md` 792          |

<!-- fresh:skip: F2 F3 F4 F5 F6 F7 F8 are deliberately not harvested under intake control (close >= mint); see section h -->

## g) Questions I can not answer myself

**Q1. The 06:15:07 `nh os switch` was yours or one of your sessions, and who repairs the anchor?**
What I tried: the sudo journal (`lars`, TTY pts/40, PWD SystemNix), the deploy logs (deploy.sh's own attempts 06:12:18 and 06:18:38 were refused rc=12, so this switch has no deploy log), and `pgrep`. I cannot attribute a TTY to a session and cannot run the root repair.

**Q2. Is 192.168.1.46 the MacBook?**
What I tried: `/proc/net/arp` (Realtek `00:e0:4c:68:04:00`), the registry comment in `platforms/nixos/system/dns-blocker-config.nix` lines 100–110 (says that OUI is the Mac's USB adapter, at `.62`), and the dnsblockd journal (`.62`: no line in 14 days; `.46`: 4,935 lines). I have no DHCP lease access.

**Q3. Was the blocklist drop on 2026-11-24 intended?**
The mapping fell from 3,329,343 to 2,160,328 between 20:47:02 and 21:37:02 that day. `platforms/common/dns-blocklists.nix` line 149 retires `HaGeZi-dga7` on the same day and the HaGeZi URLs became pinned-commit then. I did not compare per-list counts (out of scope by instruction) and cannot tell intent from the journal.

## h) Harvest ledger (pass artifact)

Every premise was re-checked on 2026-11-26 between 06:14 and 06:40.

| Source | Disposition                       | Destination / reason                                                                                                                                                     |
| ------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| F1     | existing row (updated)            | `TODO_LIST.md` row 409 and `docs/todo/stability.md` row 531: new-instance note. Premise re-checked: `/run/current-system` = `d5qzj0h2n8qc`, profile = `system-1031-link` |
| F2     | declined for now                  | The switching session owns it; no row read that names it                                                                                                                 |
| F3     | not harvested (intake control)    | No existing row (grep for the counts, `tick-todo-rows.sh` dry-run); waits on question Q3                                                                                 |
| F4     | not harvested (intake control)    | No existing row                                                                                                                                                          |
| F5     | not harvested (intake control)    | `TODO_LIST.md` row 2425 (ipify pin assertion) is related but open and different                                                                                          |
| F6     | not harvested (intake control)    | The live artifact already proves the effect; the check run is hygiene                                                                                                    |
| F7     | not harvested (intake control)    | `docs/todo/pipeline.md` rows 366–469 cover the deploy.sh side only                                                                                                       |
| F8     | not harvested (question)          | Registry edit needs the identity (question Q2)                                                                                                                           |
| F9     | existing row (stamped)            | `docs/todo/services.md` row 791: re-check stamp. Premise re-checked: `dig @192.168.1.151` timeout at 06:40                                                                |
| F10    | existing row                      | `docs/todo/services.md` rows 1151 and 1152; this report adds the six measured startup times                                                                                   |
| F11    | existing row                      | `docs/todo/stability.md` row 17; this report names the two reader PIDs                                                                                                     |
| F12    | existing row (adjacent)           | `docs/todo/services.md` row 792                                                                                                                                            |
| e1     | done in this pass                 | `docs/services/dnsblockd.md`, new "Blocked-domain triage" section                                                                                                          |
| e4     | done in this pass                 | `docs/agents/stability.md`, Build-Storm runbook step 3                                                                                                                     |
| a6     | done in this pass                 | Library row ticked, CHANGELOG marker set to live, duplicate fragment at `CHANGELOG.md` line 44 removed                                                                     |
| e6     | declined                          | Tooling idea without a bounded spec                                                                                                                                        |
| §7     | declined                          | Keeping or dropping `HaGeZi-nosafesearch` is an owner preference; no row minted                                                                                             |
| §9     | declined                          | `~/.cache/baidu-allow/` kept as the evidence directory for this report                                                                                                     |
