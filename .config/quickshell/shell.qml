// shell.qml — Entry point for the Hyprland shell
// Run with: qs -p ~/dev/shell/shell.qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "modules/theme"
import "modules/bar"
import "modules/launcher"

ShellRoot {
    id: root

    // ─── Home directory (read from $HOME at startup) ─────────────────
    // Used to locate COLORS_DIR="$HOME/.config/quickshell"
    // COLORS_FILE="$COLORS_DIR/colors.json"
    property string homeDir: ""

    Process {
        id: homeQuery
        command: ["sh", "-c", "echo \"$HOME\""]
        running: true
        stdout: SplitParser {
            onRead: data => root.homeDir = data.trim()
        }
    }

    // ─── Matugen color watcher ───────────────────────────────────────
    // When wallpaper.sh runs matugen and writes colors.json,
    // this FileView detects the change and pushes new colors into Theme.
    readonly property string colorFilePath: {
        var url = Qt.resolvedUrl("colors.json").toString()
        if (url.startsWith("file://")) return url.substring(7)
        return url
    }

    FileView {
        id: colorFile
        path: root.colorFilePath
        watchChanges: true
        onFileChanged: {
            catProcess.rawJson = ""
            catProcess.running = true
        }
    }

    Process {
        id: catProcess
        property string rawJson: ""
        command: ["cat", root.colorFilePath]
        stdout: SplitParser {
            onRead: data => catProcess.rawJson += data
        }
        onExited: {
            debounceTimer.data = rawJson
            debounceTimer.restart()
        }
    }

    Timer {
        id: debounceTimer
        property string data: ""
        interval: 10
        repeat: false
        onTriggered: {
            if (data.length < 10) return
            try {
                var json = JSON.parse(data)
                if (json.colors) {
                    Theme.apply(json)
                }
            } catch (e) {
                console.warn("[shell] JSON parse error: " + e)
            }
        }
    }

    // ─── Bar — spawned once per connected monitor ────────────────────
    Variants {
        model: Quickshell.screens
        Bar {
            screen: modelData
        }
    }

    // ─── Application launcher ────────────────────────────────────────
    // Single instance, toggled via IPC or Super+Space keybind
    WallpaperSelector { id: wallpaperSelector }

    // ─── Application launcher ────────────────────────────────────────
    // Single instance, toggled via IPC or Super+Space keybind
    Launcher { id: launcher }


    // ─── IPC handler ─────────────────────────────────────────────────
    // Hyprland keybind calls: qs ipc call shell toggleLauncher
    IpcHandler {
        target: "shell"
        function toggleLauncher(): void {
            launcher.toggle()
        }

        function toggleWallpaperSelector(): void {
            wallpaperSelector.toggle()
        }
    }

    Timer {
        id: startupTimer
        interval: 200
        repeat: false
        onTriggered: {
            catProcess.rawJson = ""
            catProcess.running = true
        }
    }

    Component.onCompleted: startupTimer.start()
}
