import QtQuick
import Quickshell
import "./topbar"
import "./osd"
import "./launcher"

ShellRoot {
    id: root

    TopBar {}

    Osd {}

    NotificationToast {}

    AppLauncher {}
}
