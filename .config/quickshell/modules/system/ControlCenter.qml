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

    property var notifier: null
    property var powerMenu: null

    property real volumePercent: 0
    property bool audioMuted: false
    property bool wifiEnabled: false
    property bool networkOnline: false
    property string wifiSsid: ""
    property real brightnessPercent: 0
    property bool hasBattery: false
    property string batteryText: "--"
    property string loadLabel: "LOAD --"
    property string memLabel: "RAM --"
    property bool nightLightOn: false
    property bool dndOn: false

    readonly property var overlayScreen: ScreenUtil.focusedScreen()
    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    function toggle(kind, label) {
        if (visible) { visible = false; return }
        visible = true; refreshNow()
    }
    function closePanel() { visible = false }

    function refreshNow() {
        if (!audioProc.running) audioProc.running = true
        if (!networkProc.running) networkProc.running = true
        if (!powerProc.running) powerProc.running = true
        if (!systemProc.running) systemProc.running = true
        if (!nightProc.running) nightProc.running = true
    }

    function runShell(cmd) {
        actionProc.command = ["sh", "-c", cmd]; actionProc.running = true
        refreshNow()
    }

    function setVolume(v) {
        var r = Math.max(0, Math.min(100, Math.round(v)))
        runShell("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + r + "%")
    }
    function setBrightness(v) {
        var r = Math.max(1, Math.min(100, Math.round(v)))
        runShell("brightnessctl set " + r + "%")
    }

    // ── Processes ─────────────────────────────────────────────────────
    Process { id: actionProc }

    Process {
        id: audioProc; property string buf: ""
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/MUTED/{printf \"%d|1\\n\",$2*100;next}{printf \"%d|0\\n\",$2*100}'"]
        stdout: SplitParser { onRead: data => audioProc.buf += data }
        onRunningChanged: { if (!running && buf.length > 0) { var p=buf.trim().split("|"); root.volumePercent=parseFloat(p[0])||0; root.audioMuted=p[1]==="1"; buf="" } }
    }

    Process {
        id: networkProc; property string buf: ""
        command: ["sh", "-c",
            "wifi=$(nmcli radio wifi 2>/dev/null);" +
            "ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null|grep '^yes'|cut -d: -f2);" +
            "online=$(nmcli -t -f STATE general 2>/dev/null|grep -c connected);" +
            "printf '%s|%s|%s\\n' \"$wifi\" \"$ssid\" \"$online\""]
        stdout: SplitParser { onRead: data => networkProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.wifiEnabled = p[0] === "enabled"
                root.wifiSsid = p[1] || ""
                root.networkOnline = (parseInt(p[2]) || 0) > 0
                buf = ""
            }
        }
    }

    Process {
        id: powerProc; property string buf: ""
        command: ["sh", "-c",
            "cur=$(brightnessctl g 2>/dev/null);max=$(brightnessctl m 2>/dev/null);" +
            "[ -n \"$max\" ] && [ \"$max\" -gt 0 ] && bright=$((cur*100/max)) || bright=0;" +
            "f=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null|head -1);" +
            "if [ -f \"$f\" ];then cap=$(cat \"$f\");s=$(cat \"${f%/capacity}/status\");" +
            "case \"$s\" in Charging)st=CHG;;Full)st=FULL;;*)st=DIS;;esac;" +
            "printf '%s|%s%% %s|1\\n' \"$bright\" \"$cap\" \"$st\";" +
            "else printf '%s|--|0\\n' \"$bright\";fi"]
        stdout: SplitParser { onRead: data => powerProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.brightnessPercent = parseFloat(p[0]) || 0
                root.batteryText = p[1] || "--"
                root.hasBattery = p[2] === "1"
                buf = ""
            }
        }
    }

    Process {
        id: systemProc; property string buf: ""
        command: ["sh", "-c",
            "load=$(cut -d' ' -f1 /proc/loadavg);cores=$(nproc);" +
            "lt=$(awk -v l=\"$load\" -v c=\"$cores\" 'BEGIN{if(c>0)printf \"LOAD %d%%\",(l/c)*100;else print \"LOAD --\"}');" +
            "mt=$(free|awk '/Mem:/{printf \"RAM %d%%\",($3/$2)*100}');" +
            "printf '%s|%s\\n' \"$lt\" \"$mt\""]
        stdout: SplitParser { onRead: data => systemProc.buf += data }
        onRunningChanged: { if (!running && buf.length > 0) { var p=buf.trim().split("|"); root.loadLabel=p[0]; root.memLabel=p[1]||"RAM --"; buf="" } }
    }

    Process {
        id: nightProc; property string buf: ""
        command: ["sh", "-c", "pgrep -x wlsunset >/dev/null && echo 1 || echo 0"]
        stdout: SplitParser { onRead: data => nightProc.buf += data }
        onRunningChanged: { if (!running && buf.length > 0) { root.nightLightOn = buf.trim() === "1"; buf="" } }
    }

    Timer { interval: 500; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: if (!audioProc.running) audioProc.running = true
    }
    Timer { interval: 2000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: {
            if (!networkProc.running) networkProc.running = true
            if (!powerProc.running) powerProc.running = true
            if (!systemProc.running) systemProc.running = true
            if (!nightProc.running) nightProc.running = true
        }
    }

    // ── Custom slider ─────────────────────────────────────────────────
    component CcSlider: Slider {
        id: sr; from: 0; to: 100; stepSize: 1
        background: Rectangle {
            x: sr.leftPadding; y: sr.topPadding + sr.availableHeight/2 - height/2
            width: sr.availableWidth; height: 6; radius: 3
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.9)
            Rectangle { width: sr.visualPosition*parent.width; height: parent.height; radius: parent.radius; color: Theme.primary }
        }
        handle: Rectangle {
            x: sr.leftPadding + sr.visualPosition*(sr.availableWidth-width)
            y: sr.topPadding + sr.availableHeight/2 - height/2
            implicitWidth: 16; implicitHeight: 16; radius: 8
            color: Theme.fg; border.width: 2; border.color: Theme.primary
        }
    }

    // ── Dismiss ───────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "transparent"; visible: root.visible
        MouseArea { anchors.fill: parent; onClicked: root.closePanel() }
    }

    // ── Panel ─────────────────────────────────────────────────────────
    Rectangle {
        id: panelContainer
        visible: opacity > 0
        opacity: root.visible ? 1 : 0
        scale:   root.visible ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        anchors { right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: Config.controlCenterBottomOffset }
        width: Config.controlCenterWidth
        radius: 24
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.97)
        border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
        implicitHeight: cc.childrenRect.height + 28
        MouseArea { anchors.fill: parent }

        Column {
            id: cc
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 14
            spacing: 12

            // ── Header ────────────────────────────────────────────────
            Text {
                text: "SETTINGS"; color: Theme.primary
                font.family: Theme.monoFont; font.pixelSize: 10; font.letterSpacing: 4; font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ── Toggle grid ───────────────────────────────────────────
            Grid {
                columns: 2; spacing: 8; width: parent.width

                // Wi-Fi
                Rectangle {
                    id: wifiTile
                    width: (parent.width - 8) / 2; height: 68; radius: 16
                    color: root.networkOnline
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                    border.width: 1
                    border.color: root.networkOnline
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.networkOnline ? "󰖩" : "󰖪"; font.family: Theme.iconFont; font.pixelSize: 20; color: root.networkOnline ? Theme.primaryFg : Theme.fgMuted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.wifiSsid || "Wi-Fi"; font.family: Theme.uiFont; font.pixelSize: 11; font.bold: true; color: root.networkOnline ? Theme.primaryFg : Theme.fg; elide: Text.ElideRight; width: wifiTile.width - 16 ; horizontalAlignment: Text.AlignHCenter }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.wifiEnabled ? (root.networkOnline ? "Connected" : "Disconnected") : "Off"; font.family: Theme.uiFont; font.pixelSize: 9; color: root.networkOnline ? Qt.rgba(Theme.primaryFg.r,Theme.primaryFg.g,Theme.primaryFg.b,0.7) : Theme.fgMuted }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell(root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on") }
                }

                // Audio
                Rectangle {
                    width: (parent.width - 8) / 2; height: 68; radius: 16
                    color: !root.audioMuted
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                    border.width: 1
                    border.color: !root.audioMuted
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.audioMuted ? "󰝟" : "󰕾"; font.family: Theme.iconFont; font.pixelSize: 20; color: !root.audioMuted ? Theme.primaryFg : Theme.fgMuted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Audio"; font.family: Theme.uiFont; font.pixelSize: 11; font.bold: true; color: !root.audioMuted ? Theme.primaryFg : Theme.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.audioMuted ? "Muted" : Math.round(root.volumePercent) + "%"; font.family: Theme.uiFont; font.pixelSize: 9; color: !root.audioMuted ? Qt.rgba(Theme.primaryFg.r,Theme.primaryFg.g,Theme.primaryFg.b,0.7) : Theme.fgMuted }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") }
                }

                // Night Light
                Rectangle {
                    width: (parent.width - 8) / 2; height: 68; radius: 16
                    color: root.nightLightOn
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                    border.width: 1
                    border.color: root.nightLightOn
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰖔"; font.family: Theme.iconFont; font.pixelSize: 20; color: root.nightLightOn ? Theme.primaryFg : Theme.fgMuted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Night Light"; font.family: Theme.uiFont; font.pixelSize: 11; font.bold: true; color: root.nightLightOn ? Theme.primaryFg : Theme.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.nightLightOn ? "On" : "Off"; font.family: Theme.uiFont; font.pixelSize: 9; color: root.nightLightOn ? Qt.rgba(Theme.primaryFg.r,Theme.primaryFg.g,Theme.primaryFg.b,0.7) : Theme.fgMuted }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell(root.nightLightOn ? "pkill wlsunset" : "wlsunset -t 4000 -T 6500 &") }
                }

                // Battery / DND
                Rectangle {
                    width: (parent.width - 8) / 2; height: 68; radius: 16
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    Column {
                        anchors.centerIn: parent; spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.hasBattery ? "󰁹" : "󰚥"; font.family: Theme.iconFont; font.pixelSize: 20; color: root.hasBattery ? Theme.primary : Theme.fgMuted }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.hasBattery ? "Battery" : "AC Power"; font.family: Theme.uiFont; font.pixelSize: 11; font.bold: true; color: Theme.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.batteryText; font.family: Theme.uiFont; font.pixelSize: 9; color: Theme.fgMuted }
                    }
                }
            }

            // ── Volume slider ─────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 42; radius: 14
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    Text { text: "󰕾"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    CcSlider { width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; value: root.volumePercent; onMoved: root.setVolume(value) }
                    Text { text: Math.round(root.volumePercent) + "%"; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter; width: 28 }
                }
            }

            // ── Brightness slider ─────────────────────────────────────
            Rectangle {
                width: parent.width; height: 42; radius: 14
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                Row {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                    Text { text: "󰃠"; font.family: Theme.iconFont; font.pixelSize: 15; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    CcSlider { width: parent.width - 60; anchors.verticalCenter: parent.verticalCenter; value: root.brightnessPercent; onMoved: root.setBrightness(value) }
                    Text { text: Math.round(root.brightnessPercent) + "%"; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted; anchors.verticalCenter: parent.verticalCenter; width: 28 }
                }
            }

            // ── Quick actions ─────────────────────────────────────────
            Row {
                width: parent.width; spacing: 8

                // Screenshot
                Rectangle {
                    width: (parent.width - 16) / 3; height: 36; radius: 18
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { text: "󰹑"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Screen"; font.family: Theme.uiFont; font.pixelSize: 10; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closePanel(); root.runShell("sleep 0.2 && grim -g \"$(slurp)\" - | wl-copy") }
                    }
                }

                // Screenshot full
                Rectangle {
                    width: (parent.width - 16) / 3; height: 36; radius: 18
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { text: "󰍹"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Full"; font.family: Theme.uiFont; font.pixelSize: 10; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closePanel(); root.runShell("sleep 0.2 && grim - | wl-copy") }
                    }
                }

                // Wallpaper
                Rectangle {
                    width: (parent.width - 16) / 3; height: 36; radius: 18
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)
                    border.width: 1; border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)
                    Row { anchors.centerIn: parent; spacing: 6
                        Text { text: "󰸉"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Walls"; font.family: Theme.uiFont; font.pixelSize: 10; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.closePanel(); Hyprland.dispatch("exec qs ipc call shell toggleWallpaperSelector") }
                    }
                }
            }

            // ── Stats ─────────────────────────────────────────────────
            Row {
                width: parent.width; spacing: 8
                Rectangle {
                    width: (parent.width - 8) / 2; height: 28; radius: 14
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                    Text { anchors.centerIn: parent; text: root.loadLabel; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted }
                }
                Rectangle {
                    width: (parent.width - 8) / 2; height: 28; radius: 14
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                    Text { anchors.centerIn: parent; text: root.memLabel; font.family: Theme.monoFont; font.pixelSize: 10; color: Theme.fgMuted }
                }
            }

            // ── Power ─────────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 36; radius: 18
                color: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.45)
                border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                Row { anchors.centerIn: parent; spacing: 8
                    Text { text: "󰐥"; font.family: Theme.iconFont; font.pixelSize: 13; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Power Menu"; font.family: Theme.uiFont; font.pixelSize: 12; color: Theme.fg; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.closePanel(); if (root.powerMenu) root.powerMenu.openMenu() }
                }
            }
        }
    }
}
