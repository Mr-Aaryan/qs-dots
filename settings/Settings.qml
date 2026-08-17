pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ============================================================
    // SETTINGS
    // ============================================================

    property string userName: "Mr-Aaryan"
    property string profileImage: ""

    readonly property string settingsFile:
        Quickshell.env("HOME") +
        "/.config/quickshell/settings.json"

    // ============================================================
    // FILE
    // ============================================================

    property FileView fileView: FileView {
        path: root.settingsFile

        watchChanges: true

        JsonAdapter {
            property string userName: "Mr-Aaryan"
            property string profileImage: ""
        }

        onLoaded: {
            root.userName = adapter.userName
            root.profileImage = adapter.profileImage

            console.log("Settings loaded")
            console.log("Username:", root.userName)
            console.log("Profile:", root.profileImage)
        }
    }

    // ============================================================
    // SAVE
    // ============================================================

    function save() {
        fileView.adapter.userName = root.userName
        fileView.adapter.profileImage = root.profileImage

        fileView.writeAdapter()
    }

    // ============================================================
    // LOAD
    // ============================================================

    function load() {
        fileView.reload()
    }

    Component.onCompleted: {
        load()
    }
}