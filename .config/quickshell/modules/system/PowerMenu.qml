pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    focusable: true
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1
    color: "transparent"

    property var notifier: null
    property int selectedIndex: 0

    readonly property var items: [
        { id: "lock", label: "Lock", sublabel: "Secure this session now" },
        { id: "suspend", label: "Suspend", sublabel: "Sleep until activity resumes" },
        { id: "logout", label: "Logout", sublabel: "Exit the current Hyprland session" },
        { id: "reboot", label: "Reboot", sublabel: "Restart the system" },
        { id: "shutdown", label: "Shutdown", sublabel: "Power off completely" }
    ]

    readonly property var selectedItem: items[selectedIndex]

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

    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    function toggle() {
        if (visible) closeMenu()
        else openMenu()
    }

    function openMenu() {
        visible = true
        selectedIndex = 0
    }

    function closeMenu() {
        visible = false
    }

    function moveSelection(delta) {
        selectedIndex = (selectedIndex + delta + items.length) % items.length
    }

    function invoke(actionId) {
        closeMenu()
        if (actionId === "lock")
            Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction lock")
        else if (actionId === "suspend")
            Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction suspend")
        else if (actionId === "logout")
            Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction logout")
        else if (actionId === "reboot")
            Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction reboot")
        else if (actionId === "shutdown")
            Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction shutdown")
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.72

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeMenu()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 640
        radius: 28
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
        implicitHeight: content.implicitHeight + 36

        MouseArea { anchors.fill: parent }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.moveSelection(-1)
                event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.moveSelection(1)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.closeMenu()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.invoke(root.selectedItem.id)
                event.accepted = true
            }
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            Text {
                text: "POWER"
                color: Theme.primary
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 4
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedItem.label
                color: Theme.fg
                font.family: Theme.uiFont
                font.pixelSize: 26
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedItem.sublabel
                color: Theme.fgMuted
                font.family: Theme.uiFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Repeater {
                    model: root.items

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 132
                        radius: 24
                        color: root.selectedIndex === index
                            ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.96)
                            : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.6)
                        border.width: 1
                        border.color: root.selectedIndex === index
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.42)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.16)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: modelData.label
                                color: root.selectedIndex === index ? Theme.primary : Theme.fg
                                font.family: Theme.uiFont
                                font.pixelSize: 16
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: (index + 1).toString()
                                color: Theme.fgMuted
                                font.family: Theme.monoFont
                                font.pixelSize: 11
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selectedIndex = index
                            onClicked: root.invoke(modelData.id)
                        }
                    }
                }
            }

            Text {
                text: "LEFT RIGHT or H L to move  •  ENTER to confirm  •  ESC to close"
                color: Theme.fgMuted
                font.family: Theme.monoFont
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
