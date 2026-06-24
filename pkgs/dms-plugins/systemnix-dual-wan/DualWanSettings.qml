import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-dual-wan"

    StringSetting {
        settingKey: "primaryIface"
        label: "Primary WAN interface"
        defaultValue: "enp2s0"
    }

    StringSetting {
        settingKey: "secondaryIface"
        label: "Secondary WAN interface"
        defaultValue: "wlp1s0"
    }
}
