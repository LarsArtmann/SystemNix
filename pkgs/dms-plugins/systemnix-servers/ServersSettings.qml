import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-servers"

    StringSetting {
        settingKey: "diskMount"
        label: "Disk mount to monitor"
        defaultValue: "/"
    }
}
