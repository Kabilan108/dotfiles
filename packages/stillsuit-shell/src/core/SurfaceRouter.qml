import QtQuick
import "ManifestValidator.js" as ManifestValidator

QtObject {
    id: root

    property QtObject catalog: null
    property QtObject hostContext: null
    property QtObject serviceRegistry: null
    property QtObject compositor: null
    property var screens: []
    property var componentFactory: function(url, mode) {
        return Qt.createComponent(url, mode)
    }

    readonly property string activeId: internalActiveId
    readonly property string focusedOutputId: _currentFocusedOutputId()
    readonly property int revision: internalRevision
    readonly property int objectCount: _objectCount()
    readonly property int pendingLoadCount: pendingLoads
    readonly property int screenCount: _screens().length

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

    onScreensChanged: Qt.callLater(root._reconcileScreens)

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
            root._containUnavailable()
            root._preloadAll()
            root._retryQueuedOpenRoutes()
        }
    }

    property Connections serviceConnections: Connections {
        target: root.serviceRegistry
        ignoreUnknownSignals: true

        function onRevisionChanged() {
            root._containUnavailable()
            root._preloadAll()
            root._retryQueuedOpenRoutes()
        }

        function onDependencyContained(pluginId) {
            root.unload(pluginId)
        }
    }

    function state(pluginId) {
        var kinds = _routedKindsForPlugin(String(pluginId))
        var hasLoaded = false
        for (var index = 0; index < kinds.length; index++) {
            var contribution = contributionState(pluginId, kinds[index])
            if (contribution === "error")
                return "error"
            if (contribution === "loading")
                return "loading"
            if (contribution === "loaded")
                hasLoaded = true
        }
        return hasLoaded ? "loaded" : "unloaded"
    }

    function contributionState(pluginId, kind) {
        return states[_routeKey(String(pluginId), String(kind))] || "unloaded"
    }

    function error(pluginId) {
        var kinds = _routedKindsForPlugin(String(pluginId))
        for (var index = 0; index < kinds.length; index++) {
            var message = contributionError(pluginId, kinds[index])
            if (message !== "")
                return message
        }
        return ""
    }

    function contributionError(pluginId, kind) {
        return errors[_routeKey(String(pluginId), String(kind))] || ""
    }

    function contributionInstances(pluginId, kind) {
        return objects[_routeKey(String(pluginId), String(kind))] || []
    }

    function isOpen(pluginId) {
        return sessionOpen[String(pluginId)] === true
    }

    function pendingCount(pluginId) {
        var queue = queues[String(pluginId)]
        return Array.isArray(queue) ? queue.length : 0
    }

    function pendingKinds(pluginId) {
        var queue = queues[String(pluginId)] || []
        var result = []
        for (var index = 0; index < queue.length; index++)
            result.push(queue[index].kind)
        return result
    }

    function placementOutputId(pluginId) {
        return placements[String(pluginId)] || ""
    }

    function open(pluginId, payloadJson) {
        var key = String(pluginId)
        var validation = _validateRequest(key, payloadJson, true)
        if (validation !== "ok")
            return validation
        var kind = catalog.primarySurfaceKind(key)
        if (contributionState(key, kind) === "error")
            return "error"

        if (internalActiveId !== "" && internalActiveId !== key)
            close(internalActiveId)
        _setSessionOpen(key, true)
        internalActiveId = key
        _setPlacement(key, _currentFocusedOutputId())

        if (contributionState(key, kind) === "loaded") {
            _applyPlacement(key)
            return _deliverOne(key, kind, String(payloadJson || "")) ? "ok" : "error"
        }

        _enqueue(key, kind, String(payloadJson || ""))
        var loadResult = _startLoadAll(key)
        if (loadResult === "started" || loadResult === "wait")
            return "ok"

        _clearQueue(key)
        _setSessionOpen(key, false)
        _setPlacement(key, "")
        if (internalActiveId === key)
            internalActiveId = ""
        return "error"
    }

    function close(pluginId) {
        var key = String(pluginId)
        if (!catalog || !catalog.has(key) || catalog.primarySurfaceKind(key) === "")
            return "unknown"

        _clearQueue(key)
        _setSessionOpen(key, false)
        _setPlacement(key, "")
        if (internalActiveId === key)
            internalActiveId = ""

        var primaryKind = catalog.primarySurfaceKind(key)
        var primaryState = contributionState(key, primaryKind)
        if (primaryState === "loaded" && !_invokeClose(key, primaryKind))
            return "error"
        if ((primaryState === "loaded" || primaryState === "loading")
                && catalog.get(key).manifest.keepLoaded !== true)
            _unloadObjects(key)
        return primaryState === "error" ? "error" : "ok"
    }

    function toggle(pluginId, payloadJson) {
        return isOpen(pluginId) ? close(pluginId) : open(pluginId, payloadJson)
    }

    function unload(pluginId) {
        var key = String(pluginId)
        _clearQueue(key)
        _setSessionOpen(key, false)
        _setPlacement(key, "")
        if (internalActiveId === key)
            internalActiveId = ""
        _unloadObjects(key)
        _clearErrors(key)
    }

    function unloadAll() {
        var ids = _loadedPluginIds()
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
            var kinds = _routedKindsForPlugin(pluginId)
            if (kinds.length === 0)
                continue
            var contributionRecords = {}
            for (var kindIndex = 0; kindIndex < kinds.length; kindIndex++) {
                var kind = kinds[kindIndex]
                contributionRecords[kind] = {
                    state: contributionState(pluginId, kind),
                    instances: contributionInstances(pluginId, kind).length,
                    error: contributionError(pluginId, kind)
                }
            }
            result[pluginId] = {
                state: state(pluginId),
                open: isOpen(pluginId),
                outputId: placementOutputId(pluginId),
                queuedPayloads: pendingCount(pluginId),
                queuedKinds: pendingKinds(pluginId),
                error: error(pluginId),
                contributions: contributionRecords
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
        return dependencyState === "ready" || dependencyState === "wait" ? "ok" : "error"
    }

    function _payloadValid(payloadJson) {
        var value = String(payloadJson || "")
        if (value === "")
            return true
        try {
            JSON.parse(value)
            return true
        } catch (error) {
            return false
        }
    }

    function _dependencyState(entry) {
        if (!entry || !catalog)
            return "error"
        var pluginId = String(entry.manifest.id)
        if (catalog.hasKind(pluginId, "service")) {
            var ownState = serviceRegistry ? serviceRegistry.state(pluginId) : "unloaded"
            if (ownState === "loading" || ownState === "unloaded")
                return "wait"
            if (ownState !== "loaded")
                return "error"
        }

        var dependencies = entry.manifest.dependencies || []
        for (var index = 0; index < dependencies.length; index++) {
            var dependencyId = dependencies[index]
            if (!catalog.isEnabled(dependencyId))
                return "disabled"
            if (!catalog.hasKind(dependencyId, "service"))
                continue
            var dependencyState = serviceRegistry
                ? serviceRegistry.state(dependencyId)
                : "unloaded"
            if (dependencyState === "loading" || dependencyState === "unloaded")
                return "wait"
            if (dependencyState !== "loaded")
                return "error"
        }
        return "ready"
    }

    function _startLoadAll(pluginId) {
        var entry = catalog ? catalog.get(pluginId) : null
        if (!entry)
            return "error"
        var dependencyState = _dependencyState(entry)
        if (dependencyState === "wait")
            return "wait"
        if (dependencyState !== "ready") {
            _failPlugin(pluginId, catalog.primarySurfaceKind(pluginId),
                "surface dependency is unavailable")
            return "error"
        }

        var kinds = _routedKinds(entry)
        for (var index = 0; index < kinds.length; index++) {
            var kind = kinds[index]
            var contribution = contributionState(pluginId, kind)
            if (contribution === "error")
                return "error"
            if (contribution === "unloaded"
                    && !_startContributionLoad(pluginId, kind, entry))
                return "error"
        }
        return "started"
    }

    function _startContributionLoad(pluginId, kind, entry) {
        var url = catalog.entryPointUrl(entry, kind)
        if (url === "") {
            _failPlugin(pluginId, kind, "invalid " + kind + " entry-point path")
            return false
        }

        var routeKey = _routeKey(pluginId, kind)
        var token = ++nextToken
        var tokensNext = _copy(tokens)
        tokensNext[routeKey] = token
        tokens = tokensNext
        _setContributionState(pluginId, kind, "loading")
        pendingLoads++
        var component = componentFactory(url, Component.Asynchronous)
        var componentsNext = _copy(components)
        componentsNext[routeKey] = component
        components = componentsNext

        function finalize() {
            if (tokens[routeKey] !== token)
                return
            if (component.status === Component.Loading)
                return
            var tokensDone = _copy(tokens)
            delete tokensDone[routeKey]
            tokens = tokensDone
            pendingLoads = Math.max(0, pendingLoads - 1)

            if (component.status !== Component.Ready) {
                _failPlugin(pluginId, kind, component.errorString())
                return
            }

            var instances = _createInstances(pluginId, component, entry, kind)
            if (instances === null) {
                _failPlugin(pluginId, kind, kind + " construction returned null")
                return
            }
            var objectsNext = _copy(objects)
            objectsNext[routeKey] = instances
            objects = objectsNext
            _clearContributionError(pluginId, kind)
            _setContributionState(pluginId, kind, "loaded")
            if (kind === catalog.primarySurfaceKind(pluginId)) {
                _applyPlacement(pluginId)
                _deliverQueue(pluginId)
            }
        }

        if (component.status === Component.Loading)
            component.statusChanged.connect(finalize)
        else
            finalize()
        return true
    }

    function _createInstances(pluginId, component, entry, kind) {
        var scopeKey = ManifestValidator.entryPointKey(kind)
        if (entry.manifest.scope[scopeKey] !== "per-output") {
            var globalInstance = component.createObject(surfaceHost,
                _constructionProperties(entry, null, false))
            return globalInstance ? [globalInstance] : null
        }

        var instances = []
        var currentScreens = _screens()
        for (var index = 0; index < currentScreens.length; index++) {
            var instance = component.createObject(surfaceHost,
                _constructionProperties(entry, currentScreens[index], true))
            if (!instance) {
                _destroyInstances(instances)
                return null
            }
            instances.push(instance)
        }
        return instances
    }

    function _constructionProperties(entry, screen, perOutput) {
        var properties = {
            context: hostContext ? hostContext.contextFor(entry) : null
        }
        var pluginId = String(entry.manifest.id)
        if (catalog.hasKind(pluginId, "service"))
            properties.service = serviceRegistry ? serviceRegistry.get(pluginId) : null
        if (perOutput) {
            properties.screen = screen
            properties.outputId = _outputId(screen)
        }
        return properties
    }

    function _deliverQueue(pluginId) {
        if (!isOpen(pluginId)) {
            _clearQueue(pluginId)
            return true
        }
        var queue = queues[pluginId]
        if (!Array.isArray(queue) || queue.length === 0)
            return true
        var primaryKind = catalog.primarySurfaceKind(pluginId)
        _clearQueue(pluginId)
        for (var index = 0; index < queue.length; index++) {
            if (queue[index].kind !== primaryKind)
                continue
            if (!_deliverOne(pluginId, primaryKind, queue[index].payload))
                return false
        }
        return true
    }

    function _deliverOne(pluginId, kind, payloadJson) {
        var instance = _placedInstance(pluginId, kind)
        if (!instance) {
            _failPlugin(pluginId, kind, "surface has no instance for the selected output")
            return false
        }
        try {
            if (typeof instance.open === "function")
                instance.open(payloadJson)
            else if ("visible" in instance)
                instance.visible = true
            return true
        } catch (error) {
            _failPlugin(pluginId, kind, "surface open failed: " + error)
            return false
        }
    }

    function _invokeClose(pluginId, kind) {
        var instances = contributionInstances(pluginId, kind)
        try {
            for (var index = 0; index < instances.length; index++) {
                if (typeof instances[index].close === "function")
                    instances[index].close()
                else if ("visible" in instances[index])
                    instances[index].visible = false
            }
            return true
        } catch (error) {
            _failPlugin(pluginId, kind, "surface close failed: " + error)
            return false
        }
    }

    function _applyPlacement(pluginId) {
        var kind = catalog.primarySurfaceKind(pluginId)
        var instance = _placedInstance(pluginId, kind)
        if (!instance)
            return
        var entry = catalog.get(pluginId)
        var scopeKey = ManifestValidator.entryPointKey(kind)
        if (entry.manifest.scope[scopeKey] === "per-output")
            return
        var screen = _screenById(placementOutputId(pluginId))
        if ("screen" in instance)
            instance.screen = screen
        if ("output" in instance)
            instance.output = screen
        if ("outputId" in instance)
            instance.outputId = placementOutputId(pluginId)
    }

    function _placedInstance(pluginId, kind) {
        var instances = contributionInstances(pluginId, kind)
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
        var order = typeof catalog.topologicalOrder === "function"
            ? catalog.topologicalOrder()
            : Object.keys(catalog.entries).sort()
        for (var index = 0; index < order.length; index++)
            _preloadIfNeeded(order[index])
    }

    function _preloadIfNeeded(pluginId) {
        if (!catalog || !catalog.has(pluginId) || !catalog.isEnabled(pluginId)
                || _routedKindsForPlugin(pluginId).length === 0)
            return
        var entry = catalog.get(pluginId)
        if (entry.manifest.keepLoaded !== true || state(pluginId) === "error")
            return
        if (_dependencyState(entry) !== "ready")
            return
        _startLoadAll(pluginId)
    }

    function _retryQueuedOpenRoutes() {
        if (!catalog || !catalog.loaded)
            return
        var order = typeof catalog.topologicalOrder === "function"
            ? catalog.topologicalOrder()
            : Object.keys(catalog.entries).sort()
        for (var index = 0; index < order.length; index++) {
            var pluginId = order[index]
            if (!isOpen(pluginId) || pendingCount(pluginId) === 0)
                continue
            if (!catalog.has(pluginId) || !catalog.isEnabled(pluginId)) {
                unload(pluginId)
                continue
            }
            var dependencyState = _dependencyState(catalog.get(pluginId))
            if (dependencyState === "wait")
                continue
            if (dependencyState !== "ready") {
                unload(pluginId)
                continue
            }
            _startLoadAll(pluginId)
        }
    }

    function _containUnavailable() {
        if (!catalog)
            return
        var ids = _loadedPluginIds()
        for (var index = 0; index < ids.length; index++) {
            var pluginId = ids[index]
            if (!catalog.has(pluginId) || !catalog.isEnabled(pluginId)
                    || _dependencyState(catalog.get(pluginId)) !== "ready")
                unload(pluginId)
        }
    }

    function _reconcileScreens() {
        if (!catalog)
            return
        var currentScreens = _screens()
        if (currentScreens.length === 0) {
            var openIds = Object.keys(sessionOpen).sort()
            for (var openIndex = 0; openIndex < openIds.length; openIndex++)
                close(openIds[openIndex])
        }
        var ids = _loadedPluginIds()
        for (var idIndex = 0; idIndex < ids.length; idIndex++) {
            var pluginId = ids[idIndex]
            var entry = catalog.get(pluginId)
            if (!entry)
                continue
            var primaryKind = catalog.primarySurfaceKind(pluginId)
            var primaryScopeKey = ManifestValidator.entryPointKey(primaryKind)
            var reopenOnReplacement = isOpen(pluginId)
                && entry.manifest.scope[primaryScopeKey] === "per-output"
                && _screenById(placementOutputId(pluginId)) === null
            if (reopenOnReplacement) {
                var replacementOutputId = _availableFocusedOutputId()
                if (replacementOutputId === "") {
                    close(pluginId)
                    reopenOnReplacement = false
                } else {
                    _setPlacement(pluginId, replacementOutputId)
                }
            }
            var kinds = _routedKinds(entry)
            for (var kindIndex = 0; kindIndex < kinds.length; kindIndex++) {
                var kind = kinds[kindIndex]
                var scopeKey = ManifestValidator.entryPointKey(kind)
                if (entry.manifest.scope[scopeKey] !== "per-output"
                        || contributionState(pluginId, kind) !== "loaded")
                    continue
                if (!_reconcileContributionScreens(pluginId, kind, entry))
                    return
            }
            if (reopenOnReplacement && isOpen(pluginId)
                    && contributionState(pluginId, primaryKind) === "loaded"
                    && !_deliverOne(pluginId, primaryKind, ""))
                return
        }
    }

    function _reconcileContributionScreens(pluginId, kind, entry) {
        var routeKey = _routeKey(pluginId, kind)
        var component = components[routeKey]
        if (!component)
            return true
        var existing = contributionInstances(pluginId, kind)
        var existingById = {}
        for (var index = 0; index < existing.length; index++)
            existingById[String(existing[index].outputId || "")] = existing[index]

        var nextInstances = []
        var created = []
        var currentScreens = _screens()
        for (var screenIndex = 0; screenIndex < currentScreens.length; screenIndex++) {
            var screen = currentScreens[screenIndex]
            var outputId = _outputId(screen)
            var instance = existingById[outputId]
            if (instance) {
                delete existingById[outputId]
            } else {
                instance = component.createObject(surfaceHost,
                    _constructionProperties(entry, screen, true))
                if (!instance) {
                    _destroyInstances(created)
                    _failPlugin(pluginId, kind, kind + " screen reconciliation failed")
                    return false
                }
                created.push(instance)
            }
            nextInstances.push(instance)
        }
        for (var removedId in existingById)
            existingById[removedId].destroy()
        var objectsNext = _copy(objects)
        objectsNext[routeKey] = nextInstances
        objects = objectsNext
        internalRevision++
        return true
    }

    function _unloadObjects(pluginId) {
        var prefix = String(pluginId) + ":"
        var keys = _contributionKeys(prefix)
        for (var index = 0; index < keys.length; index++)
            _unloadContributionKey(keys[index])
    }

    function _unloadContributionKey(routeKey) {
        var tokenNext = _copy(tokens)
        if (tokenNext[routeKey] !== undefined) {
            delete tokenNext[routeKey]
            tokens = tokenNext
            if (states[routeKey] === "loading")
                pendingLoads = Math.max(0, pendingLoads - 1)
        }
        _destroyInstances(objects[routeKey] || [])
        var component = components[routeKey]
        if (component && typeof component.destroy === "function")
            component.destroy()

        var objectsNext = _copy(objects)
        delete objectsNext[routeKey]
        objects = objectsNext
        var componentsNext = _copy(components)
        delete componentsNext[routeKey]
        components = componentsNext
        var statesNext = _copy(states)
        delete statesNext[routeKey]
        states = statesNext
        internalRevision++
    }

    function _failPlugin(pluginId, kind, message) {
        var key = String(pluginId)
        _clearQueue(key)
        _setSessionOpen(key, false)
        _setPlacement(key, "")
        if (internalActiveId === key)
            internalActiveId = ""
        _unloadObjects(key)
        var errorsNext = _copy(errors)
        errorsNext[_routeKey(key, kind)] = String(message || "unknown surface error")
        errors = errorsNext
        _setContributionState(key, kind, "error")
    }

    function _clearContributionError(pluginId, kind) {
        var errorsNext = _copy(errors)
        delete errorsNext[_routeKey(pluginId, kind)]
        errors = errorsNext
    }

    function _clearErrors(pluginId) {
        var prefix = String(pluginId) + ":"
        var errorsNext = {}
        for (var key in errors) {
            if (key.indexOf(prefix) !== 0)
                errorsNext[key] = errors[key]
        }
        errors = errorsNext
    }

    function _enqueue(pluginId, kind, payloadJson) {
        var queuesNext = _copyQueues(queues)
        var queue = queuesNext[pluginId] || []
        queue.push({ kind: kind, payload: payloadJson })
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

    function _setContributionState(pluginId, kind, nextState) {
        var statesNext = _copy(states)
        var routeKey = _routeKey(pluginId, kind)
        if (nextState === "unloaded")
            delete statesNext[routeKey]
        else
            statesNext[routeKey] = nextState
        states = statesNext
        internalRevision++
    }

    function _currentFocusedOutputId() {
        return _availableFocusedOutputId()
    }

    function _availableFocusedOutputId() {
        var focusedOutputId = compositor
            ? String(compositor.focusedOutputId || "")
            : ""
        if (focusedOutputId !== "" && _screenById(focusedOutputId) !== null)
            return focusedOutputId
        var currentScreens = _screens()
        return currentScreens.length > 0 ? _outputId(currentScreens[0]) : ""
    }

    function _screens() {
        var result = []
        if (!screens)
            return result
        for (var index = 0; index < screens.length; index++)
            result.push(screens[index])
        return result
    }

    function _outputId(screen) {
        if (!screen)
            return ""
        return String(screen.name || screen.id || "")
    }

    function _screenById(outputId) {
        var currentScreens = _screens()
        for (var index = 0; index < currentScreens.length; index++) {
            if (_outputId(currentScreens[index]) === outputId)
                return currentScreens[index]
        }
        return null
    }

    function _routedKindsForPlugin(pluginId) {
        return catalog && catalog.has(pluginId) ? _routedKinds(catalog.get(pluginId)) : []
    }

    function _routedKinds(entry) {
        var result = []
        if (!entry || !entry.manifest)
            return result
        var order = ["panel", "overlay", "menu"]
        for (var index = 0; index < order.length; index++) {
            if (entry.manifest.kinds.indexOf(order[index]) !== -1)
                result.push(order[index])
        }
        return result
    }

    function _routeKey(pluginId, kind) {
        return String(pluginId) + ":" + String(kind)
    }

    function _contributionKeys(prefix) {
        var found = {}
        var sources = [states, errors, objects, components, tokens]
        for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
            for (var key in sources[sourceIndex]) {
                if (key.indexOf(prefix) === 0)
                    found[key] = true
            }
        }
        return Object.keys(found)
    }

    function _loadedPluginIds() {
        var found = {}
        var keys = _contributionKeys("")
        for (var index = 0; index < keys.length; index++) {
            var separator = keys[index].lastIndexOf(":")
            if (separator !== -1)
                found[keys[index].substring(0, separator)] = true
        }
        return Object.keys(found).sort()
    }

    function _objectCount() {
        var count = 0
        for (var routeKey in objects)
            count += objects[routeKey].length
        return count
    }

    function _destroyInstances(instances) {
        for (var index = 0; index < instances.length; index++) {
            if (instances[index] && typeof instances[index].destroy === "function")
                instances[index].destroy()
        }
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
