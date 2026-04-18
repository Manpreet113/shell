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
        { id: "lock", label: "Lock", sublabel: "Secure session", icon: "󰌾" },
        { id: "suspend", label: "Suspend", sublabel: "Sleep mode", icon: "󰤄" },
        { id: "logout", label: "Logout", sublabel: "Exit Hyprland", icon: "󰗽" },
        { id: "reboot", label: "Reboot", sublabel: "Restart system", icon: "󰜉" },
        { id: "shutdown", label: "Power Off", sublabel: "Shut down", icon: "󰐥" }
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
            width: Math.min(840, parent.width - 64)
            radius: 40
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98)
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)
            implicitHeight: content.implicitHeight + 48

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        spacing: 2

                        Text {
                            text: "SYSTEM"
                            color: Theme.primary
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            font.letterSpacing: 6
                            font.bold: true
                        }

                        Text {
                            text: "Control center"
                            color: Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        implicitWidth: hintText.implicitWidth + 20
                        implicitHeight: 28
                        radius: 14
                        color: Qt.rgba(Theme.secondaryContainer.r, Theme.secondaryContainer.g, Theme.secondaryContainer.b, 0.4)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                        Text {
                            id: hintText
                            anchors.centerIn: parent
                            text: "Select: H/L or arrows • Confirm: Enter"
                            color: Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Repeater {
                        model: root.items

                        delegate: Rectangle {
                            id: itemRect
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 180
                            radius: 32
                            
                            color: root.selectedIndex === index
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                : "transparent"
                            
                            border.width: 1
                            border.color: root.selectedIndex === index
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 12

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    color: root.selectedIndex === index ? Theme.primary : Theme.fgMuted
                                    font.family: Theme.iconFont
                                    font.pixelSize: 42
                                    font.bold: true
                                    
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label
                                        color: root.selectedIndex === index ? Theme.fg : Theme.fgMuted
                                        font.family: Theme.uiFont
                                        font.pixelSize: 16
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.sublabel
                                        color: root.selectedIndex === index ? Theme.fgMuted : "transparent"
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                        horizontalAlignment: Text.AlignHCenter
                                        
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
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
