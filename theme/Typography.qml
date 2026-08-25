pragma Singleton

import QtQuick

/*
 * Two families, deliberately split by job.
 *
 * Everything in the shell used to render in FiraCode Nerd Font
 * *Mono*. That is a code font: every glyph is padded out to the same
 * cell, which is what makes a notification body at 10px hard to
 * read — the words lose their shape and the lines run together.
 *
 * So `ui` is a proportional face for anything read as words, and
 * `mono` stays for Nerd Font glyphs and for figures that must not
 * jitter as they count.
 */
Item {
    id: root

    FontLoader {
        id: firacode

        source: "../assets/fonts/FiraCodeNerdFontMono-Regular.ttf"
    }

    // ============================================================
    // FAMILIES
    // ============================================================

    /*
     * Adwaita Sans is a fork of Inter: tall x-height, open
     * apertures, and spacing drawn for small sizes on screen, which
     * is exactly the range this shell renders in.
     *
     * Resolved against the fonts actually installed rather than
     * named outright, so the shell still comes up on a machine that
     * does not have it.
     */
    readonly property string ui: root.pickFamily(["Adwaita Sans", "Inter", "Inter Display", "Noto Sans", "Liberation Sans", "DejaVu Sans"])

    // Nerd Font glyphs, and digits that would otherwise reflow.
    readonly property string mono: firacode.name

    function pickFamily(candidates) {
        const installed = Qt.fontFamilies();

        for (let i = 0; i < candidates.length; i++) {
            if (installed.indexOf(candidates[i]) !== -1)
                return candidates[i];
        }

        return "sans-serif";
    }

    // ============================================================
    // SIZES
    //
    // Nudged up one step across the board. The old scale bottomed
    // out at 10px, which only ever worked because nothing on it was
    // meant to be read at a glance.
    // ============================================================

    readonly property int xs: 12
    readonly property int sm: 13
    readonly property int md: 15
    readonly property int lg: 17
    readonly property int xl: 21
    readonly property int xxl: 30

    // ============================================================
    // WEIGHTS
    // ============================================================

    readonly property int light: Font.Light
    readonly property int normal: Font.Normal

    /*
     * Body copy sits at Medium rather than Normal: light-on-dark
     * text renders optically thinner than the same weight dark-on-
     * light, and Medium buys the strokes back without reading as
     * emphasis.
     */
    readonly property int medium: Font.Medium

    readonly property int demiBold: Font.DemiBold
    readonly property int bold: Font.Bold
}
