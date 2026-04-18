// Clock.qml — Center-bar time and date display
// Top line: HH:mm  (updates every second)
// Bot line: Mon 07 Apr  (updates every minute)
pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

Column {
    id: root
    property string timeText: ""
    property string dateText: ""
    property var dashboard: null
    readonly property bool dashboardOpen: dashboard && dashboard.visible
    spacing: 0

    Rectangle {
        id: pill
        implicitHeight: 32
        implicitWidth: clockRow.implicitWidth + (hoverArea.containsMouse || root.dashboardOpen ? 40 : 24)
        radius: implicitHeight / 2
        color: root.dashboardOpen 
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.95)
            : hoverArea.containsMouse
                ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.96)
                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.86)
        
        border.width: 1
        border.color: root.dashboardOpen
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)

        Behavior on implicitWidth { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: root.timeText
                color: root.dashboardOpen ? Theme.primaryFg : Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: root.dateText
                color: root.dashboardOpen ? Qt.rgba(Theme.primaryFg.r, Theme.primaryFg.g, Theme.primaryFg.b, 0.7) : Theme.fgMuted
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (root.dashboard) root.dashboard.toggle()
        }
    }

    // Update on every tick
    Timer {
        interval:         1000
        running:          true
        repeat:           true
        triggeredOnStart: true
        onTriggered: {
            var now     = new Date()
            var h       = now.getHours().toString().padStart(2, "0")
            var m       = now.getMinutes().toString().padStart(2, "0")
            root.timeText = h + ":" + m

            var days   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            var months = ["Jan","Feb","Mar","Apr","May","Jun",
                          "Jul","Aug","Sep","Oct","Nov","Dec"]
            root.dateText = days[now.getDay()] + " " +
                            now.getDate().toString().padStart(2, "0") + " " +
                            months[now.getMonth()]
        }
    }
}
