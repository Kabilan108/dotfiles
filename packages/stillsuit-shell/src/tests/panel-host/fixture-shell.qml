import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "ui" as Ui
import "plugins/builtin/battery" as Battery
import "plugins/builtin/bar" as Bar
import "design_lab" as Lab
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root
    property int checks: 0
    property var testScreens: Quickshell.screens
    property var publicPanels: null
    property string pointerPhase: "loading"
    HostContext { id: contexts; surfaceRouter: testRouter; actionsSource: testActions }
    IpcFacade { id: testActions; surfaceRouter: testRouter }
    property var barPressAreas: []
    property var barContext: ({
        theme: root.theme,
        actions: contexts.actionsComponent.createObject(root),
        settings: {values: {shadowMode: false}},
        registerBarPressProbe: function(area, outputId) { root.barPressAreas.push(area) }
    })
    Component {
        id: barWidget
        Ui.ShellBarCluster {
            objectName: "fixture-switch"
            required property var context
            required property string outputId
            theme: context.theme
            label: "Switch"
            onClicked: context.actions.surfaceToggle("b", JSON.stringify({outputId: outputId}))
        }
    }
    Bar.Bar {
        id: fixtureBar
        context: root.barContext
        outputScreens: root.testScreens
        widgetRegistrations: [{component: barWidget, context: root.barContext,
            manifest: {id: "fixture.switch"}, defaultSection: "left"}]
    }
    property var theme: FixtureTheme.create()
    property var batteryContext: ({
        theme: root.theme,
        services: {get: function(id) { return null }},
        actions: {surfaceClose: function(id) {}}
    })
    Battery.Panel {
        id: batteryPanel
        context: root.batteryContext
        screen: Quickshell.screens[0]
        outputId: screen.name
        service: ({ available: true, present: true, percentage: 58,
            charging: true, low: false, pending: false, discharging: false,
            stateLabel: "Charging", timeText: "17h 20m" })
    }
    PanelWindow {
        id: testBar
        screen: Quickshell.screens[0]
        anchors { top: true; left: true; right: true }
        implicitHeight: 28
        exclusiveZone: 0
        visible: tooltip.hovering
        Item { id: tooltipTarget; width: 30; height: 28 }
        Ui.ShellBarTooltip {
            id: tooltip
            theme: root.theme
            target: tooltipTarget
            text: "Default accounts: Codex 42% remaining; Claude 76% remaining"
        }
    }
    function named(item, name) {
        if (item.objectName === name) return item
        var children = item.children || []
        for (var i = 0; i < children.length; i++) {
            var result = named(children[i], name)
            if (result) return result
        }
        return null
    }
    function pressBar(x) {
        var area = root.barPressAreas.length > 0 ? root.barPressAreas[0] : null
        verify(area !== null, "bar dismiss area registered through the fixture context")
        area.handlePress(x, 14)
        var cluster = named(area.parent, "fixture-switch")
        if (cluster === null) return
        var point = area.mapToItem(cluster, x, 14)
        if (point.x >= 0 && point.y >= 0
                && point.x < cluster.width && point.y < cluster.height) cluster.clicked()
    }
    Timer {
        id: layoutCheck
        interval: 700
        onTriggered: {
            try {
                var track = root.named(batteryPanel, "battery-charge-track")
                var summary = root.named(batteryPanel, "battery-state-summary")
                root.verify(track && track.width >= 180, "long battery summary preserves charge graphic")
                root.verify(summary && summary.width <= 112, "summary width is bounded")
                var percentage = root.named(batteryPanel, "battery-percentage")
                root.verify(percentage.role === "charging", "charging colors percentage as well as icon")
                batteryPanel.service = {available: true, low: true, charging: false, percentage: 10}
                root.verify(percentage.role === "danger", "low battery keeps danger precedence")
                root.verify(tooltip.popupWindow && tooltip.popupWindow.visible, "tooltip renders in separate popup")
                tooltip.hovering = false
                root.verify(!tooltip.showing, "hover exit dismisses tooltip")
                testBar.visible = false
                var host = testRouter.panelHosts[testCompositor.focusedOutputId]
                root.verify(host.height === host.screen.height,
                    "host uses the full output despite the production bar's exclusive zone")
                root.verify(batteryPanel.parent.y === root.theme.metrics.barHeight
                    + root.theme.metrics.barOuterGap + root.theme.metrics.spaceUnit,
                    "panel sits one theme space below the bar")
                host.dismiss(batteryPanel)
                testRouter.open("a", "")
                root.pointerPhase = "ready"
            } catch (error) {
                console.error("PANEL_HOST_FAIL", error, error.stack)
                Qt.exit(1)
            }
        }
    }
    QtObject {
        id: testCompositor
        property string focusedOutputId: Quickshell.screens[0].name
    }
    QtObject {
        id: testCatalog
        property bool loaded: true
        property var entries: ({ a: entry("a"), b: entry("b"), transient: entry("transient") })
        function entry(id) {
            return {manifest: {id: id, keepLoaded: id !== "transient", kinds: ["panel"], scope: {panel: "per-output"}, dependencies: []}}
        }
        function has(id) { return entries[id] !== undefined }
        function get(id) { return entries[id] }
        function isEnabled(id) { return has(id) }
        function hasKind(id, kind) { return has(id) && kind === "panel" }
        function primarySurfaceKind(id) { return has(id) ? "panel" : "" }
        function entryPointUrl(entry, kind) { return entry.manifest.id }
    }
    QtObject {
        id: delayedComponent
        property int status: Component.Loading
        function createObject(parent, properties) { return panelComponent.createObject(parent, properties) }
        function errorString() { return "test error" }
        function destroy() {}
    }
    Component {
        id: panelComponent
        Item {
            required property var context
            required property var screen
            required property string outputId
            readonly property bool hostedPanel: true
            property bool opened: false
            implicitWidth: 380
            implicitHeight: 200
            visible: false
            function open(payload) { opened = true }
            function close() { opened = false }
        }
    }
    SurfaceRouter {
        id: testRouter
        catalog: testCatalog
        compositor: testCompositor
        screens: root.testScreens
        componentFactory: function(url, mode) {
            return url === "b" ? delayedComponent : panelComponent
        }
    }
    Variants {
        model: root.testScreens
        PanelHost {
            required property var modelData
            screen: modelData
            outputId: modelData.name
            theme: root.theme
            router: testRouter
        }
    }
    function verify(value, message) {
        checks++
        if (!value) throw new Error(message)
    }
    IpcHandler {
        target: "panel-host-test"
        function phase(): string { return root.pointerPhase }
        function press(x: string): string {
            try {
                root.pressBar(Number(x))
                return "ok"
            } catch (error) {
                console.error("PANEL_HOST_FAIL", error, error.stack)
                Qt.exit(1)
                return "error"
            }
        }
        function checkPointer(step: string): string {
            try {
                var host = testRouter.panelHosts[testCompositor.focusedOutputId]
                if (step === "widget") {
                    root.verify(testRouter.isOpen("b") && host.visible,
                        "real widget click switches panels without background dismissal")
                } else {
                    root.verify(!host.visible && root.publicPanels.selectedId === ""
                        && testRouter.activeId === "" && testRouter.pendingCount("b") === 0,
                        "real bar background press clears the panel and pending routing")
                    console.log("PANEL_HOST_OK", root.checks)
                    Qt.callLater(Qt.quit)
                }
                return "ok"
            } catch (error) {
                console.error("PANEL_HOST_FAIL", error, error.stack)
                Qt.exit(1)
                return "error"
            }
        }
    }
    Timer {
        id: removalCheck
        interval: 100
        onTriggered: {
            try {
                var host = testRouter.panelHosts[testCompositor.focusedOutputId]
                root.verify(Object.keys(testRouter.panelHosts).length === 1, "removed output releases host")
                root.verify(host.visible && testRouter.placementOutputId("a") === testCompositor.focusedOutputId,
                    "open panel moves to surviving output")
                testRouter.dismissPanels()
                host.present(batteryPanel)
                tooltip.hovering = true
                layoutCheck.start()
            } catch (error) {
                console.error("PANEL_HOST_FAIL", error, error.stack)
                Qt.exit(1)
            }
        }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            try {
                verify(Object.keys(testRouter.panelHosts).length === 2, "one host per output")
                root.publicPanels = contexts.panelsFacadeComponent.createObject(root)
                var host = testRouter.panelHosts[testCompositor.focusedOutputId]
                verify(testRouter.open("a", "") === "ok", "open first panel")
                var first = host.panelContent
                verify(first && first.opened && host.visible, "first panel displayed")
                verify(testRouter.open("b", "") === "ok", "request delayed replacement")
                verify(host.panelContent === first && first.opened, "outgoing stays during compilation")
                verify(root.publicPanels.selectedId === "a", "selection follows displayed panel during replacement")
                testRouter.toggle("b", "")
                verify(testRouter.activeId === "a" && first.opened, "canceling replacement retains active outgoing panel")
                testRouter.open("b", "")
                delayedComponent.status = Component.Ready
                var second = host.panelContent
                verify(second !== first && second.opened && !first.opened, "atomic replacement")
                verify(root.publicPanels.selectedId === "b", "selection transfers when replacement is displayed")
                verify(!testRouter.isOpen("a") && testRouter.isOpen("b"), "single active panel")
                testRouter.toggle("a", "")
                verify(host.panelContent === first && first.opened, "one-click cached switch")
                testRouter.interruptForBanner(Quickshell.screens[1].name)
                verify(first.opened, "other-output toast does not dismiss")
                testRouter.interruptForBanner(testCompositor.focusedOutputId)
                verify(!host.visible && !first.opened, "same-output toast dismisses")
                testRouter.open("a", "")
                var otherId = Quickshell.screens[1].name
                var otherHost = testRouter.panelHosts[otherId]
                testRouter.toggle("a", JSON.stringify({outputId: otherId}))
                verify(!host.visible && otherHost.visible, "same plugin transfers outputs on one click")
                verify(testRouter.placementOutputId("a") === otherId, "clicked output owns placement")
                testRouter.toggle("a", JSON.stringify({outputId: testCompositor.focusedOutputId}))
                verify(host.visible && !otherHost.visible, "cross-output return closes previous host")
                testRouter.open("a", "")
                testRouter.dismissPanels()
                verify(!host.visible && testRouter.pendingCount("a") === 0, "outside dismissal clears routing")
                testRouter.open("b", "")
                testRouter.unload("b")
                verify(!host.visible, "unload removes host content")
                testRouter.open("transient", "")
                testRouter.close("transient")
                verify(testRouter.contributionState("transient", "panel") === "unloaded",
                    "hosted panel with keepLoaded false unloads on close")
                testRouter.open("a", JSON.stringify({outputId: otherId}))
                root.testScreens = [Quickshell.screens[0]]
                removalCheck.start()
            } catch (error) {
                console.error("PANEL_HOST_FAIL", error, error.stack)
                Qt.exit(1)
            }
        }
    }
}
