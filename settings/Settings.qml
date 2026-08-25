pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io as Io

Io.FileView {
    id: root

    property string userName: "Mr-Aaryan"
    property string profileImage: ""

    /*
     * Do Not Disturb, toggled from the control center. Lives here
     * so the notification icon can reflect it too.
     */
    property bool dnd: false

    readonly property string settingsFile: Quickshell.env("HOME") + "/.config/quickshell/settings.json"

    path: root.settingsFile

    watchChanges: true

    onLoaded: {
        const settings = JSON.parse(root.text());
        root.userName = settings.userName ?? root.userName;
        root.profileImage = settings.profileImage ?? root.profileImage;
        root.dnd = settings.dnd ?? root.dnd;

        console.log("Settings loaded");
        console.log("Username:", root.userName);
        console.log("Profile:", root.profileImage);
    }

    onFileChanged: root.reload()

    function save() {
        root.setText(JSON.stringify({
            userName: root.userName,
            profileImage: root.profileImage,
            dnd: root.dnd
        }, null, 4));
    }

    function load() {
        root.reload();
    }

    Component.onCompleted: {
        load();
    }
}
