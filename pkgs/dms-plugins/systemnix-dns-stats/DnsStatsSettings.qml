import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-dns-stats"

    StringSetting {
        settingKey: "statsUrl"
        label: "DNS Blocker Stats URL"
        defaultValue: "http://127.0.0.1:9090/stats"
    }
}
