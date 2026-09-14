# Reticulum Network — Integration Assessment for Evo-x2

**Date:** 2026-04-15
**System:** Evo-x2 (AMD Ryzen AI Max+ 395, 128 GB RAM, NixOS)
**Status:** Not recommended — deferred to future LoRa/mesh project

---

## 1. What Is Reticulum?

Reticulum is a **cryptography-first networking stack** for building local and wide-area mesh networks over heterogeneous physical media. It provides:

| Feature | Detail |
|---------|--------|
| **Encryption** | E2E encrypted by default — X25519 ECDH + Ed25519 signatures, AES-256-CBC, HMAC-SHA256 |
| **Identity** | Self-sovereign 512-bit Curve25519 keysets — no PKI, no central authority |
| **Routing** | Self-configuring multi-hop routing across heterogeneous carriers |
| **Media** | LoRa, packet radio (AX.25/KISS), WiFi, Ethernet, TCP/UDP, serial, custom via pipes |
| **Latency tolerance** | Designed for links from 150 bps to 500 Mbps — handles extreme delay gracefully |
| **Link efficiency** | Encrypted link setup in 3 packets / 297 bytes; keepalive ≈ 0.44 bits/sec |
| **License** | Permissive with ethical restrictions (no weapon systems, no AI/ML training) |

### Protocol Stack

Reticulum is **not IP-based**. It runs its own protocol stack beneath the application layer:

```
┌─────────────────────────────────┐
│   Application (LXMF, NomadNet)  │
├─────────────────────────────────┤
│   Reticulum (Identity, Links)   │
│   - E2E encryption              │
│   - Multi-hop routing           │
│   - Announcement/destination    │
├─────────────────────────────────┤
│   Carrier (LoRa, TCP, WiFi...)  │
│   - Any half-duplex medium      │
│   - Min 5 bps, 500 byte MTU     │
└─────────────────────────────────┘
```

### Ecosystem Applications

| Application | Description |
|-------------|-------------|
| **Nomad Network** | Terminal-based mesh comms — encrypted pages, messaging, file transfer |
| **Sideband** | GUI LXMF client (Android/Linux/macOS) — messages, files, voice, telemetry |
| **LXMF** | Delay-tolerant message transfer protocol (like email for mesh) |
| **LXST** | Real-time audio transport for voice calls |
| **MeshChat** | Web-based LXMF client — images, voice, files |
| **RNsh** | Remote shell over Reticulum |
| **RNS FileSync** | File synchronization over mesh |
| **RNS Map** | Network topology visualization (2D + 3D) |
| **Reticulum Telephone** | Voice communication over Reticulum |

---

## 2. Evo-x2 Current Networking Stack

| Layer | Current Setup |
|-------|---------------|
| **Physical** | Realtek 2.5G Ethernet (`r8125`), MediaTek WiFi MT7925 (loaded, **not configured**) |
| **IP** | Static `192.168.1.150/24`, gateway `192.168.1.1`, IPv6 enabled |
| **DNS** | Unbound local resolver (DNS-over-TLS → Quad9, Cloudflare fallback), custom blocklist (2.5M+ domains), `.home.lan` local records |
| **Reverse Proxy** | Caddy with TLS (via sops-managed certs) — all services at `*.home.lan` |
| **Services** | Gitea, Immich, SigNoz, Grafana, Homepage, TaskChampion, Authelia SSO, Photomap |
| **Remote Access** | SSH (hardened, key-only via nix-ssh-config), wireguard-tools installed |
| **Secrets** | sops-nix (age-encrypted with SSH host key) |
| **Firewall** | TCP 22/53/80/443, UDP 53 |
| **WiFi** | Kernel module loaded (`mt7925e`) but **no AP, mesh, or client config** |
| **Radio/LoRa** | **None** |

---

## 3. Integration Possibilities

### 3.1 AutoInterface (LAN Discovery)

Reticulum's `AutoInterface` uses IPv6 multicast for peer discovery and UDP for transport. It works over any Ethernet/WiFi switching medium without IP infrastructure.

**Requirements:**
- Link-local IPv6 support (enabled by default on NixOS)
- UDP ports 29716 and 42671 open
- At least one switching medium (switch, AP, direct cable)

**Could work on Evo-x2:** Technically yes, but only the wired Ethernet is active. Without other Reticulum nodes on the LAN, there's nothing to discover.

### 3.2 TCP Transport (Internet Backbone)

Reticulum nodes can connect over TCP to form a global backbone. The public RNS testnet has community-run transport nodes.

**Could work on Evo-x2:** Yes — join the backbone via `TCPClientInterface` to a public transport node. You'd be a leaf node on a global mesh overlay.

### 3.3 WiFi Mesh

The MT7925 WiFi card supports station mode but has no AP/mesh configuration. Reticulum could theoretically use `AutoInterface` over an ad-hoc WiFi network, but this requires:
- Configuring the WiFi card in IBSS/ad-hoc mode or AP mode
- Other nodes also on the same WiFi segment

### 3.4 LoRa Radio

Reticulum's primary designed-for use case. Requires hardware:
- **RNode** LoRa transceiver (~$30-50 USB dongle, or DIY with ESP32 + SX1276/SX1262)
- Frequencies: 433 MHz (EU), 868/915 MHz (US)
- Range: 5-15 km line-of-sight, longer with directional antennas
- Bandwidth: 150 bps to ~50 kbps depending on LoRa settings

**Could work on Evo-x2:** With a USB RNode dongle plugged in, yes. The Evo-x2 has plenty of USB ports and compute power to serve as a backbone transport node.

---

## 4. Honest Assessment: Why It Doesn't Make Sense Now

### The Core Problem

> **Reticulum solves problems that Evo-x2 doesn't have.**

Evo-x2 is a **wired home server/workstation** behind a home router with full internet access. Every capability Reticulum offers is already served by existing infrastructure:

| Reticulum Capability | Already Covered By |
|---------------------|-------------------|
| Encrypted messaging | Element, Slack, email |
| File sync/transfer | Immich, Gitea, Syncthing potential |
| Remote access | SSH + Caddy TLS reverse proxy |
| Service discovery | Unbound `.home.lan` DNS records + Homepage dashboard |
| Encrypted transport | WireGuard, TLS everywhere via Caddy |
| Voice communication | Discord, Google Meet, etc. |

### Why Not Add It Anyway?

| Concern | Detail |
|---------|--------|
| **No radio hardware** | The killer feature (off-grid mesh over LoRa) requires USB dongles you don't own |
| **IP-only is redundant** | Without radio, Reticulum is a TCP/UDP overlay — your existing stack does this better and faster |
| **Single node mesh** | A mesh network of one node is pointless. No local peers to discover |
| **Not in nixpkgs** | No official NixOS package. Community flake exists but adds maintenance burden |
| **No security audit** | Reticulum hasn't had external security review. Running alongside sops secrets needs careful sandboxing |
| **WiFi not configured** | Your WiFi card has no AP/mesh config. Enabling it for Reticulum alone is marginal value |
| **Performance ceiling** | 500 Mbps max — your 2.5G Ethernet already exceeds this |
| **License concerns** | Ethical restrictions clause is unusual; protocol itself is public domain but implementation isn't standard FOSS |

---

## 5. When Reticulum *Would* Make Sense

### Scenario A: LoRa Community Mesh Network

**Setup:** Buy USB RNode dongles (~$30-50 each). Distribute to friends/neighbors. Evo-x2 serves as backbone transport node.

```
[Pi + RNode] ←── LoRa ──→ [Pi + RNode] ←── LoRa ──→ [Evo-x2 + RNode]
  (Neighbor A)                              (Your home server)
      │                                         │
      └──── TCP over Internet ──────────────────┘
                    (backbone)
```

**What you'd gain:**
- Off-grid encrypted messaging across your neighborhood
- Independent communication layer that works without internet
- Nomad Network "darknet" pages served from Evo-x2
- Community resilience / emergency preparedness

**Estimated cost:** $50-150 depending on antenna quality and number of nodes

### Scenario B: Emergency/Disaster Preparedness

**Setup:** Keep a USB RNode in a drawer. Flash a Raspberry Pi with NixOS + Reticulum. Pre-configure as a transport node.

In a disaster scenario where internet is down, LoRa mesh becomes the only game in town. Evo-x2's massive compute resources make it an ideal backbone node.

### Scenario C: IoT Sensor Network

**Setup:** LoRa sensors (environmental, security, agriculture) reporting back through Reticulum to Evo-x2. Low bandwidth but long range and encrypted by default.

This would complement the existing monitoring stack (SigNoz, Grafana) with off-grid sensor data.

### Scenario D: Learning / Exploration

**Lowest barrier:** Join the public RNS backbone via TCP, install NomadNet, browse the mesh. Zero hardware cost.

---

## 6. NixOS Packaging Status

| Component | In nixpkgs? | Notes |
|-----------|-------------|-------|
| `rns` (Reticulum) | No | Python package, installable via `pip install rns` |
| `lxmf` | Partially | `python311Packages.lxmf` exists in nixpkgs |
| `nomadnet` | No | Terminal mesh client |
| `sideband` | No | GUI LXMF client |
| `meshchat` | No | Web-based LXMF client |

### Community Flake

A comprehensive community NixOS flake exists: [codeberg.org/adingbatponder/reticulum_nixos_flake](https://codeberg.org/adingbatponder/reticulum_nixos_flake)

It provides:
- Complete Reticulum stack (RNS, LXMF, NomadNet, MeshChat, MeshChat Desktop)
- NixOS modules for service integration
- Network monitoring (Suricata IDS, Zeek)
- USB WiFi hotspot management
- flake-parts compatible architecture

**Integration into SystemNix would be:**
1. Add flake input to `flake.nix`
2. Import the `reticulum-integration` NixOS module
3. Open firewall ports 29716/42671 UDP
4. Configure interfaces in `~/.reticulum/config`
5. Optionally create `modules/nixos/services/reticulum.nix` for declarative config

**Estimated effort:** ~60 lines of Nix for a basic transport node setup.

---

## 7. Technical Deep-Dive: How It Works

### Identity & Encryption

```
Identity: 512-bit Curve25519 keyset
  ├── Ed25519 (signing) — 256-bit private + 256-bit public
  └── X25519 (ECDH)    — 256-bit private + 256-bit public

Link Establishment (3 packets, 297 bytes):
  1. Initiator → Responder: ECDH key exchange request
  2. Responder → Initiator: ECDH response + identity proof
  3. Initiator → Responder: Identity proof

All packets: AES-256-CBC + HMAC-SHA256 + HKDF key derivation
```

### Routing

- **Self-configuring:** Nodes announce their existence; paths are learned automatically
- **Multi-hop:** Intermediate nodes forward packets — no need for direct connectivity
- **Heterogeneous:** A single path might span LoRa → TCP → Ethernet transparently
- **No source addresses:** Initiator anonymity by design — packets don't reveal origin

### Interface Types

| Interface | Use Case | Bandwidth |
|-----------|----------|-----------|
| `AutoInterface` | LAN auto-discovery (WiFi/Ethernet) | Up to 500 Mbps |
| `TCPClientInterface` | Connect to remote transport node | Medium |
| `TCPServerInterface` | Serve as transport node | Medium |
| `RNodeInterface` | LoRa radio via RNode hardware | 150 bps – 50 kbps |
| `SerialInterface` | Any serial-port device | Variable |
| `KISSInterface` | AX.25 packet radio TNCs | Variable |
| `UDPInterface` | Local broadcast | Medium |

### Configuration Example (TCP Backbone + AutoInterface)

```ini
# ~/.reticulum/config

[reticulum]
  share_instance = Yes
  shared_instance_port = 37428

[[Local Discovery]]
  type = AutoInterface
  enabled = yes
  devices = eno1

[[Internet Backbone]]
  type = TCPClientInterface
  enabled = yes
  target_host = rns.unsigned.io
  target_port = 4965

[[Transport Node]]
  type = TCPServerInterface
  enabled = yes
  listen_ip = 0.0.0.0
  listen_port = 4242
```

---

## 8. Recommendation

### Primary Recommendation: **Defer**

Reticulum is **fascinating, well-designed technology** with genuine value for off-grid and mesh scenarios. However, Evo-x2 is the wrong host:

- **Wired home server** with full internet — no radio isolation problem to solve
- **All capabilities already covered** by existing services
- **No local peers** for mesh networking
- **No LoRa hardware** — the primary use case is inaccessible
- **Adds maintenance burden** without commensurate value

### Conditional Recommendation: **Explore Later If...**

1. **You acquire RNode hardware** → Evo-x2 becomes an excellent backbone node
2. **You build a community mesh** → Neighbors with Pis/RNodes form a real network
3. **You want off-grid resilience** → Pre-configure as emergency communication hub
4. **You want to learn mesh networking** → TCP-only backbone join is zero-cost exploration

### If Exploring: Minimal Setup

```nix
# flake.nix — add input
reticulum-flake.url = "git+https://codeberg.org/adingbatponder/reticulum_nixos_flake.git";

# configuration.nix — import module
imports = [ reticulum-flake.nixosModules.reticulum-integration ];

# networking.nix — open ports
networking.firewall.allowedUDPPorts = [ 29716 42671 ];
```

Then run `nomadnet` to browse the RNS network and send/receive LXMF messages.

---

## 9. References

| Resource | URL |
|----------|-----|
| Reticulum Website | https://reticulum.network/ |
| Reference Implementation | https://github.com/markqvist/Reticulum |
| Manual | https://markqvist.github.io/Reticulum/manual/ |
| Interface Types | https://markqvist.github.io/Reticulum/manual/interfaces.html |
| Cryptographic Stack | https://reticulum.network/crypto.html |
| Hardware Guide | https://reticulum.network/hardware.html |
| Community NixOS Flake | https://codeberg.org/adingbatponder/reticulum_nixos_flake |
| Nomad Network | https://github.com/markqvist/NomadNet |
| Sideband (GUI Client) | https://unsigned.io/sideband/ |
| Public Node Directory | https://directory.rns.recipes/ |
| Network Map | https://rmap.world/ |
