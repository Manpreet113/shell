// Launcher.qml — Full-screen app launcher overlay
// Toggled via: qs ipc call shell toggleLauncher  (Super+Space in hyprland.conf)
// The card is centered; clicking the dimmed backdrop closes the launcher.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"

PanelWindow {
    id: root

    // Launcher should be on top of all windows and receive keyboard focus
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay

    // ─── Visibility state ────────────────────────────────────────────
    // Starts hidden; toggled by shell.qml's IpcHandler.
    visible: false

    function toggle() {
        if (visible) _close()
        else         _open()
    }

    function _open() {
        appBuffer = ""
        visible   = true
        selectedIndex = 0
        searchField.text = ""
        // Load app list fresh each time (catches newly installed apps)
        appLoader.running = true
        // Give focus to the search field
        searchField.forceActiveFocus()
    }

    function _close() {
        visible = false
    }

    // ─── Layer shell config ───────────────────────────────────────────
    readonly property var overlayScreen: {
        if (Quickshell.screens.length === 0)
            return null

        var focusedMonitor = Hyprland.focusedMonitor
        if (focusedMonitor && focusedMonitor.name) {
            for (var i = 0; i < Quickshell.screens.length; ++i) {
                var shellScreen = Quickshell.screens[i]
                if (shellScreen.name === focusedMonitor.name)
                    return shellScreen
            }
        }

        return Quickshell.screens[0]
    }

    screen: overlayScreen

    anchors { top: true; bottom: true; left: true; right: true }

    // Don't push any windows around (we're an overlay)
    exclusiveZone: -1

    color: "transparent"

    // ─── App data ─────────────────────────────────────────────────────
    property var    allApps:      []   // full list from list_apps.py
    property var    filteredApps: []   // subset matching search text
    property string appBuffer:    ""   // accumulates stdout from appLoader
    property int    selectedIndex: 0
    readonly property var selectedEntry: selectedApp()
    readonly property int visibleResultCount: Math.min(6, filteredApps.length)
    readonly property string searchPrompt: searchField.text.trim().length > 0
        ? searchField.text.trim()
        : "Type an app name"

    // Path to the Python script, resolved relative to this QML file
    readonly property string listAppsScript: {
        var url = Qt.resolvedUrl("../../scripts/list_apps.py").toString()
        if (url.startsWith("file://")) {
            return url.substring(7)
        }
        return url
    }

    Process {
        id: appLoader
        command: ["python3", root.listAppsScript]

        // list_apps.py outputs a single compact JSON line — one onRead call
        stdout: SplitParser {
            onRead: data => root.appBuffer += data
        }

        onRunningChanged: {
            if (!running && root.appBuffer.length > 0) {
                try {
                    root.allApps = JSON.parse(root.appBuffer)
                    root.filterApps()
                } catch (e) {
                    console.warn("[launcher] Failed to parse app list:", e)
                }
                root.appBuffer = ""
            }
        }
    }

    function filterApps() {
        var q = searchField.text.toLowerCase().trim()
        filteredApps = q.length === 0
            ? allApps
            : allApps.filter(a => a.name.toLowerCase().includes(q))
        clampSelection()
    }

    function clampSelection() {
        if (filteredApps.length === 0) {
            selectedIndex = -1
            appList.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= filteredApps.length)
            selectedIndex = 0

        appList.currentIndex = selectedIndex
        appList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function moveSelection(delta) {
        if (filteredApps.length === 0)
            return

        var nextIndex = selectedIndex
        if (nextIndex < 0)
            nextIndex = 0
        else
            nextIndex = (nextIndex + delta + filteredApps.length) % filteredApps.length

        selectedIndex = nextIndex
        appList.currentIndex = selectedIndex
        appList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    function selectedApp() {
        if (selectedIndex < 0 || selectedIndex >= filteredApps.length)
            return null
        return filteredApps[selectedIndex]
    }

    function launchApp(app) {
        if (!app)
            return

        // dispatch exec via Hyprland IPC — proper window rules apply
        Hyprland.dispatch("exec " + app.exec)
        _close()
    }

    // ─── Dim backdrop ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color:        "#000000"
        opacity:      0.65

        // Click on the backdrop to dismiss
        MouseArea {
            anchors.fill: parent
            onClicked:    root._close()
        }
    }

    // ─── Launcher card ────────────────────────────────────────────────
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
                text: "COMMAND"
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.9)
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 4
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                radius: implicitHeight / 2
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.26)

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 16

                    Text {
                        text: ">"
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

                        onTextChanged: root.filterApps()

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-1)
                                event.accepted = true
                            }
                        }

                        Keys.onReturnPressed: root.launchApp(root.selectedApp())
                        Keys.onEscapePressed: root._close()
                    }

                    Rectangle {
                        visible: root.selectedEntry !== null
                        implicitWidth: actionHint.implicitWidth + 18
                        implicitHeight: 30
                        radius: implicitHeight / 2
                        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.78)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: actionHint
                            anchors.centerIn: parent
                            text: "ENTER"
                            color: Theme.fgMuted
                            font.family: Theme.monoFont
                            font.pixelSize: 10
                        }
                    }
                }
            }

            Text {
                text: root.selectedEntry
                    ? root.selectedEntry.name
                    : root.searchPrompt
                color: root.selectedEntry ? Theme.fg : Theme.fgMuted
                font.family: Theme.uiFont
                font.pixelSize: root.selectedEntry ? 24 : 18
                font.weight: root.selectedEntry ? 700 : 500
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                visible: root.selectedEntry !== null
                text: root.selectedEntry ? root.selectedEntry.exec : ""
                color: Theme.fgMuted
                font.family: Theme.monoFont
                font.pixelSize: 11
                elide: Text.ElideMiddle
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            ListView {
                id: appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.filteredApps
                spacing: 10
                currentIndex: root.selectedIndex
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: appList
                    visible: appList.count === 0
                    text: searchField.text.length > 0 ? "No matching apps" : "loading…"
                    color: Theme.fgMuted
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: appList.width
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
                        opacity: root.selectedIndex === index ? 1 : 0.92

                        Behavior on color { ColorAnimation { duration: 90 } }
                        Behavior on opacity { NumberAnimation { duration: 90 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 22
                        anchors.rightMargin: 22
                        spacing: 16

                        Rectangle {
                            implicitWidth: 28
                            implicitHeight: 28
                            radius: 14
                            color: root.selectedIndex === index
                                ? Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.78)
                                : "transparent"
                            border.width: 1
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.selectedIndex === index ? 0.18 : 0.1)
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1).toString()
                                color: root.selectedIndex === index ? Theme.primary : Theme.fgMuted
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: root.selectedIndex === index ? Theme.fg : Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: root.selectedIndex === index ? 18 : 15
                            font.weight: root.selectedIndex === index ? 650 : 500
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedIndex = index
                            appList.currentIndex = index
                        }
                        onClicked: {
                            root.selectedIndex = index
                            root.launchApp(modelData)
                        }
                    }
                }
            }

            Text {
                text: "UP DOWN to move  •  ENTER to launch  •  ESC to close"
                color: Qt.rgba(Theme.fgMuted.r, Theme.fgMuted.g, Theme.fgMuted.b, 0.9)
                font.family: Theme.monoFont
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
