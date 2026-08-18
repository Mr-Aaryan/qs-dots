import QtQuick
import Quickshell
import Quickshell.Hyprland

import "../theme"
import "../popups"
import "."

PanelWindow {
    id: topbar

    property int barHeight: 28
    property int barWidth: 520

    implicitHeight: barHeight + Math.max(notificationCenter.panelHeight, Math.max(clipboardCenter.panelHeight, Math.max(networkCenter.panelHeight, dashboardCenter.panelHeight))) + 16
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    exclusiveZone: barHeight
    aboveWindows: true
    exclusionMode: ExclusionMode.Auto

    mask: Region {
        Region {
            item: bar
        }
        Region {
            x: notificationCenter.x
            y: notificationCenter.y

            width: notificationCenter.width
            height: notificationCenter.height

            intersection: notificationCenter.opened ? Intersection.Combine : Intersection.Subtract
        }
        Region {
            x: clipboardCenter.x
            y: clipboardCenter.y

            width: clipboardCenter.width
            height: clipboardCenter.height

            intersection: clipboardCenter.opened ? Intersection.Combine : Intersection.Subtract
        }
        Region {
            x: networkCenter.x
            y: networkCenter.y

            width: networkCenter.width
            height: networkCenter.height

            intersection: networkCenter.opened ? Intersection.Combine : Intersection.Subtract
        }
        Region {
            x: dashboardCenter.x
            y: dashboardCenter.y

            width: dashboardCenter.width
            height: dashboardCenter.height

            intersection: dashboardCenter.opened ? Intersection.Combine : Intersection.Subtract
        }
    }

    HyprlandFocusGrab {
        id: popupGrab

        windows: [topbar]

        active: notificationCenter.opened || clipboardCenter.opened || networkCenter.opened || dashboardCenter.opened

        onCleared: {
            notificationCenter.close();
            clipboardCenter.close();
            networkCenter.close();
            dashboardCenter.close();
        }
    }

    NotificationCenter {
        id: notificationCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    ClipboardCenter {
        id: clipboardCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    NetworkCenter {
        id: networkCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    DashboardCenter {
        id: dashboardCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    Rectangle {
        id: bar

        width: topbar.barWidth
        height: topbar.barHeight

        anchors.horizontalCenter: parent.horizontalCenter

        color: Colors.base
        radius: 8

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

        Clock {
            anchors.centerIn: parent

            onClicked: {
                notificationCenter.close();
                clipboardCenter.close();
                networkCenter.close();

                dashboardCenter.toggle();
            }
        }

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

                NetworkIcon {
                    onClicked: {
                        notificationCenter.close();
                        clipboardCenter.close();
                        dashboardCenter.close();

                        networkCenter.toggle();
                    }
                }

                ClipboardIcon {
                    onClicked: {
                        notificationCenter.close();
                        networkCenter.close();
                        dashboardCenter.close();

                        clipboardCenter.toggle();
                    }
                }

                NotificationIcon {
                    onClicked: {
                        clipboardCenter.close();
                        networkCenter.close();
                        dashboardCenter.close();

                        notificationCenter.toggle();
                    }
                }
            }
        }
    }
}
