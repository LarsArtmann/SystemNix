# ActivityWatch Comprehensive Analysis & Recommendations

**Date:** February 27, 2026 15:32 CET
**Project:** SystemNix
**Status:** Window URL Fix Applied - Further Enhancements Researched
**Classification:** Strategic Technology Assessment

---

## Executive Summary

Following the successful resolution of ActivityWatch's window URL tracking issue (via `just activitywatch-fix-permissions`), this report documents comprehensive research into the broader ActivityWatch plugin ecosystem. **43+ plugins** were analyzed across 10 categories, with particular focus on advanced/experimental watchers that could significantly enhance tracking capabilities.

**Key Finding:** ActivityWatch's ecosystem has matured far beyond basic time tracking, offering AI-powered context extraction, screenshot documentation, hardware integration, and psychological self-monitoring tools.

---

## Current System State

### ✅ Resolved Issues

| Issue                             | Solution Applied                     | Status        |
| --------------------------------- | ------------------------------------ | ------------- |
| Empty URLs in `aw-watcher-window` | `just activitywatch-fix-permissions` | ✅ Fixed      |
| macOS Accessibility permissions   | TCC reset + manual GUI approval      | ✅ Complete   |
| Permission persistence            | TCC configuration profile created    | ✅ Documented |

### 📊 Current Active Watchers

Based on system configuration, the following watchers are operational:

| Watcher                 | Type    | Data Captured                          | Status       |
| ----------------------- | ------- | -------------------------------------- | ------------ |
| `aw-watcher-afk`        | Core    | Mouse/keyboard inactivity (3min AFK)   | ✅ Active    |
| `aw-watcher-window`     | Core    | Window title, app name, URL            | ✅ Fixed     |
| `aw-watcher-web-chrome` | Browser | Tab title, URL, audio state, incognito | ✅ Active    |
| `aw-watcher-input`      | System  | Keystroke count, mouse distance        | ✅ Available |

---

## Advanced/Experimental Watchers - Deep Analysis

### 1. aw-watcher-enhanced (kepptic) ⭐ HIGHLY RECOMMENDED

**Repository:** `kepptic/aw-watcher-enhanced`
**Status:** Alpha (v0.1.0) - **Actively Developed (Jan 2026)**
**Language:** Python
**Stars:** 11

#### Capabilities

| Feature            | Technology                                     | Performance            |
| ------------------ | ---------------------------------------------- | ---------------------- |
| **Smart OCR**      | Apple Vision (macOS) / Windows OCR / Tesseract | ~100-800ms             |
| **LLM Context**    | Ollama (local) / Claude / OpenAI               | ~2-3s analysis         |
| **Smart Idle**     | Activity detection                             | Reduces resource usage |
| **Remote Desktop** | RDP/Citrix/TeamViewer support                  | Full tracking          |
| **Multi-Monitor**  | All displays captured                          | Synchronized           |

#### OCR Technology Stack

| Platform    | Library                    | Speed  | Accuracy   |
| ----------- | -------------------------- | ------ | ---------- |
| macOS       | Apple Vision (`ocrmac`)    | ~100ms | ⭐⭐⭐⭐⭐ |
| Windows     | Windows OCR API (`winocr`) | ~200ms | ⭐⭐⭐⭐   |
| Windows Alt | RapidOCR                   | ~400ms | ⭐⭐⭐⭐   |
| Fallback    | Tesseract                  | ~800ms | ⭐⭐⭐     |

#### LLM Context Extraction

Uses **text-based LLM** (not vision models) for efficiency:

```
Screen Capture → OCR Text → LLM Analysis → Structured JSON
                     ↓
              Window title prepended
              for context
```

**Extracted Fields:**

- `document` - Filename, webpage title, repo name
- `client` - Client codes (e.g., "ACME01")
- `project` - Project name, ticket ID, task
- `url` - Full URL if visible
- `breadcrumb` - Navigation path
- `keywords` - 3-5 topic descriptors

**Example Output:**

```json
{
  "app": "Microsoft Excel",
  "title": "Budget Report.xlsx - Excel",
  "llm_document": "Budget Report.xlsx",
  "llm_client": "ACME01",
  "llm_project": "Q4 Planning",
  "ocr_keywords": ["budget", "revenue", "forecast"],
  "category": "Work/Data/Spreadsheets"
}
```

#### Requirements

- Python 3.9+ (3.11/3.12 recommended)
- ActivityWatch running
- **Ollama** for LLM features: `ollama pull gemma3:4b`
- Platform-specific OCR libraries

#### Performance

| Metric         | Value                                                |
| -------------- | ---------------------------------------------------- |
| Memory         | ~50-100MB                                            |
| CPU            | <5% average                                          |
| OCR            | ~100ms (Apple Silicon Neural Engine)                 |
| LLM            | ~2-3s per analysis                                   |
| Diff Detection | 85% similarity threshold (skips redundant LLM calls) |

#### Recommendation

**PRIORITY: HIGH** - This watcher represents a paradigm shift from simple time tracking to AI-powered activity understanding. The January 2026 release date indicates active development. Ideal for knowledge workers who need context-rich productivity data.

---

### 2. aw-watcher-screenshot (InertialG) ⭐ VISUAL DOCUMENTATION

**Repository:** `InertialG/aw-watcher-screenshot`
**Status:** v0.1.0 - **Very New (Jan 8, 2026)**
**Language:** Rust (100%)
**Stars:** 5

#### Capabilities

| Feature             | Implementation             | Notes                              |
| ------------------- | -------------------------- | ---------------------------------- |
| **Multi-Monitor**   | Hot-plug detection         | Handles monitor changes at runtime |
| **Smart Filtering** | Perceptual hashing (dhash) | Skips unchanged screens            |
| **Compression**     | WebP encoding              | Lossy/lossless, quality adjustable |
| **Storage**         | Local cache + Optional S3  | S3/R2/MinIO compatible             |
| **Integration**     | ActivityWatch heartbeats   | Tracks when screenshots taken      |

#### Pipeline Architecture

```
TimerCaptureProducer → FilterProcessor → ToWebpProcessor → S3/Passthrough → AwServerProcessor
```

#### Configuration Example

```toml
[trigger]
interval_secs = 2        # Screenshot every 2 seconds
force_interval_secs = 60 # Force capture even if unchanged

[capture]
dhash_threshold = 10     # Hamming distance threshold (0-64)

[cache]
cache_dir = "cache"
webp_quality = 75        # 1-100 (100=lossless)

[s3]
enabled = false          # Keep local only for privacy
```

#### Storage Implications

| Interval | Screenshots/Hour | WebP Size (est.) | Daily Storage |
| -------- | ---------------- | ---------------- | ------------- |
| 2s       | 1,800            | ~50KB            | ~86MB         |
| 5s       | 720              | ~50KB            | ~34MB         |
| 60s      | 60               | ~50KB            | ~3MB          |

**⚠️ Warning:** Fast intervals accumulate significant storage. Plan for 1-3GB/month at 2-second intervals.

#### Use Cases

- Visual documentation of work sessions
- Activity reconstruction for billing/auditing
- Detailed work session review
- Security/compliance requirements
- Creative process tracking (designers, developers)

#### Recommendation

**PRIORITY: MEDIUM** - Powerful for specific use cases but requires storage planning. The Rust implementation suggests performance is a priority. Best for: consultants billing by the hour, security-conscious environments, creative professionals documenting work.

---

### 3. aw-watcher-ask (bcbernardo) 🗣️ SELF-REFLECTION

**Repository:** `bcbernardo/aw-watcher-ask`
**Status:** v0.1.0 (Stable)
**Language:** Python
**Stars:** 83

#### Capabilities

**Experience Sampling Method (ESM)** implementation:

- **Zenity dialog boxes** pop up on schedule
- **Cron-like scheduling** for questions
- **Multiple question types** (yes/no, scale, entry)
- **Answer storage** in ActivityWatch
- **Timeout support** (dialogs auto-close)

#### How It Works

```bash
aw-watcher-ask run \
  --question-id "happiness.level" \
  --question-type="question" \
  --title="My happiness level" \
  --text="Are you feeling happy right now?" \
  --timeout=120 \
  --schedule "0 */1 * * * 0"  # Every hour
```

**Question Types:**

- `question` - Yes/No dialog
- `entry` - Text input
- `scale` - Numeric rating
- `list` - Selection from list (not implemented)

#### Data Structure

Stored in `aw-watcher-ask_localhost.localdomain` bucket:

```json
{
  "question_id": "happiness.level",
  "answer": "Yes",
  "timestamp": "2026-02-27T15:30:00Z"
}
```

#### Requirements

- **Zenity** must be installed: `brew install zenity` (macOS)
- ActivityWatch running
- Manual scheduling setup (no built-in persistence)

#### Use Cases

- **Mood tracking** throughout the day
- **Productivity self-assessment** ("How focused are you?")
- **Pain/energy level** logging (health tracking)
- **Experience sampling** for psychological studies
- **Habit tracking** ("Did you exercise today?")

#### Recommendation

**PRIORITY: MEDIUM** - Simple to implement, high psychological value. Best for: self-improvement enthusiasts, quantified self practitioners, health tracking.

---

### 4. aw-watcher-table (Alwinator) 🪑 HARDWARE INTEGRATION

**Repository:** `Alwinator/aw-watcher-table`
**Status:** v1.2.0 (Maintenance Mode)
**Language:** Python + Arduino C++
**Stars:** 56

#### Capabilities

**Standing Desk Position Tracking** via DIY hardware:

- **HC-SR04 Ultrasonic Sensor** measures distance to floor
- **ESP8266 Microcontroller** provides WiFi + HTTP endpoint
- **Height calculation** determines sitting vs standing
- **Position changes** logged to ActivityWatch

#### Hardware Requirements

| Component       | Cost     | Purpose                         |
| --------------- | -------- | ------------------------------- |
| ESP8266         | €6.50    | WiFi microcontroller            |
| HC-SR04 Sensor  | €5.16    | Ultrasonic distance measurement |
| 3D Printed Case | ~€0.25   | Mounting enclosure              |
| **Total**       | **~€12** |                                 |

**Pin Configuration (ESP8266):**

- `TRIGGER_PIN` → D5 (GPIO 14)
- `ECHO_PIN` → D6 (GPIO 12)

#### How It Works

```cpp
// ESP8266 code excerpt
int measure_table_height() {  // in cm
  digitalWrite(TRIGGER_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIGGER_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIGGER_PIN, LOW);
  return pulseIn(ECHO_PIN, HIGH) * 0.01715;
}
```

Python watcher polls `http://192.168.x.x/measure` → `{"table_height": 128}`

#### Use Cases

- **Health tracking** - Monitor sitting time, enforce stand breaks
- **Posture analysis** - Correlate standing with productivity
- **Standing desk ROI** - Prove usage to justify purchase
- **Ergonomic research** - Long-term posture impact study

#### Recommendation

**PRIORITY: LOW** - Requires DIY hardware assembly. Best for: standing desk owners, health-conscious workers, DIY enthusiasts. The maintenance mode status (last commit Nov 2023) suggests limited future development.

---

### 5. aw-watcher-anki (abdnh) 🎴 STUDY TRACKING

**Repository:** `abdnh/aw-watcher-anki`
**Status:** v0.0.2 (Stable)
**Language:** Python (Anki add-on)
**Stars:** 27

#### Capabilities

**Anki Flashcard Study Session Tracking:**

- Anki add-on (install via AnkiWeb)
- Tracks **active review sessions** only
- Records card ID, note ID, deck name
- 60-second heartbeat pulsetime

#### Installation

AnkiWeb code: `567877061`

Anki → Tools → Add-ons → Get Add-ons → Enter code

#### Data Tracked

```json
{
  "cid": 123456789,
  "nid": 987654321,
  "deck": "Medical School::Anatomy"
}
```

#### Requirements

- Anki 2.1.x
- ActivityWatch must be running when Anki starts
- Add-on auto-connects to localhost:5600

#### Use Cases

- **Study time analytics** - Track hours per deck
- **Spaced repetition optimization** - Correlate time with retention
- **Exam preparation** - Monitor study consistency
- **Language learning** - Track daily practice time

#### Recommendation

**PRIORITY: LOW** - Only relevant if you use Anki. Best for: students, language learners, medical/law students using spaced repetition.

---

## Additional High-Value Watchers

### System Monitoring

| Watcher                    | Repository                           | What It Tracks                   | Recommendation                                          |
| -------------------------- | ------------------------------------ | -------------------------------- | ------------------------------------------------------- |
| **aw-watcher-utilization** | `Alwinator/aw-watcher-utilization`   | CPU, RAM, disk, network, sensors | ⭐ HIGH - Production ready (100 stars, active Oct 2024) |
| **aw-watcher-netstatus**   | `sameersismail/aw-watcher-netstatus` | Online/offline status            | ⚠️ LOW - Minimal, stale (Jan 2023)                       |

**Note:** `aw-watcher-utilization` is recommended over `aw-watcher-netstatus` since it includes network I/O counters plus comprehensive system metrics.

### Media Tracking

| Watcher                     | Repository                     | Platform | Status                     |
| --------------------------- | ------------------------------ | -------- | -------------------------- |
| **aw-watcher-spotify**      | Official                       | All      | Beta - Web API integration |
| **aw-watcher-lastfm**       | `brayo-pip/aw-watcher-lastfm`  | All      | Cross-platform music       |
| **aw-watcher-media-player** | `2e3s/aw-watcher-media-player` | Linux    | MPRIS system integration   |

### Editor Integration (If Not Already Configured)

| Editor                           | Repository                         | Status                |
| -------------------------------- | ---------------------------------- | --------------------- |
| **JetBrains** (GoLand, IntelliJ) | `OlivierMary/aw-watcher-jetbrains` | ⭐ HIGHLY RECOMMENDED |
| **Neovim**                       | `lowitea/aw-watcher.nvim`          | Lua-based, modern     |
| **VS Code**                      | Official                           | Marketplace available |
| **Zed**                          | `sachk/aw-watcher-zed`             | New editor support    |
| **Emacs**                        | `pauldub/activity-watch-mode`      | Emacs Lisp            |

---

## Implementation Recommendations

### Phase 1: Immediate (High Impact, Low Effort)

| Watcher                  | Effort | Impact | Action                                                             |
| ------------------------ | ------ | ------ | ------------------------------------------------------------------ |
| `aw-watcher-utilization` | Low    | High   | `pip install aw-watcher-utilization`                               |
| `aw-watcher-jetbrains`   | Low    | High   | Install via JetBrains Marketplace                                  |
| `aw-watcher-ask`         | Low    | Medium | `pip install git+https://github.com/bcbernardo/aw-watcher-ask.git` |

### Phase 2: Short Term (High Impact, Medium Effort)

| Watcher               | Effort | Impact    | Considerations                       |
| --------------------- | ------ | --------- | ------------------------------------ |
| `aw-watcher-enhanced` | Medium | Very High | Requires Ollama setup, AI processing |
| `aw-watcher-spotify`  | Low    | Medium    | Only if you use Spotify              |
| `aw-watcher-neovim`   | Low    | High      | If you use Neovim                    |

### Phase 3: Experimental (High Impact, High Effort)

| Watcher                 | Effort | Impact | Considerations            |
| ----------------------- | ------ | ------ | ------------------------- |
| `aw-watcher-screenshot` | Medium | High   | Storage planning required |
| `aw-watcher-table`      | High   | Medium | DIY hardware assembly     |
| `aw-watcher-anki`       | Low    | Low    | Only if you use Anki      |

---

## Technical Architecture Notes

### watcher-enhanced Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    aw-watcher-enhanced                       │
├─────────────────────────────────────────────────────────────┤
│  Screen Capture (mss)                                        │
│       ↓                                                      │
│  OCR Extraction ──┬──► Apple Vision (macOS) ──┐             │
│                   ├──► Windows OCR (Windows)  ├──► Text     │
│                   └──► Tesseract (fallback)   │             │
│                                                 ↓            │
│  Title Enhancement ◄── Window title bar text ─┘             │
│       ↓                                                      │
│  LLM Analysis ──┬──► Ollama (local) ──┐                     │
│                 ├──► Claude (cloud)   ├──► Structured JSON  │
│                 └──► OpenAI (cloud)   │                     │
│                                         ↓                    │
│  Diff Detection ◄── 85% similarity threshold                 │
│       ↓                                                      │
│  ActivityWatch Heartbeat → aw-watcher-enhanced bucket       │
└─────────────────────────────────────────────────────────────┘
```

### watcher-screenshot Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   aw-watcher-screenshot                      │
│                      (Rust Implementation)                   │
├─────────────────────────────────────────────────────────────┤
│  Timer Capture Producer ──► Every N seconds                  │
│       ↓                                                      │
│  Filter Processor ──► Perceptual hash (dhash)               │
│       ↓                                                      │
│  WebP Processor ──► Compress with quality setting           │
│       ↓                                                      │
│  Storage Router ──┬──► Local Cache (configurable dir)       │
│                   └──► S3/R2/MinIO (optional)               │
│       ↓                                                      │
│  ActivityWatch Heartbeat ──► Screenshot metadata            │
└─────────────────────────────────────────────────────────────┘
```

---

## Privacy & Security Considerations

| Watcher                 | Privacy Level | Data Sensitivity                | Mitigation                                  |
| ----------------------- | ------------- | ------------------------------- | ------------------------------------------- |
| `aw-watcher-enhanced`   | Medium        | OCR captures all on-screen text | Local LLM (Ollama) keeps data on-device     |
| `aw-watcher-screenshot` | High          | Full screen captures            | Keep local only (disable S3), encrypt cache |
| `aw-watcher-ask`        | Low           | Self-reported answers           | Stored locally in ActivityWatch             |
| `aw-watcher-window`     | Low           | Window titles, URLs             | Already active, standard tracking           |

**Recommendations:**

- Use **Ollama (local LLM)** for `aw-watcher-enhanced` to avoid cloud processing
- Disable **S3 upload** in `aw-watcher-screenshot` unless cloud backup required
- Regularly **audit screenshot cache** for sensitive information
- Consider **encryption** for screenshot storage directory

---

## Resource Requirements Summary

| Watcher                  | Memory   | CPU | Disk        | Network       |
| ------------------------ | -------- | --- | ----------- | ------------- |
| `aw-watcher-enhanced`    | 50-100MB | <5% | Minimal     | Local only    |
| `aw-watcher-screenshot`  | ~50MB    | <5% | 1-3GB/month | If S3 enabled |
| `aw-watcher-utilization` | ~20MB    | <2% | Minimal     | None          |
| `aw-watcher-ask`         | ~10MB    | <1% | Minimal     | None          |
| `aw-watcher-table`       | ~15MB    | <1% | Minimal     | Local WiFi    |

---

## Conclusion & Next Steps

### Immediate Actions (This Week)

1. **Install `aw-watcher-utilization`** for comprehensive system monitoring
2. **Install JetBrains watcher** (if using GoLand/IntelliJ) for detailed coding metrics
3. **Evaluate `aw-watcher-enhanced`** - Install Ollama and test locally

### Short Term (Next Month)

1. **Deploy `aw-watcher-screenshot`** if visual documentation needed (plan storage)
2. **Configure `aw-watcher-ask`** for mood/productivity self-monitoring
3. **Add media watchers** (Spotify) if relevant to your workflow

### Long Term (Ongoing)

1. **Monitor `aw-watcher-enhanced` development** - This represents the future of intelligent time tracking
2. **Evaluate screenshot storage** - Implement retention policies if storage grows
3. **Consider custom watchers** - ActivityWatch's REST API makes custom tracking straightforward

### Key Insight

ActivityWatch has evolved from a simple time tracker to a **comprehensive activity intelligence platform**. The combination of:

- ✅ Fixed window/URL tracking (done)
- 🔄 AI-powered context extraction (aw-watcher-enhanced)
- 🔄 Visual documentation (aw-watcher-screenshot)
- 🔄 System resource correlation (aw-watcher-utilization)
- 🔄 Self-reported metrics (aw-watcher-ask)

...provides unprecedented visibility into knowledge work patterns.

---

## References

- **Window URL Fix Report:** `docs/status/2026-02-11_02-31_ACTIVITYWATCH-URL-TRACKING-INVESTIGATION.md`
- **Plugin Ecosystem Research:** `/Users/larsartmann/projects/reports/ActivityWatch_GitHub_Research_Report.md`
- **Official Documentation:** https://docs.activitywatch.net/
- **GitHub Organization:** https://github.com/ActivityWatch

---

**Report Generated:** 2026-02-27 15:32 CET
**Author:** SystemNix Configuration System
**Classification:** Internal Strategic Assessment
**Next Review:** As needed based on implementation progress
