package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func testConfig(t *testing.T) serverConfig {
	t.Helper()
	return serverConfig{
		listen:        "127.0.0.1:0",
		upstream:      "http://upstream.invalid/webhook",
		alertFile:     filepath.Join(t.TempDir(), "alert"),
		bootGrace:     15 * time.Minute,
		flapWindow:    6 * time.Hour,
		flapMax:       4,
		flapQuiet:     30 * time.Minute,
		rearmGuard:    10 * time.Minute,
		sev1Freshness: 10 * time.Minute,
		sev1Mute:      map[string]bool{"Monitoring/Swap Metrics": true, "Monitoring/Monitor365 Server": true},
		replayTick:    time.Hour, // tests drive replayOnce directly
	}
}

func newTestPolicy(t *testing.T) (*policy, serverConfig, time.Time) {
	t.Helper()
	cfg := testConfig(t)
	p := newPolicy(cfg)
	start := time.Now()
	p.startedAt = start.Add(-2 * time.Hour) // past boot grace by default
	return p, cfg, start
}

func triggerBody(endpoint string) []byte {
	return fmt.Appendf(nil, `{"content":"","embeds":[{"title":":helmet_with_white_cross: Gatus","description":"An alert for **%s** has been triggered due to having failed 3 time(s) in a row:\n\u003e some description","color":15158332}]}`, endpoint)
}

func resolveBody(endpoint string) []byte {
	return fmt.Appendf(nil, `{"content":"","embeds":[{"description":"An alert for **%s** has been resolved after passing successfully 2 time(s) in a row","color":3066993}]}`, endpoint)
}

func writeSev1(t *testing.T, path, severity string, age time.Duration) {
	t.Helper()
	epoch := time.Now().Add(-age).Unix()
	content := fmt.Sprintf("SEV1 title\nSEV1 detail\n%d\n%s\n", epoch, severity)
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
}

type collector struct{ sent []string }

func (c *collector) forward(_ []byte, endpoint, _ string) { c.sent = append(c.sent, endpoint) }

// --- parsing ---

func TestParseAlert(t *testing.T) {
	ep, state, ok := parseAlert(triggerBody("Monitoring/Swap Metrics"))
	if !ok || ep != "Monitoring/Swap Metrics" || state != stateTriggered {
		t.Fatalf("trigger parse: ok=%v ep=%q state=%v", ok, ep, state)
	}
	ep, state, ok = parseAlert(resolveBody("Productivity/InboxClean"))
	if !ok || ep != "Productivity/InboxClean" || state != stateResolved {
		t.Fatalf("resolve parse: ok=%v ep=%q state=%v", ok, ep, state)
	}
	if _, _, ok := parseAlert([]byte(`{"content":"garbage"}`)); ok {
		t.Fatal("garbage must not parse")
	}
	if _, _, ok := parseAlert([]byte(`not json`)); ok {
		t.Fatal("non-json must not parse")
	}
}

// --- leg 1a: boot grace ---

func TestBootGraceSuppressAndReplay(t *testing.T) {
	p, cfg, start := newTestPolicy(t)
	p.startedAt = start // relay is young again

	d := p.handle(triggerBody("Infrastructure/Caddy"), start.Add(1*time.Minute))
	if d.forward || d.reason != reasonBootGrace {
		t.Fatalf("young relay must suppress with boot-grace, got %+v", d)
	}

	var c collector
	p.replayOnce(c.forward, start.Add(10*time.Minute))
	if len(c.sent) != 0 {
		t.Fatal("nothing replays while grace still active")
	}
	p.replayOnce(c.forward, start.Add(20*time.Minute))
	if len(c.sent) != 1 || c.sent[0] != "Infrastructure/Caddy" {
		t.Fatalf("grace-expired replay must forward the still-failing trigger, got %v", c.sent)
	}
	_ = cfg
}

func TestBootGraceResolveCancels(t *testing.T) {
	p, _, start := newTestPolicy(t)
	p.startedAt = start

	p.handle(triggerBody("Infrastructure/Caddy"), start.Add(1*time.Minute))
	if d := p.handle(resolveBody("Infrastructure/Caddy"), start.Add(2*time.Minute)); !d.forward {
		t.Fatal("resolves always forward, even during boot grace")
	}
	var c collector
	p.replayOnce(c.forward, start.Add(20*time.Minute))
	if len(c.sent) != 0 {
		t.Fatalf("resolved-while-queued trigger must NOT replay, got %v", c.sent)
	}
}

func TestResolvesAlwaysForwardDuringMute(t *testing.T) {
	p, cfg, _ := newTestPolicy(t)
	writeSev1(t, cfg.alertFile, "page", 0)
	if d := p.handle(resolveBody("Monitoring/Swap Metrics"), time.Now()); !d.forward {
		t.Fatal("resolve during SEV1 page mute must still forward")
	}
}

// --- leg 2: parent-incident mute ---

func TestSev1MuteMatrix(t *testing.T) {
	p, cfg, now := newTestPolicy(t)

	cases := []struct {
		name     string
		severity string
		age      time.Duration
		endpoint string
		file     bool
		wantMute bool
	}{
		{"page mutes listed", "page", 0, "Monitoring/Swap Metrics", true, true},
		{"page does not mute unlisted", "page", 0, "Infrastructure/Caddy", true, false},
		{"warn does not mute", "warn", 0, "Monitoring/Swap Metrics", true, false},
		{"warn-seen does not mute", "warn-seen", 0, "Monitoring/Swap Metrics", true, false},
		{"stale page does not mute", "page", 30 * time.Minute, "Monitoring/Swap Metrics", true, false},
		{"missing file does not mute", "", 0, "Monitoring/Swap Metrics", false, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if tc.file {
				writeSev1(t, cfg.alertFile, tc.severity, tc.age)
			} else {
				os.Remove(cfg.alertFile)
			}
			d := p.handle(triggerBody(tc.endpoint), now)
			if tc.wantMute && (d.forward || d.reason != reasonSev1Mute) {
				t.Fatalf("want sev1-mute suppress, got %+v", d)
			}
			if !tc.wantMute && !d.forward {
				t.Fatalf("want forward, got suppress %+v", d)
			}
			// drain any queue so later subtests start clean
			p.endpoints[tc.endpoint].queued = nil
		})
	}
}

func TestSev1MuteReplayAfterClear(t *testing.T) {
	p, cfg, now := newTestPolicy(t)
	writeSev1(t, cfg.alertFile, "page", 0)

	if d := p.handle(triggerBody("Monitoring/Monitor365 Server"), now); d.forward || d.reason != reasonSev1Mute {
		t.Fatalf("want sev1-mute, got %+v", d)
	}
	os.Remove(cfg.alertFile)
	var c collector
	p.replayOnce(c.forward, now.Add(time.Minute))
	if len(c.sent) != 1 || c.sent[0] != "Monitoring/Monitor365 Server" {
		t.Fatalf("cleared SEV1 must replay the still-failing trigger, got %v", c.sent)
	}
}

// --- leg 1b: flap collapse ---

func TestFlapCollapse(t *testing.T) {
	p, cfg, start := newTestPolicy(t)
	cfg.flapMax = 2
	cfg.rearmGuard = 0 // isolate flap from rearm interplay
	p.cfg = cfg

	ep := "Monitoring/Monitor365 Server"
	for i, wantForward := range []bool{true, true, false, false} {
		d := p.handle(triggerBody(ep), start.Add(time.Duration(i)*time.Minute))
		if d.forward != wantForward {
			t.Fatalf("trigger %d: want forward=%v, got %+v", i+1, wantForward, d)
		}
		if !wantForward && d.reason != reasonFlapCollapse {
			t.Fatalf("trigger %d: want flap-collapse, got %+v", i+1, d)
		}
	}

	// Quiet period resets the counter: last event was at +3min, so +40min
	// is past flapQuiet (30m).
	d := p.handle(triggerBody(ep), start.Add(40*time.Minute))
	if !d.forward {
		t.Fatalf("post-quiet trigger must forward again, got %+v", d)
	}
}

func TestFlapWindowPrune(t *testing.T) {
	p, cfg, start := newTestPolicy(t)
	cfg.flapMax = 2
	cfg.rearmGuard = 0
	p.cfg = cfg

	ep := "Monitoring/Swap Metrics"
	if d := p.handle(triggerBody(ep), start); !d.forward {
		t.Fatalf("first trigger must forward, got %+v", d)
	}
	// Two triggers 7h apart: window (6h) pruned, so the second forwards.
	if d := p.handle(triggerBody(ep), start.Add(7*time.Hour)); !d.forward {
		t.Fatalf("trigger outside flap window must forward, got %+v", d)
	}
}

// --- leg 1c: re-arm guard ---

func TestRearmGuardHoldsThenReplays(t *testing.T) {
	p, _, start := newTestPolicy(t)

	ep := "Infrastructure/Caddy"
	if d := p.handle(triggerBody(ep), start); !d.forward {
		t.Fatalf("first trigger must forward, got %+v", d)
	}
	if d := p.handle(resolveBody(ep), start.Add(time.Minute)); !d.forward {
		t.Fatal("resolve must forward")
	}
	// Re-trigger 5 minutes after the resolve: held by the re-arm guard.
	d := p.handle(triggerBody(ep), start.Add(6*time.Minute))
	if d.forward || d.reason != reasonRearmGuard {
		t.Fatalf("re-trigger inside guard must be held, got %+v", d)
	}

	var c collector
	p.replayOnce(c.forward, start.Add(10*time.Minute)) // deadline is +16m
	if len(c.sent) != 0 {
		t.Fatal("rearm replay must wait for the deadline")
	}
	p.replayOnce(c.forward, start.Add(17*time.Minute))
	if len(c.sent) != 1 || c.sent[0] != ep {
		t.Fatalf("past-deadline still-failing trigger must replay, got %v", c.sent)
	}
}

func TestRearmGuardQuickRecoveryIsSilent(t *testing.T) {
	p, _, start := newTestPolicy(t)

	ep := "Infrastructure/Caddy"
	p.handle(triggerBody(ep), start)
	p.handle(resolveBody(ep), start.Add(time.Minute))
	if d := p.handle(triggerBody(ep), start.Add(2*time.Minute)); d.forward || d.reason != reasonRearmGuard {
		t.Fatalf("want rearm-guard hold, got %+v", d)
	}
	// Recovers within the guard window: queued trigger cancels silently.
	p.handle(resolveBody(ep), start.Add(4*time.Minute))
	var c collector
	p.replayOnce(c.forward, start.Add(30*time.Minute))
	if len(c.sent) != 0 {
		t.Fatalf("quick flap recovery must replay nothing, got %v", c.sent)
	}
}

// --- fail-open ---

func TestUnparsedForward(t *testing.T) {
	p, _, start := newTestPolicy(t)
	p.startedAt = start // inside grace on purpose: an unparseable payload
	// must forward even then (fail-open outranks mutes).
	if d := p.handle([]byte(`{"content":"template drift"}`), start.Add(time.Second)); !d.forward {
		t.Fatalf("unparseable payload must forward, got %+v", d)
	}
}

// --- healthz ---

func TestSnapshotJSON(t *testing.T) {
	p, cfg, now := newTestPolicy(t)
	writeSev1(t, cfg.alertFile, "page", 0)
	p.handle(triggerBody("Monitoring/Swap Metrics"), now)
	snap := p.snapshotJSON()
	for _, want := range []string{
		`"forwarded"`, `"suppressed"`, `"queued_triggers":1`, `"sev1-mute":1`,
	} {
		if !strings.Contains(snap, want) {
			t.Fatalf("snapshot %s missing %q", snap, want)
		}
	}
}
