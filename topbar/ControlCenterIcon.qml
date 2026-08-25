import QtQuick
import "../theme"
import "../shared/components"

IconButton {
    id: root

    /*
     * md-tune-variant (U+F1542) — the two stacked horizontal sliders
     * macOS uses for Control Center. Picked over fa-sliders and
     * oct-sliders because those carry three rows, which fills in and
     * turns to mush at the bar's 14px.
     */
    iconText: "󱕂"
    iconColor: Colors.text
}
