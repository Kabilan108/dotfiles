import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "plugins/builtin/bar" as Bar
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root
    property var theme: FixtureTheme.create()
    property var renderedBar: null
    QtObject {
        id: contexts
        function contextFor(entry) {
            return ({
                theme: root.theme,
                settings: entry && entry.settings ? entry.settings : ({})
            })
        }
        function dropContext(pluginId) {}
    }
    Component {
        id: fallback
        Item {
            id: bar
            required property var context
            property var widgetRegistrations: []
            property var outputScreens: []
            Component.onCompleted: root.renderedBar = bar
            property alias slots: slots
            Repeater {
                id: slots
                model: bar.widgetRegistrations
                Bar.WidgetSlot {
                    required property var modelData
                    registration: modelData
                    outputId: "fixture"
                }
            }
        }
    }
    PluginCatalog {
        id: catalog
        allowLocalPlugins: true
        hostContext: contexts
        serviceRegistry: services
        fallbackContext: contexts
        fallbackBarComponent: fallback
    }
    ServiceRegistry {
        id: services
        catalog: catalog
        hostContext: contexts
    }
    IpcHandler {
        target: "runtime-plugin-test"
        function unload(): string { return catalog.unload("stillsuit.example") }
        function unloadBar(): string { return catalog.unload("stillsuit.test-bar") }
        function reload(): string { return catalog.reload("stillsuit.example") }
        function rescan(): string { return catalog.rescan() || "ok" }
        function inspect(): string {
            var entry = catalog.get("stillsuit.example")
            var barEntry = catalog.get("stillsuit.test-bar")
            var result = {ready: catalog.ready, exists: !!entry,
                enabled: catalog.isEnabled("stillsuit.example"),
                activeProfile: catalog.activeProfile,
                profileRevision: catalog.profileRevision,
                runtimeDisabled: catalog.runtimeDisabled["stillsuit.example"] === true,
                barRuntimeDisabled: catalog.runtimeDisabled["stillsuit.test-bar"] === true,
                activeBarId: catalog.activeBarId,
                fallbackActive: catalog.fallbackActive,
                barSettings: barEntry ? barEntry.settings : ({}),
                settings: entry ? entry.settings : ({}),
                serviceCount: services.objectCount,
                workServiceState: services.state("stillsuit.work-only")}
            result.rendered = []
            var activeBar = catalog.barInstance
            if (activeBar && activeBar.slots) {
                for (var index = 0; index < activeBar.slots.count; index++) {
                    var slot = activeBar.slots.itemAt(index)
                    if (slot && slot.createdWidget) result.rendered.push(slot.createdWidget.label)
                }
            }
            var workService = services.get("stillsuit.work-only")
            result.workServiceLabel = workService ? workService.label : ""
            if (entry && result.enabled) {
                var component = catalog.widgetComponents["stillsuit.example"]
                if (component && component.status === Component.Ready) {
                    var widget = component.createObject(root, {
                        context: {theme: root.theme, settings: entry.settings},
                        outputId: "fixture"
                    })
                    if (widget) { result.label = widget.label; widget.destroy() }
                }
            }
            return JSON.stringify(result)
        }
    }
}
