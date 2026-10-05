import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services" as Services

ShellRoot {
    id: root

    readonly property string helper: Quickshell.env("FIXTURE_HELPER")
    readonly property string lateHelperPath: Quickshell.env("FIXTURE_LATE_HELPER")
    readonly property string configPath: Quickshell.env("FIXTURE_LAUNCH_CONFIG")
    property var spawned: []
    property var realSpawned: []
    property int checks: 0
    property var failures: []
    property string phase: "starting"
    property var entries: ({
        "org.example.Editor": {
            id: "org.example.Editor",
            command: ["editor", "--new"],
            runInTerminal: false,
            workingDirectory: "/srv/project",
            actions: [{ id: "private", command: ["editor", "--private"] }]
        },
        "htop": {
            id: "htop",
            command: ["htop"],
            runInTerminal: true,
            workingDirectory: "",
            actions: []
        },
        "broken": {
            id: "broken",
            command: [],
            runInTerminal: false,
            workingDirectory: "",
            actions: []
        }
    })

    Services.AppLaunch {
        id: launcher
        helperPath: root.helper
        configPath: root.configPath
        spawn: function(argv) { root.spawned.push(argv) }
        findEntry: function(id) { return root.entries[id] || null }
    }

    Services.AppLaunch {
        id: realEntries
        helperPath: root.helper
        configPath: root.configPath
        spawn: function(argv) { root.realSpawned.push(argv) }
    }

    Services.AppLaunch {
        id: unconfigured
        helperPath: ""
        configPath: ""
        spawn: function(argv) { root.spawned.push(argv) }
        findEntry: function(id) { return root.entries[id] || null }
    }

    Services.AppLaunch {
        id: throwing
        helperPath: root.helper
        configPath: root.configPath
        spawn: function(argv) { throw new Error("exec failed") }
        findEntry: function(id) { return root.entries[id] || null }
    }

    // These keep the real execDetached spawn.
    Services.AppLaunch {
        id: realHelper
        helperPath: root.helper
        configPath: root.configPath
        findEntry: function(id) { return root.entries[id] || null }
    }

    Services.AppLaunch {
        id: missingHelper
        helperPath: "/nonexistent/stillsuit-app-launch"
        configPath: root.configPath
        findEntry: function(id) { return root.entries[id] || null }
    }

    Services.AppLaunch {
        id: lateHelper
        helperPath: root.lateHelperPath
        configPath: root.configPath
        findEntry: function(id) { return root.entries[id] || null }
    }

    IpcFacade { id: facade; appLauncher: launcher }
    HostContext { id: contexts; actionsSource: facade }

    function expect(condition, message) {
        checks++
        if (!condition) failures.push(message)
    }

    function last() {
        return spawned.length > 0 ? JSON.stringify(spawned[spawned.length - 1]) : ""
    }

    function expectSpawn(status, expectedArgv, message) {
        expect(status === "ok" && last() === JSON.stringify(expectedArgv),
            message + ": " + status + " " + last())
    }

    // Before the startup check has finished, nothing reaches the helper.
    function runEarlyChecks() {
        expect(launcher.helperState === "checking" && launcher.helperChecks === 1,
            "the helper check starts at startup: " + launcher.helperState)
        expect(launcher.appLaunch("org.example.Editor", "") === "unavailable"
            && launcher.openUrl("https://example.com") === "unavailable"
            && launcher.openPath("/tmp", "open") === "unavailable",
            "helper launches are unavailable while the check runs")
        expect(launcher.helperChecks === 1, "calls during a running check start no second check")
        expect(spawned.length === 0, "nothing spawns before the helper check passes")
        expect(unconfigured.helperState === "unavailable", "an unset helper path is unavailable")
    }

    function helperChecksSettled() {
        var services = [launcher, realEntries, throwing, realHelper, missingHelper, lateHelper]
        for (var index = 0; index < services.length; index++)
            if (services[index].helperState === "checking") return false
        return true
    }

    function runSynchronousChecks() {
        expect(launcher.helperState === "ready", "a runnable helper passes its check: " + launcher.helperState)
        expect(launcher.helperChecks === 1, "a passing check is not repeated")
        expect(launcher.configError === "", "launch config loads: " + launcher.configError)
        expect(unconfigured.configError !== "", "missing launch config is reported")

        expect(missingHelper.helperState === "unavailable", "a nonexistent helper fails its check")
        expect(missingHelper.appLaunch("org.example.Editor", "") === "unavailable",
            "appLaunch through a nonexistent helper is unavailable, not ok")
        expect(missingHelper.helperChecks === 2 && missingHelper.helperState === "checking",
            "an unavailable launch starts one re-check")
        expect(missingHelper.openUrl("https://example.com") === "unavailable"
            && missingHelper.openPath("/tmp", "open") === "unavailable",
            "URL and path launches through a nonexistent helper are unavailable")
        expect(missingHelper.helperChecks === 2, "launches during the re-check start no other check")
        expect(realHelper.appLaunch("org.example.Editor", "") === "ok",
            "a checked helper launches through the real spawn path")

        var count = spawned.length
        expectSpawn(launcher.appLaunch("org.example.Editor", ""),
            [helper, "--name", "org.example.Editor", "--cwd", "/srv/project", "--", "editor", "--new"],
            "main entry launches through the helper with its working directory")
        expectSpawn(launcher.appLaunch("org.example.Editor", "private"),
            [helper, "--name", "org.example.Editor", "--cwd", "/srv/project", "--", "editor", "--private"],
            "desktop action launches its own command")
        expectSpawn(launcher.appLaunch("htop"),
            [helper, "--name", "htop", "--", "term", "-e", "htop"],
            "terminal entry is wrapped in the terminal prefix")
        expect(spawned.length === count + 3, "each launch spawns once")

        count = spawned.length
        expect(launcher.appLaunch("missing", "") === "unknown", "unknown desktop id")
        expect(launcher.appLaunch("org.example.Editor", "missing") === "unknown", "unknown desktop action")
        expect(launcher.appLaunch("../org.example.Editor", "") === "unknown", "path-like id is refused")
        expect(launcher.appLaunch("", "") === "unknown", "empty id is refused")
        expect(launcher.appLaunch(42, "") === "unknown", "non-string id is refused")
        expect(launcher.appLaunch("org.example.Editor", 7) === "unknown", "non-string action is refused")
        expect(launcher.appLaunch("broken", "") === "error", "entry without a command is an error")
        expect(unconfigured.appLaunch("org.example.Editor", "") === "unavailable",
            "missing helper is unavailable")
        expect(unconfigured.appLaunch("htop", "") === "error", "missing terminal prefix is an error")
        expect(throwing.appLaunch("org.example.Editor", "") === "error", "spawn failure is an error")
        expect(spawned.length === count, "refused launches spawn nothing")

        expectSpawn(launcher.openUrl("https://example.com/search?q=a%20b#top"),
            [helper, "--name", "browser-bin", "--", "/opt/bin/browser-bin", "--new-tab",
                "https://example.com/search?q=a%20b#top"],
            "https URL opens through the browser prefix")
        expectSpawn(launcher.openUrl("HTTP://Example.com"),
            [helper, "--name", "browser-bin", "--", "/opt/bin/browser-bin", "--new-tab", "HTTP://Example.com"],
            "scheme check is case-insensitive")
        count = spawned.length
        var invalidUrls = ["javascript:alert(1)", "file:///etc/passwd", "http://", "https:///path",
            "https://example.com/a b", "https://example.com/\nx", "-https://example.com",
            "https://example.com/" + "a".repeat(8200), 7, ""]
        for (var index = 0; index < invalidUrls.length; index++)
            expect(launcher.openUrl(invalidUrls[index]) === "invalid",
                "invalid URL is refused: " + String(invalidUrls[index]).substring(0, 40))
        expect(launcher.openUrl("https://example.com/" + "a".repeat(8000)) === "ok",
            "URL within 8 KiB is accepted")
        expect(unconfigured.openUrl("https://example.com") === "error", "missing browser prefix is an error")
        expect(spawned.length === count + 1, "refused URLs spawn nothing")

        expectSpawn(launcher.openPath("/home/user/notes.md", "open"),
            [helper, "--name", "opener", "--", "opener", "/home/user/notes.md"],
            "path opens through the opener prefix")
        expectSpawn(launcher.openPath("/home/user/dir/notes.md", "reveal"),
            [helper, "--name", "opener", "--", "opener", "/home/user/dir"],
            "reveal opens the parent directory")
        expectSpawn(launcher.openPath("/home/user/dir/", "reveal"),
            [helper, "--name", "opener", "--", "opener", "/home/user"],
            "reveal ignores a trailing slash")
        expectSpawn(launcher.openPath("/top", "reveal"),
            [helper, "--name", "opener", "--", "opener", "/"],
            "reveal of a top-level path opens the root")
        expectSpawn(launcher.openPath("/does/not/exist yet", "open"),
            [helper, "--name", "opener", "--", "opener", "/does/not/exist yet"],
            "a path need not exist")
        count = spawned.length
        expect(launcher.openPath("relative/path", "open") === "invalid", "relative path is refused")
        expect(launcher.openPath("/a\u0000b", "open") === "invalid", "NUL in path is refused")
        expect(launcher.openPath("/a", "delete") === "invalid", "unknown mode is refused")
        expect(launcher.openPath("/a") === "invalid", "missing mode is refused")
        expect(launcher.openPath(null, "open") === "invalid", "non-string path is refused")
        expect(spawned.length === count, "refused paths spawn nothing")

        expectSpawn(launcher.sessionAction("lock"), ["/fixture/bin/lock", "--now"],
            "session action runs its argv directly")
        count = spawned.length
        expect(launcher.sessionAction("suspend") === "error", "unconfigured session action is an error")
        expect(launcher.sessionAction("shutdown") === "unknown", "unknown session action")
        expect(launcher.sessionAction(undefined) === "unknown", "missing session action")
        expect(launcher.sessionAction("logout") === "error", "invalid configured argv is dropped")
        expect(spawned.length === count, "refused session actions spawn nothing")

        expect(launcher.copyText(17) === "error", "non-string copy is refused")
        expect(launcher.copyText("x".repeat(1048577)) === "error", "copy over 1 MiB is refused")
        expect(launcher.copyText("é".repeat(524289)) === "error", "copy limit counts UTF-8 bytes")

        var actions = contexts.actionsComponent.createObject(root)
        count = spawned.length
        expect(actions.appLaunch("org.example.Editor") === "ok", "context action launches without an action id")
        expect(actions.openUrl("https://example.com") === "ok", "context openUrl reaches the launcher")
        expect(actions.openPath("/tmp", "open") === "ok", "context openPath reaches the launcher")
        expect(actions.sessionAction("lock") === "ok", "context sessionAction reaches the launcher")
        expect(actions.openUrl("ftp://example.com") === "invalid", "context passes launcher status through")
        expect(spawned.length === count + 4, "context actions spawn through the launcher")
        facade.appLauncher = null
        expect(actions.appLaunch("org.example.Editor", "") === "error"
            && actions.openUrl("https://example.com") === "error"
            && actions.openPath("/tmp", "open") === "error"
            && actions.copyText("x") === "error"
            && actions.sessionAction("lock") === "error",
            "actions without a launcher report error")
        facade.appLauncher = launcher
    }

    function startCopies() {
        var actions = contexts.actionsComponent.createObject(root)
        expect(actions.copyText("first copy") === "ok", "copy starts")
        expect(launcher.copyProcess.running, "copy process runs")
        expect(actions.copyText("second copy") === "ok", "copy queues while running")
        expect(actions.copyText("third copy\nwith a line") === "ok", "newest queued copy wins")
        expect(launcher._copyPending === "third copy\nwith a line", "only the newest copy is pending")
    }

    property Timer entryPoll: Timer {
        interval: 50
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++
            var status = realEntries.appLaunch("fixture-terminal", "")
            if (status === "unknown" && attempts < 100)
                return
            stop()
            root.expect(status === "ok", "real desktop entry resolves: " + status)
            root.expect(JSON.stringify(root.realSpawned[0]) === JSON.stringify([
                root.helper, "--name", "fixture-terminal", "--cwd", "/tmp", "--",
                "term", "-e", "fixture-tool", "--open", "quoted arg", "%literal"]),
                "field codes are stripped and Terminal=true wraps: " + JSON.stringify(root.realSpawned[0]))
            root.expect(realEntries.appLaunch("fixture-terminal", "new-window") === "ok",
                "real desktop action resolves")
            root.expect(JSON.stringify(root.realSpawned[1]) === JSON.stringify([
                root.helper, "--name", "fixture-terminal", "--cwd", "/tmp", "--",
                "term", "-e", "fixture-tool", "--new-window"]),
                "real desktop action argv: " + JSON.stringify(root.realSpawned[1]))
            root.expect(realEntries.appLaunch("fixture-hidden", "") === "ok",
                "NoDisplay entries still launch by id")
            root.phase = "copying"
            root.startCopies()
        }
    }

    property Timer checkPoll: Timer {
        interval: 50
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++
            if (!root.helperChecksSettled() && attempts < 100)
                return
            stop()
            try {
                root.runSynchronousChecks()
            } catch (error) {
                root.failures.push("exception: " + error + " " + error.stack)
            }
            entryPoll.start()
        }
    }

    // Completion order between this root and its children is not defined.
    Component.onCompleted: Qt.callLater(function() {
        try {
            runEarlyChecks()
        } catch (error) {
            failures.push("exception: " + error + " " + error.stack)
        }
        checkPoll.start()
    })

    IpcHandler {
        target: "app-launch-test"
        function phase(): string { return root.phase }
        function copyState(): string {
            return JSON.stringify({
                running: launcher.copyProcess.running,
                pending: launcher._copyPending !== null
            })
        }
        function result(): string {
            return JSON.stringify({ checks: root.checks, failures: root.failures })
        }
        function helperState(name: string): string {
            var service = name === "late" ? lateHelper : missingHelper
            return JSON.stringify({ state: service.helperState, checks: service.helperChecks })
        }
        function lateLaunch(): string { return lateHelper.appLaunch("org.example.Editor", "private") }
    }
}
