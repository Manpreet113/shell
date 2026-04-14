// Bar.qml — Bottom panel bar
// A PanelWindow anchored to the bottom of the assigned monitor.
// Layout: [Workspaces · WindowTitle]   [Clock]   [VOL · NET · BAT]
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../theme"

PanelWindow {
    id: bar

    required property var modelData // Provided by Variants
    screen: modelData
    anchors {
        bottom: true
        left:   true
        right:  true
    }

    // Height of the bar in pixels
    implicitHeight: 38

    // Push windows up so they don't overlap the bar
    exclusiveZone: implicitHeight

    // Transparent — the Rectangle below is the visible surface
    color: "transparent"

    // ─── Bar surface ──────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(
            Theme.surface.r,
            Theme.surface.g,
            Theme.surface.b,
            0.92            // Slight transparency — adjust to taste
        )

        // Top border: a 1px line at the very top edge of the bar
        Rectangle {
            anchors.top:   parent.top
            width:         parent.width
            height:        1
            color:         Theme.outline
            opacity:       0.4
        }

        // ─── Left Group: Workspaces + Window title ────────────────────────
        RowLayout {
            anchors {
                left: parent.left
                leftMargin: 16
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Workspaces {}

            // Separator dot
            Text {
                text: "·"
                color: Theme.outline
                font.family: Theme.monoFont
                font.pixelSize: 12
            }

            WindowTitle {
                Layout.maximumWidth: 260
            }
        }

        // ─── Center Group: Clock (Absolute Centering) ────────────────────
        Clock {
            anchors.centerIn: parent
        }

        // ─── Right Group: System tray ─────────────────────────────────────
        RowLayout {
            anchors {
                right: parent.right
                rightMargin: 16
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            SysTray {}
        }
    }
}
