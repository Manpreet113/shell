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
    property bool volMuted: false

    Process {
        id: volProc
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "awk '/MUTED/ {print \"VOL MUTED\"; next} {printf \"VOL %d%%\\n\", $2 * 100}'"
        ]
        stdout: SplitParser {
            onRead: data => {
                root.volText = data.trim()
                root.volMuted = root.volText.indexOf("MUTED") !== -1
            }
        }
    }

    Timer {
        interval: 1500; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!volProc.running) volProc.running = true }
    }

    // ─── Network ─────────────────────────────────────────────────────
    property string netText: "NET --"
    property bool netOnline: false

    Process {
        id: netProc
        command: ["sh", "-c",
            "conn=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null " +
            "| awk -F: '$2==\"connected\" {print $1\":\"$3; exit}'); " +
            "if [ -z \"$conn\" ]; then echo 'NET OFF'; exit 0; fi; " +
            "type=${conn%%:*}; name=${conn#*:}; " +
            "case \"$type\" in " +
            "wifi) printf 'WIFI %s\\n' \"$name\" ;; " +
            "ethernet) printf 'ETH %s\\n' \"$name\" ;; " +
            "*) printf 'NET %s\\n' \"$name\" ;; " +
            "esac"
        ]
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim()
                root.netText = name.length > 18 ? name.slice(0, 17) + "…" : name
                root.netOnline = root.netText !== "NET OFF"
            }
        }
    }

    Timer {
        interval: 15000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!netProc.running) netProc.running = true }
    }

    // ─── Battery ─────────────────────────────────────────────────────
    property string batText: ""
    property bool batCharging: false
    property bool batWarning: false

    Process {
        id: batProc
        command: ["sh", "-c",
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "if [ -f \"$f\" ]; then " +
            "  cap=$(cat \"$f\"); " +
            "  s=$(cat \"${f%/capacity}/status\"); " +
            "  case \"$s\" in " +
            "    Charging) st='CHG' ;; " +
            "    Full) st='FULL' ;; " +
            "    Not\\ charging) st='IDLE' ;; " +
            "    *) st='DIS' ;; " +
            "  esac; " +
            "  printf 'BAT %s%% %s\\n' \"$cap\" \"$st\"; " +
            "fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                root.batText = data.trim()
                root.batCharging = root.batText.indexOf("CHG") !== -1
                var match = root.batText.match(/BAT (\d+)%/)
                var level = match ? parseInt(match[1], 10) : 100
                root.batWarning = root.batText.length > 0 && !root.batCharging && level <= 15
            }
        }
    }

    // ─── System load ──────────────────────────────────────────────────
    property string loadText: "LOAD --"

    Process {
        id: loadProc
        command: ["sh", "-c",
            "load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null); " +
            "cores=$(nproc 2>/dev/null); " +
            "awk -v l=\"$load\" -v c=\"$cores\" 'BEGIN { " +
            "if (l == \"\" || c == \"\" || c == 0) print \"LOAD --\"; " +
            "else printf \"LOAD %d%%\\n\", (l / c) * 100 }'"
        ]
        stdout: SplitParser {
            onRead: data => root.loadText = data.trim()
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!loadProc.running) loadProc.running = true }
    }

    // ─── Memory ───────────────────────────────────────────────────────
    property string memText: "RAM --"

    Process {
        id: memProc
        command: ["sh", "-c",
            "free | awk '/Mem:/ {printf \"RAM %d%%\\n\", ($3 / $2) * 100}'"
        ]
        stdout: SplitParser {
            onRead: data => root.memText = data.trim()
        }
    }

    Timer {
        interval: 10000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!memProc.running) memProc.running = true }
    }

    Timer {
        interval: 30000; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: { if (!batProc.running) batProc.running = true }
    }

    // ─── Render ──────────────────────────────────────────────────────
    StatusPill {
        labelText: root.loadText
        muted: true
    }

    StatusPill {
        labelText: root.memText
        muted: true
    }

    StatusPill {
        labelText: root.netText
        emphasized: root.netOnline
    }

    StatusPill {
        labelText: root.volText
        warning: root.volMuted
        muted: !root.volMuted
    }

    StatusPill {
        visible: root.batText.length > 0
        labelText: root.batText
        emphasized: root.batCharging
        warning: root.batWarning
        muted: !root.batCharging && !root.batWarning
    }
}
