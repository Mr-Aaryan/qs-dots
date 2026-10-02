pragma ComponentBehavior: Bound

import QtQuick
import QtCore
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../theme"

Item {
    id: clipboardCenter

    property bool opened: false
    readonly property int panelWidth: 320
    readonly property int panelHeight: 420

    property string searchText: ""
    property var clipboardItems: []

    /*
     * Raw `cliphist list` output from the last refresh. When a refresh
     * returns the same output the model is left untouched, so reopening
     * the popup does not rebuild every delegate.
     */
    property string lastListOutput: ""

    /*
     * Set of entry ids whose image has been decoded to disk. Kept
     * outside the model on purpose: replacing the model for every
     * decoded image rebuilt the whole list and reset the selection.
     */
    property var readyImages: ({})
    property var pendingReadyImages: ({})

    /*
     * Id of the entry currently being copied, and the id of the
     * entry that was just copied successfully. The latter drives
     * the "Copied" badge in the list.
     */
    property string pendingCopyId: ""
    property string copiedId: ""

    width: panelWidth
    height: panelHeight

    // ============================================================
    // CLIPBOARD HISTORY
    // ============================================================

    Process {
        id: listProcess

        command: ["cliphist", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                clipboardCenter.parseClipboardList(this.text);
            }
        }
    }

    function refresh() {
        listProcess.running = false;
        listProcess.running = true;
    }

    function parseClipboardList(output) {
        if (output === lastListOutput)
            return;

        lastListOutput = output;

        const lines = output.split("\n");
        const items = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            if (line.trim() === "")
                continue;

            const separator = line.indexOf("\t");

            if (separator === -1)
                continue;

            const id = line.substring(0, separator);
            const text = line.substring(separator + 1);

            // Example:
            //
            // [[ binary data 324 KiB png 494x404 ]]
            //
            const imageMatch = text.match(/^\[\[\s*binary data\s+.*?\s+([a-zA-Z0-9]+)\s+(\d+)x(\d+)\s*\]\]$/);

            const isImage = imageMatch !== null;

            let extension = "";
            let imageWidth = 0;
            let imageHeight = 0;

            if (isImage) {
                extension = imageMatch[1].toLowerCase();
                imageWidth = Number(imageMatch[2]);
                imageHeight = Number(imageMatch[3]);
            }

            items.push({
                id: id,
                text: text,
                rawLine: line,
                isImage: isImage,
                extension: extension,
                imageWidth: imageWidth,
                imageHeight: imageHeight,
                imagePath: isImage ? "/tmp/quickshell-clipboard-" + id + "." + extension : ""
            });
        }

        clipboardItems = items;

        prepareImages();

        Qt.callLater(function () {
            if (clipboardList.count > 0)
                clipboardList.currentIndex = 0;
            else
                clipboardList.currentIndex = -1;
        });
    }

    // ============================================================
    // IMAGE DECODING
    // ============================================================

    /*
     * A single shell process walks every image entry, newest first.
     * Entries already decoded by an earlier run are reused from /tmp,
     * so only new images ever hit `cliphist decode`. The id of each
     * image that is available on disk is printed on its own line.
     */
    Process {
        id: decodeProcess

        stdout: SplitParser {
            onRead: data => clipboardCenter.markImageReady(data.trim())
        }
    }

    function prepareImages() {
        const args = [];

        for (let i = 0; i < clipboardItems.length; i++) {
            const item = clipboardItems[i];

            if (item.isImage)
                args.push(item.rawLine, item.imagePath, item.id);
        }

        decodeProcess.running = false;

        if (args.length === 0)
            return;

        decodeProcess.command = ["sh", "-c", "while [ $# -ge 3 ]; do " + "raw=$1; out=$2; id=$3; shift 3; " + "if [ ! -s \"$out\" ]; then " + "printf '%s\\n' \"$raw\" | cliphist decode > \"$out.tmp\" " + "&& file --mime-type -b \"$out.tmp\" | grep -q '^image/' " + "&& mv \"$out.tmp\" \"$out\" " + "|| { rm -f \"$out.tmp\"; continue; }; " + "fi; " + "printf '%s\\n' \"$id\"; " + "done", "clipboard-images"].concat(args);

        decodeProcess.running = true;
    }

    /*
     * Ready ids arrive one per line; they are batched and applied once
     * per event-loop turn so a burst of cached images costs a single
     * property update.
     */
    function markImageReady(id) {
        if (id === "")
            return;

        pendingReadyImages[id] = true;

        Qt.callLater(flushReadyImages);
    }

    function flushReadyImages() {
        readyImages = Object.assign({}, readyImages, pendingReadyImages);
        pendingReadyImages = {};
    }

    // ============================================================
    // SEARCH
    // ============================================================

    property var filteredItems: {
        const query = searchText.trim().toLowerCase();

        if (query === "")
            return clipboardItems;

        return clipboardItems.filter(item => {
            return item.text.toLowerCase().includes(query);
        });
    }

    /*
     * Whenever the search results change, reset keyboard selection
     * to the first result.
     */
    onSearchTextChanged: {
        Qt.callLater(function () {
            if (clipboardList.count > 0) {
                clipboardList.currentIndex = 0;
            } else {
                clipboardList.currentIndex = -1;
            }
        });
    }

    // ============================================================
    // COPY SELECTED ITEM
    // ============================================================

    Process {
        id: copyProcess

        running: false

        onExited: function (exitCode) {
            if (exitCode === 0) {
                /*
                 * Show the "Copied" badge for a moment before the
                 * popup disappears, otherwise a successful copy is
                 * indistinguishable from the popup simply closing.
                 */
                clipboardCenter.copiedId = clipboardCenter.pendingCopyId;

                copyFeedbackTimer.restart();
            } else {
                console.log("Clipboard copy failed, exit code:", exitCode);

                clipboardCenter.pendingCopyId = "";
            }
        }
    }

    Timer {
        id: copyFeedbackTimer

        interval: 550
        repeat: false

        onTriggered: {
            clipboardCenter.close();
        }
    }

    function copyItem(item) {
        if (!item)
            return;

        if (copyProcess.running || clipboardCenter.copiedId !== "")
            return;

        clipboardCenter.pendingCopyId = item.id;

        copyProcess.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "clipboard-copy", item.rawLine];

        copyProcess.running = true;
    }

    function copyCurrent() {
        const index = clipboardList.currentIndex;

        if (index >= 0 && index < filteredItems.length)
            copyItem(filteredItems[index]);
    }

    // ============================================================
    // WIPE CLIPBOARD HISTORY
    // ============================================================

    Process {
        id: wipeProcess

        running: false

        onRunningChanged: if (!running) {
            clipboardCenter.clipboardItems = [];
            clipboardCenter.lastListOutput = "";
            clipboardCenter.readyImages = {};
            clipboardCenter.searchText = "";
            searchInput.text = "";
            clipboardList.currentIndex = -1;

            /*
             * Refresh after wiping so the UI reflects the
             * actual cliphist database.
             */
            clipboardCenter.refresh();
        }
    }

    function wipeClipboard() {
        decodeProcess.running = false;

        wipeProcess.command = ["sh", "-c", "cliphist wipe; rm -f /tmp/quickshell-clipboard-*"];
        wipeProcess.running = true;
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        searchText = "";
        searchInput.text = "";

        clipboardList.currentIndex = clipboardList.count > 0 ? 0 : -1;
        clipboardList.positionViewAtBeginning();

        refresh();

        opened = true;

        /*
         * Keyboard focus starts on the list with the newest entry
         * selected. Typing still searches: printable keys pressed in
         * the list are forwarded to the search field.
         */
        clipboardList.forceActiveFocus();
        listFocusTimer.restart();
    }

    function close() {
        opened = false;

        searchText = "";
        searchInput.text = "";

        searchInput.focus = false;
        clipboardList.focus = false;

        clipboardList.currentIndex = -1;

        copyFeedbackTimer.stop();

        copiedId = "";
        pendingCopyId = "";
    }

    function toggle() {
        if (opened)
            close();
        else
            open();
    }

    Timer {
        id: listFocusTimer

        interval: 80
        repeat: false

        /*
         * Re-assert focus once the focus grab has handed the window
         * keyboard focus, unless the user already moved it.
         */
        onTriggered: {
            if (clipboardCenter.opened && !searchInput.activeFocus)
                clipboardList.forceActiveFocus();
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

            y: clipboardCenter.opened ? 0 : -height

            opacity: clipboardCenter.opened ? 1 : 0.85

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
                id: panel

                anchors.fill: parent

                radius: 12

                color: Colors.panel

                border.width: 1
                border.color: Colors.surface

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12

                    spacing: 8

                    // =================================================
                    // HEADER
                    // =================================================

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Clipboard"

                            color: Colors.text

                            font.family: Typography.ui
                            font.pixelSize: Typography.lg
                            font.bold: true

                            Layout.fillWidth: true

                            textFormat: Text.PlainText
                        }

                        // ---------------------------------------------
                        // WIPE BUTTON
                        // ---------------------------------------------

                        Rectangle {
                            id: wipeButton

                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30

                            radius: 7

                            color: wipeMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "󰃢"

                                color: wipeMouse.containsMouse ? Colors.text : Colors.subtext

                                font.pixelSize: 17

                                textFormat: Text.PlainText

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                id: wipeMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    clipboardCenter.wipeClipboard();
                                }
                            }
                        }
                    }

                    // =================================================
                    // SEARCH
                    // =================================================

                    Rectangle {
                        id: searchBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34

                        radius: 8

                        color: Colors.surface

                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: Colors.accent

                        RowLayout {
                            anchors.fill: parent

                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            spacing: 8

                            Text {
                                text: "󰍉"

                                color: Colors.subtext

                                font.pixelSize: 16

                                textFormat: Text.PlainText
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                TextInput {
                                    id: searchInput

                                    anchors.fill: parent

                                    color: Colors.text
                                    selectionColor: Colors.accent

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.sm

                                    clip: true

                                    verticalAlignment: TextInput.AlignVCenter

                                    onTextChanged: {
                                        clipboardCenter.searchText = text;
                                    }

                                    /*
                                     * Down from the search field moves
                                     * keyboard focus into the clipboard list.
                                     */
                                    Keys.onDownPressed: {
                                        if (clipboardList.count > 0) {
                                            clipboardList.currentIndex = 0;
                                            clipboardList.forceActiveFocus();
                                            clipboardList.positionViewAtIndex(clipboardList.currentIndex, ListView.Contain);
                                        }
                                    }

                                    Keys.onReturnPressed: clipboardCenter.copyCurrent()
                                    Keys.onEnterPressed: clipboardCenter.copyCurrent()

                                    Keys.onEscapePressed: {
                                        clipboardCenter.close();
                                    }
                                }

                                Text {
                                    anchors.fill: parent

                                    visible: searchInput.text.length === 0 && !searchInput.activeFocus

                                    text: "Search clipboard..."

                                    color: Colors.subtext
                                    opacity: 0.5

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.sm

                                    verticalAlignment: Text.AlignVCenter

                                    textFormat: Text.PlainText

                                    MouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            searchInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    // =================================================
                    // EMPTY STATE
                    // =================================================

                    Text {
                        visible: clipboardCenter.filteredItems.length === 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        text: clipboardCenter.clipboardItems.length === 0 ? "No clipboard history" : "No results"

                        color: Colors.subtext

                        font.family: Typography.ui
                        font.pixelSize: Typography.md

                        opacity: 0.6

                        textFormat: Text.PlainText
                    }

                    // =================================================
                    // CLIPBOARD LIST
                    // =================================================

                    ListView {
                        id: clipboardList

                        visible: clipboardCenter.filteredItems.length > 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing: 6

                        model: clipboardCenter.filteredItems

                        /*
                         * Allow the ListView itself to receive keyboard
                         * focus.
                         */
                        focus: clipboardCenter.opened

                        /*
                         * UP — from the first entry, move to the
                         * search field.
                         */
                        Keys.onUpPressed: {
                            if (currentIndex > 0) {
                                currentIndex--;

                                positionViewAtIndex(currentIndex, ListView.Contain);
                            } else {
                                searchInput.forceActiveFocus();
                            }
                        }

                        /*
                         * Typing while the list has focus goes to the
                         * search field, so search works without having
                         * to move focus there first.
                         */
                        Keys.onPressed: event => {
                            if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                                return;

                            if (event.key === Qt.Key_Backspace) {
                                searchInput.forceActiveFocus();
                                searchInput.remove(searchInput.text.length - 1, searchInput.text.length);
                                event.accepted = true;
                            } else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                                searchInput.forceActiveFocus();
                                searchInput.insert(searchInput.text.length, event.text);
                                event.accepted = true;
                            }
                        }

                        /*
                         * DOWN
                         */
                        Keys.onDownPressed: {
                            if (currentIndex < count - 1) {
                                currentIndex++;

                                positionViewAtIndex(currentIndex, ListView.Contain);
                            }
                        }

                        /*
                         * ENTER
                         */
                        Keys.onReturnPressed: clipboardCenter.copyCurrent()

                        /*
                         * Numpad Enter / alternate Enter event.
                         */
                        Keys.onEnterPressed: clipboardCenter.copyCurrent()

                        /*
                         * ESCAPE
                         */
                        Keys.onEscapePressed: {
                            clipboardCenter.close();
                        }

                        delegate: Rectangle {
                            id: clipboardDelegate

                            required property var modelData
                            required property int index

                            readonly property bool imageReady: clipboardCenter.readyImages[modelData.id] === true

                            width: clipboardList.width

                            height: clipboardDelegate.modelData.isImage ? 100 : 54

                            radius: 8

                            /*
                             * Keyboard-selected item and hovered item
                             * share the same highlight.
                             */
                            color: clipboardList.currentIndex === index || clipboardMouse.containsMouse ? Colors.surface : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            RowLayout {
                                anchors.fill: parent

                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                spacing: 10

                                // =====================================
                                // NUMBER
                                // =====================================

                                Rectangle {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26

                                    radius: 6

                                    color: Colors.surface

                                    Text {
                                        anchors.centerIn: parent

                                        text: `${clipboardDelegate.index + 1}`

                                        color: Colors.subtext

                                        font.family: Typography.ui
                                        font.pixelSize: Typography.xs
                                        font.bold: true

                                        textFormat: Text.PlainText
                                    }
                                }

                                // =====================================
                                // IMAGE PREVIEW
                                // =====================================

                                Rectangle {
                                    visible: clipboardDelegate.modelData.isImage

                                    Layout.preferredWidth: 82
                                    Layout.preferredHeight: 82

                                    radius: 6

                                    color: Colors.base

                                    clip: true

                                    Image {
                                        id: previewImage

                                        anchors.fill: parent
                                        anchors.margins: 2

                                        visible: clipboardDelegate.imageReady

                                        source: clipboardDelegate.imageReady ? "file://" + clipboardDelegate.modelData.imagePath : ""

                                        fillMode: Image.PreserveAspectFit

                                        asynchronous: true
                                        cache: false
                                    }

                                    Text {
                                        anchors.centerIn: parent

                                        visible: !clipboardDelegate.imageReady || previewImage.status !== Image.Ready

                                        text: "󰋩"

                                        color: Colors.subtext

                                        font.pixelSize: 24

                                        opacity: 0.5

                                        textFormat: Text.PlainText
                                    }
                                }

                                // =====================================
                                // NORMAL TEXT
                                // =====================================

                                Text {
                                    visible: !clipboardDelegate.modelData.isImage

                                    Layout.fillWidth: true

                                    text: clipboardDelegate.modelData.text

                                    color: Colors.text

                                    font.family: Typography.ui
                                    font.pixelSize: Typography.sm

                                    maximumLineCount: 2

                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight

                                    textFormat: Text.PlainText
                                }

                                // =====================================
                                // IMAGE INFORMATION
                                // =====================================

                                ColumnLayout {
                                    visible: clipboardDelegate.modelData.isImage

                                    Layout.fillWidth: true

                                    spacing: 2

                                    Text {
                                        text: "Image"

                                        color: Colors.text

                                        font.family: Typography.ui
                                        font.pixelSize: Typography.sm
                                        font.bold: true

                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        text: clipboardDelegate.modelData.imageWidth + "x" + clipboardDelegate.modelData.imageHeight + "  " + clipboardDelegate.modelData.extension.toUpperCase()

                                        color: Colors.subtext

                                        font.family: Typography.ui
                                        font.pixelSize: Typography.xs

                                        textFormat: Text.PlainText
                                    }
                                }

                                // =====================================
                                // COPY BUTTON / COPIED BADGE
                                //
                                // The whole row is the click target, so
                                // this is a pure affordance — it carries
                                // no MouseArea of its own.
                                // =====================================

                                Rectangle {
                                    id: copyButton

                                    readonly property bool copied: clipboardCenter.copiedId === clipboardDelegate.modelData.id

                                    visible: clipboardMouse.containsMouse || copyButton.copied

                                    Layout.preferredWidth: copyButton.copied ? copyLabel.implicitWidth + 16 : 30

                                    Layout.preferredHeight: 30

                                    radius: 7

                                    color: copyButton.copied ? Colors.accent : Colors.surface

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Text {
                                        id: copyLabel

                                        anchors.centerIn: parent

                                        text: copyButton.copied ? "󰄬 Copied" : "󰆏"

                                        color: copyButton.copied ? Colors.base : Colors.text

                                        font.family: Typography.mono

                                        font.pixelSize: copyButton.copied ? Typography.xs : 16

                                        font.weight: Typography.normal

                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            // =============================================
                            // ROW HOVER + COPY
                            //
                            // This sits on top of the whole row and owns
                            // both hover and clicks, so clicking anywhere
                            // in the row — including the copy button —
                            // copies the entry.
                            // =============================================

                            MouseArea {
                                id: clipboardMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    /*
                                     * Keep keyboard selection synchronized
                                     * with mouse selection.
                                     */
                                    clipboardList.currentIndex = clipboardDelegate.index;

                                    clipboardList.forceActiveFocus();

                                    clipboardCenter.copyItem(clipboardDelegate.modelData);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
