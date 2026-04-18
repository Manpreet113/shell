pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../core"

PanelWindow {
    id: root

    focusable: true
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1
    color: "transparent"

    property string panelType: "audio"
    property string contextLabel: ""
    property var notifier: null
    property var powerMenu: null

    property string audioLabel: "VOL --"
    property real volumePercent: 0
    property bool audioMuted: false

    property string networkLabel: "NET OFF"
    property bool wifiEnabled: false
    property bool networkOnline: false

    property string batteryLabel: "BAT --"
    property real brightnessPercent: 0
    property bool hasBattery: false

    property string loadLabel: "LOAD --"
    property string memLabel: "RAM --"

    readonly property var overlayScreen: {
        return ScreenUtil.focusedScreen()
    }

    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    function toggle(kind, label) {
        if (visible && panelType === kind) {
            visible = false
            return
        }

        panelType = kind
        contextLabel = label || ""
        visible = true
        refreshNow()
    }

    function closePanel() {
        visible = false
    }

    function refreshNow() {
        if (!audioProc.running) audioProc.running = true
        if (!networkProc.running) networkProc.running = true
        if (!powerProc.running) powerProc.running = true
        if (!systemProc.running) systemProc.running = true
    }

    function runShell(command, osdText, title, body) {
        actionProc.command = ["sh", "-c", command]
        actionProc.running = true

        if (notifier && osdText)
            notifier.showOsd(osdText)
        if (notifier && title)
            notifier.notify(title, body || "")

        refreshNow()
    }

    function setVolume(value) {
        var rounded = Math.max(0, Math.min(100, Math.round(value)))
        runShell("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + rounded + "%", "VOL " + rounded + "%", "Audio", "Set volume to " + rounded + "%")
    }

    function setBrightness(value) {
        var rounded = Math.max(1, Math.min(100, Math.round(value)))
        runShell("brightnessctl set " + rounded + "%", "BRIGHT " + rounded + "%", "Power", "Set brightness to " + rounded + "%")
    }

    Process { id: actionProc }

    Process {
        id: audioProc
        property string buffer: ""
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "awk '/MUTED/ {printf \"VOL MUTED|%d|1\\n\", $2 * 100; next} {printf \"VOL %d%%|%d|0\\n\", $2 * 100, $2 * 100}'"
        ]
        stdout: SplitParser { onRead: data => audioProc.buffer += data }
        onRunningChanged: {
            if (!running && buffer.length > 0) {
                var parts = buffer.trim().split("|")
                root.audioLabel = parts[0] || "VOL --"
                root.volumePercent = parts.length > 1 ? parseFloat(parts[1]) : 0
                root.audioMuted = parts.length > 2 ? parts[2] === "1" : false
                buffer = ""
            }
        }
    }

    Process {
        id: networkProc
        property string buffer: ""
        command: ["sh", "-c",
            "wifi=$(nmcli radio wifi 2>/dev/null); " +
            "conn=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\" {print $1\":\"$3; exit}'); " +
            "if [ -z \"$conn\" ]; then printf 'NET OFF|%s|0\\n' \"$wifi\"; exit 0; fi; " +
            "type=${conn%%:*}; name=${conn#*:}; " +
            "case \"$type\" in wifi) label=\"WIFI $name\" ;; ethernet) label=\"ETH $name\" ;; *) label=\"NET $name\" ;; esac; " +
            "printf '%s|%s|1\\n' \"$label\" \"$wifi\""
        ]
        stdout: SplitParser { onRead: data => networkProc.buffer += data }
        onRunningChanged: {
            if (!running && buffer.length > 0) {
                var parts = buffer.trim().split("|")
                root.networkLabel = parts[0] || "NET OFF"
                root.wifiEnabled = parts.length > 1 ? parts[1] === "enabled" : false
                root.networkOnline = parts.length > 2 ? parts[2] === "1" : false
                buffer = ""
            }
        }
    }

    Process {
        id: powerProc
        property string buffer: ""
        command: ["sh", "-c",
            "cur=$(brightnessctl g 2>/dev/null); max=$(brightnessctl m 2>/dev/null); " +
            "if [ -n \"$cur\" ] && [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then bright=$((cur * 100 / max)); else bright=0; fi; " +
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "if [ -f \"$f\" ]; then cap=$(cat \"$f\"); s=$(cat \"${f%/capacity}/status\"); " +
            "case \"$s\" in Charging) st='CHG' ;; Full) st='FULL' ;; Not\\ charging) st='IDLE' ;; *) st='DIS' ;; esac; " +
            "printf 'BAT %s%% %s|%s|1\\n' \"$cap\" \"$st\" \"$bright\"; " +
            "else printf 'NO BAT|%s|0\\n' \"$bright\"; fi"
        ]
        stdout: SplitParser { onRead: data => powerProc.buffer += data }
        onRunningChanged: {
            if (!running && buffer.length > 0) {
                var parts = buffer.trim().split("|")
                root.batteryLabel = parts[0] || "BAT --"
                root.brightnessPercent = parts.length > 1 ? parseFloat(parts[1]) : 0
                root.hasBattery = parts.length > 2 ? parts[2] === "1" : false
                buffer = ""
            }
        }
    }

    Process {
        id: systemProc
        property string buffer: ""
        command: ["sh", "-c",
            "load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null); cores=$(nproc 2>/dev/null); " +
            "loadtext=$(awk -v l=\"$load\" -v c=\"$cores\" 'BEGIN { if (l == \"\" || c == \"\" || c == 0) print \"LOAD --\"; else printf \"LOAD %d%%\", (l / c) * 100 }'); " +
            "memtext=$(free | awk '/Mem:/ {printf \"RAM %d%%\", ($3 / $2) * 100}'); " +
            "printf '%s|%s\\n' \"$loadtext\" \"$memtext\""
        ]
        stdout: SplitParser { onRead: data => systemProc.buffer += data }
        onRunningChanged: {
            if (!running && buffer.length > 0) {
                var parts = buffer.trim().split("|")
                root.loadLabel = parts[0] || "LOAD --"
                root.memLabel = parts.length > 1 ? parts[1] : "RAM --"
                buffer = ""
            }
        }
    }

    Timer {
        interval: 400
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!audioProc.running) audioProc.running = true
        }
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!networkProc.running) networkProc.running = true
            if (!powerProc.running) powerProc.running = true
            if (!systemProc.running) systemProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.visible
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePanel()
        }
    }

    component StateChip: Rectangle {
        property string chipText: ""
        property bool chipActive: false
        implicitHeight: 28
        implicitWidth: chipLabel.implicitWidth + 18
        radius: implicitHeight / 2
        color: chipActive
            ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.9)
            : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.64)
        border.width: 1
        border.color: chipActive
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.16)

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: parent.chipText
            color: parent.chipActive ? Theme.primary : Theme.fgMuted
            font.family: Theme.monoFont
            font.pixelSize: 10
        }
    }

    component SectionCard: Rectangle {
        default property alias cardData: content.data
        implicitHeight: content.implicitHeight + 24
        radius: 18
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
        }
    }

    component ActionButton: Rectangle {
        property string buttonText: ""
        signal pressed()
        implicitHeight: 40
        radius: implicitHeight / 2
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.72)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

        Text {
            anchors.centerIn: parent
            text: parent.buttonText
            color: Theme.fg
            font.family: Theme.uiFont
            font.pixelSize: 13
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.pressed()
        }
    }

    component ValueSlider: Slider {
        id: sliderRoot
        from: 0
        to: 100
        stepSize: 1

        background: Rectangle {
            x: sliderRoot.leftPadding
            y: sliderRoot.topPadding + sliderRoot.availableHeight / 2 - height / 2
            width: sliderRoot.availableWidth
            height: 8
            radius: 4
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.82)

            Rectangle {
                width: sliderRoot.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9)
            }
        }

        handle: Rectangle {
            x: sliderRoot.leftPadding + sliderRoot.visualPosition * (sliderRoot.availableWidth - width)
            y: sliderRoot.topPadding + sliderRoot.availableHeight / 2 - height / 2
            implicitWidth: 20
            implicitHeight: 20
            radius: 10
            color: Theme.fg
            border.width: 2
            border.color: Theme.primary
        }
    }

    Rectangle {
        visible: root.visible
        anchors {
            right: parent.right
            rightMargin: 18
            bottom: parent.bottom
            bottomMargin: Config.controlCenterBottomOffset
        }
        width: Config.controlCenterWidth
        radius: 24
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.97)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        implicitHeight: content.implicitHeight + 28

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: root.panelType === "audio" ? "AUDIO" : root.panelType === "network" ? "NETWORK" : root.panelType === "power" ? "POWER" : "SYSTEM"
                color: Theme.primary
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 3
            }

            Text {
                Layout.fillWidth: true
                text: root.contextLabel
                color: Theme.fgMuted
                font.family: Theme.uiFont
                font.pixelSize: 12
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StateChip {
                    chipText: root.panelType === "audio" ? root.audioLabel : root.panelType === "network" ? root.networkLabel : root.panelType === "power" ? root.batteryLabel : root.loadLabel
                    chipActive: true
                }

                StateChip {
                    visible: root.panelType === "system"
                    chipText: root.memLabel
                }

                StateChip {
                    visible: root.panelType === "network"
                    chipText: root.wifiEnabled ? "WIFI ON" : "WIFI OFF"
                    chipActive: root.wifiEnabled
                }
            }

            Loader {
                Layout.fillWidth: true
                sourceComponent: root.panelType === "audio"
                    ? audioPanel
                    : root.panelType === "network"
                        ? networkPanel
                        : root.panelType === "power"
                            ? powerPanel
                            : systemPanel
            }
        }
    }

    Component {
        id: audioPanel

        ColumnLayout {
            spacing: 10

            SectionCard {
                Layout.fillWidth: true

                Text {
                    text: "Output"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.audioMuted ? "Muted" : Math.round(root.volumePercent) + "%"
                        color: root.audioMuted ? Theme.error : Theme.primary
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    StateChip {
                        chipText: root.audioMuted ? "MUTED" : "LIVE"
                        chipActive: !root.audioMuted
                    }
                }

                ValueSlider {
                    Layout.fillWidth: true
                    value: root.volumePercent
                    onMoved: root.setVolume(value)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: root.audioMuted ? "Unmute" : "Mute"
                    onPressed: root.runShell("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Audio toggled", "Audio", "Toggled mute state")
                }

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Mixer"
                    onPressed: root.runShell("pavucontrol", "", "Audio", "Opening mixer")
                }
            }
        }
    }

    Component {
        id: networkPanel

        ColumnLayout {
            spacing: 10

            SectionCard {
                Layout.fillWidth: true

                Text {
                    text: "Connection"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.networkLabel
                    color: root.networkOnline ? Theme.fg : Theme.fgMuted
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StateChip {
                        chipText: root.networkOnline ? "ONLINE" : "OFFLINE"
                        chipActive: root.networkOnline
                    }

                    StateChip {
                        chipText: root.wifiEnabled ? "RADIO ON" : "RADIO OFF"
                        chipActive: root.wifiEnabled
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: root.wifiEnabled ? "Disable Wi-Fi" : "Enable Wi-Fi"
                    onPressed: root.runShell(root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on", root.wifiEnabled ? "Wi-Fi disabled" : "Wi-Fi enabled", "Network", root.wifiEnabled ? "Disabled Wi-Fi" : "Enabled Wi-Fi")
                }

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Settings"
                    onPressed: root.runShell("nm-connection-editor", "", "Network", "Opening settings")
                }
            }
        }
    }

    Component {
        id: powerPanel

        ColumnLayout {
            spacing: 10

            SectionCard {
                Layout.fillWidth: true

                Text {
                    text: "Brightness"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text: Math.round(root.brightnessPercent) + "%"
                    color: Theme.primary
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    font.bold: true
                }

                ValueSlider {
                    Layout.fillWidth: true
                    value: root.brightnessPercent
                    onMoved: root.setBrightness(value)
                }
            }

            SectionCard {
                Layout.fillWidth: true
                visible: root.hasBattery

                Text {
                    text: "Battery"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.batteryLabel
                    color: Theme.fgMuted
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Lock"
                    onPressed: root.runShell("qs -p ~/.config/quickshell ipc call shell powerAction lock", "", "Session", "Locking screen")
                }

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Suspend"
                    onPressed: root.runShell("qs -p ~/.config/quickshell ipc call shell powerAction suspend", "", "Power", "Suspending system")
                }
            }

            ActionButton {
                Layout.fillWidth: true
                buttonText: "Open Power Menu"
                onPressed: {
                    root.closePanel()
                    if (root.powerMenu)
                        root.powerMenu.openMenu()
                }
            }
        }
    }

    Component {
        id: systemPanel

        ColumnLayout {
            spacing: 10

            SectionCard {
                Layout.fillWidth: true

                Text {
                    text: "System Load"
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 14
                    font.bold: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StateChip {
                        chipText: root.loadLabel
                        chipActive: true
                    }

                    StateChip {
                        chipText: root.memLabel
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Task View"
                    onPressed: root.runShell("kitty -e btop", "", "System", "Opening btop")
                }

                ActionButton {
                    Layout.fillWidth: true
                    buttonText: "Reload"
                    onPressed: root.runShell("killall qs; qs -p ~/.config/quickshell --daemonize", "Shell reloaded", "Shell", "Reloading Quickshell")
                }
            }
        }
    }
}
