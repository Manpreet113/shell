pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "modules/theme"
import "modules/bar"
import "modules/launcher"
import "modules/system"
import "modules/core"

ShellRoot {
    id: root

    ThemeLoader {}
    
    property string configPath: ""

    Process {
        command: ["sh", "-c", "realpath .config/quickshell"]
        stdout: SplitParser {
            onRead: data => { 
                root.configPath = data.trim()
                console.log("[Shell] Absolute Config Path:", root.configPath)
            }
        }
        running: true
    }

    // ─── Bar — spawned once per connected monitor ────────────────────
    Variants {
        model: Quickshell.screens
        Bar {
            screen: modelData
            controlCenter: controlCenter
            dashboard: dashboard
            notifier: notifications
            configPath: root.configPath
        }
    }

    Dashboard {
        id: dashboard
        notifier: notifications
    }

    ControlCenter {
        id: controlCenter
        notifier: notifications
        powerMenu: powerMenu
        configPath: root.configPath
    }

    PowerMenu {
        id: powerMenu
        notifier: notifications
    }

    ScreenCapture {
        id: screenCapture
        configPath: root.configPath
    }

    NotificationOverlay {
        id: notifications
    }

    OSDService {
        notifications: notifications
    }

    WallpaperSelector { id: wallpaperSelector }

    Launcher {
        id: launcher
        notifier: notifications
        wallpaperSelector: wallpaperSelector
    }

    ShellCommands {
        id: shellCommands
        launcher: launcher
        wallpaperSelector: wallpaperSelector
        controlCenter: controlCenter
        dashboard: dashboard
        powerMenu: powerMenu
        screenCapture: screenCapture
        notifications: notifications
    }

    IpcHandler {
        target: "shell"
        function toggleLauncher(): void {
            shellCommands.toggleLauncher()
        }

        function toggleWallpaperSelector(): void {
            shellCommands.toggleWallpaperSelector()
        }

        function openPanel(kind: string): void {
            shellCommands.openPanel(kind)
        }

        function toggleDashboard(): void {
            shellCommands.toggleDashboard()
        }

        function togglePowerMenu(): void {
            shellCommands.togglePowerMenu()
        }

        function powerAction(action: string): void {
            shellCommands.powerAction(action)
        }

        function showNotification(title: string, body: string): void {
            shellCommands.showNotification(title, body)
        }

        function showOsd(text: string): void {
            shellCommands.showOsd(text)
        }

        function toggleScreenCapture(): void {
            shellCommands.toggleScreenCapture()
        }
    }
}
