// Clock.qml — Center-bar time and date display
// Top line: HH:mm  (updates every second)
// Bot line: Mon 07 Apr  (updates every minute)
pragma ComponentBehavior: Bound

import QtQuick
import "../theme"

Column {
    id: root
    spacing: 0

    Text {
        id: timeTxt
        anchors.horizontalCenter: parent.horizontalCenter
        color:          Theme.fg
        font.family:    Theme.monoFont
        font.pixelSize: 14
        font.bold:      true
    }

    Text {
        id: dateTxt
        anchors.horizontalCenter: parent.horizontalCenter
        color:          Theme.fgMuted
        font.family:    Theme.monoFont
        font.pixelSize: 10
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
            timeTxt.text = h + ":" + m

            var days   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            var months = ["Jan","Feb","Mar","Apr","May","Jun",
                          "Jul","Aug","Sep","Oct","Nov","Dec"]
            dateTxt.text = days[now.getDay()] + " " +
                           now.getDate().toString().padStart(2, "0") + " " +
                           months[now.getMonth()]
        }
    }
}
