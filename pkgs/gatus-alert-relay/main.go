package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const maxBodyBytes = 64 * 1024

type serverConfig struct {
	listen        string
	upstream      string
	alertFile     string
	bootGrace     time.Duration
	flapWindow    time.Duration
	flapMax       int
	flapQuiet     time.Duration
	rearmGuard    time.Duration
	sev1Freshness time.Duration
	sev1Mute      map[string]bool
	replayTick    time.Duration
}

// The relay gates gatus' Discord webhook. Decision rules live in policy.go;
// this file is the HTTP surface, the replay loop, and the forwarder.
//
// Endpoints:
//
//	POST /hook     — gatus Discord-provider payload (pass-through bytes)
//	GET  /healthz  — counters + queue depth, for the gatus self-check
//
// Every decision is one journal line:
//
//	relay decision=forward|suppress|replay-forward reason=... endpoint="..." state=...
//
// Suppression semantics (the contract with the runbook):
//   - boot-grace / sev1-mute / rearm-guard drops are QUEUED and replayed
//     when their condition clears without an intervening resolve — a mute
//     may delay a real alert, never lose it.
//   - flap-collapse drops are NOT replayed. That is the point: after
//     flapMax forwarded triggers in flapWindow, further triggers are noise
//     until the endpoint goes flapQuiet without any event.
//
// Unparseable payloads are FORWARDED (fail-open): a gatus template change
// must degrade to today's behavior, never to silence.
func main() {
	cfg := serverConfig{sev1Mute: map[string]bool{}}
	var sev1MuteList string
	flag.StringVar(&cfg.listen, "listen", "127.0.0.1:9411", "listen address (bind loopback only)")
	flag.StringVar(&cfg.upstream, "upstream", os.Getenv("DISCORD_WEBHOOK_URL"), "upstream Discord webhook URL (or $DISCORD_WEBHOOK_URL)")
	flag.StringVar(&cfg.alertFile, "alert-file", "/run/systemnix/sev1/alert", "SEV1 bridge alert file (4 lines: title/detail/epoch/severity)")
	flag.DurationVar(&cfg.bootGrace, "boot-grace", 15*time.Minute, "suppress triggers while the relay process is younger than this (covers boot windows and deploy restarts)")
	flag.DurationVar(&cfg.flapWindow, "flap-window", 6*time.Hour, "sliding window counting forwarded triggers for flap collapse")
	flag.IntVar(&cfg.flapMax, "flap-max", 4, "forwarded triggers per flap-window before flap collapse suppresses further ones")
	flag.DurationVar(&cfg.flapQuiet, "flap-quiet", 30*time.Minute, "event-free period that resets an endpoint's flap counter")
	flag.DurationVar(&cfg.rearmGuard, "rearm-guard", 10*time.Minute, "delay re-triggers that follow a resolve within this window (queued; replayed if still failing at the deadline)")
	flag.DurationVar(&cfg.sev1Freshness, "sev1-freshness", 10*time.Minute, "max age of the SEV1 alert file's epoch line before it no longer counts as active")
	flag.StringVar(&sev1MuteList, "sev1-mute", "", "comma-separated Group/Name display names muted while SEV1 page-tier is active")
	flag.DurationVar(&cfg.replayTick, "replay-tick", 30*time.Second, "queue re-evaluation interval")
	flag.Parse()

	if cfg.upstream == "" {
		log.Fatal("relay: -upstream/$DISCORD_WEBHOOK_URL is empty — refusing to start as a silent gate")
	}
	for name := range strings.SplitSeq(sev1MuteList, ",") {
		if name = strings.TrimSpace(name); name != "" {
			cfg.sev1Mute[name] = true
		}
	}

	pol := newPolicy(cfg)
	client := &http.Client{Timeout: 10 * time.Second}

	go replayLoop(pol, cfg, func(body []byte, endpoint, reason string) {
		forward(client, cfg.upstream, body, endpoint, reason)
	})

	mux := http.NewServeMux()
	mux.HandleFunc("POST /hook", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(io.LimitReader(r.Body, maxBodyBytes))
		if err != nil {
			http.Error(w, "read body: "+err.Error(), http.StatusBadRequest)
			return
		}
		decision := pol.handle(body, time.Now())
		if decision.forward {
			go forward(client, cfg.upstream, body, decision.endpoint, "")
		}
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, "%s\n", pol.snapshotJSON())
	})

	srv := &http.Server{
		Addr:              cfg.listen,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       15 * time.Second,
		WriteTimeout:      15 * time.Second,
	}
	log.Printf("relay listening on %s (upstream set, boot-grace %s, mute-list %d endpoints)", cfg.listen, cfg.bootGrace, len(cfg.sev1Mute))
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("relay: %v", err)
	}
}

func forward(client *http.Client, upstream string, body []byte, endpoint, replayReason string) {
	// One retry: Discord webhooks occasionally 429/5xx transiently, and gatus
	// will not re-send this alert — the relay is the last hop.
	var lastErr error
	for attempt := 1; attempt <= 2; attempt++ {
		resp, err := client.Post(upstream, "application/json", strings.NewReader(string(body)))
		if err == nil {
			io.Copy(io.Discard, resp.Body) //nolint:errcheck — drain for keep-alive
			resp.Body.Close()              //nolint:errcheck
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				if replayReason != "" {
					log.Printf("relay decision=replay-forward reason=%s endpoint=%q", replayReason, endpoint)
				}
				return
			}
			lastErr = fmt.Errorf("upstream status %s", resp.Status)
		} else {
			lastErr = err
		}
		time.Sleep(500 * time.Millisecond)
	}
	log.Printf("relay decision=forward-failed endpoint=%q error=%v (gatus will not retry this alert)", endpoint, lastErr)
}
