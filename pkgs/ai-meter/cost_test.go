package main

import (
	"math"
	"testing"
)

// The dashboard's spend-rate queries mirror EstimateCost in PromQL. The
// 100/20/50 tokens at 2/0.5/4 USD per 1M fixture is the one the
// ai-meter-spend-promql check pins them to.
func TestEstimateCost(t *testing.T) {
	priced := Cost{Input: 2, Output: 4, CachedInput: 0.5}
	tests := []struct {
		name       string
		prompt     int
		cached     int
		completion int
		price      Cost
		want       float64
	}{
		{"cached subset is billed at its own rate", 100, 20, 50, priced, 0.00037},
		{"nothing cached", 1_000_000, 0, 0, priced, 2},
		{"unpriced model costs nothing", 100, 20, 50, Cost{}, 0},
		{"cached above prompt never bills a negative prompt", 10, 25, 0, priced, 12.5e-6},
		{"no tokens", 0, 0, 0, priced, 0},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := EstimateCost(test.prompt, test.cached, test.completion, test.price)
			if math.Abs(got-test.want) > 1e-12 {
				t.Fatalf("EstimateCost(%d, %d, %d, %+v) = %v, want %v", test.prompt, test.cached, test.completion, test.price, got, test.want)
			}
		})
	}
}

func TestCostForStripsOneProviderPrefix(t *testing.T) {
	cfg := &Config{Costs: map[string]Cost{"glm-5.3": {Input: 1.4}}}
	tests := []struct {
		model string
		want  float64
	}{
		{"glm-5.3", 1.4},
		{"zai/glm-5.3", 1.4},
		{"openai/zai/glm-5.3", 0},
		{"glm-5.3-flash", 0},
		{"glm-5.31", 0},
		{"glm-5.3/", 0},
	}
	for _, test := range tests {
		if got := cfg.CostFor(test.model).Input; got != test.want {
			t.Errorf("CostFor(%q).Input = %v, want %v", test.model, got, test.want)
		}
	}
}
