pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../theme"
import "../core"

Item {
    id: root

    property var notifications: [] // Active popups
    property var history: []       // All recent notifications
    property int nextId: 1
    property string osdText: ""
    property bool osdVisible: false

    readonly property var overlayScreen: ScreenUtil.focusedScreen()

    NotificationServer {
        onNotification: n => {
            root.addNotification(n.summary, n.body)
        }
    }

    function addNotification(title, body) {
        var entry = { 
            id: nextId++, 
            title: title || "Notification", 
            body: body || "", 
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) 
        }
        notifications = [entry].concat(notifications).slice(0, 3)
        history = [entry].concat(history).slice(0, 50)
        notificationTimer.restart()
    }

    function notify(title, body) { addNotification(title, body) }

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
        interval: 1600
        repeat: false
        onTriggered: { root.osdVisible = false; root.osdText = "" }
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
            spacing: 10
            width: Config.notificationWidth; height: 1000
            interactive: false; clip: false

            delegate: Rectangle {
                id: notificationDelegate
                required property var modelData

                width: Config.notificationWidth; radius: 18
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                implicitHeight: content.implicitHeight + 24

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.dismissPopup(modelData.id)
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent; anchors.margins: 14; spacing: 4
                    Text {
                        Layout.fillWidth: true; text: modelData.title
                        color: Theme.fg; font.family: Theme.uiFont; font.pixelSize: 14; font.bold: true; wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true; visible: modelData.body.length > 0; text: modelData.body
                        color: Theme.fgMuted; font.family: Theme.uiFont; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
            }

            add: Transition {
                NumberAnimation { property: "x"; from: Config.notificationWidth; duration: 400; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
            }
            remove: Transition {
                NumberAnimation { property: "x"; to: Config.notificationWidth; duration: 300; easing.type: Easing.InBack }
                NumberAnimation { property: "opacity"; to: 0; duration: 250 }
            }
            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutBack }
            }
        }
    }

    PanelWindow {
        id: osdWindow
        visible: root.osdVisible
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        exclusiveZone: -1
        color: "transparent"
        screen: root.overlayScreen
        implicitWidth: osdLabel.implicitWidth + 34
        implicitHeight: osdLabel.implicitHeight + 22
        anchors { bottom: true }
        margins { bottom: Config.osdBottomOffset }

        Rectangle {
            id: osdContent
            anchors.fill: parent; radius: 22
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
            border.width: 1; border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
            opacity: root.osdVisible ? 1 : 0
            scale:   root.osdVisible ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Behavior on scale   { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

            Text {
                id: osdLabel; anchors.centerIn: parent; text: root.osdText
                color: Theme.fg; font.family: Theme.monoFont; font.pixelSize: 14; font.bold: true
            }
        }
    }
}
