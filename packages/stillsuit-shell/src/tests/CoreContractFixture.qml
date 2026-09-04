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
        id: screenA
        property string name: "output-a"
    }

    QtObject {
        id: screenB
        property string name: "output-b"
    }

    QtObject {
        id: screenC
        property string name: "output-c"
    }

    QtObject {
        id: fixtureSingleton
        property string identity: "fixture-singleton"
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
        property var serviceStates: ({})
        readonly property int objectCount: 1

        signal dependencyContained(string pluginId)

        function state(pluginId) {
            return serviceStates[String(pluginId)] || "loaded"
        }

        function get(pluginId) {
            return fixtureSingleton
        }

        function setState(pluginId, nextState) {
            var next = {}
            for (var key in serviceStates)
                next[key] = serviceStates[key]
            next[String(pluginId)] = String(nextState)
            serviceStates = next
            revision++
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
            "stillsuit.keep": fixture._entry(true),
            "stillsuit.dependency": fixture._serviceEntry("stillsuit.dependency", []),
            "stillsuit.dependent": fixture._dependentEntry()
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
            return hasKind(pluginId, "panel") ? "panel" : ""
        }

        function entryPointUrl(entry, kind) {
            return "fixture://" + entry.manifest.id
        }

        function topologicalOrder() {
            return [
                "stillsuit.async",
                "stillsuit.dependency",
                "stillsuit.dependent",
                "stillsuit.keep"
            ]
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
            property var screen: null
            property var service: null
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
        screens: [screenA, screenB]
        componentFactory: function(url, mode) {
            fakeComponent.status = Component.Loading
            return fakeComponent
        }
    }

    HostContext {
        id: builtinHostContext
        theme: ({
            schemaVersion: 2,
            identity: { id: "stillsuit.fixture" },
            palette: { neutral: { base: "#000000" } },
            semantic: { surface: { panel: "#111111" } },
            component: { panel: { background: "#111111" } },
            typography: { bodyFamily: "Fixture Sans" },
            metrics: { barHeight: 26 },
            motion: { fast: 66 },
            effects: { surfaceOpacity: 0.8 }
        })
        compositor: fakeCompositor
        serviceRegistry: fakeServices
        surfaceRouter: router
        instanceId: "lane-b-fixture"
    }

    QtObject {
        id: multiCatalog
        property bool loaded: true
        property var entries: ({ "stillsuit.multi": fixture._multiEntry() })

        signal entryAdded(string pluginId)
        signal entryChanged(string pluginId)
        signal entryRemoved(string pluginId)
        signal pluginUnloaded(string pluginId)
        signal pluginReloaded(string pluginId)
        signal catalogChanged()

        function has(pluginId) {
            return String(pluginId) === "stillsuit.multi"
        }

        function get(pluginId) {
            return has(pluginId) ? entries["stillsuit.multi"] : null
        }

        function isEnabled(pluginId) {
            return has(pluginId)
        }

        function hasKind(pluginId, kind) {
            return has(pluginId) && entries["stillsuit.multi"].manifest.kinds.indexOf(kind) !== -1
        }

        function primarySurfaceKind(pluginId) {
            return has(pluginId) ? "panel" : ""
        }

        function entryPointUrl(entry, kind) {
            if (kind === "panel")
                return Qt.resolvedUrl("fixtures/plugins/multi/Panel.qml")
            if (kind === "overlay")
                return Qt.resolvedUrl("fixtures/plugins/multi/Overlay.qml")
            return ""
        }

        function topologicalOrder() {
            return ["stillsuit.multi"]
        }
    }

    SurfaceRouter {
        id: multiRouter
        catalog: multiCatalog
        hostContext: fakeHostContext
        serviceRegistry: fakeServices
        compositor: fakeCompositor
        screens: [screenA, screenB]
        componentFactory: function(url, mode) {
            return Qt.createComponent(url, Component.PreferSynchronous)
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
            var defaultBuiltin = builtinHostContext.contextForBuiltin(
                "stillsuit.fixture-default", "/fixture")
            var shadowBuiltin = builtinHostContext.contextForBuiltin(
                "stillsuit.fixture-shadow", "/fixture", { shadowMode: true })
            _assert(defaultBuiltin.settings.values.shadowMode === false,
                "builtin shadow mode did not default false")
            _assert(shadowBuiltin.settings.values.shadowMode === true,
                "builtin shadow mode was not injected")
            _assert(defaultBuiltin.theme.palette === undefined,
                "plugin theme exposed the raw palette")
            _assert(defaultBuiltin.theme.semantic.surface.panel === "#111111",
                "plugin theme lost its semantic roles")

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
            _assert(router.pendingKinds("stillsuit.async").join(",") === "panel,panel",
                "surface payload queue lost its contribution kind")
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
            var loaded = router.contributionInstances("stillsuit.async", "panel")[0]
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

            fakeServices.setState("stillsuit.dependency", "loading")
            _assert(router.open("stillsuit.dependent", "{\"queued\":true}") === "ok",
                "waiting dependent surface rejected its open")
            _assert(router.state("stillsuit.dependent") === "unloaded"
                    && router.pendingCount("stillsuit.dependent") === 1,
                "waiting dependent surface did not retain its queued payload")
            fakeServices.setState("stillsuit.dependency", "loaded")
            _assert(router.state("stillsuit.dependent") === "loading",
                "ready dependency did not retry the queued open")
            fakeComponent.status = Component.Ready
            var dependent = router.contributionInstances(
                "stillsuit.dependent", "panel")[0]
            _assert(router.state("stillsuit.dependent") === "loaded"
                    && router.pendingCount("stillsuit.dependent") === 0,
                "retried dependent surface did not finish loading")
            _assert(dependent.receivedPayloads.length === 1
                    && dependent.receivedPayloads[0] === "{\"queued\":true}",
                "retried dependent surface did not receive its payload once")
            fakeServices.revision++
            _assert(router.contributionInstances(
                        "stillsuit.dependent", "panel")[0] === dependent
                    && dependent.receivedPayloads.length === 1,
                "later service revision duplicated the retried open")
            _assert(router.close("stillsuit.dependent") === "ok",
                "retried dependent surface did not close")

            _assert(router.open("stillsuit.dependent", "{\"contained\":true}") === "ok",
                "dependent containment fixture did not begin loading")
            _assert(router.pendingCount("stillsuit.dependent") === 1,
                "dependent containment fixture did not queue its payload")
            fakeServices.dependencyContained("stillsuit.dependent")
            _assert(router.state("stillsuit.dependent") === "unloaded"
                    && router.pendingCount("stillsuit.dependent") === 0,
                "dependency containment did not unload the dependent route")
            fakeComponent.status = Component.Ready
            _assert(router.state("stillsuit.dependent") === "unloaded",
                "contained dependent revived after late completion")

            multiRouter.reload("stillsuit.multi")
            _assert(multiRouter.state("stillsuit.multi") === "loaded",
                "multi-contribution plugin did not load")
            var panels = multiRouter.contributionInstances("stillsuit.multi", "panel")
            var overlays = multiRouter.contributionInstances("stillsuit.multi", "overlay")
            _assert(panels.length === 2 && overlays.length === 2,
                "per-output contributions were not constructed once per screen")
            _assert(panels[0].fixtureKind === "panel"
                    && overlays[0].fixtureKind === "overlay",
                "overlay contribution was replaced by the primary panel route")
            _assert(panels[0].service === fixtureSingleton
                    && panels[1].service === fixtureSingleton
                    && overlays[0].service === fixtureSingleton
                    && overlays[1].service === fixtureSingleton,
                "visual contributions did not receive the exact singleton service")
            _assert(fakeServices.objectCount === 1,
                "multi-contribution construction changed the service count")
            _assert(panels[0].screen === screenA && panels[0].outputId === "output-a"
                    && overlays[1].screen === screenB && overlays[1].outputId === "output-b",
                "screen and output ID were not available during construction")
            fakeCompositor.focusedOutputId = "output-a"
            _assert(multiRouter.open("stillsuit.multi", "{\"screen\":\"a\"}") === "ok",
                "per-output primary panel did not open")
            _assert(multiRouter.activeId === "stillsuit.multi"
                    && multiRouter.placementOutputId("stillsuit.multi") === "output-a"
                    && panels[0].opened && !panels[1].opened,
                "per-output primary panel opened on the wrong output")
            var retainedPanel = panels[1]
            var retainedOverlay = overlays[1]
            multiRouter.screens = [screenB, screenC]
            multiRouter._reconcileScreens()
            panels = multiRouter.contributionInstances("stillsuit.multi", "panel")
            overlays = multiRouter.contributionInstances("stillsuit.multi", "overlay")
            _assert(panels.length === 2 && overlays.length === 2
                    && multiRouter.objectCount === 4,
                "screen reconciliation changed the contribution cardinality")
            _assert(panels[0] === retainedPanel && overlays[0] === retainedOverlay,
                "screen reconciliation replaced an unchanged output instance")
            _assert(multiRouter.isOpen("stillsuit.multi")
                    && multiRouter.activeId === "stillsuit.multi"
                    && multiRouter.placementOutputId("stillsuit.multi") === "output-b",
                "screen reconciliation left the open session on a removed output")
            _assert(panels[0].opened && !panels[1].opened
                    && panels[0].receivedPayloads.length === 1
                    && panels[0].receivedPayloads[0] === "",
                "screen reconciliation did not open exactly one replacement instance")
            _assert(panels[1].outputId === "output-c"
                    && overlays[1].outputId === "output-c",
                "screen reconciliation did not add both contribution kinds")
            _assert(panels[1].service === fixtureSingleton
                    && overlays[1].service === fixtureSingleton
                    && fakeServices.objectCount === 1,
                "screen reconciliation constructed another service")
            _assert(panels[0].outputId === "output-b"
                    && panels[1].outputId === "output-c"
                    && overlays[0].outputId === "output-b"
                    && overlays[1].outputId === "output-c",
                "screen reconciliation retained a removed output")

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

    function _serviceEntry(pluginId, dependencies) {
        return {
            packageRoot: "/fixture",
            signature: "fixture:" + pluginId,
            settings: {},
            manifest: {
                id: pluginId,
                kinds: ["service"],
                entryPoints: { service: "Service.qml" },
                scope: { service: "global" },
                dependencies: dependencies
            }
        }
    }

    function _dependentEntry() {
        var entry = _entry(false)
        entry.signature = "fixture:dependent"
        entry.manifest.id = "stillsuit.dependent"
        entry.manifest.dependencies = ["stillsuit.dependency"]
        return entry
    }

    function _multiEntry() {
        return {
            packageRoot: "/fixture",
            signature: "fixture:multi",
            settings: {},
            manifest: {
                id: "stillsuit.multi",
                kinds: ["service", "panel", "overlay"],
                entryPoints: {
                    service: "Service.qml",
                    panel: "Panel.qml",
                    overlay: "Overlay.qml"
                },
                scope: {
                    service: "global",
                    panel: "per-output",
                    overlay: "per-output"
                },
                dependencies: [],
                keepLoaded: true
            }
        }
    }
}
