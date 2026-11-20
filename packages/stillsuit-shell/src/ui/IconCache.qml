// SPDX-License-Identifier: MIT
pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property int tintedLimit: 512

    readonly property var store: ({
                                      knownNames: null,
                                      markupByUrl: {},
                                      tintedByKey: {},
                                      tintedCount: 0
                                  })

    property Component reader: Component {
        FileView {
            preload: false
            blockLoading: true
            blockAllReads: true
            printErrors: false
        }
    }

    function symbolicSource(name, catalog) {
        if (store.knownNames === null) {
            var names = {}
            var list = catalog()
            for (var index = 0; index < list.length; index++)
                names[list[index]] = true
            store.knownNames = names
        }
        var key = store.knownNames[name] === true ? name : "circle"
        return Qt.resolvedUrl("icons/" + key + ".svg")
    }

    function tinted(source, fill) {
        var url = String(source)
        if (url === "")
            return ""
        var key = url + "|" + fill
        var cached = store.tintedByKey[key]
        if (cached !== undefined)
            return cached
        var markup = _markup(url)
        if (markup === "")
            return ""
        var result = "data:image/svg+xml;utf8," + encodeURIComponent(markup.replace(/<svg\b/,
                                                                                    '<svg fill="'
                                                                                    + fill + '"'))
        if (store.tintedCount >= tintedLimit) {
            store.tintedByKey = {}
            store.tintedCount = 0
        }
        store.tintedByKey[key] = result
        store.tintedCount++
        return result
    }

    function _markup(url) {
        var cached = store.markupByUrl[url]
        if (cached !== undefined)
            return cached
        var file = reader.createObject(root, {
                                           path: url
                                       })
        if (!file)
            return ""
        var text = file.text()
        file.destroy()
        if (text !== "")
            store.markupByUrl[url] = text
        return text
    }
}
