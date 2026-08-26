pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

import "../theme"

Item {
    id: networkCenter

    // ============================================================
    // PUBLIC API
    // ============================================================

    property bool opened: false

    /*
     * Which half of the panel is showing: "wifi" or "bluetooth".
     * Set once by open() from whichever control center chevron was
     * clicked — the panel shows that one section and nothing else,
     * so this is a drill-down rather than a tabbed view.
     */
    property string section: "wifi"

    /*
     * Raised by the header's back arrow. This panel does not own the
     * control center it came from, so it asks the bar to make the
     * swap rather than reaching across.
     */
    signal backRequested

    readonly property int panelWidth: 320

    /*
     * A little taller than the old Wi-Fi-only panel: the bluetooth
     * section carries two lists, and at 420 the scan results were
     * down to a single visible row once a few devices were paired.
     */
    readonly property int panelHeight: 440

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
    // BLUETOOTH
    //
    // BlueZ is enumerated over DBus, so `defaultAdapter` is null for
    // the first second or two of the shell's life and again whenever
    // bluetoothd goes away. Every binding below treats null as
    // "unavailable" rather than assuming it settles.
    // ============================================================

    readonly property var btAdapter: Bluetooth.defaultAdapter

    readonly property bool btAvailable: networkCenter.btAdapter !== null

    // `enabled` is BlueZ's Powered property.
    readonly property bool btEnabled: networkCenter.btAvailable && networkCenter.btAdapter.enabled

    readonly property bool btScanning: networkCenter.btAvailable && networkCenter.btAdapter.discovering

    readonly property var btDevices: networkCenter.btAdapter?.devices?.values ?? []

    /*
     * Paired devices stay listed while the adapter is off — BlueZ
     * remembers them — so this is not gated on btEnabled.
     */
    readonly property var btPaired: networkCenter.btDevices.filter(device => device.paired || device.bonded)

    readonly property var btNearby: networkCenter.btDevices.filter(device => !device.paired && !device.bonded)

    function toggleBluetooth() {
        if (!networkCenter.btAvailable)
            return;
        networkCenter.btAdapter.enabled = !networkCenter.btAdapter.enabled;
    }

    /*
     * Discovery is a battery drain, so it is only ever on while this
     * panel is showing the bluetooth section.
     */
    function setBtDiscovery(active) {
        if (!networkCenter.btAvailable || !networkCenter.btEnabled)
            return;
        networkCenter.btAdapter.discovering = active;
    }

    /*
     * Set while a pair or connect is in flight. Discovery is held off
     * for the duration -- see btDiscoveryWanted.
     */
    property bool btBusy: false

    /*
     * The device most recently asked to pair, so the follow-up work
     * can run once BlueZ reports it bonded.
     */
    property var btPendingDevice: null

    /*
     * A tap on a device row means the obvious thing for whatever
     * state it is in.
     */
    function pressDevice(device) {
        if (!device)
            return;

        /*
         * A second tap while pairing is in flight means stop, not
         * pair again. BlueZ rejects the duplicate request, and the
         * row would otherwise sit on "Pairing…" until it timed out.
         */
        if (device.pairing) {
            device.cancelPair();

            networkCenter.clearBtBusy();

            return;
        }

        if (device.connected) {
            device.disconnect();

            return;
        }

        /*
         * A scan and a connection attempt compete for the same radio.
         * BlueZ will often take many seconds or fail outright while
         * discovery is running, so it is stopped for the attempt and
         * resumes on its own once btBusy clears.
         */
        networkCenter.btBusy = true;

        btBusyTimeout.restart();

        if (device.paired || device.bonded) {
            networkCenter.connectDevice(device);

            return;
        }

        networkCenter.btPendingDevice = device;

        device.pair();
    }

    /*
     * Pairing on its own does not connect, and an untrusted device
     * will not come back by itself after it next drops. Both of those
     * are what "it paired but nothing happened" actually is.
     */
    function connectDevice(device) {
        if (!device)
            return;

        if (!device.trusted)
            device.trusted = true;

        if (!device.connected)
            device.connect();
    }

    function clearBtBusy() {
        networkCenter.btBusy = false;
        networkCenter.btPendingDevice = null;

        btBusyTimeout.stop();
    }

    /*
     * Pairing that is never answered -- the other device out of
     * range, or a confirmation nobody accepted -- leaves no signal to
     * react to. Without this, discovery would stay off for as long as
     * the panel stayed open.
     */
    Timer {
        id: btBusyTimeout

        interval: 30000
        repeat: false

        onTriggered: {
            networkCenter.clearBtBusy();
        }
    }

    Connections {
        target: networkCenter.btPendingDevice

        ignoreUnknownSignals: true

        function onPairingChanged() {
            networkCenter.finishPairing();
        }

        function onPairedChanged() {
            networkCenter.finishPairing();
        }

        function onBondedChanged() {
            networkCenter.finishPairing();
        }
    }

    function finishPairing() {
        const device = networkCenter.btPendingDevice;

        if (!device)
            return;

        // Still in flight.
        if (device.pairing)
            return;

        /*
         * Pairing ended without a bond -- rejected, or out of range.
         * Release the radio and leave the row showing "Tap to pair"
         * so it can be tried again.
         */
        if (!device.paired && !device.bonded) {
            networkCenter.clearBtBusy();

            return;
        }

        networkCenter.btPendingDevice = null;

        networkCenter.connectDevice(device);

        networkCenter.btBusy = false;

        btBusyTimeout.stop();
    }

    /*
     * BlueZ reports a freedesktop icon name; the rest of the shell
     * draws Nerd Font glyphs, so translate rather than pulling in an
     * icon theme for four shapes.
     */
    function btIcon(device) {
        const name = device?.icon ?? "";

        if (name.indexOf("headset") !== -1 || name.indexOf("headphone") !== -1)
            return "󰋋";

        if (name.indexOf("mouse") !== -1)
            return "󰦋";

        if (name.indexOf("keyboard") !== -1)
            return "󰌌";

        if (name.indexOf("phone") !== -1)
            return "󰄜";

        if (name.indexOf("computer") !== -1)
            return "󰟀";

        if (name.indexOf("audio") !== -1 || name.indexOf("speaker") !== -1)
            return "󰓃";

        if (name.indexOf("input-gaming") !== -1)
            return "󰊴";

        return "󰂯";
    }

    function btSubtitle(device) {
        if (!device)
            return "";
        if (device.pairing)
            return "Pairing…";
        if (device.connected) {
            /*
             * batteryAvailable gates this because a disconnected
             * device reports a flat 0 rather than "unknown".
             */
            if (device.batteryAvailable)
                return "Connected • " + Math.round(device.battery * 100) + "%";

            return "Connected";
        }

        if (device.paired || device.bonded)
            return "Paired";

        return "Tap to pair";
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open(section) {
        networkCenter.section = section ?? "wifi";

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

    function toggle(section) {
        /*
         * Re-opening on a different section from the one already
         * showing switches to it rather than closing the panel.
         */
        if (networkCenter.opened && (section === undefined || section === networkCenter.section))
            close();
        else
            open(section);
    }

    /*
     * Discovery follows the panel: scanning only while the bluetooth
     * section is actually on screen, and stopped again on the way
     * out so it does not sit burning the radio.
     */
    readonly property bool btDiscoveryWanted: networkCenter.opened && networkCenter.section === "bluetooth" && networkCenter.btEnabled && !networkCenter.detailView && !networkCenter.btBusy

    onBtDiscoveryWantedChanged: {
        networkCenter.setBtDiscovery(networkCenter.btDiscoveryWanted);
    }

    /*
     * BlueZ leaves the adapter non-pairable by default, which blocks
     * a device that answers a pair request by starting its own. Held
     * on only while the bluetooth section is up, for the same reason
     * discovery is.
     */
    readonly property bool btPairableWanted: networkCenter.opened && networkCenter.section === "bluetooth" && networkCenter.btEnabled

    onBtPairableWantedChanged: {
        if (networkCenter.btAvailable)
            networkCenter.btAdapter.pairable = networkCenter.btPairableWanted;
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

                color: Colors.panel

                border.width: 1
                border.color: Colors.surface

                // =================================================
                // BLUETOOTH DEVICE ROW
                //
                // Shared by both device lists: a row looks the same
                // whether the device is already paired or has just
                // turned up in a scan, and only the subtitle and the
                // trailing affordance differ.
                // =================================================

                Component {
                    id: btDeviceRow

                    Rectangle {
                        id: deviceRow

                        required property var modelData

                        readonly property bool isPaired: deviceRow.modelData.paired || deviceRow.modelData.bonded

                        width: deviceRow.ListView.view ? deviceRow.ListView.view.width : 0

                        height: 48

                        radius: 8

                        color: deviceMouse.containsMouse ? Colors.surface : "transparent"

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

                            Text {
                                text: networkCenter.btIcon(deviceRow.modelData)

                                color: deviceRow.modelData.connected ? Colors.accent : Colors.text

                                font.pixelSize: 19

                                textFormat: Text.PlainText
                            }

                            ColumnLayout {
                                Layout.fillWidth: true

                                spacing: 1

                                Text {
                                    // Unnamed devices only ever report a MAC.
                                    text: deviceRow.modelData.name !== "" ? deviceRow.modelData.name : deviceRow.modelData.address

                                    color: Colors.text

                                    font.family: Typography.ui

                                    font.pixelSize: Typography.sm

                                    elide: Text.ElideRight

                                    Layout.fillWidth: true

                                    textFormat: Text.PlainText
                                }

                                Text {
                                    text: networkCenter.btSubtitle(deviceRow.modelData)

                                    color: Colors.subtext

                                    font.family: Typography.ui

                                    font.pixelSize: Typography.xs

                                    elide: Text.ElideRight

                                    Layout.fillWidth: true

                                    textFormat: Text.PlainText
                                }
                            }

                            Text {
                                visible: deviceRow.modelData.connected

                                text: "✓"

                                color: Colors.accent

                                font.pixelSize: 18

                                textFormat: Text.PlainText
                            }

                            /*
                             * Kept visible rather than revealed on
                             * hover: a hover-gated button carrying
                             * its own hover-enabled MouseArea steals
                             * the row's hover, hides itself, and
                             * flickers.
                             */
                            Rectangle {
                                visible: deviceRow.isPaired

                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24

                                radius: 7

                                color: forgetMouse.containsMouse ? Colors.error : "transparent"

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent

                                    text: "󰅖"

                                    color: forgetMouse.containsMouse ? Colors.base : Colors.subtext

                                    font.pixelSize: 13

                                    textFormat: Text.PlainText
                                }

                                MouseArea {
                                    id: forgetMouse

                                    anchors.fill: parent

                                    hoverEnabled: true

                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        deviceRow.modelData.forget();
                                    }
                                }
                            }
                        }

                        /*
                         * Declared last and pushed under the row so
                         * the forget button gets its own clicks.
                         */
                        MouseArea {
                            id: deviceMouse

                            anchors.fill: parent

                            z: -1

                            hoverEnabled: true

                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                networkCenter.pressDevice(deviceRow.modelData);
                            }
                        }
                    }
                }

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

                        spacing: 4

                        /*
                         * Returns to the control center, which is the
                         * only way into this panel now that the bar
                         * icon is gone.
                         */
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28

                            radius: 7

                            color: headerBackMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "󰁍"

                                color: headerBackMouse.containsMouse ? Colors.text : Colors.subtext

                                font.pixelSize: 17

                                textFormat: Text.PlainText
                            }

                            MouseArea {
                                id: headerBackMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    networkCenter.backRequested();
                                }
                            }
                        }

                        Text {
                            // The panel only ever shows one section now.
                            text: networkCenter.section === "bluetooth" ? "Bluetooth" : "Wi-Fi"

                            color: Colors.text

                            font.family: Typography.ui

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
                                    if (networkCenter.section === "bluetooth") {
                                        /*
                                         * Bounce discovery — BlueZ
                                         * keeps handing back the same
                                         * cached results otherwise.
                                         */
                                        networkCenter.setBtDiscovery(false);

                                        networkCenter.setBtDiscovery(true);

                                        return;
                                    }

                                    networkCenter.scan();
                                }
                            }
                        }
                    }

                    // =============================================
                    // WIFI TOGGLE
                    // =============================================

                    Rectangle {
                        visible: networkCenter.section === "wifi"

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

                                font.family: Typography.ui

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
                        visible: networkCenter.section === "wifi" && networkCenter.connectedSsid !== ""

                        text: "Connected"

                        color: Colors.subtext

                        font.family: Typography.ui

                        font.pixelSize: Typography.xs

                        font.bold: true

                        textFormat: Text.PlainText

                        Layout.topMargin: 2
                    }

                    Rectangle {
                        visible: networkCenter.section === "wifi" && networkCenter.connectedSsid !== ""

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

                                    font.family: Typography.ui

                                    font.pixelSize: Typography.sm

                                    font.bold: true

                                    elide: Text.ElideRight

                                    Layout.fillWidth: true

                                    textFormat: Text.PlainText
                                }

                                Text {
                                    text: networkCenter.connectedSignal + "%"

                                    color: Colors.subtext

                                    font.family: Typography.ui

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
                        visible: networkCenter.section === "wifi" && networkCenter.networks.length > 0

                        text: "Available Networks"

                        color: Colors.subtext

                        font.family: Typography.ui

                        font.pixelSize: Typography.xs

                        font.bold: true

                        textFormat: Text.PlainText

                        Layout.topMargin: 2
                    }

                    ListView {
                        id: networkList

                        visible: networkCenter.section === "wifi"

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

                                        font.family: Typography.ui

                                        font.pixelSize: Typography.sm

                                        elide: Text.ElideRight

                                        Layout.fillWidth: true

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        text: networkDelegate.modelData.saved ? (networkDelegate.modelData.visible ? networkDelegate.modelData.signal + "% • Saved" : "Saved network") : (networkDelegate.modelData.signal + "%")

                                        color: Colors.subtext

                                        font.family: Typography.ui

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
                        visible: networkCenter.section === "wifi" && !networkCenter.wifiEnabled

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        text: "Wi-Fi is turned off"

                        color: Colors.subtext

                        opacity: 0.7

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.ui

                        font.pixelSize: Typography.sm

                        textFormat: Text.PlainText
                    }

                    // =============================================
                    // NO NETWORKS
                    // =============================================

                    Text {
                        visible: networkCenter.section === "wifi" && networkCenter.wifiEnabled && !networkCenter.loading && networkCenter.networks.length === 0

                        Layout.fillWidth: true

                        Layout.fillHeight: true

                        text: "No networks found"

                        color: Colors.subtext

                        opacity: 0.6

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.ui

                        font.pixelSize: Typography.sm

                        textFormat: Text.PlainText
                    }

                    // =============================================
                    // BLUETOOTH TOGGLE
                    // =============================================

                    Rectangle {
                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable

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
                                text: networkCenter.btEnabled ? "󰂯" : "󰂲"

                                color: networkCenter.btEnabled ? Colors.accent : Colors.subtext

                                font.pixelSize: 20

                                textFormat: Text.PlainText
                            }

                            Text {
                                text: "Bluetooth"

                                color: Colors.text

                                font.family: Typography.ui

                                font.pixelSize: Typography.sm

                                Layout.fillWidth: true

                                textFormat: Text.PlainText
                            }

                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 22

                                radius: 11

                                color: networkCenter.btEnabled ? Colors.accent : Colors.subtext

                                opacity: networkCenter.btEnabled ? 1 : 0.4

                                Rectangle {
                                    width: 18
                                    height: 18

                                    radius: 9

                                    anchors.verticalCenter: parent.verticalCenter

                                    x: networkCenter.btEnabled ? parent.width - width - 2 : 2

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
                                        networkCenter.toggleBluetooth();
                                    }
                                }
                            }
                        }
                    }

                    // =============================================
                    // MY DEVICES
                    // =============================================

                    Text {
                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable && networkCenter.btPaired.length > 0

                        text: "My Devices"

                        color: Colors.subtext

                        font.family: Typography.ui

                        font.pixelSize: Typography.xs

                        font.bold: true

                        textFormat: Text.PlainText

                        Layout.topMargin: 2
                    }

                    ListView {
                        id: pairedList

                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable && networkCenter.btPaired.length > 0

                        Layout.fillWidth: true

                        /*
                         * Caps at three rows so a long list of paired
                         * headphones cannot crowd out the scan
                         * results below; it scrolls past that.
                         */
                        Layout.preferredHeight: Math.min(networkCenter.btPaired.length, 3) * 48

                        clip: true

                        spacing: 2

                        model: networkCenter.btPaired

                        delegate: btDeviceRow
                    }

                    // =============================================
                    // AVAILABLE DEVICES
                    // =============================================

                    RowLayout {
                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable && networkCenter.btEnabled

                        Layout.fillWidth: true

                        Layout.topMargin: 2

                        spacing: 6

                        Text {
                            text: "Available"

                            color: Colors.subtext

                            font.family: Typography.ui

                            font.pixelSize: Typography.xs

                            font.bold: true

                            textFormat: Text.PlainText
                        }

                        Text {
                            visible: networkCenter.btScanning

                            text: "scanning…"

                            color: Colors.subtext

                            opacity: 0.7

                            font.family: Typography.ui

                            font.pixelSize: Typography.xs

                            textFormat: Text.PlainText

                            Layout.fillWidth: true
                        }
                    }

                    ListView {
                        id: nearbyList

                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable && networkCenter.btEnabled

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing: 2

                        model: networkCenter.btNearby

                        delegate: btDeviceRow
                    }

                    // =============================================
                    // BLUETOOTH EMPTY STATES
                    // =============================================

                    Text {
                        visible: networkCenter.section === "bluetooth" && networkCenter.btAvailable && !networkCenter.btEnabled

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: "Bluetooth is turned off"

                        color: Colors.subtext

                        opacity: 0.7

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.ui

                        font.pixelSize: Typography.sm

                        textFormat: Text.PlainText
                    }

                    /*
                     * Null adapter means bluetoothd is not up yet, or
                     * not running at all — distinct from the radio
                     * being switched off.
                     */
                    Text {
                        visible: networkCenter.section === "bluetooth" && !networkCenter.btAvailable

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: "No Bluetooth adapter"

                        color: Colors.subtext

                        opacity: 0.6

                        horizontalAlignment: Text.AlignHCenter

                        verticalAlignment: Text.AlignVCenter

                        font.family: Typography.ui

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

                            font.family: Typography.ui

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

                            font.family: Typography.ui

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

                            font.family: Typography.ui

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

                            font.family: Typography.ui

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

                                    font.family: Typography.ui

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

                        font.family: Typography.ui

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

                        font.family: Typography.ui

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

                            font.family: Typography.ui

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

                            font.family: Typography.ui

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
