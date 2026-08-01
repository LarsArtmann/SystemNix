# Open Web Index + SearXNG Semantic Search Research

**Date:** 2026-08-01
**Question:** Has anyone run an AI embeddings model over the Open Web Index (OWI) data (~35 TB snapshot at openwebindex.eu/owler/our_data) to enable semantic search via SearXNG?

---

## TL;DR

**No one has embedded the full OWI dataset.** The OWI data model has a slot for embeddings (the `owie` resource type), but it is explicitly marked "not yet available." SearXNG integration exists only as a GitHub discussion issue ([searxng/searxng#5327](https://github.com/searxng/searxng/issues/5327), opened Oct 2025 by core maintainer return42) with zero code. Several EU-funded research projects built embeddings over small OWI subsets, but none expose a search API SearXNG could consume.

---

## What Is the Open Web Index?

An open-sourced web search index created by the **OpenWebSearch.eu** consortium (14 European research institutions including CERN, University of Passau, Radboud University), funded by the EU Horizon programme. Launched September 2022. Designed as a nonprofit, federated alternative to Google/Bing indexes for European "digital sovereignty."

- **Scale:** ~3 TB/day of new crawl data (CERN: ~9M URLs/hour). 1 PB pilot released June 2025, targeting 5-10 PB.
- **Status:** Beta (as of 2025).
- **The "35 TB" figure** from the dashboard is likely a specific collection/snapshot for a date range/resource type, not the full dataset.

---

## Data Formats

| Format | Extension | Contains |
|--------|-----------|----------|
| **CIFF** (Common Index File Format) | `.ciff.gz` | The searchable inverted index (keyword-based) |
| **Apache Parquet** | `.parquet` | Rich metadata per page: title, cleaned text, URL, language, MIME, outgoing links, GenAI consent flag (`ows_genai`), etc. |
| **WARC** (Web ARChive) | `.warc.gz` | Raw crawl data |
| **JSON** | `.json` | Dataset changelogs, schema metadata |
| **Embeddings** (planned) | `emb` | Vector embeddings - **not yet available** |

Folder structure: `year={YYYY}/month={MM}/day={DD}/language={LANG}/index.ciff.gz` + `metadata-{num}.parquet`

---

## Embeddings Status in OWI

The OWI data model explicitly defines a resource type called `owie` ("contains vector-embeddings (**not yet available**)"). The `subResourceType` field includes `emb` ("contains embeddings") and `<algorithm>` ("contains the algorithm"), but these are not yet populated.

CERN names embeddings as a future capability: *"The OWI facilitates AI capabilities, allowing web search data to be used for training large language models (LLMs), generating embeddings and powering chatbots."*

The parquet metadata includes an `ows_genai` field (`True`/`False`) indicating whether each page's content is permitted for Generative AI use - the consent/legal groundwork is built in.

**Bottom line:** The plumbing for embeddings exists in the schema, but no embeddings have been generated or published.

---

## EU-Funded Projects That Built Embeddings/Semantic Search Over OWI Subsets

These were funded through OpenWebSearch.eu open calls. None expose a public search API.

### VERITAS (DEXAI, Czechia) - Embeddings + RAG

The most direct example of embeddings over OWI data:
- Filtered **30 days of OWI crawl data**, extracted news content
- **Indexed using a semantic embedding model** - converts text passages into numerical vectors capturing meaning
- Queries vectorized and matched against the index via similarity search
- Results passed to **LLaMA 3.1** for grounded, source-cited fact-checking responses
- Delivered as a **Chrome browser extension** for real-time fact-checking
- Technical report: [zenodo.org/records/17588890](https://zenodo.org/records/17588890)

### TILDE (Know Center Research, Austria) - Hybrid Semantic + Entity Search

- Extracted medical entities from **~200,000 health-related websites** in the OWI
- Built a **hybrid retrieval engine combining entity-based retrieval with semantic similarity search**
- Used the UMLS clinical ontology to standardize medical concepts into a knowledge graph
- Added fairness-aware re-ranking pipeline with chain-of-thought reasoning
- Technical report: [zenodo.org/records/17542369](https://zenodo.org/records/17542369)

### AKASE (University of Groningen) - Argument Knowledge Graph

- Processed **over 105 million web index documents** from the OWI
- Built an argumentation knowledge graph identifying claims, premises, rhetorical fallacies, and argument relationships
- Includes a search engine that **reorders results by argument quality**

### FUN (University of Pisa & Glasgow) - Neural Crawling

- Developed **four neural crawling strategies** using language models to assess semantic quality of pages (vs. traditional PageRank)
- Tested on **87 million pages** from ClueWeb22-B
- Found neural strategies outperformed PageRank for natural language queries

---

## SearXNG Integration Status

**GitHub Issue [searxng/searxng#5327](https://github.com/searxng/searxng/issues/5327):** "Make use of 'The Open Web Index'" - opened October 15, 2025 by **return42** (a SearXNG core maintainer). Labeled as both "Open WEB Index" and "engine request." The issue explicitly invites discussion: *"Please discuss suggestions here on how 'The Open Web Index' could be made usable in SearXNG."*

**No code, PRs, or implementation exist.** No SearXNG engine plugin for OWI has been built.

The reference search engine built for OWI is **MOSAIC** (Modular Search Application based on Index Fraction), which uses Lucene-based inverted index search, not vector/semantic search.

---

## OWI Tooling Ecosystem

| Tool | Purpose |
|------|---------|
| **owilix** | CLI tool ("git for OWI") to pull, slice, and query OWI data shards via DuckDB SQL |
| **OWI Book Tutorials 6 & 7** | Show how to push OWI data into **OpenSearch** (which natively supports kNN vector search) |
| **MOSAIC** | Prototype search engine for OWI data with REST API and web interface |
| **Resilipipe** | WARC processing pipeline for the OWI |
| **TIRA/TIREx** | Evaluation platform for search components on OWI data |
| **Tutorial 14** | LLM fine-tuning using OWI data on the LUMI supercomputer |
| **WOWS-Eval** | Annual shared task for RAG/retrieval experiments over OWI data ([github.com/OpenWebSearch/wows-code](https://github.com/OpenWebSearch/wows-code)) |

---

## Why Embedding 35 TB Is Non-Trivial

- At ~1 KB cleaned text/page and a 768-dim float32 embedding (~3 KB), embedding 35 TB of text produces ~105 TB of vectors.
- At int8 quantization, ~26 TB of vector data.
- Requires a **distributed vector database** (Milvus, Qdrant cluster, or Vespa), not a single-node setup.
- OWI produces ~3 TB/day of NEW data, so the index must be continuously updated.
- The full dataset is now at **petabyte scale** (1 PB pilot, targeting 5-10 PB).

---

## Path to OWI + SearXNG Semantic Search (If We Wanted to Build It)

This would be a real engineering project, not a weekend hack. The most practical architecture:

1. **Data access:** Use `owilix` CLI to pull specific shards - filter by date/language/domain. Data arrives as Parquet (clean text + metadata) + CIFF (inverted index).
2. **Embedding:** Batch-embed the Parquet `content` column using an embedding model (e.g., Qwen3-Embedding, which we already use in QMD). Filter to `ows_genai = true` pages only.
3. **Vector store:** Push into **OpenSearch** with kNN vector search (OWI Book tutorials 6 & 7 show this). This is the most battle-tested path.
4. **SearXNG engine:** Write a custom SearXNG engine plugin that queries the OpenSearch kNN endpoint and merges semantic results with the existing keyword-based engine results.
5. **Hybrid search:** Combine OWI CIFF keyword results (via MOSAIC or direct Lucene) with the kNN vector results for a hybrid retrieval pipeline.

### Hardware Considerations for evo-x2

- 128 GB RAM, but only ~94 GB visible (34 GB BIOS VRAM carveout), with 51+ GB consumed by GPUActive
- A full 35 TB embedding index would need to live on `/data` (BTRFS) with a distributed vector DB
- Realistically, we'd embed only a filtered subset (e.g., English tech docs, or specific domains relevant to our use)
- Continuous embedding of new crawl data would require a scheduled pipeline

---

## Related GitHub Projects: Text / Semantic Search Over Web Crawl Data

No project currently provides a **native SearXNG engine plugin** that performs vector/semantic search over a locally indexed web corpus. However, several projects build the underlying pipeline (crawl → embed → vector DB → search API). None target OWI data specifically; they use Common Crawl, WARC files, or their own crawls.

### Most relevant for SearXNG integration

| Project | Stars | What it does |
|---------|-------|-------------|
| [harvard-lil/warc-gpt](https://github.com/harvard-lil/warc-gpt) | 275 | RAG pipeline for WARC files: text extraction → embeddings → ChromaDB → REST API (`/api/search` for vector search). Works with Ollama for local inference. Most mature WARC-to-vector project. |
| [NikhilJ-05/Web-Scrapper-for-AI-agents](https://github.com/NikhilJ-05/Web-Scrapper-for-AI-agents) (Orion) | 0 | **Closest to "SearXNG + semantic search."** Uses SearXNG as live backend, async-scrapes results, builds a parallel Qdrant vector KB with BGE embeddings (1024-dim). Two-phase: returns live results immediately, ingests to KB in background. `<100ms` semantic search on indexed data. |
| [yacy/yacy_expert](https://github.com/yacy/yacy_expert) | 694 | Bridges YaCy's decentralized web crawl index with FAISS vector RAG. BERT embeddings + llama.cpp. YaCy is already a SearXNG engine backend, so the FAISS search server (using YaCy's API format) could theoretically be exposed as a semantic YaCy endpoint. |
| [MultiX0/froxy](https://github.com/MultiX0/froxy) | 21 | Full semantic search engine: Go crawler → FastEmbed → Qdrant → Next.js UI. Includes "Froxy Apex" (Perplexity-style AI answers via Llama 3.1 via Groq). |

### Web crawl → vector DB pipelines (no SearXNG link)

| Project | Stars | What it does |
|---------|-------|-------------|
| [commoncrawl/cc-vec](https://github.com/commoncrawl/cc-vec) | 6 | **Official** Common Crawl tool for indexing into vector stores. CLI + Python lib + MCP server. Supports Ollama/nomic-embed-text for local embeddings. Uses AWS Athena to query CC metadata index. |
| [m-spangenberg/demo-semantic-crawl](https://github.com/m-spangenberg/demo-semantic-crawl) | 0 | 14-step pipeline: Common Crawl → chunk → Sentence Transformers (all-MiniLM-L6-v2) → BERTopic → NER (SpaCy) → Qdrant. Most complete NLP-enriched crawl pipeline. |

### SearXNG-adjacent (not true vector search)

| Project | Stars | What it does |
|---------|-------|-------------|
| [jcrabapple/searxng-ai](https://github.com/jcrabapple/searxng-ai) | 2 | SearXNG fork adding AI summaries from search results (OpenAI-compatible APIs including Ollama). **No embedding-based retrieval** — just LLM summaries on top of keyword results. |

### Other open source web search engines (keyword, not semantic)

| Project | Stars | Notes |
|---------|-------|-------|
| [StractOrg/stract](https://github.com/StractOrg/stract) | 2.4k | Full Rust web search engine on Tantivy (inverted index). **ARCHIVED April 2026.** Used Common Crawl. Funded by NLnet/NGI Zero. |
| [mwmbl/mwmbl](https://github.com/mwmbl/mwmbl) | 1.8k | Non-profit community-crawled search engine. Novel hash-map index. Keyword-based. |

### Gap analysis

The gap is clear: **no project provides a native SearXNG engine plugin that does vector/semantic search over a locally-indexed web corpus.** The closest patterns are:
1. **Orion** — uses SearXNG as its live search source, then builds a parallel vector KB
2. **searxng-ai** — adds AI summaries to SearXNG but lacks embedding-based retrieval
3. **YaCy Expert** — uses YaCy's API format (which SearXNG supports), but requires running YaCy

A custom SearXNG engine plugin that queries a Qdrant/OpenSearch kNN vector store populated from OWI/Common Crawl/WARC data would be genuinely novel.

---

## Related GitHub Projects: Semantic Image Search Backends

SearXNG has **no CLIP/vector image engine**. Its image search is pure metasearch (Google Images, Bing, TinEye API). A [discussion #3327](https://github.com/searxng/searxng/discussions/3327) asked about reverse image search with no responses. However, SearXNG supports `engine_type = "offline"` engines that query local databases, and image results support `template="images.html"` with `img_src` + `thumbnail` fields, so writing a custom engine that queries a CLIP vector backend is architecturally supported.

### Tier 1: Production-grade CLIP image search

| Project | Stars | What it does |
|---------|-------|-------------|
| [rom1504/clip-retrieval](https://github.com/rom1504/clip-retrieval) | 2.8k | **The reference project.** Full pipeline: CLIP embeddings (1500 img/s on a 3080) → FAISS index → Flask KNN backend (50ms latency, ~20 q/s) → web UI. Powers [LAION-5B search](https://rom1504.github.io/clip-retrieval/) (5.85B image-text pairs). Includes NSFW filtering, aesthetic scoring, near-duplicate dedup. |
| [rom1504/img2dataset](https://github.com/rom1504/img2dataset) | 2.5k+ | Companion downloader: 100M image URLs → structured dataset in 20h on one machine. Takes URLs from Common Crawl, LAION, or any URL list. |
| [criteo/autofaiss](https://github.com/criteo/autofaiss) | 1k+ | Auto-builds FAISS KNN indices: 200M vectors (1 TB) in 3h, 15 GB RAM, 10ms latency. Supports Spark for distributed index building. |

### Tier 2: Self-hosted semantic image search engines

| Project | Stars | What it does |
|---------|-------|-------------|
| [hv0905/NekoImageGallery](https://github.com/hv0905/NekoImageGallery) | 193 | CLIP (ViT-L/14, 768-dim) + Qdrant + OCR (PaddleOCR + BERT). Docker, GPU/CPU/ARM variants. Closest to a self-hosted "Google Photos" semantic search. Has admin API for image upload/indexing and local directory indexing. |
| [flaribbit/imgfind](https://github.com/flaribbit/imgfind) | 153 | **Rust + candle + CLIP.** Local image search by text description. Interesting for performance-oriented implementations. |
| [kingyiusuen/clip-image-search](https://github.com/kingyiusuen/clip-image-search) | 268 | CLIP + Elasticsearch k-NN + AWS Lambda + Streamlit frontend. Cloud reference architecture, indexes 25K Unsplash images. |
| [soulteary/simple-image-search-engine](https://github.com/soulteary/simple-image-search-engine) | 155 | CLIP + Redis Vector Search. 3-step tutorial for image-to-image and text-to-image search. Docker-based. |
| [stg7/clipse](https://github.com/stg7/clipse) | 6 | Minimalist academic CLIP search engine. Has benchmarking paper ([arXiv:2504.17643](https://arxiv.org/abs/2504.17643)). |

### Vector DB / infrastructure components

| Component | Repository | Notes |
|-----------|-----------|-------|
| **Qdrant** | [qdrant/qdrant](https://github.com/qdrant/qdrant) | Vector DB with HNSW indexing — used by most self-hosted projects above |
| **Milvus** | [milvus-io/milvus](https://github.com/milvus-io/milvus) | Cloud-native vector DB — has [text-to-image search tutorial](https://milvus.io/docs/text_image_search.md) |
| **OpenSearch** | [opensearch.org](https://opensearch.org/) | Has [text_image_embedding processor](https://docs.opensearch.org/latest/ingest-pipelines/processors/text-image-embedding/) for multimodal neural search |
| **txtai** | [neuml/txtai](https://github.com/neuml/txtai) | All-in-one embeddings framework with [image similarity search](https://github.com/neuml/txtai) using CLIP |
| **Vald** | [vdaas/vald](https://github.com/vdaas/vald) | 1.7k stars. Kubernetes-native distributed vector search engine |
| **FAISS** | (via autofaiss) | The underlying ANN library used by clip-retrieval for billion-scale search |

### Build path for semantic image search (evo-x2)

The `clip-retrieval` ecosystem is the most production-proven path:

1. **img2dataset** to download images from OWI/Common Crawl URLs → `/data`
2. **clip inference** for CLIP embeddings (Strix Halo iGPU or CPU; 1500 img/s on a consumer GPU)
3. **autofaiss** to build the FAISS index (200M vectors in 3h, 15 GB RAM)
4. **clip back** Flask KNN API service (50ms latency, ~20 q/s)
5. Custom SearXNG `offline` engine querying the clip back API, returning `template="images.html"` results

For a smaller-scale / personal setup, [NekoImageGallery](https://github.com/hv0905/NekoImageGallery) (CLIP + Qdrant + Docker) is the simplest turnkey option.

---

## Sources

- [openwebindex.eu/owler/our_data](https://openwebindex.eu/owler/our_data) - Statistics dashboard (JS-rendered)
- [OWI Book - Data Access](https://openwebsearcheu-public.pages.it4i.eu/ows-the-book/content/dnt/owi-access.html) - Data structure, formats, resource types, parquet schema
- [OWI Book - Technology Overview](https://openwebsearcheu-public.pages.it4i.eu/ows-the-book/content/dnt/overview.html) - Data products, AI vision
- [OWI Book - Tutorials](https://openwebindex.eu/book/content/howto/intro.html) - Including OpenSearch push (6 & 7), MOSAIC, LLM fine-tuning (14)
- [Wikipedia - Open Web Index](https://en.wikipedia.org/wiki/Open_Web_Index) - History, petabyte milestones
- [CERN announcement](https://home.cern/european-project-make-web-search-more-open-and-ethical/) - ~3 TB/day crawl rate, 1 PB pilot, embeddings capability
- [SearXNG Issue #5327](https://github.com/searxng/searxng/issues/5327) - OWI integration discussion (Oct 2025)
- [OpenWebSearch GitHub org](https://github.com/OpenWebSearch) - 8 repos including wows-code
- [VERITAS report](https://zenodo.org/records/17588890) - Embeddings + RAG over OWI news
- [TILDE report](https://zenodo.org/records/17542369) - Hybrid semantic search over OWI medical pages
- [OpenWebSearch.EU project results](https://opensearchfoundation.org/ows-project-results/) - All partner projects

### Text / semantic search projects

- [harvard-lil/warc-gpt](https://github.com/harvard-lil/warc-gpt) - WARC → embeddings → ChromaDB RAG pipeline
- [NikhilJ-05/Web-Scrapper-for-AI-agents](https://github.com/NikhilJ-05/Web-Scrapper-for-AI-agents) - SearXNG + Qdrant vector KB (Orion)
- [yacy/yacy_expert](https://github.com/yacy/yacy_expert) - YaCy + FAISS vector RAG
- [MultiX0/froxy](https://github.com/MultiX0/froxy) - Full semantic search engine (Go + Qdrant)
- [commoncrawl/cc-vec](https://github.com/commoncrawl/cc-vec) - Official Common Crawl vector indexing tool
- [m-spangenberg/demo-semantic-crawl](https://github.com/m-spangenberg/demo-semantic-crawl) - 14-step CC → Qdrant pipeline
- [jcrabapple/searxng-ai](https://github.com/jcrabapple/searxng-ai) - SearXNG fork with AI summaries
- [StractOrg/stract](https://github.com/StractOrg/stract) - Rust web search engine (archived)
- [mwmbl/mwmbl](https://github.com/mwmbl/mwmbl) - Non-profit community search engine

### Image search projects

- [rom1504/clip-retrieval](https://github.com/rom1504/clip-retrieval) - Production CLIP search (powers LAION-5B)
- [rom1504/img2dataset](https://github.com/rom1504/img2dataset) - Mass image downloader
- [criteo/autofaiss](https://github.com/criteo/autofaiss) - Auto FAISS index builder
- [hv0905/NekoImageGallery](https://github.com/hv0905/NekoImageGallery) - CLIP + Qdrant self-hosted image search
- [flaribbit/imgfind](https://github.com/flaribbit/imgfind) - Rust + candle + CLIP
- [kingyiusuen/clip-image-search](https://github.com/kingyiusuen/clip-image-search) - CLIP + Elasticsearch k-NN
- [soulteary/simple-image-search-engine](https://github.com/soulteary/simple-image-search-engine) - CLIP + Redis Vector
- [stg7/clipse](https://github.com/stg7/clipse) - Academic CLIP search ([arXiv:2504.17643](https://arxiv.org/abs/2504.17643))
- [LAION-5B](https://laion.ai/blog/laion-5b/) - 5.85B CLIP-filtered image-text pairs from Common Crawl
- [clip-retrieval live demo](https://rom1504.github.io/clip-retrieval/) - Billion-scale semantic image search
- [SearXNG discussion #3327](https://github.com/searxng/searxng/discussions/3327) - Reverse image search discussion (unanswered)
- [Milvus text-to-image tutorial](https://milvus.io/docs/text_image_search.md)
- [OpenSearch text_image_embedding processor](https://docs.opensearch.org/latest/ingest-pipelines/processors/text-image-embedding/)
