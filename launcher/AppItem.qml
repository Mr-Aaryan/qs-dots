pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../theme"

/*
 * One row in the spotlight result list.
 *
 * The row draws its own selection fill rather than letting the list
 * paint a highlight behind it, because the selection follows the
 * keyboard as well as the mouse and has to move without the lag a
 * separate highlight item would introduce.
 */
Rectangle {
    id: root

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * A search result as built by AppLauncher — `entry` is the
     * DesktopEntry, `subtitle` the caption shown on the right.
     */
    required property var result

    property bool selected: false

    signal activated
    signal hovered

    readonly property var entry: root.result.entry

    // ============================================================
    // APPEARANCE
    // ============================================================

    height: 44

    radius: 10

    color: root.selected ? Colors.accent : "transparent"

    /*
     * No colour transition on selection. Held arrow keys move the
     * selection faster than any easing can follow, and a fade turns
     * that into two rows glowing at once.
     */

    RowLayout {
        anchors.fill: parent

        anchors.leftMargin: 12
        anchors.rightMargin: 14

        spacing: 12

        IconImage {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28

            /*
             * Already resolved to a real path by AppLauncher, which
             * drops any entry whose icon it could not find.
             */
            source: root.result.icon

            asynchronous: true
        }

        Text {
            Layout.fillWidth: true

            text: root.entry.name

            color: root.selected ? Colors.base : Colors.text

            font.family: Typography.ui
            font.pixelSize: Typography.md
            font.weight: root.selected ? Typography.demiBold : Typography.medium

            elide: Text.ElideRight

            textFormat: Text.PlainText
        }

        /*
         * macOS puts the result's kind on the right of the row. The
         * generic name ("Web Browser") says more than "Application"
         * where the entry provides one.
         */
        Text {
            visible: root.result.subtitle !== ""

            Layout.maximumWidth: root.width * 0.35

            text: root.result.subtitle

            color: root.selected ? Colors.base : Colors.subtext

            opacity: root.selected ? 0.75 : 1

            font.family: Typography.ui
            font.pixelSize: Typography.xs

            horizontalAlignment: Text.AlignRight

            elide: Text.ElideRight

            textFormat: Text.PlainText
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.hovered();
        }

        onClicked: {
            root.activated();
        }
    }
}
