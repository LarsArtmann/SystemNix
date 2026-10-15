import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-snippets"

    StringSetting {
        settingKey: "snippetsDir"
        label: "Snippets directory"
        description: "One .txt file per snippet: filename is the name, content is the text to paste. Create snippets from the launcher with :s > name (saves the current clipboard), or by adding files here."
        placeholder: "~/.local/share/snippets"
        defaultValue: "~/.local/share/snippets"
    }
}
