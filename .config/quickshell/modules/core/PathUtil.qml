pragma Singleton

import QtQuick

QtObject {
    function resolveFilePath(relativePath) {
        var url = Qt.resolvedUrl(relativePath).toString()
        return url.startsWith("file://") ? url.substring(7) : url
    }
}