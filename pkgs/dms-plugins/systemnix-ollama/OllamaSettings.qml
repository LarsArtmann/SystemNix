import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-ollama"

    StringSetting {
        settingKey: "apiBase"
        label: "Ollama API URL"
        defaultValue: "http://127.0.0.1:11434"
    }

    StringSetting {
        settingKey: "pollInterval"
        label: "Poll interval (ms)"
        defaultValue: "5000"
    }
}
