package main

import (
	"strings"
	"testing"
)

func TestCallMovesItsInFlightMark(t *testing.T) {
	r := NewRegistry()
	call := r.BeginCall("crush", "zai")

	call.SetModel("glm-5.3")
	call.SetModel("glm-5.3") // idempotent
	call.SetModel("")        // an absent model is "none", never a blank label

	want := `ai_meter_active_requests{client="crush",upstream="zai",model="glm-5.3"} 1` + "\n" +
		`ai_meter_active_requests{client="crush",upstream="zai",model="none"} 0` + "\n"
	if got := r.Render(); !strings.Contains(got, want) {
		t.Fatalf("in-flight mark not moved to its model:\n%s", got)
	}

	call.End()
	call.End()            // a second End must not push the gauge below zero
	call.SetModel("x")    // a finished call cannot re-enter the gauge

	for _, line := range strings.Split(r.Render(), "\n") {
		if strings.HasPrefix(line, "ai_meter_active_requests{") && !strings.HasSuffix(line, " 0") {
			t.Fatalf("in-flight gauge not zero after End: %q", line)
		}
	}
}

func TestInFlightGaugeCountsConcurrentCalls(t *testing.T) {
	r := NewRegistry()
	calls := []*Call{
		r.BeginCall("crush", "zai"),
		r.BeginCall("crush", "zai"),
		r.BeginCall("crush", "zai"),
	}
	calls[0].SetModel("glm-5.3")
	calls[1].SetModel("glm-5.3")
	calls[2].SetModel("glm-5.4")

	want := `ai_meter_active_requests{client="crush",upstream="zai",model="glm-5.3"} 2` + "\n" +
		`ai_meter_active_requests{client="crush",upstream="zai",model="glm-5.4"} 1` + "\n"
	if got := r.Render(); !strings.Contains(got, want) {
		t.Fatalf("concurrent calls not counted per model:\n%s", got)
	}

	for _, call := range calls {
		call.End()
	}
	if got := r.Render(); strings.Contains(got, "ai_meter_active_requests{client=\"crush\",upstream=\"zai\",model=\"glm-5.3\"} 0") == false {
		t.Fatalf("idle series should stay exposed at 0:\n%s", got)
	}
}
