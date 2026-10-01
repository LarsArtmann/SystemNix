# visionreviewd (vision review agent)

**Service:** `services.vision-review-agent` — `modules/nixos/services/visionreviewd.nix`, a thin SystemNix wrapper around the upstream `vision-review-agent` nixosModule (the input owns every option incl. `llamaServer.{enable,package,model,port}`). SystemNix layers only: the flake-input package, registered llama port, onFailure alert routing, and the registry entry.

**No HTTP surface by design** — the daemon writes markdown reviews and talks to the llama-vlm captioner over loopback. The registry entry is monitored-only: NO vHost, NO Gatus check — probing the socket-activated llama-vlm endpoint would defeat its idle-unload TTL by keeping the model permanently resident (the fastflowlm doctrine: never probe what socket-activation is supposed to unload).

## Ops

- **Monitoring = unit state only** — system-health `monitoredServices` + onFailure (Discord); a silent wedge is covered by the unit's own restart behavior, not endpoint probes.
- **The llama leg is socket-activated** — first review after idle pays the cold load; that is expected latency, not an incident.
- **Upstream moves fast** — this wrapper dropped its old lazy `or null` guard once the input shipped the module (2026-09-22); option surface changes land upstream, this file only tracks the four layered concerns.

## Related

- [fastflowlm.md](./fastflowlm.md) — the socket-activation + never-probe doctrine
- [llama-rag.md](./llama-rag.md) — the other llama-server fleet members
