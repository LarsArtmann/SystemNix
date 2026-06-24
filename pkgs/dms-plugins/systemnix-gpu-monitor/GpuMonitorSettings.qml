import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-gpu-monitor"

    StringSetting {
        settingKey: "cardPath"
        label: "GPU sysfs path"
        defaultValue: "/sys/class/drm/card0/device"
    }
}
