import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

import "../theme"
import "../shared/components"

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

    // ============================================================
    // OUTPUT KIND
    //
    // "speaker" | "headphones" | "headset".
    //
    // PipeWire does not put this on the node: plugging headphones
    // into the built-in card switches the *route* on the device and
    // leaves the sink node byte-for-byte identical, so watching the
    // node tells you nothing. The active port does, and only pactl
    // exposes it — PwNode has no port or route API.
    // ============================================================

    property string outputKind: "speaker"

    readonly property string outputLabel: {
        if (root.outputKind === "headset")
            return "Headset";

        if (root.outputKind === "headphones")
            return "Headphones";

        return "Speakers";
    }

    Process {
        id: portProcess

        command: ["pactl", "--format=json", "list", "sinks"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.applyPorts(this.text);
            }
        }
    }

    function refreshPort() {
        portProcess.running = false;
        portProcess.running = true;
    }

    function applyPorts(raw) {
        const name = root.sink?.name ?? "";

        if (name === "")
            return;
        let sinks;

        /*
         * pactl is being run on an event, so a malformed or partial
         * read is not worth acting on — another event will follow.
         */
        try {
            sinks = JSON.parse(raw);
        } catch (e) {
            return;
        }

        for (let i = 0; i < sinks.length; i++) {
            if (sinks[i].name !== name)
                continue;
            const ports = sinks[i].ports ?? [];

            for (let j = 0; j < ports.length; j++) {
                if (ports[j].name !== sinks[i].active_port)
                    continue;
                root.outputKind = root.classifyPort(ports[j], sinks[i]);

                return;
            }

            /*
             * Bluetooth sinks often carry no matching port entry, so
             * fall back to what the device says it is.
             */
            root.outputKind = root.classifyFormFactor(sinks[i]);

            return;
        }

        root.outputKind = "speaker";
    }

    function classifyPort(port, sink) {
        const type = String(port.type ?? "").toLowerCase();

        if (type.indexOf("headset") !== -1)
            return "headset";

        if (type.indexOf("headphone") !== -1)
            return "headphones";

        // A known non-headphone type (Speaker, HDMI, Line…) settles it.
        if (type !== "" && type !== "unknown")
            return "speaker";

        return root.classifyFormFactor(sink);
    }

    function classifyFormFactor(sink) {
        const props = sink.properties ?? {};

        // pactl reports it underscored; PipeWire itself uses a dash.
        const factor = String(props["device.form_factor"] ?? props["device.form-factor"] ?? "").toLowerCase();

        if (factor === "headset")
            return "headset";

        if (factor === "headphone" || factor === "headphones")
            return "headphones";

        return "speaker";
    }

    /*
     * Jack plugs are a card event, not a node one, so this listens
     * to PulseAudio's event stream rather than polling. Cheap: the
     * process sits idle until something actually changes.
     */
    Process {
        id: audioEvents

        running: true

        command: ["pactl", "subscribe"]

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                if (data.indexOf("card") !== -1 || data.indexOf("sink") !== -1 || data.indexOf("server") !== -1)
                    portDebounce.restart();
            }
        }
    }

    /*
     * A single plug event produces a burst of lines; coalesce them
     * into one query.
     */
    Timer {
        id: portDebounce

        interval: 150

        onTriggered: {
            root.refreshPort();
        }
    }

    onSinkChanged: {
        root.refreshPort();
    }

    Component.onCompleted: {
        root.refreshPort();
    }

    width: 24
    height: 24

    visible: root.audio !== null

    HoverHandler {
        id: hover
    }

    Text {
        anchors.centerIn: parent

        text: {
            if (root.muted)
                return root.outputKind === "speaker" ? "󰝟" : "󰋐";

            if (root.outputKind === "headset")
                return "󰋎";

            if (root.outputKind === "headphones")
                return "󰋋";

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

    Tooltip {
        active: hover.hovered

        label: root.muted ? root.outputLabel + " • Muted" : root.outputLabel + " • " + Math.round(root.volume * 100) + "%"
    }
}
