import QtQuick
import "../theme"
import "../settings"
import "../shared/components"

IconButton {
    id: root

    /*
     * Reflects the control center's Do Not Disturb toggle, so the
     * toggle has a visible consequence in the bar.
     */
    iconText: Settings.dnd ? "󰂛" : "󰂚"
    iconColor: Settings.dnd ? Colors.subtext : Colors.text
}
