import QtQuick
import Quickshell
import "plugins/builtin/agent-usage" as AgentUsage
import "tests/FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root

    readonly property bool visualMode:
        Quickshell.env("STILLSUIT_AGENT_USAGE_VISUAL") === "1"
    property int checks: 0
    property int refreshes: 0
    property var fakeContext: QtObject {
        property var theme: FixtureTheme.create()
        property var settings: QtObject {
            property var values: ({ helperPath: "" })
        }
        property var panels: QtObject {
            function isOpen(pluginId) { return false }
        }
        property var actions: QtObject {
            function surfaceToggle(pluginId, payloadJson) { return "ok" }
            function surfaceClose(pluginId) { return "ok" }
        }
    }
    property var fakeModel: QtObject {
        property int revision: 1
        property string updatedAt: "2030-01-01T00:00:00+00:00"
        property var accounts: [
            {
                id: "codex-default",
                provider: "codex",
                source: "default",
                label: "Default",
                plan: "Pro",
                identity: "fixture@example.com",
                status: "ready",
                statusText: "",
                windows: [
                    { id: "primary", label: "5 hour", used: 0.42,
                        resetsAt: "2030-01-01T05:00:00+00:00" },
                    { id: "secondary", label: "Weekly", used: 0.91,
                        resetsAt: "2030-01-08T00:00:00+00:00" }
                ]
            },
            {
                id: "codex-rani",
                provider: "codex",
                source: "shadow",
                label: "rani",
                plan: "Free",
                identity: "shadow@example.com",
                status: "ready",
                statusText: "",
                windows: [
                    { id: "primary", label: "720 hour", used: 0.99,
                        resetsAt: "2030-02-01T00:00:00+00:00" }
                ]
            },
            {
                id: "claude-work",
                provider: "claude",
                source: "default",
                label: "work",
                plan: "Max 20x",
                identity: "",
                status: "refresh-required",
                statusText: "Open Claude Code to refresh sign-in",
                windows: []
            }
        ]
        property var summary: ({ accountCount: 3, readyCount: 2, maxUsed: 0.99 })

        function refresh(force) {
            root.refreshes++
        }
    }

    AgentUsage.Service {
        id: usage
        context: root.fakeContext
        model: root.fakeModel
    }

    function verify(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
    }

    Loader {
        id: visualPanel
    }

    Loader {
        id: visualBar
    }

    Component.onCompleted: {
        if (visualMode) {
            visualBar.setSource("tests/agent-usage/visual-bar.qml", {
                context: fakeContext,
                service: usage,
                screen: Quickshell.screens[0]
            })
            visualPanel.setSource("plugins/builtin/agent-usage/Panel.qml", {
                context: fakeContext,
                service: usage,
                screen: Quickshell.screens[0],
                outputId: "fixture-output"
            })
            Qt.callLater(function() {
                if (visualPanel.item)
                    visualPanel.item.open("")
            })
        } else {
            Qt.callLater(run)
        }
    }

    function run() {
        try {
            var widgetComponent = Qt.createComponent(
                "plugins/builtin/agent-usage/Widget.qml",
                Component.PreferSynchronous)
            verify(widgetComponent.status === Component.Ready,
                "widget: " + widgetComponent.errorString())
            var widget = widgetComponent.createObject(root, {
                context: fakeContext,
                service: usage,
                outputId: "fixture-output"
            })
            verify(widget !== null, "widget construction")
            verify(widget.usedPercent === 91, "bar summary")
            verify(widget.remainingPercent === 9, "bar remaining summary")
            verify(String(widget.iconSource).endsWith("/assets/codex.svg"),
                "bar Codex mark")
            verify(String(widget.secondaryIconSource) === "",
                "signed-out default Claude hidden from bar")
            verify(widget.hasCodex && !widget.hasClaude,
                "only reporting default providers shown")
            usage.refreshing = true
            verify(!widget.busy, "refresh keeps bar value visible")
            usage.refreshing = false
            verify(usage.accountCount === 3 && usage.readyCount === 2,
                "multi-account summary")
            verify(usage.statusRole(fakeModel.accounts[0]) === "success",
                "ready status role")
            verify(usage.statusRole(fakeModel.accounts[2]) === "warning",
                "expired status role")
            verify(usage.refresh(true) === "ok" && refreshes === 1,
                "refresh delegation")
            console.log("AGENT_USAGE_FIXTURE_OK", checks)
            Qt.quit()
        } catch (error) {
            console.error("AGENT_USAGE_FIXTURE_FAIL", error)
            Qt.exit(1)
        }
    }
}
