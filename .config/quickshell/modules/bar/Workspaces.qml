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
    spacing: 6

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

            implicitWidth:  label.implicitWidth + 20
            implicitHeight: 28

            Rectangle {
                anchors.fill: parent
                radius:       height / 2
                color: parent.isActive
                       ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.95)
                       : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.8)
                border.width: 1
                border.color: parent.isActive
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)

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
