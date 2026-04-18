pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

Item {
    id: root

    property var notifications: []
    property int nextId: 1
    property string osdText: ""
    property bool osdVisible: false

    readonly property var overlayScreen: {
        if (Quickshell.screens.length === 0)
            return null

        var focusedMonitor = Hyprland.focusedMonitor
        if (focusedMonitor && focusedMonitor.name) {
            for (var i = 0; i < Quickshell.screens.length; ++i) {
                var shellScreen = Quickshell.screens[i]
                if (shellScreen.name === focusedMonitor.name)
                    return shellScreen
            }
        }

        return Quickshell.screens[0]
    }

    function notify(title, body) {
        var entry = { id: nextId++, title: title, body: body || "" }
        notifications = [entry].concat(notifications).slice(0, 3)
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
        implicitHeight: notificationColumn.implicitHeight

        anchors {
            top: true
            right: true
        }

        margins {
            top: Config.notificationTopOffset
            right: 18
        }

        Column {
            id: notificationColumn
            spacing: 10

            Repeater {
                model: root.notifications

                delegate: Rectangle {
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
            anchors.fill: parent
            radius: 22
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)

            Text {
                id: osdLabel
                anchors.centerIn: parent
                text: root.osdText
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 14
                font.bold: true
            }
        }

        margins {
            bottom: Config.osdBottomOffset
        }
    }
}
