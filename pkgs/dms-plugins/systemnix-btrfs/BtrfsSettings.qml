import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-btrfs"

    StringSetting {
        settingKey: "timerName"
        label: "systemd timer name"
        defaultValue: "btrbk.timer"
    }
}
