// WallpaperSelector.qml — Floating wallpaper picker with preview and keyboard navigation
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../theme"
import "../bar"

PanelWindow {
    id: root

    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    visible: false

    property var allWallpapers: []
    property var filteredWallpapers: []
    property string buffer: ""
    property int selectedIndex: -1

    readonly property var selectedWallpaper: {
        if (selectedIndex < 0 || selectedIndex >= filteredWallpapers.length)
            return null
        return filteredWallpapers[selectedIndex]
    }

    function toggle() {
        if (visible) _close()
        else _open()
    }

    function _open() {
        buffer = ""
        visible = true
        selectedIndex = -1
        searchField.text = ""
        loader.running = true
        searchField.forceActiveFocus()
    }

    function _close() {
        visible = false
    }

    function filterWallpapers() {
        var q = searchField.text.toLowerCase().trim()
        filteredWallpapers = q.length === 0
            ? allWallpapers
            : allWallpapers.filter(w => w.name.toLowerCase().includes(q))
        clampSelection()
    }

    function clampSelection() {
        if (filteredWallpapers.length === 0) {
            selectedIndex = -1
            grid.currentIndex = -1
            return
        }

        if (selectedIndex < 0 || selectedIndex >= filteredWallpapers.length)
            selectedIndex = 0

        grid.currentIndex = selectedIndex
        grid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    function moveSelection(delta) {
        if (filteredWallpapers.length === 0)
            return

        var columns = Math.max(1, Math.floor(grid.width / grid.cellWidth))
        var nextIndex = selectedIndex < 0 ? 0 : selectedIndex

        if (delta === columns || delta === -columns)
            nextIndex = Math.max(0, Math.min(filteredWallpapers.length - 1, nextIndex + delta))
        else
            nextIndex = (nextIndex + delta + filteredWallpapers.length) % filteredWallpapers.length

        selectedIndex = nextIndex
        grid.currentIndex = nextIndex
        grid.positionViewAtIndex(nextIndex, GridView.Contain)
    }

    function selectWallpaper(wp) {
        if (!wp)
            return

        applier.command = [root.applyScript, wp.path]
        applier.running = true
        _close()
    }

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

    screen: overlayScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"

    Process {
        id: loader
        command: ["python3", root.listScript, Config.wallpaperDir]
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

    Process {
        id: applier
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

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Config.wallpaperSelectorWidth
        height: Math.min(Config.wallpaperSelectorMaxHeight, parent.height - Config.wallpaperSelectorHeightMargin)
        color: Theme.surfaceVariant
        radius: 24

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

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: "WALLPAPERS"
                        color: Theme.primary
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                        font.letterSpacing: 4
                    }

                    Text {
                        text: root.selectedWallpaper
                            ? "Press Enter to apply " + root.selectedWallpaper.name
                            : "Browse and preview your wallpaper collection"
                        color: Theme.fgMuted
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: hintText.implicitWidth + 18
                    implicitHeight: 28
                    radius: implicitHeight / 2
                    color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.7)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.28)

                    Text {
                        id: hintText
                        anchors.centerIn: parent
                        text: "ARROWS move  ENTER apply  ESC close"
                        color: Theme.fgMuted
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 44
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.88)
                radius: height / 2
                border.color: Theme.outline
                border.width: 1

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10

                    Text {
                        text: ""
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
                        Keys.onPressed: event => {
                            var columns = Math.max(1, Math.floor(grid.width / grid.cellWidth))
                            if (event.key === Qt.Key_Right) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Left) {
                                root.moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down) {
                                root.moveSelection(columns)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-columns)
                                event.accepted = true
                            }
                        }
                        Keys.onReturnPressed: root.selectWallpaper(root.selectedWallpaper)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 2
                    radius: 22
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.48)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                    GridView {
                        id: grid
                        anchors.fill: parent
                        anchors.margins: 14
                        clip: true
                        cellWidth: Config.wallpaperGridCellWidth
                        cellHeight: Config.wallpaperGridCellHeight
                        model: root.filteredWallpapers
                        currentIndex: root.selectedIndex

                        delegate: Item {
                            required property var modelData
                            required property int index

                            width: grid.cellWidth - 10
                            height: grid.cellHeight - 10

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: {
                                    if (root.selectedIndex === index)
                                        return Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.9)
                                    if (hoverArea.containsMouse)
                                        return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.86)
                                    return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.48)
                                }
                                border.width: 1
                                border.color: root.selectedIndex === index
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 6

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 14
                                        clip: true
                                        color: Theme.surface

                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + modelData.path
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 360
                                            smooth: true
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 24
                                        radius: implicitHeight / 2
                                        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.74)

                                        Text {
                                            anchors {
                                                left: parent.left
                                                right: parent.right
                                                leftMargin: 10
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: modelData.name
                                            color: root.selectedIndex === index ? Theme.fg : Theme.fgMuted
                                            font.family: Theme.uiFont
                                            font.pixelSize: 10
                                            elide: Text.ElideMiddle
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }
                                }

                                MouseArea {
                                    id: hoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: {
                                        root.selectedIndex = index
                                        grid.currentIndex = index
                                    }
                                    onClicked: {
                                        root.selectedIndex = index
                                        root.selectWallpaper(modelData)
                                    }
                                }
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 4
                                color: Theme.outline
                                radius: 2
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 290
                    radius: 22
                    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.56)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 220
                            radius: 18
                            clip: true
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.72)

                            Image {
                                anchors.fill: parent
                                visible: root.selectedWallpaper !== null
                                source: root.selectedWallpaper ? "file://" + root.selectedWallpaper.path : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 720
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: root.selectedWallpaper === null
                                text: "No wallpaper selected"
                                color: Theme.fgMuted
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.selectedWallpaper ? root.selectedWallpaper.name : "Choose a wallpaper"
                            color: Theme.fg
                            font.family: Theme.uiFont
                            font.pixelSize: 16
                            font.bold: true
                            wrapMode: Text.WrapAnywhere
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: pathText.implicitHeight + 18
                            radius: 16
                            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.72)

                            Text {
                                id: pathText
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: 12
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }
                                text: root.selectedWallpaper ? root.selectedWallpaper.path : Config.wallpaperDir
                                color: Theme.fgMuted
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                wrapMode: Text.WrapAnywhere
                            }
                        }

                        StatusPill {
                            labelText: root.selectedWallpaper
                                ? "MATCHES " + root.filteredWallpapers.length
                                : "DIR " + Config.wallpaperDir
                            muted: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Tip: search to narrow the grid, use arrows to move, and press Enter to apply the selected wallpaper."
                            color: Theme.fgMuted
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: implicitHeight / 2
                            color: root.selectedWallpaper
                                ? Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.92)
                                : Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.62)
                            border.width: 1
                            border.color: root.selectedWallpaper
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.4)
                                : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: root.selectedWallpaper ? "APPLY SELECTED WALLPAPER" : "SELECT A WALLPAPER"
                                color: root.selectedWallpaper ? Theme.primary : Theme.fgMuted
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                font.bold: true
                                font.letterSpacing: 1.4
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.selectedWallpaper !== null
                                onClicked: root.selectWallpaper(root.selectedWallpaper)
                            }
                        }
                    }
                }
            }
        }
    }
}
