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

    property var activePlayer: {
        const players = Mpris.players.values;

        if (players.length === 0)
            return null;

        const playing = players.find(p => p.isPlaying);

        return playing || players[0];
    }

    property bool hasPlayer: activePlayer !== null

    // ============================================================
    // TRACK STATE
    // ============================================================

    property real displayPosition: 0

    // IMPORTANT:
    // This is the duration shown by our UI.
    // We intentionally do NOT continuously trust MPRIS length.
    property real trackLength: 0

    // Used to detect an actual track change.
    property string trackId: ""

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

    function currentTrackId() {
        if (!root.activePlayer)
            return "";

        return String(
            root.activePlayer.trackTitle || ""
        ) + "|" + String(
            root.activePlayer.trackArtist || ""
        ) + "|" + String(
            root.activePlayer.trackAlbum || ""
        );
    }

    function updateTrackState() {
        if (!root.activePlayer)
            return;

        const newId = root.currentTrackId();

        // --------------------------------------------------------
        // New track
        // --------------------------------------------------------

        if (newId !== root.trackId) {
            root.trackId = newId;

            const newLength =
                Number(root.activePlayer.length);

            if (isFinite(newLength) && newLength > 0)
                root.trackLength = newLength;

            const newPosition =
                Number(root.activePlayer.position);

            if (isFinite(newPosition) && newPosition >= 0)
                root.displayPosition = newPosition;

            return;
        }

        // --------------------------------------------------------
        // Same track
        //
        // DO NOT update trackLength here.
        //
        // Some MPRIS players, especially browser/media players,
        // can temporarily report a different length after seeking.
        // --------------------------------------------------------

        if (!progressMouseArea.pressed) {
            const position =
                Number(root.activePlayer.position);

            if (isFinite(position) && position >= 0)
                root.displayPosition = position;
        }
    }

    // ============================================================
    // INITIAL PLAYER
    // ============================================================

    onActivePlayerChanged: {
        root.trackId = "";

        if (!root.activePlayer) {
            root.trackLength = 0;
            root.displayPosition = 0;
            return;
        }

        root.updateTrackState();
    }

    // ============================================================
    // POSITION SYNC
    // ============================================================

    Timer {
        interval: 100
        running: root.activePlayer !== null
        repeat: true

        onTriggered: {
            root.updateTrackState();
        }
    }

    // ============================================================
    // MPRIS
    // ============================================================

    Connections {
        target: root.activePlayer

        function onPositionChanged() {
            if (!progressMouseArea.pressed) {
                const position =
                    Number(root.activePlayer.position);

                if (isFinite(position) && position >= 0)
                    root.displayPosition = position;
            }
        }

        function onTrackChanged() {
            root.trackId = "";

            Qt.callLater(function() {
                root.updateTrackState();
            });
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

                source: root.activePlayer
                        ? root.activePlayer.trackArtUrl
                        : ""

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

            text: root.activePlayer
                  ? root.activePlayer.identity
                  : "Music Player"

            color: Colors.subtext

            font.family: Typography.firaCode
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

            text: root.activePlayer &&
                  root.activePlayer.trackTitle
                  ? root.activePlayer.trackTitle
                  : "Nothing playing"

            color: Colors.text

            font.family: Typography.firaCode
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

            text: root.activePlayer &&
                  root.activePlayer.trackArtist
                  ? root.activePlayer.trackArtist
                  : "Unknown Artist"

            color: Colors.subtext

            font.family: Typography.firaCode
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

            text: root.activePlayer &&
                  root.activePlayer.trackAlbum
                  ? root.activePlayer.trackAlbum
                  : ""

            color: Colors.subtext

            opacity: 0.8

            font.family: Typography.firaCode
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

                    width: root.trackLength > 0
                           ? progressTrack.width *
                             Math.max(
                                 0,
                                 Math.min(
                                     1,
                                     root.displayPosition /
                                     root.trackLength
                                 )
                             )
                           : 0

                    height: parent.height

                    radius: 3

                    color: Colors.blue

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

                    x: Math.max(
                        -1,
                        Math.min(
                            parent.width - width + 1,
                            progressFill.width - width / 2
                        )
                    )

                    color: Colors.blue

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

                enabled: root.activePlayer &&
                         root.activePlayer.canSeek &&
                         root.trackLength > 0

                cursorShape: enabled
                             ? Qt.PointingHandCursor
                             : Qt.ArrowCursor

                function positionFromMouse(mouseX) {
                    if (root.trackLength <= 0)
                        return 0;

                    const ratio = Math.max(
                        0,
                        Math.min(
                            1,
                            mouseX / progressTrack.width
                        )
                    );

                    return root.trackLength * ratio;
                }

                // ------------------------------------------------
                // START
                // ------------------------------------------------

                onPressed: function(mouse) {
                    root.displayPosition =
                        positionFromMouse(mouse.x);
                }

                // ------------------------------------------------
                // DRAG
                // ------------------------------------------------

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return;

                    // ONLY update the UI.
                    //
                    // Absolutely do NOT change
                    // activePlayer.position here.
                    root.displayPosition =
                        positionFromMouse(mouse.x);
                }

                // ------------------------------------------------
                // RELEASE
                // ------------------------------------------------

                onReleased: function(mouse) {
                    if (!root.activePlayer)
                        return;

                    const finalPosition =
                        positionFromMouse(mouse.x);

                    root.displayPosition =
                        finalPosition;

                    // Only seek once.
                    root.activePlayer.position =
                        finalPosition;
                }

                onCanceled: {
                    root.updateTrackState();
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

                text: root.activePlayer
                      ? root.formatTime(root.displayPosition)
                      : "0:00"

                color: Colors.subtext

                font.family: Typography.firaCode
                font.pixelSize: 8
            }

            Item {
                width: parent.width -
                       currentTime.width -
                       totalTime.width

                height: 1
            }

            Text {
                id: totalTime

                text: root.activePlayer
                      ? root.formatTime(root.trackLength)
                      : "0:00"

                color: Colors.subtext

                font.family: Typography.firaCode
                font.pixelSize: 8
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

                color: previousMouse.containsMouse
                       ? Colors.base
                       : "transparent"

                opacity: root.activePlayer &&
                         root.activePlayer.canGoPrevious
                         ? 1
                         : 0.4

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

                    enabled: root.activePlayer &&
                             root.activePlayer.canGoPrevious

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

                color: playMouse.containsMouse
                       ? Colors.base
                       : "transparent"

                Text {
                    anchors.centerIn: parent

                    text: root.activePlayer &&
                          root.activePlayer.isPlaying
                          ? "󰏤"
                          : "󰐊"

                    color: Colors.text

                    font.pixelSize: 15
                }

                MouseArea {
                    id: playMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    cursorShape: Qt.PointingHandCursor

                    enabled: root.activePlayer &&
                             root.activePlayer.canTogglePlaying

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

                color: nextMouse.containsMouse
                       ? Colors.base
                       : "transparent"

                opacity: root.activePlayer &&
                         root.activePlayer.canGoNext
                         ? 1
                         : 0.4

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

                    enabled: root.activePlayer &&
                             root.activePlayer.canGoNext

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

                    font.family: Typography.firaCode
                    font.pixelSize: Typography.xs
                }
            }
        }
    }
}