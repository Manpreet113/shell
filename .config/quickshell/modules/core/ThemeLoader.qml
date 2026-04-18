pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Item {
    id: root

    readonly property string colorFilePath: {
        var url = Qt.resolvedUrl("../../colors.json").toString()
        return url.startsWith("file://") ? url.substring(7) : url
    }

    FileView {
        id: colorFile
        path: root.colorFilePath
        watchChanges: true
        onFileChanged: root.reloadColors()
    }

    Process {
        id: catProcess
        property string rawJson: ""
        command: ["cat", root.colorFilePath]
        stdout: SplitParser {
            onRead: data => catProcess.rawJson += data
        }
        onExited: {
            debounceTimer.data = rawJson
            debounceTimer.restart()
        }
    }

    function reloadColors() {
        if (catProcess.running)
            return

        catProcess.rawJson = ""
        catProcess.running = true
    }

    Timer {
        id: debounceTimer
        property string data: ""
        interval: 10
        repeat: false
        onTriggered: {
            if (data.length < 10)
                return

            try {
                var json = JSON.parse(data)
                if (json.colors)
                    Theme.apply(json)
            } catch (e) {
                console.warn("[shell] JSON parse error: " + e)
            }
        }
    }

    Timer {
        id: startupTimer
        interval: 200
        repeat: false
        onTriggered: root.reloadColors()
    }

    Component.onCompleted: startupTimer.start()
}