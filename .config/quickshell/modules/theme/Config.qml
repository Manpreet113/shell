pragma Singleton

import QtQuick

QtObject {
    readonly property int barHeight: 38
    readonly property int barHorizontalPadding: 16
    readonly property int panelSpacing: 8

    readonly property int launcherWidth: 640
    readonly property int launcherHeightMargin: 80
    readonly property int launcherMaxHeight: 540
    readonly property int launcherRowHeight: 62

    readonly property int wallpaperSelectorWidth: 980
    readonly property int wallpaperSelectorHeightMargin: 80
    readonly property int wallpaperSelectorMaxHeight: 680
    readonly property int wallpaperGridCellWidth: 156
    readonly property int wallpaperGridCellHeight: 128
    readonly property string wallpaperDir: "~/Pictures/wallpapers"
}
