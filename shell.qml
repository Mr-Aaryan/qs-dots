//@ pragma UseQApplication

/*
 * QApplication mode, rather than the lighter QGuiApplication default.
 *
 * Platform menus need it, and the tray is what wants one: right
 * clicking a SysTray icon opens the application's own DBusMenu
 * through QsMenuAnchor. Without this pragma that call fails outright
 * with "quickshell was not started in QApplication mode", which is
 * why right clicking a tray icon appeared to do nothing at all.
 *
 * Has to live in the root QML file, above the imports.
 */

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
