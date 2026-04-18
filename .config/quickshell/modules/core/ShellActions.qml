pragma Singleton

import QtQuick

QtObject {
    readonly property var actionItems: [
        { type: "action", id: "wallpapers", name: "Pick Wallpaper", subtitle: "Open the wallpaper browser", keywords: "background theme" },
        { type: "action", id: "emoji", name: "Emoji Picker", subtitle: "Switch the launcher into emoji mode", keywords: "emoji symbols smile" },
        { type: "action", id: "audio", name: "Audio Controls", subtitle: "Open the audio control panel", keywords: "volume mute sound" },
        { type: "action", id: "network", name: "Network Controls", subtitle: "Open the network control panel", keywords: "wifi ethernet internet" },
        { type: "action", id: "power", name: "Power Controls", subtitle: "Open the power control panel", keywords: "battery brightness suspend" },
        { type: "action", id: "clipboard", name: "Clipboard History", subtitle: "Open clipse in a terminal", keywords: "copy paste history" },
        { type: "action", id: "files", name: "File Manager", subtitle: "Open Thunar", keywords: "files browse folder" },
        { type: "action", id: "audio-settings", name: "Volume Mixer", subtitle: "Open pavucontrol", keywords: "pavucontrol audio mixer" },
        { type: "action", id: "network-settings", name: "Network Settings", subtitle: "Open NetworkManager editor", keywords: "nmcli wifi settings" },
        { type: "action", id: "lock", name: "Lock Screen", subtitle: "Lock the current session", keywords: "session secure" },
        { type: "action", id: "power-menu", name: "Power Menu", subtitle: "Open lock, suspend, reboot, shutdown", keywords: "power menu suspend reboot shutdown" },
        { type: "action", id: "reload", name: "Reload Shell", subtitle: "Restart Quickshell", keywords: "quickshell restart refresh" }
    ]

    function activate(entry, context) {
        if (!entry || entry.type !== "action")
            return

        var close = context && context.close ? context.close : function() {}
        var dispatch = context && context.dispatch ? context.dispatch : function() {}
        var setMode = context && context.setMode ? context.setMode : function() {}
        var wallpaperSelector = context && context.wallpaperSelector ? context.wallpaperSelector : null
        var notifier = context && context.notifier ? context.notifier : null

        switch (entry.id) {
        case "wallpapers":
            if (wallpaperSelector)
                wallpaperSelector.toggle()
            close()
            break
        case "emoji":
            setMode("emoji")
            if (notifier)
                notifier.showOsd("Emoji mode")
            break
        case "audio":
            dispatch("exec qs -p ~/.config/quickshell ipc call shell openPanel audio")
            close()
            break
        case "network":
            dispatch("exec qs -p ~/.config/quickshell ipc call shell openPanel network")
            close()
            break
        case "power":
            dispatch("exec qs -p ~/.config/quickshell ipc call shell openPanel power")
            close()
            break
        case "clipboard":
            dispatch("exec kitty --class clipse -e clipse")
            close()
            break
        case "files":
            dispatch("exec thunar")
            close()
            break
        case "audio-settings":
            dispatch("exec pavucontrol")
            close()
            break
        case "network-settings":
            dispatch("exec nm-connection-editor")
            close()
            break
        case "lock":
            dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction lock")
            close()
            break
        case "power-menu":
            dispatch("exec qs -p ~/.config/quickshell ipc call shell togglePowerMenu")
            close()
            break
        case "reload":
            dispatch("exec killall qs; qs -p ~/.config/quickshell --daemonize")
            close()
            break
        }
    }
}