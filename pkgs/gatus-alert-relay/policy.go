package main

import (
	"encoding/json"
	"log"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

type alertState int

const (
	stateTriggered alertState = iota
	stateResolved
)

func (s alertState) String() string {
	if s == stateResolved {
		return "resolved"
	}
	return "triggered"
}

type suppressReason string

const (
	reasonBootGrace    suppressReason = "boot-grace"
	reasonSev1Mute     suppressReason = "sev1-mute"
	reasonFlapCollapse suppressReason = "flap-collapse"
	reasonRearmGuard   suppressReason = "rearm-guard"
)

type decision struct {
	forward  bool
	endpoint string
	state    alertState
	reason   suppressReason
}

type queuedTrigger struct {
	body     []byte
	queuedAt time.Time
	reason   suppressReason
	deadline time.Time // rearm-guard only; zero for open-ended reasons
}

type endpointState struct {
	prevEventAt       time.Time // time of the event BEFORE the one being processed
	lastResolvedAt    time.Time
	forwardedTriggers []time.Time // within flapWindow; only FORWARDED ones count
	queued            *queuedTrigger
}

type policy struct {
	mu         sync.Mutex
	cfg        serverConfig
	startedAt  time.Time
	endpoints  map[string]*endpointState
	suppressed map[suppressReason]int64
	forwarded  int64
	replayed   int64
}

// Gatus 5.37 discord provider renders, into embeds[0].description:
//
//	An alert for **<Group/Name>** has been triggered due to having failed N time(s) in a row
//	An alert for **<Group/Name>** has been resolved after passing successfully N time(s) in a row
//
// The relay pins gatus via nixpkgs; if the wording ever drifts, parsing
// fails and the payload is FORWARDED (fail-open) — never silently dropped.
var endpointRe = regexp.MustCompile(`An alert for \*\*(.+?)\*\* has been (triggered|resolved)`)

type discordPayload struct {
	Content string `json:"content"`
	Embeds  []struct {
		Description string `json:"description"`
	} `json:"embeds"`
}

func parseAlert(body []byte) (endpoint string, state alertState, ok bool) {
	var p discordPayload
	if err := json.Unmarshal(body, &p); err != nil {
		return "", 0, false
	}
	texts := []string{p.Content}
	for _, e := range p.Embeds {
		texts = append(texts, e.Description)
	}
	for _, text := range texts {
		if m := endpointRe.FindStringSubmatch(text); m != nil {
			state = stateTriggered
			if m[2] == "resolved" {
				state = stateResolved
			}
			return m[1], state, true
		}
	}
	return "", 0, false
}

func newPolicy(cfg serverConfig) *policy {
	return &policy{
		cfg:        cfg,
		startedAt:  time.Now(),
		endpoints:  map[string]*endpointState{},
		suppressed: map[suppressReason]int64{},
	}
}

// sev1PageActive reads the SEV1 bridge alert file: present + fresh + page
// tier. Warn tiers do not mute (they are not drop-everything conditions),
// and any read failure fails OPEN (no mute) — a missing file is the bridge's
// own "clear" state, a garbage file is the bridge's problem, not a reason to
// eat alerts.
func (p *policy) sev1PageActive(now time.Time) bool {
	data, err := os.ReadFile(p.cfg.alertFile)
	if err != nil {
		return false
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) < 4 {
		return false
	}
	epoch, err := strconv.ParseInt(strings.TrimSpace(lines[2]), 10, 64)
	if err != nil || now.Sub(time.Unix(epoch, 0)) > p.cfg.sev1Freshness {
		return false
	}
	return strings.TrimSpace(lines[3]) == "page"
}

func (p *policy) stateFor(endpoint string) *endpointState {
	st, ok := p.endpoints[endpoint]
	if !ok {
		st = &endpointState{}
		p.endpoints[endpoint] = st
	}
	return st
}

// handle is the per-alert entry point from the HTTP layer.
func (p *policy) handle(body []byte, now time.Time) decision {
	endpoint, state, ok := parseAlert(body)
	if !ok {
		// Fail-open: an unparseable payload is forwarded verbatim.
		log.Printf("relay decision=forward reason=unparsed endpoint=\"?\" (gatus template drift? fail-open)")
		p.mu.Lock()
		p.forwarded++
		p.mu.Unlock()
		return decision{forward: true}
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	st := p.stateFor(endpoint)

	if state == stateResolved {
		// Resolves always pass: they close the loop in Discord and cancel
		// any queued trigger for this endpoint.
		st.lastResolvedAt = now
		st.prevEventAt = now
		st.queued = nil
		p.forwarded++
		log.Printf("relay decision=forward endpoint=%q state=resolved", endpoint)
		return decision{forward: true, endpoint: endpoint, state: state}
	}

	d := p.decideTriggerLocked(st, endpoint, body, now)
	if d.forward {
		p.forwarded++
		log.Printf("relay decision=forward endpoint=%q state=triggered", endpoint)
	} else {
		p.suppressed[d.reason]++
		log.Printf("relay decision=suppress reason=%s endpoint=%q state=triggered", d.reason, endpoint)
	}
	return d
}

func (p *policy) decideTriggerLocked(st *endpointState, endpoint string, body []byte, now time.Time) decision {
	// 1. Boot/deploy grace: the relay's own first minutes. Covers boot
	//    windows (services legitimately down while gatus is already up)
	//    and the relay's own deploy restarts. Queued.
	if now.Sub(p.startedAt) < p.cfg.bootGrace {
		st.queued = &queuedTrigger{body: body, queuedAt: now, reason: reasonBootGrace}
		return decision{endpoint: endpoint, reason: reasonBootGrace}
	}

	// 2. Parent-incident mute: SEV1 page tier active + endpoint on the
	//    storm-attributable list. Queued.
	if p.sev1PageActive(now) && p.cfg.sev1Mute[endpoint] {
		st.queued = &queuedTrigger{body: body, queuedAt: now, reason: reasonSev1Mute}
		return decision{endpoint: endpoint, reason: reasonSev1Mute}
	}

	// Flap bookkeeping: prune the window, then reset if the gap since the
	// previous event exceeded the quiet period.
	st.forwardedTriggers = pruneWindow(st.forwardedTriggers, now, p.cfg.flapWindow)
	if !st.prevEventAt.IsZero() && now.Sub(st.prevEventAt) > p.cfg.flapQuiet {
		st.forwardedTriggers = nil
	}
	st.prevEventAt = now

	// 3. Flap collapse: rate limit. NOT queued — after flapMax forwarded
	//    triggers in the window, more are noise until a quiet period.
	if len(st.forwardedTriggers) >= p.cfg.flapMax {
		return decision{endpoint: endpoint, reason: reasonFlapCollapse}
	}

	// 4. Re-arm guard: a trigger right after a resolve is a flap re-arm;
	//    hold it for the guard window and replay if still failing then.
	if !st.lastResolvedAt.IsZero() && now.Sub(st.lastResolvedAt) < p.cfg.rearmGuard {
		st.queued = &queuedTrigger{
			body: body, queuedAt: now, reason: reasonRearmGuard,
			deadline: now.Add(p.cfg.rearmGuard),
		}
		return decision{endpoint: endpoint, reason: reasonRearmGuard}
	}

	st.forwardedTriggers = append(st.forwardedTriggers, now)
	return decision{forward: true, endpoint: endpoint}
}

func pruneWindow(times []time.Time, now time.Time, window time.Duration) []time.Time {
	out := times[:0]
	for _, t := range times {
		if now.Sub(t) < window {
			out = append(out, t)
		}
	}
	return out
}

// replay evaluates queued triggers: a mute may delay, never lose.
type replayForwarder func(body []byte, endpoint, reason string)

func replayLoop(p *policy, cfg serverConfig, forward replayForwarder) {
	for now := range time.Tick(cfg.replayTick) {
		p.replayOnce(forward, now)
	}
}

func (p *policy) replayOnce(forward replayForwarder, now time.Time) {
	p.mu.Lock()
	type out struct {
		body     []byte
		endpoint string
		reason   suppressReason
	}
	var send []out
	for endpoint, st := range p.endpoints {
		q := st.queued
		if q == nil {
			continue
		}
		// Recovered while queued: the resolve handler already cleared the
		// queue, but a resolve that arrived between decide and this pass
		// with a NEWER timestamp also cancels.
		if !st.lastResolvedAt.IsZero() && st.lastResolvedAt.After(q.queuedAt) {
			st.queued = nil
			log.Printf("relay decision=replay-cancel endpoint=%q reason=%s (resolved while queued)", endpoint, q.reason)
			continue
		}
		switch q.reason {
		case reasonBootGrace:
			if now.Sub(p.startedAt) >= p.cfg.bootGrace {
				// Grace over: still failing. If SEV1 took over meanwhile,
				// re-queue under that reason instead of firing.
				if p.sev1PageActive(now) && p.cfg.sev1Mute[endpoint] {
					q.reason = reasonSev1Mute
					continue
				}
				st.queued = nil
				st.forwardedTriggers = append(st.forwardedTriggers, now)
				send = append(send, out{body: q.body, endpoint: endpoint, reason: reasonBootGrace})
			}
		case reasonSev1Mute:
			if !p.sev1PageActive(now) {
				st.queued = nil
				st.forwardedTriggers = append(st.forwardedTriggers, now)
				send = append(send, out{body: q.body, endpoint: endpoint, reason: reasonSev1Mute})
			}
		case reasonRearmGuard:
			if now.After(q.deadline) {
				st.queued = nil
				st.forwardedTriggers = append(st.forwardedTriggers, now)
				send = append(send, out{body: q.body, endpoint: endpoint, reason: reasonRearmGuard})
			}
		}
	}
	p.mu.Unlock()
	for _, o := range send {
		forward(o.body, o.endpoint, string(o.reason))
	}
	p.mu.Lock()
	p.replayed += int64(len(send))
	p.mu.Unlock()
}

func (p *policy) snapshotJSON() string {
	p.mu.Lock()
	defer p.mu.Unlock()
	queued := 0
	for _, st := range p.endpoints {
		if st.queued != nil {
			queued++
		}
	}
	sup := map[string]int64{}
	for k, v := range p.suppressed {
		sup[string(k)] = v
	}
	b, _ := json.Marshal(map[string]any{
		"uptime_seconds":    int(time.Since(p.startedAt).Seconds()),
		"forwarded":         p.forwarded,
		"replayed":          p.replayed,
		"suppressed":        sup,
		"queued_triggers":   queued,
		"endpoints_tracked": len(p.endpoints),
	})
	return string(b)
}
