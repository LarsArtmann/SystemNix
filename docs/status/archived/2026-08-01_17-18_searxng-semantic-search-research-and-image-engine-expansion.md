# Session Status: SearXNG Semantic Search Research & Image Engine Expansion

**Date:** 2026-08-01 17:18
**Session focus:** Open Web Index + SearXNG semantic search research, image search engine expansion

---

> **RESOLVED — Resolved. Work captured in CHANGELOG.md.**
> All forward-looking items in this report were completed in subsequent sessions.


## a) FULLY DONE

### 1. OWI + SearXNG Semantic Search Research Doc

**File:** `docs/research/2026-08-01_open-web-index-searxng-semantic-search.md`

Comprehensive research document covering:
- What the Open Web Index is (EU-funded, 14 institutions, 1 PB pilot, targeting 5-10 PB)
- Data formats (CIFF inverted index, Parquet metadata, WARC raw crawl, planned `emb` embeddings slot)
- Embeddings status: OWI data model has `owie` resource type for embeddings but explicitly "not yet available"
- 4 EU-funded projects that built embeddings over OWI subsets (VERITAS, TILDE, AKASE, FUN) — none expose a search API
- SearXNG integration: only GitHub issue #5327 (discussion, Oct 2025, no code)
- Scale analysis: embedding 35 TB → ~105 TB vectors (float32) or ~26 TB (int8), needs distributed vector DB
- Build path for evo-x2: owilix → embed Parquet content → OpenSearch kNN → custom SearXNG engine

### 2. Related GitHub Projects Documentation (Text Search)

Added to the research doc:
- **For SearXNG integration:** harvard-lil/warc-gpt (275★), Orion/SearXNG+Qdrant (closest to native integration), yacy/yacy_expert (694★, FAISS), MultiX0/froxy (21★)
- **Web crawl → vector pipelines:** commoncrawl/cc-vec (official CC tool, MCP-enabled), demo-semantic-crawl (14-step pipeline)
- **SearXNG-adjacent:** jcrabapple/searxng-ai (AI summaries, no vector retrieval)
- **Other web search engines:** StractOrg/stract (2.4k★, archived), mwmbl/mwmbl (1.8k★)
- **Gap analysis:** No project provides a native SearXNG engine plugin that does vector/semantic search over a locally indexed web corpus

### 3. Related GitHub Projects Documentation (Image Search)

Added to the research doc:
- **Tier 1 (Production):** rom1504/clip-retrieval (2.8k★, powers LAION-5B), rom1504/img2dataset (2.5k★), criteo/autofaiss (1k+)
- **Tier 2 (Self-hosted):** hv0905/NekoImageGallery (193★, CLIP+Qdrant), flaribbit/imgfind (153★, Rust+candle+CLIP), kingyiusuen/clip-image-search (268★), soulteary/simple-image-search-engine (155★), stg7/clipse (6★, academic)
- **Vector DB infrastructure:** Qdrant, Milvus, OpenSearch, txtai, Vald, FAISS
- **Build path for evo-x2:** img2dataset → clip inference → autofaiss → clip back → custom SearXNG offline engine

### 4. SearXNG Image Engine Expansion

**File:** `modules/nixos/services/searxng.nix:200-203`

Added 4 new image search engines:
- `bing images` — second-largest image index
- `duckduckgo images` — privacy-respecting, diverse sources
- `qwant images` — European engine, good EU content
- `tineye` — reverse image search (find where an image appears on the web)

All engine names verified as valid SearXNG engine names against the upstream `settings.yml`.
`nix flake check --no-build` passes. `nix eval` confirms all 8 image engines active (was 4).
Auto-git daemon committed changes in `141ae427`.

### 5. NekoImageGallery Deep-Dive Analysis

Researched full deployment requirements for SystemNix:
- 2 containers: Qdrant + NekoImageGallery (CPU-only on evo-x2, no CUDA)
- CLIP ViT-L/14 (768-dim) + BERT + PaddleOCR (all bundled in Docker image)
- Token-based auth (admin API + access protection), no OIDC
- API endpoints: text search, image search, hybrid search, admin upload, local indexing
- **Conclusion:** redundant with Immich for personal photos. Makes sense only for a separate corpus (stock images, memes, web-crawled datasets)

---

## b) PARTIALLY DONE

### SearXNG image engine expansion

- Added 4 engines but there are **25+ more image engines** available in SearXNG that we didn't add (see section e)
- Did NOT deploy the changes (committed but not activated)
- Did NOT run `nix fmt` (alejandra formatting not verified)

### Research doc

- Complete for the OWI question but lacks a prioritized "what to try first" recommendation section
- NekoImageGallery analysis is in conversation only, NOT documented in the research doc

---

## c) NOT STARTED

- **Deploy:** Changes are committed but `nix run .#deploy` was never run
- **Post-deploy verification:** No smoke test that the new image engines actually return results
- **NekoImageGallery module:** Fully scoped but no `modules/nixos/services/neko-image-gallery.nix` was created
- **TODO_LIST.md / ROADMAP.md entries:** Research findings not converted to actionable tasks
- **AGENTS.md update:** New SearXNG image engines not documented in the gotchas/conventions

---

## d) TOTALLY FUCKED UP

### Nothing critically broken, but:

1. **TinEye category misunderstanding:** I implied TinEye would improve image search results. TinEye's `engine_type` is `online_url_search` and its category is `general`, NOT `images`. It won't appear in the SearXNG Images tab — it's a reverse image lookup (upload/find by URL) that appears in general search. The user may have expected it in the Images tab.

2. **Did NOT run `nix flake check` immediately after editing** — only ran it much later when writing this status report. If the edit had broken evaluation, I would not have caught it until now. (It passed, but that's luck of correct syntax, not verification discipline.)

3. **Did NOT verify engine names before adding them** — I added engine names from memory/research without checking them against SearXNG's actual `settings.yml`. All 4 happened to be correct (verified in this report), but I should have verified BEFORE the edit, not after.

---

## e) WHAT WE SHOULD IMPROVE

### SearXNG image engines we're still missing

There are **25+ more image engines** in SearXNG we haven't enabled:

| Engine | Why it matters |
|--------|---------------|
| `brave.images` | Independent index, good quality |
| `flickr` | Creative Commons photos, large photography corpus |
| `flickr_api` | Flickr with API (better quality, needs API key) |
| `openverse` | CC-licensed images aggregated from many sources |
| `unsplash` | High-quality free stock photography |
| `wallhaven` | Wallpaper-focused, high quality |
| `wikicommons.images` | Free/copyright-free images |
| `pixabay images` | Free stock photos |
| `500px` | Professional photography |
| `artstation` | Digital art, concept art, game art |
| `deviantart` | Digital art community |
| `startpage images` | Google Images proxy (privacy) |
| `swisscows images` | Swiss privacy search engine |
| `naver images` | Korean content (useful for K-pop, K-drama) |
| `sogou images` | Chinese content |
| `google cse images` | Custom search engine images |
| `public domain image archive` | Public domain images |

### Process improvements

1. **Always verify engine/option names against upstream docs BEFORE editing** — not after
2. **Run `nix flake check` immediately after every code edit** — not deferred
3. **Run `nix fmt` after every `.nix` edit** — alejandra formatting matters for consistency
4. **Document the TinEye category distinction** — it's a reverse image search in general category, not an images-tab engine
5. **Add a "Recommendations" section to research docs** — prioritize findings into "try this first, this second"
6. **Convert research findings into TODO_LIST.md entries** — research without action items is library work, not engineering

### Research doc improvements

- Add NekoImageGallery analysis to the research doc (currently only in conversation)
- Add a "Decision Matrix" section: when to use Immich smart search vs NekoImageGallery vs clip-retrieval vs SearXNG metasearch
- Add hardware feasibility analysis for CLIP on Strix Halo (ROCm/Vulkan exploration — I assumed CPU-only without checking)

---

## f) Up to 50 Things We Should Get Done Next

#### Immediate (P0 — unverified changes need deploy)
1. Deploy the SearXNG image engine changes (`nix run .#deploy`)
2. Run post-deploy smoke test verifying image search returns results from all new engines
3. Run `nix fmt` on `searxng.nix`
4. Verify TinEye appears in the right SearXNG category (general, not images)

#### SearXNG improvements (P1)
5. Enable `brave.images` engine
6. Enable `flickr` engine (or `flickr_api` with a sops-managed API key)
7. Enable `openverse` engine
8. Enable `unsplash` engine
9. Enable `wallhaven` engine
10. Enable `wikicommons.images` engine
11. Enable `pixabay images` engine
12. Enable `artstation` engine (if digital art is relevant)
13. Enable `startpage images` engine
14. Enable `swisscows images` engine
15. Consider `naver images` / `sogou images` for Asian content coverage
16. Consider `google cse images` with a custom search engine ID
17. Add Gatus health check verifying image search returns results
18. Update Homepage tile description for SearXNG to mention expanded image search
19. Test SearXNG image search latency with 8+ image engines (may need timeout tuning)

#### Documentation (P1)
20. Add NekoImageGallery analysis to the research doc
21. Add "Decision Matrix" section to research doc (Immich vs NekoImageGallery vs clip-retrieval vs metasearch)
22. Update AGENTS.md SearXNG section with new image engines list
23. Create TODO_LIST.md entries for interesting research findings
24. Document the TinEye category distinction in AGENTS.md gotchas
25. Add a "Recommendations" section to the OWI research doc

#### Semantic search exploration (P2)
26. Explore whether SearXNG `engine_type = "offline"` can query a local vector DB
27. Prototype a SearXNG offline engine that queries Qdrant for semantic image search
28. Test CLIP inference on Strix Halo iGPU (ROCm Direct GEMM or Vulkan backend)
29. Evaluate Qwen3-Embedding (already used in QMD) for text embeddings over OWI Parquet data
30. Evaluate OpenSearch kNN as a unified vector store for both text and image search
31. Explore owilix CLI for pulling OWI data shards filtered by language/domain
32. Build a small-scale OWI embedding pipeline (1 day of crawl data → embeddings → vector DB)

#### NekoImageGallery (P2 — only if a use case is identified)
33. Identify the image corpus to index (stock images? memes? web-crawled?)
34. Create `lib/ports.nix` entries for Qdrant + NekoImageGallery
35. Create `modules/nixos/services/neko-image-gallery.nix` with Docker containers
36. Configure Qdrant with persistent storage on `/data`
37. Add Caddy `protectedVHost` for the gallery
38. Add Gatus health check
39. Add Homepage tile
40. Add sops secrets for admin token + access token
41. Test CLIP indexing speed on CPU (images/second)
42. Write SearXNG offline engine plugin that queries NekoImageGallery's `/search/text` API

#### clip-retrieval ecosystem (P3 — web-scale, ambitious)
43. Evaluate img2dataset for downloading images from OWI/Common Crawl URLs
44. Benchmark autofaiss index building on evo-x2 (200M vectors, 3h/15GB RAM claim)
45. Test clip-retrieval's `clip back` Flask API as a SearXNG backend
46. Evaluate LAION-5B pre-built indices (can we download and serve them locally?)
47. Explore distributed vector DB (Qdrant cluster or Milvus) on evo-x2
48. Research whether Ollama can serve CLIP models for embedding generation
49. Build hybrid search pipeline: SearXNG keyword results + CLIP re-ranking
50. Consider contributing a SearXNG vector search engine plugin upstream (filling the documented gap)

---

## g) Questions (3)

### Q1: What image corpus would NekoImageGallery actually index?

I cannot determine this. You already have Immich with CLIP smart search for personal photos (machine-learning enabled). NekoImageGallery would be redundant for that use case. Is there a separate image collection (downloaded stock images, memes, screenshots, web-crawled images) you want to make searchable? Without knowing the corpus, building the module is premature.

### Q2: Should I deploy the SearXNG changes now, or batch them with more engine additions?

The 4 new engines (bing images, duckduckgo images, qwant images, tineye) are committed but not deployed. I identified 15+ more image engines that could be added. Do you want me to add more engines first and deploy once, or deploy the current 4 now and iterate?

### Q3: Is the goal better web image search, or building a local semantic image search system?

These are fundamentally different paths. "Better web image search" = enable more SearXNG metasearch engines (quick, free, done in config). "Local semantic image search" = build a CLIP + vector DB pipeline (NekoImageGallery or clip-retrieval, real engineering project, needs a corpus to index). The research covered both, but the implementation paths diverge significantly.
