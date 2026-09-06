import QtQuick
import Quickshell
import Quickshell.Io
import "core/ManifestValidator.js" as ManifestValidator
import "ui" as Ui

ShellRoot {
    id: fixture

    property int checks: 0

    QtObject {
        id: themeContext

        property var theme: ({
            colors: {
                border: { focus: "#123456" },
                text: { primary: "#cdd6f4" }
            },
            controls: {
                hover: { fill: "#313244", border: "#585b70" },
                active: { fill: "#45475a", border: "#89b4fa" }
            },
            geometry: { radius: 6 },
            motion: { fast: 0 }
        })
    }

    Component {
        id: cursorComponent

        Ui.CursorSurface {
            context: themeContext
        }
    }

    IpcHandler {
        target: "stillsuit-schema-theme-contract"

        function run(): string {
            return fixture.runContracts()
        }
    }

    function runContracts() {
        checks = 0
        try {
            var keys = ["bar", "barWidget", "service", "panel", "overlay", "menu"]
            var kinds = ["bar", "bar-widget", "service", "panel", "overlay", "menu"]
            for (var index = 0; index < keys.length; index++) {
                var baseKind = kinds[index] === "panel" ? "service" : "panel"
                var baseKey = ManifestValidator.entryPointKey(baseKind)
                var entryPointManifest = _manifest(baseKind, baseKey)
                entryPointManifest.entryPoints[keys[index]] = "Extra.qml"
                var entryPointErrors = ManifestValidator.validate(entryPointManifest)
                _assert(_contains(entryPointErrors,
                        "entry point does not match a declared kind: " + keys[index]),
                    "host accepted undeclared entry point " + keys[index])

                var scopeManifest = _manifest(baseKind, baseKey)
                scopeManifest.scope[keys[index]] = _scopeFor(kinds[index])
                var scopeErrors = ManifestValidator.validate(scopeManifest)
                _assert(_contains(scopeErrors,
                        "scope does not match a declared kind: " + keys[index]),
                    "host accepted undeclared scope " + keys[index])
            }

            var valid = _manifest("panel", "panel")
            valid.kinds.push("overlay")
            valid.entryPoints.overlay = "Overlay.qml"
            valid.scope.overlay = "per-output"
            _assert(ManifestValidator.validate(valid).length === 0,
                "host rejected a symmetric multi-kind manifest")

            var cursor = cursorComponent.createObject(null)
            _assert(cursor !== null, "cursor did not construct")
            _assert(String(cursor.accent).toLowerCase() === "#123456",
                "cursor accent did not use colors.border.focus")
            cursor.destroy()

            return JSON.stringify({ ok: true, checks: checks })
        } catch (error) {
            return JSON.stringify({ ok: false, checks: checks, error: String(error) })
        }
    }

    function _manifest(kind, key) {
        var entryPoints = {}
        entryPoints[key] = key.charAt(0).toUpperCase() + key.slice(1) + ".qml"
        var scope = {}
        scope[key] = _scopeFor(kind)
        return {
            schemaVersion: 1,
            id: "stillsuit.manifest-fixture",
            name: "Manifest fixture",
            version: "1.0.0",
            apiVersion: "1",
            kinds: [kind],
            entryPoints: entryPoints,
            scope: scope
        }
    }

    function _scopeFor(kind) {
        if (kind === "bar" || kind === "bar-widget")
            return "per-output"
        return "global"
    }

    function _contains(values, expected) {
        return values.indexOf(expected) !== -1
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
        checks++
    }
}
