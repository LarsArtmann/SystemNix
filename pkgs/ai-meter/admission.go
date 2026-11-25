package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand/v2"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Admission control keeps one upstream inside the request rate it tolerates.
//
// Some providers publish no concurrency number. z.ai's GLM Coding Plan
// "dynamically adjusts these limits based on resource availability"
// (docs.z.ai/devpack/usage-policy) and answers what exceeds them with HTTP
// 429. A client that sends everything at once gets a share of its calls
// rejected, and a client that retries on a short fixed schedule keeps
// meeting the same rejection. The gate inverts that: a call waits in the
// proxy until the upstream has room, a rejection the proxy can retry never
// reaches the client, and the allowance follows the upstream as it moves.
const (
	defaultMinConcurrency   = 1
	defaultMaxWait          = 30 * time.Second
	defaultMaxRetries       = 6
	defaultGrowAfter        = 30 * time.Second
	maxRetriesForBackoff    = 5 // a later rejection waits the ceiling, not longer
	maxProbeInterval        = 10 * time.Minute
	rejectionCoalesceWindow = time.Second

	retryBase            = 500 * time.Millisecond
	retryCeiling         = 8 * time.Second
	maxHonoredRetryAfter = 10 * time.Second

	quotaResetGuard    = 2 * time.Second
	maxQuotaResetAhead = 8 * 24 * time.Hour
)

// AdmissionSettings is the wire shape of one upstream's admission control,
// as the host renders it into the config. Durations are whole seconds so
// the JSON stays free of duration-string parsing; config turns them into an
// AdmissionConfig.
type AdmissionSettings struct {
	// MaxConcurrency is the largest number of calls the proxy keeps in
	// flight at the upstream, and where the allowance starts.
	MaxConcurrency int `json:"max_concurrency"`
	// MinConcurrency is where the allowance stops shrinking, however many
	// rejections come back. 0 means 1.
	MinConcurrency int `json:"min_concurrency"`
	// MaxWaitSeconds bounds how long one call may wait in the proxy, across
	// its queueing and its retries, before the proxy gives up on it. 0
	// means 30.
	MaxWaitSeconds int `json:"max_wait_seconds"`
	// MaxRetries is how many rate-limit rejections of one call the proxy
	// retries itself before it lets the next one through to the client. 0
	// means 6.
	MaxRetries int `json:"max_retries"`
	// GrowAfterSeconds is the quiet time after which the allowance grows by
	// one, up to MaxConcurrency. 0 means 30.
	GrowAfterSeconds int `json:"grow_after_seconds"`
	// RetryableCodes are the business codes of 429 answers that mean "too
	// much at once": the proxy counts them against the allowance and
	// retries the call.
	RetryableCodes []string `json:"retryable_codes"`
	// QuotaCodes are the business codes of 429 answers that mean "a usage
	// window is spent": nothing passes before the reset time the answer
	// names, so the proxy stops sending until then.
	QuotaCodes []string `json:"quota_codes"`
	// QuotaResetUTCOffsetHours is the zone of the reset times in those
	// answers, for a provider that prints them without one.
	QuotaResetUTCOffsetHours int `json:"quota_reset_utc_offset_hours"`
}

// AdmissionConfig is AdmissionSettings validated and in the units the proxy
// computes with.
type AdmissionConfig struct {
	MaxConcurrency      int
	MinConcurrency      int
	MaxWait             time.Duration
	MaxRetries          int
	GrowAfter           time.Duration
	RetryableCodes      map[string]bool
	QuotaCodes          map[string]bool
	QuotaResetUTCOffset time.Duration
}

// config validates the settings and fills in the defaults of those left at
// zero.
func (s AdmissionSettings) config() (AdmissionConfig, error) {
	cfg := AdmissionConfig{
		MaxConcurrency:      s.MaxConcurrency,
		MinConcurrency:      s.MinConcurrency,
		MaxWait:             seconds(s.MaxWaitSeconds, defaultMaxWait),
		MaxRetries:          s.MaxRetries,
		GrowAfter:           seconds(s.GrowAfterSeconds, defaultGrowAfter),
		RetryableCodes:      codeSet(s.RetryableCodes),
		QuotaCodes:          codeSet(s.QuotaCodes),
		QuotaResetUTCOffset: time.Duration(s.QuotaResetUTCOffsetHours) * time.Hour,
	}
	if s.MaxConcurrency < 1 {
		return cfg, fmt.Errorf("max_concurrency must be at least 1")
	}
	if s.MinConcurrency < 0 || s.MinConcurrency > s.MaxConcurrency {
		return cfg, fmt.Errorf("min_concurrency (%d) must be between 0 and max_concurrency (%d)", s.MinConcurrency, s.MaxConcurrency)
	}
	if cfg.MinConcurrency == 0 {
		cfg.MinConcurrency = defaultMinConcurrency
	}
	if s.MaxWaitSeconds < 0 || s.GrowAfterSeconds < 0 {
		return cfg, fmt.Errorf("max_wait_seconds and grow_after_seconds must not be negative")
	}
	if s.MaxRetries < 0 {
		return cfg, fmt.Errorf("max_retries must not be negative")
	}
	if cfg.MaxRetries == 0 {
		cfg.MaxRetries = defaultMaxRetries
	}
	if s.QuotaResetUTCOffsetHours < -24 || s.QuotaResetUTCOffsetHours > 24 {
		return cfg, fmt.Errorf("quota_reset_utc_offset_hours (%d) must be within a day", s.QuotaResetUTCOffsetHours)
	}
	if len(cfg.RetryableCodes) == 0 {
		return cfg, fmt.Errorf("retryable_codes is required: a gate without it only queues, and every 429 would still pass through")
	}
	return cfg, nil
}

func seconds(value int, fallback time.Duration) time.Duration {
	if value == 0 {
		return fallback
	}
	return time.Duration(value) * time.Second
}

func codeSet(codes []string) map[string]bool {
	set := make(map[string]bool, len(codes))
	for _, code := range codes {
		set[strings.TrimSpace(code)] = true
	}
	return set
}

// How a call left a gated upstream. The ledger stores every value but
// outcomeAdmitted, so a line without "admission" is a call the upstream
// answered on its first attempt.
const (
	outcomeAdmitted  = "admitted"
	outcomeAbsorbed  = "absorbed"
	outcomeGaveUp    = "gave_up"
	outcomeTimeout   = "timeout"
	outcomeCircuit   = "circuit"
	outcomeCancelled = "cancelled"
)

// rejectionKind is what a 429 says about the NEXT request to the upstream.
type rejectionKind string

const (
	// kindRateLimit: too much at once. Fewer calls in flight would have
	// passed, so the answer counts against the allowance and the call is
	// retried.
	kindRateLimit rejectionKind = "rate_limit"
	// kindQuota: a usage window is spent. Nothing passes before its reset.
	kindQuota rejectionKind = "quota"
	// kindOther: a limit only the client can act on (balance, plan, usage
	// policy), or an answer that said nothing recognizable.
	kindOther rejectionKind = "other"
)

var (
	rateLimitWording = regexp.MustCompile(`(?i)rate limit`)
	quotaResetWording = regexp.MustCompile(`(?i)\breset(?:s)? at (\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2})?)`)
)

// errorAnswer is the error object of an upstream's answer.
type errorAnswer struct {
	Code    string
	Message string
}

// errorOf reads the error object of a JSON answer. The zero value is an
// answer without one.
func errorOf(body []byte) errorAnswer {
	var answer struct {
		Error *struct {
			Code    json.RawMessage `json:"code"`
			Message string          `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &answer); err != nil || answer.Error == nil {
		return errorAnswer{}
	}
	return errorAnswer{
		Code:    strings.Trim(strings.TrimSpace(string(answer.Error.Code)), `"`),
		Message: answer.Error.Message,
	}
}

// classify reads what the upstream's 429 means and returns the business
// code it carried, empty when it named none.
func (c AdmissionConfig) classify(body []byte) (rejectionKind, string) {
	answer := errorOf(body)
	switch {
	case c.RetryableCodes[answer.Code]:
		return kindRateLimit, answer.Code
	case c.QuotaCodes[answer.Code]:
		return kindQuota, answer.Code
	case quotaResetWording.MatchString(answer.Message):
		// A reset time names a window, whatever code the provider files it
		// under: nothing passes before it.
		return kindQuota, answer.Code
	case answer.Code == "" && rateLimitWording.MatchString(answer.Message):
		return kindRateLimit, answer.Code
	}
	// A code the config does not name, with no reset time: the provider
	// said something specific, and guessing from its wording is a guess.
	return kindOther, answer.Code
}

// quotaReset is the moment a quota answer says its window resets. It is
// false for an answer that names none or names one that cannot be read.
func (c AdmissionConfig) quotaReset(body []byte) (time.Time, bool) {
	stamp := quotaResetWording.FindStringSubmatch(errorOf(body).Message)
	if stamp == nil {
		return time.Time{}, false
	}
	zone := time.FixedZone("reset", int(c.QuotaResetUTCOffset/time.Second))
	reset, err := time.ParseInLocation("2006-01-02T15:04:05Z07:00", strings.Replace(stamp[1], " ", "T", 1), zone)
	if err != nil {
		return time.Time{}, false
	}
	return reset, true
}

// Gate admits calls to one upstream. At most `limit` are in flight at any
// moment; the rest wait in order of arrival. The allowance starts at the
// configured ceiling, drops by one when the upstream rejects a call as too
// much at once, and grows back by one after a quiet interval. A raise that
// is rejected counts as a failed probe and doubles the time until the next
// one, so an allowance that sits below the ceiling is probed rarely, not on
// every interval.
type Gate struct {
	name     string
	cfg      AdmissionConfig
	registry *Registry
	logger   *slog.Logger
	now      func() time.Time

	mu            sync.Mutex
	inflight      int
	limit         int
	waiters       []*waiter
	changedAt     time.Time // when the allowance last moved
	probeInterval time.Duration
	lastWasRaise  bool
	shrunkAt      time.Time // when a rejection last lowered the allowance
	quota         quotaState
}

// quotaState is the upstream's own answer that a usage window is spent,
// kept to answer later calls without asking the upstream again.
type quotaState struct {
	until       time.Time
	body        []byte
	contentType string
	code        string
}

type waiter struct {
	ready   chan struct{}
	granted bool
}

func NewGate(name string, cfg AdmissionConfig, registry *Registry, logger *slog.Logger) *Gate {
	g := &Gate{
		name:          name,
		cfg:           cfg,
		registry:      registry,
		logger:        logger,
		now:           time.Now,
		limit:         cfg.MaxConcurrency,
		probeInterval: cfg.GrowAfter,
	}
	g.changedAt = g.now()
	g.publish()
	return g
}

// open starts the admission of one call that arrived at started.
func (g *Gate) open(started time.Time) *pending {
	return &pending{gate: g, deadline: started.Add(g.cfg.MaxWait)}
}

// acquire takes one in-flight slot, waiting for it in order of arrival. A
// call that already waited once (front) rejoins ahead of the queue: it has
// been waiting longer than any call in it. The context ends the wait.
func (g *Gate) acquire(ctx context.Context, front bool) error {
	g.mu.Lock()
	g.grow()
	if g.inflight < g.limit {
		g.inflight++
		g.publish()
		g.mu.Unlock()
		return nil
	}
	w := &waiter{ready: make(chan struct{})}
	if front {
		g.waiters = append([]*waiter{w}, g.waiters...)
	} else {
		g.waiters = append(g.waiters, w)
	}
	g.publish()
	g.mu.Unlock()

	select {
	case <-w.ready:
		return nil
	case <-ctx.Done():
		g.mu.Lock()
		if w.granted {
			// The slot became ours as the call was leaving: hand it on.
			g.release()
		} else {
			for i, other := range g.waiters {
				if other == w {
					g.waiters = append(g.waiters[:i], g.waiters[i+1:]...)
					break
				}
			}
		}
		g.publish()
		g.mu.Unlock()
		return context.Cause(ctx)
	}
}

// Release gives back a slot taken by acquire and hands it to the first
// waiting call.
func (g *Gate) Release() {
	g.mu.Lock()
	g.release()
	g.publish()
	g.mu.Unlock()
}

// release is Release for a caller that holds the lock.
func (g *Gate) release() {
	g.inflight--
	for len(g.waiters) > 0 && g.inflight < g.limit {
		w := g.waiters[0]
		g.waiters[0] = nil
		g.waiters = g.waiters[1:]
		w.granted = true
		g.inflight++
		close(w.ready)
	}
}

// rejected records that the upstream answered a call with "too much at
// once". The allowance drops by one. Rejections that arrive within
// rejectionCoalesceWindow of the drop it caused are the same overload seen
// by several calls at once and do not drop it further.
func (g *Gate) rejected() {
	g.mu.Lock()
	defer g.mu.Unlock()
	now := g.now()
	if g.lastWasRaise {
		// The raise did not hold: wait longer before trying it again.
		g.probeInterval = min(2*g.probeInterval, maxProbeInterval)
	}
	g.lastWasRaise = false
	if now.Sub(g.shrunkAt) < rejectionCoalesceWindow {
		return
	}
	g.shrunkAt = now
	if g.limit > g.cfg.MinConcurrency {
		g.limit--
		g.changedAt = now
		g.logger.Info("admission allowance lowered", "upstream", g.name, "limit", g.limit)
	}
	g.publish()
}

// exhausted records the upstream's quota answer: nothing passes before
// until, so later calls are answered from body instead of being sent.
func (g *Gate) exhausted(until time.Time, body []byte, contentType, code string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if ahead := until.Sub(g.now()); ahead <= 0 || ahead >= maxQuotaResetAhead || !until.After(g.quota.until) {
		return
	}
	g.quota = quotaState{until: until, body: body, contentType: contentType, code: code}
	g.logger.Warn("upstream usage quota exhausted", "upstream", g.name, "code", code, "resets_at", until)
	g.publish()
}

// grow raises the allowance by one once it has been quiet for the probe
// interval. The caller holds the lock.
func (g *Gate) grow() {
	if g.limit >= g.cfg.MaxConcurrency || g.now().Sub(g.changedAt) < g.probeInterval {
		return
	}
	if g.lastWasRaise {
		// The previous raise held a whole interval: the probe passed, so
		// probe at the base rate again.
		g.probeInterval = g.cfg.GrowAfter
	}
	g.limit++
	g.changedAt, g.lastWasRaise = g.now(), true
	g.logger.Info("admission allowance raised", "upstream", g.name, "limit", g.limit)
}

// quotaBlocked is the reset the upstream is known to be exhausted until and
// the answer to replay until then.
func (g *Gate) quotaBlocked() (quotaState, bool) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if !g.now().Before(g.quota.until) {
		return quotaState{}, false
	}
	return g.quota, true
}

// publish copies the gate's state into the metrics registry. The caller
// holds the lock.
func (g *Gate) publish() {
	g.registry.AdmissionState(g.name, len(g.waiters), g.inflight, g.limit, g.now().Before(g.quota.until))
}

// pending is the admission of one client call: what it has waited, how
// often the upstream has answered it, and when the proxy stops waiting on
// its behalf. A call to an upstream without a gate has one too, with no
// gate, whose every method does nothing.
type pending struct {
	gate     *Gate
	deadline time.Time // arrival + MaxWait, across queueing and retries
	attempts int       // answers the upstream has given this call
	rejected int       // of those, the "too much at once" ones
	waited   time.Duration
}

// ungated is the admission of a call to an upstream without a gate.
func ungated() *pending { return &pending{} }

// gated reports whether a 429 to this call is one the admission reads.
func (p *pending) gated() bool { return p.gate != nil }

// errAdmissionTimeout is the wait budget running out before the upstream
// had room, so that the call was not sent again.
var errAdmissionTimeout = errors.New("admission wait budget exhausted")

// quotaRejection is why a call was not sent: the upstream's usage quota is
// spent. Body is the upstream's own answer, to replay as is.
type quotaRejection struct {
	until       time.Time
	body        []byte
	contentType string
	code        string
}

func (q *quotaRejection) Error() string {
	return "upstream usage quota exhausted until " + q.until.Format(time.RFC3339)
}

// enter takes a slot for the next attempt. It returns errAdmissionTimeout
// or a *quotaRejection when the call is not to be sent, and nil once the
// call holds a slot. When the client goes away it returns the context's
// error.
func (p *pending) enter(ctx context.Context) error {
	if p.gate == nil {
		return nil
	}
	g := p.gate
	if quota, blocked := g.quotaBlocked(); blocked {
		// A reset within the budget is worth waiting for: the call then
		// goes through like any other. The guard allows the upstream's
		// clock and ours to disagree by a moment.
		wait := quota.until.Sub(g.now()) + quotaResetGuard
		if g.now().Add(wait).After(p.deadline) {
			return &quotaRejection{until: quota.until, body: quota.body, contentType: quota.contentType, code: quota.code}
		}
		if err := p.sleep(ctx, wait); err != nil {
			return err
		}
	}
	if err := ctx.Err(); err != nil {
		return err
	}

	waitCtx, cancel := context.WithDeadlineCause(ctx, p.deadline, errAdmissionTimeout)
	defer cancel()
	since := g.now()
	if err := g.acquire(waitCtx, p.attempts > 0); err != nil {
		if errors.Is(err, errAdmissionTimeout) {
			return err
		}
		return ctx.Err()
	}
	p.waited += g.now().Sub(since)
	g.registry.AdmissionWaited(g.name, p.waited)
	return nil
}

// answered counts the answer the upstream just gave the call.
func (p *pending) answered() { p.attempts++ }

// stamp copies onto the call's record what the admission knows so far.
func (p *pending) stamp(rec *Record) {
	if p.gate == nil {
		return
	}
	rec.Attempts = p.attempts
	rec.QueueMS = p.waited.Milliseconds()
	rec.Admission = outcomeAdmitted
	if p.rejected > 0 {
		rec.Admission = outcomeAbsorbed
	}
}

// leave gives back the slot enter took.
func (p *pending) leave() {
	if p.gate != nil {
		p.gate.Release()
	}
}

// retryable reports whether one more attempt at the call is allowed.
func (p *pending) retryable() bool {
	return p.rejected <= p.gate.cfg.MaxRetries
}

// pause waits out the delay the upstream asked for after a "too much at
// once" answer, or the proxy's own backoff when it asked for none. It
// returns false when the call is not to be tried again: the delay would
// outlast the budget, the upstream asked for longer than the proxy waits,
// or the client went away.
func (p *pending) pause(ctx context.Context, header http.Header) bool {
	delay := p.backoff()
	if asked, ok := retryAfter(header); ok {
		if asked > maxHonoredRetryAfter {
			return false
		}
		delay = asked
	}
	return p.sleep(ctx, delay) == nil
}

// backoff is the proxy's own wait before the next attempt: exponential from
// retryBase, jittered over its range so calls rejected together do not
// return together.
func (p *pending) backoff() time.Duration {
	ceiling := min(retryBase<<min(p.rejected-1, maxRetriesForBackoff), retryCeiling)
	floor := ceiling / 4
	return floor + rand.N(ceiling-floor)
}

// sleep waits for d, unless the budget ends first (the call is out of time)
// or the client goes away. It reports nil only after the whole delay
// passed.
func (p *pending) sleep(ctx context.Context, d time.Duration) error {
	if p.gate.now().Add(d).After(p.deadline) {
		return errAdmissionTimeout
	}
	ctx, cancel := context.WithDeadlineCause(ctx, p.deadline, errAdmissionTimeout)
	defer cancel()
	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case <-timer.C:
		return nil
	case <-ctx.Done():
		return context.Cause(ctx)
	}
}

// retryAfter reads a seconds-form Retry-After header.
func retryAfter(header http.Header) (time.Duration, bool) {
	raw := strings.TrimSpace(header.Get("Retry-After"))
	seconds, err := strconv.Atoi(raw)
	if err != nil || seconds < 0 {
		return 0, false
	}
	return time.Duration(seconds) * time.Second, true
}
