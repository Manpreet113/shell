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
    spacing: 0

    Rectangle {
        implicitHeight: 32
        implicitWidth: clockRow.implicitWidth + 24
        radius: implicitHeight / 2
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.86)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)

        Row {
            id: clockRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: root.timeText
                color: Theme.fg
                font.family: Theme.monoFont
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: root.dateText
                color: Theme.fgMuted
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
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
