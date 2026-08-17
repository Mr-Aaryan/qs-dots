import QtQuick
import Quickshell

import "../theme"
import "."

PanelWindow {
    id: topbar

    property int barHeight: 28
    property int barWidth: 520

    implicitHeight: barHeight

    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    margins.top: 2

    // Reserve space so tiled windows start below the bar.
    exclusiveZone: height
    aboveWindows: true
    exclusionMode: ExclusionMode.Auto

    Rectangle {
        id: bar

        width: topbar.barWidth
        height: topbar.barHeight

        anchors.horizontalCenter: parent.horizontalCenter

        color: Colors.base
        radius: 8

        // Left group
        Row {
            id: leftGroup

            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }

            spacing: 12

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
            }
            SysTray {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Center
        Clock {
            anchors.centerIn: parent
        }

        // Right group
        Rectangle {
            id: rightGroupBackground

            height: 24
            width: rightGroup.implicitWidth + 8

            color: "transparent"
            radius: 8

            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            Row {
                id: rightGroup

                anchors.centerIn: parent

                spacing: 2

                NetworkIcon {}
                BluetoothIcon {}
                NotificationIcon {}
            }
        }
    }
}
