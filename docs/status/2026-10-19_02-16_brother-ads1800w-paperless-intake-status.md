# Status: Brother ADS-1800W → Paperless-ngx intake setup (first session)

- **Date:** 2026-10-19 02:16 CEST
- **Session scope:** plan + verify + wire the scanning leg of the 2000-receipts/invoices → Paperless-ngx campaign (user-owned hardware: Brother ADS-1800W)
- **Tree at report time:** HEAD `6d6b7cf57`, working tree CLEAN (auto-commit daemon swept everything; see §Concurrency)
- **Format note:** user explicitly demanded `.md` at this path — the status-report skill's HTML-canonical default is overridden by that instruction (recorded per skill rule, not propagated as a default)

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| a1 | **Server-side intake confirmed already built** — Paperless-ngx on evo-x2 with consume dir `/mnt/pool/services/paperless/consume`, `PAPERLESS_CONSUMER_RECURSIVE`, PATCH-T barcode splitting, Code-39 ASN barcodes, `PAPERLESS_OCR_LANGUAGE=deu+eng`, FastFlowLM AI classification, `PAPERLESS_CONSUMER_DELETE_DUPLICATES` | `modules/nixos/services/paperless.nix:438-482` (repo read, this session) |
| a2 | **Scanner located and identified** — USB-connected to evo-x2, not on WiFi: `/sys/bus/usb/devices/6-1`, vendor `04f9`, product `ADS-1800W`, serial `E83229M4X114379` | live sysfs read |
| a3 | **Driver requirement established** — ADS-1800W is NOT in sane-backends; all four USB interfaces are vendor-proprietary (class `ff`, no IPP-USB) → eSCL/AirScan-over-USB impossible → **brscan5** required; `sane-find-scanner` sees `libusb:006:004` (vendor=0x04f9 product=0x0708); `scanimage -L` finds nothing (expected without backend) | live probes, this session |
| a4 | **brscan5 verified as the correct Brother Linux driver for ADS-1800W** — Brother's official download list for the model is the brscan5 line; the artifact IDs nixpkgs fetches (`dlf104033`/`dlf104034`) are the exact downloads whose Brother compatible-models list includes ADS-1800W | Brother support pages + web.archive.org captures, 2026-10-19 |
| a5 | **brscan5 wired into the config** — `hardware.sane.brscan5.enable = true` added in `platforms/nixos/system/networking.nix:175-181` using the dedicated NixOS module option (canonical wiring confirmed from `nixos/tests/brscan5.nix`; `netDevices` not needed for USB) | commit `81cf31372` (daemon-swept, content verified in HEAD) |
| a6 | **Eval verification** — `nix eval .#nixosConfigurations.evo-x2.config.hardware.sane.brscan5.enable` → `true`; toplevel evals: `/nix/store/p5n3j5ly7hmn2sr0sbbpgyr6h50mjxky-nixos-system-evo-x2-26.11.20261015.fe13242.drv` | nix eval run 2026-10-19 ~01:35 CEST, at tree `692ee009` + my edit |
| a7 | **External claims verified against primary sources (after §d1 correction)** — Brother: Scan-to-Network CIFS / FTP / SFTP all supported, configured via Web Based Management (`https://<scanner-ip>`), duplex yes, "Receipt" an officially supported paper type, ADF 20 sheets, min doc size 50.8 × 70 mm (smaller needs Carrier Sheet). Paperless: inotify default consumer (polling only for NFS/CIFS-mounted consume dirs), `RECURSIVE`/`ENABLE_BARCODES`/`ASN_BARCODE` all real options, `PATCHT` default separator string, Code 39 = ASN symbology | Brother Online User's Guide (`support.brother.com` htmldoc `cv_ads1800w`) + specs page; Paperless docs (`docs.paperless-ngx.com/configuration/`, `advanced_usage/`, `usage/`, `troubleshooting/` — raw site 403s, identical Read-the-Docs mirror used). All 2026-10-19 |

## b) PARTIALLY DONE

| # | Item | What's missing |
|---|------|----------------|
| b1 | **First scan** — driver wired + eval green, but the generation is NOT deployed and no scan has been taken | `nix run .#deploy` (user-manual deploy authority), then `scanimage -L` → `scanimage -A` → one test page |
| b2 | **Scan → Paperless handoff** — the drop path is known but not built: consume-dir write permissions for `lars` unverified (dir owned by the paperless user), no scan script/staging dir | permission check + small drop mechanism (§f12-14) |
| b3 | **Efficient 2000-doc workflow** — physical process defined (no pre-sort, staples out, flatten folded thermal receipts, sort digitally in Paperless after ~50-100 training docs), but nothing operationalized (no scan profile, no training milestone, no carrier-sheet check for sub-50.8 mm slips) | §f15-22 |
| b4 | **Scanner on the LAN** — network route fully researched (SMB/SFTP/FTP destinations verified; would let the scanner sit at the desk instead of next to the server) but deliberately parked after USB was found; SMB-version-negotiation risk flagged, unresolved | decision §g2, then §f23-25 |

## c) NOT STARTED

| # | Item | Note |
|---|------|------|
| c1 | DNS/DHCP identity for the scanner (`scanner.home.lan` + dnsblockd device-registry entry) — moot for USB, needed for the WiFi route | §f24 |
| c2 | Runbook doc (`docs/services/` has no scanner page; `docs/services/paperless.md` doesn't mention a scanner intake path) | §f30 |
| c3 | `FEATURES.md` / `CHANGELOG.md` entries for scanner support | §f31-32 |
| c4 | Ingest-capacity estimate for 2000 docs (OCR deu+eng, 2 celery workers, FLM classification) — will run fine overnight per architecture, but no measured duration exists | §f19 |
| c5 | Carrier Sheet acquisition/check for receipts narrower than 50.8 mm | §f21 |
| c6 | AGENTS.md knowledge-routing update (scanner knowledge belongs in the paperless runbook per the routing table) | §f33 |

## d) TOTALLY FUCKED UP

| # | Item | Honest accounting |
|---|------|-------------------|
| d1 | **First answer shipped UNVERIFIED external claims — the user had to catch it** ("Did you check the official paperless-ngx and co docs?"). Violation of the verify-external-claims chat-time gate (skill now loaded; gate applies per-sentence, not per-session). Two claims needed correction: "feed stacks" → ADF is **20 sheets**; "ADF auto-detects size, receipts fine" → min doc **50.8 × 70 mm**, smaller slips need the Carrier Sheet. The SMB-recommendation survived verification, as did inotify-fast-ingestion | corrections delivered with sources in-session; this is the skill's own documented failure mode, replayed live |
| d2 | **LAN hunt burned ~6 probe rounds before checking the obvious** — ARP → ping sweep → TLS-cert probes on 6 hosts → /dev/tcp:80 → nmap → mDNS (timed out) — all hunting a WiFi device that was USB-plugged into the very server I was probing. `lsusb`-equivalent sysfs check would have ended it in one round. Root cause: I optimized for the pre-planned network architecture instead of questioning where the user had plugged the device | "I just connected it" was ambiguous; one clarifying question or one sysfs check first was the better move |
| d3 | **Eval-green claim is now stale by 6 daemon commits** — I verified the evo-x2 toplevel at `692ee009` + my edit; the current HEAD (`6d6b7cf57`) carries foreign changes (`lib/lars-packages.nix`, `overlays/linux.nix`, `modules/nixos/services/{discordsync,health-dashboard}.nix`) from a parallel session AFTER my eval. My change still reads correct in HEAD (`networking.nix:179-180`), but "toplevel evals green" is only proven for MY snapshot, not the tree a deploy would build | per concurrent-session rule: your flake check covers your files only |

## e) WHAT WE SHOULD IMPROVE

**Self-review answers (brutal-self-review folded in per user's one-report instruction):**

1. **What did you forget?** — (i) to ask "USB or WiFi?" for ~5 minutes of probes; (ii) that `hardware.sane` was already enabled (found it late — my own first-turn answer implied SANE wasn't configured; networking.nix:176 had it all along, for a "Canon PIXMA MG2500"); (iii) to queue any of this in `TODO_LIST.md` (deliberately deferred, see Harvest note); (iv) no runbook/FEATURES/CHANGELOG entries yet (c2/c3).
2. **What is stupid that we do anyway?** — `hardware.sane.enable` sits in `networking.nix` (networking file owns a scanner), justified by a Canon PIXMA MG2500 comment. Is that Canon even still in the house? If not, that comment is a doc-drift lie and the provenance is a ghost config. Worth one owner question, not research.
3. **Did you lie to me?** — No. But the first answer contained confident unverified specifics (d1) — that is the lie-adjacent failure class this repo documents, and the user caught it. Everything asserted after that challenge carries a source.
4. **Ghost systems?** — Two candidates: (i) the Canon PIXMA sane enablement (possibly dead provenance, live config); (ii) the verified-but-unused network scan route (SMB/SFTP) — real feature, zero wiring. Neither should be integrated without the §g2 decision.
5. **Split brains?** — Small one, self-inflicted this session: the efficient workflow now has TWO half-truths in circulation (USB-with-brscan5 vs WiFi-SMB/SFTP). Until §g2 is decided, any doc written about "the scanner setup" would fork. Keep one source of truth (the future runbook) blocked on the decision.
6. **Could you have done better?** — Load verify-external-claims BEFORE the first substantive answer (the skill's chat-time gate); lead hardware questions with the one-cheapest probe (sysfs/USB) before network sweeps; deliver the §b2 permission check in the same breath as the driver wiring instead of parking it.
7. **Could you still improve?** — Yes: §f. Also, when handing off a deploy to the user mid-parallel-session, state explicitly that the eval proof is snapshot-scoped (d3) — I did flag the foreign changes, but not that they post-dated my eval.

**Process improvements:**

- Adopt "verify at first assertion" for external-tool claims in chat answers, not just artifacts.
- For hardware questions: enumerate connection modalities (USB/WiFi/both) as step 0.
- Daemon-race: my one tracked-file edit landed inside a 5-file heuristic commit (`81cf31372`) mixed with a parallel session's work — attribute honestly in the report (done here) and consider the PATHSPEC-commit discipline next time a shared-tree commit is mine to make.

**Concurrency note (shared tree):** during this session a parallel session committed Shodan exposure-monitoring advisory work, a drive-paperless self-review doc, and code changes (lars-packages, overlays/linux.nix, discordsync, health-dashboard). None touched my file. My brscan5 edit rode daemon commit `81cf31372` (content verified in HEAD by `git grep`). The §d3 stale-eval caveat applies to any deploy decision until a fresh toplevel eval.

---

## f) NEXT THINGS (sorted by impact; `[d]` = dispatch-grade one-ask, `[r]` = roadmap/decision-grade)

*Harvest note (per TODO-system rule): the user instructed "THEN WAIT FOR INSTRUCTIONS" — §f is NOT harvested into `TODO_LIST.md`/domain libraries this report. Deliberate deferral, recorded here; on the user's go, items below route to `docs/todo/services.md` (paperless-owned) with `**Source:**` = this report.*

1. `[d]` **Deploy the brscan5 generation** — `nix run .#deploy`; re-eval toplevel first if the parallel session's commits land before the build (d3). Then verify `/run/current-system` anchors to the new generation (deploy-anchor discipline).
2. `[d]` **`scanimage -L` must list a `brother5:` device** — the §a3→§a5 chain is unproven until SANE actually drives it. Watch for a model-metadata failure: nixpkgs ships brscan5 `1.3.1-0` while Brother's current rev is newer; if the models dir lacks ADS-1800W, the package needs a version bump/override.
3. `[d]` **`scanimage -A` option probe** — enumerate ADF source names (duplex), resolution, color mode for the profile in #4.
4. `[d]` **First test scan** — single page, 300 dpi color; confirm the PNG/PDF lands.
5. `[d]` **Verify USB device-node permissions for user scans** — `lars` is in `scanner`; brscan5 ships udev rules (`49-brother-mfp-brscan5`); confirm post-deploy they landed and a non-root scan works.
6. `[d]` **ADF duplex batch test** — 10-page mixed-size stack, one job.
7. `[d]` **Consume-dir write path for scans** — check `/mnt/pool/services/paperless/consume` ownership/ACLs; decide `lars`-writes-directly vs staging dir + mover.
8. `[d]` **Build the scan→consume handoff** — smallest sound shape: a `scan-drop` script (scanimage --batch → PDF → consume) or a systemd path unit on a staging dir. Pool mount-gating: a drop while the pool is degraded must not vanish (verify dir behavior under mount-gate).
9. `[d]` **Live-probe the Paperless consumer on a manual drop** — one tiny PDF into consume; confirm ingest + OCR + classification end-to-end before the campaign.
10. `[r]` **Decide duplicate policy for the campaign** — `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` silently deletes byte-identical files: right for mail intake, but a 2-page doc re-scan after a jam becomes a partial-duplicate question. Owner call: keep on vs toggle off for the campaign window.
11. `[r]` **Decide primary transport: USB-at-server vs WiFi Scan-to-Network** — WiFi moves scanning to the desk (receipts pile up where you are, not next to the server) and removes the brscan5 dependency; USB is already 80 % wired. Owner decision (§g2), then #12-14 or close them.
12. `[d]` **(if WiFi) SMB vs SFTP destination** — SFTP with public-key auth avoids the unverified SMB-version-negotiation risk entirely; SMB matches the docs' canonical pattern.
13. `[d]` **(if WiFi) build the server leg** — samba share or sshd account exposing the consume dir; credential via interactive step (house rule: no secret values in repo or command lines).
14. `[d]` **(if WiFi) scanner-side profile** — define the destination in Web Based Management (`https://<scanner-ip>`); test one push-to-consume round-trip.
15. `[d]` **Scan profile definition** — 300 dpi, color, duplex, multi-page PDF; write it into the runbook (#30) once proven.
16. `[d]` **Thermal-receipt legibility test** — one faint receipt at default settings vs contrast bump; fades are the known failure mode.
17. `[r]` **Carrier Sheet for sub-50.8 × 70 mm slips** — inventory the smallest receipts first; buy only if needed (officially required below min size).
18. `[d]` **Training milestone plan** — after ~50-100 scans: create correspondents/tags, set AUTO matching, run Train Classifier; only then bulk-scan the rest (machine-self-sorts, human corrects exceptions).
19. `[d]` **Ingest-capacity measurement** — time the first 50-doc batch (OCR deu+eng, 2 workers, FLM classify) → extrapolate 2000; confirms overnight-batch assumption with data.
20. `[d]` **Receipt classification sanity** — FLM AI on short no-correspondent receipts: check title/tag suggestions on the first batch, tune before bulk.
21. `[d]` **Date extraction spot-check** — `DATE_ORDER=DMY` is set; verify on real German receipts after the first batch.
22. `[r]` **PATCH-T separator sheets** — only if a stack-scan workflow (one job, many docs) beats per-doc touchscreen jobs for part of the 2000; order sheets then.
23. `[r]` **(if WiFi) DNS/DHCP identity** — `scanner.home.lan` reservation + dnsblockd device-registry entry (candidates API lists active leases for onboarding).
24. `[r]` **Physical placement decision** — where the scanner lives (desk vs server shelf) drives #11; tie-break after the first week of scanning.
25. `[d]` **(post-campaign) Pool/storage note** — 2000 docs into paperless dataDir on the pool: size is trivial, but the first export/restic window after bulk ingest is worth watching.
26. `[r]` **brscan5 provenance question** — is the Canon PIXMA MG2500 (the original `hardware.sane.enable` reason, networking.nix comment) still around? If dead: fix the comment/provenance; if alive: it shares the SANE stack fine.
27. `[r]` **scanbd (button-driven scanning)?** — probably YAGNI with this workflow; record as considered-and-rejected unless the touchscreen route annoys.
28. `[d]` **Post-first-batch Paperless hygiene** — check the train-classifier hourly task stays green (the repo runbook documents the empty-vocabulary failure class; receipts + AUTO tags could re-trigger variants).
29. `[d]` **Document the unverified-SMB-risk resolution** — whichever way #12 goes, record the scanner's actual SMB negotiation result (or "moot, SFTP") so the runbook doesn't carry an open "risk" forever.
30. `[d]` **Write `docs/services/<scanner>.md`** (or extend `paperless.md`) — driver, profile, transport decision, workflow, training plan, jam/duplicate procedure; the AGENTS.md routing table expects a runbook for this surface.
31. `[d]` **FEATURES.md entry** — document scanner intake as a capability with its status.
32. `[d]` **CHANGELOG entry** — brscan5 wiring + first-scan verification once done.
33. `[d]` **AGENTS.md routing update** — one line pointing scanner questions at the runbook (#30).
34. `[r]` **Multi-page receipts / Continuous Scan** — the scanner's Continuous-Scan mode (verified: saves >ADF-capacity runs as one file) vs host-side `--batch`; pick per workflow in #15.
35. `[r]` **ASN barcodes** — enabled in Paperless already; only relevant if a print-shop-style numbering scheme is ever wanted. No action now.
36. `[r]` **Jam-recovery procedure note** — what a mid-batch jam does to consume (partial jobs, re-scan duplicates vs #10's policy); belongs in the runbook (#30).
37. `[r]` **Offsite/backup timing** — paperless exporter + restic windows after bulk ingest; confirm the first post-campaign export is green before declaring victory.
38. `[r]` **Second-scanner option** — if the campaign stalls on physical throughput (20-sheet ADF), revisit: a second ADF or the Qonto/inboxclean digital paths already cover some invoices.

## g) QUESTIONS (cannot figure out myself)

1. **Deploy timing:** run `nix run .#deploy` for the brscan5 generation now, or wait for the parallel session's in-flight work (Shodan advisory, lars-packages/overlays changes — 6 commits since my eval, eval-status of the current tree unknown per §d3)? My recommendation: fresh `nix eval` of the toplevel right before deploying, then deploy — but the go is yours.
2. **Transport doctrine:** is USB-with-the-server acceptable for the whole 2000-doc campaign, or should the scanner go on WiFi (Scan-to-Network → consume) so scanning happens at the desk? This decides whether I build the Samba/SFTP leg (#12-14) at all, and where the scanner physically lives (#24).
3. **Duplicate policy during the campaign:** keep `PAPERLESS_CONSUMER_DELETE_DUPLICATES=true` (current; silently drops byte-identical re-scans — including accidental re-feeds after a jam) or turn it off for the campaign window so every physical page is guaranteed archived and dedup happens by review instead?

---

*Report ends. WAITING FOR INSTRUCTIONS.*
