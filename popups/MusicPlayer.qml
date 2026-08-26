import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    implicitWidth: 120
    implicitHeight: 210

    // ============================================================
    // ACTIVE PLAYER
    // ============================================================

    /*
     * Cleared while the panel this lives in is shut or showing a
     * different tab, so nothing is polled for a widget nobody can
     * see. Defaults true so the component still works on its own.
     */
    property bool active: true

    readonly property var activePlayer: {
        const players = Mpris.players.values;

        if (players.length === 0)
            return null;

        /*
         * isPlaying is read for every player rather than stopping at
         * the first match. Array.find short circuits, and a binding
         * only depends on what it actually read -- so once a playing
         * player was found, starting or pausing any player after it
         * in the list would not re-run this.
         */
        let playing = null;

        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying && playing === null)
                playing = players[i];
        }

        return playing ?? players[0];
    }

    readonly property bool hasPlayer: root.activePlayer !== null

    readonly property bool playing: root.hasPlayer && root.activePlayer.isPlaying

    // ============================================================
    // TRACK STATE
    // ============================================================

    property real displayPosition: 0

    /*
     * Duration of the current track, or 0 while it is not known yet.
     *
     * Sticky against zero deliberately: players do report a length of
     * 0 for a moment mid-track, and this used to be frozen at
     * whatever arrived on the track change to avoid that. The catch
     * is that most players emit the track change *before* the new
     * metadata, so the frozen value was the previous track's length
     * and stayed wrong for the whole song. Clearing on a real track
     * change and ignoring only the zeroes gets both cases right.
     */
    property real trackLength: 0

    readonly property bool positionKnown: root.hasPlayer && root.activePlayer.positionSupported

    readonly property bool lengthKnown: root.hasPlayer && root.activePlayer.lengthSupported

    // A seek needs a scale to seek against, not just permission.
    readonly property bool seekable: root.hasPlayer && root.activePlayer.canSeek && root.positionKnown && root.trackLength > 0

    // ============================================================
    // HELPERS
    // ============================================================

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";

        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);

        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function syncLength() {
        if (!root.lengthKnown)
            return;

        const length = Number(root.activePlayer.length);

        if (isFinite(length) && length > 0)
            root.trackLength = length;
    }

    function syncPosition() {
        if (!root.positionKnown || progressMouseArea.pressed)
            return;

        const position = Number(root.activePlayer.position);

        if (isFinite(position) && position >= 0)
            root.displayPosition = position;
    }

    /*
     * The player moved to a different track. The old duration has to
     * go with it -- carrying it over is what made the total time read
     * wrong until the song after next.
     */
    function resetTrack() {
        root.trackLength = 0;
        root.displayPosition = 0;

        root.syncLength();
        root.syncPosition();
    }

    onActivePlayerChanged: {
        root.resetTrack();
    }

    // ============================================================
    // POSITION SYNC
    //
    // Only while something is actually playing and on screen. A
    // paused player's position does not move, and a closed panel has
    // nobody to show it to.
    // ============================================================

    Timer {
        interval: 100
        running: root.active && root.playing && root.positionKnown
        repeat: true

        onTriggered: {
            root.syncPosition();
        }
    }

    // ============================================================
    // MPRIS
    // ============================================================

    Connections {
        target: root.activePlayer

        function onPositionChanged() {
            root.syncPosition();
        }

        /*
         * Length arrives on its own signal, usually a beat after the
         * track change. Without this the duration was only ever read
         * at the instant it was least likely to be there.
         */
        function onLengthChanged() {
            root.syncLength();
        }

        /*
         * The player's own track-change signal, which fires once per
         * track. The old code derived an identity from title, artist
         * and album instead -- fields a player fills in one at a
         * time, so a single track looked like three track changes and
         * reset the position on each.
         */
        function onTrackChanged() {
            root.resetTrack();
        }
    }

    // ============================================================
    // MAIN CARD
    // ============================================================

    Rectangle {
        anchors.fill: parent

        radius: 10

        color: Colors.surface

        border.width: 1
        border.color: Colors.base

        // ========================================================
        // ALBUM ART
        // ========================================================

        Rectangle {
            id: artworkContainer

            width: 64
            height: 64

            radius: 8

            anchors {
                top: parent.top
                topMargin: 10
                horizontalCenter: parent.horizontalCenter
            }

            color: Colors.base

            clip: true

            Image {
                id: artwork

                anchors.fill: parent

                source: root.activePlayer ? root.activePlayer.trackArtUrl : ""

                fillMode: Image.PreserveAspectCrop

                asynchronous: true
                cache: true

                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent

                text: "󰝚"

                color: Colors.subtext

                font.pixelSize: 26

                visible: artwork.status !== Image.Ready
            }
        }

        // ========================================================
        // PLAYER NAME
        // ========================================================

        Text {
            id: playerName

            anchors {
                top: artworkContainer.bottom
                topMargin: 6

                left: parent.left
                right: parent.right

                leftMargin: 7
                rightMargin: 7
            }

            text: root.activePlayer ? root.activePlayer.identity : "Music Player"

            color: Colors.subtext

            font.family: Typography.ui
            font.pixelSize: Typography.xs

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight
        }

        // ========================================================
        // TITLE
        // ========================================================

        Text {
            id: title

            anchors {
                top: playerName.bottom
                topMargin: 2

                left: parent.left
                right: parent.right

                leftMargin: 7
                rightMargin: 7
            }

            text: root.activePlayer && root.activePlayer.trackTitle ? root.activePlayer.trackTitle : "Nothing playing"

            color: Colors.text

            font.family: Typography.ui
            font.pixelSize: Typography.sm
            font.bold: true

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight
        }

        // ========================================================
        // ARTIST
        // ========================================================

        Text {
            id: artist

            anchors {
                top: title.bottom
                topMargin: 2

                left: parent.left
                right: parent.right

                leftMargin: 7
                rightMargin: 7
            }

            text: root.activePlayer && root.activePlayer.trackArtist ? root.activePlayer.trackArtist : "Unknown Artist"

            color: Colors.subtext

            font.family: Typography.ui
            font.pixelSize: Typography.xs

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight
        }

        // ========================================================
        // ALBUM
        // ========================================================

        Text {
            id: album

            anchors {
                top: artist.bottom
                topMargin: 2

                left: parent.left
                right: parent.right

                leftMargin: 7
                rightMargin: 7
            }

            text: root.activePlayer && root.activePlayer.trackAlbum ? root.activePlayer.trackAlbum : ""

            color: Colors.subtext

            opacity: 0.8

            font.family: Typography.ui
            font.pixelSize: Typography.xs

            horizontalAlignment: Text.AlignHCenter

            elide: Text.ElideRight

            visible: text.length > 0
        }

        // ========================================================
        // PROGRESS SLIDER
        // ========================================================

        Item {
            id: progressSlider

            anchors {
                left: parent.left
                right: parent.right

                leftMargin: 9
                rightMargin: 9

                bottom: timeLabels.top
                bottomMargin: 3
            }

            height: 16

            // ====================================================
            // TRACK
            // ====================================================

            Rectangle {
                id: progressTrack

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                height: 5

                radius: 3

                color: Colors.base

                // =================================================
                // PROGRESS
                // =================================================

                Rectangle {
                    id: progressFill

                    width: root.trackLength > 0 ? progressTrack.width * Math.max(0, Math.min(1, root.displayPosition / root.trackLength)) : 0

                    height: parent.height

                    radius: 3

                    color: Colors.accent

                    Behavior on width {
                        enabled: !progressMouseArea.pressed

                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.Linear
                        }
                    }
                }

                // =================================================
                // HANDLE
                // =================================================

                Rectangle {
                    id: progressHandle

                    width: 10
                    height: 10

                    radius: 5

                    anchors.verticalCenter: parent.verticalCenter

                    x: Math.max(-1, Math.min(parent.width - width + 1, progressFill.width - width / 2))

                    color: Colors.accent

                    visible: root.activePlayer !== null

                    Behavior on x {
                        enabled: !progressMouseArea.pressed

                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            // ====================================================
            // DRAG AREA
            // ====================================================

            MouseArea {
                id: progressMouseArea

                anchors.fill: parent

                hoverEnabled: true

                /*
                 * Also requires the player to report a position at
                 * all -- canSeek alone is not enough to place the
                 * handle, and dragging a bar that cannot move is
                 * worse than not offering the drag.
                 */
                enabled: root.seekable

                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                function positionFromMouse(mouseX) {
                    if (root.trackLength <= 0)
                        return 0;

                    const ratio = Math.max(0, Math.min(1, mouseX / progressTrack.width));

                    return root.trackLength * ratio;
                }

                // ------------------------------------------------
                // START
                // ------------------------------------------------

                onPressed: function (mouse) {
                    root.displayPosition = positionFromMouse(mouse.x);
                }

                // ------------------------------------------------
                // DRAG
                // ------------------------------------------------

                onPositionChanged: function (mouse) {
                    if (!pressed)
                        return;

                    // ONLY update the UI.
                    //
                    // Absolutely do NOT change
                    // activePlayer.position here.
                    root.displayPosition = positionFromMouse(mouse.x);
                }

                // ------------------------------------------------
                // RELEASE
                // ------------------------------------------------

                onReleased: function (mouse) {
                    if (!root.activePlayer)
                        return;

                    const finalPosition = positionFromMouse(mouse.x);

                    root.displayPosition = finalPosition;

                    // Only seek once.
                    root.activePlayer.position = finalPosition;
                }

                /*
                 * Drag aborted rather than released -- no seek was
                 * issued, so put the handle back where the player
                 * actually is.
                 */
                onCanceled: {
                    root.syncPosition();
                }
            }
        }

        // ========================================================
        // TIME LABELS
        // ========================================================

        Row {
            id: timeLabels

            anchors {
                left: parent.left
                right: parent.right

                bottom: controls.top
                bottomMargin: 2

                leftMargin: 9
                rightMargin: 9
            }

            Text {
                id: currentTime

                text: root.activePlayer ? root.formatTime(root.displayPosition) : "0:00"

                color: Colors.subtext

                font.family: Typography.mono
                font.pixelSize: Typography.xs
            }

            Item {
                width: parent.width - currentTime.width - totalTime.width

                height: 1
            }

            Text {
                id: totalTime

                text: root.activePlayer ? root.formatTime(root.trackLength) : "0:00"

                color: Colors.subtext

                font.family: Typography.mono
                font.pixelSize: Typography.xs
            }
        }

        // ========================================================
        // CONTROLS
        // ========================================================

        Row {
            id: controls

            anchors {
                bottom: parent.bottom
                bottomMargin: 7

                horizontalCenter: parent.horizontalCenter
            }

            spacing: 2

            // ====================================================
            // PREVIOUS
            // ====================================================

            Rectangle {
                width: 24
                height: 24

                radius: 6

                color: previousMouse.containsMouse ? Colors.base : "transparent"

                opacity: root.activePlayer && root.activePlayer.canGoPrevious ? 1 : 0.4

                Text {
                    anchors.centerIn: parent

                    text: "󰒮"

                    color: Colors.text

                    font.pixelSize: 14
                }

                MouseArea {
                    id: previousMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    enabled: root.activePlayer && root.activePlayer.canGoPrevious

                    onClicked: {
                        root.activePlayer.previous();
                    }
                }
            }

            // ====================================================
            // PLAY / PAUSE
            // ====================================================

            Rectangle {
                width: 28
                height: 24

                radius: 6

                color: playMouse.containsMouse ? Colors.base : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"

                    color: Colors.text

                    font.pixelSize: 15
                }

                MouseArea {
                    id: playMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    enabled: root.activePlayer && root.activePlayer.canTogglePlaying

                    onClicked: {
                        root.activePlayer.togglePlaying();
                    }
                }
            }

            // ====================================================
            // NEXT
            // ====================================================

            Rectangle {
                width: 24
                height: 24

                radius: 6

                color: nextMouse.containsMouse ? Colors.base : "transparent"

                opacity: root.activePlayer && root.activePlayer.canGoNext ? 1 : 0.4

                Text {
                    anchors.centerIn: parent

                    text: "󰒭"

                    color: Colors.text

                    font.pixelSize: 14
                }

                MouseArea {
                    id: nextMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    enabled: root.activePlayer && root.activePlayer.canGoNext

                    onClicked: {
                        root.activePlayer.next();
                    }
                }
            }
        }

        // ========================================================
        // EMPTY STATE
        // ========================================================

        Rectangle {
            anchors.fill: parent

            radius: 10

            color: Colors.surface

            visible: !root.hasPlayer

            Column {
                anchors.centerIn: parent

                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: "󰝚"

                    color: Colors.subtext

                    font.pixelSize: 28
                }

                Text {
                    text: "Nothing playing"

                    color: Colors.subtext

                    font.family: Typography.ui
                    font.pixelSize: Typography.xs
                }
            }
        }
    }
}
