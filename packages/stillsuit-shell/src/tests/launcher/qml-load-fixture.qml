import QtQuick
import Quickshell
import "model/Matcher.js" as Matcher
import "model/History.js" as History
import "model/Query.js" as Query
import "model/Engine.js" as Engine
import "model/providers/apps.js" as Apps
import "model/providers/calc.js" as Calc
import "model/providers/web.js" as Web
import "model/providers/windows.js" as Windows
import "model/providers/power.js" as Power
import "model/providers/profiles.js" as Profiles
import "model/providers/files.js" as Files
import "model/providers/clipboard.js" as Clipboard

ShellRoot {
    id: fixture

    function fail(message) {
        console.log("LAUNCHER_QML_FIXTURE_FAIL " + message)
        Qt.exit(1)
    }

    function expect(condition, message) {
        if (!condition) {
            fail(message)
            return false
        }
        return true
    }

    // Same generator as load.js syntheticApps, so node and V4 time the same
    // catalog.
    function syntheticApps(count) {
        var words = ["alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel",
            "india", "juliet", "kilo", "lima", "mike", "november", "oscar", "papa", "quebec",
            "romeo", "sierra", "tango", "uniform", "victor", "whiskey", "xray", "yankee", "zulu",
            "studio", "editor", "manager", "viewer", "player", "browser", "terminal", "monitor"]
        var result = []
        var seed = 12345
        function next() {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff
            return seed
        }
        function capitalized(word) {
            return word.charAt(0).toUpperCase() + word.slice(1)
        }
        for (var index = 0; index < count; index++) {
            var nameWords = []
            var length = 1 + next() % 3
            for (var w = 0; w < length; w++) nameWords.push(capitalized(words[next() % words.length]))
            var keywords = []
            for (var k = 0; k < 4; k++) keywords.push(words[next() % words.length])
            var genericName = words[next() % words.length] + " " + words[next() % words.length]
            var comment = "A synthetic " + words[next() % words.length] + " application for "
            comment += words[next() % words.length] + " and " + words[next() % words.length]
            result.push({
                id: "synthetic-" + index, name: nameWords.join(" ") + " " + index,
                genericName: genericName, comment: comment, keywords: keywords, icon: "synthetic-" + index,
                categories: [], actions: [], runInTerminal: false
            })
        }
        return result
    }

    function percentile(sorted, fraction) {
        return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))]
    }

    // Times every prefix of each word as one keystroke, three rounds. Date.now()
    // has 1 ms resolution, so each figure is rounded down to a whole ms.
    // prepare_ms of a later, larger catalog includes V4 growing its heap; a
    // fresh process prepares 1,500 apps in about 150 ms.
    function measure(engine, appCount) {
        var history = History.create(null)
        var now = Date.now()
        for (var record = 0; record < 400; record++)
            history.record("al", "apps:synthetic-" + (record * 7 % appCount), now - (record % 12) * 86400000)
        var env = { apps: syntheticApps(appCount), history: history, settings: { maxResults: 100 }, now: now }
        var prepareStarted = Date.now()
        engine.prepare(env)
        var prepareMs = Date.now() - prepareStarted
        var words = ["alpha", "studio", "brv", "terminal", "xray", "monitor", "zulu ed", "vic", "charlie 4", "sas"]
        var inputs = []
        for (var sequence = 0; inputs.length < 400; sequence++) {
            var word = words[sequence % words.length]
            for (var length = 1; length <= word.length && inputs.length < 400; length++)
                inputs.push(word.slice(0, length))
        }
        for (var warm = 0; warm < 40; warm++) engine.run(inputs[warm], "combi", env)
        var all = []
        var shortTimings = []
        for (var round = 0; round < 3; round++) {
            for (var index = 0; index < inputs.length; index++) {
                var started = Date.now()
                engine.run(inputs[index], "combi", env)
                var elapsed = Date.now() - started
                all.push(elapsed)
                if (inputs[index].length <= 2) shortTimings.push(elapsed)
            }
        }
        var byNumber = function(a, b) { return a - b }
        all.sort(byNumber)
        shortTimings.sort(byNumber)
        var emptyStarted = Date.now()
        engine.run("", "combi", env)
        var stats = {
            median: percentile(all, 0.5), p95: percentile(all, 0.95), max: all[all.length - 1],
            shortP95: percentile(shortTimings, 0.95)
        }
        console.log("LAUNCHER_QML_PERF apps=" + appCount + " keystrokes=" + all.length
            + " median_ms=" + stats.median + " p95_ms=" + stats.p95 + " max_ms=" + stats.max
            + " short_p95_ms=" + stats.shortP95 + " prepare_ms=" + prepareMs
            + " empty_ms=" + (Date.now() - emptyStarted))
        return stats
    }

    function runChecks() {
        var engine = Engine.create({
            Matcher: Matcher, History: History, Query: Query,
            providers: [Apps, Calc, Web, Windows, Power, Profiles, Files, Clipboard]
        })
        var env = {
            apps: [
                { id: "com.mitchellh.ghostty", name: "Ghostty", genericName: "Terminal", comment: "",
                    keywords: ["shell"], icon: "x", categories: [], actions: [{ id: "new-window", name: "New Window", icon: "" }],
                    runInTerminal: false },
                { id: "code", name: "Visual Studio Code", genericName: "Text Editor", comment: "",
                    keywords: [], icon: "x", categories: [], actions: [], runInTerminal: false }
            ],
            windows: [
                { id: 1, title: "A - Helium", app_id: "helium", is_focused: false, focus_timestamp: { secs: 10, nanos: 0 } },
                { id: 2, title: "B - Helium", app_id: "helium", is_focused: false, focus_timestamp: { secs: 20, nanos: 0 } }
            ],
            history: History.create(null),
            settings: { webEngine: "https://unduck.link?q=%TERM%", maxResults: 100, searchRoot: "/home/x" },
            calcResult: { text: "2+2*3", value: "8", error: "" },
            now: Date.now()
        }
        if (!expect(engine.run("ghost", "combi", env).rows[0].text === "Ghostty", "ghost")) return
        if (!expect(engine.run("vsc", "combi", env).rows[0].text === "Visual Studio Code", "vsc")) return
        if (!expect(engine.run("2+2*3", "combi", env).rows[0].text === "8", "calc")) return
        var windows = engine.run("$hel", "combi", env).rows
        if (!expect(windows.length === 2 && windows[0].windowId === 2, "windows")) return
        var web = engine.run("@nix flake", "combi", env).rows
        if (!expect(web.length === 1 && web[0].url === "https://unduck.link?q=nix%20flake", "web")) return
        var intent = engine.activate(engine.run("ghost", "combi", env).rows[0], "action:new-window")
        if (!expect(intent && intent.type === "app.launch" && intent.actionId === "new-window", "intent")) return
        engine.record(env.history, "vs", engine.run("vs", "combi", env).rows[0], env.now)
        var restored = History.create(JSON.parse(JSON.stringify(env.history.toJSON())))
        if (!expect(restored.size() === 1, "history round trip")) return
        var surrogate = engine.run("@" + "x".repeat(1022) + "\uD83D\uDE00", "combi", env).rows
        if (!expect(surrogate.length === 1 && surrogate[0].url.length === 1022 + 22, "surrogate cut")) return
        if (!expect(engine.run("@a\uD800", "combi", env).rows[0].url === "https://unduck.link?q=a%EF%BF%BD",
                "lone surrogate")) return
        var stale = engine.run("ghost", "combi", env).rows[0]
        var current = engine.run("ghost", "combi", env).rows[0]
        if (!expect(engine.activate(stale, "") === null, "stale row")) return
        if (!expect(engine.activate(current, "") !== null, "current row")) return
        var sigma = engine.run("ΛΟΓΟΣ", "combi", { apps: [{ id: "g", name: "λογος", actions: [] }] }).rows[0]
        if (!expect(sigma.key === "apps:g" && sigma.positions.join() === "0,1,2,3,4", "final sigma")) return

        var notesEnv = { filesResult: { text: "notes", paths: ["/home/test/notes.md"] }, now: Date.now() }
        var notes = engine.run("/notes", "combi", notesEnv).rows[0]
        if (!expect(Object.isFrozen(notes) && Object.isFrozen(notes.actions) && Object.isFrozen(notes.actions[0])
                && Object.isFrozen(notes.positions), "rows are frozen")) return
        try { notes.path = "/etc/shadow" } catch (error) {}
        if (!expect(notes.path === "/home/test/notes.md", "frozen row write")) return
        var opened = engine.activate(notes, "")
        if (!expect(opened && opened.path === "/home/test/notes.md", "row write ignored")) return
        var edited = {}
        for (var field in notes) edited[field] = notes[field]
        edited.path = "/etc/shadow"
        opened = engine.activate(edited, "")
        if (!expect(opened && opened.path === "/home/test/notes.md", "copy edit ignored")) return
        // V4 lets push() and index writes through on a frozen array, so the
        // mutated row itself must still be refused.
        var ghost = engine.run("ghost", "combi", env).rows[0]
        try { ghost.actions.push({ id: "action:injected", label: "x" }) } catch (error) {}
        try { ghost.actions[0].id = "action:injected" } catch (error) {}
        if (!expect(ghost.actions[0].id === "launch", "frozen action object")) return
        if (!expect(engine.activate(ghost, "action:injected") === null, "injected action on mutated row")) return
        var laterGhost = engine.run("ghost", "combi", env).rows[0]
        if (!expect(laterGhost.actions.length === 2, "injected action leaked into a later run")) return
        if (!expect(engine.activate(laterGhost, "action:injected") === null, "injected action")) return

        var editors = []
        for (var editor = 0; editor < 30; editor++) editors.push({ id: "a" + editor, name: "Editor", actions: [] })
        var capped = [5, 12, 20]
        for (var cap = 0; cap < capped.length; cap++) {
            var tiedRows = engine.run("", "combi", { apps: editors, settings: { maxResults: capped[cap] } }).rows
            var order = []
            for (var tied = 0; tied < tiedRows.length; tied++) order.push(tiedRows[tied].key)
            var wanted = []
            for (var want = 0; want < capped[cap]; want++) wanted.push("apps:a" + want)
            if (!expect(order.join() === wanted.join(), "tie order " + capped[cap] + ": " + order.join())) return
        }

        var spaced = [" a", "\ta"]
        for (var space = 0; space < spaced.length; space++) {
            var gated = Matcher.score(spaced[space], [spaced[space]], { minScore: 50 })
            if (!expect(gated.score === 62 && gated.positions.join() === "0,1", "whitespace first char " + space))
                return
        }

        var realistic = measure(engine, 400)
        if (!expect(realistic.p95 < 8, "400 apps: p95 " + realistic.p95 + " ms, budget 8 ms")) return
        var stress = measure(engine, 1500)
        if (!expect(stress.p95 < 16, "1500 apps: p95 " + stress.p95 + " ms, budget 16 ms")) return
        console.log("LAUNCHER_QML_FIXTURE_OK")
        Qt.exit(0)
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            try {
                fixture.runChecks()
            } catch (error) {
                fixture.fail(String(error))
            }
        }
    }
}
