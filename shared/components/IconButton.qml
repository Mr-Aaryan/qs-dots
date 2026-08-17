import QtQuick

Rectangle {
    id: root

    property string iconText
    property color iconColor
    property color bgColor: "transparent"
    property int iconHeight: 24
    property int iconWidth: 24

    signal clicked

    height: iconHeight
    width: iconWidth
    color: bgColor

    Text {
        text: root.iconText
        color: root.iconColor
        anchors.centerIn: parent
        font.pixelSize: 14
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }
}
