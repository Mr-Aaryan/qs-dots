pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

import "../theme"

PanelWindow {
    id: osd

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * Backlight device under /sys/class/backlight, and keyboard
     * backlight under /sys/class/leds.
     * See `brightnessctl -l` for the available devices.
     */
    property string backlightDevice: "intel_backlight"
    property string keyboardDevice: "asus::kbd_backlight"

    property int hideDelay: 1600

    /*
     * Battery percentages, 0-100.
     */
    property int lowThreshold: 20
    property int criticalThreshold: 10

    readonly property int panelWidth: 260
    readonly property int panelHeight: 56

    // ============================================================
    // STATE
    // ============================================================

    /*
     * "volume", "brightness" or "battery".
     */
    property string kind: "volume"

    /*
     * 0..1, though volume may go above 1 since the volume
     * keybind allows boosting up to 150%.
     */
    property real value: 0

    property bool muted: false

    /*
     * Optional caption above the bar. Only the battery uses it,
     * since "Charging" is not something a percentage can say.
     */
    property string label: ""

    property bool revealed: false

    /*
     * Pipewire emits volumeChanged once when the default sink
     * first binds, and the backlight file is read once at
     * startup. Neither is a real change, so nothing is shown
     * until the OSD has been alive for a moment.
     *
     * UPower settles later than this and is primed separately.
     */
    property bool armed: false

    Timer {
        id: armTimer

        interval: 1200
        repeat: false
        running: true

        onTriggered: {
            osd.armed = true;
        }
    }

    // ============================================================
    // WINDOW
    // ============================================================

    anchors {
        bottom: true
    }

    margins.bottom: 90

    implicitWidth: panelWidth
    implicitHeight: panelHeight

    color: "transparent"

    aboveWindows: true

    exclusionMode: ExclusionMode.Ignore

    /*
     * An empty mask makes the whole window click-through, so the
     * OSD never steals a click from whatever is underneath it.
     */
    mask: Region {}

    /*
     * Stay mapped until the fade-out has finished, otherwise the
     * window would vanish instantly instead of animating away.
     */
    visible: osd.revealed || content.opacity > 0

    // ============================================================
    // REVEAL
    // ============================================================

    property int currentDuration: hideDelay

    function reveal(duration) {
        if (!osd.armed)
            return;
        osd.currentDuration = duration === undefined ? osd.hideDelay : duration;

        osd.revealed = true;

        hideTimer.restart();
    }

    Timer {
        id: hideTimer

        interval: osd.currentDuration
        repeat: false

        onTriggered: {
            osd.revealed = false;
        }
    }

    // ============================================================
    // VOLUME
    // ============================================================

    readonly property var sink: Pipewire.defaultAudioSink

    /*
     * Audio properties are only populated on bound nodes.
     */
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: osd.sink?.audio ?? null

        function onVolumeChanged() {
            osd.showVolume();
        }

        function onMutedChanged() {
            osd.showVolume();
        }
    }

    function showVolume() {
        const audio = osd.sink?.audio ?? null;

        if (!audio)
            return;
        osd.kind = "volume";
        osd.label = "";
        osd.value = audio.volume;
        osd.muted = audio.muted;

        osd.reveal();
    }

    // ============================================================
    // SCREEN BRIGHTNESS
    // ============================================================

    BacklightSource {
        path: "/sys/class/backlight/" + osd.backlightDevice

        onUpdated: function (fraction) {
            osd.showBrightness(fraction);
        }
    }

    function showBrightness(fraction) {
        osd.kind = "brightness";
        osd.label = "";
        osd.value = fraction;
        osd.muted = false;

        osd.reveal();
    }

    // ============================================================
    // KEYBOARD BACKLIGHT
    // ============================================================

    BacklightSource {
        path: "/sys/class/leds/" + osd.keyboardDevice

        onUpdated: function (fraction) {
            osd.showKeyboard(fraction);
        }
    }

    function showKeyboard(fraction) {
        osd.kind = "keyboard";

        /*
         * Labelled because a keyboard backlight step reads as an
         * ordinary brightness change otherwise.
         */
        osd.label = "Keyboard";
        osd.value = fraction;
        osd.muted = false;

        osd.reveal();
    }

    // ============================================================
    // BATTERY
    // ============================================================

    readonly property var battery: UPower.displayDevice

    property int batteryState: UPowerDeviceState.Unknown
    property int batteryLevel: 0

    /*
     * The state the battery was last seen in, used to tell a real
     * transition apart from an unrelated property update.
     */
    property int lastBatteryState: UPowerDeviceState.Unknown

    /*
     * Which low-battery warning has already been shown, so a
     * slowly draining battery warns once rather than on every
     * percentage tick. 0 means none pending.
     */
    property int warnedLevel: 0

    /*
     * UPower becomes ready around a second and a half after
     * startup — later than armTimer — so the battery cannot rely
     * on it. The first update it delivers describes the state we
     * booted into, which is not an event worth announcing.
     */
    property bool batteryPrimed: false

    Connections {
        target: osd.battery

        function onStateChanged() {
            osd.handleBatteryState();
        }

        function onPercentageChanged() {
            osd.handleBatteryLevel();
        }

        function onReadyChanged() {
            osd.handleBatteryState();
        }
    }

    /*
     * Returns true once the battery is reporting real data AND the
     * initial reading has already been absorbed.
     */
    function batteryReady() {
        const battery = osd.battery;

        if (!battery || !battery.ready)
            return false;
        if (!osd.batteryPrimed) {
            osd.batteryPrimed = true;

            osd.lastBatteryState = battery.state;

            /*
             * Booting into "Charging" is not news, but booting into
             * a nearly flat battery still is.
             */
            osd.checkBatteryLevel();

            return false;
        }

        return true;
    }

    function syncBattery() {
        osd.kind = "battery";
        osd.muted = false;
        osd.value = osd.battery.percentage;
        osd.batteryLevel = Math.round(osd.battery.percentage * 100);
        osd.batteryState = osd.battery.state;
    }

    // ------------------------------------------------------------
    // PLUGGED IN / UNPLUGGED / FULL
    // ------------------------------------------------------------

    function handleBatteryState() {
        if (!osd.batteryReady())
            return;
        const state = osd.battery.state;

        if (state === osd.lastBatteryState)
            return;
        osd.lastBatteryState = state;

        osd.syncBattery();

        if (state === UPowerDeviceState.Charging) {
            /*
             * Plugging in resolves any pending low warning.
             */
            osd.warnedLevel = 0;

            osd.label = "Charging";

            osd.reveal(2200);

            return;
        }

        if (state === UPowerDeviceState.FullyCharged) {
            osd.warnedLevel = 0;

            osd.label = "Fully charged";

            osd.reveal(2200);

            return;
        }

        if (state === UPowerDeviceState.Discharging) {
            osd.label = "On battery";

            osd.reveal(2200);

            /*
             * Unplugging at 8% should warn immediately rather than
             * waiting for the next percentage tick.
             */
            osd.checkBatteryLevel();

            return;
        }

        if (state === UPowerDeviceState.Empty) {
            osd.label = "Battery empty";

            osd.reveal(4500);
        }
    }

    // ------------------------------------------------------------
    // LOW / CRITICAL
    // ------------------------------------------------------------

    function handleBatteryLevel() {
        if (!osd.batteryReady())
            return;
        osd.checkBatteryLevel();
    }

    function checkBatteryLevel() {
        const battery = osd.battery;

        if (!battery || !battery.ready)
            return;
        const level = Math.round(battery.percentage * 100);

        const draining = battery.state === UPowerDeviceState.Discharging;

        /*
         * Charging, or recovered well clear of the threshold —
         * re-arm the warnings.
         */
        if (!draining || level > osd.lowThreshold + 5) {
            osd.warnedLevel = 0;

            return;
        }

        if (level <= osd.criticalThreshold && osd.warnedLevel !== osd.criticalThreshold) {
            osd.warnedLevel = osd.criticalThreshold;

            osd.syncBattery();

            osd.label = "Battery critical";

            osd.reveal(4500);

            return;
        }

        if (level <= osd.lowThreshold && osd.warnedLevel === 0) {
            osd.warnedLevel = osd.lowThreshold;

            osd.syncBattery();

            osd.label = "Battery low";

            osd.reveal(3000);
        }
    }

    // ============================================================
    // ICON
    // ============================================================

    readonly property var batterySteps: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    function icon() {
        if (osd.kind === "battery") {
            if (osd.batteryState === UPowerDeviceState.Charging)
                return "󰂄";

            if (osd.batteryState === UPowerDeviceState.FullyCharged)
                return "󰁹";

            if (osd.batteryLevel <= osd.criticalThreshold)
                return "󰂃";

            return osd.batterySteps[Math.max(0, Math.min(10, Math.round(osd.batteryLevel / 10)))];
        }

        if (osd.kind === "keyboard")
            return osd.value > 0 ? "󰌌" : "󰌐";

        if (osd.kind === "brightness") {
            if (osd.value >= 0.66)
                return "󰃠";

            if (osd.value >= 0.33)
                return "󰃟";

            return "󰃞";
        }

        if (osd.muted)
            return "󰝟";

        if (osd.value >= 0.5)
            return "󰕾";

        if (osd.value > 0)
            return "󰖀";

        return "󰕿";
    }

    // ============================================================
    // TINT
    // ============================================================

    readonly property color tint: {
        if (osd.kind === "battery") {
            if (osd.batteryState === UPowerDeviceState.Charging || osd.batteryState === UPowerDeviceState.FullyCharged)
                return Colors.success;

            if (osd.batteryLevel <= osd.criticalThreshold)
                return Colors.error;

            if (osd.batteryLevel <= osd.lowThreshold)
                return Colors.warning;

            return Colors.accent;
        }

        /*
         * A keyboard backlight that is off should read as off
         * rather than as an accent-coloured empty bar.
         */
        if (osd.kind === "keyboard" && osd.value <= 0)
            return Colors.subtext;

        if (osd.muted)
            return Colors.subtext;

        if (osd.value > 1)
            return Colors.warning;

        return Colors.accent;
    }

    // ============================================================
    // CONTENT
    // ============================================================

    Item {
        id: content

        width: parent.width
        height: parent.height

        y: osd.revealed ? 0 : 10

        opacity: osd.revealed ? 1 : 0

        Behavior on y {
            NumberAnimation {
                duration: 180

                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160

                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: panel

            anchors.fill: parent

            radius: 12

            color: Colors.base

            border.width: 1
            border.color: Colors.surface

            RowLayout {
                anchors.fill: parent

                anchors.leftMargin: 14
                anchors.rightMargin: 14

                spacing: 12

                // =============================================
                // ICON
                // =============================================

                Text {
                    Layout.preferredWidth: 24

                    text: osd.icon()

                    color: osd.tint

                    font.pixelSize: 20

                    horizontalAlignment: Text.AlignHCenter

                    textFormat: Text.PlainText

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                // =============================================
                // LABEL + BAR
                // =============================================

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 5

                    Text {
                        visible: osd.label !== ""

                        Layout.fillWidth: true

                        text: osd.label

                        color: Colors.subtext

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.xs

                        elide: Text.ElideRight

                        textFormat: Text.PlainText
                    }

                    Rectangle {
                        id: track

                        Layout.fillWidth: true
                        Layout.preferredHeight: 6

                        radius: 3

                        color: Colors.surface

                        Rectangle {
                            /*
                             * Never narrower than the corner radius, so a
                             * near-zero value still renders as a dot rather
                             * than a sliver.
                             */
                            width: Math.max(parent.height, parent.width * Math.min(1, osd.value))

                            height: parent.height

                            radius: parent.radius

                            color: osd.tint

                            Behavior on width {
                                NumberAnimation {
                                    duration: 140

                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                    }
                }

                // =============================================
                // PERCENTAGE
                // =============================================

                Text {
                    Layout.preferredWidth: 40

                    text: Math.round(osd.value * 100) + "%"

                    color: osd.muted ? Colors.subtext : Colors.text

                    font.family: Typography.firaCode

                    font.pixelSize: Typography.sm

                    font.bold: true

                    horizontalAlignment: Text.AlignRight

                    textFormat: Text.PlainText
                }
            }
        }
    }
}
