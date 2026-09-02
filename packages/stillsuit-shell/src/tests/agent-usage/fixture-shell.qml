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
                id: "claude-work",
                provider: "claude",
                label: "work",
                plan: "Max 20x",
                identity: "",
                status: "refresh-required",
                statusText: "Open Claude Code to refresh sign-in",
                windows: []
            }
        ]
        property var summary: ({ accountCount: 2, readyCount: 1, maxUsed: 0.91 })

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

    Component.onCompleted: {
        if (visualMode) {
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
            verify(usage.accountCount === 2 && usage.readyCount === 1,
                "multi-account summary")
            verify(usage.statusRole(fakeModel.accounts[0]) === "success",
                "ready status role")
            verify(usage.statusRole(fakeModel.accounts[1]) === "warning",
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
