import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../theme"

Rectangle {
    id: root

    property int itemSize: 18
    property int horizontalPadding: 8
    property int itemSpacing: 10

    color: "transparent"
    radius: 8

    height: 24
    implicitWidth: trayRow.implicitWidth + horizontalPadding * 2

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: root.itemSpacing

        Repeater {
            id: trayRepeater

            model: SystemTray.items

            delegate: Rectangle {
                id: trayItem

                required property SystemTrayItem modelData

                width: root.itemSize
                height: root.itemSize
                radius: 6
                color: "transparent"

                IconImage {
                    anchors.centerIn: parent

                    implicitWidth: root.itemSize
                    implicitHeight: root.itemSize

                    source: trayItem.modelData.icon
                }

                MouseArea {
                    anchors.fill: parent

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function (mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            trayItem.modelData.activate();
                        } else if (mouse.button === Qt.RightButton && trayItem.modelData.hasMenu) {
                            trayItem.modelData.display(trayItem, 0, trayItem.height);
                        }
                    }
                }
            }
        }
    }
}
