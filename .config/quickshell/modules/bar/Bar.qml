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
    property var controlCenter: null
    property var dashboard: null
    property var notifier: null
    property string configPath: ""
    screen: modelData
    anchors {
        bottom: true
        left:   true
        right:  true
    }

    // Height of the bar in pixels
    implicitHeight: 54

    // Push windows up so they don't overlap the bar
    exclusiveZone: implicitHeight

    color: "transparent"

    // ─── Left Group: Workspaces + Window title ────────────────────────
    RowLayout {
        anchors {
            left: parent.left
            leftMargin: Config.barHorizontalPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: Config.panelSpacing

        Workspaces {}

        WindowTitle {
            Layout.maximumWidth: 340
        }
    }

    // ─── Center Group: Clock + Recording Indicator ────────────────────
    Row {
        anchors.centerIn: parent
        spacing: 12
        
        MediaPill {}

        RecordingIndicator {
            configPath: bar.configPath
        }
        
        Clock {
            dashboard: bar.dashboard
        }
    }

    // ─── Right Group: System tray ─────────────────────────────────────
    RowLayout {
        anchors {
            right: parent.right
            rightMargin: Config.barHorizontalPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: 6

        SysTray {
            controlCenter: bar.controlCenter
            notifier: bar.notifier
        }
    }
}
