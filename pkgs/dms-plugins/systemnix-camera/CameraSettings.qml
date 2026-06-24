import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-camera"

    StringSetting {
        settingKey: "daemonUrl"
        label: "eMeet Pixy daemon URL"
        defaultValue: "http://127.0.0.1:8090"
    }
}
