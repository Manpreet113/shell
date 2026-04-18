pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

Item {
    id: root

    property var launcher: null
    property var wallpaperSelector: null
    property var controlCenter: null
    property var powerMenu: null
    property var notifications: null

    function toggleLauncher() {
        if (launcher)
            launcher.toggle()
    }

    function toggleWallpaperSelector() {
        if (wallpaperSelector)
            wallpaperSelector.toggle()
    }

    function openPanel(kind) {
        var label = ""
        if (kind === "audio")
            label = "Audio controls"
        else if (kind === "network")
            label = "Network controls"
        else if (kind === "power")
            label = "Power controls"
        else
            label = "System controls"

        if (controlCenter)
            controlCenter.toggle(kind, label)
    }

    function togglePowerMenu() {
        if (powerMenu)
            powerMenu.toggle()
    }

    function powerAction(action) {
        if (!controlCenter || !powerMenu)
            return

        if (action === "lock") {
            if (notifications)
                notifications.showOsd("Locking")
            controlCenter.closePanel()
            powerMenu.closeMenu()
            powerActionProc.command = ["sh", "-c", "pidof hyprlock >/dev/null || hyprlock"]
            powerActionProc.running = true
        } else if (action === "suspend") {
            if (notifications)
                notifications.notify("Power", "Suspending system")
            controlCenter.closePanel()
            powerMenu.closeMenu()
            powerActionProc.command = ["sh", "-c", "systemctl suspend"]
            powerActionProc.running = true
        } else if (action === "logout") {
            if (notifications)
                notifications.notify("Session", "Logging out")
            controlCenter.closePanel()
            powerMenu.closeMenu()
            powerActionProc.command = ["sh", "-c", "loginctl terminate-user \"$USER\""]
            powerActionProc.running = true
        } else if (action === "reboot") {
            if (notifications)
                notifications.notify("Power", "Rebooting system")
            controlCenter.closePanel()
            powerMenu.closeMenu()
            powerActionProc.command = ["sh", "-c", "systemctl reboot"]
            powerActionProc.running = true
        } else if (action === "shutdown") {
            if (notifications)
                notifications.notify("Power", "Shutting down system")
            controlCenter.closePanel()
            powerMenu.closeMenu()
            powerActionProc.command = ["sh", "-c", "systemctl poweroff"]
            powerActionProc.running = true
        }
    }

    function showNotification(title, body) {
        if (notifications)
            notifications.notify(title, body)
    }

    function showOsd(text) {
        if (notifications)
            notifications.showOsd(text)
    }

    Process {
        id: powerActionProc
    }
}