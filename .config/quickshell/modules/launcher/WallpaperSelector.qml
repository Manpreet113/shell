// WallpaperSelector.qml — Floating wallpaper picker with thumbnails
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

    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    visible: false

    function toggle() {
        if (visible) _close()
        else         _open()
    }

    function _open() {
        buffer = ""
        visible = true
        searchField.text = ""
        loader.running = true
        searchField.forceActiveFocus()
    }

    function _close() {
        visible = false
    }

    screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    // ─── Data ─────────────────────────────────────────────────────────
    property var    allWallpapers: []
    property var    filteredWallpapers: []
    property string buffer: ""

    readonly property string listScript: {
        var url = Qt.resolvedUrl("../../scripts/list_wallpapers.py").toString()
        if (url.startsWith("file://")) return url.substring(7)
        return url
    }

    readonly property string applyScript: {
        var url = Qt.resolvedUrl("../../scripts/wallpaper.sh").toString()
        if (url.startsWith("file://")) return url.substring(7)
        return url
    }

    Process {
        id: loader
        command: ["python3", root.listScript]
        stdout: SplitParser {
            onRead: data => root.buffer += data
        }
        onRunningChanged: {
            if (!running && root.buffer.length > 0) {
                try {
                    root.allWallpapers = JSON.parse(root.buffer)
                    root.filterWallpapers()
                } catch (e) {
                    console.warn("[wallpaper] Failed to parse wallpapers:", e)
                }
                root.buffer = ""
            }
        }
    }

    function filterWallpapers() {
        var q = searchField.text.toLowerCase().trim()
        filteredWallpapers = q.length === 0
            ? allWallpapers
            : allWallpapers.filter(w => w.name.toLowerCase().includes(q))
    }

    Process {
        id: applier
        // command will be set dynamically
    }

    function selectWallpaper(wp) {
        applier.command = [root.applyScript, wp.path]
        applier.running = true
        _close()
    }

    // ─── Dim backdrop ─────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.65
        MouseArea {
            anchors.fill: parent
            onClicked: root._close()
        }
    }

    // ─── Selector card ────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 680
        height: Math.min(600, parent.height - 80)
        color: Theme.surfaceVariant
        radius: 12

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: Theme.outline
            border.width: 1
            radius: parent.radius
            opacity: 0.5
        }

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 24 }
            spacing: 16

            // ── Header ─────────────────────────────────────────────────
            Text {
                text: "WALLPAPERS"
                color: Theme.primary
                font.family: Theme.monoFont
                font.pixelSize: 11
                font.letterSpacing: 4
            }

            // ── Search bar ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 42
                color: Theme.surface
                radius: 6
                border.color: Theme.outline
                border.width: 1

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: "" // search icon
                        color: Theme.primary
                        font.family: Theme.uiFont
                        font.pixelSize: 16
                    }

                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        color: Theme.fg
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        onTextChanged: root.filterWallpapers()
                        Keys.onEscapePressed: root._close()
                        Keys.onReturnPressed: {
                            if (root.filteredWallpapers.length > 0)
                                root.selectWallpaper(root.filteredWallpapers[0])
                        }
                    }
                }
            }

            // ── Grid ───────────────────────────────────────────────────
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: 158
                cellHeight: 120
                model: root.filteredWallpapers

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: grid.cellWidth - 10
                    height: grid.cellHeight - 10

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: hoverArea.containsMouse ? Theme.surfaceContainer : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4

                            // Thumbnail
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                clip: true
                                color: Theme.surface

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + modelData.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 300 // keeps it low-res for the grid
                                    smooth: true
                                }
                            }

                            // Filename
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Theme.fg
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.selectWallpaper(modelData)
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }
        }
    }
}
