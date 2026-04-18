pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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
    property string githubUser: "..."
    property var githubData: []
    property int totalContributions: 0
    property string uptime: "..."

    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()

    property string mediaTitle: "No media"
    property string mediaArtist: ""
    property string mediaStatus: "Stopped"
    property real mediaPosition: 0
    property real mediaLength: 0

    readonly property var overlayScreen: ScreenUtil.focusedScreen()
    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    function toggle() {
        if (visible) { visible = false }
        else { visible = true; refresh() }
    }

    function refresh() {
        if (!fetcherProc.running) fetcherProc.running = true
        if (!uptimeProc.running)  uptimeProc.running  = true
        if (!mediaProc.running)   mediaProc.running   = true
        currentDate = new Date()
    }

    function runShell(cmd) {
        actionProc.command = ["sh", "-c", cmd]
        actionProc.running = true
    }

    // ── Processes ──────────────────────────────────────────────────────
    Process { id: actionProc }

    Process {
        id: fetcherProc
        command: ["python3", PathUtil.resolveFilePath("../../scripts/fetch_github.py")]
        onRunningChanged: if (!running && !githubProc.running) githubProc.running = true
    }

    Process {
        id: githubProc
        property string buf: ""
        command: ["python3", PathUtil.resolveFilePath("../../scripts/list_github.py")]
        stdout: SplitParser { onRead: data => githubProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                try {
                    var d = JSON.parse(buf)
                    root.githubUser = d.user
                    root.githubData = d.contributions
                    root.totalContributions = d.total
                } catch (e) { console.warn("Dashboard: bad github json") }
                buf = ""
            }
        }
    }

    Process {
        id: uptimeProc
        property string buf: ""
        command: ["sh", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: data => uptimeProc.buf += data }
        onRunningChanged: { if (!running && buf.length > 0) { root.uptime = buf.trim(); buf = "" } }
    }

    Process {
        id: mediaProc
        property string buf: ""
        command: ["sh", "-c",
            "s=$(playerctl status 2>/dev/null||echo Stopped);" +
            "t=$(playerctl metadata title 2>/dev/null||echo '');" +
            "a=$(playerctl metadata artist 2>/dev/null||echo '');" +
            "p=$(playerctl position 2>/dev/null||echo 0);" +
            "l=$(playerctl metadata mpris:length 2>/dev/null|awk '{printf \"%.0f\",$1/1000000}'||echo 0);" +
            "printf '%s|%s|%s|%s|%s\\n' \"$s\" \"$t\" \"$a\" \"$p\" \"$l\""
        ]
        stdout: SplitParser { onRead: data => mediaProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.mediaStatus   = p[0] || "Stopped"
                root.mediaTitle    = p[1] || "No media"
                root.mediaArtist   = p[2] || ""
                root.mediaPosition = p.length > 3 ? parseFloat(p[3]) : 0
                root.mediaLength   = p.length > 4 ? parseFloat(p[4]) : 0
                buf = ""
            }
        }
    }

    Timer { interval: 1500; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: if (!mediaProc.running) mediaProc.running = true
    }

    // ── Backdrop ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; color: "#000"
        opacity: root.visible ? 0.45 : 0
        Behavior on opacity { NumberAnimation { duration: 250 } }
        MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    }

    // ── Main Panel ────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 860; height: 640
        radius: 28
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        clip: true

        opacity: root.visible ? 1 : 0
        scale:   root.visible ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 300; easing.type: Easing.OutBack  } }

        // Two columns side by side, each with fixed pixel heights
        Row {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 24

            // ─────────── LEFT: Calendar + GitHub ──────────────────────
            Column {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                spacing: 20

                // Header
                Row {
                    width: parent.width
                    spacing: 14
                    Rectangle {
                        width: 48; height: 48; radius: 24
                        color: Theme.primaryContainer
                        Text { anchors.centerIn: parent; text: "󰄛"; font.family: Theme.iconFont; font.pixelSize: 24; color: Theme.primary }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: "Welcome, " + root.githubUser
                            color: Theme.fg; font.family: Theme.uiFont
                            font.pixelSize: 20; font.bold: true
                            width: parent.parent.width - 62; elide: Text.ElideRight
                        }
                        Text {
                            text: "Uptime: " + root.uptime
                            color: Theme.fgMuted; font.family: Theme.uiFont
                            font.pixelSize: 12
                        }
                    }
                }

                // Calendar card
                Rectangle {
                    width: parent.width; height: 310
                    radius: 20
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                    Column {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "CALENDAR"
                            color: Theme.fgMuted; font.family: Theme.monoFont
                            font.pixelSize: 10; font.letterSpacing: 2; font.bold: true
                        }

                        Text {
                            text: ["January","February","March","April","May","June",
                                   "July","August","September","October","November","December"][root.currentMonth] + " " + root.currentYear
                            color: Theme.fg; font.family: Theme.uiFont
                            font.pixelSize: 16; font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        // Day-of-week headers
                        Grid {
                            columns: 7; spacing: 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: ["S","M","T","W","T","F","S"]
                                delegate: Item {
                                    required property var modelData
                                    width: 42; height: 24
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData; color: Theme.fgMuted
                                        font.family: Theme.monoFont; font.pixelSize: 11; font.bold: true
                                    }
                                }
                            }
                        }

                        // Day cells
                        Grid {
                            columns: 7; spacing: 0
                            anchors.horizontalCenter: parent.horizontalCenter
                            Repeater {
                                model: 42
                                delegate: Item {
                                    required property int index
                                    width: 42; height: 36

                                    readonly property int dayOffset: index - new Date(root.currentYear, root.currentMonth, 1).getDay()
                                    readonly property int dayNumber: dayOffset + 1
                                    readonly property int daysInMonth: new Date(root.currentYear, root.currentMonth + 1, 0).getDate()
                                    readonly property bool isCurrentMonth: dayNumber > 0 && dayNumber <= daysInMonth
                                    readonly property bool isToday: isCurrentMonth && dayNumber === root.currentDate.getDate()

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32; height: 32; radius: 16
                                        color: isToday ? Theme.primary : "transparent"
                                        opacity: isCurrentMonth ? 1.0 : 0.0

                                        Text {
                                            anchors.centerIn: parent
                                            text: isCurrentMonth ? dayNumber : ""
                                            color: isToday ? Theme.primaryFg : Theme.fg
                                            font.family: Theme.monoFont
                                            font.pixelSize: 13; font.bold: isToday
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // GitHub card
                Rectangle {
                    width: parent.width
                    height: parent.height - 360 - 35 - 20 * 2 // remaining space
                    radius: 20
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                    Column {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 10

                        Row {
                            width: parent.width
                            Text {
                                text: "GITHUB"
                                color: Theme.fgMuted; font.family: Theme.monoFont
                                font.pixelSize: 10; font.letterSpacing: 2; font.bold: true
                            }
                            Item { width: parent.width - 150; height: 1 }
                            Text {
                                text: root.totalContributions + " contributions"
                                color: Theme.primary; font.family: Theme.monoFont
                                font.pixelSize: 11; font.bold: true
                            }
                        }

                        // Contribution grid
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Math.min(26, root.githubData.length)
                                delegate: Column {
                                    required property int index
                                    spacing: 3
                                    property var week: root.githubData[root.githubData.length - 1 - index]
                                    Repeater {
                                        model: 7
                                        delegate: Rectangle {
                                            required property int index
                                            width: 11; height: 11; radius: 2
                                            property int lvl: week ? week[index] : 0
                                            color: lvl === 0 ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06)
                                                 : lvl === 1 ? "#0e4429"
                                                 : lvl === 2 ? "#006d32"
                                                 : lvl === 3 ? "#26a641"
                                                 :             "#39d353"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────── RIGHT: Media + Notifications ─────────────────
            Column {
                width: (parent.width - parent.spacing) / 2
                height: parent.height
                spacing: 20

                // Media card
                Rectangle {
                    width: parent.width; height: 260
                    radius: 20
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                    Column {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "NOW PLAYING"
                            color: Theme.fgMuted; font.family: Theme.monoFont
                            font.pixelSize: 10; font.letterSpacing: 2; font.bold: true
                        }

                        Row {
                            width: parent.width; spacing: 14
                            Rectangle {
                                width: 72; height: 72; radius: 14
                                color: Theme.primaryContainer
                                Text { anchors.centerIn: parent; text: "󰎆"; font.family: Theme.iconFont; font.pixelSize: 30; color: Theme.primary }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                Text {
                                    text: root.mediaTitle; color: Theme.fg
                                    font.family: Theme.uiFont; font.pixelSize: 18; font.bold: true
                                    width: 240; elide: Text.ElideRight
                                }
                                Text {
                                    text: root.mediaArtist; color: Theme.fgMuted
                                    font.family: Theme.uiFont; font.pixelSize: 13
                                    width: 240; elide: Text.ElideRight
                                }
                            }
                        }

                        // Transport controls
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 36
                            Text {
                                text: "󰒮"; font.family: Theme.iconFont; font.pixelSize: 24; color: Theme.fg
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl previous") }
                            }
                            Text {
                                text: root.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                font.family: Theme.iconFont; font.pixelSize: 26; color: Theme.primary
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl play-pause") }
                            }
                            Text {
                                text: "󰒭"; font.family: Theme.iconFont; font.pixelSize: 24; color: Theme.fg
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl next") }
                            }
                        }

                        // Progress bar
                        Rectangle {
                            width: parent.width; height: 5; radius: 2.5
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                            Rectangle {
                                width: parent.width * (root.mediaLength > 0 ? Math.min(1, root.mediaPosition / root.mediaLength) : 0)
                                height: parent.height; radius: parent.radius; color: Theme.primary
                            }
                        }
                    }
                }

                // Notifications card
                Rectangle {
                    width: parent.width
                    height: parent.height - 295 - 20 // remaining space
                    radius: 20
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.65)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                    Column {
                        anchors.fill: parent; anchors.margins: 16
                        spacing: 10

                        Text {
                            text: "NOTIFICATIONS"
                            color: Theme.fgMuted; font.family: Theme.monoFont
                            font.pixelSize: 10; font.letterSpacing: 2; font.bold: true
                        }

                        Text {
                            visible: !root.notifier || root.notifier.history.length === 0
                            text: "No recent notifications"
                            color: Theme.fgMuted; font.family: Theme.uiFont; font.pixelSize: 13
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        ListView {
                            width: parent.width
                            height: parent.height - 30
                            model: root.notifier ? root.notifier.history : []
                            spacing: 10; clip: true

                            delegate: Row {
                                required property var modelData
                                width: parent ? parent.width : 0
                                spacing: 12
                                Rectangle { width: 3; height: 28; radius: 1.5; color: Theme.primary; opacity: 0.5 }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        text: modelData.title; color: Theme.fg
                                        font.family: Theme.uiFont; font.pixelSize: 13; font.bold: true
                                        elide: Text.ElideRight; width: 300
                                    }
                                    Text {
                                        text: modelData.body; color: Theme.fgMuted
                                        font.family: Theme.uiFont; font.pixelSize: 11
                                        elide: Text.ElideRight; width: 300
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
