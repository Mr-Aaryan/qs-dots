import QtQuick
import "../theme"

Text {
    id: root

    property string format: "HH:mm"

    signal clicked

    color: Colors.text

    font.family: Typography.firaCode
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
