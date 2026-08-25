pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../settings"

/*
 * The single notification server for the whole shell.
 *
 * Only one process can own org.freedesktop.Notifications, and within
 * the shell only one NotificationServer may exist — so both the
 * notification center (history) and the on-screen toasts read from
 * here rather than each declaring their own.
 *
 * This replaces swaync.
 */
Item {
    id: root

    // ============================================================
    // STORE
    // ============================================================

    /*
     * Full history, newest first. Entries are
     * { notification, timestamp }.
     *
     * Kept as a plain array that is reassigned wholesale, because
     * that is what makes QML bindings update reliably.
     */
    property var notifications: []

    /*
     * Currently visible toasts, newest first. Entries are
     * { entry, expiresAt }, where expiresAt of 0 means "stays until
     * dismissed".
     */
    property var popups: []

    property int popupLimit: 4

    property int defaultTimeout: 5000

    // ============================================================
    // SERVER
    // ============================================================

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: false

        imageSupported: true
        actionsSupported: true

        onNotification: function (notification) {
            notification.tracked = true;

            const entry = {
                notification: notification,
                timestamp: new Date()
            };

            root.notifications = [entry, ...root.notifications];

            /*
             * Do Not Disturb silences the toast but still files the
             * notification, so nothing is lost.
             */
            if (!Settings.dnd)
                root.showPopup(entry);
        }
    }

    // ============================================================
    // TOASTS
    // ============================================================

    function showPopup(entry) {
        const notification = entry.notification;

        /*
         * Critical notifications are not dismissed on a timer —
         * they wait for the user.
         */
        const permanent = notification.urgency === NotificationUrgency.Critical;

        const timeout = notification.expireTimeout > 0 ? notification.expireTimeout : root.defaultTimeout;

        const popup = {
            entry: entry,
            expiresAt: permanent ? 0 : Date.now() + timeout
        };

        let next = [popup, ...root.popups];

        if (next.length > root.popupLimit)
            next = next.slice(0, root.popupLimit);

        root.popups = next;
    }

    /*
     * One shared ticker rather than a timer per toast.
     */
    Timer {
        interval: 250
        repeat: true

        running: root.popups.length > 0

        onTriggered: {
            const now = Date.now();

            /*
             * The notification check is not redundant with the clock:
             * an app can withdraw its own notification at any point,
             * which destroys the object and leaves this entry holding
             * a slot in the stack with nothing to draw in it.
             */
            const remaining = root.popups.filter(popup => popup.entry.notification && (popup.expiresAt === 0 || popup.expiresAt > now));

            if (remaining.length !== root.popups.length)
                root.popups = remaining;
        }
    }

    /*
     * Hides the toast but keeps the notification in the center.
     */
    function dismissPopup(popup) {
        if (!popup)
            return;
        root.popups = root.popups.filter(current => current !== popup);
    }

    function clearPopups() {
        root.popups = [];
    }

    // ============================================================
    // DISMISSAL
    // ============================================================

    function dismissNotification(entry) {
        if (!entry)
            return;
        entry.notification.dismiss();

        root.notifications = root.notifications.filter(current => current !== entry);

        root.popups = root.popups.filter(popup => popup.entry !== entry);
    }

    function clearAll() {
        const current = root.notifications;

        for (let i = 0; i < current.length; i++) {
            current[i].notification.dismiss();
        }

        root.notifications = [];
        root.popups = [];
    }

    // ============================================================
    // HELPERS
    // ============================================================

    /*
     * Notifications carry either an inline image or an icon name;
     * resolve whichever is present to something Image can load.
     */
    function iconFor(notification) {
        if (!notification)
            return "";
        if (notification.image !== "")
            return notification.image;

        if (notification.appIcon !== "")
            return Quickshell.iconPath(notification.appIcon, true);

        return "";
    }
}
