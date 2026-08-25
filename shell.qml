import QtQuick
import Quickshell
import "./topbar"
import "./osd"
import "./launcher"
import "./session"

ShellRoot {
    id: root

    TopBar {}

    Osd {}

    NotificationToast {}

    AppLauncher {}

    PowerMenu {}
}
