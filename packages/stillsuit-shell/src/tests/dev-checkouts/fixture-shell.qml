import QtQuick
import Quickshell
import Quickshell.Io
import "plugins/dev-checkouts" as DevCheckouts
import "FixtureTheme.js" as FixtureTheme

ShellRoot {
    id: root

    property int checks: 0
    readonly property string fixtureRoot: Quickshell.env("DEV_CHECKOUTS_FIXTURE_ROOT")
    property var fakeContext: QtObject {
        property var theme: FixtureTheme.create()
        property var settings: QtObject {
            property var values: ({
                helperPath: root.fixtureRoot + "/helper.sh",
                openHelperPath: root.fixtureRoot + "/open.sh",
                refreshIntervalSec: 3600
            })
        }
        property var panels: QtObject {
            property string selectedId: ""
            property string selectedOutputId: ""
        }
        property var actions: QtObject {
            function surfaceToggle(pluginId, payloadJson) { return "ok" }
            function surfaceClose(pluginId) { return "ok" }
        }
    }

    DevCheckouts.Service {
        id: service
        context: root.fakeContext
        onLoadedChanged: if (loaded) Qt.callLater(root.run)
    }

    Timer {
        interval: 10000
        running: true
        onTriggered: root.fail("helper output never loaded: " + service.lastError)
    }

    function verify(condition, message) {
        checks++
        if (!condition)
            throw new Error(message)
    }

    function fail(message) {
        console.error("DEV_CHECKOUTS_FIXTURE_FAIL " + message)
        Qt.exit(1)
    }

    function create(path, properties) {
        var component = Qt.createComponent(path, Component.PreferSynchronous)
        verify(component.status === Component.Ready, path + ": " + component.errorString())
        var item = component.createObject(root, properties)
        verify(item !== null, path + " construction")
        return item
    }

    function run() {
        try {
            verify(service.checkouts.length === 3, "all checkouts parsed")
            verify(service.runningCount === 1 && service.running[0].name === "dev-server-1",
                "running split")
            verify(service.idle.length === 2, "idle split")
            verify(service.checkouts[0].name === "t3code-e52c4300", "most recently used first")
            var coin = service.running[0]
            var unlabeled = service.idle.filter(function(c) { return c.name === "t3code-e52c4300" })[0]
            verify(service.title(coin) === "MCP-7160 COIN", "project is the title")
            verify(service.subtitle(coin) === "#1 · dev/flake", "branch beside project")
            verify(service.title(unlabeled) === "t3code/sd-channels", "branch fallback title")
            verify(service.subtitle(unlabeled) === "#8 · t3code-e52c4300 · db 7304-work",
                "name and non-default checkpoint in subtitle")
            verify(service.title(service.idle.filter(function(c) { return c.name === "broken" })[0])
                === "broken", "name fallback title")
            var live = service.liveLinks(coin)
            verify(live.length === 2 && live[0].name === "dashboard" && live[1].name === "dask",
                "only running services get buttons, in devcli order")
            verify(service.isPrimary(live[0]) && !service.isPrimary(coin.links[2]),
                "default primary links")
            verify(service.linkLabel(live[1]) === "Dask"
                && service.linkLabel({ name: "grafana" }) === "grafana",
                "known and unknown link labels")

            verify(service.openLink({ url: "file:///etc/passwd" }) === "invalid",
                "non-http links refused")
            verify(service.openLink(live[1]) === "started", "link opener started")

            var widget = create("plugins/dev-checkouts/Widget.qml", {
                context: fakeContext, service: service, outputId: "fixture-output"
            })
            verify(widget.label === "1", "chip shows running count")
            verify(String(widget.iconSource).endsWith("/assets/moberg.svg"), "chip brand mark")
            var panel = create("plugins/dev-checkouts/Panel.qml", {
                context: fakeContext, service: service,
                screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null,
                outputId: "fixture-output"
            })
            panel.open("{}")
            verify(panel.hostedPanel && panel.implicitHeight > 0, "panel lays out")

            service._apply('{"schema_version": 2, "checkouts": []}')
            verify(service.lastError === "Unsupported dev co list schema"
                && service.checkouts.length === 3, "unknown schema keeps last good list")
            service._apply('not json')
            verify(service.lastError === "Status helper returned invalid JSON", "invalid JSON")
            verify(widget.failing, "chip shows failure")

            verify(service.canResume(unlabeled) && !service.canResume(coin)
                && !service.canResume(service.idle.filter(function(c) {
                    return c.name === "broken" })[0]),
                "resume offered only for healthy stopped checkouts")
            service.actionError = "stale"
            verify(service.resume(unlabeled) === "started", "resume started")
            verify(service.actionError === "", "starting an action clears the old action error")
            verify(service.acting && service.pending(unlabeled, "resume")
                && !service.pending(unlabeled, "pause") && !service.pending(coin),
                "pending state names one checkout and verb")
            verify(service.pause(coin) === "busy", "one action at a time")
            step = "resume"
            actionPoll.start()
        } catch (error) {
            fail(error.message)
        }
    }

    property string step: ""

    Timer {
        id: actionPoll
        interval: 100
        repeat: true
        onTriggered: {
            if (service.acting || service.refreshing)
                return
            try {
                if (root.step === "resume") {
                    root.verify(service.actionError === "", "resume succeeded: " + service.actionError)
                    root.verify(service.pause({ name: "../x" }) === "invalid",
                        "unsafe checkout names refused")
                    root.verify(service.pause(service.running[0]) === "started", "pause started")
                    root.step = "pause"
                    return
                }
                stop()
                root.verify(service.actionError
                    === "Pause dev-server-1: checkout dev-server-1 is not registered",
                    "action error survives the follow-up poll: " + service.actionError)
                root.verify(service.lastError === "" && !service.refreshQueued,
                    "follow-up poll succeeded")
                actionLog.reload()
                root.verify(actionLog.text().trim()
                    === "resume t3code-e52c4300\npause dev-server-1",
                    "helper received verb and name: " + actionLog.text())
                openLog.reload()
                var opened = openLog.text().trim()
                root.verify(opened === "http://100.64.0.2:8887", "opener received URL: " + opened)
                console.log("DEV_CHECKOUTS_FIXTURE_OK " + root.checks + " checks")
                Qt.exit(0)
            } catch (error) {
                root.fail(error.message)
            }
        }
    }

    FileView {
        id: actionLog
        path: root.fixtureRoot + "/actions.txt"
        blockLoading: true
    }

    FileView {
        id: openLog
        path: root.fixtureRoot + "/opened.txt"
        blockLoading: true
    }
}
