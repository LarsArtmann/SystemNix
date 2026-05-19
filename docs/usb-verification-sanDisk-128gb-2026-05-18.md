# USB Stick Verification Report

**Date:** 2026-05-18
**Device:** SanDisk Ultra Fit 128GB USB 3.2 Gen 1
**Purpose:** Raspberry Pi 3 DNS failover node (`rpi3-dns`)

---

## Device Identity

| Field | Value |
|-------|-------|
| Device | `/dev/sda` |
| Model | SanDisk Ultra Fit (USB 3.2 Gen 1) |
| VID:PID | `0781:5583` (SanDisk Corp.) |
| Serial | `03026530071625182355` |
| USB Spec | 3.20, SuperSpeed 5 Gbps |
| Firmware | `1.00` |
| SCSI Inquiry | `USB SanDisk 3.2Gen1 1.00` |
| Interface | SCSI over Bulk-Only + UAS (USB Attached SCSI) |
| Power | Bus Powered, 896 mA max |

**Authenticity indicators:**
- VID `0781` is SanDisk's official USB-IF vendor ID
- PID `5583` matches the SanDisk Ultra Fit product line
- USB 3.20 descriptor with SuperSpeed 5Gbps negotiation
- UAS (USB Attached SCSI) protocol support — cheap fakes typically only support Bulk-Only Transport
- LPM (Link Power Management) supported
- bMaxPacketSize0 = 9 (512 bytes at SuperSpeed) — correct for USB 3.x

## Capacity Verification

| Metric | Value |
|--------|-------|
| Claimed module size | 128.00 GB (2^37 bytes) |
| Usable size | 114.60 GB (240,328,704 blocks) |
| Overhead | ~10.5% (normal) |

**f3probe (initial):**
```
Good news: The device `/dev/sda' is the real thing
Usable size: 114.60 GB matches Announced size: 114.60 GB
Probe time: 15.11s
```

**f3probe (post-stress):**
```
Good news: The device `/dev/sda' is the real thing
Usable size: 114.60 GB matches Announced size: 114.60 GB
Probe time: 41.33s
```

## Data Integrity Test (f3write + f3read)

Wrote 112.22 GB of incompressible random data across 113 files, then read back and verified every byte.

| Metric | Value |
|--------|-------|
| Data written | 112.22 GB (235,343,872 sectors) |
| Write speed | 44.82 MB/s average |
| **Corrupted sectors** | **0** |
| **Changed sectors** | **0** |
| **Overwritten sectors** | **0** |
| **Data LOST** | **0.00 Byte** |
| Read speed | 359.88 MB/s average |

## 4-Pass Destructive Stress Test (badblocks)

Wrote four distinct bit patterns across every block, reading back after each pass.

| Pattern | Pass | Errors |
|---------|------|--------|
| `0xAA` (alternating bits) | Write + Read | 0 |
| `0x55` (inverted alternating) | Write + Read | 0 |
| `0xFF` (all ones) | Write + Read | 0 |
| `0x00` (all zeros) | Write + Read | 0 |

**Total blocks tested:** 120,164,351 (every block on the device)
**Total bad blocks found:** 0
**Duration:** ~5 hours 30 minutes

## Performance Summary

| Operation | Speed |
|-----------|-------|
| Sequential write | 44.82 MB/s |
| Sequential read | 359.88 MB/s |

Write speed consistent with genuine SanDisk Ultra Fit 128GB — small form-factor drives are write-limited by thermals.

## Verdict

| Check | Result |
|-------|--------|
| VID/PID matches SanDisk Ultra Fit | PASS |
| USB 3.2 Gen 1 + UAS protocol | PASS |
| f3probe capacity (initial) | PASS |
| f3write+f3read — 112GB random data, 0 corruption | PASS |
| badblocks 4-pass — 0 bad blocks across 120M blocks | PASS |
| f3probe capacity (post-stress) — no shrinkage | PASS |

**Genuine SanDisk Ultra Fit 128GB USB 3.2 Gen 1 in perfect condition. Ready for Pi 3 deployment.**
