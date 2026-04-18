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
        { id: "lock",     label: "Lock",      sublabel: "Secure session",  icon: "󰌾" },
        { id: "suspend",  label: "Suspend",   sublabel: "Sleep mode",      icon: "󰤄" },
        { id: "logout",   label: "Logout",    sublabel: "Exit Hyprland",   icon: "󰗽" },
        { id: "reboot",   label: "Reboot",    sublabel: "Restart system",  icon: "󰜉" },
        { id: "shutdown", label: "Power Off", sublabel: "Shut down",       icon: "󰐥" }
    ]

    readonly property var selectedItem: items[selectedIndex]
    readonly property var overlayScreen: ScreenUtil.focusedScreen()

    screen: overlayScreen
    anchors { top: true; right: true; left: true; bottom: true }

    onVisibleChanged: if (visible) menuFocus.forceActiveFocus()

    function toggle() { if (visible) closeMenu(); else openMenu() }
    function openMenu() { visible = true; selectedIndex = 0; menuFocus.forceActiveFocus() }
    function closeMenu() { visible = false }
    function moveSelection(delta) { selectedIndex = (selectedIndex + delta + items.length) % items.length }

    function invoke(actionId) {
        closeMenu()
        Hyprland.dispatch("exec qs -p ~/.config/quickshell ipc call shell powerAction " + actionId)
    }

    FocusScope {
        id: menuFocus
        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                root.moveSelection(-1); event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                root.moveSelection(1); event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root.closeMenu(); event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.invoke(root.selectedItem.id); event.accepted = true
            }
        }

        // ── Backdrop ──────────────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: root.visible ? 0.7 : 0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
        }

        // ── Floating panel ────────────────────────────────────────────
        Item {
            id: panel
            anchors.centerIn: parent
            width: 740; height: panelContent.height

            opacity: root.visible ? 1 : 0
            scale:   root.visible ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 350; easing.type: Easing.OutBack  } }

            Column {
                id: panelContent
                width: parent.width
                spacing: 28

                // Title
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "What would you like to do?"
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 26; font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "← →  Navigate  ·  Enter  Confirm  ·  Esc  Cancel"
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.3)
                        font.family: Theme.monoFont; font.pixelSize: 11
                    }
                }

                // Action cards
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14

                    Repeater {
                        model: root.items
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: 128; height: 160; radius: 24

                            property bool isSel: root.selectedIndex === index

                            color: isSel
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.5)

                            border.width: isSel ? 2 : 1
                            border.color: isSel
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.1)

                            scale: isSel ? 1.06 : 1.0

                            Behavior on color       { ColorAnimation  { duration: 200 } }
                            Behavior on border.color { ColorAnimation  { duration: 200 } }
                            Behavior on scale        { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 12

                                // Icon circle
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 52; height: 52; radius: 26
                                    color: isSel
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                                    border.width: 1
                                    border.color: isSel
                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                        : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.06)

                                    Behavior on color       { ColorAnimation { duration: 200 } }
                                    Behavior on border.color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: isSel ? Theme.primary : Theme.fgMuted
                                        font.family: Theme.iconFont; font.pixelSize: 24
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                // Labels
                                Column {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 2

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label
                                        color: isSel ? Theme.fg : Theme.fgMuted
                                        font.family: Theme.uiFont; font.pixelSize: 14; font.bold: true
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.sublabel
                                        color: isSel ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45) : "transparent"
                                        font.family: Theme.uiFont; font.pixelSize: 10
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = index
                                onClicked: root.invoke(modelData.id)
                            }
                        }
                    }
                }

                // Confirmation pill
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: confirmRow.width + 28; height: 40; radius: 20
                    color: Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.5)
                    border.width: 1
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)

                    Row {
                        id: confirmRow
                        anchors.centerIn: parent; spacing: 8
                        Text {
                            text: root.selectedItem.icon
                            color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Press Enter to " + root.selectedItem.label
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.55)
                            font.family: Theme.uiFont; font.pixelSize: 12
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.invoke(root.selectedItem.id)
                    }
                }
            }
        }
    }
}
