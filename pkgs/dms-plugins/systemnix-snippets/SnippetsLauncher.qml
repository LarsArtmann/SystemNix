import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Snippets launcher plugin (PasteBot-style ⌘⇧C replacement).
//
// Contract (DMS 1.6.x launcher plugin API, same shape as dms-emoji-launcher):
//   - property var pluginService   (injected by PluginService.ensureLauncherInstance)
//   - getItems(query)  -> [{ name, comment, action, icon, categories, ... }]
//   - executeItem(item)             Enter/click action
//   - getPasteArgs(item)            Shift+Enter action (launcher sends the
//                                   paste keystroke itself after the copy exits)
//
// Storage: one file per snippet in snippetsDir (default ~/.local/share/snippets).
// Filename (minus .txt) is the snippet name; file content is the payload.
// A snippet can also be captured from the live clipboard with the query
// ":s > name" (see getItems). Editing files on disk is picked up on the
// next refresh; refresh runs when the picker opens and after each save.
QtObject {
    id: root

    property var pluginService: null
    property string trigger: ":s"

    // Populated from plugin settings (nix-managed via plugin_settings.json).
    property string snippetsDir: "~/.local/share/snippets"

    property var snippets: []           // [{ fileName, name, content, preview }]
    // Session-scoped (in-memory only): DMS 1.6.3's PluginService state
    // writer is broken ("_flushStateToDisk" createObject returns false →
    // "Property 'connect' of object false is not a function" — every
    // savePluginState call WARNs and persists nothing). Recency ordering
    // survives within a session; re-add persistence when upstream fixes the
    // state writer.
    property var recentFiles: []        // fileNames, most recent first
    property bool refreshInFlight: false
    property real lastRefreshAt: 0

    function loadSettings() {
        if (!pluginService)
            return;
        const dir = pluginService.loadPluginData("systemnix-snippets", "snippetsDir", snippetsDir);
        if (dir && dir.trim().length > 0)
            snippetsDir = dir.trim();
        refresh();
    }

    onPluginServiceChanged: {
        if (pluginService)
            loadSettings();
    }

    Component.onCompleted: loadSettings()

    function expandedDir() {
        return snippetsDir.startsWith("~/") ? (Quickshell.env("HOME") + "/" + snippetsDir.slice(2)) : snippetsDir;
    }

    // Async scan of the snippets directory. Records are framed with \x1e
    // (record separator) and \x1f (unit separator) so arbitrary multiline
    // content round-trips safely. (Assigned to a property, not declared as a
    // child: QtObject has no default property for children.)
    property Process scanProcess: Process {
        id: scanProcess
        command: ["sh", "-c",
            "DIR=\"$1\"; " +
            "for f in \"$DIR\"/*.txt; do " +
            "  [ -f \"$f\" ] || continue; " +
            "  printf '\\036%s\\037' \"${f##*/}\"; " +
            "  cat \"$f\"; " +
            "done",
            "scan", root.expandedDir()
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.lastRefreshAt = Date.now();
                root.refreshInFlight = false;
                const parsed = [];
                const records = this.text.split("\x1e");
                for (let i = 0; i < records.length; i++) {
                    const record = records[i];
                    if (!record || record.length === 0)
                        continue;
                    const sep = record.indexOf("\x1f");
                    if (sep < 0)
                        continue;
                    const fileName = record.slice(0, sep);
                    const content = record.slice(sep + 1);
                    const name = fileName.replace(/\.txt$/i, "");
                    let preview = content.split("\n")[0] || "";
                    preview = preview.trim();
                    const lineCount = content.replace(/\n+$/, "").split("\n").length;
                    if (preview.length > 80)
                        preview = preview.slice(0, 80) + "…";
                    if (preview.length === 0)
                        preview = content.trim().length > 0 ? "(multiline)" : "(empty)";
                    if (lineCount > 1)
                        preview = preview + "  ·  " + lineCount + " lines";
                    parsed.push({
                        fileName: fileName,
                        name: name,
                        content: content,
                        preview: preview
                    });
                }
                parsed.sort(function (a, b) {
                    const ra = root.recentFiles.indexOf(a.fileName);
                    const rb = root.recentFiles.indexOf(b.fileName);
                    if (ra !== -1 || rb !== -1)
                        return (ra === -1 ? 1 : 0) - (rb === -1 ? 1 : 0) || ra - rb;
                    return a.name.localeCompare(b.name);
                });
                root.snippets = parsed;
                // Deliberately NO savePluginState here — see recentFiles note
                // above (upstream state writer is broken in DMS 1.6.3).
            }
        }
    }

    function refresh() {
        if (refreshInFlight)
            return;
        refreshInFlight = true;
        scanProcess.running = true;
    }

    function maybeRefresh() {
        if (Date.now() - lastRefreshAt > 2000)
            refresh();
    }

    function slugify(name) {
        let slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
        if (slug.length === 0)
            slug = "snippet-" + Date.now();
        return slug;
    }

    function score(snippet, lowerQuery, tokens) {
        const lowerName = snippet.name.toLowerCase();
        let score = 0;
        if (lowerName.startsWith(lowerQuery))
            score = 100;
        else if (lowerName.includes(lowerQuery))
            score = 70;
        else if (snippet.content.toLowerCase().includes(lowerQuery))
            score = 40;
        else
            return 0;
        for (let i = 0; i < tokens.length; i++) {
            if (!lowerName.includes(tokens[i]) && !snippet.content.toLowerCase().includes(tokens[i]))
                return 0;
        }
        return score;
    }

    function getItems(query) {
        maybeRefresh();

        const trimmed = (query || "").trim();

        // Save mode: ":s > name" captures the live clipboard as a new snippet.
        if (trimmed.startsWith(">")) {
            const name = trimmed.slice(1).trim();
            if (name.length === 0) {
                return [{
                    name: "Type a name after > to save the clipboard",
                    comment: "Example: " + trigger + " > standup update",
                    action: "hint",
                    icon: "info",
                    categories: ["Snippets"]
                }];
            }
            return [{
                name: "Save clipboard as \u201C" + name + "\u201D",
                comment: "Writes " + expandedDir() + "/" + slugify(name) + ".txt",
                action: "save",
                icon: "save",
                categories: ["Snippets"],
                _saveName: name,
                _saveSlug: slugify(name)
            }];
        }

        const lowerQuery = trimmed.toLowerCase();
        const tokens = lowerQuery.length > 0 ? lowerQuery.split(/\s+/) : [];
        const items = [];

        for (let i = 0; i < snippets.length; i++) {
            const snippet = snippets[i];
            const relevance = lowerQuery.length === 0 ? 1 : score(snippet, lowerQuery, tokens);
            if (relevance === 0)
                continue;
            items.push({
                name: snippet.name,
                comment: snippet.preview,
                action: "paste",
                icon: "text_snippet",
                categories: ["Snippets"],
                _content: snippet.content,
                _fileName: snippet.fileName,
                _preScored: relevance
            });
        }

        if (lowerQuery.length > 0)
            items.sort(function (a, b) { return b._preScored - a._preScored; });

        if (items.length === 0 && lowerQuery.length === 0) {
            items.push({
                name: "No snippets yet",
                comment: "Copy text anywhere, then type " + trigger + " > name — or add files to " + expandedDir(),
                action: "hint",
                icon: "info",
                categories: ["Snippets"]
            });
        }

        return items.slice(0, 50);
    }

    function trackRecent(fileName) {
        const next = recentFiles.filter(function (f) { return f !== fileName; });
        next.unshift(fileName);
        if (next.length > 10)
            next.length = 10;
        recentFiles = next;
    }

    // PasteBot-style Enter: copy into the DMS clipboard (which also records
    // it in history), give the launcher time to close and return focus, then
    // synthesize Ctrl+V via the compositor's virtual-keyboard protocol
    // (dms cl send-paste — no wtype, no uinput permissions needed).
    // $1 carries the content as argv, never interpolated into the script.
    function pasteCommand() {
        return "printf '%s' \"$1\" | setsid dms cl copy; sleep 0.3; dms cl send-paste";
    }

    function executeItem(item) {
        if (!item || !item.action)
            return;
        switch (item.action) {
        case "paste":
            Quickshell.execDetached(["sh", "-c", pasteCommand(), "snippet-paste", item._content || ""]);
            ToastService?.showInfo("Pasted snippet: " + item.name);
            trackRecent(item._fileName);
            break;
        case "save":
            saveProcess.saveName = item._saveName;
            saveProcess.saveSlug = item._saveSlug;
            saveProcess.running = true;
            break;
        }
    }

    // The launcher's native Shift+Enter path: it runs these args, then sends
    // the paste keystroke itself once the process exits (Controller copyProcess).
    function getPasteArgs(item) {
        if (!item || item.action !== "paste")
            return null;
        return ["sh", "-c", "printf '%s' \"$1\" | setsid dms cl copy", "snippet-copy", item._content || ""];
    }

    // "dms cl paste" streams the live clipboard to stdout; we write it into
    // the snippets directory. Runs in the DMS session env (WAYLAND_DISPLAY).
    // chmod 600: saved clipboard content can carry secrets; snippets live
    // inside the snapshotted @ home subvol — keep files owner-only.
    property Process saveProcess: Process {
        id: saveProcess
        property string saveName: ""
        property string saveSlug: ""
        command: ["sh", "-c",
            "DIR=\"$1\"; NAME=\"$2\"; " +
            "mkdir -p \"$DIR\" && dms cl paste > \"$DIR/$NAME.txt\" && chmod 600 \"$DIR/$NAME.txt\" && echo saved",
            "save", root.expandedDir(), saveSlug
        ]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                root.refresh();
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0)
                ToastService?.showInfo("Snippet saved: " + saveName);
            else
                ToastService?.showError("Failed to save snippet (exit " + exitCode + ")");
        }
    }
}
