pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"

Rectangle {
    id: root
    
    property bool active: false
    property int seconds: 0
    property string configPath: ""
    
    visible: active
    height: 32
    width: active ? (label.implicitWidth + 44) : 0
    radius: 16
    color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.15)
    border.width: 1
    border.color: Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.3)
    
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
    
    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: checkProc.running = true
    }
    
    Timer {
        id: durationTimer
        interval: 1000
        running: root.active
        repeat: true
        onTriggered: root.seconds++
    }
    
    Process {
        id: checkProc
        command: ["sh", "-c", "pgrep -x gpu-screen-reco > /dev/null && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                var isNowActive = (data.trim() === "1")
                if (isNowActive && !root.active) {
                    root.seconds = 0 // Reset duration on start
                }
                root.active = isNowActive
            }
        }
    }
    
    function formatTime(s) {
        var mins = Math.floor(s / 60)
        var secs = s % 60
        return (mins < 10 ? "0" : "") + mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    
    Row {
        anchors.centerIn: parent
        spacing: 8
        
        Rectangle {
            width: 8; height: 8; radius: 4
            color: Theme.error
            anchors.verticalCenter: parent.verticalCenter
            
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 800 }
                NumberAnimation { from: 0.3; to: 1; duration: 800 }
            }
        }
        
        Text {
            id: label
            text: "REC " + root.formatTime(root.seconds)
            color: Theme.error
            font.family: Theme.monoFont
            font.pixelSize: 12
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            console.log("[Indicator] Stopping with scriptPath: " + root.scriptPath)
            root.active = false
            stopProc.running = true
        }
    }
    
    readonly property string scriptPath: root.configPath + "/scripts/capture.sh"

    Process {
        id: stopProc
        command: ["sh", root.scriptPath, "stop"]
    }
}
