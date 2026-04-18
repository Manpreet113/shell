// shell.qml — Entry point for the Hyprland shell
// Run with: qs -p ~/dev/shell/shell.qml
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "modules/theme"
import "modules/bar"
import "modules/launcher"
import "modules/system"

ShellRoot {
    id: root

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
        onFileChanged: root.reloadColors()
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

    function reloadColors() {
        if (catProcess.running)
            return

        catProcess.rawJson = ""
        catProcess.running = true
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
            controlCenter: controlCenter
            notifier: notifications
        }
    }

    ControlCenter {
        id: controlCenter
        notifier: notifications
        powerMenu: powerMenu
    }

    PowerMenu {
        id: powerMenu
        notifier: notifications
    }

    NotificationOverlay {
        id: notifications
    }

    // ─── Application launcher ────────────────────────────────────────
    // Single instance, toggled via IPC or Super+Space keybind
    WallpaperSelector { id: wallpaperSelector }

    // ─── Application launcher ────────────────────────────────────────
    // Single instance, toggled via IPC or Super+Space keybind
    Launcher {
        id: launcher
        notifier: notifications
        wallpaperSelector: wallpaperSelector
    }


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

        function openPanel(kind: string): void {
            var label = ""
            if (kind === "audio")
                label = "Audio controls"
            else if (kind === "network")
                label = "Network controls"
            else if (kind === "power")
                label = "Power controls"
            else
                label = "System controls"
            controlCenter.toggle(kind, label)
        }

        function togglePowerMenu(): void {
            powerMenu.toggle()
        }

        function powerAction(action: string): void {
            if (action === "lock") {
                notifications.showOsd("Locking")
                controlCenter.closePanel()
                powerMenu.closeMenu()
                powerActionProc.command = ["sh", "-c", "pidof hyprlock >/dev/null || hyprlock"]
                powerActionProc.running = true
            } else if (action === "suspend") {
                notifications.notify("Power", "Suspending system")
                controlCenter.closePanel()
                powerMenu.closeMenu()
                powerActionProc.command = ["sh", "-c", "systemctl suspend"]
                powerActionProc.running = true
            } else if (action === "logout") {
                notifications.notify("Session", "Logging out")
                controlCenter.closePanel()
                powerMenu.closeMenu()
                powerActionProc.command = ["sh", "-c", "loginctl terminate-user \"$USER\""]
                powerActionProc.running = true
            } else if (action === "reboot") {
                notifications.notify("Power", "Rebooting system")
                controlCenter.closePanel()
                powerMenu.closeMenu()
                powerActionProc.command = ["sh", "-c", "systemctl reboot"]
                powerActionProc.running = true
            } else if (action === "shutdown") {
                notifications.notify("Power", "Shutting down system")
                controlCenter.closePanel()
                powerMenu.closeMenu()
                powerActionProc.command = ["sh", "-c", "systemctl poweroff"]
                powerActionProc.running = true
            }
        }

        function showNotification(title: string, body: string): void {
            notifications.notify(title, body)
        }

        function showOsd(text: string): void {
            notifications.showOsd(text)
        }
    }

    Process {
        id: powerActionProc
    }

    Timer {
        id: startupTimer
        interval: 200
        repeat: false
        onTriggered: root.reloadColors()
    }

    Component.onCompleted: startupTimer.start()
}
