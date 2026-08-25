import QtQuick
import Quickshell.Services.Pipewire

import "../theme"

/*
 * Status only — see BatteryIcon.
 */
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink

    readonly property var audio: root.sink?.audio ?? null

    readonly property bool muted: root.audio !== null && root.audio.muted

    readonly property real volume: root.audio !== null ? root.audio.volume : 0

    /*
     * Audio properties are only populated on bound nodes.
     */
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    width: 24
    height: 24

    visible: root.audio !== null

    Text {
        anchors.centerIn: parent

        text: {
            if (root.muted)
                return "󰝟";

            if (root.volume >= 0.5)
                return "󰕾";

            if (root.volume > 0)
                return "󰖀";

            return "󰕿";
        }

        color: root.muted ? Colors.subtext : Colors.text

        font.pixelSize: 14

        textFormat: Text.PlainText

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }
}
