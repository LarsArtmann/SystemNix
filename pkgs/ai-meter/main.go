// ai-meter — a loopback OpenAI-compatible metering proxy.
//
// Every AI call from every client (crush, paperless-gpt, inboxclean, …)
// flows through one endpoint. The proxy is TRANSPARENT: model names,
// request shapes, and response bodies are forwarded untouched. It only
// adds three things: per-client authentication, Prometheus metrics on a
// separate admin port, and a durable JSONL usage ledger.
//
// Routing is path-based so client model names stay stable everywhere:
//
//	POST /v1/<upstream>/chat/completions   → upstream's /chat/completions
//	POST /v1/<upstream>/embeddings         → upstream's /embeddings
//	GET  /v1/<upstream>/models             → passthrough (unmetered)
//	*    /v1/<upstream>/<anything>         → passthrough (request-counted)
//
// Costs are best-effort: a per-model USD/1M-token table in the config
// feeds ai_meter_cost_usd_total; unknown or local models meter tokens
// exactly and cost $0.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	configPath := flag.String("config", "/run/ai-meter/config.json", "path to the JSON config (client key files, upstreams, costs)")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	if err := run(*configPath, logger); err != nil {
		logger.Error("ai-meter exited", "err", err)
		os.Exit(1)
	}
}

func run(configPath string, logger *slog.Logger) error {
	cfg, err := LoadConfig(configPath)
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	ledger, err := OpenLedger(cfg.LedgerPath, logger)
	if err != nil {
		return fmt.Errorf("open ledger: %w", err)
	}
	defer ledger.Close()

	registry := NewRegistry()
	proxy := NewProxy(cfg, registry, ledger, logger)

	proxyServer := &http.Server{
		Addr:              cfg.Listen,
		Handler:           proxy,
		ReadHeaderTimeout: 30 * time.Second,
		IdleTimeout:       120 * time.Second,
		// No WriteTimeout: streamed completions legitimately run for minutes.
	}
	adminServer := &http.Server{
		Addr:              cfg.MetricsListen,
		Handler:           NewAdminHandler(registry, logger),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
	}

	errCh := make(chan error, 2)
	go func() {
		logger.Info("proxy listening", "addr", cfg.Listen, "upstreams", cfg.UpstreamNames())
		errCh <- proxyServer.ListenAndServe()
	}()
	go func() {
		logger.Info("admin listening", "addr", cfg.MetricsListen)
		errCh <- adminServer.ListenAndServe()
	}()

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)

	select {
	case sig := <-sigCh:
		logger.Info("shutting down", "signal", sig.String())
	case err := <-errCh:
		if !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("server: %w", err)
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = proxyServer.Shutdown(shutdownCtx)
	_ = adminServer.Shutdown(shutdownCtx)
	return nil
}
