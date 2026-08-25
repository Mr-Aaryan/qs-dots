pragma ComponentBehavior: Bound

import QtQuick

import "../theme"

/*
 * One tile in the power menu.
 *
 * Three visual states, in order of precedence: armed (a destructive
 * action waiting on a second press), selected (the keyboard or mouse
 * is on it), and resting.
 */
Rectangle {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * An entry from PowerMenu.actions — id, label, icon, key,
     * command, and whether it costs you the session.
     */
    required property var action

    property bool selected: false

    /*
     * Set while this tile is the one asking for confirmation. Only
     * ever true for a destructive action.
     */
    property bool armed: false

    signal activated
    signal hovered

    // ============================================================
    // APPEARANCE
    // ============================================================

    readonly property color highlight: root.armed ? Colors.error : Colors.accent

    radius: 16

    color: {
        if (root.armed)
            return Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.16);
        if (root.selected)
            return Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14);

        return Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.5);
    }

    border.width: root.selected || root.armed ? 2 : 1

    border.color: root.selected || root.armed ? root.highlight : Qt.lighter(Colors.surface, 1.15)

    /*
     * A tile the keyboard is on lifts very slightly. Enough to read as
     * raised next to its neighbours without the grid appearing to
     * shift around as the selection moves.
     */
    scale: root.selected || root.armed ? 1.03 : 1

    Behavior on color {
        ColorAnimation {
            duration: 130
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 130
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 130
            easing.type: Easing.OutCubic
        }
    }

    // ------------------------------------------------------------
    // ACCELERATOR BADGE
    //
    // The same letters wlogout used, so the muscle memory carries
    // over. Only worth showing on the resting tiles — on the armed
    // one the confirm prompt is the only thing that matters.
    // ------------------------------------------------------------

    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right

        anchors.margins: 10

        width: 20
        height: 20

        radius: 6

        visible: !root.armed

        color: root.selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.28) : Qt.rgba(Colors.base.r, Colors.base.g, Colors.base.b, 0.45)

        Text {
            anchors.centerIn: parent

            text: root.action.key.toUpperCase()

            color: root.selected ? Colors.text : Colors.subtext

            font.family: Typography.ui
            font.pixelSize: Typography.xs
            font.weight: Typography.demiBold

            textFormat: Text.PlainText
        }
    }

    // ------------------------------------------------------------
    // ICON + LABEL
    // ------------------------------------------------------------

    Column {
        anchors.centerIn: parent

        spacing: 14

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.armed ? "󰀦" : root.action.icon

            color: root.armed ? Colors.error : root.selected ? Colors.text : Colors.subtext

            font.family: Typography.mono
            font.pixelSize: 46

            textFormat: Text.PlainText

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.armed ? "Confirm?" : root.action.label

            color: root.armed ? Colors.error : Colors.text

            font.family: Typography.ui
            font.pixelSize: Typography.md
            font.weight: root.selected || root.armed ? Typography.demiBold : Typography.medium

            textFormat: Text.PlainText
        }
    }

    // ------------------------------------------------------------
    // CONFIRM HINT
    // ------------------------------------------------------------

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        anchors.bottomMargin: 12

        visible: root.armed

        text: "press again"

        color: Colors.error

        opacity: 0.75

        font.family: Typography.ui
        font.pixelSize: Typography.xs

        textFormat: Text.PlainText
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.hovered();
        }

        onClicked: {
            root.activated();
        }
    }
}
