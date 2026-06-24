import QtQuick
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "systemnix-voice-agent"

    StringSetting { settingKey: "whisperUrl"; label: "Whisper URL"; defaultValue: "http://127.0.0.1:7860" }
    StringSetting { settingKey: "livekitUrl"; label: "LiveKit URL"; defaultValue: "http://127.0.0.1:7880" }
}
