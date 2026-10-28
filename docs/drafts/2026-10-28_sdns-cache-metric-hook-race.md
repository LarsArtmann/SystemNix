# Draft — semihalev/sdns issue — data race on the cache metric hooks (production-reachable)

**Title:** `middleware/cache: SetCacheSizeFuncs writes six package globals that the Prometheus Gather goroutine reads unsynchronized (data race, reachable on blocklist reload)`

**Verified against:** sdns `v1.8.3` (the version dnsblockd pins) **and** `v1.9.1` (current upstream tag at the time of writing) — both still carry the unsynchronized globals, so this is not already fixed on `main`.

**Status:** drafted, NOT filed. Filing against a third-party project is the repo owner's call.

---

> [!NOTE]
> This filing was drafted by DeepSeek-V4.1-Flash via Crush from an AI-run investigation, not at my request.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

TL;DR: `middleware/cache` keeps six mutable package-level variables (`metricsInstance`, `positiveCacheLen`, `negativeCacheLen`, `failureCacheLen`, `nxDomainCutLen`, `denialProofLen`) and exposes `SetCacheSizeFuncs` / `SetMetricsInstance` to write them with no synchronization. `cacheHitRate` is a registered `GaugeFunc`, so every Prometheus scrape calls `calculateHitRate` → `UpdateCacheSizeMetrics`, which reads those same variables from the scrape goroutine. A reload that constructs a new cache therefore races the scraper. A `sync.Mutex` or an `atomic.Pointer` around the hook set fixes it.

## Problem

### The write side

```go
// middleware/cache/prometheus.go
var (
	metricsInstance  *CacheMetrics
	positiveCacheLen func() int
	negativeCacheLen func() int
	failureCacheLen  func() int
	nxDomainCutLen   func() int
	denialProofLen   func() int
)

func SetCacheSizeFuncs(positive, negative func() int, extras ...func() int) {
	positiveCacheLen = positive
	negativeCacheLen = negative
	failureCacheLen = nil
	nxDomainCutLen = nil
	denialProofLen = nil
	// … then conditionally reassigns the three optional ones
}
```

### The read side

```go
cacheHitRate = prometheus.NewGaugeFunc(prometheus.GaugeOpts{
	Name: "dns_cache_hit_rate",
}, calculateHitRate)

func calculateHitRate() float64 {
	UpdateCacheSizeMetrics()   // reads all six globals
	if metricsInstance == nil { return 0 }
	// …
}
```

`GaugeFunc` is invoked inside `prometheus.Registry.Gather()` — i.e. on whatever goroutine the exporter runs on, not on the goroutine that constructed the cache.

### Why it is reachable in production, not only in tests

Any consumer that rebuilds its cache while serving metrics races this. Our DNS resolver rebuilds on every blocklist reload (a periodic timer, hourly in our configuration) and on every manual cache flush:

```go
func (h *Handler) newCache() *cache.Cache {
	cacheNewMu.Lock()
	responseCache := cache.New(h.sdnsCfg)   // -> SetCacheSizeFuncs / SetMetricsInstance
	cacheNewMu.Unlock()
	// …
}
```

We added that mutex on OUR side because the comment in `cache.New`'s call path says the hooks are written "without any internal synchronization". But a consumer-side mutex can only serialize writers: the reader is the Prometheus Gather goroutine, which no consumer can lock. So the mitigation is necessarily incomplete until the hook set is synchronized inside this package.

### Observed

Under `go test -race` on a heavily loaded machine (load average ~100, so extensive scheduling interleaving), 55 tests in one suite run failed in a single wave, with the race detector reporting a write in `SetCacheSizeFuncs` from `cache.New` (called during handler construction) against a read in `UpdateCacheSizeMetrics` via the collector's `Gather`. We could not reproduce it on a quiet machine — the failure is timing-dependent — which is exactly why the fix belongs here rather than behind a test-only mitigation.

### Consequence beyond the report

A scrape that interleaves with `SetCacheSizeFuncs` can observe the four-then-nil sequence in the middle of the reset, which in the worst interleaving means calling a nil function pointer in `UpdateCacheSizeMetrics`' `if failureCacheLen != nil` branch (the nil check and the call are not atomic with respect to the write). A panicking metric collector takes down the exporter goroutine, and in consumers that serve the scrape endpoint in-process it can take down the scrape handler.

## Suggested fix

The minimal change that makes the whole set consistent is to publish it atomically as one immutable value:

```go
type sizeFuncs struct {
	metrics *CacheMetrics
	positive, negative, failure, nxDomainCut, denialProof func() int
}

var current atomic.Pointer[sizeFuncs]

func SetCacheSizeFuncs(positive, negative func() int, extras ...func() int) {
	f := &sizeFuncs{positive: positive, negative: negative}
	// …fill extras…
	current.Store(f)
}

func calculateHitRate() float64 {
	f := current.Load()
	if f == nil { return 0 }
	UpdateCacheSizeMetrics(f)
	// …
}
```

A `sync.RWMutex` around the existing variables would also work; the atomic pointer additionally gives readers a single consistent snapshot instead of six independent loads.

We are happy to send a PR with the atomic-pointer version plus a `-race` test that constructs a cache concurrently with scraping `Gather()`, if you would prefer that over filing this alone.
