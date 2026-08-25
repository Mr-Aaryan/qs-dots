pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

import "../theme"
import "../services"

/*
 * On-screen notification toasts, stacked under the top bar on the
 * right. Fed by the shared Notifications service — this window owns
 * no server of its own.
 */
PanelWindow {
    id: toasts

    property int barHeight: 28

    readonly property int toastWidth: 360

    anchors {
        top: true
        right: true
    }

    margins.top: toasts.barHeight + 10
    margins.right: 10

    implicitWidth: toastWidth

    /*
     * Sized to the stack so the window never covers more of the
     * screen than it is actually drawing.
     */
    implicitHeight: Math.max(1, column.implicitHeight)

    color: "transparent"

    aboveWindows: true

    exclusionMode: ExclusionMode.Ignore

    visible: Notifications.popups.length > 0

    Column {
        id: column

        width: parent.width

        spacing: 8

        Repeater {
            /*
             * A fixed pool of slots rather than a model over the
             * array: reassigning the array would rebuild every
             * delegate, replaying the entry animation on toasts that
             * were already on screen.
             */
            model: Notifications.popupLimit

            delegate: Item {
                id: slot

                required property int index

                readonly property var popup: Notifications.popups[slot.index] ?? null

                readonly property var notification: slot.popup ? slot.popup.entry.notification : null

                readonly property bool filled: slot.popup !== null

                readonly property bool critical: slot.filled && slot.notification.urgency === NotificationUrgency.Critical

                width: column.width

                height: slot.filled ? card.implicitHeight : 0

                opacity: slot.filled ? 1 : 0

                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: 180

                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }

                Rectangle {
                    id: card

                    width: parent.width

                    implicitHeight: Math.max(64, cardLayout.implicitHeight + 20)

                    x: slot.filled ? 0 : slot.width

                    radius: 12

                    color: Colors.panel

                    border.width: 1
                    border.color: slot.critical ? Colors.error : Colors.surface

                    Behavior on x {
                        NumberAnimation {
                            duration: 220

                            easing.type: Easing.OutCubic
                        }
                    }

                    RowLayout {
                        id: cardLayout

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        anchors.leftMargin: 12
                        anchors.rightMargin: 10

                        spacing: 10

                        // =========================================
                        // ICON
                        // =========================================

                        Rectangle {
                            visible: iconImage.source != ""

                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36

                            Layout.alignment: Qt.AlignTop

                            radius: 8

                            color: Colors.surface

                            clip: true

                            Image {
                                id: iconImage

                                anchors.fill: parent

                                anchors.margins: 2

                                source: slot.filled ? Notifications.iconFor(slot.notification) : ""

                                fillMode: Image.PreserveAspectFit

                                asynchronous: true

                                sourceSize.width: 72
                            }
                        }

                        // =========================================
                        // TEXT
                        // =========================================

                        ColumnLayout {
                            Layout.fillWidth: true

                            spacing: 2

                            Text {
                                Layout.fillWidth: true

                                visible: slot.filled && slot.notification.appName !== ""

                                text: slot.filled ? slot.notification.appName : ""

                                color: slot.critical ? Colors.error : Colors.accent

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.xs

                                font.bold: true

                                elide: Text.ElideRight

                                textFormat: Text.PlainText
                            }

                            Text {
                                Layout.fillWidth: true

                                visible: text !== ""

                                text: slot.filled ? slot.notification.summary : ""

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

                                visible: text !== ""

                                text: slot.filled ? slot.notification.body : ""

                                color: Colors.subtext

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.xs

                                wrapMode: Text.Wrap

                                elide: Text.ElideRight

                                maximumLineCount: 3

                                textFormat: Text.PlainText
                            }

                            // =====================================
                            // ACTIONS
                            // =====================================

                            Flow {
                                Layout.fillWidth: true

                                Layout.topMargin: 4

                                spacing: 6

                                Repeater {
                                    model: slot.filled ? slot.notification.actions : []

                                    delegate: Rectangle {
                                        id: actionChip

                                        required property var modelData

                                        width: actionText.implicitWidth + 18
                                        height: 22

                                        radius: 7

                                        color: actionChipMouse.containsMouse ? Colors.accent : Colors.surface

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }

                                        Text {
                                            id: actionText

                                            anchors.centerIn: parent

                                            text: actionChip.modelData.text

                                            color: actionChipMouse.containsMouse ? Colors.base : Colors.text

                                            font.family: Typography.firaCode

                                            font.pixelSize: Typography.xs

                                            textFormat: Text.PlainText
                                        }

                                        MouseArea {
                                            id: actionChipMouse

                                            anchors.fill: parent

                                            hoverEnabled: true

                                            cursorShape: Qt.PointingHandCursor

                                            onClicked: {
                                                actionChip.modelData.invoke();

                                                Notifications.dismissPopup(slot.popup);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // =========================================
                        // CLOSE
                        // =========================================

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Layout.alignment: Qt.AlignTop

                            radius: 7

                            color: closeMouse.containsMouse ? Colors.error : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "×"

                                color: closeMouse.containsMouse ? "#ffffff" : Colors.subtext

                                font.family: Typography.firaCode

                                font.pixelSize: 15

                                textFormat: Text.PlainText
                            }

                            MouseArea {
                                id: closeMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    Notifications.dismissNotification(slot.popup.entry);
                                }
                            }
                        }
                    }

                    /*
                     * Declared last so it sits under the action chips
                     * and close button, which need their own clicks.
                     */
                    MouseArea {
                        anchors.fill: parent

                        z: -1

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            Notifications.dismissPopup(slot.popup);
                        }
                    }
                }
            }
        }
    }
}
