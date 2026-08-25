import QtQuick
import Quickshell
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

                /*
                 * The item's own context menu, served over DBusMenu by
                 * the application.
                 *
                 * This used to call modelData.display(trayItem, ...),
                 * which silently did nothing: that method's first
                 * argument is a *window*, and a Rectangle is not one.
                 * QsMenuAnchor takes the item directly and is the
                 * supported way to place one of these.
                 */
                QsMenuAnchor {
                    id: trayMenu

                    menu: trayItem.modelData.menu

                    anchor.item: trayItem

                    // Hang it off the bottom edge, aligned to the icon.
                    anchor.edges: Edges.Bottom

                    anchor.gravity: Edges.Bottom
                }

                MouseArea {
                    anchors.fill: parent

                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function (mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            trayItem.modelData.activate();

                            return;
                        }

                        if (!trayItem.modelData.hasMenu)
                            return;

                        /*
                         * Right-clicking the same icon again dismisses
                         * a menu that is already up.
                         */
                        if (trayMenu.visible)
                            trayMenu.close();
                        else
                            trayMenu.open();
                    }
                }
            }
        }
    }
}
