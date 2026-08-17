pragma Singleton
import QtQuick

Item {
    FontLoader {
        id: firacode
        source: "../assets/fonts/FiraCodeNerdFontMono-Regular.ttf"
    }

    readonly property string firaCode: firacode.name

    // Sizes
    readonly property int xs: 10
    readonly property int sm: 12
    readonly property int md: 14
    readonly property int lg: 16
    readonly property int xl: 20
    readonly property int xxl: 28

    // Weights
    readonly property int light: Font.Light
    readonly property int normal: Font.Normal
    readonly property int medium: Font.Medium
    readonly property int demiBold: Font.DemiBold
    readonly property int bold: Font.Bold
}
