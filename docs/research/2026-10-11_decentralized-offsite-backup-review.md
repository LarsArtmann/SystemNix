# Decentralized ("Web3") + Quantum-Secure Offsite Backup — Review

**Date:** 2026-10-11
**Status:** REVIEW COMPLETE, owner decisions pending — no config changed. The dormant Hetzner StorageBox + Borg leg (`docs/services/offsite-borg.md`) remains the chosen offsite design; this doc reviews whether a decentralized/quantum-secure alternative or addition is worth it.
**External-claims stamp:** all vendor prices/features below verified 2026-10-11 via live web research (sources at the bottom). Re-verify before acting on any price.

---

## Verdict up front

1. **"Quantum secure" is already achieved by the existing design** — Borg's client-side AES-256 at rest (symmetric = quantum-resistant) + OpenSSH 10 `mlkem768x25519` transport (default since 2025-04). No Web3 network adds any quantum security; none ships post-quantum anything (verified).
2. **"Web3 = decentralized instead of a company" was refined during the review into the real criterion: control over the DATA (= key custody), for which a company is acceptable.** The dormant Borg `repokey-blake2` leg already satisfies it: the provider holds AES-256 ciphertext only, the repo is an open self-contained format, restore needs only `borg` + the passphrase.
3. **No company-free consumer Web3 backup product exists** (verified 2026-10-11) — the backup product layer (billing, apps, restore UX) is exactly the part that re-centralizes. The decentralized part is only the storage layer.
4. **If a decentralized leg is still wanted:** Sia (self-hosted renterd, or the newer self-hosted `indexd` path) is the only operationally viable versioned-backup option (~<$1/mo storage for the ~100 GB irreplaceable set + real ops burden). Arweave complements it as a one-time-permanent seed archive (~$20 for a few GB). Storj fails the control criterion (company + Jul 2026 financial restructuring); Filecoin is architecturally mismatched for nightly incrementals.
5. **Cheapest honest alternative to all Web3:** one more independent vendor copy (~€3–4/mo) — with client-side encryption, "two unrelated vendors" already means no single company can lose or read the data.

---

## 1. What "quantum secure" actually requires

The harvest-now-decrypt-later threat targets **asymmetric** crypto (key exchange, signatures). Backup payload ciphers are symmetric and already quantum-resistant: Grover halves AES-256's effective strength to ~AES-128 — considered safe. Layer-by-layer:

| Layer | Mechanism | Quantum status (2026-10) |
| --- | --- | --- |
| Backup payload at rest | Borg `repokey-blake2`: AES-256-CTR + HMAC-SHA256, client-side keys | Quantum-resistant (symmetric) |
| Passphrase derivation | argon2 (memory-hard) | Not meaningfully weakened by known quantum algorithms |
| Transport to offsite | SSH; `mlkem768x25519-sha256` (FIPS 203 ML-KEM + X25519 hybrid) default since OpenSSH 10.0, 2025-04 | PQ-hybrid. This box already negotiates it (logged in the 2026-04-04 session status) |
| Residual gap | ed25519 SSH host/user-key *signatures* are not PQ | Active-MITM-at-session-time only; pinned `known_hosts` (`borg_known_hosts`, fail-closed) already blocks MITM. OpenSSH 10.x offers optional `mldsa44` hybrid signatures |
| Optional hardening | `age` v1.3+ ships ML-KEM hybrid keys (`age-keygen -pq`, `AGE-SECRET-KEY-PQ-1…`) | Could regenerate the sops-nix age identity for a PQ secrets envelope |
| Web3 chain crypto | ECDSA/EdDSA/RSA wallet + deal signatures on every network reviewed | Quantum-VULNERABLE — but irrelevant to data confidentiality when the client encrypts before upload |

**Conclusion:** PQ security comes from the client-side envelope, not the storage provider. It is free and already in place; a "quantum-safe" marketing label on a storage service buys nothing.

## 2. Decentralized storage landscape (prices verified 2026-10-11)

Irreplaceable offsite set ≈ 50–100 GB class today (day-1 Borg seed ~50 GB compressed per the blueprint); BX11 ceiling 1 TB.

| Network | Trust model (who holds data) | Storage cost | Restore/egress | Fit for versioned offsite backups |
| --- | --- | --- | --- | --- |
| **Sia** | Many independent, collateralized hosts; erasure-coded shards; Sia Foundation runs the chain, no company holds data | ~$1.4/TB/mo raw network avg (Q4 2025); ~$3.3/TB effective with erasure overhead; hosted app ~$2/TB/mo | Host bandwidth fees inside pricing | **Best candidate.** restic → rclone → renterd's S3 API works (verified); rclone's legacy `sia` backend is deprecated heading for removal — use the S3 route |
| **Arweave** | Permissionless miners, ~200-yr endowment; strongest "nobody can unpublish" | ~$4/GB **one-time, permanent** (≈0.9 AR/GB at AR ≈ $4.10) → 5 GB ≈ $20, 100 GB ≈ $400, 1 TB ≈ $3,600–4,100 | Free reads via gateways | Not for versioned backups (append-only; each new full = full fee again). Seed-archive niche only |
| **Filecoin** | Permissionless provider market; deals with individual providers (collateral + slashing) | Warm Storage $2.50/TiB/mo per replica + ~$0.12/data-set/mo proving (USDFC, 30-day prepay); raw deals ~$0.19–2/TB | Up to ~$14/TiB via CDN (~half from cache) | Mismatch: static immutable deals, no incremental model, no restic/borg backend, token treasury ops. Managed layers (Lighthouse) ~$20/TB/mo |
| **Storj** | Storj Labs = a company with distributed nodes | Simplified pricing from Jul 1 2026: $7/TB/mo + $7/TB egress, **$5/mo minimum fee floor**; no permanent free tier (25 GB/30-day trial) | $7/TB | **Fails the control criterion** (company; and a voluntary financial restructuring was announced Jul 2026 — bad sole-offsite counterparty). Client-side E2E AES-256-GCM though |
| **Walrus (Sui)** | Mysten Labs protocol; epoch-based | ~$0.023/GB/mo ≈ $23.5/TB/mo | Reads free | Most expensive per byte; developer-targeted |

Baseline for comparison: **Hetzner BX11 (1 TB) €3.20/mo net, already owned (sunk) — marginal €0 to go live**; unlimited traffic, free restore. BX21 (5 TB) = €10.90/mo (the hetzner research doc's "+€3.20/mo more" upgrade figure was stale — corrected in that doc 2026-10-11 to the +€7.70 delta).

## 3. Why nobody has built a company-free Web3 backup product

A consumer backup product needs billing rails, SLAs, support, and shipped apps — that *is* a company/foundation front-end. The networks decentralized the storage commodity; the trust-reducing frontier (the client) stayed open-source. Verified landscape 2026-10-11:

| Product | What it is | "No company"? |
| --- | --- | --- |
| Storj + Duplicati/Kopia/restic | Polished S3 with first-class backup-tool guides | ✗ Storj Labs (+ restructuring) |
| **Sia Storage app + s3d** | **Closest to the ask**: Sia Foundation (non-profit) consumer app (50 GB free, ~$2/TB/mo) + S3 gateway so restic/Kopia target Sia without running a node | ◑ Foundation front-end; self-hosting removes the trust point |
| Internxt | Most turnkey consumer "decentralized" cloud | ✗ decentralization mostly marketing |
| ArDrive (Arweave) | Polished pay-once-forever file storage/sync | ◑ archival, not incremental backup (no schedule/dedup/restore) |
| Züs/Vult, Filebase | S3 gateways over decentralized networks (Veeam integration on Blimp) | ✗ B2B company/foundation-run |
| Storacha (ex-web3.storage), Lighthouse, Walrus, Autonomi (ex-MaidSafe) | Developer SDKs/CLIs only; no consumer backup app | — (Autonomi most "pure" P2P design; consumer app still missing, network young) |

## 4. The control-over-data criterion (owner's refined requirement)

"A company is fine IF I have control over the data." Control decomposes into:

| Dimension | Hetzner (Borg `repokey-blake2`) | Web3 networks |
| --- | --- | --- |
| Confidentiality | Provider stores AES-256 ciphertext only; passphrase never leaves host (sops) | Same **if** encrypted client-side; plaintext otherwise |
| Integrity | HMAC-SHA256 per chunk — tampering fails loudly | Comparable (chain makes tampering evident) |
| Availability | Company can delete/lock one copy — mitigated by a second independent copy | Network can't easily delete — strongest against takedowns |
| Portability | Repo is an open self-contained format; `borg` + passphrase = full restore, provider uninvolved | SDK/format dependency varies, often worse |
| Deletion (the owner's right too) | Delete whenever | **Arweave: nobody can delete, including you** — permanence is the flip side of control |

Control = client-side keys + open format + portable repo + (for availability) more than one independent copy. The dormant leg has all but the passphrase recovery copy, which is already owner-gated in the go-live checklist (step 1) and `docs/todo/storage.md`.

## 5. Filecoin in one section

Decentralized storage marketplace (Protocol Labs, 2020). You strike **storage deals** with independent providers who collateralize stake and prove custody on-chain: **Proof-of-Replication** (sealed replica of your data), **Proof-of-Spacetime** (~24h challenges forever). Retrieval requires unsealing (slow) unless served hot via CDN. Modern onboarding = "Warm Storage / Onchain Cloud": $2.50/TiB/mo per replica + proving fees, paid in USDFC stablecoin with 30-day prepay lockup.

Ruled out for this offsite leg: it is a **static-archive protocol, not a backup protocol** — immutable deals with manual renewal, no incremental-sync model (nightly borg/restic deltas have no path), no restic/borg backend, USDFC treasury ops for ~$0.25/mo of storage, and up-to-$14/TiB restore egress. Right tool for: large, rarely-changing datasets that must survive a specific party dying (public datasets, compliance retention) — spread over 2–3 providers as occasional full archives, never nightly incrementals.

## 6. Sia deep-dive: what is Web3 and what isn't

**s3d itself is not Web3** — it is a local S3-API translator so standard tools can talk to Sia. The decentralized machinery underneath:

1. Data never lives at a company: renterd encrypts client-side (ChaCha20 per slab), erasure-codes into 30 pieces (10 data + 20 parity; any 10 reconstruct), scatters pieces across independent hosts worldwide.
2. Availability is enforced by **on-chain file contracts**, not SLAs: each host locks collateral in escrow and must submit storage proofs to keep earning Siacoin; lose data → slashed.
3. Self-custody: you hold the wallet seed + encryption keys; hosts store only encrypted shards. Permissionless hosting — no account with anyone for the storage itself.

Web2-ish caveats: the S3 shape is cosmetic compatibility; the **Foundation-hosted "Sia Storage"** variant runs the renterd/indexer and bills fiat (a trust point, albeit non-profit) — self-hosting removes it; host discovery defaults to Foundation-run indexers (self-hostable). Integration verified: **restic → rclone (type=s3 against renterd's S3 API) → Sia**; restic already runs in this repo (`restic-app-dumps` pattern). Honest footnotes: renterd needs a Siacoin buffer for contracts (small, token-volatile) and a consensus connection (own chain data or a hosted gateway = small trust point). Sia's docs now steer new self-hosts toward **`indexd`** (explicit backup/recovery docs, same key-custody story) — evaluate before committing to renterd.

## 7. Self-hosted renterd: key custody + how to back the keys up

**Verified from docs + source: the seed alone does NOT recover uploaded data.** Two artifacts:

| Artifact | What it recovers | Lost → |
| --- | --- | --- |
| **12-word seed** (BIP-39; sits plaintext in `renterd.yml`) | Wallet + Siacoin balance + file contracts | Funds gone permanently; contracts can't renew → data dies at contract expiry |
| **Bus SQLite DB** (object index + per-slab ChaCha20 keys) | Files (mapping + decryption keys) | Files unrecoverable even WITH the seed (shards exist on hosts, unusable without mapping/keys) |

Backup design mapped onto existing SystemNix patterns:

- **Seed + `renterd.yml` → offline owner-held layer:** printed paper (steel optional), **two separate physical locations**, together with the Borg passphrase recovery copy (one combined owner policy covers both — that decision is pending in `docs/todo/storage.md`). NEVER on a command line (2026-08-18 fish_history leak class); seed entry happens in an interactive editor only. A password-manager copy is a convenience mirror, not the primary.
- **Bus DB → the automated layer (pocket-id pattern):** nightly WAL-safe oneshot `sqlite3 /var/lib/renterd/bus.sqlite ".backup" /mnt/pool/backups/renterd/` + `.last_success` marker → backup-coordination → "All Backups Healthy"; rides btrbk pool receives → the offsite Borg job (already covers `/mnt/pool/backups/*` dumps); extend `services.restic-app-dumps.paths`. Keep renterd state as a plain dir under `@` (per-service subvolume doctrine class A); the live `.backup` is canonical because btrbk snapshots of a live SQLite can tear.
- **Recovery chain (print it with the seed):** Borg passphrase (offline) → restore renterd data dir + DB → seed (offline) → re-link wallet + contracts → data back. Root of trust = two offline artifacts; nothing on evo-x2 is a single point.

## 8. Costs summary (monthly unless noted; verified 2026-10-11)

| Option | ~100 GB set | 1 TB | Restore | Control |
| --- | --- | --- | --- | --- |
| Hetzner BX11 + Borg (owned, dormant) | €3.20/mo net, **marginal €0 to go live** | same (BX21 upgrade +€7.70/mo) | free, unlimited | full (client-side keys) |
| Second independent vendor (one more BX11-class bill) | ~€3–4/mo | ~€11–21 | free | full; removes single-vendor availability risk |
| Sia self-hosted (renterd/indexd) | ~<$1/mo + SC buffer + ops | ~$3.3 effective/TB | bandwidth fees | full, decentralized hosts |
| Sia Foundation-hosted app | ~$0.2/mo | ~$2/TB | included | ◑ non-profit front-end |
| Arweave seed archive (5 GB) | ~$20 one-time | 1 TB ≈ $4,000 one-time | free | full + permanence; **no deletion right** |
| Storj | $5/mo floor | $7/mo + $7/TB egress | $7/TB | company (+ restructuring) |
| Filecoin Warm Storage | ~$0.25/mo + fees | $2.50/TiB + proving | up to $14/TiB | permissionless but integration-impractical |

## 9. Recommendation

1. **Go live with the dormant Borg→Hetzner leg** (owner-gated checklist in `docs/services/offsite-borg.md`). A dormant backup protects nobody; it is the cheapest and already quantum-adequate and control-complete.
2. **Availability independence** = one more independent copy, not decentralization: either a second vendor (~€3–4/mo) or the Sia self-host leg (~<$1/mo + ops) if owning the decentralized custody story is worth the operational burden.
3. **Optional Arweave seed archive** (~$20 one-time for a few GB): Borg passphrase, vault, identity docs — uploaded client-side encrypted, accepting the surrendered deletion right for those bytes.
4. **Skip** Storj (fails control + restructuring), Filecoin (architecture mismatch), Walrus (price), Internxt (marketing).
5. **Cheap genuine PQ hardening:** regenerate the sops-nix age identity with `age v1.3` `age-keygen -pq`; OpenSSH transport already defaults to ML-KEM hybrid.

## 10. Open owner decisions

- Go-live inputs for the dormant Borg leg (tracked: "Offsite Borg go-live inputs", `docs/todo/storage.md`) — unchanged by this review.
- Decentralized leg: adopt Sia self-host as a 4th copy / second independent vendor / stay 3-2-1 → decision row in `docs/todo/storage.md`.
- Combined offline recovery-copy policy: Borg passphrase + (if adopted) Sia seed + (optional) Arweave-upload keys — paper ×2 locations.
- If Sia adopted: renterd vs the newer self-hosted `indexd` path (Sia docs' current recommendation) before building the NixOS module.

## Sources (all fetched 2026-10-11)

- Hetzner Storage Box pricing: hetzner.com/storage/storage-box (BX11 €3.20 / BX21 €10.90 net)
- Storj pricing + restructuring: storj.dev/dcs/pricing, storj.dev/dcs/pricing/simplified, storj.io/blog
- Sia network economics: messari.io "State of Sia" Q3/Q4 2025; docs.sia.tech (renterd setup, seed importance, S3 integrations, Sia Storage app); github.com/SiaFoundation/renterd (per-slab `EncryptionKey`)
- rclone/restic integration: rclone.org/sia (deprecated backend), rclone.org/commands/rclone_serve_restic, restic rclone backend blog
- Filecoin: docs.filecoin.cloud/developer-guides/storage/storage-costs (Warm Storage rates, CDN egress); lighthouse.storage cost blogs
- Arweave: ar-fees.arweave.net, coingecko.com/en/coins/arweave (AR ≈ $4.10), docs.irys.xyz
- Walrus: docs.wal.app storage costs
- PQC status: openssh.com/releasenotes (10.0 default mlkem768x25519), github.com/FiloSottile/age (v1.3 PQ keys), borgbackup/restic docs (symmetric ciphers), developers.cloudflare.com/ssl/post-quantum-cryptography
- Product landscape: storj.dev/dcs/third-party-tools (Duplicati/restic), siafoundation/sia-storage-app, ardrive.io, internxt reviews, docs.zus.network, github.com/maidsafe/autonomi, walrus.xyz, docs.lighthouse.storage
