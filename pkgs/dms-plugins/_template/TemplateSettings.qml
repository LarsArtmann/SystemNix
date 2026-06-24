import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-template"

    StringSetting {
        settingKey: "apiUrl"
        label: "API URL"
        defaultValue: "http://127.0.0.1:8080"
    }
}
