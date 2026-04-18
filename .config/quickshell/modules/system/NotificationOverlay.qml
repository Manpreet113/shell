pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../core"

Item {
    id: root

    property var notifications: []
    property var history: []
    property int nextId: 1
    property string osdText: ""
    property bool osdVisible: false

    readonly property var overlayScreen: {
        return ScreenUtil.focusedScreen()
    }

    function notify(title, body) {
        var entry = { 
            id: nextId++, 
            title: title, 
            body: body || "", 
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) 
        }
        notifications = [entry].concat(notifications).slice(0, 3)
        history = [entry].concat(history).slice(0, 50)
        notificationTimer.restart()
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
            if (root.notifications.length === 0)
                return

            root.notifications = root.notifications.slice(0, root.notifications.length - 1)
            if (root.notifications.length > 0)
                restart()
        }
    }

    Timer {
        id: osdTimer
        interval: 1600
        repeat: false
        onTriggered: {
            root.osdVisible = false
            root.osdText = ""
        }
    }

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

        anchors {
            top: true
            right: true
        }

        margins {
            top: Config.notificationTopOffset
            right: 18
        }

        ListView {
            id: notificationList
            model: root.notifications
            spacing: 10
            width: Config.notificationWidth
            height: 1000 // Just a tall container
            interactive: false
            clip: false

            delegate: Rectangle {
                id: notificationDelegate
                required property var modelData

                width: Config.notificationWidth
                radius: 18
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                implicitHeight: content.implicitHeight + 24

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: modelData.body.length > 0
                        text: modelData.body
                        color: Theme.fgMuted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
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

        anchors {
            bottom: true
        }

        Rectangle {
            id: osdContent
            anchors.fill: parent
            radius: 22
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
            opacity: 0
            scale: 0.8

            Text {
                id: osdLabel
                anchors.centerIn: parent
                text: root.osdText
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 14
                font.bold: true
            }

            states: State {
                name: "visible"
                when: root.osdVisible
                PropertyChanges { target: osdContent; opacity: 1; scale: 1 }
            }

            transitions: Transition {
                NumberAnimation { properties: "opacity,scale"; duration: 250; easing.type: Easing.OutBack }
            }
        }

        margins {
            bottom: Config.osdBottomOffset
        }
    }
}
