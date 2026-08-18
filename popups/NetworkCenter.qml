pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../theme"

Item {
    id: networkCenter

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool opened: false

    readonly property int panelWidth: 320
    readonly property int panelHeight: 420

    width: panelWidth
    height: panelHeight

    // ============================================================
    // STATE
    // ============================================================

    property bool wifiEnabled: false
    property bool scanning: false
    property bool loading: true

    property string connectedSsid: ""
    property string connectedDevice: ""
    property int connectedSignal: 0

    /*
     * Final merged network list.
     *
     * Every item has:
     *
     * ssid
     * signal
     * security
     * secured
     * connected
     * saved
     * visible
     */
    property var networks: []

    property var scannedNetworks: []
    property var savedNetworks: []

    // ============================================================
    // DETAIL VIEW
    // ============================================================

    property bool detailView: false
    property var selectedNetwork: null

    property bool passwordVisible: false
    property string password: ""

    property string errorMessage: ""
    property bool connecting: false

    // ============================================================
    // WIFI STATE
    // ============================================================

    Process {
        id: wifiStateProcess

        command: ["nmcli", "-t", "-f", "WIFI", "radio"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = this.text.trim().toLowerCase();

                networkCenter.wifiEnabled = value === "enabled";
            }
        }
    }

    // ============================================================
    // CURRENT CONNECTION
    // ============================================================

    Process {
        id: activeConnectionProcess

        command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,DEVICE", "device", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                networkCenter.connectedSsid = "";
                networkCenter.connectedSignal = 0;
                networkCenter.connectedDevice = "";

                const lines = this.text.trim().split("\n");

                for (let i = 0; i < lines.length; i++) {
                    if (!lines[i])
                        continue;
                    const parts = lines[i].split(":");

                    if (parts.length < 4)
                        continue;
                    if (parts[0] === "yes") {
                        networkCenter.connectedSsid = parts[1];
                        networkCenter.connectedSignal = Number(parts[2]);
                        networkCenter.connectedDevice = parts[3];
                        break;
                    }
                }

                networkCenter.mergeNetworks();
            }
        }
    }

    // ============================================================
    // SCANNED WIFI NETWORKS
    // ============================================================

    Process {
        id: wifiListProcess

        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = [];
                const lines = this.text.trim().split("\n");

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];

                    if (!line)
                        continue;
                    const parts = line.split(":");

                    if (parts.length < 4)
                        continue;
                    const inUse = parts[0] === "*";
                    const ssid = parts[1];
                    const signal = Number(parts[2]);
                    const security = parts[3];

                    if (ssid === "")
                        continue;
                    result.push({
                        ssid: ssid,
                        signal: signal,
                        security: security,
                        secured: security !== "" && security !== "--",
                        connected: inUse,
                        visible: true
                    });
                }

                networkCenter.scannedNetworks = result;

                networkCenter.mergeNetworks();

                networkCenter.loading = false;
                networkCenter.scanning = false;
            }
        }
    }

    // ============================================================
    // SAVED NETWORKS
    // ============================================================

    Process {
        id: savedNetworksProcess

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const result = [];
                const lines = this.text.trim().split("\n");

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];

                    if (!line)
                        continue;
                    const separatorIndex = line.lastIndexOf(":");

                    if (separatorIndex === -1)
                        continue;
                    const name = line.substring(0, separatorIndex);

                    const type = line.substring(separatorIndex + 1);

                    /*
                     * Only Wi-Fi profiles.
                     */
                    if (type === "802-11-wireless" || type === "wifi") {
                        if (name !== "")
                            result.push(name);
                    }
                }

                networkCenter.savedNetworks = result;

                networkCenter.mergeNetworks();
            }
        }
    }

    // ============================================================
    // MERGE SCANNED + SAVED NETWORKS
    // ============================================================

    function mergeNetworks() {
        const merged = [];
        const seen = {};

        /*
         * First add scanned networks.
         */
        for (let i = 0; i < networkCenter.scannedNetworks.length; i++) {
            const scanned = networkCenter.scannedNetworks[i];

            /*
             * Never show the currently connected
             * network in Available Networks.
             */
            if (scanned.ssid === networkCenter.connectedSsid) {
                continue;
            }

            if (seen[scanned.ssid])
                continue;
            seen[scanned.ssid] = true;

            merged.push({
                ssid: scanned.ssid,
                signal: scanned.signal,
                security: scanned.security,
                secured: scanned.secured,
                connected: false,
                saved: networkCenter.isSaved(scanned.ssid),
                visible: true
            });
        }

        /*
         * Then add saved networks which aren't
         * currently visible.
         */
        for (let i = 0; i < networkCenter.savedNetworks.length; i++) {
            const ssid = networkCenter.savedNetworks[i];

            /*
             * Don't show connected network again.
             */
            if (ssid === networkCenter.connectedSsid) {
                continue;
            }

            /*
             * Already added from the scan.
             */
            if (seen[ssid])
                continue;
            seen[ssid] = true;

            merged.push({
                ssid: ssid,
                signal: 0,
                security: "saved",
                secured: true,
                connected: false,
                saved: true,
                visible: false
            });
        }

        /*
         * Strongest signal first.
         * Saved networks that aren't currently visible
         * go to the bottom.
         */
        merged.sort(function (a, b) {
            if (!a.visible && b.visible)
                return 1;

            if (a.visible && !b.visible)
                return -1;

            return b.signal - a.signal;
        });

        networkCenter.networks = merged;
    }

    function isSaved(ssid) {
        for (let i = 0; i < networkCenter.savedNetworks.length; i++) {
            if (networkCenter.savedNetworks[i] === ssid) {
                return true;
            }
        }

        return false;
    }

    // ============================================================
    // REFRESH
    // ============================================================

    function refresh() {
        networkCenter.loading = true;

        wifiStateProcess.running = false;
        wifiStateProcess.running = true;

        activeConnectionProcess.running = false;
        activeConnectionProcess.running = true;

        savedNetworksProcess.running = false;
        savedNetworksProcess.running = true;

        wifiListProcess.running = false;
        wifiListProcess.running = true;
    }

    // ============================================================
    // SCAN
    // ============================================================

    Process {
        id: scanProcess

        command: ["nmcli", "device", "wifi", "rescan"]

        onRunningChanged: if (!running) {
            networkCenter.scanning = false;

            networkCenter.refresh();
        }
    }

    function scan() {
        if (networkCenter.scanning || !networkCenter.wifiEnabled) {
            return;
        }

        networkCenter.scanning = true;
        scanProcess.running = true;
    }

    // ============================================================
    // WIFI TOGGLE
    // ============================================================

    Process {
        id: wifiToggleProcess

        onRunningChanged: if (!running) {
            networkCenter.refresh();
        }
    }

    function toggleWifi() {
        const state = networkCenter.wifiEnabled ? "off" : "on";

        wifiToggleProcess.command = ["nmcli", "radio", "wifi", state];

        wifiToggleProcess.running = true;
    }

    // ============================================================
    // SELECT NETWORK
    // ============================================================

    function selectNetwork(network) {
        networkCenter.selectedNetwork = network;
        networkCenter.password = "";
        networkCenter.passwordVisible = false;
        networkCenter.errorMessage = "";
        networkCenter.detailView = true;
    }

    // ============================================================
    // CONNECT
    // ============================================================

    Process {
        id: connectProcess

        stdout: StdioCollector {}

        stderr: StdioCollector {
            id: connectError
        }

        onRunningChanged: if (!running) {
            networkCenter.connecting = false;
            networkCenter.errorMessage = connectError.text.trim();

            if (networkCenter.errorMessage === "") {
                networkCenter.errorMessage = "Unable to connect";
            }

            networkCenter.detailView = false;
            networkCenter.selectedNetwork = null;
            networkCenter.password = "";

            networkCenter.refresh();
        }
    }

    function connectNetwork() {
        const network = networkCenter.selectedNetwork;

        if (!network || networkCenter.connecting) {
            return;
        }

        networkCenter.errorMessage = "";

        networkCenter.connecting = true;

        /*
         * SAVED NETWORK
         *
         * Use the existing NetworkManager profile.
         * No password required.
         */
        if (network.saved) {
            connectProcess.command = ["nmcli", "connection", "up", "id", network.ssid];

            connectProcess.running = true;

            return;
        }

        /*
         * NEW SECURED NETWORK
         */
        if (network.secured) {
            if (networkCenter.password.trim() === "") {
                networkCenter.connecting = false;

                networkCenter.errorMessage = "Password is required";

                passwordInput.forceActiveFocus();

                return;
            }

            connectProcess.command = ["nmcli", "device", "wifi", "connect", network.ssid, "password", networkCenter.password];

            connectProcess.running = true;

            return;
        }

        /*
         * OPEN NETWORK
         */
        connectProcess.command = ["nmcli", "device", "wifi", "connect", network.ssid];

        connectProcess.running = true;
    }

    // ============================================================
    // DISCONNECT
    // ============================================================

    Process {
        id: disconnectProcess

        onRunningChanged: if (!running) {
            networkCenter.detailView = false;
            networkCenter.selectedNetwork = null;

            networkCenter.refresh();
        }
    }

    function disconnectNetwork() {
        if (networkCenter.connectedDevice === "") {
            return;
        }

        disconnectProcess.command = ["nmcli", "device", "disconnect", networkCenter.connectedDevice];

        disconnectProcess.running = true;
    }

    // ============================================================
    // FORGET
    // ============================================================

    Process {
        id: forgetProcess

        stderr: StdioCollector {
            id: forgetError
        }

        onRunningChanged: if (!running) {
            networkCenter.errorMessage = forgetError.text.trim();

            if (networkCenter.errorMessage === "") {
                networkCenter.errorMessage = "Unable to forget network";
            }

            networkCenter.detailView = false;
            networkCenter.selectedNetwork = null;

            networkCenter.refresh();
        }
    }

    function forgetNetwork() {
        const network = networkCenter.selectedNetwork;

        if (!network || !network.saved)
            return;
        forgetProcess.command = ["nmcli", "connection", "delete", "id", network.ssid];

        forgetProcess.running = true;
    }

    // ============================================================
    // SIGNAL ICON
    // ============================================================

    function signalIcon(signal) {
        if (signal >= 80)
            return "󰤨";

        if (signal >= 60)
            return "󰤥";

        if (signal >= 40)
            return "󰤢";

        if (signal >= 20)
            return "󰤟";

        if (signal > 0)
            return "󰤯";

        return "󰤭";
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        networkCenter.detailView = false;
        networkCenter.selectedNetwork = null;
        networkCenter.password = "";
        networkCenter.errorMessage = "";

        networkCenter.opened = true;

        networkCenter.refresh();
    }

    function close() {
        networkCenter.opened = false;
    }

    function toggle() {
        if (networkCenter.opened)
            close();
        else
            open();
    }

    // ============================================================
    // INITIAL REFRESH
    // ============================================================

    Component.onCompleted: {
        refresh();
    }

    // ============================================================
    // SLIDE-DOWN ANIMATION
    // ============================================================

    Item {
        id: revealArea

        anchors.fill: parent

        clip: true

        Item {
            id: animatedContent

            width: parent.width
            height: parent.height

            y: networkCenter.opened ? 0 : -height

            opacity: networkCenter.opened ? 1 : 0.85

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

                color: Colors.base

                border.width: 1
                border.color: Colors.surface

                // =================================================
                // MAIN NETWORK LIST
                // =================================================

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins: 12

                    spacing: 8

                    visible: !networkCenter.detailView

                    // =============================================
                    // HEADER
                    // =============================================

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Network"

                            color: Colors.text

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.lg

                            font.bold: true

                            textFormat: Text.PlainText

                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

                            radius: 7

                            color: refreshMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "󰑐"

                                color: refreshMouse.containsMouse ? Colors.text : Colors.subtext

                                font.pixelSize: 17

                                textFormat: Text.PlainText
                            }

                            MouseArea {
                                id: refreshMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    networkCenter.scan();
                                }
                            }
                        }
                    }

                    // =============================================
                    // WIFI TOGGLE
                    // =============================================

                    Rectangle {
                        Layout.fillWidth: true

                        Layout.preferredHeight: 48

                        radius: 8

                        color: Colors.surface

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            spacing: 10

                            Text {
                                text: networkCenter.wifiEnabled ? "󰤨" : "󰤭"

                                color: networkCenter.wifiEnabled ? Colors.accent : Colors.subtext

                                font.pixelSize: 20

                                textFormat: Text.PlainText
                            }

                            Text {
                                text: "Wi-Fi"

                                color: Colors.text

                                font.family: Typography.firaCode

                                font.pixelSize: Typography.sm

                                Layout.fillWidth: true

                                textFormat: Text.PlainText
                            }

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 22

                                radius: 11

                                color: networkCenter.wifiEnabled ? Colors.accent : Colors.subtext

                                opacity: networkCenter.wifiEnabled ? 1 : 0.4

                                Rectangle {
                                    width: 18
                                    height: 18

                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter

                                    x: networkCenter.wifiEnabled ? parent.width - width - 2 : 2

                                    color: Colors.text

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 160

                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        networkCenter.toggleWifi();
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // CONNECTED
                    // =============================================

                    Text {
                        visible: networkCenter.connectedSsid !== ""

                        text: "Connected"

                        color: Colors.subtext

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.xs

                        font.bold: true

                        textFormat: Text.PlainText

                        Layout.topMargin: 2
                    }

                    Rectangle {
                        visible: networkCenter.connectedSsid !== ""

                        Layout.fillWidth: true

                        Layout.preferredHeight: 56

                        radius: 8

                        color: Colors.surface

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            spacing: 10

                            Text {
                                text: networkCenter.signalIcon(networkCenter.connectedSignal)

                                color: Colors.accent

                                font.pixelSize: 20

                                textFormat: Text.PlainText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                spacing: 1

                                Text {
                                    text: networkCenter.connectedSsid

                                    color: Colors.text

                                    font.family: Typography.firaCode

                                    font.pixelSize: Typography.sm

                                    font.bold: true

                                    elide: Text.ElideRight

                                    Layout.fillWidth: true

                                    textFormat: Text.PlainText
                                }

                                Text {
                                    text: networkCenter.connectedSignal + "%"

                                    color: Colors.subtext

                                    font.family: Typography.firaCode

                                    font.pixelSize: Typography.xs

                                    textFormat: Text.PlainText
                                }
                            }

                            Text {
                                text: "✓"

                                color: Colors.accent

                                font.pixelSize: 18

                                textFormat: Text.PlainText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                for (let i = 0; i < networkCenter.networks.length; i++) {
                                    if (networkCenter.networks[i].ssid === networkCenter.connectedSsid) {
                                        networkCenter.selectNetwork({
                                            ssid: networkCenter.connectedSsid,
                                            signal: networkCenter.connectedSignal,
                                            security: "connected",
                                            secured: true,
                                            connected: true,
                                            saved: networkCenter.isSaved(networkCenter.connectedSsid),
                                            visible: true
                                        });

                                        break;
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // AVAILABLE NETWORKS
                    // =============================================

                    Text {
                        visible: networkCenter.networks.length > 0

                        text: "Available Networks"

                        color: Colors.subtext

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.xs

                        font.bold: true

                        textFormat: Text.PlainText

                        Layout.topMargin: 2
                    }

                    ListView {
                        id: networkList

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing: 2

                        model: networkCenter.networks

                        delegate: Rectangle {
                            id: networkDelegate

                            required property var modelData

                            width: networkList.width

                            height: 48

                            radius: 8

                            color: networkMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                spacing: 8

                                // Signal
                                Text {
                                    text: networkCenter.signalIcon(networkDelegate.modelData.signal)

                                    color: networkDelegate.modelData.visible ? Colors.text : Colors.subtext

                                    font.pixelSize: 19

                                    textFormat: Text.PlainText
                                }

                                // SSID + metadata
                                ColumnLayout {
                                    Layout.fillWidth: true

                                    spacing: 1

                                    Text {
                                        text: networkDelegate.modelData.ssid

                                        color: Colors.text

                                        font.family: Typography.firaCode

                                        font.pixelSize: Typography.sm

                                        elide: Text.ElideRight

                                        Layout.fillWidth: true

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        text: networkDelegate.modelData.saved ? (networkDelegate.modelData.visible ? networkDelegate.modelData.signal + "% • Saved" : "Saved network") : (networkDelegate.modelData.signal + "%")

                                        color: Colors.subtext

                                        font.family: Typography.firaCode

                                        font.pixelSize: Typography.xs

                                        textFormat: Text.PlainText
                                    }
                                }

                                // Saved indicator
                                Text {
                                    visible: networkDelegate.modelData.saved

                                    text: "󰌾"

                                    color: Colors.subtext

                                    font.pixelSize: 14

                                    textFormat: Text.PlainText
                                }

                                // Security indicator
                                Text {
                                    visible: networkDelegate.modelData.secured && !networkDelegate.modelData.saved

                                    text: "󰌾"

                                    color: Colors.subtext

                                    font.pixelSize: 14

                                    textFormat: Text.PlainText
                                }
                            }

                            MouseArea {
                                id: networkMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    networkCenter.selectNetwork(networkDelegate.modelData);
                                }
                            }
                        }
                    }

                    // =============================================
                    // WIFI OFF
                    // =============================================

                    Text {
                        visible: !networkCenter.wifiEnabled

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        text: "Wi-Fi is turned off"

                        color: Colors.subtext

                        opacity: 0.7

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.sm

                        textFormat: Text.PlainText
                    }

                    // =============================================
                    // NO NETWORKS
                    // =============================================

                    Text {
                        visible: networkCenter.wifiEnabled && !networkCenter.loading && networkCenter.networks.length === 0

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        text: "No networks found"

                        color: Colors.subtext

                        opacity: 0.6

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.sm

                        textFormat: Text.PlainText
                    }
                }

                // =================================================
                // DETAIL VIEW
                // =================================================

                ColumnLayout {
                    anchors.fill: parent

                    anchors.margins: 12

                    spacing: 10

                    visible: networkCenter.detailView

                    // =============================================
                    // HEADER
                    // =============================================

                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

                            radius: 7

                            color: backMouse.containsMouse ? Colors.surface : "transparent"

                            Text {
                                anchors.centerIn: parent

                                text: "󰁍"

                                color: Colors.text

                                font.pixelSize: 17

                                textFormat: Text.PlainText
                            }

                            MouseArea {
                                id: backMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    networkCenter.detailView = false;
                                    networkCenter.errorMessage = "";
                                }
                            }
                        }

                        Text {
                            text: networkCenter.selectedNetwork ? networkCenter.selectedNetwork.ssid : "Network"

                            color: Colors.text

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.lg

                            font.bold: true

                            elide: Text.ElideRight

                            Layout.fillWidth: true

                            textFormat: Text.PlainText
                        }
                    }

                    // =============================================
                    // NETWORK INFO
                    // =============================================

                    ColumnLayout {
                        Layout.fillWidth: true

                        Layout.topMargin: 6

                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: networkCenter.selectedNetwork ? networkCenter.signalIcon(networkCenter.selectedNetwork.signal) : "󰤨"

                            color: Colors.accent

                            font.pixelSize: 42

                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true

                            horizontalAlignment: Text.AlignHCenter

                            text: networkCenter.selectedNetwork ? networkCenter.selectedNetwork.ssid : ""

                            color: Colors.text

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.md

                            font.bold: true

                            elide: Text.ElideRight

                            textFormat: Text.PlainText
                        }

                        Text {
                            Layout.fillWidth: true

                            horizontalAlignment: Text.AlignHCenter

                            text: networkCenter.selectedNetwork ? (networkCenter.selectedNetwork.saved ? (networkCenter.selectedNetwork.visible ? "Saved • " + networkCenter.selectedNetwork.signal + "%" : "Saved network") : (networkCenter.selectedNetwork.secured ? "Secured" : "Open")) : ""

                            color: Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            textFormat: Text.PlainText
                        }
                    }

                    // =============================================
                    // PASSWORD
                    //
                    // IMPORTANT:
                    // Saved networks NEVER show this.
                    // =============================================

                    ColumnLayout {
                        visible: networkCenter.selectedNetwork && !networkCenter.selectedNetwork.saved && networkCenter.selectedNetwork.secured && !networkCenter.selectedNetwork.connected

                        Layout.fillWidth: true

                        spacing: 5

                        Text {
                            text: "Password"

                            color: Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            textFormat: Text.PlainText
                        }

                        Rectangle {
                            Layout.fillWidth: true

                            Layout.preferredHeight: 38

                            radius: 8

                            color: Colors.surface

                            border.width: passwordInput.activeFocus ? 1 : 0

                            border.color: Colors.accent

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 10
                                anchors.rightMargin: 6

                                spacing: 6

                                TextInput {
                                    id: passwordInput

                                    Layout.fillWidth: true

                                    color: Colors.text

                                    selectionColor: Colors.accent

                                    font.family: Typography.firaCode

                                    font.pixelSize: Typography.sm

                                    echoMode: networkCenter.passwordVisible ? TextInput.Normal : TextInput.Password

                                    text: networkCenter.password

                                    onTextChanged: {
                                        networkCenter.password = text;
                                    }

                                    Keys.onReturnPressed: {
                                        networkCenter.connectNetwork();
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28

                                    radius: 7

                                    color: passwordEyeMouse.containsMouse ? Colors.base : "transparent"

                                    Text {
                                        anchors.centerIn: parent

                                        text: networkCenter.passwordVisible ? "󰈈" : "󰈉"

                                        color: Colors.subtext

                                        font.pixelSize: 16

                                        textFormat: Text.PlainText
                                    }

                                    MouseArea {
                                        id: passwordEyeMouse

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            networkCenter.passwordVisible = !networkCenter.passwordVisible;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // SAVED NETWORK INFO
                    // =============================================

                    Text {
                        visible: networkCenter.selectedNetwork && networkCenter.selectedNetwork.saved && !networkCenter.selectedNetwork.connected

                        Layout.fillWidth: true

                        text: "Saved network — your existing password will be used."

                        color: Colors.subtext

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.xs

                        wrapMode: Text.WordWrap

                        textFormat: Text.PlainText
                    }

                    // =============================================
                    // ERROR
                    // =============================================

                    Text {
                        visible: networkCenter.errorMessage !== ""

                        Layout.fillWidth: true

                        text: networkCenter.errorMessage

                        color: "#ef4444"

                        font.family: Typography.firaCode

                        font.pixelSize: Typography.xs

                        wrapMode: Text.WordWrap

                        maximumLineCount: 2

                        textFormat: Text.PlainText
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    // =============================================
                    // CONNECT / DISCONNECT
                    // =============================================

                    Rectangle {
                        Layout.fillWidth: true

                        Layout.preferredHeight: 38

                        radius: 8

                        color: connectMouse.containsMouse ? Qt.darker(Colors.accent, 1.08) : Colors.accent

                        opacity: networkCenter.connecting ? 0.6 : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: networkCenter.connecting ? "Connecting..." : (networkCenter.selectedNetwork && networkCenter.selectedNetwork.connected ? "Disconnect" : "Connect")

                            color: Colors.base

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.sm

                            font.bold: true

                            textFormat: Text.PlainText
                        }

                        MouseArea {
                            id: connectMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            enabled: !networkCenter.connecting

                            onClicked: {
                                if (networkCenter.selectedNetwork && networkCenter.selectedNetwork.connected) {
                                    networkCenter.disconnectNetwork();
                                } else {
                                    networkCenter.connectNetwork();
                                }
                            }
                        }
                    }

                    // =============================================
                    // FORGET
                    // =============================================

                    Rectangle {
                        visible: networkCenter.selectedNetwork && networkCenter.selectedNetwork.saved

                        Layout.fillWidth: true

                        Layout.preferredHeight: 34

                        radius: 8

                        color: forgetMouse.containsMouse ? Colors.surface : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Text {
                            anchors.centerIn: parent

                            text: "Forget network"

                            color: forgetMouse.containsMouse ? "#ef4444" : Colors.subtext

                            font.family: Typography.firaCode

                            font.pixelSize: Typography.xs

                            textFormat: Text.PlainText

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }

                        MouseArea {
                            id: forgetMouse

                            anchors.fill: parent

                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                networkCenter.forgetNetwork();
                            }
                        }
                    }
                }
            }
        }
    }
}
