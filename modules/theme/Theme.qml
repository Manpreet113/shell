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
    function apply(dark) {
        if (!dark) return
        if (dark.surface)             surface          = dark.surface
        if (dark.surface_variant)     surfaceVariant   = dark.surface_variant
        if (dark.surface_container)   surfaceContainer = dark.surface_container
        if (dark.on_surface)          fg               = dark.on_surface
        if (dark.on_surface_variant)  fgMuted          = dark.on_surface_variant
        if (dark.outline)             outline          = dark.outline
        if (dark.primary)             primary          = dark.primary
        if (dark.on_primary)          primaryFg        = dark.on_primary
        if (dark.primary_container)   primaryContainer = dark.primary_container
    }
}
