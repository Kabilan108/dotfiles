// Stillsuit plugin workbench: the production core (catalog, service registry,
// surface router, panel hosts, IPC facade) running against fixture-driven
// service models and a synthetic compositor, inside an isolated XDG sandbox.
// Plugins under the sandbox root are discovered and reloaded exactly as in
// production; the stillsuit-workbench launcher owns process and environment.
import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "workbench" as Workbench

ShellRoot {
    id: shell

    readonly property string homeRoot: Quickshell.env("HOME")
    readonly property string xdgConfigRoot: _xdgRoot("XDG_CONFIG_HOME", ".config")
    readonly property string xdgDataRoot: _xdgRoot("XDG_DATA_HOME", ".local/share")
    readonly property string xdgStateRoot: _xdgRoot("XDG_STATE_HOME", ".local/state")
    readonly property string configId: Quickshell.env("STILLSUIT_CONFIG_ID") || "stillsuit-workbench"
    readonly property string fixtureRoot: Quickshell.env("STILLSUIT_WORKBENCH_FIXTURES") || ""
    readonly property string themePath: Quickshell.env("STILLSUIT_THEME_PATH") || ""
    readonly property string initialFixtureId: Quickshell.env("STILLSUIT_WORKBENCH_FIXTURE") || "default"
    // Interactive runs share the real session and draw on one chosen output
    // in bar shadow mode; headless runs own every screen of their compositor.
    readonly property string outputFilter: Quickshell.env("STILLSUIT_WORKBENCH_OUTPUT") || ""
    readonly property bool shadowMode: Quickshell.env("STILLSUIT_WORKBENCH_SHADOW") === "1"
    // In shadow mode the production bar still owns the top edge. Everything
    // the core positions from barOuterGap (bar, panel hosts, toasts) moves
    // down together so the two bars stack instead of overlapping.
    readonly property real shadowOffset: shadowMode && effectiveTheme.metrics
        ? effectiveTheme.metrics.barHeight + effectiveTheme.metrics.barOuterGap + effectiveTheme.metrics.spaceUnit * 2
        : 0
    readonly property var screens: _selectScreens(Quickshell.screens, outputFilter)
    readonly property bool ready: themeLoaded && themeError === ""
        && pluginCatalog.ready && serviceRegistry.ready
        && surfaceRouter.pendingLoadCount === 0 && fixtureId !== ""

    property bool themeLoaded: false
    property string themeError: ""
    property var effectiveTheme: ({})
    readonly property var publicTheme: _publicTheme(effectiveTheme)
    property string fixtureId: ""
    property var actionLog: []
    property var liveNotifications: []
    property int nextNotificationId: 100

    FileView {
        id: themeFile
        path: shell.themePath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    Workbench.FixtureLibrary {
        id: fixtures
        directory: shell.fixtureRoot
        onIdsChanged: {
            if (shell.fixtureId === "" && ids.length > 0)
                shell.selectFixture(ids.indexOf(shell.initialFixtureId) >= 0 ? shell.initialFixtureId : ids[0])
        }
    }

    Workbench.FixtureModels {
        id: models
        onActionRecorded: function(pluginId, action, detail) {
            var next = shell.actionLog.slice(-199)
            next.push({ at: Date.now(), pluginId: pluginId, action: action, detail: String(detail) })
            shell.actionLog = next
        }
    }

    Workbench.SyntheticCompositor { id: compositor }

    HostContext {
        id: hostContext
        theme: shell.publicTheme
        compositor: compositor
        serviceRegistry: serviceRegistry
        surfaceRouter: surfaceRouter
        actionsSource: ipcFacade
        instanceId: Quickshell.instanceId
        configRoot: shell.xdgConfigRoot + "/stillsuit"
        dataRoot: shell.xdgDataRoot + "/stillsuit"
        stateRoot: shell.xdgStateRoot + "/stillsuit"
    }

    PluginCatalog {
        id: pluginCatalog
        allowLocalPlugins: true
        hostContext: hostContext
        serviceRegistry: serviceRegistry
        outputScreens: shell.screens
        fallbackContext: null
    }

    ServiceRegistry {
        id: serviceRegistry
        catalog: pluginCatalog
        hostContext: hostContext
        constructionProvider: function(pluginId) {
            var model = models.modelFor(pluginId)
            return model ? { model: model } : null
        }
        onRevisionChanged: shell.applyModels()
    }

    SurfaceRouter {
        id: surfaceRouter
        catalog: pluginCatalog
        hostContext: hostContext
        serviceRegistry: serviceRegistry
        compositor: compositor
        screens: shell.screens
    }

    IpcFacade {
        id: ipcFacade
        catalog: pluginCatalog
        serviceRegistry: serviceRegistry
        surfaceRouter: surfaceRouter
        theme: shell.publicTheme
        fallbackContext: pluginCatalog.fallbackContext
        configId: shell.configId
        instanceId: Quickshell.instanceId
        ready: shell.ready
    }

    Loader {
        active: shell.screens.length > 0
            && Quickshell.env("QT_QPA_PLATFORM") !== "offscreen"
        source: "core/PanelHosts.qml"
        onLoaded: {
            item.router = surfaceRouter
            item.theme = Qt.binding(function() { return shell.publicTheme })
            item.screens = Qt.binding(function() { return shell.screens })
        }
    }

    Connections {
        target: {
            void(serviceRegistry.revision)
            return serviceRegistry.get("stillsuit.notifications")
        }
        ignoreUnknownSignals: true
        function onBannerWillPresent(outputId) {
            surfaceRouter.interruptForBanner(outputId)
        }
    }

    Component { id: notificationComponent; HostNotice {} }

    Connections {
        target: pluginCatalog
        function onPluginContained(pluginId, kind, message) {
            shell.presentNotification({ appName: "Stillsuit", summary: pluginId + " " + kind + " omitted", body: message, urgency: 2 })
        }
    }
    Connections {
        target: serviceRegistry
        function onServiceContained(pluginId, message) {
            shell.presentNotification({ appName: "Stillsuit", summary: pluginId + " service failed", body: message, urgency: 2 })
        }
    }

    IpcHandler {
        target: "stillsuit-workbench"

        function fixtures(): string { return JSON.stringify(fixtures.ids) }
        function fixture(): string { return shell.fixtureId }
        function select(id: string): string { return shell.selectFixture(id) ? "ok" : "unknown" }
        function reloadFixtures(): string { fixtures.reload(); return "ok" }
        function notify(summary: string, body: string): string {
            return shell.presentNotification({ appName: "Workbench", summary: summary, body: body, urgency: 1 })
        }
        function actions(): string { return JSON.stringify(shell.actionLog) }
        function clearActions(): string { shell.actionLog = []; return "ok" }
        function status(): string {
            return JSON.stringify({
                ready: shell.ready,
                fixture: shell.fixtureId,
                fixtureError: fixtures.error,
                themeError: shell.themeError,
                catalogRevision: pluginCatalog.revision,
                catalogError: pluginCatalog.loadError,
                plugins: pluginCatalog.statusRecords(),
                services: serviceRegistry.statusRecords(),
                surfaces: surfaceRouter.statusRecords(),
                selectedPanel: surfaceRouter.presentedId,
                screens: shell.screens.map(function(screen) { return String(screen.name) }),
                shadowMode: shell.shadowMode,
                modelsApplied: shell._appliedModelIds()
            })
        }
    }

    Component.onCompleted: {
        var text = themeFile.text()
        if (text === "") {
            themeLoaded = true
            themeError = "cannot read theme " + themePath
        } else {
            _loadTheme(text)
        }
        pluginCatalog.fallbackContext = hostContext.contextForBuiltin(
            "stillsuit.builtin-bar", Quickshell.shellDir, { shadowMode: shell.shadowMode })
        pluginCatalog.rescan()
        fixtures.reload()
    }

    function selectFixture(id) {
        var document = fixtures.get(id)
        if (!document) return false
        fixtureId = String(id)
        models.fixture = document
        models.rebuild()
        compositor.apply(document.compositor || {}, shell.screens)
        applyModels()
        _writeWorkflowState(document)
        _replaceNotifications(document.notifications || [])
        return true
    }

    // Services are constructed by the real registry with real context; the
    // workbench only swaps their `model` input afterwards. Any service without
    // a fixture entry keeps whatever it would do in production.
    function applyModels() {
        var ids = ["stillsuit.battery", "stillsuit.power", "stillsuit.network",
            "stillsuit.bluetooth", "stillsuit.audio", "stillsuit.agent-usage"]
        for (var index = 0; index < ids.length; index++) {
            var service = serviceRegistry.get(ids[index])
            var model = models.modelFor(ids[index])
            if (!service || !("model" in service)) continue
            if (service.model !== model) service.model = model
            if (ids[index] === "stillsuit.audio" && service.mediaService && model)
                service.mediaService.model = model.media
        }
        var resources = serviceRegistry.get("stillsuit.resources")
        var resourceSpec = (models.services || {})["stillsuit.resources"]
        if (resources && resourceSpec) {
            if (resources.refreshTimer) resources.refreshTimer.running = false
            resources.cpuPercent = Number(resourceSpec.cpuPercent || 0)
            resources.memoryPercent = Number(resourceSpec.memoryPercent || 0)
        }
    }

    function presentNotification(spec) {
        var service = serviceRegistry.get("stillsuit.notifications")
        if (!service) return "unavailable"
        var notification = notificationComponent.createObject(shell, {
            id: nextNotificationId++,
            appName: String(spec.appName || "Workbench"),
            appIcon: String(spec.appIcon || ""),
            summary: String(spec.summary || ""),
            body: String(spec.body || ""),
            urgency: Number(spec.urgency === undefined ? 1 : spec.urgency),
            expireTimeout: Number(spec.expireTimeout || 0),
            actions: (spec.actions || []).map(function(action) {
                return { identifier: String(action.identifier), text: String(action.text),
                    invoke: function() { notification.lastInvoked = String(action.identifier) } }
            })
        })
        liveNotifications = liveNotifications.concat([notification])
        service.handleNotification(notification)
        return "ok"
    }

    function _replaceNotifications(specs) {
        var service = serviceRegistry.get("stillsuit.notifications")
        var previous = liveNotifications
        liveNotifications = []
        if (service && typeof service.clearHistory === "function") service.clearHistory()
        for (var index = 0; index < previous.length; index++) {
            previous[index].closed()
            previous[index].destroy()
        }
        if (service && typeof service.clearHistory === "function") service.clearHistory()
        for (var specIndex = 0; specIndex < specs.length; specIndex++)
            presentNotification(specs[specIndex])
    }

    // The workflow services read state files; the launcher points them at
    // sandbox paths, and each fixture writes what the recorder and meeting
    // worker would have produced.
    function _writeWorkflowState(document) {
        var runtimeRoot = Quickshell.env("STILLSUIT_WORKBENCH_STATE") || ""
        if (runtimeRoot === "") return
        recordingWriter.path = runtimeRoot + "/recording.json"
        recordingWriter.setText(JSON.stringify(document.recording || { schemaVersion: 1, phase: "idle" }))
        meetingJobsWriter.path = runtimeRoot + "/meeting-jobs.json"
        meetingJobsWriter.setText(JSON.stringify(document.meetingJobs || { schemaVersion: 1, jobs: [] }))
        meetingStatusWriter.path = runtimeRoot + "/meeting-status.json"
        meetingStatusWriter.setText(JSON.stringify(document.meetingStatus || { schemaVersion: 1, phase: "idle" }))
    }

    FileView { id: recordingWriter; printErrors: false }
    FileView { id: meetingJobsWriter; printErrors: false }
    FileView { id: meetingStatusWriter; printErrors: false }

    function _appliedModelIds() {
        var result = []
        for (var key in models.built) {
            var service = serviceRegistry.get(key)
            if (service && service.model === models.built[key]) result.push(key)
        }
        return result.sort()
    }

    function _selectScreens(all, filter) {
        var result = []
        for (var index = 0; index < all.length; index++) {
            if (filter === "" || String(all[index].name) === filter)
                result.push(all[index])
        }
        return result
    }

    function _xdgRoot(variable, fallbackSuffix) {
        return Quickshell.env(variable) || homeRoot + "/" + fallbackSuffix
    }

    function _loadTheme(text) {
        try {
            var parsed = JSON.parse(text)
            if (!parsed || parsed.schemaVersion !== 2)
                throw new Error("theme does not satisfy theme.v2")
            effectiveTheme = parsed
            themeError = ""
        } catch (error) {
            effectiveTheme = {}
            themeError = "theme is invalid: " + error
        }
        themeLoaded = true
    }

    function _publicTheme(value) {
        if (!value || value.schemaVersion !== 2) return {}
        var metrics = JSON.parse(JSON.stringify(value.metrics))
        metrics.barOuterGap = Number(metrics.barOuterGap || 0) + shadowOffset
        return {
            schemaVersion: value.schemaVersion, identity: value.identity,
            semantic: value.semantic, component: value.component,
            typography: value.typography, metrics: metrics,
            motion: value.motion, effects: value.effects
        }
    }
}
