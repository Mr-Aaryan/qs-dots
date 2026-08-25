pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

import "../theme"
import "."

/*
 * Spotlight — a centred application search, in the shape of the one
 * on macOS.
 *
 * This is its own layer-shell window rather than a popup hung off the
 * bar, for two reasons: it needs real keyboard focus (a bar popup only
 * ever gets a Hyprland focus grab, which routes clicks but not keys),
 * and it has to sit over everything on screen including fullscreen
 * windows.
 *
 * Bound on the Hyprland side as "quickshell:spotlight" — see the
 * GlobalShortcut at the bottom of this file.
 */
PanelWindow {
    id: spotlight

    // ============================================================
    // STATE
    // ============================================================

    property bool opened: false

    /*
     * Window mapping is a separate flag from `opened` so the close
     * animation has something to play over. Unmapping on `opened`
     * alone would make the panel vanish instantly.
     */
    property bool mapped: false

    property string query: ""

    property int selectedIndex: 0

    // ============================================================
    // METRICS
    // ============================================================

    readonly property int panelWidth: 680

    readonly property int searchHeight: 62
    readonly property int rowHeight: 44

    // How many results are on screen before the list starts scrolling.
    readonly property int maxRows: 8

    /*
     * macOS puts the field a little above the vertical centre — high
     * enough that a full result list still has room beneath it.
     */
    readonly property real verticalBias: 0.2

    // ============================================================
    // WINDOW
    // ============================================================

    visible: spotlight.mapped

    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    /*
     * -1 exclusive zone: cover the whole output, including the strip
     * the bar reserves for itself, rather than starting below it.
     */
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay

    /*
     * Exclusive focus while open, so keystrokes reach the field
     * instead of whatever window was focused underneath. None while
     * closed — an Overlay surface holding focus would swallow every
     * key on the desktop.
     */
    WlrLayershell.keyboardFocus: spotlight.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ============================================================
    // SEARCH
    // ============================================================

    readonly property var results: spotlight.search(spotlight.query)

    readonly property bool hasQuery: spotlight.query.trim() !== ""

    readonly property bool noResults: spotlight.hasQuery && spotlight.results.length === 0

    /*
     * The entries worth offering, resolved once rather than on every
     * keystroke — the icon lookups below hit the icon theme on disk.
     *
     * A resolvable icon is what separates real applications from the
     * entries shipped alongside libraries and CLI tools (hwloc's
     * lstopo, the Avahi browsers, nm-connection-editor). Those name an
     * icon no installed theme provides, so they can only ever render
     * as a blank square, and they are not what anyone is searching
     * for.
     *
     * The icon is carried alongside the entry rather than looked up
     * again in the row, so what is filtered and what is drawn cannot
     * disagree.
     */
    readonly property var launchable: {
        const entries = DesktopEntries.applications.values;

        const usable = [];

        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];

            if (entry.noDisplay)
                continue;

            const icon = spotlight.resolveIcon(entry);

            if (icon === "")
                continue;

            usable.push({
                entry: entry,
                icon: icon,
                /*
                 * Precomputed for the same reason: `search` runs over
                 * every entry on every keystroke.
                 */
                haystack: {
                    name: entry.name.toLowerCase(),
                    genericName: entry.genericName.toLowerCase(),
                    comment: entry.comment.toLowerCase(),
                    keywords: entry.keywords.map(k => k.toLowerCase())
                },
                subtitle: entry.genericName !== "" && entry.genericName !== entry.name ? entry.genericName : "Application"
            });
        }

        return usable;
    }

    /*
     * The icon an entry names, or the one its desktop id implies.
     *
     * The second fallback matters more than it looks: an entry whose
     * Icon= key names something generic the active theme happens not
     * to carry — nemo asking for "system-file-manager" under Adwaita —
     * still usually ships an icon under its own id.
     *
     * Returns "" when nothing resolves, which is also the signal to
     * drop the entry.
     */
    function resolveIcon(entry) {
        // The trailing `true` makes iconPath return "" for a miss.
        if (entry.icon !== "") {
            const named = Quickshell.iconPath(entry.icon, true);

            if (named !== "")
                return named;
        }

        return Quickshell.iconPath(entry.id, true);
    }

    function search(text) {
        const needle = text.trim().toLowerCase();

        if (needle === "")
            return [];

        const candidates = spotlight.launchable;

        const matches = [];

        for (let i = 0; i < candidates.length; i++) {
            const candidate = candidates[i];

            const score = spotlight.score(candidate.haystack, needle);

            if (score <= 0)
                continue;

            matches.push({
                entry: candidate.entry,
                icon: candidate.icon,
                score: score,
                subtitle: candidate.subtitle
            });
        }

        matches.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;

            return a.entry.name.localeCompare(b.entry.name);
        });

        /*
         * Past a couple of dozen the tail is noise, and the list is
         * only ever eight rows tall.
         */
        return matches.slice(0, 24);
    }

    /*
     * Ranking, strongest signal first: what the app is called beats
     * what it says about itself.
     *
     * Ties are broken towards shorter names, so "Files" outranks
     * "Files (Root)" for the query "files".
     */
    function score(haystack, needle) {
        const name = haystack.name;

        const lengthBias = Math.min(name.length, 40) * 0.5;

        if (name === needle)
            return 1000;
        if (name.startsWith(needle))
            return 800 - lengthBias;

        // A match at the start of any word — "code" in "Visual Studio Code".
        if (name.includes(" " + needle))
            return 600 - lengthBias;
        if (name.includes(needle))
            return 450 - lengthBias;
        if (haystack.genericName.includes(needle))
            return 300;

        const keywords = haystack.keywords;

        for (let i = 0; i < keywords.length; i++) {
            if (keywords[i].includes(needle))
                return 250;
        }

        if (haystack.comment.includes(needle))
            return 150;

        /*
         * Last resort: the query as a subsequence of the name, which
         * is what makes "gimp" find "GNU Image Manipulation Program"
         * and "vsc" find "Visual Studio Code".
         */
        if (spotlight.isSubsequence(needle, name))
            return 80;

        return 0;
    }

    function isSubsequence(needle, haystack) {
        let cursor = 0;

        for (let i = 0; i < haystack.length && cursor < needle.length; i++) {
            if (haystack[i] === needle[cursor])
                cursor++;
        }

        return cursor === needle.length;
    }

    // ============================================================
    // SELECTION
    // ============================================================

    onResultsChanged: {
        spotlight.selectedIndex = 0;
    }

    onSelectedIndexChanged: {
        resultList.positionViewAtIndex(spotlight.selectedIndex, ListView.Contain);
    }

    function move(delta) {
        const count = spotlight.results.length;

        if (count === 0)
            return;

        // Wraps, like the real one does.
        spotlight.selectedIndex = (spotlight.selectedIndex + delta + count) % count;
    }

    function activate(index) {
        const result = spotlight.results[index];

        if (!result)
            return;

        result.entry.execute();

        spotlight.close();
    }

    // ============================================================
    // OPEN / CLOSE
    // ============================================================

    function open() {
        spotlight.query = "";
        searchInput.text = "";

        spotlight.selectedIndex = 0;

        unmapTimer.stop();

        spotlight.mapped = true;
        spotlight.opened = true;

        focusTimer.restart();
    }

    function close() {
        spotlight.opened = false;

        spotlight.query = "";
        searchInput.text = "";

        searchInput.focus = false;

        focusTimer.stop();

        unmapTimer.restart();
    }

    function toggle() {
        if (spotlight.opened)
            spotlight.close();
        else
            spotlight.open();
    }

    /*
     * The compositor hands keyboard focus over a round trip after the
     * surface is mapped, so the field cannot take focus in the same
     * frame it appears in.
     */
    Timer {
        id: focusTimer

        interval: 60
        repeat: false

        onTriggered: {
            if (spotlight.opened)
                searchInput.forceActiveFocus();
        }
    }

    // Outlives the close animation below by a hair.
    Timer {
        id: unmapTimer

        interval: 220
        repeat: false

        onTriggered: {
            spotlight.mapped = false;
        }
    }

    // ============================================================
    // SCRIM
    // ============================================================

    Rectangle {
        anchors.fill: parent

        color: Qt.rgba(0, 0, 0, 0.28)

        opacity: spotlight.opened ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                spotlight.close();
            }
        }
    }

    // ============================================================
    // PANEL
    // ============================================================

    Rectangle {
        id: panel

        width: spotlight.panelWidth

        height: spotlight.searchHeight + (spotlight.hasQuery ? bodyHeight + 1 : 0)

        /*
         * The result area, or a single row for the empty state. The
         * +8 is the padding above and below the list.
         */
        readonly property int bodyHeight: {
            if (spotlight.results.length > 0)
                return Math.min(spotlight.results.length, spotlight.maxRows) * spotlight.rowHeight + 8;

            return spotlight.noResults ? spotlight.rowHeight + 8 : 0;
        }

        x: (parent.width - width) / 2

        y: Math.round(parent.height * spotlight.verticalBias)

        radius: 20

        color: Colors.panel

        /*
         * A hairline lift off the wallpaper. Blur it in Hyprland for
         * the frosted look the real one has:
         *
         *   hl.layer_rule({ match = "quickshell", blur = true })
         */
        border.width: 1
        border.color: Qt.lighter(Colors.surface, 1.1)

        opacity: spotlight.opened ? 1 : 0

        scale: spotlight.opened ? 1 : 0.97

        transformOrigin: Item.Center

        Behavior on height {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // --------------------------------------------------------
        // SEARCH FIELD
        //
        // The field is the panel's top edge rather than a box drawn
        // inside it — that shape is most of what makes this read as
        // Spotlight and not as a search popup.
        // --------------------------------------------------------

        RowLayout {
            id: searchRow

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.leftMargin: 20
            anchors.rightMargin: 20

            height: spotlight.searchHeight

            spacing: 14

            Text {
                text: "󰍉"

                color: Colors.subtext

                font.family: Typography.mono
                font.pixelSize: 24

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
                    selectedTextColor: Colors.base

                    font.family: Typography.ui
                    font.pixelSize: 25
                    font.weight: Typography.light

                    clip: true

                    verticalAlignment: TextInput.AlignVCenter

                    onTextChanged: {
                        spotlight.query = text;
                    }

                    Keys.onEscapePressed: {
                        spotlight.close();
                    }

                    Keys.onUpPressed: {
                        spotlight.move(-1);
                    }

                    Keys.onDownPressed: {
                        spotlight.move(1);
                    }

                    Keys.onReturnPressed: {
                        spotlight.activate(spotlight.selectedIndex);
                    }

                    Keys.onEnterPressed: {
                        spotlight.activate(spotlight.selectedIndex);
                    }

                    // Tab walks the list too, the way it does on macOS.
                    Keys.onTabPressed: {
                        spotlight.move(1);
                    }

                    Keys.onBacktabPressed: {
                        spotlight.move(-1);
                    }
                }

                Text {
                    anchors.fill: parent

                    visible: searchInput.text.length === 0

                    text: "Spotlight Search"

                    color: Colors.subtext

                    opacity: 0.45

                    font.family: Typography.ui
                    font.pixelSize: 25
                    font.weight: Typography.light

                    verticalAlignment: Text.AlignVCenter

                    textFormat: Text.PlainText
                }
            }
        }

        // --------------------------------------------------------
        // DIVIDER
        // --------------------------------------------------------

        Rectangle {
            id: divider

            anchors.top: searchRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.leftMargin: 1
            anchors.rightMargin: 1

            height: 1

            visible: spotlight.hasQuery

            color: Colors.surface

            opacity: 0.8
        }

        // --------------------------------------------------------
        // RESULTS
        // --------------------------------------------------------

        ListView {
            id: resultList

            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            anchors.margins: 4
            anchors.topMargin: 4

            visible: spotlight.results.length > 0

            clip: true

            model: spotlight.results

            /*
             * The delegate paints its own selection fill, so the view
             * needs no highlight of its own.
             */
            boundsBehavior: Flickable.StopAtBounds

            delegate: AppItem {
                required property var modelData
                required property int index

                width: resultList.width

                result: modelData

                selected: spotlight.selectedIndex === index

                onActivated: {
                    spotlight.activate(index);
                }

                onHovered: {
                    spotlight.selectedIndex = index;
                }
            }
        }

        Text {
            anchors.top: divider.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            height: spotlight.rowHeight + 8

            visible: spotlight.noResults

            text: "No Results"

            color: Colors.subtext

            font.family: Typography.ui
            font.pixelSize: Typography.md

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            opacity: 0.6

            textFormat: Text.PlainText
        }
    }

    // ============================================================
    // SHORTCUT
    //
    // Exposed to Hyprland through the global-shortcuts protocol as
    // "quickshell:spotlight". Bind it on the Hyprland side with:
    //
    //   hl.bind("SUPER + SPACE", hl.dsp.global("quickshell:spotlight"))
    // ============================================================

    GlobalShortcut {
        appid: "quickshell"
        name: "spotlight"

        description: "Toggle the spotlight application search"

        onPressed: {
            spotlight.toggle();
        }
    }
}
