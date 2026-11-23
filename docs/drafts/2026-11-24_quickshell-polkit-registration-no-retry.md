# Dux/quickshell issue draft — polkit registration never retried

Title: PolkitAgent: failed registration is never retried, leaving authentication dead until shell restart

---

> [!NOTE]
> This filing was drafted by GLM (glm-5.3-flash) via Crush from an AI-run investigation, not at my request. The incident evidence below is quoted from our live journal (NixOS host running DankMaterialShell).
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** When `PolkitAgent`'s listener registration fails (polkitd rejects it, typically because another agent already owns the session), quickshell logs one warning and never tries again — even after the occupying agent is gone, authentication stays dead until the whole shell restarts. A retry, either with backoff or lazily when an authentication request arrives while unregistered, would let agents recover instead.

## Problem

A `PolkitAgent` registers its listener exactly once per instance lifetime. At quickshell `9b0f339b19057f4731bf3b48293307d7ef241671` (master):

- `src/services/polkit/agentimpl.cpp:31` registers in the constructor; `agentimpl.cpp:98` re-registers only in `setPath()`. No other registration call site exists.
- The failure branch is terminal (`agentimpl.cpp:101-104`):

```cpp
void PolkitAgentImpl::registerComplete(bool success) {
	if (success) this->bIsRegistered = true;
	else qCWarning(logPolkit) << "failed to register listener on path" << this->qmlAgent->path();
}
```

No retry, no backoff, and no re-attempt when a later authentication request arrives while unregistered.

## Real-world failure (NixOS, DankMaterialShell consumer)

Two agents raced at login; the other one won the slot (user journal, 2026-10-04 05:11):

```
05:11:14 Authentication agent result: true
05:11:20 failed to register listener: An authentication agent already exists for the given subject
```

Every shell start that morning failed identically (14:36, 03:39, 05:11). When the occupying agent was finally removed, the slot freed — and `org.freedesktop.PolicyKit1.AuthenticationAgent` then had NO owner on the session bus: GUI authentication stayed dead system-wide until the whole shell restarted so the constructor could run again on an empty slot. Any transient holder at shell start time (a stale agent from a previous session, a greeter-spawned agent) produces the same one-WARN permanent failure.

## Why this belongs here, not in the shell

DankMaterialShell's agent is a bare `PolkitAgent {}` (`quickshell/Services/PolkitAgentInstance.qml` at dux-shell `291f4c58786a4fa38832a3267e66b889748c7c40`). The no-retry behavior lives entirely in quickshell, and every `PolkitAgent` consumer inherits the same dead-end. The QML side can already observe state (`isRegistered` property, `src/services/polkit/qml.hpp:39`), but it sees no error detail, and shells that don't build recovery logic themselves are stuck with the single swallowed WARN.

## Suggested fix

Either of:

1. **Retry with backoff** in `registerComplete()`'s failure branch — registration failures are inherently transient ("already exists" clears when the other agent dies; polkit daemon may not be up yet).
2. **Lazy re-register**: in `initiateAuthentication()`, if `bIsRegistered` is false, attempt registration first. A request is proof the slot matters, and polkitd simply re-reports the conflict if it still exists.

Minor addition: `src/services/polkit/listener.cpp:126` already logs `error->message`, but nothing reaches QML — exposing the registration error (a `registrationError` string next to `isRegistered`) would let shells log or alert instead of depending on the journal WARN.

Versions: quickshell master `9b0f339b19057f4731bf3b48293307d7ef241671`, consumer DankMaterialShell locked at `d6564b02ec39457c22e4cf64d88130b868e33bb2` (dux-shell master `291f4c58786a4fa38832a3267e66b889748c7c40` checked for a fix), NixOS with nixpkgs 26.11.

💘 Generated with Crush
