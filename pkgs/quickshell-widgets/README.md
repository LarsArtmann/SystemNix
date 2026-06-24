# SystemNix Quickshell Widgets

Custom QML widgets for DankMaterialShell/Quickshell that surface live state from
SystemNix's own services — the features no upstream shell has.

## Widgets

| Widget | Source | Poll | Shows |
|--------|--------|------|-------|
| `OllamaStatus.qml` | Ollama `:11434/api/ps` | 5s | Loaded AI model + VRAM footprint |
| `DnsStats.qml` | dnsblockd `:9090/stats` | 10s | Queries blocked today, % blocked |
| `ServiceHealth.qml` | Gatus `:9110` | 30s | Service up/down health dots |
| `GpuMonitor.qml` | amdgpu sysfs | 5s | VRAM used/total, GPU temp |
| `TaskRadar.qml` | Taskchampion `:10222` | 30s | Pending + overdue task counts |
| `BtrfsSnapshot.qml` | systemd timer | 60s | Snapshot freshness (stale >3d) |
| `VoiceAgent.qml` | Whisper `:7860` + LiveKit `:7880` | 10s | Voice agent active/listening state |
| `CameraStatus.qml` | emeet-pixyd IPC | 10s | Camera on/tracking (replaces waybar-camera) |
| `ServerPulse.qml` | Minecraft `:25565` + Forgejo `:3000` | 30s | Player count + pending PRs |
| `CrmPipeline.qml` | Twenty CRM `:3200` | 60s | Active opportunities + pipeline value |
| `SystemNixService.qml` | — | — | Shared base class for HTTP polling |

## Usage

These widgets are designed to be imported into DankMaterialShell's QML environment
or a custom Quickshell config. They use Quickshell's `Process` + `StdioCollector`
for HTTP polling and `FileView` for sysfs reads — all reactive, no shell scripts.

During development, use `nix develop .#quickshell` to get a devShell with
Quickshell + qmlls for hot-reload iteration.

## Port wiring

All port numbers match `lib/ports.nix`. If a service port changes, update both
the port in `lib/ports.nix` and the corresponding widget's URL constant.

## Development

```bash
nix develop .#quickshell    # devShell with quickshell + qmlls
# Edit .qml files → save → Quickshell hot-reloads
```
