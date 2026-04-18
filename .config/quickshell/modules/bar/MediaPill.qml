pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../theme"
import "../core"

Rectangle {
    id: root

    property string mediaStatus: "Stopped"
    property string mediaTitle: ""
    property string mediaArtist: ""
    property real mediaPosition: 0
    property real mediaLength: 0
    property string mediaArtUrl: ""

    // State properties
    readonly property bool isPlaying: mediaStatus === "Playing" || mediaStatus === "Paused"
    
    visible: isPlaying // Hide entirely if nothing is playing or paused

    height: 32
    implicitWidth: layout.implicitWidth + 24
    radius: 16
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
    border.width: 1
    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
    clip: true

    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
    }

    // Blurred Background
    Image {
        id: bgImg
        anchors.fill: parent
        source: root.mediaArtUrl
        visible: false
    }

    Item {
        id: maskBg
        anchors.fill: parent
        visible:false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            color: "black"
            radius: 16
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: bgImg
        blurEnabled: true
        blurMax: 16
        blur: 1.0
        opacity: 0.4
        maskEnabled: true
        maskSource: maskBg
        visible: root.mediaArtUrl !== ""
        autoPaddingEnabled: false // This prevents the blur from expanding outside the anchors
    }

    // Dark Overlay for readability
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.mediaArtUrl !== "" ? 0.3 : 0
        radius: root.radius
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
            "art=$(playerctl metadata mpris:artUrl 2>/dev/null||echo '');" +
            "printf '%s|%s|%s|%s|%s|%s\\n' \"$s\" \"$t\" \"$a\" \"$p\" \"$l\" \"$art\""
        ]
        stdout: SplitParser { onRead: data => mediaProc.buf += data }
        onRunningChanged: {
            if (!running && buf.length > 0) {
                var p = buf.trim().split("|")
                root.mediaStatus   = p[0] || "Stopped"
                root.mediaTitle    = p[1] || ""
                root.mediaArtist   = p[2] || ""
                root.mediaPosition = p.length > 3 ? parseFloat(p[3]) : 0
                root.mediaLength   = p.length > 4 ? parseFloat(p[4]) : 0
                root.mediaArtUrl   = p.length > 5 ? p[5] : ""
                buf = ""
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!mediaProc.running) mediaProc.running = true
        }
    }

    Process { id: actionProc }
    function runShell(cmd) { actionProc.command = ["sh", "-c", cmd]; actionProc.running = true }

    RowLayout {
        id: layout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left; anchors.leftMargin: 6
        spacing: 10

        // Album Art Thumbnail
        Rectangle {
            width: 24; height: 24; radius: 12
            color: root.mediaArtUrl !== "" ? "transparent" : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            clip: true
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: thumbImg
                anchors.fill: parent
                source: root.mediaArtUrl
                fillMode: Image.PreserveAspectCrop
                visible: false
            }
            
            Rectangle {
                visible:false
                id: maskThumb
                layer.enabled: true
                anchors.fill: parent
                radius: 12
            }

            MultiEffect {
                anchors.fill: parent
                source: thumbImg
                maskEnabled: true
                maskSource: maskThumb
                visible: root.mediaArtUrl !== ""
            }            

            Text {
                anchors.centerIn: parent
                text: "󰎆"
                font.family: Theme.iconFont; font.pixelSize: 12
                color: Theme.primary
                visible: root.mediaArtUrl === ""
            }
        }

        // Title and Artist column
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.mediaTitle
                color: root.mediaArtUrl !== "" ? "white" : Theme.fg
                font.family: Theme.uiFont; font.pixelSize: 12; font.bold: true
                Layout.maximumWidth: hoverArea.containsMouse ? 150 : 120
                elide: Text.ElideRight
                Behavior on Layout.maximumWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            }

            Text {
                text: root.mediaArtist
                color: root.mediaArtUrl !== "" ? Qt.rgba(255, 255, 255, 0.7) : Theme.fgMuted
                font.family: Theme.uiFont; font.pixelSize: 9
                visible: hoverArea.containsMouse && root.mediaArtist !== ""
                Layout.maximumWidth: 150
                elide: Text.ElideRight
            }
        }

        // Expanded Controls
        RowLayout {
            visible: hoverArea.containsMouse
            spacing: 12
            Layout.leftMargin: 4
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: "󰒮"; font.family: Theme.iconFont; font.pixelSize: 14; color: root.mediaArtUrl !== "" ? "white" : Theme.fg
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl previous") }
            }
            Text {
                text: root.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                font.family: Theme.iconFont; font.pixelSize: 16; color: root.mediaArtUrl !== "" ? "white" : Theme.primary
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl play-pause") }
            }
            Text {
                text: "󰒭"; font.family: Theme.iconFont; font.pixelSize: 14; color: root.mediaArtUrl !== "" ? "white" : Theme.fg
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runShell("playerctl next") }
            }
        }
    }

    // Mini Progress Bar underneath when expanded
    Rectangle {
        anchors { bottom: parent.bottom; bottomMargin: 2; left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8 }
        height: 2
        radius: 1
        color: root.mediaArtUrl !== "" ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
        visible: hoverArea.containsMouse

        Rectangle {
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            width: parent.width * (root.mediaLength > 0 ? Math.min(1, root.mediaPosition / root.mediaLength) : 0)
            radius: 1
            color: root.mediaArtUrl !== "" ? "white" : Theme.primary
        }
    }
}

