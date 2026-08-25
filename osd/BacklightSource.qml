import QtQuick
import Quickshell.Io

/*
 * Watches a sysfs backlight-style directory — anything exposing
 * `brightness` and `max_brightness`, which covers both
 * /sys/class/backlight and /sys/class/leds devices.
 *
 * The file notifies on change, so this reacts no matter what did
 * the changing — keybind, GUI or the kernel itself. No polling.
 */
Item {
    id: source

    // ============================================================
    // PUBLIC API
    // ============================================================

    /*
     * Directory holding the brightness files, without a
     * trailing slash.
     */
    property string path: ""

    /*
     * Emitted whenever the brightness changes, as a 0..1
     * fraction of the device maximum.
     */
    signal updated(real fraction)

    // ============================================================
    // MAXIMUM
    //
    // Read blocking so the maximum is always known before the
    // first brightness value is turned into a fraction.
    // ============================================================

    property int maxValue: 1

    FileView {
        id: maxFile

        path: source.path + "/max_brightness"

        blockLoading: true

        onLoaded: {
            const parsed = Number(maxFile.text().trim());

            if (parsed > 0)
                source.maxValue = parsed;
        }
    }

    // ============================================================
    // CURRENT VALUE
    // ============================================================

    FileView {
        id: valueFile

        path: source.path + "/brightness"

        watchChanges: true

        onFileChanged: {
            valueFile.reload();
        }

        onLoaded: {
            const raw = Number(valueFile.text().trim());

            if (!isNaN(raw))
                source.updated(raw / source.maxValue);
        }
    }
}
