import QtQuick

import "../../theme"

/*
 * Hand-rolled slider — this shell pulls in no QtQuick.Controls.
 *
 * The value is NOT updated internally on drag. It is emitted through
 * moved() and the owner decides what to do with it, so the slider
 * always reflects real device state rather than an optimistic guess.
 */
Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property string icon: ""

    /*
     * 0..1
     */
    property real value: 0

    /*
     * True while the user is dragging. The owner should ignore
     * incoming device updates during a drag, otherwise the knob
     * fights the cursor.
     */
    readonly property bool dragging: dragArea.pressed

    signal moved(real value)

    implicitHeight: 22

    readonly property int knobSize: 14

    Text {
        id: iconLabel

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        width: 20

        text: root.icon

        color: Colors.subtext

        font.pixelSize: 15

        horizontalAlignment: Text.AlignHCenter

        textFormat: Text.PlainText
    }

    Item {
        id: track

        anchors.left: iconLabel.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        height: root.knobSize

        readonly property real usable: Math.max(1, width - root.knobSize)

        readonly property real knobX: Math.max(0, Math.min(1, root.value)) * track.usable

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            height: 4

            radius: 2

            color: Colors.surface
        }

        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            width: track.knobX + root.knobSize / 2

            height: 4

            radius: 2

            color: Colors.accent
        }

        Rectangle {
            x: track.knobX

            anchors.verticalCenter: parent.verticalCenter

            width: root.knobSize
            height: root.knobSize

            radius: root.knobSize / 2

            color: Colors.text

            scale: dragArea.pressed ? 1.15 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
        }

        MouseArea {
            id: dragArea

            anchors.fill: parent

            /*
             * Generous vertical target — the track itself is only
             * a few pixels tall.
             */
            anchors.topMargin: -8
            anchors.bottomMargin: -8

            cursorShape: Qt.PointingHandCursor

            function emitFor(mouseX) {
                const raw = (mouseX - root.knobSize / 2) / track.usable;

                root.moved(Math.max(0, Math.min(1, raw)));
            }

            onPressed: function (mouse) {
                dragArea.emitFor(mouse.x);
            }

            onPositionChanged: function (mouse) {
                if (dragArea.pressed)
                    dragArea.emitFor(mouse.x);
            }
        }
    }
}
