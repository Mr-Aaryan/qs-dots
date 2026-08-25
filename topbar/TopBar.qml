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

        /*
         * The popups overlap each other, so a closed popup must contribute
         * an EMPTY region, never a Subtract — a Subtract would cut the
         * rectangle of whichever popup is currently open back out of the
         * input region, making its clicks fall through to the window below
         * and clearing the focus grab.
         */

        Region {
            x: notificationCenter.x
            y: notificationCenter.y

            width: notificationCenter.opened ? notificationCenter.width : 0
            height: notificationCenter.opened ? notificationCenter.height : 0

            intersection: Intersection.Combine
        }

        Region {
            x: clipboardCenter.x
            y: clipboardCenter.y

            width: clipboardCenter.opened ? clipboardCenter.width : 0
            height: clipboardCenter.opened ? clipboardCenter.height : 0

            intersection: Intersection.Combine
        }

        Region {
            x: networkCenter.x
            y: networkCenter.y

            width: networkCenter.opened ? networkCenter.width : 0
            height: networkCenter.opened ? networkCenter.height : 0

            intersection: Intersection.Combine
        }

        Region {
            x: dashboardCenter.x
            y: dashboardCenter.y

            width: dashboardCenter.opened ? dashboardCenter.width : 0
            height: dashboardCenter.opened ? dashboardCenter.height : 0

            intersection: Intersection.Combine
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

                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                }

                VolumeIcon {
                    anchors.verticalCenter: parent.verticalCenter
                }

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
