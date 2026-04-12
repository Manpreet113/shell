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
import "../theme"

PanelWindow {
    id: root

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
    // Use the primary screen; for multi-monitor, improve by using
    // Hyprland.focusedMonitor's corresponding ShellScreen.
    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    anchors { top: true; bottom: true; left: true; right: true }

    // Don't push any windows around (we're an overlay)
    exclusiveZone: -1

    color: "transparent"

    // ─── App data ─────────────────────────────────────────────────────
    property var    allApps:      []   // full list from list_apps.py
    property var    filteredApps: []   // subset matching search text
    property string appBuffer:    ""   // accumulates stdout from appLoader

    // Path to the Python script, resolved relative to this QML file
    readonly property string listAppsScript:
        Qt.resolvedUrl("../../scripts/list_apps.py")
            .toString()
            .replace("file://", "")

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
    }

    function launchApp(app) {
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
    Rectangle {
        id: card
        anchors.centerIn:        parent
        width:                   520
        height:                  Math.min(560, parent.height - 80)
        color:                   Theme.surfaceVariant
        radius:                  8

        // Subtle border
        Rectangle {
            anchors.fill:  parent
            color:         "transparent"
            border.color:  Theme.outline
            border.width:  1
            radius:        parent.radius
            opacity:       0.5
        }

        // Catch clicks so they don't reach the backdrop
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors {
                fill:    parent
                margins: 20
            }
            spacing: 12

            // ── Header ─────────────────────────────────────────────────
            Text {
                text:               "LAUNCH"
                color:              Theme.primary
                font.family:        Theme.monoFont
                font.pixelSize:     11
                font.letterSpacing: 3.5
            }

            // ── Search bar ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height:           38
                color:            Theme.surface
                radius:           4
                border.color:     Theme.outline
                border.width:     1

                RowLayout {
                    anchors {
                        fill:        parent
                        leftMargin:  10
                        rightMargin: 10
                    }
                    spacing: 8

                    // Prompt glyph
                    Text {
                        text:           "›_"
                        color:          Theme.primary
                        font.family:    Theme.monoFont
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignVCenter
                    }

                    TextInput {
                        id:              searchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color:           Theme.fg
                        font.family:     Theme.monoFont
                        font.pixelSize:  13
                        selectionColor:  Theme.primaryContainer

                        // Type to filter
                        onTextChanged: root.filterApps()

                        // Enter launches the first result
                        Keys.onReturnPressed: {
                            if (root.filteredApps.length > 0)
                                root.launchApp(root.filteredApps[0])
                        }

                        Keys.onEscapePressed: root._close()
                    }
                }
            }

            // ── Divider ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height:           1
                color:            Theme.outline
                opacity:          0.4
            }

            // ── App list ───────────────────────────────────────────────
            ListView {
                id:               appList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip:             true
                model:            root.filteredApps
                spacing:          2

                // No items placeholder
                Text {
                    anchors.centerIn: appList
                    visible:          appList.count === 0
                    text:             searchField.text.length > 0
                                        ? "no matches"
                                        : "loading…"
                    color:            Theme.fgMuted
                    font.family:      Theme.monoFont
                    font.pixelSize:   12
                }

                delegate: Item {
                    required property var modelData   // { name, exec }
                    required property int index

                    width:  appList.width
                    height: 40

                    // Hover background
                    Rectangle {
                        anchors.fill: parent
                        radius:       4
                        color:        hoverArea.containsMouse
                                        ? Theme.surfaceContainer
                                        : "transparent"

                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    Text {
                        anchors {
                            left:           parent.left
                            leftMargin:     10
                            verticalCenter: parent.verticalCenter
                            right:          parent.right
                            rightMargin:    10
                        }
                        text:           modelData.name
                        color:          Theme.fg
                        font.family:    Theme.uiFont
                        font.pixelSize: 13
                        elide:          Text.ElideRight
                    }

                    MouseArea {
                        id:           hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked:    root.launchApp(modelData)
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        color:         Theme.outline
                        radius:        2
                    }
                }
            }
        }
    }
}
