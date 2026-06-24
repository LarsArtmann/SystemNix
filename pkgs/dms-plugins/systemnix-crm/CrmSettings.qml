import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-crm"

    StringSetting {
        settingKey: "crmUrl"
        label: "Twenty CRM URL"
        defaultValue: "http://127.0.0.1:3200"
    }
}
