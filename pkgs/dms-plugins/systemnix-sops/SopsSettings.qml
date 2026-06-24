import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-sops"

    StringSetting {
        settingKey: "secretsDir"
        label: "Sops secrets mount directory"
        defaultValue: "/run/secrets"
    }

    StringSetting {
        settingKey: "sopsFile"
        label: "Sops age key file path"
        defaultValue: "/run/secrets/sops-nix-age-key"
    }
}
