pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "../core"
import QtQuick.Effects

Item {
    id: root

    property var notifications: [] // Active popups
    property var history: []       // All recent notifications
    property int nextId: 1
    property string osdText: ""
    property int osdValue: 0
    property string osdIcon: ""
    property string osdMode: "text" // "text", "volume", "brightness"
    property bool osdVisible: false

    readonly property var overlayScreen: ScreenUtil.focusedScreen() || Quickshell.screens[0]

    NotificationServer {
        onNotification: n => {
            root.addNotification(n)
        }
    }

    function addNotification(n) {
        var entry = { 
            id: nextId++, 
            title: n.summary || "Notification", 
            body: n.body || "", 
            appName: n.appName || "",
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) 
        }
        notifications = [entry].concat(notifications).slice(0, 3)
        history = [entry].concat(history).slice(0, 50)
        notificationTimer.restart()
    }

    function notify(title, body) { addNotification({summary: title, body: body}) }

    function dismissPopup(id) {
        notifications = notifications.filter(n => n.id !== id)
    }

    function deleteFromHistory(id) {
        history = history.filter(n => n.id !== id)
    }

    function clearHistory() {
        history = []
    }

    function showOsd(text) {
        if (text.includes(":")) {
            var parts = text.split(":")
            if (parts[0] === "vol" || parts[0] === "br") {
                osdMode = parts[0] === "vol" ? "volume" : "brightness"
                osdValue = parseInt(parts[1])
                if (osdMode === "volume") {
                    osdIcon = osdValue === 0 ? "󰝟" : osdValue < 33 ? "󰕿" : osdValue < 66 ? "󰖀" : "󰕾"
                } else {
                    osdIcon = "󰃠"
                }
                osdVisible = true
                osdTimer.restart()
                return
            }
        }
        
        // Fallback to text mode
        osdMode = "text"
        osdText = text
        osdVisible = true
        osdTimer.restart()
    }

    Timer {
        id: notificationTimer
        interval: 4200
        repeat: false
        onTriggered: {
            if (root.notifications.length > 0) {
                root.notifications = root.notifications.slice(0, root.notifications.length - 1)
                if (root.notifications.length > 0) restart()
            }
        }
    }

    Timer {
        id: osdTimer
        interval: 2500
        repeat: false
        onTriggered: { root.osdVisible = false }
    }

    // ── Popup Windows ─────────────────────────────────────────────────
    PanelWindow {
        id: notificationWindow
        visible: root.notifications.length > 0
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: -1
        color: "transparent"
        screen: root.overlayScreen

        implicitWidth: Config.notificationWidth
        implicitHeight: notificationList.contentHeight

        anchors { top: true; right: true }
        margins { top: Config.notificationTopOffset; right: 18 }

        ListView {
            id: notificationList
            model: root.notifications
            spacing: 12
            width: Config.notificationWidth; height: 1000
            interactive: false; clip: false

            delegate: Rectangle {
                id: notificationDelegate
                required property var modelData

                width: Config.notificationWidth; height: implicitHeight
                radius: 20
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.85)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
                implicitHeight: mainLayout.implicitHeight + 35
                clip: true // to keep progress bar within rounded corners

                scale: hoverArea.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.dismissPopup(modelData.id)
                }

                RowLayout {
                    id: mainLayout
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 14
                    
                    // Icon Container
                    Rectangle {
                        Layout.alignment: Qt.AlignTop
                        width: 44; height: 44; radius: 22
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
                        Text {
                            anchors.centerIn: parent
                            text: modelData.appName.toLowerCase().includes("discord") ? "󰙯" :
                                  modelData.appName.toLowerCase().includes("capture") || modelData.appName.toLowerCase().includes("recording") ? "󰄀" : "󰂚"
                            font.family: Theme.iconFont; font.pixelSize: 22; color: Theme.primary
                        }
                    }
                    
                    // Text Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 15; font.bold: true; wrapMode: Text.WordWrap
                            }
                            Text {
                                text: "󰅖"
                                font.family: Theme.iconFont; font.pixelSize: 16; color: Theme.fgMuted
                                opacity: hoverArea.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }
                        Text {
                            Layout.fillWidth: true; visible: modelData.body.length > 0; text: modelData.body
                            color: Theme.fgMuted; font.family: Theme.uiFont; font.pixelSize: 13; wrapMode: Text.WordWrap
                        }
                    }
                }

                // Progress Bar
                Rectangle {
                    anchors { bottom: parent.bottom; bottomMargin: 2; left: parent.left; leftMargin: 16 }
                    height: 3
                    radius: 1.5
                    color: Theme.primary
                    
                    NumberAnimation on width {
                        from: notificationDelegate.width - 32
                        to: 0
                        duration: 4200
                        running: true
                    }
                }
            }

            add: Transition {
                NumberAnimation { property: "x"; from: Config.notificationWidth + 20; duration: 400; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
            }
            remove: Transition {
                NumberAnimation { property: "x"; to: Config.notificationWidth + 20; duration: 300; easing.type: Easing.InBack }
                NumberAnimation { property: "opacity"; to: 0; duration: 250 }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutBack }
            }
        }
    }

    PanelWindow {
        id: osdWindow
        visible: true
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: -1
        color: "transparent"
        screen: root.overlayScreen
        
        width: implicitWidth
        height: implicitHeight
        implicitWidth: root.osdMode === "text" ? osdLabel.implicitWidth + 40 : 48
        implicitHeight: root.osdMode === "text" ? 48 : 240
        
        anchors { 
            right: true
            top: true
        }
        
        margins { 
            right: root.osdMode === "text" ? (root.overlayScreen ? root.overlayScreen.width/2 - width/2 : 100) : (root.osdVisible ? 24 : -100)
            top: root.osdMode === "text" ? (root.overlayScreen ? root.overlayScreen.height - implicitHeight - Config.osdBottomOffset : 800) : (root.overlayScreen ? root.overlayScreen.height/2 - implicitHeight/2 : 300)
        }

        Behavior on margins.right { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

        // Main Container
        Rectangle {
            id: osdContent
            anchors.fill: parent
            radius: 24
            color: "transparent"
            clip: true

            // Glass Background (Only this is blurred)
            Rectangle {
                id: osdBg
                anchors.fill: parent
                radius: 24
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blurMax: 32
                    blur: 1.0
                    maskEnabled: true
                    maskSource: osdBg
                }
            }

            // Dark Overlay
            Rectangle {
                anchors.fill: parent
                radius: 24
                color: "black"
                opacity: 0.1
            }

            // --- TEXT MODE ---
            Text {
                id: osdLabel
                visible: root.osdMode === "text"
                anchors.centerIn: parent
                text: root.osdText
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 14; font.bold: true
            }

            // --- BAR MODE (Volume/Brightness) ---
            Column {
                visible: root.osdMode !== "text"
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Icon at the top
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.osdIcon
                    font.family: Theme.iconFont
                    font.pixelSize: 22
                    color: Theme.primary
                }

                // Vertical Progress Bar
                Rectangle {
                    width: 12
                    height: parent.height - 60
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 6
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.1)
                    
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.height * (Math.max(0, Math.min(100, root.osdValue)) / 100)
                        radius: 6
                        color: Theme.primary
                        
                        Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }

            opacity: root.osdVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }
    }
}
