# Cloud Backup Storage Pricing Comparison — May 2026

**Scenario:** 2TB encrypted backups (restic), ~1TB restored once per year.

---

## Provider Comparison (2TB, 1TB restore/year)

Sorted by total annual cost.

| Rank | Provider | Storage/yr | Restore 1TB/yr | Total/yr | Min Duration | Egress | Protocol | Complexity |
|------|----------|-----------|-----------------|----------|-------------|--------|----------|------------|
| 1 | **Azure Blob Archive** | $24 | $20 | **$44** | 180 days | $0.02/GB | AzCopy/REST | High |
| 2 | **IDrive e2** (2TB) | $49 | $0 | **$49** | None | Free (3x) | S3 | Low |
| 3 | **AWS Glacier Deep Archive** | $24 | $3 | **$27** → $52 w/ ops | 180 days | $0.0025/GB | S3 | High |
| 4 | **GCS Archive** | $29 | $50 | **$79** | 365 days | $0.05/GB | gsutil | High |
| 5 | **Hetzner BX11** (1TB) ×2 | $86 | $0 | **$86** | None | Free | SFTP/restic/borg | Low |
| 6 | **AWS Glacier Flexible** | $86 | $10 | **$96** | 90 days | $0.01/GB | S3 | High |
| 7 | **GCS Coldline** | $96 | $20 | **$116** | 90 days | $0.02/GB | gsutil | High |
| 8 | **Hetzner BX21** (5TB) | $122 | $0 | **$122** | None | Free | SFTP/restic/borg | Low |
| 9 | **Azure Blob Cold** | $96 | $30 | **$126** | 90 days | $0.03/GB | AzCopy/REST | High |
| 10 | **Backblaze B2** | $167 | $0 | **$167** | None | Free (3x) | S3 | Low |
| 11 | **Wasabi** (2TB) | $168 | $0 | **$168** | 90 days | Free | S3 | Low |
| 12 | **AWS S3 Standard-IA** | $250 | $20 | **$270** | 30 days | $0.01/GB | S3 | High |
| 13 | **GCS Nearline** | $240 | $10 | **$250** | 30 days | $0.01/GB | gsutil | High |
| 14 | **Azure Blob Cool** | $312 | $10 | **$322** | 30 days | $0.01/GB | AzCopy/REST | High |
| 15 | **Cloudflare R2** (2TB) | $360 | $10 | **$370** | 30d (IA) | Free | S3 | Medium |

> Wasabi price increase: $6.99 → $7.99/TB/mo effective July 1, 2026.

---

## Detailed Provider Profiles

### 1. Azure Blob Archive — $44/yr

| Metric | Value |
|--------|-------|
| Storage | $0.00099/GB/mo |
| Retrieval | $0.02/GB |
| Min duration | 180 days |
| Rehydration time | Up to 15 hours |
| Min object size | 128 KiB (from Jul 2026) |

**Pros:** Cheapest archive storage from a major cloud provider.
**Cons:** 15-hour rehydration, 180-day lock-in, complex IAM setup, AzCopy tooling.

### 2. IDrive e2 — $49/yr

| Metric | Value |
|--------|-------|
| Storage (2TB) | $4.13/mo (Y1), $2.06/mo after (50% discount first year) |
| Pay-as-you-go | $5/TB/mo |
| Egress | Free up to 3x storage |
| Min duration | None |
| S3-compatible | Yes |

**Pros:** Cheapest S3-compatible option, no retention lock-in, no API fees, simple pricing.
**Cons:** Less proven than Backblaze/Wasabi, smaller company, Y1 discount is temporary.

### 3. AWS Glacier Deep Archive — ~$52/yr (with ops)

| Metric | Value |
|--------|-------|
| Storage | $0.00099/GB/mo |
| Retrieval (bulk) | $0.0025/GB |
| Min duration | 180 days |
| Retrieval time | 12–48 hours |

**Pros:** Cheapest raw storage from AWS, bulk restore is nearly free.
**Cons:** 12-48 hour restore time, 180-day lock-in, complex S3 Glacier API, metadata overhead.

### 4. GCS Archive — $79/yr

| Metric | Value |
|--------|-------|
| Storage | $0.0012/GB/mo |
| Retrieval | $0.05/GB |
| Min duration | 365 days |
| Egress | $0.05/GB |

**Pros:** Google infrastructure, multi-region available.
**Cons:** Most expensive restore cost ($50 for 1TB), 365-day lock-in, restore cost kills the value.

### 5. Hetzner Storage Box BX11 ×2 — $86/yr

| Metric | Value |
|--------|-------|
| Storage (2× 1TB) | €3.20/mo each = €6.40/mo (~$7.20/mo) |
| Egress | Free |
| Min duration | None |
| Protocols | SFTP, WebDAV, rsync, Borg, Restic, Rclone |
| Locations | Germany (FSN) or Finland (HEL) |
| Snapshots | 10 per box |
| Traffic | Unlimited |

**Pros:** Zero egress, native restic/borg over SFTP, no API complexity, EU data center, no lock-in, 10 snapshots included.
**Cons:** Need 2 boxes for 2TB (or use BX21 for 5TB at €10.13/mo), Hetzner account required.

### 6. AWS Glacier Flexible Retrieval — $96/yr

| Metric | Value |
|--------|-------|
| Storage | $0.0036/GB/mo |
| Retrieval (standard) | $0.01/GB |
| Min duration | 90 days |
| Retrieval time | 3–5 hours (standard), minutes (expedited) |

**Pros:** Faster restore than Deep Archive, well-documented.
**Cons:** 90-day lock-in, S3 Glacier API complexity, still slow for restores.

### 7. GCS Coldline — $116/yr

| Metric | Value |
|--------|-------|
| Storage | $0.004/GB/mo |
| Retrieval | $0.02/GB |
| Min duration | 90 days |

**Pros:** Good balance of storage cost vs restore cost for Google ecosystem.
**Cons:** 90-day lock-in, Google IAM complexity, gsutil tooling.

### 8. Hetzner Storage Box BX21 (5TB) — $122/yr

| Metric | Value |
|--------|-------|
| Storage (5TB) | €10.13/mo (~$11.40/mo) |
| Egress | Free |
| Min duration | None |
| Snapshots | 20 |
| Everything else | Same as BX11 |

**Pros:** 5TB for only €7 more than 2× BX11 (2TB). Room to grow. All the same Hetzner benefits.
**Cons:** Overkill if you only need 2TB today.

### 9. Azure Blob Cold — $126/yr

| Metric | Value |
|--------|-------|
| Storage | $0.004/GB/mo |
| Retrieval | $0.03/GB |
| Min duration | 90 days |

**Pros:** Online access (no rehydration delay), Azure ecosystem.
**Cons:** 90-day lock-in, $30 restore cost for 1TB, Azure complexity.

### 10. Backblaze B2 — $167/yr

| Metric | Value |
|--------|-------|
| Storage | $6.95/TB/mo |
| Egress | Free up to 3x storage |
| Min duration | None |
| API calls | Free (Class A, B, C) |
| Free tier | First 10GB |

**Pros:** Well-proven, S3-compatible, zero API fees, great documentation, no lock-in.
**Cons:** Most expensive of the "simple" providers. 3x egress limit could matter for frequent restores.

### 11. Wasabi — $168–192/yr

| Metric | Value |
|--------|-------|
| Storage | $6.99/TB/mo ($7.99 from Jul 2026) |
| Egress | Free |
| API calls | Free |
| Min duration | 90 days |

**Pros:** Truly zero egress/API fees, S3-compatible, simple flat pricing.
**Cons:** 90-day minimum retention, price increasing Jul 2026, more expensive than Hetzner/IDrive.

### 12-15. Premium Tiers ($250-370/yr)

AWS S3 Standard-IA, GCS Nearline, Azure Blob Cool, and Cloudflare R2 are all $250-370/yr — not competitive for backup use cases. They're designed for data that needs frequent, fast access.

---

## Recommendations for SystemNix Homelab

### Best Value: Hetzner BX11 ×2 — $86/yr

- Zero restore cost, zero API complexity, native restic over SFTP
- EU data center (GDPR-friendly)
- No lock-in, no minimum retention
- Total with local USB HDD ($50 one-time): **$136 first year, $86/year after**

### Cheapest: IDrive e2 — $49/yr

- S3-compatible, works with restic
- No minimum retention
- Small provider risk — consider Hetzner for critical data

### Best Budget Combo: External HDD + Hetzner

| Component | Cost |
|-----------|------|
| External USB HDD 4TB (one-time) | $50 |
| Hetzner BX11 1TB (monthly) | $3.60/mo |
| **Year 1 total** | **$93** |
| **Year 2+ total** | **$43/yr** |

Two backup targets: local (fast restore, ransomware-proof when unplugged) + offsite (fire/theft protection).

---

_Generated May 2026 — prices verified from provider websites_
