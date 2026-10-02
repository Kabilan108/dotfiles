// SPDX-License-Identifier: MIT
pragma Singleton

import QtQuick
import Quickshell.Io

// Shared by every ShellIcon in the engine. A directory import of ui/ and the
// Stillsuit.Ui module import resolve to different URLs, so each import style
// gets its own instance; both stay correct, the second only repeats the reads.
QtObject {
    id: root

    // A plugin animating an icon's color would mint a key per frame; past this
    // many entries the tinted cache starts over instead of growing without end.
    readonly property int tintedLimit: 512

    // Lookups run inside ShellIcon bindings. The store is only ever mutated in
    // place: assigning a property here would notify every icon binding that
    // read it, and the binding doing the assignment would loop.
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

    // Qt SVG has no currentColor support, so the fill is written into the
    // markup before decoding instead of tinting pixels afterwards.
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
        var result = "data:image/svg+xml;utf8,"
            + encodeURIComponent(markup.replace(/<svg\b/, '<svg fill="' + fill + '"'))
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
        var file = reader.createObject(root, { path: url })
        if (!file)
            return ""
        var text = file.text()
        file.destroy()
        if (text !== "")
            store.markupByUrl[url] = text
        return text
    }
}
