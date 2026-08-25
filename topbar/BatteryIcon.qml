import QtQuick
import Quickshell.Services.UPower

import "../theme"
import "../shared/components"

/*
 * Status only — there is no battery popup, so unlike the other bar
 * icons this carries no MouseArea and no pointer cursor. Hovering
 * uses a HoverHandler, which reports the pointer without claiming
 * clicks the way a MouseArea would.
 *
 * Geometry matches IconButton so the row stays aligned.
 */
Item {
    id: root

    property int lowThreshold: 20
    property int criticalThreshold: 10

    readonly property var battery: UPower.displayDevice

    readonly property bool active: root.battery !== null && root.battery.ready

    readonly property int level: root.active ? Math.round(root.battery.percentage * 100) : 0

    readonly property int state: root.active ? root.battery.state : UPowerDeviceState.Unknown

    readonly property bool plugged: root.state === UPowerDeviceState.Charging || root.state === UPowerDeviceState.FullyCharged

    readonly property var steps: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property string tooltipLabel: {
        if (!root.active)
            return "";

        if (root.state === UPowerDeviceState.FullyCharged)
            return "Battery • Full";

        if (root.state === UPowerDeviceState.Charging)
            return "Charging • " + root.level + "%";

        return "Battery • " + root.level + "%";
    }

    width: 24
    height: 24

    /*
     * Nothing sensible to show on a machine without a battery.
     */
    visible: root.active

    HoverHandler {
        id: hover
    }

    Text {
        anchors.centerIn: parent

        text: {
            if (root.state === UPowerDeviceState.FullyCharged)
                return "󰁹";

            if (root.state === UPowerDeviceState.Charging)
                return "󰂄";

            if (root.level <= root.criticalThreshold)
                return "󰂃";

            return root.steps[Math.max(0, Math.min(10, Math.round(root.level / 10)))];
        }

        color: {
            if (root.plugged)
                return Colors.success;

            if (root.level <= root.criticalThreshold)
                return Colors.error;

            if (root.level <= root.lowThreshold)
                return Colors.warning;

            return Colors.text;
        }

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

        label: root.tooltipLabel
    }
}
