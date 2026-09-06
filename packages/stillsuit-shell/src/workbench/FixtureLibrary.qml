// Loads every fixture document under a directory and exposes them by id.
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string directory: ""
    property var ids: []
    property var documents: ({})
    property string error: ""

    property Process lister: Process {
        command: ["sh", "-c", "for f in \"$1\"/*.json; do [ -e \"$f\" ] && printf '%s\\n' \"$f\"; done", "sh", root.directory]
        stdout: StdioCollector { id: listing; waitForEnd: true }
        onExited: function(exitCode) {
            var paths = listing.text.split("\n").filter(function(line) { return line !== "" })
            root._load(paths)
        }
    }

    property Component readerComponent: Component {
        FileView { blockLoading: true; blockAllReads: true; printErrors: false }
    }

    function reload() { lister.running = false; lister.running = true }

    function get(id) { return documents[String(id)] || null }

    function _load(paths) {
        var nextIds = []
        var nextDocuments = {}
        var problems = []
        for (var index = 0; index < paths.length; index++) {
            var reader = readerComponent.createObject(root, { path: paths[index] })
            try {
                var parsed = JSON.parse(reader.text())
                if (!parsed || parsed.schemaVersion !== 1 || typeof parsed.id !== "string")
                    throw new Error("not a workbench fixture v1")
                nextDocuments[parsed.id] = parsed
                nextIds.push(parsed.id)
            } catch (caught) {
                problems.push(paths[index] + ": " + caught)
            } finally {
                reader.destroy()
            }
        }
        nextIds.sort(function(left, right) {
            if (left === "default") return -1
            if (right === "default") return 1
            return left < right ? -1 : left > right ? 1 : 0
        })
        documents = nextDocuments
        ids = nextIds
        error = problems.join("\n")
    }
}
