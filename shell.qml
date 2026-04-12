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
    // Used to locate ~/.config/shell/colors.json
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
    FileView {
        id: colorFile
        path: root.homeDir ? root.homeDir + "/.config/shell/colors.json" : ""
        onTextChanged: {
            if (!text || text.length < 2) return
            try {
                var data = JSON.parse(text)
                Theme.apply(data.colors.dark)
            } catch (e) {
                console.warn("[shell] Failed to parse colors.json:", e)
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
    Launcher { id: launcher }

    // ─── IPC handler ─────────────────────────────────────────────────
    // Hyprland keybind calls: qs ipc call shell toggleLauncher
    IpcHandler {
        target: "shell"
        function toggleLauncher(): void {
            launcher.toggle()
        }
    }
}
