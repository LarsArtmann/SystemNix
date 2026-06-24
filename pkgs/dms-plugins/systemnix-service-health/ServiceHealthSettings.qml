import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-service-health"

    StringSetting {
        settingKey: "gatusUrl"
        label: "Gatus statuses URL"
        defaultValue: "http://127.0.0.1:9110/api/v1/endpoints/statuses"
    }
}
