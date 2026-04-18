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

    readonly property var overlayScreen: ScreenUtil.focusedScreen()

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

    function closePanel() { visible = false }

    function refreshNow() {
        if (!audioProc.running) audioProc.running = true
        if (!networkProc.running) networkProc.running = true
        if (!powerProc.running) powerProc.running = true
        if (!systemProc.running) systemProc.running = true
    }

    function runShell(command, osdText, title, body) {
        actionProc.command = ["sh", "-c", command]
        actionProc.running = true
        if (notifier && osdText) notifier.showOsd(osdText)
        if (notifier && title) notifier.notify(title, body || "")
        refreshNow()
    }

    function setVolume(value) {
        var r = Math.max(0, Math.min(100, Math.round(value)))
        runShell("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + r + "%", "VOL " + r + "%", "Audio", "Set volume to " + r + "%")
    }

    function setBrightness(value) {
        var r = Math.max(1, Math.min(100, Math.round(value)))
        runShell("brightnessctl set " + r + "%", "BRIGHT " + r + "%", "Power", "Set brightness to " + r + "%")
    }

    // ── Processes ─────────────────────────────────────────────────────
    Process { id: actionProc }

    Process {
        id: audioProc; property string buf: ""
        command: ["sh", "-c",
            "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | " +
            "awk '/MUTED/ {printf \"VOL MUTED|%d|1\\n\", $2 * 100; next} {printf \"VOL %d%%|%d|0\\n\", $2 * 100, $2 * 100}'"]
        stdout: SplitParser { onRead: data => audioProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.audioLabel = p[0] || "VOL --"
                root.volumePercent = p.length > 1 ? parseFloat(p[1]) : 0
                root.audioMuted = p.length > 2 ? p[2] === "1" : false
                buf = ""
            }
        }
    }

    Process {
        id: networkProc; property string buf: ""
        command: ["sh", "-c",
            "wifi=$(nmcli radio wifi 2>/dev/null); " +
            "conn=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F: '$2==\"connected\" {print $1\":\"$3; exit}'); " +
            "if [ -z \"$conn\" ]; then printf 'NET OFF|%s|0\\n' \"$wifi\"; exit 0; fi; " +
            "type=${conn%%:*}; name=${conn#*:}; " +
            "case \"$type\" in wifi) label=\"WIFI $name\" ;; ethernet) label=\"ETH $name\" ;; *) label=\"NET $name\" ;; esac; " +
            "printf '%s|%s|1\\n' \"$label\" \"$wifi\""]
        stdout: SplitParser { onRead: data => networkProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.networkLabel = p[0] || "NET OFF"
                root.wifiEnabled = p.length > 1 ? p[1] === "enabled" : false
                root.networkOnline = p.length > 2 ? p[2] === "1" : false
                buf = ""
            }
        }
    }

    Process {
        id: powerProc; property string buf: ""
        command: ["sh", "-c",
            "cur=$(brightnessctl g 2>/dev/null); max=$(brightnessctl m 2>/dev/null); " +
            "if [ -n \"$cur\" ] && [ -n \"$max\" ] && [ \"$max\" -gt 0 ]; then bright=$((cur * 100 / max)); else bright=0; fi; " +
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
            "if [ -f \"$f\" ]; then cap=$(cat \"$f\"); s=$(cat \"${f%/capacity}/status\"); " +
            "case \"$s\" in Charging) st='CHG' ;; Full) st='FULL' ;; Not\\ charging) st='IDLE' ;; *) st='DIS' ;; esac; " +
            "printf 'BAT %s%% %s|%s|1\\n' \"$cap\" \"$st\" \"$bright\"; " +
            "else printf 'NO BAT|%s|0\\n' \"$bright\"; fi"]
        stdout: SplitParser { onRead: data => powerProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.batteryLabel = p[0] || "BAT --"
                root.brightnessPercent = p.length > 1 ? parseFloat(p[1]) : 0
                root.hasBattery = p.length > 2 ? p[2] === "1" : false
                buf = ""
            }
        }
    }

    Process {
        id: systemProc; property string buf: ""
        command: ["sh", "-c",
            "load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null); cores=$(nproc 2>/dev/null); " +
            "loadtext=$(awk -v l=\"$load\" -v c=\"$cores\" 'BEGIN { if (l == \"\" || c == \"\" || c == 0) print \"LOAD --\"; else printf \"LOAD %d%%\", (l / c) * 100 }'); " +
            "memtext=$(free | awk '/Mem:/ {printf \"RAM %d%%\", ($3 / $2) * 100}'); " +
            "printf '%s|%s\\n' \"$loadtext\" \"$memtext\""]
        stdout: SplitParser { onRead: data => systemProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.loadLabel = p[0] || "LOAD --"
                root.memLabel = p.length > 1 ? p[1] : "RAM --"
                buf = ""
            }
        }
    }

    Timer { interval: 400; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: if (!audioProc.running) audioProc.running = true
    }
    Timer { interval: 1000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!networkProc.running) networkProc.running = true
            if (!powerProc.running) powerProc.running = true
            if (!systemProc.running) systemProc.running = true
        }
    }

    // ── Custom slider ─────────────────────────────────────────────────
    component ValueSlider: Slider {
        id: sliderRoot
        from: 0; to: 100; stepSize: 1
        background: Rectangle {
            x: sliderRoot.leftPadding
            y: sliderRoot.topPadding + sliderRoot.availableHeight / 2 - height / 2
            width: sliderRoot.availableWidth; height: 6; radius: 3
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
            Rectangle {
                width: sliderRoot.visualPosition * parent.width
                height: parent.height; radius: parent.radius
                color: Theme.primary
            }
        }
        handle: Rectangle {
            x: sliderRoot.leftPadding + sliderRoot.visualPosition * (sliderRoot.availableWidth - width)
            y: sliderRoot.topPadding + sliderRoot.availableHeight / 2 - height / 2
            implicitWidth: 18; implicitHeight: 18; radius: 9
            color: Theme.fg
            border.width: 2; border.color: Theme.primary
        }
    }

    // ── Dismiss area ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; color: "transparent"
        visible: root.visible
        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
    }

    // ── Panel container ───────────────────────────────────────────────
    Rectangle {
        id: panelContainer
        visible: opacity > 0
        opacity: root.visible ? 1 : 0
        scale:   root.visible ? 1 : 0.94

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutBack  } }

        anchors {
            right: parent.right; rightMargin: 18
            bottom: parent.bottom; bottomMargin: Config.controlCenterBottomOffset
        }
        width: Config.controlCenterWidth
        radius: 24
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

        // Swallow clicks on the panel itself
        MouseArea { anchors.fill: parent }

        // Use a simple Column with fixed pixel widths/heights
        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            // Header
            Text {
                text: "SETTINGS"
                color: Theme.primary
                font.family: Theme.monoFont
                font.pixelSize: 10
                font.letterSpacing: 4
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ── Quick Toggles ─────────────────────────────────────────
            Grid {
                columns: 2; spacing: 10
                width: parent.width

                // Wi-Fi tile
                Rectangle {
                    width: (parent.width - 10) / 2; height: 60; radius: 14
                    color: root.networkOnline
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: root.networkOnline
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: root.networkOnline ? "󰖩" : "󰖪"; font.family: Theme.iconFont; font.pixelSize: 18; color: root.networkOnline ? Theme.primaryFg : Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Wi-Fi"; font.family: Theme.uiFont; font.pixelSize: 12; font.bold: true; color: root.networkOnline ? Theme.primaryFg : Theme.fg }
                            Text { text: root.wifiEnabled ? "On" : "Off"; font.family: Theme.uiFont; font.pixelSize: 9; color: root.networkOnline ? Qt.rgba(Theme.primaryFg.r, Theme.primaryFg.g, Theme.primaryFg.b, 0.7) : Theme.fgMuted }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell(root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on", root.wifiEnabled ? "Wi-Fi disabled" : "Wi-Fi enabled") }
                }

                // Audio tile
                Rectangle {
                    width: (parent.width - 10) / 2; height: 60; radius: 14
                    color: !root.audioMuted
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: !root.audioMuted
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: root.audioMuted ? "󰝟" : "󰕾"; font.family: Theme.iconFont; font.pixelSize: 18; color: !root.audioMuted ? Theme.primaryFg : Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Audio"; font.family: Theme.uiFont; font.pixelSize: 12; font.bold: true; color: !root.audioMuted ? Theme.primaryFg : Theme.fg }
                            Text { text: root.audioMuted ? "Muted" : Math.round(root.volumePercent) + "%"; font.family: Theme.uiFont; font.pixelSize: 9; color: !root.audioMuted ? Qt.rgba(Theme.primaryFg.r, Theme.primaryFg.g, Theme.primaryFg.b, 0.7) : Theme.fgMuted }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "Audio toggled") }
                }

                // Display tile
                Rectangle {
                    width: (parent.width - 10) / 2; height: 60; radius: 14
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "󰃠"; font.family: Theme.iconFont; font.pixelSize: 18; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Display"; font.family: Theme.uiFont; font.pixelSize: 12; font.bold: true; color: Theme.fg }
                            Text { text: Math.round(root.brightnessPercent) + "%"; font.family: Theme.uiFont; font.pixelSize: 9; color: Theme.fgMuted }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }

                // Battery tile
                Rectangle {
                    width: (parent.width - 10) / 2; height: 60; radius: 14
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                    Row {
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "󰁹"; font.family: Theme.iconFont; font.pixelSize: 18; color: root.hasBattery ? Theme.primary : Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Text { text: "Battery"; font.family: Theme.uiFont; font.pixelSize: 12; font.bold: true; color: Theme.fg }
                            Text { text: root.batteryLabel.indexOf(" ") > 0 ? root.batteryLabel.split(" ").slice(1).join(" ") : "--"; font.family: Theme.uiFont; font.pixelSize: 9; color: Theme.fgMuted }
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                }
            }

            // ── Sliders ───────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: sliderCol.height + 24
                radius: 16
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                Column {
                    id: sliderCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12
                    spacing: 14

                    Row {
                        width: parent.width; spacing: 10
                        Text { text: "󰕾"; font.family: Theme.iconFont; color: Theme.primary; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                        ValueSlider { width: parent.width - 28; value: root.volumePercent; onMoved: root.setVolume(value) }
                    }
                    Row {
                        width: parent.width; spacing: 10
                        Text { text: "󰃠"; font.family: Theme.iconFont; color: Theme.primary; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                        ValueSlider { width: parent.width - 28; value: root.brightnessPercent; onMoved: root.setBrightness(value) }
                    }
                }
            }

            // ── System stats ──────────────────────────────────────────
            Row {
                width: parent.width; spacing: 10
                Rectangle {
                    width: (parent.width - 10) / 2; height: 30; radius: 15
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    Text { anchors.centerIn: parent; text: root.loadLabel; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted }
                }
                Rectangle {
                    width: (parent.width - 10) / 2; height: 30; radius: 15
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    Text { anchors.centerIn: parent; text: root.memLabel; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted }
                }
            }

            // ── Power button ──────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 38; radius: 19
                color: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.5)
                border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "󰐥"; font.family: Theme.iconFont; font.pixelSize: 14; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Power Menu"; font.family: Theme.uiFont; font.pixelSize: 13; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.closePanel(); if (root.powerMenu) root.powerMenu.openMenu() }
                }
            }
        }

        // Dynamic height from content
        implicitHeight: content.childrenRect.height + 32
    }
}
