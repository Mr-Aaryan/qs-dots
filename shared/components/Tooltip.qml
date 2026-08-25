import QtQuick

import "../../theme"

/*
 * Hover label for the bar's status icons.
 *
 * Drawn below the bar rather than inside it. That works because the
 * panel window is already tall enough to hold the popups, and its
 * input mask covers only the bar and whichever popup is open — so
 * this paints over the desktop without ever taking a click.
 *
 * Anchors itself under whatever it is parented to, so an icon only
 * has to hand it a label and a hover state.
 */
Rectangle {
    id: root

    property string label: ""

    // Driven by the icon's HoverHandler.
    property bool active: false

    /*
     * Short dwell before appearing, so sweeping the pointer along the
     * icon row does not flash a label for every icon on the way past.
     */
    property int delay: 350

    property bool dwelled: false

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom

    anchors.topMargin: 8

    implicitWidth: labelText.implicitWidth + 16
    implicitHeight: labelText.implicitHeight + 10

    width: implicitWidth
    height: implicitHeight

    radius: 7

    color: Colors.panel

    border.width: 1
    border.color: Colors.surface

    opacity: root.dwelled ? 1 : 0

    // Kept out of the scene entirely while faded out.
    visible: root.opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: 130
        }
    }

    onActiveChanged: {
        if (root.active) {
            dwell.restart();

            return;
        }

        dwell.stop();

        root.dwelled = false;
    }

    Timer {
        id: dwell

        interval: root.delay

        onTriggered: {
            root.dwelled = true;
        }
    }

    Text {
        id: labelText

        anchors.centerIn: parent

        text: root.label

        color: Colors.text

        font.family: Typography.ui

        font.pixelSize: Typography.xs

        textFormat: Text.PlainText
    }
}
