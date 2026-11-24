package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"
)

// The tq incident sink (go-taskqueue ADR-0021): every alert the relay
// FORWARDS to Discord and that is a parsed TRIGGER is also reported to the
// tq write API (POST /api/v1/errors, Bearer token). The agent pool's
// incident policy mints a hot-band (120) agent fix task per incident, so a
// failing health check becomes AI-debugged work without a human in the
// loop. The report deliberately shares EVERY relay gate with the Discord
// forward (boot grace, SEV1 mute, flap collapse, re-arm guard): the exact
// noise those gates kill must not become autonomous agent dispatches.
//
// Contract differences vs the Discord forward:
//   - Resolves are NEVER reported (an incident mints on error
//     observations; a resolve is not an error — it would only bloat the
//     occurrence count of an incident that healed itself).
//   - Unparseable payloads are NEVER reported (the Discord path forwards
//     them fail-open; reporting an unparsable body as an incident would
//     mint a garbage fix task).
//   - The report is lossy-tolerant: a tq outage logs and counts a
//     failure, it never blocks or crashes the relay (the Discord forward
//     remains the alert path of record; the next occurrence of a still-red
//     check re-reports once tq is back).

// incidentReport is the subset of tq's incident.Report the relay sends
// (ADR-0021 wire shape). Fields absent here are absent on purpose.
type incidentReport struct {
	Project     string    `json:"project"`
	Kind        string    `json:"kind"`
	Message     string    `json:"message"`
	Breadcrumbs []string  `json:"breadcrumbs,omitempty"`
	OccurredAt  time.Time `json:"occurredAt"`
}

const (
	// maxCrumbs matches tq's incident.MaxBreadcrumbs; the relay pre-clips
	// so a hostile or drifted payload cannot inflate the request body.
	maxCrumbs = 20
	maxCrumb  = 256
)

// buildIncidentReport shapes a forwarded trigger into an error report.
// Message is DELIBERATELY just the endpoint identity: the incident
// fingerprint hashes project|kind|message|top-stack-frame, so a stable
// message means one incident per health check across its whole lifecycle
// (occurrence counting, regression detection). The failure detail rides
// the breadcrumbs, which the minted fix-task prompt renders as context.
func buildIncidentReport(project, endpoint string, desc []string) incidentReport {
	crumbs := make([]string, 0, len(desc))
	for _, line := range desc {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if len(line) > maxCrumb {
			line = line[:maxCrumb]
		}
		crumbs = append(crumbs, line)
		if len(crumbs) == maxCrumbs {
			break
		}
	}

	return incidentReport{
		Project:     project,
		Kind:        "server",
		Message:     "Gatus health check failing: " + endpoint,
		Breadcrumbs: crumbs,
		OccurredAt:  time.Now().UTC(),
	}
}

// reportIfTriggered parses a gatus Discord payload and reports it to the
// tq incident API when it is a parsed trigger. Called only after the
// policy returned a forward decision (live and replay paths alike).
func reportIfTriggered(pol *policy, client *http.Client, cfg serverConfig, body []byte) {
	if cfg.tqURL == "" {
		return
	}

	endpoint, state, desc, ok := parseAlert(body)
	if !ok || state != stateTriggered {
		return
	}

	report := buildIncidentReport(cfg.tqProject, endpoint, desc)
	payload, err := json.Marshal(report)
	if err != nil {
		pol.countTQ(false)
		log.Printf("relay tq-report=failed endpoint=%q error=%v (encode)", endpoint, err)
		return
	}

	// Same retry posture as the Discord forward: one retry for transient
	// failures; gatus will not re-send this alert, but unlike Discord the
	// next occurrence of a still-red check re-reports anyway.
	var lastErr error
	for attempt := 1; attempt <= 2; attempt++ {
		req, err := http.NewRequest(http.MethodPost, cfg.tqURL, bytes.NewReader(payload))
		if err != nil {
			lastErr = err
			break
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+cfg.tqToken)

		resp, err := client.Do(req)
		if err == nil {
			io.Copy(io.Discard, resp.Body) //nolint:errcheck — drain for keep-alive
			resp.Body.Close()              //nolint:errcheck
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				pol.countTQ(true)
				log.Printf("relay tq-report=ok endpoint=%q incident-api=%s", endpoint, resp.Status)
				return
			}
			// 4xx is deterministic (validation, auth): retrying cannot fix it.
			if resp.StatusCode >= 400 && resp.StatusCode < 500 {
				pol.countTQ(false)
				log.Printf("relay tq-report=failed endpoint=%q incident-api=%s (permanent — check token/payload)", endpoint, resp.Status)
				return
			}
			lastErr = fmt.Errorf("incident api status %s", resp.Status)
		} else {
			lastErr = err
		}
		time.Sleep(500 * time.Millisecond)
	}

	pol.countTQ(false)
	log.Printf("relay tq-report=failed endpoint=%q error=%v (next occurrence re-reports)", endpoint, lastErr)
}
