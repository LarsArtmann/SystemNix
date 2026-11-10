import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-banner"

    StringSetting {
        settingKey: "consumerPath"
        label: "Consumer script path"
        defaultValue: ""
    }

    StringSetting {
        settingKey: "maxAge"
        label: "Stale heartbeat threshold (seconds)"
        defaultValue: "15"
    }
}
