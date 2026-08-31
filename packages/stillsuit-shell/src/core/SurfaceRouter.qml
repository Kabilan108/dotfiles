import QtQuick
import "ManifestValidator.js" as ManifestValidator

QtObject {
    id: root

    property QtObject catalog: null
    property QtObject hostContext: null
    property QtObject serviceRegistry: null
    property QtObject compositor: null
    property var componentFactory: function(url, mode) {
        return Qt.createComponent(url, mode)
    }

    readonly property string activeId: internalActiveId
    readonly property string focusedOutputId: _currentFocusedOutputId()
    readonly property int revision: internalRevision
    readonly property int objectCount: _objectCount()
    readonly property int pendingLoadCount: pendingLoads

    property string internalActiveId: ""
    property int internalRevision: 0
    property int pendingLoads: 0
    property int nextToken: 0
    property var states: ({})
    property var errors: ({})
    property var queues: ({})
    property var components: ({})
    property var objects: ({})
    property var tokens: ({})
    property var sessionOpen: ({})
    property var placements: ({})
    property QtObject surfaceHost: QtObject {}

    property Connections catalogConnections: Connections {
        target: root.catalog
        ignoreUnknownSignals: true

        function onEntryAdded(pluginId) {
            root._preloadIfNeeded(pluginId)
        }

        function onEntryChanged(pluginId) {
            root.unload(pluginId)
            root._preloadIfNeeded(pluginId)
        }

        function onEntryRemoved(pluginId) {
            root.unload(pluginId)
        }

        function onPluginUnloaded(pluginId) {
            root.unload(pluginId)
        }

        function onPluginReloaded(pluginId) {
            root.reload(pluginId)
        }

        function onCatalogChanged() {
            root._preloadAll()
        }
    }

    property Connections serviceConnections: Connections {
        target: root.serviceRegistry
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._preloadAll()
        }
    }

    function state(pluginId) {
        return states[String(pluginId)] || "unloaded"
    }

    function error(pluginId) {
        return errors[String(pluginId)] || ""
    }

    function isOpen(pluginId) {
        return sessionOpen[String(pluginId)] === true
    }

    function pendingCount(pluginId) {
        var queue = queues[String(pluginId)]
        return Array.isArray(queue) ? queue.length : 0
    }

    function placementOutputId(pluginId) {
        return placements[String(pluginId)] || ""
    }

    function open(pluginId, payloadJson) {
        var key = String(pluginId)
        var validation = _validateRequest(key, payloadJson, true)
        if (validation !== "ok")
            return validation
        if (state(key) === "error")
            return "error"

        if (internalActiveId !== "" && internalActiveId !== key)
            close(internalActiveId)
        _setSessionOpen(key, true)
        internalActiveId = key
        _setPlacement(key, _currentFocusedOutputId())

        if (state(key) === "loaded") {
            _applyPlacement(key)
            return _deliverOne(key, String(payloadJson || "")) ? "ok" : "error"
        }

        _enqueue(key, String(payloadJson || ""))
        if (state(key) === "loading")
            return "ok"
        if (!_startLoad(key)) {
            _clearQueue(key)
            _setSessionOpen(key, false)
            if (internalActiveId === key)
                internalActiveId = ""
            return "error"
        }
        return "ok"
    }

    function close(pluginId) {
        var key = String(pluginId)
        if (!catalog || !catalog.has(key) || catalog.primarySurfaceKind(key) === "")
            return "unknown"

        _clearQueue(key)
        _setSessionOpen(key, false)
        if (internalActiveId === key)
            internalActiveId = ""

        var currentState = state(key)
        if (currentState === "loaded") {
            if (!_invokeClose(key))
                return "error"
            var entry = catalog.get(key)
            if (entry.manifest.keepLoaded !== true)
                _unloadObjects(key)
            return "ok"
        }
        if (currentState === "loading") {
            var loadingEntry = catalog.get(key)
            if (loadingEntry.manifest.keepLoaded !== true)
                _unloadObjects(key)
            return "ok"
        }
        return currentState === "error" ? "error" : "ok"
    }

    function toggle(pluginId, payloadJson) {
        return isOpen(pluginId) ? close(pluginId) : open(pluginId, payloadJson)
    }

    function unload(pluginId) {
        var key = String(pluginId)
        _clearQueue(key)
        _setSessionOpen(key, false)
        if (internalActiveId === key)
            internalActiveId = ""
        _unloadObjects(key)
        _clearError(key)
        _setState(key, "unloaded")
    }

    function unloadAll() {
        var ids = Object.keys(states)
        for (var index = 0; index < ids.length; index++)
            unload(ids[index])
    }

    function reload(pluginId) {
        var key = String(pluginId)
        unload(key)
        _preloadIfNeeded(key)
    }

    function statusRecords() {
        var result = {}
        if (!catalog)
            return result
        var ids = Object.keys(catalog.entries).sort()
        for (var index = 0; index < ids.length; index++) {
            var pluginId = ids[index]
            if (catalog.primarySurfaceKind(pluginId) === "")
                continue
            result[pluginId] = {
                state: state(pluginId),
                open: isOpen(pluginId),
                outputId: placementOutputId(pluginId),
                queuedPayloads: pendingCount(pluginId),
                error: error(pluginId)
            }
        }
        return result
    }

    function _validateRequest(pluginId, payloadJson, validatePayload) {
        if (!catalog || !catalog.has(pluginId)
                || catalog.primarySurfaceKind(pluginId) === "")
            return "unknown"
        if (!catalog.isEnabled(pluginId))
            return "disabled"
        if (validatePayload && !_payloadValid(payloadJson))
            return "error"

        var dependencyState = _dependencyState(catalog.get(pluginId))
        if (dependencyState !== "ready")
            return "error"
        return "ok"
    }

    function _payloadValid(payloadJson) {
        var text = String(payloadJson || "")
        if (text === "")
            return true
        try {
            JSON.parse(text)
            return true
        } catch (error) {
            return false
        }
    }

    function _dependencyState(entry) {
        var dependencies = entry.manifest.dependencies || []
        for (var index = 0; index < dependencies.length; index++) {
            var dependencyId = dependencies[index]
            if (!catalog.isEnabled(dependencyId))
                return "disabled"
            if (catalog.hasKind(dependencyId, "service")) {
                var dependencyServiceState = serviceRegistry
                    ? serviceRegistry.state(dependencyId)
                    : "unloaded"
                if (dependencyServiceState === "loading" || dependencyServiceState === "unloaded")
                    return "wait"
                if (dependencyServiceState !== "loaded")
                    return "error"
            }
        }
        return "ready"
    }

    function _startLoad(pluginId) {
        var entry = catalog.get(pluginId)
        var dependencyState = _dependencyState(entry)
        if (dependencyState === "wait")
            return false
        if (dependencyState !== "ready") {
            _fail(pluginId, "surface dependency is unavailable")
            return false
        }

        var kind = catalog.primarySurfaceKind(pluginId)
        var url = catalog.entryPointUrl(entry, kind)
        if (url === "") {
            _fail(pluginId, "invalid surface entry-point path")
            return false
        }

        var token = ++nextToken
        var tokensNext = _copy(tokens)
        tokensNext[pluginId] = token
        tokens = tokensNext
        _setState(pluginId, "loading")
        pendingLoads++
        var component = componentFactory(url, Component.Asynchronous)
        var componentsNext = _copy(components)
        componentsNext[pluginId] = component
        components = componentsNext

        function finalize() {
            if (tokens[pluginId] !== token)
                return
            if (component.status === Component.Loading)
                return
            var tokensDone = _copy(tokens)
            delete tokensDone[pluginId]
            tokens = tokensDone
            pendingLoads = Math.max(0, pendingLoads - 1)

            if (component.status !== Component.Ready) {
                _fail(pluginId, component.errorString())
                return
            }

            var instances = _createInstances(pluginId, component, entry, kind)
            if (!instances) {
                _fail(pluginId, "surface construction returned null")
                return
            }
            var objectsNext = _copy(objects)
            objectsNext[pluginId] = instances
            objects = objectsNext
            _clearError(pluginId)
            _setState(pluginId, "loaded")
            _applyPlacement(pluginId)
            _deliverQueue(pluginId)
        }

        if (component.status === Component.Loading)
            component.statusChanged.connect(finalize)
        else
            finalize()
        return true
    }

    function _createInstances(pluginId, component, entry, kind) {
        var context = hostContext ? hostContext.contextFor(entry) : null
        var scopeKey = ManifestValidator.entryPointKey(kind)
        var contributionScope = entry.manifest.scope[scopeKey]
        var outputSnapshots = contributionScope === "per-output" ? _outputs() : [null]
        if (outputSnapshots.length === 0)
            outputSnapshots = [null]
        var instances = []

        for (var index = 0; index < outputSnapshots.length; index++) {
            var instance = component.createObject(surfaceHost, { context: context })
            if (!instance) {
                for (var cleanupIndex = 0; cleanupIndex < instances.length; cleanupIndex++)
                    instances[cleanupIndex].destroy()
                return null
            }
            var output = outputSnapshots[index]
            if ("output" in instance)
                instance.output = output
            if ("outputId" in instance)
                instance.outputId = _outputId(output)
            instances.push(instance)
        }
        return instances
    }

    function _deliverQueue(pluginId) {
        if (!isOpen(pluginId)) {
            _clearQueue(pluginId)
            return true
        }
        var queue = queues[pluginId]
        if (!Array.isArray(queue) || queue.length === 0)
            return true
        _clearQueue(pluginId)
        for (var index = 0; index < queue.length; index++) {
            if (!_deliverOne(pluginId, queue[index]))
                return false
        }
        return true
    }

    function _deliverOne(pluginId, payloadJson) {
        var instance = _placedInstance(pluginId)
        if (!instance) {
            _fail(pluginId, "surface has no instance for the selected output")
            return false
        }
        try {
            if (typeof instance.open === "function")
                instance.open(payloadJson)
            else if ("visible" in instance)
                instance.visible = true
            return true
        } catch (error) {
            _fail(pluginId, "surface open failed: " + error)
            return false
        }
    }

    function _invokeClose(pluginId) {
        var instances = objects[pluginId] || []
        try {
            for (var index = 0; index < instances.length; index++) {
                if (typeof instances[index].close === "function")
                    instances[index].close()
                else if ("visible" in instances[index])
                    instances[index].visible = false
            }
            return true
        } catch (error) {
            _fail(pluginId, "surface close failed: " + error)
            return false
        }
    }

    function _applyPlacement(pluginId) {
        var instance = _placedInstance(pluginId)
        if (!instance)
            return
        var output = _outputById(placementOutputId(pluginId))
        if ("output" in instance)
            instance.output = output
        if ("outputId" in instance)
            instance.outputId = placementOutputId(pluginId)
    }

    function _placedInstance(pluginId) {
        var instances = objects[pluginId] || []
        if (instances.length === 0)
            return null
        var desiredOutputId = placementOutputId(pluginId)
        for (var index = 0; index < instances.length; index++) {
            if ("outputId" in instances[index]
                    && String(instances[index].outputId) === desiredOutputId)
                return instances[index]
        }
        return instances[0]
    }

    function _preloadAll() {
        if (!catalog || !catalog.loaded)
            return
        var ids = Object.keys(catalog.entries)
        for (var index = 0; index < ids.length; index++)
            _preloadIfNeeded(ids[index])
    }

    function _preloadIfNeeded(pluginId) {
        if (!catalog || !catalog.has(pluginId) || !catalog.isEnabled(pluginId)
                || catalog.primarySurfaceKind(pluginId) === ""
                || state(pluginId) !== "unloaded")
            return
        var entry = catalog.get(pluginId)
        if (entry.manifest.keepLoaded !== true)
            return
        if (_dependencyState(entry) !== "ready")
            return
        _startLoad(pluginId)
    }

    function _unloadObjects(pluginId) {
        var key = String(pluginId)
        var tokensNext = _copy(tokens)
        if (tokensNext[key] !== undefined) {
            delete tokensNext[key]
            tokens = tokensNext
            if (state(key) === "loading")
                pendingLoads = Math.max(0, pendingLoads - 1)
        }

        var instances = objects[key] || []
        for (var index = 0; index < instances.length; index++) {
            if (instances[index] && typeof instances[index].destroy === "function")
                instances[index].destroy()
        }
        var component = components[key]
        if (component && typeof component.destroy === "function")
            component.destroy()
        var objectsNext = _copy(objects)
        delete objectsNext[key]
        objects = objectsNext
        var componentsNext = _copy(components)
        delete componentsNext[key]
        components = componentsNext
        _setState(key, "unloaded")
    }

    function _fail(pluginId, message) {
        var key = String(pluginId)
        _clearQueue(key)
        _setSessionOpen(key, false)
        if (internalActiveId === key)
            internalActiveId = ""
        _unloadObjects(key)
        var errorsNext = _copy(errors)
        errorsNext[key] = String(message || "unknown surface error")
        errors = errorsNext
        _setState(key, "error")
    }

    function _clearError(pluginId) {
        var errorsNext = _copy(errors)
        delete errorsNext[pluginId]
        errors = errorsNext
    }

    function _enqueue(pluginId, payloadJson) {
        var queuesNext = _copyQueues(queues)
        var queue = queuesNext[pluginId] || []
        queue.push(payloadJson)
        queuesNext[pluginId] = queue
        queues = queuesNext
    }

    function _clearQueue(pluginId) {
        var queuesNext = _copyQueues(queues)
        delete queuesNext[pluginId]
        queues = queuesNext
    }

    function _setSessionOpen(pluginId, open) {
        var sessionsNext = _copy(sessionOpen)
        if (open)
            sessionsNext[pluginId] = true
        else
            delete sessionsNext[pluginId]
        sessionOpen = sessionsNext
        internalRevision++
    }

    function _setPlacement(pluginId, outputId) {
        var placementsNext = _copy(placements)
        if (outputId === "")
            delete placementsNext[pluginId]
        else
            placementsNext[pluginId] = outputId
        placements = placementsNext
    }

    function _setState(pluginId, nextState) {
        var statesNext = _copy(states)
        if (nextState === "unloaded")
            delete statesNext[pluginId]
        else
            statesNext[pluginId] = nextState
        states = statesNext
        internalRevision++
    }

    function _currentFocusedOutputId() {
        if (compositor && String(compositor.focusedOutputId || "") !== "")
            return String(compositor.focusedOutputId)
        var outputSnapshots = _outputs()
        return outputSnapshots.length > 0 ? _outputId(outputSnapshots[0]) : ""
    }

    function _outputs() {
        if (!compositor || !compositor.outputs)
            return []
        var result = []
        for (var index = 0; index < compositor.outputs.length; index++)
            result.push(compositor.outputs[index])
        return result
    }

    function _outputId(output) {
        if (!output)
            return ""
        return String(output.id || output.name || "")
    }

    function _outputById(outputId) {
        var outputSnapshots = _outputs()
        for (var index = 0; index < outputSnapshots.length; index++) {
            if (_outputId(outputSnapshots[index]) === outputId)
                return outputSnapshots[index]
        }
        return null
    }

    function _objectCount() {
        var count = 0
        for (var pluginId in objects)
            count += objects[pluginId].length
        return count
    }

    function _copy(value) {
        var result = {}
        for (var key in value)
            result[key] = value[key]
        return result
    }

    function _copyQueues(value) {
        var result = {}
        for (var key in value)
            result[key] = value[key].slice()
        return result
    }
}
