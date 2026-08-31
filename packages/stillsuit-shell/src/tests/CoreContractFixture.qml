import QtQuick
import Quickshell
import Quickshell.Io
import "./core"
import "./ui" as Ui

ShellRoot {
    id: fixture

    property int checks: 0

    QtObject {
        id: fixtureContext
    }

    QtObject {
        id: fakeHostContext

        function contextFor(entry) {
            return fixtureContext
        }
    }

    QtObject {
        id: fakeServices
        property int revision: 0

        function state(pluginId) {
            return "loaded"
        }
    }

    QtObject {
        id: fakeCompositor
        property string focusedOutputId: "output-a"
        property var outputs: [
            { id: "output-a", name: "output-a" },
            { id: "output-b", name: "output-b" }
        ]
    }

    QtObject {
        id: fakeCatalog
        property bool loaded: true
        property var entries: ({
            "stillsuit.async": fixture._entry(false),
            "stillsuit.keep": fixture._entry(true)
        })

        signal entryAdded(string pluginId)
        signal entryChanged(string pluginId)
        signal entryRemoved(string pluginId)
        signal pluginUnloaded(string pluginId)
        signal pluginReloaded(string pluginId)
        signal catalogChanged()

        function has(pluginId) {
            return entries[String(pluginId)] !== undefined
        }

        function get(pluginId) {
            return entries[String(pluginId)] || null
        }

        function isEnabled(pluginId) {
            return has(pluginId)
        }

        function hasKind(pluginId, kind) {
            return has(pluginId) && entries[pluginId].manifest.kinds.indexOf(kind) !== -1
        }

        function primarySurfaceKind(pluginId) {
            return has(pluginId) ? "panel" : ""
        }

        function entryPointUrl(entry, kind) {
            return "fixture://" + entry.manifest.id
        }
    }

    QtObject {
        id: fakeComponent
        property int status: Component.Loading
        property string diagnostic: "fixture compilation error"

        function createObject(parent, properties) {
            return fakeSurface.createObject(parent, properties)
        }

        function errorString() {
            return diagnostic
        }

        function destroy() {}
    }

    Component {
        id: fakeSurface
        QtObject {
            required property var context
            property string outputId: ""
            property var output: null
            property bool opened: false
            property var receivedPayloads: []

            function open(payloadJson) {
                var next = receivedPayloads.slice()
                next.push(String(payloadJson))
                receivedPayloads = next
                opened = true
            }

            function close() {
                opened = false
            }
        }
    }

    Component {
        id: panelPrimitive

        Ui.Panel {
            settings: { "fixture": 42 }
        }
    }

    Component {
        id: keyCatcherPrimitive

        Ui.PanelKeyCatcher {}
    }

    Component {
        id: pointerGatePrimitive

        Ui.PointerMoveGate {}
    }

    Component {
        id: cursorPrimitive

        Ui.CursorSurface {}
    }

    SurfaceRouter {
        id: router
        catalog: fakeCatalog
        hostContext: fakeHostContext
        serviceRegistry: fakeServices
        compositor: fakeCompositor
        componentFactory: function(url, mode) {
            fakeComponent.status = Component.Loading
            return fakeComponent
        }
    }

    IpcHandler {
        target: "stillsuit-lane-b-contract"

        function run(): string {
            return fixture.runContracts()
        }
    }

    function runContracts() {
        checks = 0
        try {
            var panel = panelPrimitive.createObject(null)
            _assert(panel !== null && panel.setting("fixture", 0) === 42,
                "panel setting contract failed")
            panel.controller.show("{\"primitive\":true}")
            _assert(panel.opened && panel.controller.open
                    && panel.lastPayloadJson === "{\"primitive\":true}",
                "panel controller did not open the panel")
            panel.controller.hide()
            _assert(!panel.opened && !panel.controller.open,
                "panel controller did not close the panel")
            panel.destroy()

            var keyCatcher = keyCatcherPrimitive.createObject(null)
            _assert(keyCatcher !== null && keyCatcher.blocked === false,
                "panel key catcher did not construct")
            keyCatcher.destroy()
            var pointerGate = pointerGatePrimitive.createObject(null)
            _assert(pointerGate !== null && pointerGate.moved(null, null) === false,
                "pointer move gate reset contract failed")
            pointerGate.destroy()
            var cursor = cursorPrimitive.createObject(null)
            _assert(cursor !== null && cursor.hasCursor === false && cursor.current === false,
                "cursor surface did not construct")
            cursor.destroy()

            _assert(router.open("stillsuit.async", "{\"sequence\":1}") === "ok",
                "first asynchronous open failed")
            _assert(router.state("stillsuit.async") === "loading",
                "surface did not enter loading")
            _assert(router.open("stillsuit.async", "{\"sequence\":2}") === "ok",
                "second asynchronous open failed")
            _assert(router.pendingCount("stillsuit.async") === 2,
                "FIFO payload queue lost an entry")
            _assert(router.close("stillsuit.async") === "ok",
                "close during loading failed")
            _assert(router.state("stillsuit.async") === "unloaded",
                "non-keep-loaded surface stayed loading after close")
            _assert(router.pendingCount("stillsuit.async") === 0,
                "close did not clear queued payloads")

            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.async") === "unloaded",
                "late completion revived a closed surface")

            fakeCompositor.focusedOutputId = "output-a"
            _assert(router.open("stillsuit.async", "{\"sequence\":3}") === "ok",
                "second load did not start")
            fakeCompositor.focusedOutputId = "output-b"
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.async") === "loaded",
                "ready component did not load")
            _assert(router.placementOutputId("stillsuit.async") === "output-a",
                "global surface did not keep its initial focused output")
            var loaded = router.objects["stillsuit.async"][0]
            _assert(loaded.receivedPayloads.length === 1
                    && loaded.receivedPayloads[0] === "{\"sequence\":3}",
                "cleared payloads replayed after a late completion")
            _assert(router.close("stillsuit.async") === "ok"
                    && router.state("stillsuit.async") === "unloaded",
                "non-keep-loaded close did not unload")

            _assert(router.open("stillsuit.keep", "{\"sequence\":4}") === "ok",
                "keep-loaded asynchronous open failed")
            _assert(router.close("stillsuit.keep") === "ok",
                "keep-loaded close during loading failed")
            _assert(router.pendingCount("stillsuit.keep") === 0,
                "keep-loaded close did not clear the queue")
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.keep") === "loaded"
                    && !router.isOpen("stillsuit.keep"),
                "keep-loaded surface reopened after its queue was cleared")

            router.unload("stillsuit.keep")
            _assert(router.open("stillsuit.keep", "{\"sequence\":5}") === "ok",
                "error fixture did not start")
            fakeComponent.status = Component.Error
            _assert(router.state("stillsuit.keep") === "error",
                "component error was not contained")
            _assert(router.pendingCount("stillsuit.keep") === 0,
                "component error did not clear queued payloads")
            _assert(router.open("stillsuit.keep", "{\"sequence\":6}") === "error",
                "error route retried without explicit reload")
            router.reload("stillsuit.keep")
            _assert(router.state("stillsuit.keep") === "loading",
                "explicit reload did not retry a keep-loaded surface")
            _assert(router.pendingCount("stillsuit.keep") === 0,
                "reload retained a queued payload")
            router.unload("stillsuit.keep")
            _assert(router.state("stillsuit.keep") === "unloaded",
                "unload did not cancel a loading surface")
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.keep") === "unloaded",
                "late completion revived an unloaded surface")

            _assert(router.open("stillsuit.async", "{\"sequence\":7}") === "ok",
                "reload-clear fixture did not start")
            router.reload("stillsuit.async")
            _assert(router.pendingCount("stillsuit.async") === 0
                    && router.state("stillsuit.async") === "unloaded",
                "reload did not clear a non-keep-loaded route")
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.async") === "unloaded",
                "late completion revived a reloaded closed surface")

            _assert(router.open("stillsuit.async", "{\"sequence\":8}") === "ok",
                "disable-clear fixture did not start")
            fakeCatalog.pluginUnloaded("stillsuit.async")
            _assert(router.pendingCount("stillsuit.async") === 0,
                "disable did not clear queued payloads")
            _assert(router.state("stillsuit.async") === "unloaded",
                "disable did not unload the surface")
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.async") === "unloaded",
                "late completion revived a disabled surface")

            return JSON.stringify({ ok: true, checks: checks })
        } catch (error) {
            return JSON.stringify({ ok: false, checks: checks, error: String(error) })
        }
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
        checks++
    }

    function _entry(keepLoaded) {
        return {
            packageRoot: "/fixture",
            signature: "fixture:" + keepLoaded,
            settings: {},
            manifest: {
                id: keepLoaded ? "stillsuit.keep" : "stillsuit.async",
                kinds: ["panel"],
                entryPoints: { panel: "Panel.qml" },
                scope: { panel: "global" },
                dependencies: [],
                keepLoaded: keepLoaded
            }
        }
    }
}
