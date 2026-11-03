import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-sops"

    StringSetting {
        settingKey: "secretsDir"
        label: "Sops secrets symlink directory"
        defaultValue: "/run/secrets"
    }

    StringSetting {
        // The render farm mount point (liveness signal). The old "sopsFile"
        // key pointed at a path that never exists under age.sshKeyPaths
        // mode — superb-v3 S-0006.
        settingKey: "farmDir"
        label: "Sops render farm mount point"
        defaultValue: "/run/secrets.d"
    }
}
