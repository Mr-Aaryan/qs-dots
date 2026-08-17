import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../theme"

Row {
    id: root

    property int spacingValue: 6

    spacing: spacingValue
    height: 12

    Repeater {
        model: Hyprland.workspaces.values

        delegate: Rectangle {
            id: pill

            required property HyprlandWorkspace modelData

            readonly property bool focused: modelData.focused
            readonly property bool occupied: modelData.toplevels.values.length > 0

            width: focused ? 24 : 12
            height: 12
            radius: height / 2

            anchors.verticalCenter: parent.verticalCenter

            color: {
                if (modelData.urgent)
                    return Colors.urgent;

                if (focused)
                    return Colors.text;

                if (occupied)
                    return Colors.gray;

                return Colors.defaultClr;
            }

            Behavior on width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: pill.modelData.activate()
            }
        }
    }
}
