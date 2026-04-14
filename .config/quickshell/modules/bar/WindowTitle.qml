// WindowTitle.qml — Active window title display
// Shows the title of the currently focused window, truncated if too long.
//
// NOTE: Hyprland.focusedClient is available in Quickshell ≥ 0.2.
// If you get a "focusedClient is not defined" error, uncomment the
// event-based fallback block below and remove the property binding.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "../theme"

Text {
    id: root

    // ── Primary approach: direct property binding ─────────────────────
    // Hyprland.activeToplevel is the standard property in Quickshell 0.3+.
    text:  {
        var title = Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "~"
        return title.length > 44 ? title.slice(0, 42) + "…" : title
    }

    color:          Theme.fgMuted
    font.family:    Theme.monoFont
    font.pixelSize: 12
    elide:          Text.ElideRight

    // ── Fallback: event-based approach ───────────────────────────────
    // Uncomment this block and comment out the `text: {...}` above
    // if Hyprland.focusedClient is unavailable in your version.
    //
    // property string _title: "~"
    // text: _title
    //
    // Connections {
    //     target: Hyprland
    //     function onEvent(event) {
    //         // "activewindow" event data: "class,title"
    //         if (event.name === "activewindow") {
    //             var parts  = event.data.split(",")
    //             var title  = parts.length > 1 ? parts.slice(1).join(",") : "~"
    //             root._title = title.length > 44 ? title.slice(0, 42) + "…" : title
    //         }
    //         if (event.name === "closewindow") {
    //             root._title = "~"
    //         }
    //     }
    // }
}
