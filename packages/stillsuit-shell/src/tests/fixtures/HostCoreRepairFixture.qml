import QtQuick
import Quickshell
import Quickshell.Io
import "./core"

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
        id: fakeHostContext

        function contextFor(entry) {
            return fixtureContext
        }
    }

    QtObject {
        id: fakeServices
        property int revision: 0

        signal dependencyContained(string pluginId)

        function state(pluginId) {
            return "loaded"
        }

        function get(pluginId) {
            return null
        }
    }

    QtObject {
        id: fakeCompositor
        property string focusedOutputId: "output-a"
    }

    Component {
        id: fallbackBar

        QtObject {
            property var context: null
        }
    }

    PluginCatalog {
        id: barCatalog
        allowLocalPlugins: true
        hostContext: fakeHostContext
        outputScreens: [screenA]
        fallbackBarUrl: ""
        fallbackBarComponent: fallbackBar
        fallbackContext: fixtureContext
    }

    QtObject {
        id: screenCatalog
        property bool loaded: true
        property var entries: ({
            "stillsuit.a-failing": fixture._surfaceEntry("stillsuit.a-failing"),
            "stillsuit.global": fixture._globalSurfaceEntry("stillsuit.global"),
            "stillsuit.z-migrating": fixture._surfaceEntry("stillsuit.z-migrating")
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

        function topologicalOrder() {
            return ["stillsuit.a-failing", "stillsuit.global", "stillsuit.z-migrating"]
        }
    }

    Component {
        id: fakeSurface

        QtObject {
            required property var context
            required property var screen
            required property string outputId

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

    QtObject {
        id: failingComponent
        property int status: Component.Ready
        property string failedOutputId: ""

        function createObject(parent, properties) {
            if (String(properties.outputId) === failedOutputId)
                return null
            return fakeSurface.createObject(parent, properties)
        }

        function errorString() {
            return ""
        }

        function destroy() {}
    }

    QtObject {
        id: migratingComponent
        property int status: Component.Ready

        function createObject(parent, properties) {
            return fakeSurface.createObject(parent, properties)
        }

        function errorString() {
            return ""
        }

        function destroy() {}
    }

    Component {
        id: fakeGlobalSurface

        QtObject {
            required property var context

            property var screen: null
            property var output: null
            property string outputId: ""
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

    QtObject {
        id: globalComponent
        property int status: Component.Ready

        function createObject(parent, properties) {
            return fakeGlobalSurface.createObject(parent, properties)
        }

        function errorString() {
            return ""
        }

        function destroy() {}
    }

    QtObject {
        id: stabilityHostContext

        function contextFor(entry) {
            return fixtureContext
        }

        function dropContext(pluginId) {}
    }

    QtObject {
        id: stableServiceA
    }

    QtObject {
        id: stableServiceB
    }

    QtObject {
        id: stabilityServices
        property int revision: 0
        property var instances: ({ "stillsuit.stable-service-widget": stableServiceA })

        function has(pluginId) {
            return instances[String(pluginId)] !== undefined
        }

        function get(pluginId) {
            return instances[String(pluginId)] || null
        }
    }

    Component {
        id: registrationRecordingBar

        QtObject {
            property var context: null
            property var widgetRegistrations: []
            property int assignments: 0
            onWidgetRegistrationsChanged: assignments++
        }
    }

    PluginCatalog {
        id: widgetCatalog
        allowLocalPlugins: true
        hostContext: stabilityHostContext
        serviceRegistry: stabilityServices
        outputScreens: [screenA]
        fallbackBarUrl: ""
        fallbackBarComponent: registrationRecordingBar
        fallbackContext: fixtureContext
    }

    property int stabilityPhase: 0

    SurfaceRouter {
        id: screenRouter
        catalog: screenCatalog
        hostContext: fakeHostContext
        serviceRegistry: fakeServices
        compositor: fakeCompositor
        screens: [screenA, screenB]
        componentFactory: function(url, mode) {
            var source = String(url)
            if (source.indexOf("stillsuit.a-failing") !== -1)
                return failingComponent
            if (source.indexOf("stillsuit.global") !== -1)
                return globalComponent
            return migratingComponent
        }
    }

    IpcHandler {
        target: "stillsuit-host-core-repair"

        function run(): string {
            return fixture.runContracts()
        }

        function widgetStability(): string {
            return fixture.runWidgetStability()
        }
    }

    function runContracts() {
        checks = 0
        var failures = []
        try {
            _checkCatalogFailureDuringBarLoad()
        } catch (error) {
            failures.push(String(error))
        }
        try {
            _checkScreenFailureContainment()
        } catch (error) {
            failures.push(String(error))
        }
        try {
            _checkGlobalSurfaceRehome()
        } catch (error) {
            failures.push(String(error))
        }
        return JSON.stringify({
            ok: failures.length === 0,
            checks: checks,
            errors: failures
        })
    }

    function _checkCatalogFailureDuringBarLoad() {
        var packageRoot = Quickshell.env("STILLSUIT_REPAIR_FIXTURE_ROOT")
            + "/plugins/loading-bar"
        var document = {
            schemaVersion: 1,
            selectedBar: "stillsuit.loading-bar",
            plugins: [
                {
                    packageRoot: packageRoot,
                    enabled: true,
                    settings: {},
                    manifest: {
                        schemaVersion: 1,
                        id: "stillsuit.loading-bar",
                        name: "Loading bar fixture",
                        version: "1.0.0",
                        apiVersion: "1",
                        kinds: ["bar"],
                        entryPoints: { bar: "Bar.qml" },
                        scope: { bar: "per-output" },
                        dependencies: []
                    }
                },
                {
                    packageRoot: packageRoot,
                    enabled: true,
                    settings: {},
                    manifest: {
                        schemaVersion: 1,
                        id: "stillsuit.invalid-entry",
                        name: "",
                        version: "1.0.0",
                        apiVersion: "1",
                        kinds: ["panel"],
                        entryPoints: { panel: "Panel.qml" },
                        scope: { panel: "global" },
                        dependencies: []
                    }
                }
            ]
        }

        _assert(barCatalog.applyDocument(document),
            "valid loading-bar catalog was rejected")
        _assert(barCatalog.barState === "loading" && barCatalog.pendingLoads === 1,
            "selected bar was not in flight before catalog failure")
        var initialPluginFailure = barCatalog.failures["stillsuit.invalid-entry"]
        _assert(Array.isArray(initialPluginFailure)
                && initialPluginFailure.indexOf(
                    "name must contain 1 to 80 characters") !== -1,
            "fixture catalog did not record its per-plugin failure")
        var staleToken = barCatalog.barToken

        _assert(!barCatalog.applyDocument({ schemaVersion: 2, plugins: [] }),
            "invalid catalog document was accepted")
        _assert(barCatalog.barToken !== staleToken,
            "catalog failure did not invalidate the in-flight bar token")
        _assert(barCatalog.pendingLoads === 0,
            "catalog failure did not finish the in-flight visual load exactly once")
        _assert(barCatalog.fallbackActive && barCatalog.barState === "loaded",
            "catalog failure did not leave the fallback bar active")
        var preservedPluginFailure = barCatalog.failures["stillsuit.invalid-entry"]
        _assert(Array.isArray(preservedPluginFailure)
                && preservedPluginFailure.indexOf(
                    "name must contain 1 to 80 characters") !== -1,
            "catalog document failure replaced an existing per-plugin failure")
        _assert(barCatalog.failures.catalog.length === 1
                && barCatalog.failures.catalog[0]
                    === "catalog schemaVersion must be 1",
            "catalog document failure did not add its own diagnostic")
    }

    function _checkScreenFailureContainment() {
        screenRouter.reload("stillsuit.a-failing")
        screenRouter.reload("stillsuit.z-migrating")
        _assert(screenRouter.contributionInstances(
                    "stillsuit.a-failing", "panel").length === 2,
            "failing fixture did not load on the initial screens")
        var migratingBefore = screenRouter.contributionInstances(
            "stillsuit.z-migrating", "panel")
        _assert(migratingBefore.length === 2,
            "migrating fixture did not load on the initial screens")
        var retainedOutputB = migratingBefore[1]

        _assert(screenRouter.open("stillsuit.z-migrating", "{\"before\":true}") === "ok",
            "migrating fixture did not open before screen reconciliation")
        failingComponent.failedOutputId = "output-c"
        screenRouter.screens = [screenB, screenC]
        screenRouter._reconcileScreens()

        _assert(screenRouter.contributionState(
                    "stillsuit.a-failing", "panel") === "error",
            "failed screen contribution was not reported")
        _assert(screenRouter.contributionError(
                    "stillsuit.a-failing", "panel").indexOf(
                        "screen reconciliation failed") !== -1,
            "failed screen contribution lost its diagnostic")

        var migrated = screenRouter.contributionInstances(
            "stillsuit.z-migrating", "panel")
        _assert(migrated.length === 2
                && migrated[0] === retainedOutputB
                && migrated[0].outputId === "output-b"
                && migrated[1].outputId === "output-c",
            "later plugin did not migrate after the first plugin failed")
        _assert(screenRouter.isOpen("stillsuit.z-migrating")
                && screenRouter.placementOutputId("stillsuit.z-migrating") === "output-b"
                && migrated[0].opened
                && migrated[0].receivedPayloads.length === 1
                && migrated[0].receivedPayloads[0] === "",
            "later plugin lost coherent open placement after migration")
    }

    function _checkGlobalSurfaceRehome() {
        screenRouter.screens = [screenA, screenB]
        screenRouter._reconcileScreens()
        fakeCompositor.focusedOutputId = "output-a"
        screenRouter.reload("stillsuit.global")

        _assert(screenRouter.contributionState(
                    "stillsuit.global", "panel") === "loaded",
            "global fixture did not load")
        _assert(screenRouter.open("stillsuit.global", "{\"global\":true}") === "ok",
            "global fixture did not open")
        var globalBefore = screenRouter.contributionInstances(
            "stillsuit.global", "panel")[0]
        _assert(screenRouter.placementOutputId("stillsuit.global") === "output-a"
                && globalBefore.screen === screenA
                && globalBefore.output === screenA
                && globalBefore.outputId === "output-a",
            "global fixture did not use its initial focused output")

        var perOutputBefore = screenRouter.contributionInstances(
            "stillsuit.z-migrating", "panel")
        _assert(perOutputBefore.length === 2
                && perOutputBefore[0].outputId === "output-a"
                && perOutputBefore[1].outputId === "output-b",
            "per-output fixture did not reset to the initial screens")
        var retainedOutputB = perOutputBefore[1]

        fakeCompositor.focusedOutputId = "output-c"
        screenRouter.screens = [screenB, screenC]
        screenRouter._reconcileScreens()

        var globalAfter = screenRouter.contributionInstances(
            "stillsuit.global", "panel")[0]
        _assert(globalAfter === globalBefore
                && screenRouter.isOpen("stillsuit.global")
                && screenRouter.placementOutputId("stillsuit.global") === "output-c",
            "global open surface was not rehomed to the available focused output")
        _assert(globalAfter.screen === screenC
                && globalAfter.output === screenC
                && globalAfter.outputId === "output-c",
            "global surface instance retained its removed output")
        _assert(globalAfter.receivedPayloads.length === 1
                && globalAfter.receivedPayloads[0] === "{\"global\":true}",
            "global surface rehome replayed its open payload")

        var perOutputAfter = screenRouter.contributionInstances(
            "stillsuit.z-migrating", "panel")
        _assert(perOutputAfter.length === 2
                && perOutputAfter[0] === retainedOutputB
                && perOutputAfter[0].outputId === "output-b"
                && perOutputAfter[1].outputId === "output-c"
                && !perOutputAfter[0].opened
                && !perOutputAfter[1].opened,
            "global surface rehome disturbed the per-output route")
    }

    // Polled: widget components load asynchronously and pure additions reach
    // the bar on a later event-loop turn, so this answers "pending" until the
    // two fixture widgets are registered.
    function runWidgetStability() {
        if (stabilityPhase === 0) {
            stabilityPhase = 1
            if (!widgetCatalog.applyDocument(_stabilityDocument()))
                return JSON.stringify({ ok: false, checks: 0, errors: ["stability catalog rejected"] })
            return "pending"
        }
        var bar = widgetCatalog.barInstance
        if (!bar || !bar.widgetRegistrations || bar.widgetRegistrations.length !== 2)
            return "pending"

        checks = 0
        var failures = []
        try {
            _checkWidgetRegistrationStability(bar)
        } catch (error) {
            failures.push(String(error))
        }
        return JSON.stringify({ ok: failures.length === 0, checks: checks, errors: failures })
    }

    function _checkWidgetRegistrationStability(bar) {
        var plainId = "stillsuit.stable-widget"
        var serviceId = "stillsuit.stable-service-widget"
        var initial = bar.widgetRegistrations.slice()
        var plain = widgetCatalog.widgetRegistration(plainId)
        var serviced = widgetCatalog.widgetRegistration(serviceId)
        var assignments = bar.assignments
        _assert(initial.indexOf(plain) !== -1 && initial.indexOf(serviced) !== -1,
            "catalog lookups did not return the records the bar holds")

        stabilityServices.revision++
        stabilityServices.revision++
        _assert(_sameRecords(bar.widgetRegistrations, initial)
                && bar.assignments === assignments,
            "an unrelated service revision replaced the bar's widget registrations")

        _assert(widgetCatalog.applyDocument(_stabilityDocument()),
            "no-op catalog re-sync was rejected")
        _assert(_sameRecords(bar.widgetRegistrations, initial)
                && bar.assignments === assignments,
            "a no-op catalog re-sync replaced the bar's widget registrations")
        _assert(widgetCatalog.widgetRegistration(plainId) === plain,
            "a no-op catalog re-sync minted a new registration record")

        stabilityServices.instances = ({ "stillsuit.stable-service-widget": stableServiceB })
        stabilityServices.revision++
        var replaced = widgetCatalog.widgetRegistration(serviceId)
        _assert(replaced !== serviced && replaced.service === stableServiceB,
            "a replaced service instance kept its stale registration")
        _assert(bar.widgetRegistrations.indexOf(replaced) !== -1
                && bar.widgetRegistrations.indexOf(serviced) === -1
                && bar.widgetRegistrations.indexOf(plain) !== -1,
            "a replaced service did not reach the bar synchronously")
    }

    function _sameRecords(left, right) {
        if (left.length !== right.length)
            return false
        for (var index = 0; index < left.length; index++) {
            if (left[index] !== right[index])
                return false
        }
        return true
    }

    function _stabilityDocument() {
        var packageRoot = Quickshell.env("STILLSUIT_REPAIR_FIXTURE_ROOT")
            + "/plugins/stable-widget"
        return {
            schemaVersion: 1,
            selectedBar: "stillsuit.absent-bar",
            plugins: [
                _stableWidgetEntry(packageRoot, "stillsuit.stable-widget", false),
                _stableWidgetEntry(packageRoot, "stillsuit.stable-service-widget", true)
            ]
        }
    }

    function _stableWidgetEntry(packageRoot, pluginId, ownsService) {
        var entryPoints = { barWidget: "Widget.qml" }
        var scope = { barWidget: "per-output" }
        if (ownsService) {
            entryPoints.service = "Service.qml"
            scope.service = "global"
        }
        return {
            packageRoot: packageRoot,
            enabled: true,
            settings: {},
            manifest: {
                schemaVersion: 1,
                id: pluginId,
                name: "Stable widget fixture",
                version: "1.0.0",
                apiVersion: "1",
                kinds: ownsService ? ["service", "bar-widget"] : ["bar-widget"],
                entryPoints: entryPoints,
                scope: scope,
                dependencies: [],
                barWidget: { defaultSection: "right", allowMultiple: false }
            }
        }
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
        checks++
    }

    function _surfaceEntry(pluginId) {
        return {
            packageRoot: "/fixture",
            signature: "fixture:" + pluginId,
            settings: {},
            manifest: {
                id: pluginId,
                kinds: ["panel"],
                entryPoints: { panel: "Panel.qml" },
                scope: { panel: "per-output" },
                dependencies: [],
                keepLoaded: true
            }
        }
    }

    function _globalSurfaceEntry(pluginId) {
        return {
            packageRoot: "/fixture",
            signature: "fixture:" + pluginId,
            settings: {},
            manifest: {
                id: pluginId,
                kinds: ["panel"],
                entryPoints: { panel: "Panel.qml" },
                scope: { panel: "global" },
                dependencies: [],
                keepLoaded: true
            }
        }
    }
}
