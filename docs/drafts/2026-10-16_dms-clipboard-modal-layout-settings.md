# Draft: DMS feature request — clipboard modal layout settings

- **Target:** `gh issue create --repo AvengeMedia/DankMaterialShell`
- **Title:** Clipboard modal: expose item height, preview line count, and per-row type caption as settings
- **Kind:** feature request (unsolicited, AI-found) — banner + TL;DR + footer required
- **Status:** DRAFT — awaiting Lars review (tick the banner box on publish)
- **Verified:** 2026-10-16 against master `b08f3f8`; local runtime behavior verified live on DMS 1.6.3 (`4a87e822`)

---

```markdown
> [!NOTE]
> This filing was drafted by GLM-5.3 via Crush from an AI-run investigation, not at my request. When the failure traces to an external report, that source is linked in the body.
>
> - [ ] MANUALLY REVIEWED by `@Lars Artmann` at `[<date-time>]`

**TL;DR:** Three clipboard-modal layout properties are hardcoded constants, so packagers who want denser rows or richer previews must patch QML at build time. Please expose them as settings: `clipboardItemHeight`, `clipboardPreviewLines`, and a `clipboardShowTypeCaptions` toggle.

## Problem

On 1.6.3 I patch three values in `ClipboardConstants.qml` / `ClipboardEntry.qml` post-install to make the history usable as a paste-first picker (PasteBot-style), because they are constants:

Entry height — `quickshell/Modals/Clipboard/ClipboardConstants.qml` (master `b08f3f8`):

```qml
readonly property int itemHeight: 72
```

Preview truncates plain-text entries to one line — `quickshell/Modals/Clipboard/ClipboardEntry.qml` (master `b08f3f8`):

```qml
maximumLineCount: entryType === "long_text" ? 3 : 1
```

Every plain-text row carries a "Text" caption above the content (same file):

```qml
case "long_text":
    return I18n.tr("Long Text");
default:
    return I18n.tr("Text");
```

With 72px rows, one preview line, and a caption line on every entry, a 650x550 modal shows ~5 usable entries and ~40 characters of each. Denser rows (68px) plus two preview lines fit the same space and roughly double the visible content per entry — I run exactly that via patches and it is the difference between "open, scan, Enter" and "scroll, squint, misclick".

## Proposal

Three settings in the existing clipboard block of `SettingsSpec.js` (next to `clipboardSize` / `clipboardEnterToPaste`, which already solved this class for other properties):

- `clipboardItemHeight` (int, default 72) — or a density enum if that fits the settings UI better
- `clipboardPreviewLines` (int, default 1) — replaces the hardcoded branch above; `long_text` could keep `max(3, clipboardPreviewLines)`
- `clipboardShowTypeCaptions` (bool, default true) — captions carry information for `image` / `long_text` groups but are noise on rows that are 95% plain text

Modal dimensions are already covered by `clipboardSize`, so this is deliberately only the per-entry layout trio.

## Alternatives considered

- Patching at package time (current workaround): works, but every DMS bump re-derives patch anchors, and it is invisible to everyone who is not a packager.
- `previewLength` in `ClipboardConstants.qml` covers characters-per-line, not lines — it does not address vertical density.

## Environment

DMS 1.6.3 (`4a87e822`, NixOS packaging), behavior re-verified against master `b08f3f8` before filing.

💘 Generated with Crush
```
