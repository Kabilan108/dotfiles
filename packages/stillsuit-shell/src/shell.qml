import QtQuick
import Quickshell
import Quickshell.Io
import "core"

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

    QtObject {
        id: compositorSnapshot
        readonly property string apiVersion: "1"
        readonly property string name: "niri"
        property int revision: 0
        property var outputs: []
        property string focusedOutputId: ""
        property var workspaces: []
        property var windows: []
    }

    HostContext {
        id: hostContext
        theme: shell.effectiveTheme
        compositor: compositorSnapshot
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
        QtObject {
            required property var context
            readonly property bool builtinFallback: true
        }
    }

    PluginCatalog {
        id: pluginCatalog
        catalogPath: shell.catalogPath
        allowLocalPlugins: Quickshell.env("STILLSUIT_ALLOW_LOCAL_PLUGINS") === "1"
        hostContext: hostContext
        fallbackBarComponent: builtinFallbackBar
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
        compositor: compositorSnapshot
    }

    IpcFacade {
        id: ipcFacade
        catalog: pluginCatalog
        serviceRegistry: serviceRegistry
        surfaceRouter: surfaceRouter
        theme: shell.effectiveTheme
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
            "stillsuit.builtin-bar", Quickshell.shellDir)
        pluginCatalog.rescan()
    }

    function _xdgRoot(variable, fallbackSuffix) {
        return Quickshell.env(variable) || homeRoot + "/" + fallbackSuffix
    }

    function _loadTheme(text) {
        try {
            var parsed = JSON.parse(text)
            if (!parsed || parsed.schemaVersion !== 1
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
}
