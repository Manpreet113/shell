pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
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
    property int selectedIndex: 0

    readonly property var items: [
        { id: "lock", label: "Lock", sublabel: "Secure this session now" },
        { id: "suspend", label: "Suspend", sublabel: "Sleep until activity resumes" },
        { id: "logout", label: "Logout", sublabel: "Exit the current Hyprland session" },
        { id: "reboot", label: "Reboot", sublabel: "Restart the system" },
        { id: "shutdown", label: "Shutdown", sublabel: "Power off completely" }
    ]

    readonly property var selectedItem: items[selectedIndex]
    readonly property var overlayScreen: ScreenUtil.focusedScreen()

    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    onVisibleChanged: {
        if (visible)
            menuFocus.forceActiveFocus()
    }

    function toggle() {
        if (visible)
            closeMenu()
        else
            openMenu()
    }

    function openMenu() {
        visible = true
        selectedIndex = 0
        menuFocus.forceActiveFocus()
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

    FocusScope {
        id: menuFocus
        anchors.fill: parent
        focus: true

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

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.74

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeMenu()
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(760, parent.width - 48)
            radius: 32
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            implicitHeight: content.implicitHeight + 36

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 22
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: "POWER"
                            color: Theme.primary
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            font.letterSpacing: 4
                        }

                        Text {
                            text: "Select an action"
                            color: Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: hintText.implicitWidth + 18
                        implicitHeight: 26
                        radius: 13
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.62)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: "H/L or arrows"
                            color: Theme.fgMuted
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.selectedItem.label
                    color: Theme.fg
                    font.family: Theme.uiFont
                    font.pixelSize: 30
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
                            implicitHeight: root.selectedIndex === index ? 140 : 118
                            radius: 24
                            color: root.selectedIndex === index
                                ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.98)
                                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.42)
                            border.width: 1
                            border.color: root.selectedIndex === index
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 34
                                    implicitHeight: 34
                                    radius: 17
                                    color: root.selectedIndex === index
                                        ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
                                        : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.48)
                                    border.width: 1
                                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)

                                    Text {
                                        anchors.centerIn: parent
                                        text: (index + 1).toString()
                                        color: root.selectedIndex === index ? Theme.primary : Theme.fgMuted
                                        font.family: Theme.monoFont
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: root.selectedIndex === index ? Theme.primary : Theme.fg
                                    font.family: Theme.uiFont
                                    font.pixelSize: 15
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: root.selectedIndex === index
                                    text: modelData.sublabel
                                    color: Theme.fgMuted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
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
            }
        }
    }
}
