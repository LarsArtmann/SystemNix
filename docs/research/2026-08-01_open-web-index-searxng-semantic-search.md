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
