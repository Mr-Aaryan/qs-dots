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

    // ============================================================
    // TABS
    // ============================================================

    readonly property var tabs: [
        {
            label: "Overview",
            icon: "󰕮"
        },
        {
            label: "Wallpapers",
            icon: "󰸉"
        },
    ]

    property int tab: 0

    function showTab(index) {
        dashboardCenter.tab = index;

        if (index === 1)
            wallpaperGrid.refresh();
    }

    // ============================================================
    // WALLPAPER
    // ============================================================

    Process {
        id: wallpaperProcess
    }

    function applyWallpaper(path) {
        if (wallpaperProcess.running)
            return;

        /*
         * Set the wallpaper, then re-theme from it. --prefer is
         * required: matugen 4 refuses to choose between multiple
         * source colours when it cannot detect a terminal, which is
         * exactly how it runs from here.
         */
        wallpaperProcess.command = ["bash", "-c", 'hyprctl hyprpaper wallpaper ",$1"; matugen --prefer saturation image "$1"', "wallpaper", path];

        wallpaperProcess.running = true;

        wallpaperRefreshTimer.restart();
    }

    /*
     * hyprpaper needs a moment to switch before the active-wallpaper
     * query reports the new one.
     */
    Timer {
        id: wallpaperRefreshTimer

        interval: 700
        repeat: false

        onTriggered: {
            wallpaperGrid.refresh();
        }
    }

    function currentWallpaperName() {
        const path = wallpaperGrid.currentPath;

        if (path === "")
            return "";
        return path.substring(path.lastIndexOf("/") + 1);
    }

    readonly property int panelWidth: 410
    readonly property int panelHeight: 380

    width: panelWidth
    height: panelHeight

    // ============================================================
    // PROFILE
    // ============================================================

    property string profileImage: ""
    property string userName: "Mr-Aaryan"

    property bool editingUserName: false
    property string editingName: ""

    function open() {
        dashboardCenter.tab = 0;

        opened = true;
    }

    function close() {
        opened = false;
    }

    function toggle() {
        opened ? close() : open();
    }

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

            Rectangle {
                anchors.fill: parent

                radius: 16

                color: Colors.panel

                border.width: 1
                border.color: Colors.surface

                // =================================================
                // TABS
                // =================================================

                Item {
                    id: tabBar

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }

                    height: 46

                    Row {
                        anchors.centerIn: parent

                        spacing: 10

                        Repeater {
                            model: dashboardCenter.tabs

                            delegate: Rectangle {
                                id: tabButton

                                required property var modelData
                                required property int index

                                readonly property bool active: dashboardCenter.tab === tabButton.index

                                width: 108
                                height: 34

                                radius: 9

                                color: tabButton.active ? Colors.surface : (tabMouse.containsMouse ? Colors.surface : "transparent")

                                opacity: tabButton.active || tabMouse.containsMouse ? 1 : 0.65

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 130
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent

                                    spacing: 7

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: tabButton.modelData.icon

                                        color: tabButton.active ? Colors.accent : Colors.subtext

                                        font.pixelSize: 15

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter

                                        text: tabButton.modelData.label

                                        color: tabButton.active ? Colors.text : Colors.subtext

                                        font.family: Typography.firaCode

                                        font.pixelSize: Typography.xs

                                        font.bold: tabButton.active

                                        textFormat: Text.PlainText
                                    }
                                }

                                Rectangle {
                                    visible: tabButton.active

                                    anchors {
                                        bottom: parent.bottom
                                        horizontalCenter: parent.horizontalCenter
                                        bottomMargin: 3
                                    }

                                    width: 22
                                    height: 2

                                    radius: 1

                                    color: Colors.accent
                                }

                                MouseArea {
                                    id: tabMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        dashboardCenter.showTab(tabButton.index);
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================
                // OVERVIEW TAB
                // =================================================

                Item {
                    id: overviewTab

                    anchors {
                        top: tabBar.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    visible: dashboardCenter.tab === 0

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

                // =================================================
                // WALLPAPERS TAB
                // =================================================

                Item {
                    id: wallpaperTab

                    anchors {
                        top: tabBar.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    visible: dashboardCenter.tab === 1

                    WallpaperGrid {
                        id: wallpaperGrid

                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            bottom: wallpaperFooter.top

                            leftMargin: 14
                            rightMargin: 14
                            bottomMargin: 6
                        }

                        columns: 3

                        onSelected: function (path) {
                            dashboardCenter.applyWallpaper(path);
                        }
                    }

                    Item {
                        id: wallpaperFooter

                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom

                            leftMargin: 18
                            rightMargin: 18
                            bottomMargin: 12
                        }

                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: wallpaperGrid.count + " wallpapers"

                            color: Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            textFormat: Text.PlainText
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            width: parent.width * 0.55

                            horizontalAlignment: Text.AlignRight

                            text: dashboardCenter.currentWallpaperName()

                            color: Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            elide: Text.ElideMiddle

                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
