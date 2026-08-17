import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import QtQuick.Layouts
import Quickshell.Widgets
import "../theme"
import "../shared/components"

PanelWindow {
    id: topbar

    property int barHeight: 28

    implicitHeight: barHeight
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        left: 5
        right: 5
        top: 1
    }

    exclusiveZone: height
    aboveWindows: true
    exclusionMode: ExclusiveMode.Auto

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 8

        // Left Group
        Row {
            id: leftGroup

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            spacing: 8

            // Workspaces
            Rectangle {
                id: workspaceBackground

                color: Colors.base
                radius: 8

                implicitWidth: workspaceRow.implicitWidth + 12
                implicitHeight: workspaceRow.implicitHeight + 12

                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: workspaceRow

                    anchors.centerIn: parent
                    spacing: 8

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

                            color: {
                                if (modelData.urgent)
                                    return Colors.urgent;

                                if (focused)
                                    return Colors.text;

                                if (occupied)
                                    return Colors.gray;

                                return Colors.defaultClr;
                            }

                            anchors.verticalCenter: parent.verticalCenter

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

                                onClicked: {
                                    pill.modelData.activate();
                                }
                            }
                        }
                    }
                }
            }

            // System Tray
            Rectangle {
                id: trayBackground

                color: Colors.base
                radius: 8

                implicitWidth: trayRow.implicitWidth + 12
                implicitHeight: trayRow.implicitHeight + 8

                anchors.verticalCenter: parent.verticalCenter

                Row {
                    id: trayRow

                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: SystemTray.items

                        delegate: Rectangle {
                            id: trayItem
                            required property SystemTrayItem modelData

                            width: 20
                            height: 16
                            radius: height / 2
                            color: "transparent"

                            IconImage {
                                anchors.centerIn: parent
                                implicitWidth: 20
                                implicitHeight: 16
                                source: modelData.icon
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onClicked: function (mouse) {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (mouse.button === Qt.RightButton && modelData.hasMenu) {

                                        //! need fix later to use QsMenuAnchor
                                        modelData.display(topbar, 0, trayItem.height);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Middle Group
        Rectangle {
            id: middleGroup

            anchors.centerIn: parent

            width: clockDisplay.implicitWidth + 12
            height: clockDisplay.implicitHeight + 8

            color: Colors.base
            radius: 8

            Text {
                id: clockDisplay

                anchors.centerIn: parent

                text: new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat)

                color: Colors.text

                font.family: Typography.firaCode
                font.pixelSize: Typography.md

                Timer {
                    interval: 1000
                    running: true
                    repeat: true

                    onTriggered: {
                        clockDisplay.text = new Date().toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
                    }
                }
            }
        }

        // Right Group
        Row {
            id: rightGroup

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            spacing: 8

            IconButton {
                iconHeight: topbar.height
                iconText: "W"
                iconColor: Colors.text

                onClicked: {
                    console.log("WiFi");
                }
            }

            IconButton {
                iconHeight: topbar.height
                iconText: "B"
                iconColor: Colors.text

                onClicked: {
                    console.log("Bluetooth");
                }
            }

            IconButton {
                iconHeight: topbar.height
                iconText: "N"
                iconColor: Colors.text

                onClicked: {
                    console.log("Notifications");
                }
            }
        }
    }
}
