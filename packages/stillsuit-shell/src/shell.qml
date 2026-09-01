import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services" as Services

ShellRoot {
    id: shell

    readonly property string homeRoot: Quickshell.env("HOME")
    readonly property string xdgConfigRoot: _xdgRoot("XDG_CONFIG_HOME", ".config")
    readonly property string xdgDataRoot: _xdgRoot("XDG_DATA_HOME", ".local/share")
    readonly property string xdgStateRoot: _xdgRoot("XDG_STATE_HOME", ".local/state")
    readonly property string configId: Quickshell.env("STILLSUIT_CONFIG_ID") || "stillsuit"
    readonly property string processInstanceId: Quickshell.instanceId
    readonly property string catalogPath: Quickshell.env("STILLSUIT_CATALOG_PATH")
        || xdgConfigRoot + "/stillsuit/catalog.json"
    readonly property string themePath: Quickshell.env("STILLSUIT_THEME_PATH")
        || xdgConfigRoot + "/stillsuit/theme.json"
    readonly property bool shadowMode: Quickshell.env("STILLSUIT_SHADOW_MODE") === "1"
    readonly property bool ready: themeLoaded
        && themeError === ""
        && pluginCatalog.ready
        && serviceRegistry.ready
        && surfaceRouter.pendingLoadCount === 0

    property bool themeLoaded: false
    property string themeError: ""
    property var effectiveTheme: ({})

    FileView {
        id: themeFile
        path: shell.themePath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    Services.NiriService {
        id: niriService
    }

    HostContext {
        id: hostContext
        theme: shell.effectiveTheme
        compositor: niriService.adapter
        serviceRegistry: serviceRegistry
        surfaceRouter: surfaceRouter
        actionsSource: ipcFacade
        instanceId: shell.processInstanceId
        configRoot: shell.xdgConfigRoot + "/stillsuit"
        dataRoot: shell.xdgDataRoot + "/stillsuit"
        stateRoot: shell.xdgStateRoot + "/stillsuit"
    }

    Component {
        id: builtinFallbackBar
        // A headless shadow fixture has no PanelWindow backend. Production
        // never receives this marker: failure to construct the packaged bar
        // keeps readiness false, as required by the host contract.
        QtObject {
            required property var context
            readonly property bool emergencyFallback: true
        }
    }

    PluginCatalog {
        id: pluginCatalog
        catalogPath: shell.catalogPath
        allowLocalPlugins: Quickshell.env("STILLSUIT_ALLOW_LOCAL_PLUGINS") === "1"
        hostContext: hostContext
        serviceRegistry: serviceRegistry
        outputScreens: Quickshell.screens
        fallbackBarComponent: shell.shadowMode ? builtinFallbackBar : null
        fallbackContext: null
    }

    ServiceRegistry {
        id: serviceRegistry
        catalog: pluginCatalog
        hostContext: hostContext
    }

    SurfaceRouter {
        id: surfaceRouter
        catalog: pluginCatalog
        hostContext: hostContext
        serviceRegistry: serviceRegistry
        compositor: niriService.adapter
        screens: Quickshell.screens
    }

    IpcFacade {
        id: ipcFacade
        catalog: pluginCatalog
        serviceRegistry: serviceRegistry
        surfaceRouter: surfaceRouter
        theme: shell.effectiveTheme
        fallbackContext: pluginCatalog.fallbackContext
        configId: shell.configId
        instanceId: shell.processInstanceId
        ready: shell.ready
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
            "stillsuit.builtin-bar", Quickshell.shellDir,
            { shadowMode: shell.shadowMode })
        pluginCatalog.rescan()
    }

    function _xdgRoot(variable, fallbackSuffix) {
        return Quickshell.env(variable) || homeRoot + "/" + fallbackSuffix
    }

    function _loadTheme(text) {
        try {
            var parsed = JSON.parse(text)
            if (!parsed || parsed.schemaVersion !== 1
                    || !_isRecord(parsed.identity)
                    || !_isRecord(parsed.palette)
                    || !parsed.colors
                    || !parsed.controls
                    || !parsed.typography
                    || !parsed.geometry
                    || !parsed.motion)
                throw new Error("theme does not satisfy theme.v1")
            effectiveTheme = parsed
            themeError = ""
        } catch (error) {
            effectiveTheme = {}
            themeError = "theme is invalid: " + error
        }
        themeLoaded = true
    }

    function _isRecord(value) {
        return value !== null && typeof value === "object" && !Array.isArray(value)
    }
}
