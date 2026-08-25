pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

import "../theme"
import "../settings"
import "../osd"
import "../shared/components"

Item {
    id: controlCenter

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool opened: false

    readonly property int panelWidth: 340
    readonly property int panelHeight: 450

    width: panelWidth
    height: panelHeight

    // ============================================================
    // WI-FI
    // ============================================================

    property bool wifiEnabled: false

    Process {
        id: wifiStateProcess

        command: ["nmcli", "-t", "-f", "WIFI", "radio"]

        stdout: StdioCollector {
            onStreamFinished: {
                controlCenter.wifiEnabled = this.text.trim().toLowerCase() === "enabled";
            }
        }
    }

    Process {
        id: wifiToggleProcess

        onRunningChanged: if (!running) {
            controlCenter.refreshWifi();
        }
    }

    function refreshWifi() {
        wifiStateProcess.running = false;
        wifiStateProcess.running = true;
    }

    function toggleWifi() {
        wifiToggleProcess.command = ["nmcli", "radio", "wifi", controlCenter.wifiEnabled ? "off" : "on"];

        wifiToggleProcess.running = true;
    }

    // ============================================================
    // BLUETOOTH
    //
    // Null adapter means bluetooth.service is not running, in which
    // case the tile shows as unavailable rather than pretending.
    // ============================================================

    readonly property var btAdapter: Bluetooth.defaultAdapter

    readonly property bool btAvailable: controlCenter.btAdapter !== null

    readonly property bool btEnabled: controlCenter.btAvailable && controlCenter.btAdapter.enabled

    function toggleBluetooth() {
        if (!controlCenter.btAvailable)
            return;
        controlCenter.btAdapter.enabled = !controlCenter.btAdapter.enabled;
    }

    // ============================================================
    // AUDIO
    // ============================================================

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var sinkAudio: controlCenter.sink?.audio ?? null
    readonly property var sourceAudio: controlCenter.source?.audio ?? null

    readonly property bool micMuted: controlCenter.sourceAudio !== null && controlCenter.sourceAudio.muted

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    property real volume: 0

    Connections {
        target: controlCenter.sinkAudio

        function onVolumeChanged() {
            if (!volumeSlider.dragging)
                controlCenter.volume = controlCenter.sinkAudio.volume;
        }
    }

    function setVolume(value) {
        controlCenter.volume = value;

        if (controlCenter.sinkAudio)
            controlCenter.sinkAudio.volume = value;
    }

    function toggleMic() {
        if (controlCenter.sourceAudio)
            controlCenter.sourceAudio.muted = !controlCenter.sourceAudio.muted;
    }

    // ============================================================
    // BRIGHTNESS
    // ============================================================

    property real brightness: 0

    BacklightSource {
        path: "/sys/class/backlight/intel_backlight"

        onUpdated: function (fraction) {
            if (!brightnessSlider.dragging)
                controlCenter.brightness = fraction;
        }
    }

    Process {
        id: brightnessProcess
    }

    /*
     * brightnessctl spawns a process per call, so dragging is
     * throttled rather than fired on every pixel of movement.
     */
    Timer {
        id: brightnessApplyTimer

        interval: 60
        repeat: false

        onTriggered: {
            if (brightnessProcess.running) {
                brightnessApplyTimer.restart();

                return;
            }

            /*
             * Never all the way to zero — that reads as a broken
             * screen rather than a dim one.
             */
            const percent = Math.max(1, Math.round(controlCenter.brightness * 100));

            brightnessProcess.command = ["brightnessctl", "-q", "set", percent + "%"];

            brightnessProcess.running = true;
        }
    }

    function setBrightness(value) {
        controlCenter.brightness = value;

        brightnessApplyTimer.restart();
    }

    // ============================================================
    // CAFFEINE
    //
    // hypridle honours systemd inhibitors (ignore_systemd_inhibit
    // is unset), so holding an idle inhibitor is enough — no need
    // to kill the daemon.
    // ============================================================

    Process {
        id: caffeineProcess

        command: ["systemd-inhibit", "--what=idle", "--who=Quickshell", "--why=Caffeine", "sleep", "infinity"]
    }

    readonly property bool caffeine: caffeineProcess.running

    function toggleCaffeine() {
        caffeineProcess.running = !caffeineProcess.running;
    }

    // ============================================================
    // TIMER
    // ============================================================

    property int timerRemaining: 0

    readonly property bool timerRunning: controlCenter.timerRemaining > 0

    property bool timerPickerOpen: false

    readonly property var timerPresets: [5, 10, 25, 45]

    Timer {
        interval: 1000
        repeat: true

        running: controlCenter.timerRemaining > 0

        onTriggered: {
            controlCenter.timerRemaining -= 1;

            if (controlCenter.timerRemaining <= 0) {
                controlCenter.timerRemaining = 0;

                timerDoneProcess.command = ["notify-send", "-u", "critical", "-a", "Quickshell", "Timer", "Time's up"];

                timerDoneProcess.running = true;
            }
        }
    }

    Process {
        id: timerDoneProcess
    }

    function timerLabel() {
        const minutes = Math.floor(controlCenter.timerRemaining / 60);
        const seconds = controlCenter.timerRemaining % 60;

        return minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
    }

    function startTimer(minutes) {
        controlCenter.timerRemaining = minutes * 60;

        controlCenter.timerPickerOpen = false;
    }

    function pressTimer() {
        if (controlCenter.timerRunning) {
            controlCenter.timerRemaining = 0;

            return;
        }

        controlCenter.timerPickerOpen = !controlCenter.timerPickerOpen;
    }

    // ============================================================
    // TOGGLES
    // ============================================================

    readonly property var toggles: [
        {
            key: "wifi",
            label: "Wi-Fi",
            icon: "󰤨"
        },
        {
            key: "bluetooth",
            label: "Bluetooth",
            icon: "󰂯"
        },
        {
            key: "dnd",
            label: "Do Not Disturb",
            icon: "󰂛"
        },
        {
            key: "timer",
            label: "Timer",
            icon: "󰔛"
        },
    ]

    function toggleActive(key) {
        if (key === "wifi")
            return controlCenter.wifiEnabled;

        if (key === "bluetooth")
            return controlCenter.btEnabled;

        if (key === "dnd")
            return Settings.dnd;

        return controlCenter.timerRunning;
    }

    function toggleEnabled(key) {
        if (key === "bluetooth")
            return controlCenter.btAvailable;

        return true;
    }

    function toggleLabel(key) {
        if (key === "timer" && controlCenter.timerRunning)
            return controlCenter.timerLabel();

        if (key === "bluetooth" && !controlCenter.btAvailable)
            return "Bluetooth off";

        for (let i = 0; i < controlCenter.toggles.length; i++) {
            if (controlCenter.toggles[i].key === key)
                return controlCenter.toggles[i].label;
        }

        return "";
    }

    function pressToggle(key) {
        if (key === "wifi") {
            controlCenter.toggleWifi();

            return;
        }

        if (key === "bluetooth") {
            controlCenter.toggleBluetooth();

            return;
        }

        if (key === "dnd") {
            Settings.dnd = !Settings.dnd;

            Settings.save();

            return;
        }

        controlCenter.pressTimer();
    }

    // ============================================================
    // CIRCLE ACTIONS
    // ============================================================

    readonly property var circles: [
        {
            key: "caffeine",
            icon: "󰅶"
        },
        {
            key: "mic",
            icon: "󰍬"
        },
        {
            key: "placeholder1",
            icon: "󰇘"
        },
        {
            key: "placeholder2",
            icon: "󰇘"
        },
    ]

    function circleIcon(key) {
        if (key === "mic")
            return controlCenter.micMuted ? "󰍭" : "󰍬";

        for (let i = 0; i < controlCenter.circles.length; i++) {
            if (controlCenter.circles[i].key === key)
                return controlCenter.circles[i].icon;
        }

        return "";
    }

    function circleActive(key) {
        if (key === "caffeine")
            return controlCenter.caffeine;

        if (key === "mic")
            return controlCenter.micMuted;

        return false;
    }

    function circleEnabled(key) {
        return key === "caffeine" || key === "mic";
    }

    function pressCircle(key) {
        if (key === "caffeine") {
            controlCenter.toggleCaffeine();

            return;
        }

        if (key === "mic")
            controlCenter.toggleMic();
    }

    // ============================================================
    // ACTION TILES
    // ============================================================

    readonly property var actions: [
        {
            key: "screenshot",
            label: "Screenshot",
            icon: "󰄀"
        },
        {
            key: "colorpicker",
            label: "Pick colour",
            icon: "󰈋"
        },
        {
            key: "wallpaper",
            label: "Wallpaper",
            icon: "󰸉"
        },
        {
            key: "placeholder",
            label: "",
            icon: "󰇘"
        },
    ]

    Process {
        id: actionProcess
    }

    // ------------------------------------------------------------
    // WALLPAPER PICKER
    // ------------------------------------------------------------

    readonly property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/wallpaper"

    property bool wallpaperPickerOpen: false

    Process {
        id: wallpaperProcess
    }

    function applyWallpaper(path) {
        if (wallpaperProcess.running)
            return;

        /*
         * Set the wallpaper, then re-theme from it. --prefer is
         * required: matugen 4 refuses to choose between multiple
         * source colours when it cannot detect a terminal, which is
         * exactly how it runs from here.
         */
        wallpaperProcess.command = ["bash", "-c", 'hyprctl hyprpaper wallpaper ",$1"; matugen --prefer saturation image "$1"', "wallpaper", path];

        wallpaperProcess.running = true;

        /*
         * The picker deliberately stays open — the shell re-themes
         * live, so browsing through several is the point.
         */
    }

    function pressAction(key) {
        if (key === "placeholder")
            return;
        if (key === "screenshot") {
            actionProcess.command = ["bash", "-c", 'grimshot --notify savecopy area "$HOME/Pictures/screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"'];
        } else if (key === "colorpicker") {
            actionProcess.command = ["hyprpicker", "-a"];
        } else if (key === "wallpaper") {
            /*
             * Pick a random wallpaper, then re-theme from it.
             *
             * --prefer is required: matugen 4 refuses to choose
             * between multiple source colours when it cannot detect
             * a terminal, which is exactly how it runs from here.
             */
            actionProcess.command = ["bash", "-c", 'f=$(find "$HOME/Pictures/wallpaper" -type f | shuf -n 1); [ -n "$f" ] || exit 0; hyprctl hyprpaper wallpaper ",$f"; matugen --prefer saturation image "$f"'];
        } else {
            return;
        }

        /*
         * Get out of the way first — the screenshot and the colour
         * picker both capture whatever is on screen.
         */
        controlCenter.close();

        actionProcess.running = true;
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        controlCenter.timerPickerOpen = false;
        controlCenter.wallpaperPickerOpen = false;

        controlCenter.refreshWifi();

        if (controlCenter.sinkAudio)
            controlCenter.volume = controlCenter.sinkAudio.volume;

        controlCenter.opened = true;
    }

    function close() {
        controlCenter.opened = false;

        controlCenter.timerPickerOpen = false;
        controlCenter.wallpaperPickerOpen = false;
    }

    function toggle() {
        if (controlCenter.opened)
            close();
        else
            open();
    }

    Component.onCompleted: {
        refreshWifi();
    }

    // ============================================================
    // SLIDE-DOWN ANIMATION
    // ============================================================

    Item {
        id: revealArea

        anchors.fill: parent

        clip: true

        Item {
            id: animatedContent

            width: parent.width
            height: parent.height

            y: controlCenter.opened ? 0 : -height

            opacity: controlCenter.opened ? 1 : 0.85

            Behavior on y {
                NumberAnimation {
                    duration: 360

                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220

                    easing.type: Easing.OutCubic
                }
            }

            // ====================================================
            // PANEL
            // ====================================================

            Rectangle {
                id: panel

                anchors.fill: parent

                radius: 12

                color: Colors.panel

                border.width: 1
                border.color: Colors.surface

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins: 14

                    spacing: 12

                    // =============================================
                    // TOGGLES
                    // =============================================

                    GridLayout {
                        Layout.fillWidth: true

                        columns: 2

                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: controlCenter.toggles

                            delegate: Rectangle {
                                id: toggleTile

                                required property var modelData

                                readonly property bool active: controlCenter.toggleActive(toggleTile.modelData.key)

                                readonly property bool usable: controlCenter.toggleEnabled(toggleTile.modelData.key)

                                Layout.fillWidth: true
                                Layout.preferredHeight: 54

                                radius: 12

                                color: toggleTile.active ? Colors.accent : (toggleMouse.containsMouse ? Colors.surface : "transparent")

                                border.width: 1
                                border.color: toggleTile.active ? Colors.accent : Colors.surface

                                opacity: toggleTile.usable ? 1 : 0.45

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 130
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 10

                                    spacing: 9

                                    Text {
                                        text: toggleTile.modelData.icon

                                        color: toggleTile.active ? Colors.base : Colors.text

                                        font.pixelSize: 18

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        text: controlCenter.toggleLabel(toggleTile.modelData.key)

                                        color: toggleTile.active ? Colors.base : Colors.text

                                        font.family: Typography.firaCode

                                        font.pixelSize: Typography.xs

                                        font.bold: toggleTile.active

                                        elide: Text.ElideRight

                                        textFormat: Text.PlainText
                                    }
                                }

                                MouseArea {
                                    id: toggleMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    enabled: toggleTile.usable

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        controlCenter.pressToggle(toggleTile.modelData.key);
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // SLIDERS
                    // =============================================

                    ColumnLayout {
                        Layout.fillWidth: true

                        Layout.topMargin: 2

                        spacing: 10

                        ControlSlider {
                            id: brightnessSlider

                            Layout.fillWidth: true

                            icon: "󰃟"

                            value: controlCenter.brightness

                            onMoved: function (value) {
                                controlCenter.setBrightness(value);
                            }
                        }

                        ControlSlider {
                            id: volumeSlider

                            Layout.fillWidth: true

                            icon: "󰕾"

                            value: controlCenter.volume

                            onMoved: function (value) {
                                controlCenter.setVolume(value);
                            }
                        }
                    }

                    // =============================================
                    // CIRCLES
                    // =============================================

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66

                        radius: 16

                        color: Colors.surface

                        RowLayout {
                            anchors.centerIn: parent

                            width: parent.width - 24

                            spacing: 8

                            Repeater {
                                model: controlCenter.circles

                                delegate: Item {
                                    id: circleSlot

                                    required property var modelData

                                    readonly property bool active: controlCenter.circleActive(circleSlot.modelData.key)

                                    readonly property bool usable: controlCenter.circleEnabled(circleSlot.modelData.key)

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44

                                    Rectangle {
                                        anchors.centerIn: parent

                                        width: 44
                                        height: 44

                                        radius: 22

                                        color: circleSlot.active ? Colors.accent : (circleMouse.containsMouse ? Colors.base : "transparent")

                                        border.width: 1
                                        border.color: circleSlot.active ? Colors.accent : Colors.subtext

                                        opacity: circleSlot.usable ? 1 : 0.35

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 130
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent

                                            text: controlCenter.circleIcon(circleSlot.modelData.key)

                                            color: circleSlot.active ? Colors.base : Colors.text

                                            font.pixelSize: 18

                                            textFormat: Text.PlainText
                                        }

                                        MouseArea {
                                            id: circleMouse

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            enabled: circleSlot.usable

                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                controlCenter.pressCircle(circleSlot.modelData.key);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // ACTIONS
                    // =============================================

                    GridLayout {
                        Layout.fillWidth: true

                        columns: 2

                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: controlCenter.actions

                            delegate: Rectangle {
                                id: actionTile

                                required property var modelData

                                readonly property bool usable: actionTile.modelData.key !== "placeholder"

                                readonly property bool expandable: actionTile.modelData.key === "wallpaper"

                                Layout.fillWidth: true
                                Layout.preferredHeight: 54

                                radius: 12

                                color: actionMouse.containsMouse ? Colors.surface : "transparent"

                                border.width: 1
                                border.color: Colors.surface

                                opacity: actionTile.usable ? 1 : 0.45

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 130
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent

                                    anchors.leftMargin: 12

                                    /*
                                     * Leave room for the chevron so the
                                     * label never runs underneath it.
                                     */
                                    anchors.rightMargin: actionTile.expandable ? 34 : 10

                                    spacing: 9

                                    Text {
                                        text: actionTile.modelData.icon

                                        color: Colors.text

                                        font.pixelSize: 18

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        text: actionTile.modelData.label

                                        color: Colors.text

                                        font.family: Typography.firaCode

                                        font.pixelSize: Typography.xs

                                        elide: Text.ElideRight

                                        textFormat: Text.PlainText
                                    }
                                }

                                MouseArea {
                                    id: actionMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    enabled: actionTile.usable

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        controlCenter.pressAction(actionTile.modelData.key);
                                    }
                                }

                                /*
                                 * Declared after the tile's MouseArea so it
                                 * stacks above it and gets the click — the
                                 * tile area would otherwise swallow it.
                                 */
                                Rectangle {
                                    visible: actionTile.expandable

                                    anchors.right: parent.right
                                    anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 26
                                    height: 26

                                    radius: 13

                                    color: chevronMouse.containsMouse ? Colors.base : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent

                                        text: "󰅂"

                                        color: chevronMouse.containsMouse ? Colors.accent : Colors.subtext

                                        font.pixelSize: 16

                                        textFormat: Text.PlainText
                                    }

                                    MouseArea {
                                        id: chevronMouse

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            wallpaperGrid.refresh();

                                            controlCenter.wallpaperPickerOpen = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    /*
                     * Absorbs any leftover height so the sections keep
                     * their fixed sizes instead of stretching.
                     */
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // =================================================
                // WALLPAPER PICKER
                // =================================================

                Rectangle {
                    anchors.fill: parent

                    radius: 12

                    color: Colors.base

                    visible: controlCenter.wallpaperPickerOpen

                    ColumnLayout {
                        anchors.fill: parent

                        anchors.margins: 14

                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true

                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26

                                radius: 7

                                color: backMouse.containsMouse ? Colors.surface : "transparent"

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰅁"

                                    color: Colors.text

                                    font.pixelSize: 16

                                    textFormat: Text.PlainText
                                }

                                MouseArea {
                                    id: backMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        controlCenter.wallpaperPickerOpen = false;
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text: "Wallpaper"

                                color: Colors.text

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.md

                                font.bold: true

                                textFormat: Text.PlainText
                            }

                            Text {
                                text: wallpaperGrid.count + ""

                                color: Colors.subtext

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.xs

                                textFormat: Text.PlainText
                            }
                        }

                        WallpaperGrid {
                            id: wallpaperGrid

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            columns: 2

                            onSelected: function (path) {
                                controlCenter.applyWallpaper(path);
                            }
                        }
                    }
                }

                // =================================================
                // TIMER PRESETS
                // =================================================

                Rectangle {
                    anchors.fill: parent

                    radius: 12

                    color: Colors.base

                    visible: controlCenter.timerPickerOpen

                    opacity: controlCenter.timerPickerOpen ? 0.97 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 130
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent

                        width: parent.width - 60

                        spacing: 10

                        Text {
                            Layout.fillWidth: true

                            text: "Start a timer"

                            color: Colors.text

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.md

                            font.bold: true

                            horizontalAlignment: Text.AlignHCenter

                            textFormat: Text.PlainText
                        }

                        Repeater {
                            model: controlCenter.timerPresets

                            delegate: Rectangle {
                                id: presetTile

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 40

                                radius: 10

                                color: presetMouse.containsMouse ? Colors.accent : Colors.surface

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: presetTile.modelData + " minutes"

                                    color: presetMouse.containsMouse ? Colors.base : Colors.text

                                    font.family: Typography.firaCode

                                    font.pixelSize: Typography.sm

                                    textFormat: Text.PlainText
                                }

                                MouseArea {
                                    id: presetMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        controlCenter.startTimer(presetTile.modelData);
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            Layout.topMargin: 4

                            text: "Cancel"

                            color: Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            horizontalAlignment: Text.AlignHCenter

                            textFormat: Text.PlainText

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    controlCenter.timerPickerOpen = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
