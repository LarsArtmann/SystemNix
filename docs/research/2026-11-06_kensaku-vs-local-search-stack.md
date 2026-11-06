# kensaku vs the local search stack (OpenCloud × Paperless-ngx × file-and-image-renamer × qmd × launchers)

**Date:** 2026-11-06
**Status:** Evaluation complete. Verdict: **WATCH — complementary, not replacement.** No adoption now: zero nix packaging (self-packaging a 13-day-old Tauri app = the qmd hash-drift class without the upstream-flake escape hatch), and every corpus kensaku covers already has a dedicated owner. Its genuinely new surfaces — whole-disk screenshot OCR and a unified name+content+meaning search — are real, and the cheap probe path (`kensaku-cli`, single static Linux binary) is noted below for when the owner wants it.
**Trigger:** Owner question — "How does https://github.com/yjid/kensaku compare to what we already have?" (extended to the full local search/OCR stack).
**Sources & verification levels:** kensaku facts = repo metadata + README + `docs/USAGE.md` fetched live 2026-11-06 via gh API (release v1.0.15, created 2026-10-24, 857 stars, MIT, Rust/Tauri); **no local install or runtime probe — kensaku runtime behavior is README-claim level throughout.** In-tree facts = cited runbooks/modules, all live-verified in their own sessions. nixpkgs packaging probed: 0 code-search hits for a `kensaku` package (corroborated: repo has no `flake.nix` — 404 on the contents API; install table lists AppImage/deb/rpm only).

---

## TL;DR verdict

1. **kensaku is the missing desktop layer, not a competitor to anything we run.** It is a whole-disk launcher + search GUI that fuses four tiers we currently only have in fragments: filename (DMS spotlight/rofi/fzf), full-text (paperless, per-corpus), OCR-of-images (file-and-image-renamer, as a *rename* step, not an index), and semantic (qmd, per-curated-corpus). Nothing on the box today answers "the screenshot with the CUDA error, unnamed".
2. **It replaces nothing.** Paperless keeps document lifecycle (tags, ASN barcodes, dedup-at-door, correspondents, trash) that kensaku does not do. OpenCloud keeps sync/share/versioning/xattr metadata. qmd keeps curated deep-RAG corpora for agents. The renamer keeps producing the filenames every other surface searches.
3. **Adoption blocker is packaging, not capability:** no flake, no nixpkgs package, unsigned binaries, Windows-first maturity signals, repo 13 days old at evaluation. Re-evaluate on: an upstream/nixpkgs package appearing, a 1.x stability line, or the screenshot-search need becoming acute. Probe = `kensaku-cli-linux-x86_64` from the release assets (single static binary — trivially wrappable in a `pkgs.runCommand`/fetchurl derivation without touching the Tauri GUI).

---

## Part 1 — what kensaku is (all README/USAGE-claim level)

Local-first desktop search + launcher (Rust/Tauri 2.x, MIT): indexes watched folders whole-disk and fuses three parallel retrievers — fuzzy filename, BM25 content, static-vector semantic — via reciprocal rank fusion, plus recency/frecency boosts and a cosine floor that drops weak semantic-only hits. Deterministic ordering (score, then path).

| Area | Shipped capability (per USAGE.md) |
| --- | --- |
| Scope | Whole-disk auto-index, incremental (size+mtime), rename tracking by (device, inode), unmounted roots preserved |
| Full text | PDF/DOCX/PPTX/XLSX/EPUB/ODT/RTF/plain + 50+ code/data formats (README) |
| OCR | PP-OCRv6 on bundled ONNX Runtime by default; Indra pack (~27 MB) or Tesseract selectable; re-scans existing images when toggled on |
| Screenshots | Perceptual-hash near-duplicate bursts (10-min windows, OCR-line-overlap disambiguation), `/dupes` review view |
| Query language | `type:/ext:/in:/path:/modified:/size:/lang:/name:/content:/re:` + exclusions, phrases, `near[N]` proximity, `mode:exhaustive`; NL phrasing compiles to filters **without a model** (removable chips); aliases; facet counts |
| GUI | Launcher mode (global hotkey toggle, tray) or desktop-window mode; Quick Look previews; pins/saved searches; light/dark; EN + zh-CN |
| Agents | `kensaku-cli mcp` (stdio) + `kensaku-cli serve` (loopback HTTP/SSE, bearer token); read-only; one-click connect for claude-desktop/claude-code/cursor; `search --json` / `state` / `ask` (ask needs an external Ollama/LM Studio, cites path+line) |
| Privacy posture | No account/telemetry/cloud; **sensitive paths default-denied** (`.ssh`, `.gnupg`, `.aws`, `.kube`, `.docker`, `.password-store`, `.env*`, `.pem`/`.key`/`.pfx`, password-manager dirs); cloud placeholders indexed name-only |
| Maturity (live 2026-11-06) | Repo created 2026-10-24; v1.0.15 released 2026-11-04; 857 stars; pushed daily; MIT; unsigned builds; topics include `windows` — Linux is a port, packaged as AppImage/deb/rpm; `kensaku-cli` ships as a separate static binary per platform |

---

## Part 2 — the existing stack (verified in-tree)

| Surface | What it owns today | Search semantics | Corpus | Source |
| --- | --- | --- | --- | --- |
| **OpenCloud** (pilot, `cloud.home.lan`, :9200) | File sync & share: versions, trash, shares, spaces; posix driver with metadata in xattrs; Pocket ID OIDC, fail-closed role mapping | Built-in search service with a bleve index (`<stateDir>/search/bleve` — crash-loop trap already lived once); no Tika deployed alongside, so no AI/semantic surface | Its own sync tree only (`/mnt/pool/services/opencloud`) | [docs/services/opencloud.md](../services/opencloud.md) (status head, trap #1 xattrs, trap #10 bleve) |
| **Paperless-ngx** (3.1.1, `paperless.home.lan`, :2892, PostgreSQL) | The document vault: OCR ingestion (ocrmypdf/Tesseract; encrypted-PDF empty-content incident is documented), Tika+Gotenberg Office/mail consumption, full-text index, sklearn ML auto-matching, native AI → FastFlowLM (:52625), RAG embeddings bge-m3 on GPU llama-server :8848 (llama-rag, RE-ENABLED 2026-10-10), paperless-gpt :8106 custom-field extraction + tag-gated auto processing (vision OCR deliberately OFF) | OCR + full-text + semantic (bge-m3), plus ML tag/correspondent prediction — but only for documents that entered its archive | Ingested document corpus (`/mnt/pool/services/paperless`): scans, bank statements, InboxClean mail | [docs/services/paperless.md:267-298](../services/paperless.md), [docs/services/llama-rag.md:19](../services/llama-rag.md) |
| **file-and-image-renamer** (watcher + `renamer.<domain>` health, :8086) | AI-vision renamer: inotify on screenshot dirs, renames NEW screenshots via ZAI GLM vision / Synthetic models (degrades to whichever is configured); CQRS event store in `~/.file-renamer/`, DLQ view, OTel to SigNoz. Local llama.cpp vision is a ROADMAP idea, not wired | Writes no index at all — its output is a better FILENAME, which then feeds every filename-based surface (including kensaku's, if ever adopted) | New screenshots in watched home dirs | [docs/services/file-and-image-renamer.md](../services/file-and-image-renamer.md), [FEATURES.md:137](../../FEATURES.md), [ROADMAP.md:100](../../ROADMAP.md) |
| **qmd** (flake input `github:tobi/qmd`, global CLI) | Local RAG search CLI: BM25 (model-free) + semantic GGUF embeddings (~2 GB in `~/.cache/qmd`), manually curated collections; MCP served over stdio — **project-scoped to `~/projects/CV/.crushrc`, deliberately not global** | Deep semantic + BM25 over curated corpora; agent access is the primary surface | Whatever collections are added (`qmd collection add`) | [docs/agents/shell-devtools.md:43-51](../agents/shell-devtools.md) |
| **Launchers** (DMS spotlight on niri, rofi on sway, fzf in shell) | App/filename launch and shell-level fuzzy finding; fzf init is cached fish-side | Filename/app only — no content, no OCR, no semantics | Apps + filesystem names | [modules/nixos/desktop/multi-wm.nix:45-46](../../modules/nixos/desktop/multi-wm.nix) |

---

## Part 3 — capability matrix

| Capability | OpenCloud | Paperless-ngx | renamer | qmd | kensaku (claim) |
| --- | --- | --- | --- | --- | --- |
| Corpus | sync tree | ingested docs | (output only) | curated collections | whole watched disk |
| Filename/fuzzy launch | ✅ (web tree) | ✅ (archive) | improves names | ❌ | ✅ fused tier |
| Full text (PDF/Office/code) | bleve, no Tika → limited | ✅ (Tika+Gotenberg consume) | ❌ | ✅ | ✅ 50+ formats |
| OCR of images | ❌ | ✅ ingestion (scans) | ✅ but → filename, not index | ❌ | ✅ index-level, PP-OCRv6 local |
| Semantic / by-meaning | ❌ | ✅ bge-m3 (GPU) | ❌ | ✅ GGUF | ✅ local vectors + cosine floor |
| Screenshot archaeology | ❌ | ❌ | partial (names only) | ❌ | ✅ headline feature |
| NL time/size queries | ❌ | saved views (manual) | ❌ | ❌ | ✅ compiled without model |
| MCP for agents | ❌ | REST API (auth'd) | ❌ | ✅ stdio, CV-scoped | ✅ stdio + HTTP/SSE, read-only |
| Versioning/trash/dedup-as-archive | ✅ (xattrs) | ✅ (checksum dedup, 30d trash) | DLQ only | ❌ | near-dup grouping only |
| Sync/share/auth surface | ✅ OIDC | ✅ SSO-only | dashboard auth'd | ❌ | local user only |
| Nix packaging | nixpkgs module ✅ | nixpkgs module ✅ | our flake input ✅ | upstream flake ✅ | ❌ none (probe = CLI binary) |

## Part 4 — overlap analysis, surface by surface

- **vs OpenCloud:** zero operational overlap — different trees (kensaku indexes the local disk; OpenCloud serves the pool sync tree), different jobs (search vs sync/share/versioning). Two notes: (a) the OpenCloud desktop client syncs into home, so a future kensaku would index the *local replica* for free, making OpenCloud's weaker built-in search irrelevant for local workflows; (b) OpenCloud has no semantic layer and is not planning one — kensaku's approach (index the replica locally) is the correct division of labor.
- **vs Paperless-ngx:** deepest *feature* overlap (OCR + full-text + semantic all three), shallowest *job* overlap. Paperless is an archive with lifecycle semantics — checksum dedup at the door (`CONSUMER_DELETE_DUPLICATES`), ASN barcodes, ML auto-matching, RAG chat with source links — none of which a desktop indexer does. kensaku cannot replace it; at most kensaku would surface files in the `dataDir`/export tree by name. Keep separate.
- **vs file-and-image-renamer:** the two OCR surfaces are sequential, not competing. The renamer fixes the *name* of each new screenshot at birth (cloud-vision today); kensaku indexes *pixel text* of everything, retrospectively. A kensaku adoption would make the renamer MORE valuable (better names → better filename-tier ranking), and the renamer's DLQ/event-store discipline stays. No conflict; ROADMAP's local-vision idea is orthogonal.
- **vs qmd:** the real twin — both do local BM25+semantic with MCP for agents. Differences that keep both: qmd is deep and curated (embeddings over chosen corpora, CV-project-scoped MCP by design); kensaku is broad and automatic (whole disk, screenshots included) with a read-only MCP any client can mount. If kensaku lands, its MCP is a *different scope*, not a duplicate: whole-disk read-only probe for any session vs qmd's curated deep-RAG. Two MCP servers on one client is a context cost — mount selectively.
- **vs launchers:** DMS spotlight/rofi/fzf do names and apps; kensaku's launcher mode is a strict superset (content + OCR + meaning + previews). Not a conflict — it would be a *third* launch surface with its own hotkey; DMS spotlight stays default for apps.

## Part 5 — if the owner ever wants it (probe path + considerations)

1. **Probe first, GUI later:** download `kensaku-cli-linux-x86_64` (v1.0.15, SHA256SUMS provided), wrap in a throwaway derivation or run from `~/.cache/`, index one watched folder, verify: filename latency claim, PDF full-text, screenshot OCR text hits, `kensaku-cli search --json` output shape, MCP handshake (`kensaku-cli mcp` + initialize). Everything else in this doc stays claim-level until that probe.
2. **Packaging reality check (qmd lesson applied):** do NOT hand-package the Tauri GUI. The qmd custom packaging died of NAR-hash drift and was rescued only by adopting upstream's own flake — kensaku has no flake. Acceptable interim: the static CLI binary via fetchurl (single file, no node_modules-class FOD), GUI only after an upstream flake or nixpkgs package appears.
3. **Niri integration is clean if it ever ships:** launcher mode exposes `kensaku --toggle` for a compositor bind (INSTALL.md documents the Linux pattern); tray icon rides StatusNotifier (DMS). Desktop-window mode needs nothing.
4. **Secrets surface (watch item, not a blocker):** the default-denied path list (`.ssh`, `.gnupg`, `.env*`, `.pem`, password managers) matches this repo's secrets doctrine — but OCR'd screenshot text lands in the local index DB, and this owner's screenshots have repeatedly carried live tokens (the redact-argv class, 2026-10-22/23). The index is local-only and per-user, but it would be a new plaintext store of secret-adjacent text; verify exclusion/purge controls during any probe before pointing it at real home dirs.
5. **Two-MCP cost note:** a kensaku MCP alongside qmd's in a client config costs context window in every session; wire kensaku's only where whole-disk probing is wanted (same pattern as qmd's CV-only scoping).

**Refresh trigger:** kensaku gains a flake.nix or nixpkgs package, ships a signed/stable 1.x+ line with packaging docs, the owner asks for the CLI probe, or the "find that screenshot" pain recurs — whichever first.
