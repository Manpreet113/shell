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

    // ─── Layer shell positioning ──────────────────────────────────────
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

        // ─── Main layout ──────────────────────────────────────────────
        RowLayout {
            anchors {
                fill:        parent
                leftMargin:  16
                rightMargin: 16
            }
            spacing: 0

            // ── Left: Workspaces + Window title ────────────────────────
            RowLayout {
                spacing: 8
                Layout.fillWidth:    false
                Layout.alignment:    Qt.AlignVCenter

                Workspaces {}

                // Separator dot
                Text {
                    text:           "·"
                    color:          Theme.outline
                    font.family:    Theme.monoFont
                    font.pixelSize: 12
                }

                WindowTitle {
                    Layout.maximumWidth: 260
                }
            }

            // ── Flexible spacer ────────────────────────────────────────
            Item { Layout.fillWidth: true }

            // ── Center: Clock ──────────────────────────────────────────
            Clock {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            }

            // ── Flexible spacer ────────────────────────────────────────
            Item { Layout.fillWidth: true }

            // ── Right: System tray ─────────────────────────────────────
            SysTray {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
