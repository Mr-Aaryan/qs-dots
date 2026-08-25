pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

import "../theme"
import "."

/*
 * Session / power menu — the replacement for wlogout.
 *
 * Same six actions, same commands, and the same accelerator letters,
 * so nothing about the muscle memory changes. What it adds over
 * wlogout is that it follows the matugen palette like the rest of the
 * shell, it can be driven entirely from the keyboard, and the three
 * actions that cost you the running session ask once before doing it.
 *
 * Bound on the Hyprland side as "quickshell:powermenu".
 */
PanelWindow {
    id: power

    // ============================================================
    // ACTIONS
    //
    // Commands are carried over verbatim from ~/.config/wlogout/layout.
    //
    // `destructive` marks the ones that lose the session — those get
    // a confirmation press. Lock, suspend and hibernate all come back
    // to the same desktop, so they fire immediately.
    // ============================================================

    readonly property var actions: [
        {
            id: "lock",
            label: "Lock",
            icon: "󰌾",
            key: "l",
            command: "hyprlock",
            destructive: false
        },
        {
            id: "logout",
            label: "Logout",
            icon: "󰍃",
            key: "e",
            command: "hyprctl dispatch exit",
            destructive: true
        },
        {
            id: "suspend",
            label: "Suspend",
            icon: "󰒲",
            key: "u",
            command: "systemctl suspend",
            destructive: false
        },
        {
            id: "hibernate",
            label: "Hibernate",
            icon: "󰜗",
            key: "h",
            command: "systemctl hibernate",
            destructive: false
        },
        {
            id: "shutdown",
            label: "Shutdown",
            icon: "󰐥",
            key: "s",
            command: "systemctl poweroff",
            destructive: true
        },
        {
            id: "reboot",
            label: "Reboot",
            icon: "󰑓",
            key: "r",
            command: "systemctl reboot",
            destructive: true
        }
    ]

    // ============================================================
    // STATE
    // ============================================================

    property bool opened: false

    // Kept mapped through the close animation. See AppLauncher.
    property bool mapped: false

    property int selectedIndex: 0

    /*
     * Index of the destructive action waiting on its second press,
     * or -1. Cleared by moving, closing, or Escape.
     */
    property int armedIndex: -1

    property string uptime: ""

    // ============================================================
    // METRICS
    // ============================================================

    readonly property int columns: 3

    readonly property int cardWidth: 200
    readonly property int cardHeight: 175

    readonly property int gap: 18

    // ============================================================
    // WINDOW
    // ============================================================

    visible: power.mapped

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay

    WlrLayershell.keyboardFocus: power.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        power.selectedIndex = 0;
        power.armedIndex = -1;

        unmapTimer.stop();

        power.mapped = true;
        power.opened = true;

        uptimeProcess.running = false;
        uptimeProcess.running = true;

        focusTimer.restart();
    }

    function close() {
        power.opened = false;
        power.armedIndex = -1;

        focusTimer.stop();

        unmapTimer.restart();
    }

    function toggle() {
        if (power.opened)
            power.close();
        else
            power.open();
    }

    Timer {
        id: focusTimer

        interval: 60
        repeat: false

        onTriggered: {
            if (power.opened)
                keyHandler.forceActiveFocus();
        }
    }

    Timer {
        id: unmapTimer

        interval: 220
        repeat: false

        onTriggered: {
            power.mapped = false;
        }
    }

    // ============================================================
    // NAVIGATION
    // ============================================================

    /*
     * Grid movement, wrapping on both axes. Any move cancels a
     * pending confirmation — arrowing onto Shutdown should never
     * leave it one press from firing.
     */
    function move(dx, dy) {
        const count = power.actions.length;

        const rows = Math.ceil(count / power.columns);

        let column = power.selectedIndex % power.columns;
        let row = Math.floor(power.selectedIndex / power.columns);

        column = (column + dx + power.columns) % power.columns;
        row = (row + dy + rows) % rows;

        const target = row * power.columns + column;

        if (target < count)
            power.selectedIndex = target;

        power.armedIndex = -1;
    }

    // ============================================================
    // ACTIVATION
    // ============================================================

    function activate(index) {
        const action = power.actions[index];

        if (!action)
            return;

        power.selectedIndex = index;

        /*
         * First press on a destructive action only arms it. The
         * second press — Enter or another click — gets here with the
         * tile already armed and runs it.
         */
        if (action.destructive && power.armedIndex !== index) {
            power.armedIndex = index;

            return;
        }

        power.run(action.command);
    }

    function activateByKey(key) {
        for (let i = 0; i < power.actions.length; i++) {
            if (power.actions[i].key === key) {
                power.activate(i);

                return true;
            }
        }

        return false;
    }

    /*
     * The menu comes down before the command goes out.
     *
     * This matters for Lock: while the menu is open it holds
     * exclusive keyboard focus, and hyprlock mapping underneath that
     * would be handed a session whose input is still spoken for. The
     * delay lets the compositor see the focus released first.
     */
    function run(command) {
        runProcess.command = ["sh", "-c", command];

        power.close();

        runTimer.restart();
    }

    Process {
        id: runProcess

        running: false
    }

    Timer {
        id: runTimer

        interval: 160
        repeat: false

        onTriggered: {
            runProcess.running = true;
        }
    }

    // ============================================================
    // UPTIME
    //
    // Context for what is about to be thrown away.
    // ============================================================

    Process {
        id: uptimeProcess

        command: ["uptime", "-p"]

        stdout: StdioCollector {
            onStreamFinished: {
                power.uptime = this.text.trim();
            }
        }
    }

    // ============================================================
    // SCRIM
    // ============================================================

    Rectangle {
        anchors.fill: parent

        color: Qt.rgba(0, 0, 0, 0.55)

        opacity: power.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                power.close();
            }
        }
    }

    // ============================================================
    // KEYBOARD
    // ============================================================

    Item {
        id: keyHandler

        anchors.fill: parent

        focus: true

        Keys.onPressed: function (event) {
            switch (event.key) {
            case Qt.Key_Escape:
                // Escape backs out of a confirmation before it closes.
                if (power.armedIndex !== -1)
                    power.armedIndex = -1;
                else
                    power.close();

                event.accepted = true;

                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                power.activate(power.selectedIndex);

                event.accepted = true;

                return;
            case Qt.Key_Left:
                power.move(-1, 0);

                event.accepted = true;

                return;
            case Qt.Key_Right:
                power.move(1, 0);

                event.accepted = true;

                return;
            case Qt.Key_Up:
                power.move(0, -1);

                event.accepted = true;

                return;
            case Qt.Key_Down:
                power.move(0, 1);

                event.accepted = true;

                return;
            case Qt.Key_Tab:
                power.move(1, 0);

                event.accepted = true;

                return;
            }

            /*
             * Accelerators. Navigation is arrows only, so nothing
             * competes for a letter and all six of wlogout's keys
             * work: l, e, u, h, s, r.
             */
            if (event.text.length === 1 && power.activateByKey(event.text.toLowerCase()))
                event.accepted = true;
        }

        // ========================================================
        // GRID
        // ========================================================

        Column {
            anchors.centerIn: parent

            spacing: 26

            opacity: power.opened ? 1 : 0

            scale: power.opened ? 1 : 0.97

            Behavior on opacity {
                NumberAnimation {
                    duration: 170
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Grid {
                id: grid

                anchors.horizontalCenter: parent.horizontalCenter

                columns: power.columns

                spacing: power.gap

                Repeater {
                    model: power.actions

                    PowerButton {
                        required property var modelData
                        required property int index

                        width: power.cardWidth
                        height: power.cardHeight

                        action: modelData

                        selected: power.selectedIndex === index && power.armedIndex === -1

                        armed: power.armedIndex === index

                        onActivated: {
                            power.activate(index);
                        }

                        onHovered: {
                            /*
                             * Hover moves the selection but must not
                             * disarm — the pointer travelling toward
                             * the tile it just armed would cancel the
                             * confirmation out from under itself.
                             */
                            power.selectedIndex = index;
                        }
                    }
                }
            }

            // ----------------------------------------------------
            // FOOTER
            // ----------------------------------------------------

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: power.uptime === "" ? "" : power.uptime

                color: Colors.subtext

                font.family: Typography.ui
                font.pixelSize: Typography.sm

                textFormat: Text.PlainText
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: power.armedIndex !== -1 ? "Enter to confirm  ·  Esc to cancel" : "↑↓←→ to move  ·  Enter to select  ·  Esc to close"

                color: Colors.subtext

                opacity: 0.55

                font.family: Typography.ui
                font.pixelSize: Typography.xs

                textFormat: Text.PlainText
            }
        }
    }

    // ============================================================
    // SHORTCUT
    //
    //   hl.bind("SUPER + X", hl.dsp.global("quickshell:powermenu"))
    // ============================================================

    GlobalShortcut {
        appid: "quickshell"
        name: "powermenu"

        description: "Toggle the session power menu"

        onPressed: {
            power.toggle();
        }
    }
}
