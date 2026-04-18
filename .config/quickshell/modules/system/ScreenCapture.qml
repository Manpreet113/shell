pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "../core"

PanelWindow {
    id: root

    focusable: true
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1
    color: "transparent"

    property string captureAction: "copy" // "copy", "save", "both"
    property bool isRecording: false
    property string configPath: ""

    readonly property var overlayScreen: ScreenUtil.focusedScreen()
    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    // Use absolute path for reliability
    readonly property string scriptPath: root.configPath + "/scripts/capture.sh"

    function toggle() {
        if (visible) closeMenu()
        else openMenu()
    }

    function openMenu() {
        visible = true
        checkRecordingStatus()
    }

    function closeMenu() {
        visible = false
    }

    function checkRecordingStatus() {
        recordingCheckProc.running = true
    }

    function runCapture(mode) {
        var cmd = "sh " + scriptPath + " " + mode
        if (mode !== "stop" && mode !== "picker") {
            cmd += " " + captureAction
        }
        
        console.log("[ScreenCapture] Running command: " + cmd)
        Hyprland.dispatch("exec " + cmd)
        
        if (mode !== "stop") closeMenu()
    }

    Process {
        id: recordingCheckProc
        command: ["sh", "-c", "pgrep -x gpu-screen-reco > /dev/null && echo 1 || echo 0"]
        stdout: SplitParser {
            onRead: data => {
                root.isRecording = (data.trim() === "1")
            }
        }
    }

    // ── UI Components ──────────────────────────────────────────────────
    component CaptureTile: Rectangle {
        property string icon: ""
        property string label: ""
        property string sublabel: ""
        property color accent: Theme.primary
        signal clicked()

        width: 160; height: 180; radius: 24
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)

        Column {
            anchors.centerIn: parent
            spacing: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64; height: 64; radius: 32
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: parent.parent.parent.icon
                    color: accent
                    font.family: Theme.iconFont
                    font.pixelSize: 28
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.parent.parent.label
                    color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 15; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.parent.parent.sublabel
                    color: Theme.fgMuted; font.family: Theme.uiFont; font.pixelSize: 10
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: parent.scale = 1.05
            onExited: parent.scale = 1.0
            onClicked: parent.clicked()
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000"
        opacity: root.visible ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
    }

    // ── Panel ─────────────────────────────────────────────────────
    Item {
        anchors.centerIn: parent
        width: 760; height: panelCol.height

        opacity: root.visible ? 1 : 0
        scale:   root.visible ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 350; easing.type: Easing.OutBack  } }

        Column {
            id: panelCol
            width: parent.width
            spacing: 32

            // Header
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Capture Utility"
                    color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 32; font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Select a mode to capture your screen or recording"
                    color: Theme.fgMuted; font.family: Theme.uiFont; font.pixelSize: 14
                }
            }

            // Options Bar (Save/Copy)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                
                Repeater {
                    model: [
                        { id: "copy", label: "Copy to Clipboard", icon: "󰆏" },
                        { id: "save", label: "Save to File", icon: "󰆓" },
                        { id: "both", label: "Save & Copy", icon: "󰆑" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 160; height: 40; radius: 20
                        color: root.captureAction === modelData.id 
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.4)
                        border.width: 1
                        border.color: root.captureAction === modelData.id 
                            ? Theme.primary
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)
                        
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: modelData.icon; font.family: Theme.iconFont; font.pixelSize: 14; color: root.captureAction === modelData.id ? Theme.primary : Theme.fgMuted }
                            Text { text: modelData.label; font.family: Theme.uiFont; font.pixelSize: 12; color: root.captureAction === modelData.id ? Theme.fg : Theme.fgMuted }
                        }

                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.captureAction = modelData.id }
                    }
                }
            }

            // Capture Grid
            Flow {
                width: parent.width
                spacing: 20
                Layout.alignment: Qt.AlignHCenter

                CaptureTile {
                    icon: "󰆟"; label: "Capture Area"; sublabel: "Select region"; accent: "#c8b3fa"
                    onClicked: root.runCapture("area")
                }
                CaptureTile {
                    icon: "󰹑"; label: "Capture Screen"; sublabel: "Full display"; accent: "#9cd49f"
                    onClicked: root.runCapture("screen")
                }
                CaptureTile {
                    icon: "󰖭"; label: "Capture Window"; sublabel: "Select a window"; accent: "#a1ced6"
                    onClicked: root.runCapture("window")
                }

                CaptureTile {
                    icon: "󰈋"; label: "Color Picker"; sublabel: "Pick a hex color"; accent: "#f5d0fe"
                    onClicked: root.runCapture("picker")
                }
                
                // Recording divider / text
                Item { width: parent.width; height: 1 }

                CaptureTile {
                    visible: !root.isRecording
                    icon: "󰑋"; label: "Record Area"; sublabel: "Start MP4 record"; accent: "#ffb4ab"
                    onClicked: root.runCapture("record_area")
                }
                CaptureTile {
                    visible: !root.isRecording
                    icon: "󰕧"; label: "Record Screen"; sublabel: "Entire desktop"; accent: "#ffb4ab"
                    onClicked: root.runCapture("record_screen")
                }
                CaptureTile {
                    visible: root.isRecording
                    width: parent.width - 20
                    icon: "󰐊"; label: "Stop Recording"; sublabel: "Save and finish"; accent: "#ef4444"
                    onClicked: root.runCapture("stop")
                }
            }
        }
    }
}
