pragma ComponentBehavior: Bound

import QtQuick

QtObject {
    id: root

    property var theme: ({})
    property QtObject compositor: null
    property QtObject serviceRegistry: null
    property QtObject surfaceRouter: null
    property QtObject actionsSource: null
    property string instanceId: ""
    property string configRoot: ""
    property string dataRoot: ""
    property string stateRoot: ""
    property var contextCache: ({})

    property Component contextOwnerComponent: Component {
        QtObject {
            id: contextOwner

            required property var _theme
            required property QtObject _compositor
            required property QtObject _services
            required property QtObject _panels
            required property QtObject _logger
            required property QtObject _settings
            required property QtObject _actions
            required property string _instanceId

            readonly property QtObject context: QtObject {
                readonly property var theme: contextOwner._theme
                readonly property QtObject compositor: contextOwner._compositor
                readonly property QtObject services: contextOwner._services
                readonly property QtObject panels: contextOwner._panels
                readonly property QtObject logger: contextOwner._logger
                readonly property QtObject settings: contextOwner._settings
                readonly property QtObject actions: contextOwner._actions
                readonly property string instanceId: contextOwner._instanceId
            }
        }
    }

    property Component servicesOwnerComponent: Component {
        QtObject {
            id: servicesOwner

            required property string pluginId
            required property var dependencies
            readonly property QtObject facade: QtObject {
                readonly property int revision: root.serviceRegistry
                    ? root.serviceRegistry.revision
                    : 0

                function has(serviceId) {
                    var key = String(serviceId)
                    return servicesOwner.dependencies.indexOf(key) !== -1
                        && root.serviceRegistry
                        && root.serviceRegistry.has(key)
                }

                function get(serviceId) {
                    var key = String(serviceId)
                    if (servicesOwner.dependencies.indexOf(key) === -1
                            || !root.serviceRegistry)
                        return null
                    return root.serviceRegistry.get(key)
                }

                function state(serviceId) {
                    var key = String(serviceId)
                    if (servicesOwner.dependencies.indexOf(key) === -1
                            || !root.serviceRegistry)
                        return "unloaded"
                    return root.serviceRegistry.state(key)
                }
            }
        }
    }

    property Component panelsFacadeComponent: Component {
        QtObject {
            readonly property string activeId: root.surfaceRouter ? root.surfaceRouter.activeId : ""
            readonly property string focusedOutputId: root.surfaceRouter
                ? root.surfaceRouter.focusedOutputId
                : ""

            function isOpen(pluginId) {
                return root.surfaceRouter ? root.surfaceRouter.isOpen(String(pluginId)) : false
            }

            function state(pluginId) {
                return root.surfaceRouter
                    ? root.surfaceRouter.state(String(pluginId))
                    : "unloaded"
            }
        }
    }

    property Component loggerOwnerComponent: Component {
        QtObject {
            id: loggerOwner

            required property string pluginId
            readonly property QtObject facade: QtObject {
                function debug(message) {
                    console.debug(loggerOwner.prefix() + String(message))
                }

                function info(message) {
                    console.info(loggerOwner.prefix() + String(message))
                }

                function warn(message) {
                    console.warn(loggerOwner.prefix() + String(message))
                }

                function error(message) {
                    console.error(loggerOwner.prefix() + String(message))
                }
            }

            function prefix() {
                return "[" + pluginId + " " + root.instanceId + "] "
            }
        }
    }

    property Component settingsOwnerComponent: Component {
        QtObject {
            id: settingsOwner

            required property string pluginId
            required property var values
            required property var paths
            readonly property QtObject facade: QtObject {
                readonly property string pluginId: settingsOwner.pluginId
                readonly property var values: settingsOwner.values
                readonly property var paths: settingsOwner.paths
            }
        }
    }

    property Component actionsComponent: Component {
        QtObject {
            function surfaceOpen(pluginId, payloadJson) {
                return root.actionsSource
                    ? root.actionsSource.surfaceOpen(String(pluginId), String(payloadJson))
                    : "error"
            }

            function surfaceClose(pluginId) {
                return root.actionsSource
                    ? root.actionsSource.surfaceClose(String(pluginId))
                    : "error"
            }

            function surfaceToggle(pluginId, payloadJson) {
                return root.actionsSource
                    ? root.actionsSource.surfaceToggle(String(pluginId), String(payloadJson))
                    : "error"
            }

            function pluginUnload(pluginId) {
                return root.actionsSource
                    ? root.actionsSource.pluginUnload(String(pluginId))
                    : "error"
            }

            function pluginReload(pluginId) {
                return root.actionsSource
                    ? root.actionsSource.pluginReload(String(pluginId))
                    : "error"
            }

            function pluginRescan() {
                return root.actionsSource ? root.actionsSource.pluginRescan() : "error"
            }

            function shellPing() {
                return root.actionsSource ? root.actionsSource.shellPing() : "not-ready"
            }

            function shellStatus() {
                return root.actionsSource ? root.actionsSource.shellStatus() : "{}"
            }

            function themeQuery() {
                return root.actionsSource ? root.actionsSource.themeQuery() : "{}"
            }

            function agentPanelOpen() {
                return root.actionsSource ? root.actionsSource.agentPanelOpen() : "unavailable"
            }

            function agentPanelHide() {
                return root.actionsSource ? root.actionsSource.agentPanelHide() : "unavailable"
            }

            function agentPanelToggle() {
                return root.actionsSource ? root.actionsSource.agentPanelToggle() : "unavailable"
            }

            function agentPanelStatus() {
                return root.actionsSource ? root.actionsSource.agentPanelStatus() : "unavailable"
            }

            function agentPanelTerminate() {
                return root.actionsSource ? root.actionsSource.agentPanelTerminate() : "unavailable"
            }
        }
    }

    function contextFor(entry) {
        if (!entry || !entry.manifest)
            return null
        var pluginId = String(entry.manifest.id)
        var cached = contextCache[pluginId]
        if (cached && cached.signature === entry.signature)
            return cached.context
        if (cached)
            dropContext(pluginId)

        var dependencies = entry.manifest.dependencies || []
        var servicesOwner = servicesOwnerComponent.createObject(root, {
            pluginId: pluginId,
            dependencies: dependencies.slice()
        })
        var services = servicesOwner.facade
        var panels = panelsFacadeComponent.createObject(root)
        var loggerOwner = loggerOwnerComponent.createObject(root, { pluginId: pluginId })
        var logger = loggerOwner.facade
        var settingsOwner = settingsOwnerComponent.createObject(root, {
            pluginId: pluginId,
            values: _clone(entry.settings || {}),
            paths: {
                configRoot: configRoot,
                dataRoot: dataRoot,
                stateRoot: stateRoot,
                packageRoot: entry.packageRoot
            }
        })
        var settings = settingsOwner.facade
        var actions = actionsComponent.createObject(root)
        var contextOwner = contextOwnerComponent.createObject(root, {
            _theme: _clone(theme || {}),
            _compositor: compositor,
            _services: services,
            _panels: panels,
            _logger: logger,
            _settings: settings,
            _actions: actions,
            _instanceId: instanceId
        })
        var context = contextOwner.context

        var cacheNext = _copy(contextCache)
        cacheNext[pluginId] = {
            signature: entry.signature,
            owner: contextOwner,
            context: context,
            owned: [servicesOwner, panels, loggerOwner, settingsOwner, actions]
        }
        contextCache = cacheNext
        return context
    }

    function contextForBuiltin(pluginId, packageRoot, values) {
        var builtinValues = { shadowMode: false }
        var suppliedValues = values || {}
        for (var key in suppliedValues)
            builtinValues[key] = suppliedValues[key]
        return contextFor({
            packageRoot: packageRoot || "",
            settings: builtinValues,
            signature: "builtin:" + String(pluginId) + ":" + JSON.stringify(builtinValues),
            manifest: {
                id: String(pluginId),
                dependencies: []
            }
        })
    }

    function dropContext(pluginId) {
        var key = String(pluginId)
        var cached = contextCache[key]
        if (cached) {
            if (cached.owner && typeof cached.owner.destroy === "function")
                cached.owner.destroy()
            var owned = cached.owned || []
            for (var index = 0; index < owned.length; index++) {
                if (owned[index] && typeof owned[index].destroy === "function")
                    owned[index].destroy()
            }
        }
        var cacheNext = _copy(contextCache)
        delete cacheNext[key]
        contextCache = cacheNext
    }

    function _clone(value) {
        return JSON.parse(JSON.stringify(value))
    }

    function _copy(value) {
        var result = {}
        for (var key in value)
            result[key] = value[key]
        return result
    }
}
