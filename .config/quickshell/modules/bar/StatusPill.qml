pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string labelText: ""
    property bool emphasized: false
    property bool warning: false
    property bool muted: false
    property bool interactive: false

    signal clicked()

    implicitHeight: 28
    implicitWidth: textItem.implicitWidth + 24
    radius: implicitHeight / 2

    color: {
        if (warning)
            return Qt.rgba(Theme.errorContainer.r, Theme.errorContainer.g, Theme.errorContainer.b, 0.92)
        if (emphasized)
            return Qt.rgba(Theme.primaryContainer.r, Theme.primaryContainer.g, Theme.primaryContainer.b, 0.9)
        return Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.82)
    }

    border.width: 1
    border.color: {
        if (warning)
            return Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.6)
        if (emphasized)
            return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
        if (muted)
            return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.55)
        return Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: root.labelText
        color: {
            if (warning)
                return Theme.error
            if (emphasized)
                return Theme.primary
            return root.muted ? Theme.fgMuted : Theme.fg
        }
        font.family: Theme.monoFont
        font.pixelSize: 12
        font.bold: emphasized || warning
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
