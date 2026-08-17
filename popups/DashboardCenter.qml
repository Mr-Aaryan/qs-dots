import QtQuick
import QtQuick.Dialogs
import Quickshell.Io
import QtQuick.Effects

import "../theme"
import "../settings"

Item {
    id: dashboardCenter

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool opened: false
    property bool fileDialogOpen: false

    readonly property int panelWidth: 410
    readonly property int panelHeight: 320

    width: panelWidth
    height: panelHeight

    // ============================================================
    // PROFILE
    // ============================================================

    property string profileImage: ""
    property string userName: "Mr-Aaryan"

    property bool editingUserName: false
    property string editingName: ""

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
        opened ? close() : open();
    }

    // ============================================================
    // LOAD SETTINGS
    // ============================================================

    Component.onCompleted: {
        updateDateTime();
    }

    Connections {
        target: Settings

        function onProfileImageChanged() {
            dashboardCenter.profileImage = Settings.profileImage;

            console.log("Dashboard profile updated:", dashboardCenter.profileImage);
        }

        function onUserNameChanged() {
            dashboardCenter.userName = Settings.userName;
        }
    }

    // ============================================================
    // USERNAME
    // ============================================================

    function startEditingUserName() {
        editingName = userName;
        editingUserName = true;

        nameInput.forceActiveFocus();
        nameInput.selectAll();
    }

    function saveUserName() {
        const newName = nameInput.text.trim();

        if (newName.length > 0) {
            dashboardCenter.userName = newName;

            Settings.userName = newName;
            Settings.save();
        }

        editingUserName = false;
    }

    // ============================================================
    // PROFILE PICKER
    // ============================================================

    FileDialog {
        id: profileDialog

        title: "Choose Profile Picture"

        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif)"]

        onAccepted: {
            const imagePath = selectedFile.toString();

            dashboardCenter.profileImage = imagePath;

            Settings.profileImage = imagePath;
            Settings.save();

            dashboardCenter.fileDialogOpen = false;
        }

        onRejected: {
            dashboardCenter.fileDialogOpen = false;
        }
    }

    function chooseProfileImage() {
        fileDialogOpen = true;
        profileDialog.open();
    }

    // ============================================================
    // SYSTEM TIME
    // ============================================================

    property string currentTime: ""
    property string currentDate: ""

    function updateDateTime() {
        const now = new Date();

        currentTime = Qt.formatTime(now, "h:mm AP");
        currentDate = Qt.formatDate(now, "MMM d");
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            dashboardCenter.updateDateTime();
        }
    }

    // ============================================================
    // UPTIME
    // ============================================================

    property string uptime: "--"

    Process {
        id: uptimeProcess

        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]

        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const value = text.trim();

                if (value.length > 0)
                    dashboardCenter.uptime = value;
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true

        onTriggered: {
            uptimeProcess.running = true;
        }
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

            y: dashboardCenter.opened ? 0 : -height

            opacity: dashboardCenter.opened ? 1 : 0.8

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
            // MAIN PANEL
            // ====================================================

            Rectangle {
                anchors.fill: parent

                radius: 16

                color: Colors.base

                border.width: 1
                border.color: Colors.surface

                // =================================================
                // HEADER
                // =================================================

                Item {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right

                        topMargin: 14
                        leftMargin: 18
                        rightMargin: 18
                    }

                    height: 52

                    // =============================================
                    // DATE / TIME
                    // =============================================

                    Column {
                        id: dateInfo

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        spacing: 1

                        Text {
                            text: dashboardCenter.currentTime

                            color: Colors.text

                            font.family: Typography.firaCode
                            font.pixelSize: Typography.lg
                        }

                        Text {
                            text: dashboardCenter.currentDate

                            color: Colors.subtext

                            font.family: Typography.firaCode
                            font.pixelSize: Typography.xs
                        }
                    }

                    // =============================================
                    // PROFILE + USER INFO
                    // =============================================

                    Row {
                        id: userSection

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        spacing: 9

                        // -----------------------------------------
                        // PROFILE
                        // -----------------------------------------

                        Item {
                            id: profileArea

                            width: 46
                            height: 46

                            Rectangle {
                                id: profileCircle

                                anchors.fill: parent

                                radius: width / 2

                                color: Colors.surface

                                border.width: 2
                                border.color: Colors.text

                                clip: true

                                Image {
                                    id: profileImageSource

                                    anchors.fill: parent

                                    source: dashboardCenter.profileImage

                                    fillMode: Image.PreserveAspectCrop

                                    asynchronous: true
                                    cache: true

                                    visible: false
                                }

                                MultiEffect {
                                    id: profileImageEffect

                                    anchors.fill: profileCircle

                                    source: profileImageSource

                                    maskEnabled: true

                                    maskSource: profileMask

                                    maskThresholdMin: 0.5

                                    visible: profileImageSource.status === Image.Ready
                                }

                                Rectangle {
                                    id: profileMask

                                    width: 46
                                    height: 46

                                    radius: 23

                                    color: "white"

                                    visible: false

                                    layer.enabled: true
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰀄"

                                    color: Colors.subtext

                                    font.pixelSize: 21

                                    visible: profileImageSource.status !== Image.Ready
                                }
                            }

                            // -------------------------------------
                            // EDIT IMAGE
                            // -------------------------------------

                            Rectangle {
                                id: profileEditButton

                                width: 18
                                height: 18

                                radius: 9

                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                }

                                color: profileEditMouse.containsMouse ? Colors.surface : Colors.base

                                border.width: 1
                                border.color: Colors.text

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰏫"

                                    color: Colors.text

                                    font.pixelSize: 9
                                }

                                MouseArea {
                                    id: profileEditMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        dashboardCenter.chooseProfileImage();
                                    }
                                }
                            }
                        }

                        // -----------------------------------------
                        // NAME + UPTIME
                        // -----------------------------------------

                        Column {
                            anchors.verticalCenter: parent.verticalCenter

                            spacing: 2

                            // =====================================
                            // USERNAME
                            // =====================================

                            Item {
                                width: 105
                                height: 20

                                Text {
                                    id: nameText

                                    anchors.fill: parent

                                    text: dashboardCenter.userName

                                    color: Colors.text

                                    font.family: Typography.firaCode
                                    font.pixelSize: Typography.sm
                                    font.bold: true

                                    verticalAlignment: Text.AlignVCenter

                                    elide: Text.ElideRight

                                    visible: !dashboardCenter.editingUserName

                                    MouseArea {
                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            dashboardCenter.startEditingUserName();
                                        }
                                    }
                                }

                                // =================================
                                // NAME EDITOR
                                // =================================

                                TextInput {
                                    id: nameInput

                                    anchors.fill: parent

                                    text: dashboardCenter.editingName

                                    color: Colors.text

                                    font.family: Typography.firaCode
                                    font.pixelSize: Typography.sm
                                    font.bold: true

                                    verticalAlignment: Text.AlignVCenter

                                    selectByMouse: true

                                    clip: true

                                    visible: dashboardCenter.editingUserName

                                    onAccepted: {
                                        dashboardCenter.saveUserName();
                                    }

                                    Keys.onEscapePressed: {
                                        dashboardCenter.editingUserName = false;
                                    }

                                    onActiveFocusChanged: {
                                        if (!activeFocus && dashboardCenter.editingUserName) {
                                            dashboardCenter.saveUserName();
                                        }
                                    }
                                }
                            }

                            // =====================================
                            // UPTIME
                            // =====================================

                            Text {
                                text: dashboardCenter.uptime

                                color: Colors.subtext

                                font.family: Typography.firaCode
                                font.pixelSize: Typography.xs

                                width: 105

                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // =================================================
                // DIVIDER
                // =================================================

                Rectangle {
                    anchors {
                        top: header.bottom
                        left: parent.left
                        right: parent.right

                        leftMargin: 18
                        rightMargin: 18
                    }

                    height: 1

                    color: Colors.surface

                    opacity: 0.7
                }

                // =================================================
                // CONTENT
                // =================================================

                Row {
                    id: content

                    property bool musicAvailable: musicPlayer.hasPlayer

                    anchors {
                        top: header.bottom

                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom

                        topMargin: 10
                        leftMargin: 16
                        rightMargin: 16
                        bottomMargin: 16
                    }

                    spacing: musicAvailable ? 10 : 0

                    // =============================================
                    // CALENDAR
                    // =============================================

                    Rectangle {
                        id: calendarContainer

                        width: content.musicAvailable ? 218 : content.width

                        height: parent.height

                        radius: 14

                        color: Colors.surface

                        clip: true

                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        Calendar {
                            anchors.fill: parent
                            anchors.margins: 8
                        }
                    }

                    // =============================================
                    // MUSIC PLAYER
                    // =============================================

                    Rectangle {
                        id: musicContainer

                        width: content.musicAvailable ? content.width - calendarContainer.width - content.spacing : 0

                        height: parent.height

                        radius: 14

                        color: Colors.surface

                        clip: true

                        visible: content.musicAvailable

                        opacity: content.musicAvailable ? 1 : 0

                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        MusicPlayer {
                            id: musicPlayer

                            anchors.fill: parent

                            anchors.margins: 4
                        }
                    }
                }
            }
        }
    }
}
