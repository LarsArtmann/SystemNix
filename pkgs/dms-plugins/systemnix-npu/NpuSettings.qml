import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-npu"

    StringSetting {
        settingKey: "devfreqPath"
        label: "devfreq sysfs path"
        defaultValue: "/sys/class/devfreq"
    }
}
