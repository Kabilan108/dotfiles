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
        function contextFor(entry) { return ({theme: root.theme}) }
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
        fallbackContext: contexts
        fallbackBarComponent: fallback
    }
    IpcHandler {
        target: "runtime-plugin-test"
        function unload(): string { return catalog.unload("stillsuit.example") }
        function reload(): string { return catalog.reload("stillsuit.example") }
        function rescan(): string { return catalog.rescan() || "ok" }
        function inspect(): string {
            var entry = catalog.get("stillsuit.example")
            var result = {ready: catalog.ready, exists: !!entry,
                enabled: catalog.isEnabled("stillsuit.example")}
            result.rendered = []
            if (root.renderedBar) {
                for (var index = 0; index < root.renderedBar.slots.count; index++) {
                    var slot = root.renderedBar.slots.itemAt(index)
                    if (slot && slot.createdWidget) result.rendered.push(slot.createdWidget.label)
                }
            }
            if (entry && result.enabled) {
                var component = catalog.widgetComponents["stillsuit.example"]
                if (component && component.status === Component.Ready) {
                    var widget = component.createObject(root, {
                        context: {theme: root.theme}, outputId: "fixture"
                    })
                    if (widget) { result.label = widget.label; widget.destroy() }
                }
            }
            return JSON.stringify(result)
        }
    }
}
