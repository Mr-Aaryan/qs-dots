pragma ComponentBehavior: Bound

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

import "../theme"

/*
 * Thumbnail grid over a wallpaper directory.
 *
 * Shared by the control center's chevron picker and the dashboard's
 * Wallpapers tab, so both stay in step.
 */
Item {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    property string directory: Quickshell.env("HOME") + "/Pictures/wallpaper"

    property int columns: 3

    /*
     * Thumbnail height as a fraction of its width.
     */
    property real cellRatio: 0.62

    readonly property alias count: grid.count

    /*
     * Absolute path of the wallpaper currently on screen, used to
     * mark it in the grid.
     */
    property string currentPath: ""

    signal selected(string path)

    // ============================================================
    // ACTIVE WALLPAPER
    // ============================================================

    Process {
        id: activeProcess

        command: ["hyprctl", "hyprpaper", "listactive"]

        stdout: StdioCollector {
            onStreamFinished: {
                /*
                 * Output is "<monitor>: <path>", one line per output.
                 * Any of them will do — they are normally identical.
                 */
                const line = this.text.trim().split("\n")[0] ?? "";

                const separator = line.indexOf(": ");

                root.currentPath = separator === -1 ? "" : line.substring(separator + 2).trim();
            }
        }
    }

    function refresh() {
        activeProcess.running = false;
        activeProcess.running = true;
    }

    Component.onCompleted: {
        refresh();
    }

    // ============================================================
    // GRID
    // ============================================================

    GridView {
        id: grid

        anchors.fill: parent

        clip: true

        cellWidth: Math.floor(grid.width / root.columns)
        cellHeight: Math.floor(grid.cellWidth * root.cellRatio)

        model: FolderListModel {
            folder: "file://" + root.directory

            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]

            showDirs: false

            sortField: FolderListModel.Name
        }

        delegate: Item {
            id: cell

            required property string filePath
            required property string fileName

            readonly property bool hovered: cellMouse.containsMouse

            readonly property bool current: root.currentPath !== "" && root.currentPath === cell.filePath

            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent

                /*
                 * The margin doubles as headroom for the hover
                 * scale, so a lifted thumbnail is not clipped by
                 * the grid.
                 */
                anchors.margins: 4

                radius: 10

                color: Colors.surface

                clip: true

                scale: cell.hovered ? 1.06 : 1

                border.width: cell.hovered || cell.current ? 2 : 0
                border.color: cell.current ? Colors.accent : Colors.text

                Behavior on scale {
                    NumberAnimation {
                        duration: 130

                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    anchors.fill: parent

                    source: "file://" + cell.filePath

                    fillMode: Image.PreserveAspectCrop

                    asynchronous: true

                    /*
                     * Several of these are 4K. Decoding at thumbnail
                     * size keeps scrolling cheap.
                     */
                    sourceSize.width: 240
                }

                /*
                 * Resting thumbnails are held back slightly so the
                 * hovered one reads as lit rather than merely outlined.
                 */
                Rectangle {
                    anchors.fill: parent

                    color: "#000000"

                    opacity: cell.hovered ? 0 : 0.22

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 130
                        }
                    }
                }

                // =============================================
                // NAME ON HOVER
                // =============================================

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 18

                    color: Qt.rgba(0, 0, 0, 0.65)

                    opacity: cell.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 130
                        }
                    }

                    Text {
                        anchors.fill: parent

                        anchors.leftMargin: 6
                        anchors.rightMargin: 6

                        text: cell.fileName

                        color: "#ffffff"

                        font.family: Typography.ui

                        font.pixelSize: Typography.xs

                        elide: Text.ElideMiddle

                        verticalAlignment: Text.AlignVCenter

                        textFormat: Text.PlainText
                    }
                }

                // =============================================
                // CURRENT MARKER
                // =============================================

                Rectangle {
                    visible: cell.current

                    anchors {
                        top: parent.top
                        right: parent.right

                        topMargin: 5
                        rightMargin: 5
                    }

                    width: 18
                    height: 18

                    radius: 9

                    color: Colors.accent

                    Text {
                        anchors.centerIn: parent

                        text: "󰄬"

                        color: Colors.base

                        font.pixelSize: 11

                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    id: cellMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.selected(cell.filePath);
                    }
                }
            }
        }
    }
}
