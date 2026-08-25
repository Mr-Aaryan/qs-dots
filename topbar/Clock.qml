import QtQuick
import "../theme"

Text {
    id: root

    /*
     * 12-hour, no leading zero: "4:48 PM".
     *
     * `h` drops the leading zero and switches to 12-hour because of
     * the `AP` that follows it.
     */
    property string format: "h:mm AP"

    signal clicked

    color: Colors.text

    font.family: Typography.ui
    font.pixelSize: Typography.lg

    function updateTime() {
        text = Qt.formatTime(new Date(), root.format);
    }

    Component.onCompleted: {
        updateTime();
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            root.updateTime();
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.clicked();
        }
    }
}
