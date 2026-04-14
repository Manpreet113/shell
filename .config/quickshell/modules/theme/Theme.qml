// Theme.qml — Global color singleton
// Holds all design tokens. Colors are set at startup by shell.qml's
// FileView reading ~/.config/shell/colors.json (matugen output).
// The defaults below are a tasteful dark palette used before matugen runs.
pragma Singleton

import QtQuick

QtObject {
    id: theme

    // ─── Surface / Background ────────────────────────────────────────
    property color surface:             "#121212"   // bar & card background
    property color surfaceVariant:      "#1c1c1e"   // slightly elevated surface
    property color surfaceContainer:    "#2a2a2d"   // hover / selection bg

    // ─── Text ────────────────────────────────────────────────────────
    // NOTE: Names starting with "on" + uppercase are reserved by QML as signal
    // handlers, so we use fg/fgMuted/primaryFg instead of onSurface/onPrimary.
    property color fg:                  "#e2e2e2"   // primary text  (was onSurface)
    property color fgMuted:             "#9e9e9e"   // secondary text (was onSurfaceVariant)
    property color outline:             "#3a3a3a"   // borders, separators, dots

    // ─── Accent ──────────────────────────────────────────────────────
    property color primary:             "#c8b3fa"   // active workspace, highlights
    property color primaryFg:           "#1e0a38"   // text on primary bg (was onPrimary)
    property color primaryContainer:    "#2d1f50"   // subtle accent background

    // ─── Convenience ─────────────────────────────────────────────────
    // Fonts — change here to restyle the entire shell
    readonly property string monoFont: "JetBrains Mono, monospace"
    readonly property string uiFont:   "Inter, sans-serif"

    // ─── apply() — called by shell.qml when colors.json is updated ───
    // Accepts the `colors.dark` sub-object from matugen's JSON output.
    // Keys follow matugen's snake_case naming (e.g., on_surface_variant).
    function apply(data) {
        if (!data || !data.colors) {
            console.warn("[theme] ERROR: Received invalid data object")
            return
        }
        
        const colors = data.colors
        const mode = data.mode || "dark"
        console.warn("[theme] Applying theme update (mode: " + mode + ")")
        
        try {
            // Helper to safely extract and convert color
            const get = (key) => {
                if (colors[key] && colors[key][mode] && colors[key][mode].color) {
                    var c = colors[key][mode].color
                    return Qt.color(c)
                }
                return null
            }

            // Assign properties directly
            var c;
            if ((c = get("surface")))          surface = c
            if ((c = get("surface_variant")))  surfaceVariant = c
            if ((c = get("surface_container"))) surfaceContainer = c
            if ((c = get("on_surface")))       fg = c
            if ((c = get("on_surface_variant"))) fgMuted = c
            if ((c = get("outline")))          outline = c
            if ((c = get("primary")))          primary = c
            if ((c = get("on_primary")))       primaryFg = c
            if ((c = get("primary_container"))) primaryContainer = c
            
            console.warn("[theme] Theme update complete!")
        } catch (e) {
            console.warn("[theme] CRASH during apply: " + e)
        }
    }
}
