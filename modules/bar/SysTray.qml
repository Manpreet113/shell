// SysTray.qml — Right-side system status indicators
// Displays: VOL xx%  ·  SSID/connection  ·  BAT xx%
// Each metric is polled by a shell command on a timer.
// Battery section is hidden automatically on desktops with no battery.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../theme"

RowLayout {
    id: root
    spacing: 6

    // ─── Volume ──────────────────────────────────────────────────────
    property string volText: "VOL --"

    Process {
        id: volProc
        // wpctl (WirePlumber) is standard on modern Fedora/Arch with PipeWire.
        // It prints: "Volume: 0.65" — we multiply by 100 and round.
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null " +
            "| awk '{printf \"%d%%\", $2 * 100}' " +
            "|| echo '--'"
        ]
        stdout: SplitParser {
            onRead: data => root.volText = "VOL " + data.trim()
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!volProc.running) volProc.running = true }
    }

    // ─── Network ─────────────────────────────────────────────────────
    property string netText: "NET --"

    Process {
        id: netProc
        // Try WiFi SSID first; fall back to any active connection name.
        command: ["sh", "-c",
            "ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null " +
            "       | grep '^yes:' | cut -d: -f2 | head -1); " +
            "[ -n \"$ssid\" ] && echo \"$ssid\" && exit 0; " +
            "nmcli -t -f name con show --active 2>/dev/null " +
            "| head -1 || echo 'offline'"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim()
                root.netText = name.length > 14 ? name.slice(0, 13) + "…" : name
            }
        }
    }

    Timer {
        interval: 12000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!netProc.running) netProc.running = true }
    }

    // ─── Battery ─────────────────────────────────────────────────────
    // Will be empty on desktops — those Text items are hidden via visible:
    property string batText: ""

    Process {
        id: batProc
        // Reads /sys/class/power_supply/BAT*/capacity (integer 0-100).
        // Outputs nothing if no battery found (desktop machines).
        command: ["sh", "-c",
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "[ -f \"$f\" ] && printf 'BAT %s%%' \"$(cat $f)\" || true"
        ]
        stdout: SplitParser {
            onRead: data => root.batText = data.trim()
        }
    }

    Timer {
        interval: 30000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!batProc.running) batProc.running = true }
    }

    // ─── Render ──────────────────────────────────────────────────────

    Text {
        text:           root.volText
        color:          Theme.fgMuted
        font.family:    Theme.monoFont
        font.pixelSize: 12
    }

    Text {
        text: "·"; color: Theme.outline
        font.family: Theme.monoFont; font.pixelSize: 12
    }

    Text {
        text:           root.netText
        color:          Theme.fgMuted
        font.family:    Theme.monoFont
        font.pixelSize: 12
    }

    // Battery separator + value — hidden on desktops without a battery
    Text {
        visible:        root.batText.length > 0
        text:           "·"; color: Theme.outline
        font.family:    Theme.monoFont; font.pixelSize: 12
    }

    Text {
        visible:        root.batText.length > 0
        text:           root.batText
        color:          Theme.fgMuted
        font.family:    Theme.monoFont
        font.pixelSize: 12
    }
}
