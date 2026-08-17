import QtQuick
import "../../theme"

Text {
    id: root

    color: Colors.text

    font.family: Typography.firaCode
    font.pixelSize: Typography.md
    font.weight: Typography.normal

    renderType: Text.NativeRendering
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
