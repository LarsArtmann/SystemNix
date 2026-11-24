package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
)

// The tq incident sink (tq.go): forwarded TRIGGERS become incident reports;
// resolves, unparseable payloads, and an empty sink URL never report.

type capturedReport struct {
	path string
	auth string
	body incidentReport
}

func TestReportIfTriggeredPostsParsedTriggers(t *testing.T) {
	var (
		mu       sync.Mutex
		reports  []capturedReport
		recorder = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			b, _ := io.ReadAll(r.Body)
			var rep incidentReport
			if err := json.Unmarshal(b, &rep); err != nil {
				t.Errorf("incident body not JSON: %v", err)
			}
			mu.Lock()
			reports = append(reports, capturedReport{
				path: r.URL.Path,
				auth: r.Header.Get("Authorization"),
				body: rep,
			})
			mu.Unlock()
			w.WriteHeader(http.StatusAccepted)
		}))
	)
	defer recorder.Close()

	pol := newPolicy(serverConfig{sev1Mute: map[string]bool{}})
	cfg := serverConfig{
		tqURL:     recorder.URL + "/api/v1/errors",
		tqToken:   "test-token",
		tqProject: "SystemNix",
	}

	reportIfTriggered(pol, recorder.Client(), cfg, triggerBody("Monitoring/Gatus"))
	if len(reports) != 1 {
		t.Fatalf("want 1 report, got %d", len(reports))
	}

	got := reports[0]
	if got.path != "/api/v1/errors" {
		t.Errorf("path = %q, want /api/v1/errors", got.path)
	}
	if got.auth != "Bearer test-token" {
		t.Errorf("authorization = %q, want Bearer test-token", got.auth)
	}
	if got.body.Project != "SystemNix" || got.body.Kind != "server" {
		t.Errorf("project/kind = %q/%q, want SystemNix/server", got.body.Project, got.body.Kind)
	}
	// Message stability is the fingerprint contract: identity only, no
	// failure counts or condition output (those live in breadcrumbs).
	if got.body.Message != "Gatus health check failing: Monitoring/Gatus" {
		t.Errorf("message = %q", got.body.Message)
	}
	if len(got.body.Breadcrumbs) == 0 {
		t.Error("breadcrumbs empty — failure context lost")
	}
	if got.body.OccurredAt.IsZero() {
		t.Error("occurredAt zero")
	}

	if reports, failures := snapshotTQParts(pol); reports != 1 || failures != 0 {
		t.Errorf("counters = %d/%d, want 1 report 0 failures", reports, failures)
	}
}

func TestReportIfTriggeredSkipsResolvesGarbageAndDisabled(t *testing.T) {
	var (
		mu        sync.Mutex
		hits      int
		recorder = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
			mu.Lock()
			hits++
			mu.Unlock()
			w.WriteHeader(http.StatusAccepted)
		}))
	)
	defer recorder.Close()

	pol := newPolicy(serverConfig{sev1Mute: map[string]bool{}})
	cfg := serverConfig{tqURL: recorder.URL, tqToken: "t"}

	// Resolve: not an error observation.
	reportIfTriggered(pol, recorder.Client(), cfg, resolveBody("Monitoring/Gatus"))
	// Unparseable: fail-open Discord forward, never an incident.
	reportIfTriggered(pol, recorder.Client(), cfg, []byte(`{"content":"garbage"}`))
	// Disabled sink: no URL configured.
	disabled := cfg
	disabled.tqURL = ""
	reportIfTriggered(pol, recorder.Client(), disabled, triggerBody("Monitoring/Gatus"))

	if hits != 0 {
		t.Fatalf("sink hit %d times, want 0", hits)
	}
	if reports, failures := snapshotTQParts(pol); reports != 0 || failures != 0 {
		t.Errorf("counters = %d/%d, want 0/0", reports, failures)
	}
}

func TestReportIfTriggeredCounts4xxAsPermanentFailure(t *testing.T) {
	recorder := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
	}))
	defer recorder.Close()

	pol := newPolicy(serverConfig{sev1Mute: map[string]bool{}})
	cfg := serverConfig{tqURL: recorder.URL, tqToken: "wrong"}

	reportIfTriggered(pol, recorder.Client(), cfg, triggerBody("Monitoring/Gatus"))

	if reports, failures := snapshotTQParts(pol); reports != 0 || failures != 1 {
		t.Errorf("reports=%d failures=%d, want 0/1", reports, failures)
	}
}

func TestBuildIncidentReportClipsBreadcrumbs(t *testing.T) {
	long := make([]byte, 400)
	for i := range long {
		long[i] = 'x'
	}
	desc := []string{string(long), "", "second"}
	for i := 0; i < 30; i++ {
		desc = append(desc, "extra")
	}

	rep := buildIncidentReport("SystemNix", "Group/Name", desc)
	if len(rep.Breadcrumbs) != maxCrumbs {
		t.Fatalf("crumbs = %d, want %d", len(rep.Breadcrumbs), maxCrumbs)
	}
	if len(rep.Breadcrumbs[0]) != maxCrumb {
		t.Errorf("first crumb len = %d, want %d", len(rep.Breadcrumbs[0]), maxCrumb)
	}
	if rep.Breadcrumbs[1] != "second" {
		t.Errorf("empty line not skipped: %q", rep.Breadcrumbs[1])
	}
}

func snapshotTQParts(p *policy) (reports, failures int64) {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.tqReports, p.tqFailed
}
