// Workspaces.qml — Hyprland workspace row indicator
// Shows the IDs of all active workspaces. The one matching the focused
// monitor's active workspace is highlighted with the accent color.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../theme"

RowLayout {
    id: root
    spacing: 4

    Repeater {
        // Hyprland.workspaces is a live model — updates as workspaces open/close
        model: Hyprland.workspaces

        delegate: Item {
            required property var modelData   // HyprlandWorkspace instance

            // Is this workspace the currently focused one on any monitor?
            readonly property bool isActive:
                Hyprland.focusedMonitor !== null &&
                Hyprland.focusedMonitor.activeWorkspace !== null &&
                Hyprland.focusedMonitor.activeWorkspace.id === modelData.id

            implicitWidth:  label.implicitWidth + 14
            implicitHeight: 22

            // Subtle pill behind the active workspace
            Rectangle {
                anchors.fill: parent
                radius:       4
                color:        Theme.primaryContainer
                visible:      parent.isActive

                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Text {
                id: label
                anchors.centerIn: parent
                text:           modelData.id
                color:          parent.isActive ? Theme.primary : Theme.fgMuted
                font.family:    Theme.monoFont
                font.pixelSize: 12
                font.bold:      parent.isActive

                Behavior on color { ColorAnimation { duration: 100 } }
            }

            // Click to switch to this workspace
            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                onClicked:    Hyprland.dispatch("workspace " + modelData.id)
            }
        }
    }
}
