import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-task-radar"

    StringSetting {
        settingKey: "apiUrl"
        label: "Taskchampion API URL"
        defaultValue: "http://127.0.0.1:10222"
    }
}
