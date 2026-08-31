import QtQuick
import Quickshell.Io
import "ManifestValidator.js" as ManifestValidator

QtObject {
    id: root

    property string catalogPath: ""
    property bool allowLocalPlugins: false
    property QtObject hostContext: null
    property QtObject serviceRegistry: null
    property var outputScreens: []
    property url fallbackBarUrl: Qt.resolvedUrl("../plugins/builtin/bar/Bar.qml")
    property Component fallbackBarComponent: null
    property QtObject fallbackContext: null

    readonly property bool loaded: internalLoaded
    readonly property bool ready: internalLoaded
        && loadError === ""
        && pendingVisualLoads === 0
        && barState === "loaded"
    readonly property int revision: internalRevision
    readonly property string selectedBarId: internalSelectedBarId
    readonly property string activeBarId: internalActiveBarId
    readonly property bool fallbackActive: internalActiveBarId === "stillsuit.builtin-bar"
    readonly property var entries: internalEntries
    readonly property var failures: internalFailures
    readonly property var runtimeErrors: internalRuntimeErrors
    readonly property var widgetComponents: internalWidgetComponents
    readonly property int pendingLoads: pendingVisualLoads

    property bool internalLoaded: false
    property int internalRevision: 0
    property string internalSelectedBarId: ""
    property string internalActiveBarId: ""
    property string loadError: ""
    property string barState: "unloaded"
    property string barError: ""
    property int pendingVisualLoads: 0
    property var internalEntries: ({})
    property var internalFailures: ({})
    property var internalRuntimeErrors: ({})
    property var internalWidgetComponents: ({})
    property var widgetClaims: ({})
    property var runtimeDisabled: ({})
    property var widgetTokens: ({})
    property int nextToken: 0
    property int barToken: 0
    property var barComponent: null
    property var barInstance: null

    signal catalogChanged()
    signal entryAdded(string pluginId)
    signal entryChanged(string pluginId)
    signal entryRemoved(string pluginId)
    signal pluginUnloaded(string pluginId)
    signal pluginReloaded(string pluginId)
    signal rescanFinished()

    property FileView catalogFile: FileView {
        path: root.catalogPath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property Connections serviceRegistryConnections: Connections {
        target: root.serviceRegistry
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._syncBarInputs()
        }
    }

    property Component pathProbeComponent: Component {
        FileView {
            preload: false
            blockLoading: true
            blockAllReads: true
            printErrors: false
        }
    }

    function rescan() {
        if (catalogPath === "") {
            _documentFailed("catalog path is empty")
            return
        }
        var text = catalogFile.text()
        if (text === "") {
            _documentFailed("cannot read catalog " + catalogPath)
            return
        }
        _readCatalog(text)
    }

    function applyDocument(document) {
        var wrapperError = _validateCatalogDocument(document)
        if (wrapperError !== "") {
            _documentFailed(wrapperError)
            return false
        }

        var candidates = {}
        var failuresNext = {}
        var duplicateIds = {}
        for (var index = 0; index < document.plugins.length; index++) {
            var result = _validateCatalogEntry(document.plugins[index], index)
            if (result.errors.length > 0) {
                failuresNext[result.key] = result.errors
                continue
            }

            var pluginId = result.entry.manifest.id
            if (candidates[pluginId] !== undefined) {
                duplicateIds[pluginId] = true
                delete candidates[pluginId]
                failuresNext[pluginId] = ["duplicate plugin ID"]
                continue
            }
            if (duplicateIds[pluginId] === true)
                continue
            candidates[pluginId] = result.entry
        }

        _rejectMissingDependencies(candidates, failuresNext)
        _rejectDependencyCycles(candidates, failuresNext)
        _rejectMissingDependencies(candidates, failuresNext)
        _installCatalog(document.selectedBar || "", candidates, failuresNext)
        return true
    }

    function has(pluginId) {
        return internalEntries[String(pluginId)] !== undefined
    }

    function get(pluginId) {
        return internalEntries[String(pluginId)] || null
    }

    function isEnabled(pluginId) {
        var key = String(pluginId)
        var entry = internalEntries[key]
        return entry !== undefined && entry.enabled !== false && runtimeDisabled[key] !== true
    }

    function hasKind(pluginId, kind) {
        var entry = get(pluginId)
        return entry !== null && entry.manifest.kinds.indexOf(kind) !== -1
    }

    function contributionState(pluginId, kind) {
        var key = String(pluginId)
        if (!has(key) || !isEnabled(key))
            return "unloaded"
        if (internalRuntimeErrors[key + ":" + kind] !== undefined)
            return "error"
        if (kind === "bar") {
            if (internalSelectedBarId !== key)
                return "unloaded"
            return internalActiveBarId === key ? "loaded" : barState
        }
        if (kind === "bar-widget") {
            if (widgetClaims[key] === "loading")
                return "loading"
            return internalWidgetComponents[key] ? "loaded" : "unloaded"
        }
        return "unloaded"
    }

    function widgetRegistration(pluginId) {
        var key = String(pluginId)
        var component = internalWidgetComponents[key]
        var entry = get(key)
        if (!component || !entry || !isEnabled(key))
            return null
        var ownsService = entry.manifest.kinds.indexOf("service") !== -1
        if (ownsService && (!serviceRegistry || !serviceRegistry.has(key)))
            return null
        var registration = {
            component: component,
            context: hostContext ? hostContext.contextFor(entry) : null,
            manifest: entry.manifest,
            defaultSection: entry.manifest.barWidget
                ? entry.manifest.barWidget.defaultSection || "center"
                : "center",
            allowMultiple: entry.manifest.barWidget
                ? entry.manifest.barWidget.allowMultiple === true
                : false,
            release: function(message) {
                root._releaseConstructedWidget(key, component, message)
            }
        }
        if (ownsService)
            registration.service = serviceRegistry.get(key)
        return registration
    }

    function widgetClaimed(pluginId) {
        return widgetClaims[String(pluginId)] !== undefined
    }

    function entryPointUrl(entry, kind) {
        if (!entry || !entry.manifest)
            return ""
        var key = ManifestValidator.entryPointKey(kind)
        var relativePath = key ? entry.manifest.entryPoints[key] : ""
        if (!ManifestValidator.entryPointValid(relativePath))
            return ""

        var rootPath = _normalizeRoot(entry.packageRoot)
        var resolvedPath = rootPath + "/" + relativePath
        if (resolvedPath.indexOf(rootPath + "/") !== 0)
            return ""
        return "file://" + encodeURI(resolvedPath)
    }

    function primarySurfaceKind(pluginId) {
        var entry = get(pluginId)
        if (!entry)
            return ""
        var orderedKinds = ["panel", "overlay", "menu"]
        for (var index = 0; index < orderedKinds.length; index++) {
            if (entry.manifest.kinds.indexOf(orderedKinds[index]) !== -1)
                return orderedKinds[index]
        }
        return ""
    }

    function topologicalOrder() {
        var visited = {}
        var result = []
        var ids = Object.keys(internalEntries).sort()

        function visit(pluginId) {
            if (visited[pluginId] === true)
                return
            visited[pluginId] = true
            var entry = internalEntries[pluginId]
            var dependencies = entry.manifest.dependencies || []
            for (var dependencyIndex = 0; dependencyIndex < dependencies.length; dependencyIndex++)
                visit(dependencies[dependencyIndex])
            result.push(pluginId)
        }

        for (var index = 0; index < ids.length; index++)
            visit(ids[index])
        return result
    }

    function unload(pluginId) {
        var key = String(pluginId)
        if (!has(key))
            return "unknown"
        _setRuntimeDisabled(key, true)
        _unloadVisualContributions(key)
        pluginUnloaded(key)
        if (internalSelectedBarId === key)
            _reconcileBar()
        return "ok"
    }

    function reload(pluginId) {
        var key = String(pluginId)
        if (!has(key))
            return "unknown"
        _setRuntimeDisabled(key, false)
        _clearRuntimeErrors(key)
        _unloadVisualContributions(key)
        pluginReloaded(key)
        _loadVisualContributions(key)
        _reconcileBar()
        return "ok"
    }

    function statusRecords() {
        var records = {}
        var ids = Object.keys(internalEntries).sort()
        for (var index = 0; index < ids.length; index++) {
            var pluginId = ids[index]
            var entry = internalEntries[pluginId]
            records[pluginId] = {
                enabled: isEnabled(pluginId),
                manifestVersion: entry.manifest.version,
                widgetClaimed: widgetClaimed(pluginId),
                visual: _visualStatus(pluginId)
            }
        }
        for (var failureId in internalFailures) {
            records[failureId] = {
                enabled: false,
                state: "error",
                errors: internalFailures[failureId]
            }
        }
        return records
    }

    function _readCatalog(text) {
        var document
        try {
            document = JSON.parse(text)
        } catch (error) {
            _documentFailed("catalog is not valid JSON: " + error)
            return
        }
        applyDocument(document)
    }

    function _validateCatalogDocument(document) {
        if (!ManifestValidator.isPlainObject(document))
            return "catalog must be an object"
        if (!ManifestValidator.hasOnlyKeys(document, ["schemaVersion", "selectedBar", "plugins"]))
            return "catalog contains an unknown field"
        if (document.schemaVersion !== 1)
            return "catalog schemaVersion must be 1"
        if (document.selectedBar !== undefined
                && document.selectedBar !== ""
                && !ManifestValidator.pluginIdValid(document.selectedBar))
            return "selectedBar is not a valid plugin ID"
        if (!Array.isArray(document.plugins))
            return "catalog plugins must be an array"
        return ""
    }

    function _validateCatalogEntry(value, index) {
        var errors = []
        var key = "catalog[" + index + "]"
        if (!ManifestValidator.isPlainObject(value))
            return { key: key, errors: ["catalog entry must be an object"], entry: null }
        if (!ManifestValidator.hasOnlyKeys(value,
                ["packageRoot", "sourceMode", "enabled", "settings", "manifest"]))
            errors.push("catalog entry contains an unknown field")

        var manifestErrors = ManifestValidator.validate(value.manifest)
        if (value.manifest && ManifestValidator.pluginIdValid(value.manifest.id))
            key = value.manifest.id
        for (var manifestErrorIndex = 0;
                manifestErrorIndex < manifestErrors.length;
                manifestErrorIndex++)
            errors.push(manifestErrors[manifestErrorIndex])

        var sourceMode = value.sourceMode === undefined ? "store" : value.sourceMode
        if (sourceMode !== "store" && sourceMode !== "local")
            errors.push("sourceMode must be store or local")
        if (sourceMode === "local" && !allowLocalPlugins)
            errors.push("local plugins are disabled")
        if (typeof value.packageRoot !== "string" || value.packageRoot.charAt(0) !== "/") {
            errors.push("packageRoot must be absolute")
        } else {
            var normalizedRoot = _normalizeRoot(value.packageRoot)
            if (normalizedRoot !== value.packageRoot.replace(/\/$/, ""))
                errors.push("packageRoot must be canonical")
            if (sourceMode === "store"
                    && !/^\/nix\/store\/[a-z0-9]{32}-[^/]+(?:\/[^/]+)*$/.test(normalizedRoot))
                errors.push("store packageRoot must be below one Nix store path")
        }
        if (value.enabled !== undefined && typeof value.enabled !== "boolean")
            errors.push("enabled must be boolean")
        if (value.settings !== undefined && !ManifestValidator.isPlainObject(value.settings))
            errors.push("settings must be an object")

        if (errors.length === 0) {
            for (var contributionIndex = 0;
                    contributionIndex < value.manifest.kinds.length;
                    contributionIndex++) {
                var kind = value.manifest.kinds[contributionIndex]
                var relativePath = value.manifest.entryPoints[ManifestValidator.entryPointKey(kind)]
                var absolutePath = _normalizeRoot(value.packageRoot) + "/" + relativePath
                if (!_pathExists(absolutePath))
                    errors.push("entry point does not exist: " + relativePath)
            }
        }

        return {
            key: key,
            errors: errors,
            entry: errors.length === 0 ? {
                packageRoot: _normalizeRoot(value.packageRoot),
                sourceMode: sourceMode,
                enabled: value.enabled !== false,
                settings: value.settings || {},
                manifest: value.manifest,
                signature: JSON.stringify(value)
            } : null
        }
    }

    function _pathExists(path) {
        var probe = pathProbeComponent.createObject(root, { path: path })
        if (!probe)
            return false
        probe.text()
        var exists = probe.loaded
        probe.destroy()
        return exists
    }

    function _normalizeRoot(path) {
        if (typeof path !== "string" || path.charAt(0) !== "/")
            return ""
        var parts = path.split("/")
        var normalized = []
        for (var index = 0; index < parts.length; index++) {
            var part = parts[index]
            if (part === "" || part === ".")
                continue
            if (part === "..") {
                if (normalized.length > 0)
                    normalized.pop()
                continue
            }
            normalized.push(part)
        }
        return "/" + normalized.join("/")
    }

    function _rejectMissingDependencies(candidates, failuresNext) {
        var changed = true
        while (changed) {
            changed = false
            var ids = Object.keys(candidates)
            for (var index = 0; index < ids.length; index++) {
                var pluginId = ids[index]
                var dependencies = candidates[pluginId].manifest.dependencies || []
                for (var dependencyIndex = 0;
                        dependencyIndex < dependencies.length;
                        dependencyIndex++) {
                    if (candidates[dependencies[dependencyIndex]] === undefined) {
                        failuresNext[pluginId] = ["missing dependency: " + dependencies[dependencyIndex]]
                        delete candidates[pluginId]
                        changed = true
                        break
                    }
                }
            }
        }
    }

    function _rejectDependencyCycles(candidates, failuresNext) {
        var visiting = {}
        var visited = {}
        var stack = []
        var cycleMembers = {}

        function visit(pluginId) {
            if (visiting[pluginId] === true) {
                var start = stack.indexOf(pluginId)
                for (var cycleIndex = start; cycleIndex < stack.length; cycleIndex++)
                    cycleMembers[stack[cycleIndex]] = true
                return
            }
            if (visited[pluginId] === true)
                return
            visiting[pluginId] = true
            stack.push(pluginId)
            var dependencies = candidates[pluginId].manifest.dependencies || []
            for (var dependencyIndex = 0;
                    dependencyIndex < dependencies.length;
                    dependencyIndex++)
                visit(dependencies[dependencyIndex])
            stack.pop()
            visiting[pluginId] = false
            visited[pluginId] = true
        }

        var ids = Object.keys(candidates)
        for (var index = 0; index < ids.length; index++)
            visit(ids[index])
        for (var cycleId in cycleMembers) {
            failuresNext[cycleId] = ["dependency cycle"]
            delete candidates[cycleId]
        }
    }

    function _installCatalog(selectedBar, candidates, failuresNext) {
        var oldEntries = internalEntries
        var oldSelectedBar = internalSelectedBarId
        var wasLoaded = internalLoaded
        var oldIds = Object.keys(oldEntries)
        var nextIds = Object.keys(candidates)
        var changedIds = []
        var addedIds = []
        var selectedEntryChanged = false

        for (var oldIndex = 0; oldIndex < oldIds.length; oldIndex++) {
            var oldId = oldIds[oldIndex]
            if (!candidates[oldId] || candidates[oldId].signature !== oldEntries[oldId].signature) {
                _unloadVisualContributions(oldId)
                if (!candidates[oldId])
                    entryRemoved(oldId)
                if (oldId === oldSelectedBar || oldId === selectedBar)
                    selectedEntryChanged = true
            }
        }
        for (var nextIndex = 0; nextIndex < nextIds.length; nextIndex++) {
            var nextId = nextIds[nextIndex]
            if (!oldEntries[nextId])
                addedIds.push(nextId)
            else if (oldEntries[nextId].signature !== candidates[nextId].signature) {
                changedIds.push(nextId)
                if (nextId === oldSelectedBar || nextId === selectedBar)
                    selectedEntryChanged = true
            }
            if (!oldEntries[nextId] && nextId === selectedBar)
                selectedEntryChanged = true
        }

        internalEntries = candidates
        internalFailures = failuresNext
        internalSelectedBarId = selectedBar
        internalLoaded = true
        loadError = ""
        internalRevision++

        for (var changedIndex = 0; changedIndex < changedIds.length; changedIndex++) {
            _clearRuntimeErrors(changedIds[changedIndex])
            entryChanged(changedIds[changedIndex])
            _loadVisualContributions(changedIds[changedIndex])
        }
        for (var addedIndex = 0; addedIndex < addedIds.length; addedIndex++) {
            entryAdded(addedIds[addedIndex])
            _loadVisualContributions(addedIds[addedIndex])
        }
        _loadUnclaimedWidgets()
        if (!wasLoaded || oldSelectedBar !== selectedBar || selectedEntryChanged)
            _reconcileBar()
        catalogChanged()
        rescanFinished()
    }

    function _documentFailed(message) {
        loadError = message
        internalLoaded = true
        internalFailures = { catalog: [message] }
        internalRevision++
        _invalidateBarLoad()
        _activateFallback(message)
        catalogChanged()
        rescanFinished()
    }

    function _loadUnclaimedWidgets() {
        var ids = Object.keys(internalEntries)
        for (var index = 0; index < ids.length; index++)
            _loadVisualContributions(ids[index])
    }

    function _loadVisualContributions(pluginId) {
        if (!isEnabled(pluginId))
            return
        var entry = get(pluginId)
        if (entry.manifest.kinds.indexOf("bar-widget") !== -1
                && internalRuntimeErrors[pluginId + ":bar-widget"] === undefined
                && widgetClaims[pluginId] === undefined
                && internalWidgetComponents[pluginId] === undefined)
            _loadWidget(pluginId)
    }

    function _loadWidget(pluginId) {
        var entry = get(pluginId)
        var url = entryPointUrl(entry, "bar-widget")
        if (url === "") {
            _recordRuntimeError(pluginId, "bar-widget", "invalid widget entry-point path")
            return
        }

        var token = ++nextToken
        var tokensNext = _copy(widgetTokens)
        tokensNext[pluginId] = token
        widgetTokens = tokensNext
        var claimsNext = _copy(widgetClaims)
        claimsNext[pluginId] = "loading"
        widgetClaims = claimsNext
        pendingVisualLoads++

        var component = Qt.createComponent(url, Component.Asynchronous)
        function finalize() {
            if (widgetTokens[pluginId] !== token) {
                if (component.status !== Component.Loading)
                    component.destroy()
                return
            }
            if (component.status === Component.Loading)
                return
            _finishPendingVisualLoad()
            if (component.status === Component.Ready) {
                var componentsNext = _copy(internalWidgetComponents)
                componentsNext[pluginId] = component
                internalWidgetComponents = componentsNext
                var readyClaims = _copy(widgetClaims)
                readyClaims[pluginId] = "loaded"
                widgetClaims = readyClaims
                _syncBarInputs()
                return
            }

            _releaseWidgetClaim(pluginId)
            _recordRuntimeError(pluginId, "bar-widget", component.errorString())
            component.destroy()
        }
        if (component.status === Component.Loading)
            component.statusChanged.connect(finalize)
        else
            finalize()
    }

    function _reconcileBar() {
        _invalidateBarLoad()
        _destroyBar()
        if (internalSelectedBarId === "") {
            barError = ""
            barState = "loaded"
            return
        }

        var entry = get(internalSelectedBarId)
        if (!entry || !isEnabled(internalSelectedBarId)
                || entry.manifest.kinds.indexOf("bar") === -1) {
            _activateFallback("selected bar is unavailable: " + internalSelectedBarId)
            return
        }

        var url = entryPointUrl(entry, "bar")
        if (url === "") {
            _recordRuntimeError(internalSelectedBarId, "bar", "invalid bar entry-point path")
            _activateFallback("selected bar path is invalid")
            return
        }

        var pluginId = internalSelectedBarId
        var token = ++nextToken
        barToken = token
        barState = "loading"
        barError = ""
        pendingVisualLoads++
        var component = Qt.createComponent(url, Component.Asynchronous)
        barComponent = component

        function finalize() {
            if (barToken !== token)
                return
            if (component.status === Component.Loading)
                return
            _finishPendingVisualLoad()
            if (component.status !== Component.Ready) {
                var compileError = component.errorString()
                _recordRuntimeError(pluginId, "bar", compileError)
                component.destroy()
                barComponent = null
                _activateFallback(compileError)
                return
            }

            var instance = component.createObject(root, {
                context: hostContext ? hostContext.contextFor(entry) : null,
                widgetRegistrations: _widgetRegistrations(),
                outputScreens: outputScreens
            })
            if (!instance) {
                var constructionError = "selected bar construction returned null"
                _recordRuntimeError(pluginId, "bar", constructionError)
                component.destroy()
                barComponent = null
                _activateFallback(constructionError)
                return
            }
            barInstance = instance
            internalActiveBarId = pluginId
            barState = "loaded"
            _syncBarInputs()
        }
        if (component.status === Component.Loading)
            component.statusChanged.connect(finalize)
        else
            finalize()
    }

    function _activateFallback(reason) {
        _destroyBar()
        barError = reason
        if (String(fallbackBarUrl) !== "") {
            var functionalComponent = Qt.createComponent(
                fallbackBarUrl, Component.PreferSynchronous)
            if (functionalComponent.status === Component.Ready) {
                var functionalInstance = functionalComponent.createObject(root, {
                    context: fallbackContext,
                    widgetRegistrations: _widgetRegistrations(),
                    outputScreens: outputScreens
                })
                if (functionalInstance) {
                    barComponent = functionalComponent
                    barInstance = functionalInstance
                    internalActiveBarId = "stillsuit.builtin-bar"
                    barState = "loaded"
                    _syncBarInputs()
                    return
                }
            }
            functionalComponent.destroy()
        }
        if (!fallbackBarComponent || fallbackBarComponent.status !== Component.Ready) {
            barState = "error"
            internalActiveBarId = ""
            return
        }
        var instance = fallbackBarComponent.createObject(root, {
            context: fallbackContext
        })
        if (!instance) {
            barState = "error"
            internalActiveBarId = ""
            return
        }
        barInstance = instance
        internalActiveBarId = "stillsuit.builtin-bar"
        barState = "loaded"
        _syncBarInputs()
    }

    function _unloadVisualContributions(pluginId) {
        var key = String(pluginId)
        var tokensNext = _copy(widgetTokens)
        if (tokensNext[key] !== undefined) {
            delete tokensNext[key]
            widgetTokens = tokensNext
            if (widgetClaims[key] === "loading")
                _finishPendingVisualLoad()
        }
        var component = internalWidgetComponents[key]
        if (component && typeof component.destroy === "function")
            component.destroy()
        _releaseWidgetClaim(key)

        if (internalSelectedBarId === key || internalActiveBarId === key) {
            _invalidateBarLoad()
            _destroyBar()
            barState = "unloaded"
        }
    }

    function _releaseWidgetClaim(pluginId) {
        var claimsNext = _copy(widgetClaims)
        delete claimsNext[pluginId]
        widgetClaims = claimsNext
        var componentsNext = _copy(internalWidgetComponents)
        delete componentsNext[pluginId]
        internalWidgetComponents = componentsNext
    }

    function _releaseConstructedWidget(pluginId, component, message) {
        var key = String(pluginId)
        if (internalWidgetComponents[key] !== component)
            return
        if (component && typeof component.destroy === "function")
            component.destroy()
        _releaseWidgetClaim(key)
        _recordRuntimeError(key, "bar-widget", message)
        _syncBarInputs()
    }

    function _widgetRegistrations() {
        var registrations = []
        var ids = Object.keys(internalEntries).sort()
        for (var index = 0; index < ids.length; index++) {
            var pluginId = ids[index]
            if (!hasKind(pluginId, "bar-widget"))
                continue
            var registration = widgetRegistration(pluginId)
            if (registration)
                registrations.push(registration)
        }
        return registrations
    }

    function _syncBarInputs() {
        if (!barInstance)
            return
        if ("widgetRegistrations" in barInstance)
            barInstance.widgetRegistrations = _widgetRegistrations()
        if ("outputScreens" in barInstance)
            barInstance.outputScreens = outputScreens
    }

    function _invalidateBarLoad() {
        if (barState === "loading")
            _finishPendingVisualLoad()
        barToken = ++nextToken
    }

    function _destroyBar() {
        if (barInstance && typeof barInstance.destroy === "function")
            barInstance.destroy()
        barInstance = null
        if (barComponent && typeof barComponent.destroy === "function")
            barComponent.destroy()
        barComponent = null
        internalActiveBarId = ""
    }

    function _finishPendingVisualLoad() {
        pendingVisualLoads = Math.max(0, pendingVisualLoads - 1)
    }

    function _recordRuntimeError(pluginId, kind, message) {
        var errorsNext = _copy(internalRuntimeErrors)
        errorsNext[String(pluginId) + ":" + kind] = String(message || "unknown component error")
        internalRuntimeErrors = errorsNext
    }

    function _clearRuntimeErrors(pluginId) {
        var prefix = String(pluginId) + ":"
        var errorsNext = {}
        for (var key in internalRuntimeErrors) {
            if (key.indexOf(prefix) !== 0)
                errorsNext[key] = internalRuntimeErrors[key]
        }
        internalRuntimeErrors = errorsNext
    }

    function _setRuntimeDisabled(pluginId, disabled) {
        var disabledNext = _copy(runtimeDisabled)
        if (disabled)
            disabledNext[pluginId] = true
        else
            delete disabledNext[pluginId]
        runtimeDisabled = disabledNext
    }

    function _visualStatus(pluginId) {
        var entry = get(pluginId)
        var result = {}
        for (var index = 0; index < entry.manifest.kinds.length; index++) {
            var kind = entry.manifest.kinds[index]
            if (kind === "bar" || kind === "bar-widget")
                result[kind] = contributionState(pluginId, kind)
        }
        return result
    }

    function _copy(value) {
        var result = {}
        for (var key in value)
            result[key] = value[key]
        return result
    }

    onOutputScreensChanged: _syncBarInputs()
}
