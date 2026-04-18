pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    property var notifications: null
    property bool ready: false

    // ─── Volume Listener ──────────────────────────────────────────────
    // Uses pactl subscribe to detect volume changes instantly
    Process {
        id: volListener
        command: ["sh", "-c", "pactl subscribe"]
        stdout: SplitParser {
            onRead: data => {
                if (data.indexOf("sink") !== -1) {
                    volDebounce.restart()
                }
            }
        }
        running: true
    }

    Timer {
        id: volDebounce
        interval: 50
        onTriggered: {
            volCheck.running = false
            volCheck.running = true
        }
    }

    Process {
        id: volCheck
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2*100)}'"]
        stdout: SplitParser {
            onRead: data => {
                var val = parseInt(data.trim())
                if (root.ready && notifications) {
                    notifications.showOsd("vol:" + val)
                }
            }
        }
    }

    // ─── Brightness Listener ──────────────────────────────────────────
    // Uses light polling (every 400ms) to detect brightness changes
    property int lastBrightness: -1
    
    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!brightnessCheck.running) brightnessCheck.running = true
        }
    }

    Process {
        id: brightnessCheck
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: SplitParser {
            onRead: data => {
                var val = parseInt(data.trim())
                if (root.lastBrightness === -1) {
                    root.lastBrightness = val
                    return
                }
                
                if (val !== root.lastBrightness) {
                    root.lastBrightness = val
                    if (root.ready && notifications) {
                        notifications.showOsd("br:" + val)
                    }
                }
            }
        }
    }

    // Delay readiness to avoid OSD popups on shell startup
    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }
}
