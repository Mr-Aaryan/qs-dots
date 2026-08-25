import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell.Io
import QtQuick.Effects

import "../theme"
import "../settings"
import "../shared/components"

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
        {
            label: "System",
            icon: "󰘚"
        },
    ]

    property int tab: 0

    /*
     * How far a page has to travel to reach the middle, in panel
     * widths. The active tab lands on 0, the ones before it sit off
     * to the left, the ones after it off to the right.
     */
    function tabOffset(index) {
        return index - dashboardCenter.tab;
    }

    readonly property int tabSlideDuration: 280

    function showTab(index) {
        dashboardCenter.tab = index;

        if (index === 1)
            wallpaperGrid.refresh();

        /*
         * CPU load is a delta between two samples, so the reading is
         * meaningless until a second one lands. Drop the old sample
         * on entry — it may be minutes stale, which would show as a
         * single wrong figure before the next tick corrects it.
         */
        if (index === 2)
            dashboardCenter.sysHasPrevSample = false;
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

    // ============================================================
    // SYSTEM
    // ============================================================

    property string sysHost: ""
    property string sysKernel: ""
    property string sysOs: ""
    property string sysUptime: ""
    property string sysCpuModel: ""
    property int sysCpuThreads: 0

    property real sysCpuUsage: 0
    property bool sysCpuReady: false

    property real sysMemTotal: 0
    property real sysMemUsed: 0

    // Degrees celsius, or -1 when no sensor was found.
    property real sysTemp: -1

    // [{ mount, size, used }]
    property var sysDisks: []

    /*
     * Previous /proc/stat jiffy counts. CPU load is the change in
     * idle time against the change in total time between two samples;
     * the absolute numbers are counted from boot and say nothing
     * about load right now.
     */
    property real sysPrevTotal: 0
    property real sysPrevIdle: 0
    property bool sysHasPrevSample: false

    /*
     * One shell out per tick rather than a FileView per metric --
     * cheaper, and it keeps every figure from the same instant.
     *
     * Deliberately written with echo and awk only: no printf format
     * strings and no ${...}, both of which would need escaping to
     * survive the template literal this lives in.
     */
    readonly property string systemScript: `
echo "HOST $(uname -n)"
echo "KERNEL $(uname -r)"
awk -F= '/^PRETTY_NAME=/{gsub(/"/,"",$2); print "OS",$2; exit}' /etc/os-release
echo "UPTIME $(uptime -p 2>/dev/null | sed 's/^up //')"
awk '/^cpu /{print "CPUSTAT",$2,$3,$4,$5,$6,$7,$8,$9}' /proc/stat
awk -F': ' '/^model name/{print "CPUMODEL",$2; exit}' /proc/cpuinfo
echo "CPUCOUNT $(nproc)"
awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "MEM",t,a}' /proc/meminfo
temp=""
for z in /sys/class/thermal/thermal_zone*; do
    [ "$(cat "$z/type" 2>/dev/null)" = "x86_pkg_temp" ] && { temp=$(cat "$z/temp" 2>/dev/null); break; }
done
[ -z "$temp" ] && for h in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$h/name" 2>/dev/null)" = "coretemp" ] && { temp=$(cat "$h/temp1_input" 2>/dev/null); break; }
done
[ -z "$temp" ] && for z in /sys/class/thermal/thermal_zone*; do
    [ "$(cat "$z/type" 2>/dev/null)" = "acpitz" ] && { temp=$(cat "$z/temp" 2>/dev/null); break; }
done
[ -n "$temp" ] && echo "TEMP $temp"
df -B1 --output=target,size,used / "$HOME" 2>/dev/null | awk 'NR>1 && !seen[$1]++ {print "DISK",$1,$2,$3}'
`

    Process {
        id: systemProcess

        command: ["sh", "-c", dashboardCenter.systemScript]

        stdout: StdioCollector {
            onStreamFinished: {
                dashboardCenter.parseSystem(this.text);
            }
        }
    }

    /*
     * Only ticks while the tab is actually on screen. Polling a
     * hidden panel would spawn a shell every couple of seconds for
     * numbers nobody is looking at.
     */
    Timer {
        id: systemTimer

        interval: 2000
        repeat: true

        running: dashboardCenter.opened && dashboardCenter.tab === 2

        triggeredOnStart: true

        onTriggered: {
            if (!systemProcess.running)
                systemProcess.running = true;
        }
    }

    function parseSystem(text) {
        const lines = text.split("\n");

        const disks = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            const split = line.indexOf(" ");

            if (split === -1)
                continue;

            const key = line.substring(0, split);
            const value = line.substring(split + 1).trim();

            if (key === "HOST")
                dashboardCenter.sysHost = value;
            else if (key === "KERNEL")
                dashboardCenter.sysKernel = value;
            else if (key === "OS")
                dashboardCenter.sysOs = value;
            else if (key === "UPTIME")
                dashboardCenter.sysUptime = value;
            else if (key === "CPUMODEL")
                dashboardCenter.sysCpuModel = dashboardCenter.tidyCpuModel(value);
            else if (key === "CPUCOUNT")
                dashboardCenter.sysCpuThreads = parseInt(value);
            else if (key === "CPUSTAT")
                dashboardCenter.applyCpuSample(value);
            else if (key === "MEM") {
                const memory = value.split(" ");

                // /proc/meminfo is in kB.
                const total = Number(memory[0]) * 1024;
                const available = Number(memory[1]) * 1024;

                dashboardCenter.sysMemTotal = total;
                dashboardCenter.sysMemUsed = total - available;
            } else if (key === "TEMP")
                dashboardCenter.sysTemp = Number(value) / 1000;
            else if (key === "DISK") {
                const disk = value.split(" ");

                disks.push({
                    mount: disk[0],
                    size: Number(disk[1]),
                    used: Number(disk[2])
                });
            }
        }

        dashboardCenter.sysDisks = disks;
    }

    function applyCpuSample(value) {
        const fields = value.split(" ").map(Number);

        if (fields.length < 5)
            return;

        // idle + iowait: both are time the CPU spent doing nothing.
        const idle = fields[3] + fields[4];

        let total = 0;

        for (let i = 0; i < fields.length; i++)
            total += fields[i];

        if (dashboardCenter.sysHasPrevSample) {
            const totalDelta = total - dashboardCenter.sysPrevTotal;
            const idleDelta = idle - dashboardCenter.sysPrevIdle;

            if (totalDelta > 0) {
                dashboardCenter.sysCpuUsage = Math.max(0, Math.min(1, 1 - idleDelta / totalDelta));

                dashboardCenter.sysCpuReady = true;
            }
        }

        dashboardCenter.sysPrevTotal = total;
        dashboardCenter.sysPrevIdle = idle;

        dashboardCenter.sysHasPrevSample = true;
    }

    /*
     * "12th Gen Intel(R) Core(TM) i5-12500H" is mostly trademark
     * noise at this width.
     */
    function tidyCpuModel(model) {
        return model.replace(/\((R|TM|r|tm)\)/g, "").replace(/\s+CPU\s+/g, " ").replace(/\s+/g, " ").trim();
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "0 GB";

        const gigabytes = bytes / (1024 * 1024 * 1024);

        if (gigabytes >= 10)
            return Math.round(gigabytes) + " GB";
        if (gigabytes >= 1)
            return gigabytes.toFixed(1) + " GB";

        return Math.round(bytes / (1024 * 1024)) + " MB";
    }

    /*
     * Warm and hot thresholds are for a laptop package sensor, where
     * high 70s under load is ordinary and 85+ is worth noticing.
     */
    function tempColor(celsius) {
        if (celsius >= 85)
            return Colors.error;
        if (celsius >= 70)
            return Colors.warning;

        return Colors.accent;
    }

    /*
     * The three live figures, as dials. Rates and temperatures are
     * what a gauge is for -- they sit on a known scale and are read
     * at a glance rather than compared against each other.
     */
    readonly property var systemRings: [
        {
            label: "CPU",
            detail: dashboardCenter.sysCpuThreads > 0 ? dashboardCenter.sysCpuThreads + " threads" : "",
            value: dashboardCenter.sysCpuReady ? Math.round(dashboardCenter.sysCpuUsage * 100) + "%" : "--",
            fraction: dashboardCenter.sysCpuReady ? dashboardCenter.sysCpuUsage : 0,
            tint: dashboardCenter.loadColor(dashboardCenter.sysCpuReady ? dashboardCenter.sysCpuUsage : 0)
        },
        {
            label: "Memory",
            detail: dashboardCenter.sysMemTotal > 0 ? dashboardCenter.formatBytes(dashboardCenter.sysMemUsed) + " / " + dashboardCenter.formatBytes(dashboardCenter.sysMemTotal) : "",
            value: dashboardCenter.sysMemTotal > 0 ? Math.round(dashboardCenter.sysMemUsed / dashboardCenter.sysMemTotal * 100) + "%" : "--",
            fraction: dashboardCenter.sysMemTotal > 0 ? dashboardCenter.sysMemUsed / dashboardCenter.sysMemTotal : 0,
            tint: dashboardCenter.loadColor(dashboardCenter.sysMemTotal > 0 ? dashboardCenter.sysMemUsed / dashboardCenter.sysMemTotal : 0)
        },
        {
            label: "Temp",
            detail: dashboardCenter.sysTemp < 0 ? "no sensor" : "CPU package",
            value: dashboardCenter.sysTemp < 0 ? "--" : Math.round(dashboardCenter.sysTemp) + "°",
            // 30 C floor, 95 C ceiling -- the range a package actually moves in.
            fraction: dashboardCenter.sysTemp < 0 ? 0 : Math.max(0, Math.min(1, (dashboardCenter.sysTemp - 30) / 65)),
            tint: dashboardCenter.tempColor(dashboardCenter.sysTemp)
        }
    ]

    /*
     * Storage stays a bar. It is a ratio of two large fixed numbers
     * that barely moves, and the numbers themselves are the point --
     * a dial would give it a prominence it has not earned.
     */
    readonly property var systemDisks: {
        const rows = [];

        for (let i = 0; i < dashboardCenter.sysDisks.length; i++) {
            const disk = dashboardCenter.sysDisks[i];

            const fraction = disk.size > 0 ? disk.used / disk.size : 0;

            rows.push({
                mount: disk.mount,
                detail: dashboardCenter.formatBytes(disk.used) + " / " + dashboardCenter.formatBytes(disk.size),
                percent: Math.round(fraction * 100) + "%",
                fraction: fraction,
                tint: dashboardCenter.loadColor(fraction)
            });
        }

        return rows;
    }

    /*
     * Shared ramp for anything measured as "how full is it". Kept
     * generous at the low end -- a bar that is orange at 60% trains
     * you to ignore it.
     */
    function loadColor(fraction) {
        if (fraction >= 0.9)
            return Colors.error;
        if (fraction >= 0.75)
            return Colors.warning;

        return Colors.accent;
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

                /*
                 * The tab pages are laid out side by side and slid
                 * horizontally, so the inactive ones sit outside the
                 * panel until it is their turn. Without clipping they
                 * would be drawn over the rest of the shell.
                 */
                clip: true

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

                                        font.family: Typography.ui

                                        font.pixelSize: Typography.xs

                                        /*
                                         * Constant weight. The active
                                         * tab is already carried by
                                         * the fill and the text
                                         * colour; re-weighting on top
                                         * of that also reflows the
                                         * label, which reads as a
                                         * twitch rather than a state.
                                         */
                                        font.weight: Typography.normal

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
                        bottom: parent.bottom
                    }

                    width: parent.width

                    x: dashboardCenter.tabOffset(0) * width

                    /*
                     * Off-screen pages stop rendering, but only once
                     * they are fully outside -- during the slide both
                     * the outgoing and incoming page are partly in
                     * view and both have to draw.
                     */
                    visible: Math.abs(overviewTab.x) < overviewTab.width

                    Behavior on x {
                        NumberAnimation {
                            duration: dashboardCenter.tabSlideDuration
                            easing.type: Easing.OutCubic
                        }
                    }

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

                                font.family: Typography.ui
                                font.pixelSize: Typography.lg
                            }

                            Text {
                                text: dashboardCenter.currentDate

                                color: Colors.subtext

                                font.family: Typography.ui
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

                                        font.family: Typography.ui
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

                                        font.family: Typography.ui
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

                                    font.family: Typography.ui
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
                        bottom: parent.bottom
                    }

                    width: parent.width

                    x: dashboardCenter.tabOffset(1) * width

                    visible: Math.abs(wallpaperTab.x) < wallpaperTab.width

                    Behavior on x {
                        NumberAnimation {
                            duration: dashboardCenter.tabSlideDuration
                            easing.type: Easing.OutCubic
                        }
                    }

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

                            font.family: Typography.ui

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

                            font.family: Typography.ui

                            font.pixelSize: Typography.xs

                            elide: Text.ElideMiddle

                            textFormat: Text.PlainText
                        }
                    }
                }

                // =================================================
                // SYSTEM TAB
                // =================================================

                Item {
                    id: systemTab

                    anchors {
                        top: tabBar.bottom
                        bottom: parent.bottom

                        bottomMargin: 12
                    }

                    /*
                     * Full panel width so the page slides as a whole
                     * sheet. The side insets moved onto the layout
                     * below, which used to get them from this item's
                     * left and right anchors.
                     */
                    width: parent.width

                    x: dashboardCenter.tabOffset(2) * width

                    visible: Math.abs(systemTab.x) < systemTab.width

                    Behavior on x {
                        NumberAnimation {
                            duration: dashboardCenter.tabSlideDuration
                            easing.type: Easing.OutCubic
                        }
                    }

                    ColumnLayout {
                        id: systemColumn

                        anchors.fill: parent

                        // Side insets, inherited from the page anchors.
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        /*
                         * Section gaps come from the stretching
                         * spacers below rather than a uniform
                         * spacing. Whatever height is left over gets
                         * spent between the groups instead of pooling
                         * underneath the last row -- and it stays
                         * that way whether the machine reports one
                         * filesystem or two.
                         */
                        spacing: 0

                        // ---------------------------------------------
                        // HOST
                        // ---------------------------------------------

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            Text {
                                id: hostGlyph

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter

                                text: "󰌽"

                                color: Colors.accent

                                font.family: Typography.mono
                                font.pixelSize: 22

                                textFormat: Text.PlainText
                            }

                            Column {
                                anchors.left: hostGlyph.right
                                anchors.right: uptimePill.left
                                anchors.verticalCenter: parent.verticalCenter

                                anchors.leftMargin: 10
                                anchors.rightMargin: 8

                                spacing: 1

                                Text {
                                    width: parent.width

                                    text: dashboardCenter.sysHost === "" ? "--" : dashboardCenter.sysHost

                                    color: Colors.text

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.sm
                                    font.weight: Typography.demiBold

                                    elide: Text.ElideRight

                                    textFormat: Text.PlainText
                                }

                                Text {
                                    width: parent.width

                                    text: dashboardCenter.sysOs === "" ? "" : dashboardCenter.sysOs + "  ·  " + dashboardCenter.sysKernel

                                    color: Colors.subtext

                                    opacity: 0.8

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.xs

                                    elide: Text.ElideRight

                                    textFormat: Text.PlainText
                                }
                            }

                            /*
                             * Uptime as a chip rather than loose text --
                             * it is a different kind of fact from the
                             * host identity beside it.
                             */
                            Rectangle {
                                id: uptimePill

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter

                                width: uptimeText.implicitWidth + 18
                                height: 22

                                radius: 11

                                visible: dashboardCenter.sysUptime !== ""

                                color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)

                                Text {
                                    id: uptimeText

                                    anchors.centerIn: parent

                                    text: "󰥔  " + dashboardCenter.sysUptime

                                    color: Colors.accent

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.xs
                                    font.weight: Typography.medium

                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        /*
                         * Spacer heights are ratios, not pixels. The
                         * layout hands each stretching item a share of
                         * the leftover height proportional to its
                         * preferred size, so 8:16:8 means the gap
                         * before storage always comes out twice the
                         * others no matter how much room there is.
                         */
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredHeight: 8
                        }

                        // ---------------------------------------------
                        // GAUGES
                        // ---------------------------------------------

                        Row {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 122

                            Repeater {
                                model: dashboardCenter.systemRings

                                delegate: StatRing {
                                    required property var modelData

                                    // Three across the row the gauges sit in.
                                    width: parent.width / 3

                                    diameter: 82
                                    thickness: 7

                                    value: modelData.value
                                    label: modelData.label
                                    detail: modelData.detail
                                    fraction: modelData.fraction
                                    tint: modelData.tint
                                }
                            }
                        }

                        /*
                         * The widest gap in the panel. It separates
                         * the live dials from the storage figures,
                         * which are a different kind of reading and
                         * should not look like a fourth metric row.
                         */
                        Item {
                            Layout.fillHeight: true
                            Layout.preferredHeight: 16
                        }

                        // ---------------------------------------------
                        // STORAGE
                        // ---------------------------------------------

                        Column {
                            id: storageGroup

                            Layout.fillWidth: true

                            // Tight: these two belong together.
                            spacing: 6

                            Repeater {
                                model: dashboardCenter.systemDisks

                                delegate: Item {
                                    id: diskRow

                                    required property var modelData

                                    width: parent.width

                                    height: 32

                                    Text {
                                        id: diskGlyph

                                        anchors.left: parent.left
                                        anchors.top: parent.top

                                        text: "󰋊"

                                        color: diskRow.modelData.tint

                                        font.family: Typography.mono
                                        font.pixelSize: 14

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        id: diskMount

                                        anchors.left: diskGlyph.right
                                        anchors.baseline: diskGlyph.baseline

                                        anchors.leftMargin: 9

                                        text: diskRow.modelData.mount

                                        color: Colors.text

                                        font.family: Typography.ui
                                        font.pixelSize: Typography.xs
                                        font.weight: Typography.medium

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        anchors.left: diskMount.right
                                        anchors.right: diskPercent.left
                                        anchors.baseline: diskGlyph.baseline

                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8

                                        text: diskRow.modelData.detail

                                        color: Colors.subtext

                                        opacity: 0.75

                                        font.family: Typography.ui
                                        font.pixelSize: Typography.xs

                                        elide: Text.ElideRight

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        id: diskPercent

                                        anchors.right: parent.right
                                        anchors.baseline: diskGlyph.baseline

                                        text: diskRow.modelData.percent

                                        color: diskRow.modelData.tint

                                        font.family: Typography.mono
                                        font.pixelSize: Typography.xs
                                        font.weight: Typography.demiBold

                                        textFormat: Text.PlainText
                                    }

                                    Rectangle {
                                        id: diskTrack

                                        anchors.left: diskGlyph.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom

                                        anchors.bottomMargin: 4

                                        height: 3

                                        radius: 1.5

                                        color: Colors.surface

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom

                                            width: diskTrack.width * Math.max(0, Math.min(1, diskRow.modelData.fraction))

                                            radius: 1.5

                                            color: diskRow.modelData.tint

                                            Behavior on width {
                                                NumberAnimation {
                                                    duration: 300
                                                    easing.type: Easing.OutCubic
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.preferredHeight: 8
                        }

                        // ---------------------------------------------
                        // CPU MODEL
                        // ---------------------------------------------

                        Text {
                            Layout.fillWidth: true

                            text: dashboardCenter.sysCpuModel

                            color: Colors.subtext

                            opacity: 0.6

                            font.family: Typography.ui
                            font.pixelSize: Typography.xs

                            horizontalAlignment: Text.AlignHCenter

                            elide: Text.ElideRight

                            textFormat: Text.PlainText
                        }
                    }
                }
            }
        }
    }
}
