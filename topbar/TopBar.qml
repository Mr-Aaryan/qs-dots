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

    margins.top: 2

    exclusiveZone: barHeight
    aboveWindows: true
    exclusionMode: ExclusionMode.Auto

    // ============================================================
    // CLICK-THROUGH MASK
    // ============================================================

    mask: Region {

        // Top bar
        Region {
            item: bar
        }

        // Notification center
        Region {
            x: notificationCenter.x
            y: notificationCenter.y

            width: notificationCenter.width
            height: notificationCenter.height

            intersection: notificationCenter.opened ? Intersection.Combine : Intersection.Subtract
        }

        // Clipboard center
        Region {
            x: clipboardCenter.x
            y: clipboardCenter.y

            width: clipboardCenter.width
            height: clipboardCenter.height

            intersection: clipboardCenter.opened ? Intersection.Combine : Intersection.Subtract
        }

        // Network center
        Region {
            x: networkCenter.x
            y: networkCenter.y

            width: networkCenter.width
            height: networkCenter.height

            intersection: networkCenter.opened ? Intersection.Combine : Intersection.Subtract
        }

        // Dashboard center
        Region {
            x: dashboardCenter.x
            y: dashboardCenter.y

            width: dashboardCenter.width
            height: dashboardCenter.height

            intersection: dashboardCenter.opened ? Intersection.Combine : Intersection.Subtract
        }
    }

    // ============================================================
    // OUTSIDE CLICK
    // ============================================================

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

    // ============================================================
    // NOTIFICATION CENTER
    // ============================================================

    NotificationCenter {
        id: notificationCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    // ============================================================
    // CLIPBOARD CENTER
    // ============================================================

    ClipboardCenter {
        id: clipboardCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    // ============================================================
    // NETWORK CENTER
    // ============================================================

    NetworkCenter {
        id: networkCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    // ============================================================
    // DASHBOARD CENTER
    // ============================================================

    DashboardCenter {
        id: dashboardCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    // ============================================================
    // TOP BAR
    // ============================================================

    Rectangle {
        id: bar

        width: topbar.barWidth
        height: topbar.barHeight

        anchors.horizontalCenter: parent.horizontalCenter

        color: Colors.base
        radius: 8

        // ========================================================
        // LEFT GROUP
        // ========================================================

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

        // ========================================================
        // CENTER
        // ========================================================

        Clock {
            anchors.centerIn: parent

            onClicked: {
                notificationCenter.close();
                clipboardCenter.close();
                networkCenter.close();

                dashboardCenter.toggle();
            }
        }

        // ========================================================
        // RIGHT GROUP
        // ========================================================

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

                // ------------------------------------------------
                // NETWORK
                // ------------------------------------------------

                NetworkIcon {
                    onClicked: {
                        // Close other centers first.
                        notificationCenter.close();
                        clipboardCenter.close();
                        dashboardCenter.close();

                        // Toggle network center.
                        networkCenter.toggle();
                    }
                }

                // ------------------------------------------------
                // CLIPBOARD
                // ------------------------------------------------

                ClipboardIcon {
                    onClicked: {
                        notificationCenter.close();
                        networkCenter.close();
                        dashboardCenter.close();

                        clipboardCenter.toggle();
                    }
                }

                // ------------------------------------------------
                // NOTIFICATIONS
                // ------------------------------------------------

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
