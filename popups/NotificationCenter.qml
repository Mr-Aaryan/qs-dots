import QtQuick
import QtQuick.Layouts
import Quickshell

import "../theme"
import "../services"

Item {
    id: notificationCenter

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool opened: false

    readonly property int panelWidth: 320
    readonly property int panelHeight: 420

    width: panelWidth
    height: panelHeight

    // ============================================================
    // OUR NOTIFICATION STORE
    // ============================================================

    /*
     * Mirrors the shared notification service. The server itself
     * lives there because only one may exist in the shell, and the
     * on-screen toasts read from the same store.
     */
    readonly property var notifications: Notifications.notifications

    // ============================================================
    // DATE HELPERS
    // ============================================================

    function startOfDay(date) {
        return new Date(date.getFullYear(), date.getMonth(), date.getDate());
    }

    function isSameDay(a, b) {
        return (a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate());
    }

    function isToday(date) {
        return isSameDay(date, new Date());
    }

    function isYesterday(date) {
        const today = startOfDay(new Date());

        const yesterday = new Date(today);

        yesterday.setDate(yesterday.getDate() - 1);

        return isSameDay(date, yesterday);
    }

    function dateLabel(date) {
        if (isToday(date))
            return "Today";

        if (isYesterday(date))
            return "Yesterday";

        return Qt.formatDate(date, "MMM d");
    }

    // ============================================================
    // GROUP NOTIFICATIONS
    // ============================================================

    function buildGroups() {
        const groups = [];

        for (let i = 0; i < notificationCenter.notifications.length; i++) {
            const entry = notificationCenter.notifications[i];

            const label = dateLabel(entry.timestamp);

            let group = null;

            for (let j = 0; j < groups.length; j++) {
                if (groups[j].label === label) {
                    group = groups[j];
                    break;
                }
            }

            if (group === null) {
                group = {
                    label: label,
                    timestamp: entry.timestamp,
                    items: []
                };

                groups.push(group);
            }

            group.items.push(entry);
        }

        return groups;
    }

    property var notificationGroups: {
        return buildGroups();
    }

    // ============================================================
    // DISMISS ONE
    // ============================================================

    function dismissNotification(entry) {
        Notifications.dismissNotification(entry);
    }

    // ============================================================
    // CLEAR ALL
    // ============================================================

    function clearAll() {
        Notifications.clearAll();
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        opened = true;
    }

    function close() {
        opened = false;
    }

    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    // ============================================================
    // SLIDE ANIMATION
    // ============================================================

    Item {
        id: revealArea

        anchors.fill: parent

        clip: true

        Item {
            id: animatedContent

            width: parent.width
            height: parent.height

            y: notificationCenter.opened ? 0 : -height

            opacity: notificationCenter.opened ? 1 : 0.85

            Behavior on y {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            // ====================================================
            // PANEL
            // ====================================================

            Rectangle {
                id: panel

                anchors.fill: parent

                radius: 12

                color: Colors.panel

                border.width: 1
                border.color: Colors.surface

                // =================================================
                // CONTENT
                // =================================================

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins: 12

                    spacing: 8

                    // =============================================
                    // HEADER
                    // =============================================

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Notifications"

                            color: Colors.text

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.lg

                            font.bold: true

                            textFormat: Text.PlainText

                            Layout.fillWidth: true
                        }

                        // =========================================
                        // CLEAR ALL
                        // =========================================

                        Rectangle {
                            id: clearButton

                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

                            radius: 7

                            color: clearMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "󰃢"

                                color: clearMouse.containsMouse ? Colors.text : Colors.subtext

                                font.pixelSize: 17

                                textFormat: Text.PlainText

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: clearMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    notificationCenter.clearAll();
                                }
                            }
                        }
                    }

                    // =============================================
                    // EMPTY STATE
                    // =============================================

                    Text {
                        visible: notificationCenter.notifications.length === 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        text: "No notifications"

                        color: Colors.subtext

                        opacity: 0.6

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.md

                        textFormat: Text.PlainText
                    }

                    // =============================================
                    // GROUPED NOTIFICATIONS
                    // =============================================

                    ListView {
                        id: notificationList

                        visible: notificationCenter.notifications.length > 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing: 12

                        model: notificationCenter.notificationGroups

                        delegate: Column {
                            id: groupDelegate

                            required property var modelData

                            width: notificationList.width

                            spacing: 6

                            // =========================================
                            // DATE HEADER
                            // =========================================

                            Text {
                                width: parent.width

                                text: groupDelegate.modelData.label

                                color: Colors.subtext

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.sm

                                font.bold: true

                                textFormat: Text.PlainText

                                topPadding: 2
                                bottomPadding: 2
                            }

                            // =========================================
                            // NOTIFICATIONS
                            // =========================================

                            Column {
                                width: parent.width

                                spacing: 6

                                Repeater {
                                    model: groupDelegate.modelData.items

                                    delegate: Rectangle {
                                        id: notificationCard

                                        required property var modelData

                                        width: parent.width

                                        height: 62

                                        radius: 8

                                        color: Colors.surface

                                        RowLayout {
                                            anchors.fill: parent

                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 6

                                            spacing: 8

                                            // =========================
                                            // TEXT
                                            // =========================

                                            ColumnLayout {
                                                Layout.fillWidth: true

                                                Layout.alignment: Qt.AlignVCenter

                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true

                                                    text: notificationCard.modelData.notification.summary

                                                    color: Colors.text

                                                    font.family: Typography.firaCode

                                                    font.pixelSize: Typography.sm

                                                    font.bold: true

                                                    elide: Text.ElideRight

                                                    maximumLineCount: 1

                                                    textFormat: Text.PlainText
                                                }

                                                Text {
                                                    Layout.fillWidth: true

                                                    text: notificationCard.modelData.notification.body

                                                    color: Colors.subtext

                                                    font.family: Typography.firaCode

                                                    font.pixelSize: Typography.xs

                                                    elide: Text.ElideRight

                                                    maximumLineCount: 2

                                                    wrapMode: Text.Wrap

                                                    textFormat: Text.PlainText
                                                }
                                            }

                                            // =========================
                                            // DISMISS
                                            // =========================

                                            Rectangle {
                                                id: dismissButton

                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28

                                                Layout.alignment: Qt.AlignVCenter

                                                radius: 7

                                                color: dismissMouse.containsMouse ? "#ef4444" : "transparent"

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 120
                                                    }
                                                }

                                                Text {
                                                    anchors.centerIn: parent

                                                    text: "×"

                                                    color: dismissMouse.containsMouse ? "#ffffff" : Colors.subtext

                                                    font.family: Typography.firaCode

                                                    font.pixelSize: 16

                                                    textFormat: Text.PlainText

                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: 120
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: dismissMouse

                                                    anchors.fill: parent

                                                    hoverEnabled: true

                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: {
                                                        notificationCenter.dismissNotification(notificationCard.modelData);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
