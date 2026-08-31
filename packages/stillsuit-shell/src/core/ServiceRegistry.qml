import QtQuick

QtObject {
    id: root

    property QtObject catalog: null
    property QtObject hostContext: null
    readonly property int revision: internalRevision
    readonly property bool ready: catalog !== null && catalog.loaded && pendingLoads === 0
    readonly property int objectCount: Object.keys(objects).length

    property int internalRevision: 0
    property int pendingLoads: 0
    property int nextToken: 0
    property var objects: ({})
    property var components: ({})
    property var states: ({})
    property var errors: ({})
    property var tokens: ({})
    property QtObject serviceHost: QtObject {}

    property Connections catalogConnections: Connections {
        target: root.catalog
        ignoreUnknownSignals: true

        function onEntryAdded(pluginId) {
            root._loadEligibleServices()
        }

        function onEntryChanged(pluginId) {
            root.unload(pluginId)
            root._clearError(pluginId)
            root._loadEligibleServices()
        }

        function onEntryRemoved(pluginId) {
            root.unload(pluginId)
            if (root.hostContext)
                root.hostContext.dropContext(pluginId)
        }

        function onPluginUnloaded(pluginId) {
            root.unload(pluginId)
            if (root.hostContext)
                root.hostContext.dropContext(pluginId)
            root._loadEligibleServices()
        }

        function onPluginReloaded(pluginId) {
            root.unload(pluginId)
            root._clearError(pluginId)
            if (root.hostContext)
                root.hostContext.dropContext(pluginId)
            root._loadEligibleServices()
        }

        function onCatalogChanged() {
            root._loadEligibleServices()
        }
    }

    function has(pluginId) {
        return objects[String(pluginId)] !== undefined
    }

    function get(pluginId) {
        return objects[String(pluginId)] || null
    }

    function state(pluginId) {
        return states[String(pluginId)] || "unloaded"
    }

    function error(pluginId) {
        return errors[String(pluginId)] || ""
    }

    function unload(pluginId) {
        var key = String(pluginId)
        var tokenNext = _copy(tokens)
        if (tokenNext[key] !== undefined) {
            delete tokenNext[key]
            tokens = tokenNext
            if (states[key] === "loading")
                pendingLoads = Math.max(0, pendingLoads - 1)
        }

        var instance = objects[key]
        if (instance && typeof instance.destroy === "function")
            instance.destroy()
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

    function unloadAll() {
        var ids = Object.keys(states)
        for (var index = 0; index < ids.length; index++)
            unload(ids[index])
    }

    function statusRecords() {
        var result = {}
        var ids = catalog ? Object.keys(catalog.entries).sort() : []
        for (var index = 0; index < ids.length; index++) {
            var pluginId = ids[index]
            if (!catalog.hasKind(pluginId, "service"))
                continue
            result[pluginId] = {
                state: state(pluginId),
                error: error(pluginId)
            }
        }
        return result
    }

    function _loadEligibleServices() {
        if (!catalog || !catalog.loaded)
            return
        var order = catalog.topologicalOrder()
        var progress = true
        while (progress) {
            progress = false
            for (var index = 0; index < order.length; index++) {
                var pluginId = order[index]
                if (!catalog.hasKind(pluginId, "service")
                        || !catalog.isEnabled(pluginId)
                        || state(pluginId) !== "unloaded")
                    continue

                var dependencyState = _dependencyState(catalog.get(pluginId))
                if (dependencyState === "wait")
                    continue
                if (dependencyState !== "ready") {
                    _setError(pluginId, dependencyState)
                    progress = true
                    continue
                }
                _startLoad(pluginId)
                progress = true
            }
        }
    }

    function _dependencyState(entry) {
        var dependencies = entry.manifest.dependencies || []
        for (var index = 0; index < dependencies.length; index++) {
            var dependencyId = dependencies[index]
            if (!catalog.isEnabled(dependencyId))
                return "dependency is disabled: " + dependencyId
            if (!catalog.hasKind(dependencyId, "service"))
                continue
            var dependencyServiceState = state(dependencyId)
            if (dependencyServiceState === "loading" || dependencyServiceState === "unloaded")
                return "wait"
            if (dependencyServiceState !== "loaded")
                return "dependency service failed: " + dependencyId
        }
        return "ready"
    }

    function _startLoad(pluginId) {
        var entry = catalog.get(pluginId)
        var url = catalog.entryPointUrl(entry, "service")
        if (url === "") {
            _setError(pluginId, "invalid service entry-point path")
            return
        }

        var token = ++nextToken
        var tokensNext = _copy(tokens)
        tokensNext[pluginId] = token
        tokens = tokensNext
        _setState(pluginId, "loading")
        pendingLoads++
        var component = Qt.createComponent(url, Component.Asynchronous)

        function finalize() {
            if (tokens[pluginId] !== token) {
                if (component.status !== Component.Loading)
                    component.destroy()
                return
            }
            if (component.status === Component.Loading)
                return
            var tokensDone = _copy(tokens)
            delete tokensDone[pluginId]
            tokens = tokensDone
            pendingLoads = Math.max(0, pendingLoads - 1)

            if (component.status !== Component.Ready) {
                _setError(pluginId, component.errorString())
                component.destroy()
                _loadEligibleServices()
                return
            }

            var context = hostContext ? hostContext.contextFor(entry) : null
            var instance = component.createObject(serviceHost, { context: context })
            if (!instance) {
                _setError(pluginId, "service construction returned null")
                component.destroy()
                _loadEligibleServices()
                return
            }

            var objectsNext = _copy(objects)
            objectsNext[pluginId] = instance
            objects = objectsNext
            var componentsNext = _copy(components)
            componentsNext[pluginId] = component
            components = componentsNext
            _clearError(pluginId)
            _setState(pluginId, "loaded")
            _loadEligibleServices()
        }

        if (component.status === Component.Loading)
            component.statusChanged.connect(finalize)
        else
            finalize()
    }

    function _setError(pluginId, message) {
        var errorsNext = _copy(errors)
        errorsNext[pluginId] = String(message || "unknown service error")
        errors = errorsNext
        _setState(pluginId, "error")
    }

    function _clearError(pluginId) {
        var errorsNext = _copy(errors)
        delete errorsNext[pluginId]
        errors = errorsNext
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

    function _copy(value) {
        var result = {}
        for (var key in value)
            result[key] = value[key]
        return result
    }
}
