// Launcher.qml — Multi-mode command palette for apps, actions, and emoji
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../core"

PanelWindow {
    id: root

    focusable: true
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay

    property var notifier: null
    property var wallpaperSelector: null

    property var allApps: []
    property var allEmojis: []
    property var recentApps: []
    property string appBuffer: ""
    property string emojiBuffer: ""
    property int selectedIndex: 0

    readonly property string currentMode: {
        var text = searchField.text.trim()
        if (text.startsWith(":"))
            return "emoji"
        if (text.startsWith(">"))
            return "actions"
        return "apps"
    }

    readonly property string queryText: {
        var text = searchField.text.trim()
        if (currentMode === "emoji" || currentMode === "actions")
            text = text.replace(/^[:>]\s*/, "")
        return text.toLowerCase().trim()
    }

    readonly property var actionItems: ShellActions.actionItems

    readonly property var activeItems: {
        var query = queryText

        // --- Calculator Mode ---
        if (query.length > 0 && (query.startsWith("=") || (/^[0-9+\-*/().\s]+$/.test(query) && query.match(/[+\-*/]/)))) {
            var expr = query.startsWith("=") ? query.substring(1).trim() : query.trim()
            try {
                // Basic safety check for eval
                if (/^[0-9+\-*/().\s]+$/.test(expr)) {
                    var result = eval(expr)
                    if (typeof result === "number" && !isNaN(result)) {
                        return [{
                            type: "calc",
                            name: "= " + result,
                            subtitle: "Calculator: " + expr,
                            searchKey: "",
                            value: result.toString()
                        }]
                    }
                }
            } catch (e) {}
        }

        var source = currentMode === "emoji" ? allEmojis
            : currentMode === "actions" ? actionItems
            : allApps

        if (query.length === 0) {
            if (currentMode === "apps" && recentApps.length > 0)
                return recentApps.concat(source)
            return source
        }

        return source.filter(item => {
            if (item.searchKey)
                return item.searchKey.indexOf(query) !== -1

            var haystack = [item.name || "", item.subtitle || "", item.keywords || ""].join(" ").toLowerCase()
            return haystack.indexOf(query) !== -1
        })
    }

    readonly property var selectedEntry: {
        if (selectedIndex < 0 || selectedIndex >= activeItems.length)
            return null
        return activeItems[selectedIndex]
    }

    readonly property string headerLabel: currentMode === "emoji" ? "EMOJI" : currentMode === "actions" ? "ACTIONS" : "COMMAND"
    readonly property string searchPrompt: currentMode === "emoji"
        ? "Search emoji by name or mood"
        : currentMode === "actions"
            ? "Search shell actions"
            : "Type an app name"

    readonly property var overlayScreen: {
        return ScreenUtil.focusedScreen()
    }

    readonly property string listAppsScript: {
        return PathUtil.resolveFilePath("../../scripts/list_apps.py")
    }

    readonly property string listEmojisScript: {
        return PathUtil.resolveFilePath("../../scripts/list_emojis.py")
    }

    screen: overlayScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    function toggle() {
        if (visible) _close()
        else _open()
    }

    function _open() {
        appBuffer = ""
        emojiBuffer = ""
        visible = true
        selectedIndex = 0
        if (!searchField.text.startsWith(":") && !searchField.text.startsWith(">"))
            searchField.text = ""
        appLoader.running = true
        
        if (currentMode === "emoji")
            loadEmojis()

        searchField.forceActiveFocus()
    }

    function loadEmojis() {
        if (allEmojis.length > 0 || emojiLoader.running)
            return
        emojiLoader.running = true
    }

    onCurrentModeChanged: {
        if (currentMode === "emoji") {
            loadEmojis()
        }
    }

    function _close() {
        visible = false
    }

    function shellQuote(text) {
        return "'" + text.replace(/'/g, "'\\''") + "'"
    }

    function setMode(mode) {
        if (mode === "emoji")
            searchField.text = ": "
        else if (mode === "actions")
            searchField.text = "> "
        else
            searchField.text = ""
        selectedIndex = 0
        searchField.forceActiveFocus()
    }

    function syncSelection() {
        if (activeItems.length === 0) {
            selectedIndex = -1
            resultList.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= activeItems.length)
            selectedIndex = 0

        resultList.currentIndex = selectedIndex
        resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function moveSelection(delta) {
        if (activeItems.length === 0)
            return

        if (selectedIndex < 0)
            selectedIndex = 0
        else
            selectedIndex = (selectedIndex + delta + activeItems.length) % activeItems.length

        syncSelection()
    }

    function onQueryChanged() {
        syncSelection()
    }

    function activateSelected() {
        if (selectedEntry)
            activateEntry(selectedEntry)
    }

    function activateEntry(entry) {
        if (!entry)
            return

        if (entry.type === "app") {
            // Track recent apps
            var updatedRecent = [entry].concat(root.recentApps.filter(a => a.name !== entry.name)).slice(0, 5)
            root.recentApps = updatedRecent

            Hyprland.dispatch("exec " + entry.exec)
            _close()
            return
        }

        if (entry.type === "calc") {
            copyProc.command = ["sh", "-c", "printf %s " + shellQuote(entry.value) + " | wl-copy"]
            copyProc.running = true
            if (notifier) {
                notifier.showOsd("Result copied: " + entry.value)
            }
            _close()
            return
        }

        if (entry.type === "emoji") {
            copyProc.command = ["sh", "-c", "printf %s " + shellQuote(entry.emoji) + " | wl-copy"]
            copyProc.running = true
            if (notifier) {
                notifier.showOsd(entry.emoji + " copied")
                notifier.notify("Emoji copied", entry.emoji + "  " + entry.name)
            }
            _close()
            return
        }

        ShellActions.activate(entry, {
            notifier: notifier,
            wallpaperSelector: wallpaperSelector,
            close: _close,
            setMode: setMode,
            dispatch: command => Hyprland.dispatch(command)
        })
    }

    Process {
        id: appLoader
        command: ["python3", root.listAppsScript]
        stdout: SplitParser { onRead: data => root.appBuffer += data }
        onRunningChanged: {
            if (!running && root.appBuffer.length > 0) {
                try {
                    var items = JSON.parse(root.appBuffer)
                    root.allApps = items.map(item => ({
                        type: "app",
                        name: item.name,
                        subtitle: item.exec,
                        keywords: item.exec,
                        exec: item.exec,
                        searchKey: (item.name + " " + item.exec).toLowerCase()
                    }))
                    root.onQueryChanged()
                } catch (e) {
                    console.warn("[launcher] Failed to parse apps:", e)
                }
                root.appBuffer = ""
            }
        }
    }

    Process {
        id: emojiLoader
        command: ["python3", root.listEmojisScript]
        stdout: SplitParser { onRead: data => root.emojiBuffer += data }
        onRunningChanged: {
            if (!running && root.emojiBuffer.length > 0) {
                try {
                    var items = JSON.parse(root.emojiBuffer)
                    root.allEmojis = items.map(item => {
                        var kw = item.keywords.join(" ")
                        return {
                            type: "emoji",
                            emoji: item.emoji,
                            name: item.name,
                            subtitle: item.keywords.join(", "),
                            keywords: kw,
                            searchKey: (item.name + " " + kw).toLowerCase()
                        }
                    })
                    root.onQueryChanged()
                } catch (e) {
                    console.warn("[launcher] Failed to parse emoji list:", e)
                }
                root.emojiBuffer = ""
            }
        }
    }

    Process {
        id: copyProc
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.65

        MouseArea {
            anchors.fill: parent
            onClicked: root._close()
        }
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Config.launcherWidth
        height: Math.min(Config.launcherMaxHeight, parent.height - Config.launcherHeightMargin)

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
                text: root.headerLabel
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9)
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 4
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: [
                        { mode: "apps", label: "Apps" },
                        { mode: "actions", label: "Actions" },
                        { mode: "emoji", label: "Emoji" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: modeLabel.implicitWidth + 18
                        implicitHeight: 28
                        radius: implicitHeight / 2
                        color: root.currentMode === modelData.mode
                            ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.92)
                            : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.42)
                        border.width: 1
                        border.color: root.currentMode === modelData.mode
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.currentMode === modelData.mode ? Theme.primary : Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.setMode(modelData.mode)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                radius: implicitHeight / 2
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.26)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 16

                    Text {
                        text: root.currentMode === "emoji" ? ":" : root.currentMode === "actions" ? ">" : ">"
                        color: Theme.primary
                        font.family: Theme.monoFont
                        font.pixelSize: 24
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 22
                        font.weight: 600
                        selectionColor: Theme.primaryContainer
                        clip: true

                        onTextChanged: root.onQueryChanged()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Tab) {
                                if (root.currentMode === "apps")
                                    root.setMode("actions")
                                else if (root.currentMode === "actions")
                                    root.setMode("emoji")
                                else
                                    root.setMode("apps")
                                event.accepted = true
                            }

                        }

                        Keys.onReturnPressed: root.activateSelected()
                        Keys.onEscapePressed: root._close()
                    }
                }
            }

            Text {
                text: root.selectedEntry ? root.selectedEntry.name : root.searchPrompt
                color: root.selectedEntry ? Theme.fg : Theme.fgMuted
                font.family: root.currentMode === "emoji" && root.selectedEntry ? Theme.monoFont : Theme.uiFont
                font.pixelSize: root.selectedEntry ? 24 : 18
                font.weight: root.selectedEntry ? 700 : 500
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: root.selectedEntry !== null
                text: root.selectedEntry
                    ? (root.selectedEntry.type === "emoji"
                        ? root.selectedEntry.emoji + "  " + root.selectedEntry.subtitle
                        : root.selectedEntry.subtitle)
                    : ""
                color: Theme.fgMuted
                font.family: root.currentMode === "emoji" ? Theme.uiFont : Theme.monoFont
                font.pixelSize: 11
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            ListView {
                id: resultList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.activeItems
                spacing: 10
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: resultList
                    visible: resultList.count === 0
                    text: searchField.text.length > 0 ? "No matches" : "loading…"
                    color: Theme.fgMuted
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: resultList.width
                    height: Config.launcherRowHeight
                    visible: index < 6

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: root.selectedIndex === index
                            ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.98)
                            : hoverArea.containsMouse
                                ? Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.54)
                                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.18)
                        border.width: 1
                        border.color: root.selectedIndex === index
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.46)
                            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        spacing: 16

                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 17
                            color: root.selectedIndex === index
                                ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.78)
                                : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.selectedIndex === index ? 0.18 : 0.1)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.type === "emoji" ? modelData.emoji : (index + 1).toString()
                                color: root.selectedIndex === index ? Theme.primary : Theme.fgMuted
                                font.family: modelData.type === "emoji" ? Theme.uiFont : Theme.monoFont
                                font.pixelSize: modelData.type === "emoji" ? 18 : 10
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: root.selectedIndex === index ? Theme.fg : Theme.fgMuted
                                font.family: Theme.uiFont
                                font.pixelSize: root.selectedIndex === index ? 18 : 15
                                font.weight: root.selectedIndex === index ? 650 : 500
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: root.selectedIndex === index
                                text: modelData.subtitle
                                color: Theme.fgMuted
                                font.family: modelData.type === "emoji" ? Theme.uiFont : Theme.monoFont
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedIndex = index
                            root.syncSelection()
                        }
                        onClicked: {
                            root.selectedIndex = index
                            root.activateEntry(modelData)
                        }
                    }
                }
            }

            Text {
                text: root.currentMode === "emoji"
                    ? "TAB switches modes  •  ENTER copies emoji  •  ESC closes"
                    : root.currentMode === "actions"
                        ? "TAB switches modes  •  ENTER runs action  •  ESC closes"
                        : "TAB switches modes  •  ENTER launches app  •  ESC closes"
                color: Qt.rgba(Theme.fgMuted.r, Theme.fgMuted.g, Theme.fgMuted.b, 0.9)
                font.family: Theme.monoFont
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
