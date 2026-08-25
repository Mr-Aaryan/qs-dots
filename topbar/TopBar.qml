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

    /*
     * Breathing room between the screen edge and the bar. Added to
     * the exclusive zone as well, so tiled windows start below the
     * gap rather than sliding under it.
     *
     * NotificationToast mirrors this — the toasts are their own
     * window and have to be pushed down by the same amount.
     */
    property int topGap: 2

    /*
     * Toggled by SUPER+SHIFT+W, the way killall -SIGUSR1 used to hide
     * waybar.
     *
     * Hiding unmaps the whole layer surface rather than just making
     * the bar Rectangle invisible. That is what releases the
     * exclusive zone, so tiled windows actually reclaim the strip
     * instead of leaving a gap where the bar used to be.
     *
     * The GlobalShortcut below keeps working while unmapped -- it is
     * a plain object in the tree, not something the surface owns --
     * so the bar can always be brought back.
     */
    property bool barVisible: true

    visible: topbar.barVisible

    implicitHeight: barHeight + Math.max(notificationCenter.panelHeight, Math.max(clipboardCenter.panelHeight, Math.max(networkCenter.panelHeight, Math.max(dashboardCenter.panelHeight, controlCenter.panelHeight)))) + 16
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }

    margins.top: topbar.topGap

    exclusiveZone: barHeight + topbar.topGap
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

        Region {
            x: controlCenter.x
            y: controlCenter.y

            width: controlCenter.opened ? controlCenter.width : 0
            height: controlCenter.opened ? controlCenter.height : 0

            intersection: Intersection.Combine
        }
    }

    HyprlandFocusGrab {
        id: popupGrab

        windows: [topbar]

        active: notificationCenter.opened || clipboardCenter.opened || networkCenter.opened || dashboardCenter.opened || controlCenter.opened

        onCleared: {
            notificationCenter.close();
            clipboardCenter.close();
            networkCenter.close();
            dashboardCenter.close();
            controlCenter.close();
        }
    }

    function closePopups() {
        notificationCenter.close();
        clipboardCenter.close();
        networkCenter.close();
        dashboardCenter.close();
        controlCenter.close();
    }

    /*
     * Exposed to Hyprland through the global-shortcuts protocol as
     * "quickshell:togglebar":
     *
     *   hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:togglebar"))
     */
    GlobalShortcut {
        appid: "quickshell"
        name: "togglebar"

        description: "Show or hide the top bar"

        onPressed: {
            /*
             * Popups live inside this window, so they would be torn
             * off screen with it while still believing they are open
             * -- and popupGrab would go on holding a grab for a
             * surface that no longer exists. Close them on the way
             * down, and the bar comes back in a clean state.
             */
            if (topbar.barVisible)
                topbar.closePopups();

            topbar.barVisible = !topbar.barVisible;
        }
    }

    /*
     * Exposed to Hyprland through the global-shortcuts protocol as
     * "quickshell:clipboard". Bind it on the Hyprland side with:
     *
     *   hl.bind(mainMod .. " + SHIFT + V", hl.dsp.global("quickshell:clipboard"))
     */
    GlobalShortcut {
        appid: "quickshell"
        name: "clipboard"

        description: "Toggle the clipboard history popup"

        onPressed: {
            notificationCenter.close();
            networkCenter.close();
            dashboardCenter.close();
            controlCenter.close();

            clipboardCenter.toggle();
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

        // The header's back arrow returns to where the chevron came from.
        onBackRequested: {
            networkCenter.close();

            controlCenter.open();
        }
    }

    DashboardCenter {
        id: dashboardCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8
    }

    ControlCenter {
        id: controlCenter

        x: (topbar.width - topbar.barWidth) / 2 + topbar.barWidth - width - 10

        y: topbar.barHeight + 8

        /*
         * A tile chevron hands off to the network center, which the
         * bar owns — the control center gets out of the way first so
         * the two are never open over each other.
         */
        onSectionRequested: section => {
            controlCenter.close();

            notificationCenter.close();
            clipboardCenter.close();
            dashboardCenter.close();

            networkCenter.open(section);
        }
    }

    Rectangle {
        id: bar

        width: topbar.barWidth
        height: topbar.barHeight

        anchors.horizontalCenter: parent.horizontalCenter

        color: Colors.panel
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
                controlCenter.close();

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
                
                ControlCenterIcon {
                    onClicked: {
                        notificationCenter.close();
                        clipboardCenter.close();
                        networkCenter.close();
                        dashboardCenter.close();

                        controlCenter.toggle();
                    }
                }

                NotificationIcon {
                    onClicked: {
                        clipboardCenter.close();
                        networkCenter.close();
                        dashboardCenter.close();
                        controlCenter.close();

                        notificationCenter.toggle();
                    }
                }
            }
        }
    }
}
