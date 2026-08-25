import QtQuick
import "../../theme"

Text {
    id: root

    color: Colors.text

    font.family: Typography.ui
    font.pixelSize: Typography.md
    font.weight: Typography.medium

    /*
     * Left on the default (QtRendering). NativeRendering snaps stems
     * to whole physical pixels, which on a fractionally scaled
     * Wayland output thins and smears small text instead of
     * sharpening it.
     */
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
