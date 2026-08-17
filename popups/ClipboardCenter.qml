import QtQuick
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

    width: panelWidth
    height: panelHeight

    // ============================================================
    // CLIPBOARD HISTORY
    // ============================================================

    Process {
        id: listProcess

        command: [
            "cliphist",
            "list"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                clipboardCenter.parseClipboardList(this.text)
            }
        }
    }

    function refresh() {
        listProcess.running = false
        listProcess.running = true
    }

    function parseClipboardList(output) {
        const lines = output.split("\n")
        const items = []

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i]

            if (line.trim() === "")
                continue

            const separator = line.indexOf("\t")

            if (separator === -1)
                continue

            const id = line.substring(0, separator)
            const text = line.substring(separator + 1)

            // Example:
            //
            // [[ binary data 324 KiB png 494x404 ]]
            //
            const imageMatch = text.match(
                /^\[\[\s*binary data\s+.*?\s+([a-zA-Z0-9]+)\s+(\d+)x(\d+)\s*\]\]$/
            )

            const isImage = imageMatch !== null

            let extension = ""
            let imageWidth = 0
            let imageHeight = 0

            if (isImage) {
                extension = imageMatch[1].toLowerCase()
                imageWidth = Number(imageMatch[2])
                imageHeight = Number(imageMatch[3])
            }

            items.push({
                id: id,
                text: text,
                rawLine: line,

                isImage: isImage,

                extension: extension,
                imageWidth: imageWidth,
                imageHeight: imageHeight,

                imagePath: isImage
                    ? "/tmp/quickshell-clipboard-" +
                      id +
                      "." +
                      extension
                    : "",

                imageReady: false
            })
        }

        clipboardItems = items

        prepareImages()
    }

    // ============================================================
    // IMAGE DECODING
    // ============================================================

    function prepareImages() {
        for (let i = 0; i < clipboardItems.length; i++) {
            const item = clipboardItems[i]

            if (!item.isImage)
                continue

            decodeImage(item)
        }
    }

    function decodeImage(item) {
        const tempPath = item.imagePath + ".tmp"

        const process = Qt.createQmlObject(`
            import Quickshell
            import Quickshell.Io

            Process {
                command: [
                    "sh",
                    "-c",
                    "set -e; " +
                    "printf '%s\\\\n' \\"$1\\" | cliphist decode > \\"$2\\"; " +
                    "file --mime-type \\"$2\\" | grep -q '^.*image/'; " +
                    "mv \\"$2\\" \\"$3\\"",
                    "clipboard-image",
                    ${JSON.stringify(item.rawLine)},
                    ${JSON.stringify(tempPath)},
                    ${JSON.stringify(item.imagePath)}
                ]

                running: true

                onExited: function(exitCode, exitStatus) {
                    if (exitCode === 0) {
                        clipboardCenter.markImageReady(
                            ${JSON.stringify(item.id)}
                        )
                    } else {
                        console.log(
                            "Failed to decode clipboard image:",
                            ${JSON.stringify(item.id)},
                            "exit code:",
                            exitCode
                        )
                    }

                    destroy()
                }
            }
        `, clipboardCenter)

        process.running = true
    }

    function markImageReady(id) {
        for (let i = 0; i < clipboardItems.length; i++) {
            if (clipboardItems[i].id === id) {
                clipboardItems[i].imageReady = true

                clipboardItems = clipboardItems.slice()

                break
            }
        }
    }

    // ============================================================
    // SEARCH
    // ============================================================

    property var filteredItems: {
        const query = searchText.trim().toLowerCase()

        if (query === "")
            return clipboardItems

        return clipboardItems.filter(item => {
            return item.text.toLowerCase().includes(query)
        })
    }

    // ============================================================
    // COPY SELECTED ITEM
    // ============================================================

    Process {
        id: copyProcess

        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                clipboardCenter.close()
            } else {
                console.log(
                    "Failed to copy clipboard item. Exit code:",
                    exitCode
                )
            }
        }
    }

    function copyItem(item) {
        if (copyProcess.running)
            return

        copyProcess.command = [
            "sh",
            "-c",
            "printf '%s\\n' \"$1\" | cliphist decode | wl-copy",
            "clipboard-copy",
            item.rawLine
        ]

        copyProcess.running = true
    }

    // ============================================================
    // WIPE CLIPBOARD HISTORY
    // ============================================================

    Process {
        id: wipeProcess

        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                clipboardItems = []
                searchText = ""
                searchInput.text = ""

                /*
                 * Refresh after wiping so the UI reflects the
                 * actual cliphist database.
                 */
                clipboardCenter.refresh()
            } else {
                console.log(
                    "Failed to wipe clipboard history. Exit code:",
                    exitCode
                )
            }
        }
    }

    function wipeClipboard() {
        if (wipeProcess.running)
            return

        wipeProcess.command = [
            "cliphist",
            "wipe"
        ]

        wipeProcess.running = true
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        searchText = ""
        searchInput.text = ""

        refresh()

        opened = true

        searchFocusTimer.restart()
    }

    function close() {
        opened = false

        searchText = ""
        searchInput.text = ""

        searchInput.focus = false
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    Timer {
        id: searchFocusTimer

        interval: 80
        repeat: false

        onTriggered: {
            if (clipboardCenter.opened)
                searchInput.forceActiveFocus()
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

                color: Colors.base

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

                            font.family: Typography.firaCode
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

                            color:
                                wipeMouse.containsMouse
                                ? Colors.surface
                                : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                anchors.centerIn: parent

                                text: "󰃢"

                                color:
                                    wipeMouse.containsMouse
                                    ? Colors.text
                                    : Colors.subtext

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

                                cursorShape:
                                    Qt.PointingHandCursor

                                onClicked: {
                                    clipboardCenter.wipeClipboard()
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

                        border.width:
                            searchInput.activeFocus ? 1 : 0

                        border.color: Colors.blue

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

                                    selectionColor: Colors.blue

                                    font.family:
                                        Typography.firaCode

                                    font.pixelSize:
                                        Typography.sm

                                    clip: true

                                    verticalAlignment:
                                        TextInput.AlignVCenter

                                    onTextChanged: {
                                        clipboardCenter.searchText = text
                                    }

                                    Keys.onEscapePressed: {
                                        clipboardCenter.close()
                                    }
                                }

                                Text {
                                    anchors.fill: parent

                                    visible:
                                        searchInput.text.length === 0 &&
                                        !searchInput.activeFocus

                                    text: "Search clipboard..."

                                    color: Colors.subtext

                                    opacity: 0.5

                                    font.family:
                                        Typography.firaCode

                                    font.pixelSize:
                                        Typography.sm

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    textFormat:
                                        Text.PlainText

                                    MouseArea {
                                        anchors.fill: parent

                                        onClicked: {
                                            searchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: {
                                searchInput.forceActiveFocus()
                            }
                        }
                    }

                    // =================================================
                    // EMPTY STATE
                    // =================================================

                    Text {
                        visible:
                            clipboardCenter.filteredItems.length === 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        text:
                            clipboardCenter.clipboardItems.length === 0
                            ? "No clipboard history"
                            : "No results"

                        color: Colors.subtext

                        font.family:
                            Typography.firaCode

                        font.pixelSize:
                            Typography.md

                        opacity: 0.6

                        textFormat:
                            Text.PlainText
                    }

                    // =================================================
                    // CLIPBOARD LIST
                    // =================================================

                    ListView {
                        id: clipboardList

                        visible:
                            clipboardCenter.filteredItems.length > 0

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        clip: true

                        spacing: 6

                        model:
                            clipboardCenter.filteredItems

                        delegate: Rectangle {
                            id: clipboardDelegate

                            required property var modelData
                            required property int index

                            width: clipboardList.width

                            height:
                                clipboardDelegate.modelData.isImage
                                ? 100
                                : 54

                            radius: 8

                            color:
                                clipboardMouse.containsMouse
                                ? Colors.surface
                                : "transparent"

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

                                        text:
                                            `${clipboardDelegate.index + 1}`

                                        color: Colors.subtext

                                        font.family:
                                            Typography.firaCode

                                        font.pixelSize:
                                            Typography.xs

                                        font.bold: true

                                        textFormat:
                                            Text.PlainText
                                    }
                                }

                                // =====================================
                                // IMAGE PREVIEW
                                // =====================================

                                Rectangle {
                                    visible:
                                        clipboardDelegate.modelData.isImage

                                    Layout.preferredWidth: 82
                                    Layout.preferredHeight: 82

                                    radius: 6

                                    color: Colors.base

                                    clip: true

                                    Image {
                                        id: previewImage

                                        anchors.fill: parent

                                        anchors.margins: 2

                                        visible:
                                            clipboardDelegate.modelData.imageReady

                                        source:
                                            clipboardDelegate.modelData.imageReady
                                            ? "file://" +
                                              clipboardDelegate.modelData.imagePath
                                            : ""

                                        fillMode:
                                            Image.PreserveAspectFit

                                        asynchronous: true

                                        cache: false
                                    }

                                    Text {
                                        anchors.centerIn: parent

                                        visible:
                                            !clipboardDelegate.modelData.imageReady ||
                                            previewImage.status !== Image.Ready

                                        text: "󰋩"

                                        color: Colors.subtext

                                        font.pixelSize: 24

                                        opacity: 0.5

                                        textFormat:
                                            Text.PlainText
                                    }
                                }

                                // =====================================
                                // NORMAL TEXT
                                // =====================================

                                Text {
                                    visible:
                                        !clipboardDelegate.modelData.isImage

                                    Layout.fillWidth: true

                                    text:
                                        clipboardDelegate.modelData.text

                                    color: Colors.text

                                    font.family:
                                        Typography.firaCode

                                    font.pixelSize:
                                        Typography.sm

                                    maximumLineCount: 2

                                    wrapMode:
                                        Text.WordWrap

                                    elide:
                                        Text.ElideRight

                                    textFormat:
                                        Text.PlainText
                                }

                                // =====================================
                                // IMAGE INFORMATION
                                // =====================================

                                ColumnLayout {
                                    visible:
                                        clipboardDelegate.modelData.isImage

                                    Layout.fillWidth: true

                                    spacing: 2

                                    Text {
                                        text: "Image"

                                        color: Colors.text

                                        font.family:
                                            Typography.firaCode

                                        font.pixelSize:
                                            Typography.sm

                                        font.bold: true

                                        textFormat:
                                            Text.PlainText
                                    }

                                    Text {
                                        text:
                                            clipboardDelegate.modelData.imageWidth +
                                            "x" +
                                            clipboardDelegate.modelData.imageHeight +
                                            "  " +
                                            clipboardDelegate.modelData.extension.toUpperCase()

                                        color: Colors.subtext

                                        font.family:
                                            Typography.firaCode

                                        font.pixelSize:
                                            Typography.xs

                                        textFormat:
                                            Text.PlainText
                                    }
                                }

                                // =====================================
                                // COPY BUTTON
                                // =====================================

                                Rectangle {
                                    id: copyButton

                                    visible:
                                        clipboardMouse.containsMouse

                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30

                                    radius: 7

                                    color:
                                        copyButtonMouse.containsMouse
                                        ? Colors.surface
                                        : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent

                                        text: "󰆏"

                                        color:
                                            copyButtonMouse.containsMouse
                                            ? Colors.text
                                            : Colors.subtext

                                        font.pixelSize: 16

                                        textFormat:
                                            Text.PlainText

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 120
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: copyButtonMouse

                                        anchors.fill: parent

                                        hoverEnabled: true

                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked: {
                                            clipboardCenter.copyItem(
                                                clipboardDelegate.modelData
                                            )
                                        }
                                    }
                                }
                            }

                            // =============================================
                            // ROW HOVER
                            // =============================================

                            MouseArea {
                                id: clipboardMouse

                                anchors.fill: parent

                                hoverEnabled: true

                                cursorShape:
                                    Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }
        }
    }
}