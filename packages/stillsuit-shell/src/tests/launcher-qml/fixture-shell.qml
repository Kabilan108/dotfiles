import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "plugins/builtin/launcher" as Launcher
import "tests/FixtureTheme.js" as FixtureTheme

// Drives the launcher service and menu against a fake host context, fixture
// desktop entries, and fake qalc and fd scripts that log every run. Keys are
// real key events sent to the fixture window, so they reach the menu through
// the focused search field. Each step acts once and then waits for its
// condition; the run stops at the first failed step and prints
// LAUNCHER_QML_OK or LAUNCHER_QML_FAIL lines.
ShellRoot {
    id: root

    readonly property string logPath: Quickshell.env("LAUNCHER_FIXTURE_LOG")
    readonly property string stateRoot: Quickshell.env("LAUNCHER_FIXTURE_STATE")
    readonly property string searchRoot: Quickshell.env("LAUNCHER_FIXTURE_SEARCH_ROOT")
    readonly property string screenshotDir: Quickshell.env("LAUNCHER_FIXTURE_SCREENSHOTS")
    readonly property string applicationsDir: Quickshell.env("LAUNCHER_FIXTURE_APPLICATIONS")
    property var calls: []
    // Action name -> status the fake host returns instead of success.
    property var refusals: ({})
    property var warnings: []
    property real mark: 0
    property int appsRevision: 0
    property var savedItems: []
    property var delegatesBefore: ({})
    property var failures: []
    property int checks: 0
    property int stepIndex: -1
    property real stepStarted: 0
    property bool stepActed: false
    property int startCalls: 0
    property string shot: ""

    function record(name, args) {
        calls.push({ name: name, args: args })
        if (refusals[name] !== undefined)
            return refusals[name]
        return name === "profileActivate" ? "started" : "ok"
    }

    function callsNamed(name) {
        return calls.filter(function(call) { return call.name === name })
    }

    function lastCall(name) {
        var list = callsNamed(name)
        return list.length > 0 ? JSON.stringify(list[list.length - 1].args) : ""
    }

    function expect(condition, message) {
        checks++
        if (!condition) {
            failures.push(message)
            console.log("LAUNCHER_QML_FAIL " + message)
        }
    }

    function logLines() {
        logFile.reload()
        var text = logFile.text()
        return text === "" ? [] : text.trim().split("\n")
    }

    function linesMatching(pattern) {
        return logLines().filter(function(line) { return pattern.test(line) })
    }

    function rowTexts() {
        return service.rows.map(function(row) { return row.provider + ":" + row.text })
    }

    function rowIndex(predicate) {
        for (var index = 0; index < service.rows.length; index++)
            if (predicate(service.rows[index])) return index
        return -1
    }

    function fieldFocused() {
        var field = menu.fieldItem()
        return !!field && field.inputItem.activeFocus
    }

    // Sends a key press and release to the window; the focused search field
    // receives it. Returns whether the event was delivered.
    function key(code, modifiers) {
        expect(fieldFocused(), "the search field has focus before key " + code)
        return events.keyClick(code, modifiers || 0, -1)
    }

    function typeKeys(text) {
        for (var index = 0; index < text.length; index++)
            events.keyClickChar(text.charAt(index), 0, -1)
    }

    // Replaces the field text in one edit, which reaches the service through
    // the field's text change like typing does.
    function type(text) {
        menu.fieldItem().text = text
    }

    // The order MenuHost uses: open the content, show it, focus the scope.
    function openMenu(payload) {
        menu.open(payload)
        menu.visible = true
        menu.forceActiveFocus()
    }

    function bannerText() {
        var banner = menu.findNamed(menu, "launcher-status-row")
        return banner && banner.visible ? menu.findNamed(banner, "launcher-status-text").text : ""
    }

    function bannerColor() {
        var banner = menu.findNamed(menu, "launcher-status-row")
        return banner ? String(banner.children[0].color) : ""
    }

    function resultList() {
        return menu.findNamed(menu, "launcher-results")
    }

    // Delegate per row key for every row the list has an item for.
    function delegatesByKey() {
        var list = resultList()
        list.forceLayout()
        var result = {}
        for (var index = 0; index < service.rows.length; index++) {
            var item = list.itemAtIndex(index)
            if (item)
                result[service.rows[index].key] = item
        }
        return result
    }

    // Checks that rows still on screen kept their delegate and that every
    // delegate shows the row at its index.
    function checkDelegates(before, label) {
        var after = delegatesByKey()
        var kept = 0
        var fresh = 0
        for (var key in after) {
            if (before[key] === undefined) {
                var reused = false
                for (var old in before)
                    reused = reused || before[old] === after[key]
                if (!reused)
                    fresh++
                continue
            }
            kept++
            expect(after[key] === before[key], label + ": " + key + " kept its delegate")
        }
        var list = resultList()
        for (var index = 0; index < service.rows.length; index++) {
            var item = list.itemAtIndex(index)
            if (item)
                expect(item.row && item.row.key === service.rows[index].key && item.selected === (index === service.selectedIndex),
                    label + ": delegate " + index + " shows its row: " + (item.row ? item.row.key : "none"))
        }
        expect(kept >= 8, label + ": rows on screen survive: " + kept)
        expect(fresh <= 1, label + ": at most one new delegate: " + fresh)
        return after
    }

    // What each visible row's icon slot shows: the pack glyph name once its
    // image is ready, "app:<icon>" for a theme icon, or "letter:<label>" when
    // the theme lookup failed and the monogram placeholder is up.
    function rowGlyphs() {
        var list = resultList()
        list.forceLayout()
        var result = []
        for (var index = 0; index < service.rows.length; index++) {
            var item = list.itemAtIndex(index)
            if (!item)
                continue
            var glyph = menu.findNamed(item, "launcher-row-shell-icon")
            var app = menu.findNamed(item, "launcher-row-app-icon")
            if (glyph && glyph.visible)
                result.push(glyph.ready ? glyph.name : "loading:" + glyph.name)
            else if (app && app.visible)
                result.push(app.ready ? "app:" + app.icon : "letter:" + app.fallbackLabel)
            else
                result.push("none")
        }
        return result
    }

    function noteItems() {
        var items = []
        for (var index = 0; index < 100; index++)
            items.push({ id: "n" + index, kind: "text", mime: "text/plain", bytes: 8,
                preview: index === 3 ? "other thing" : "note " + index,
                created: 100000 - index, lastUsed: 100000 - index, path: "" })
        return items
    }

    function writeApplication(name, text) {
        applicationFile.path = root.applicationsDir + "/" + name + ".desktop"
        applicationFile.setText(text)
    }

    property QtObject fakeCompositor: QtObject {
        property int revision: 1
        property var lastFocusedWindowId: null
        property var workspaces: [
            { id: 1, idx: 1, name: "", output: "DP-1" },
            { id: 2, idx: 2, name: "web", output: "DP-2" }
        ]
        property var windows: [
            { id: 11, title: "Helium docs", app_id: "helium", workspace_id: 1, is_focused: false,
                focus_timestamp: { secs: 100, nanos: 0 } },
            { id: 12, title: "Helium mail", app_id: "helium", workspace_id: 2, is_focused: true,
                focus_timestamp: { secs: 200, nanos: 0 } },
            { id: 13, title: "Terminal", app_id: "com.mitchellh.ghostty", workspace_id: 1, is_focused: false,
                focus_timestamp: { secs: 50, nanos: 0 } }
        ]
    }

    property QtObject fakeProfiles: QtObject {
        property string active: "default"
        property var available: [
            { id: "default", name: "Default", description: "Everything" },
            { id: "focus", name: "Focus", description: "Fewer widgets" }
        ]
        property int revision: 3
        property string state: "ready"
        property string error: ""
    }

    property QtObject fakeClipboard: QtObject {
        property var items: [
            { id: "c1", kind: "text", mime: "text/plain", bytes: 11, preview: "hello world",
                created: 3000, lastUsed: 3000, path: "" },
            { id: "c2", kind: "text", mime: "text/plain", bytes: 9, preview: "second clip\nline two",
                created: 2000, lastUsed: 2000, path: "" },
            { id: "c3", kind: "image", mime: "image/png", bytes: 120, preview: "",
                created: 1000, lastUsed: 1000, path: Quickshell.env("LAUNCHER_FIXTURE_IMAGE") }
        ]
        property int revision: 1
        property string status: "ok"
        property string error: ""
        function copy(id) { return root.record("clipboard.copy", [id]) }
        function remove(id) {
            var status = root.record("clipboard.remove", [id])
            if (status === "ok") {
                items = items.filter(function(item) { return item.id !== id })
                revision++
            }
            return status
        }
        function clear() {
            var status = root.record("clipboard.clear", [])
            if (status === "ok") {
                items = []
                revision++
            }
            return status
        }
    }

    property QtObject fakeServices: QtObject {
        property int revision: 1
        function has(id) { return id === "stillsuit.clipboard" }
        function get(id) { return id === "stillsuit.clipboard" ? root.fakeClipboard : null }
        function state(id) { return id === "stillsuit.clipboard" ? "loaded" : "unloaded" }
    }

    property QtObject fakeActions: QtObject {
        function surfaceClose(id) {
            root.record("surfaceClose", [id])
            menu.close()
            menu.visible = false
            return "ok"
        }
        function windowFocus(id) { return root.record("windowFocus", [id]) }
        function profileActivate(id) { return root.record("profileActivate", [id]) }
        function appLaunch(desktopId, actionId) { return root.record("appLaunch", [desktopId, actionId]) }
        function openUrl(url) { return root.record("openUrl", [url]) }
        function openPath(path, mode) { return root.record("openPath", [path, mode]) }
        function copyText(text) { return root.record("copyText", [text]) }
        function sessionAction(name) { return root.record("sessionAction", [name]) }
    }

    property QtObject fakeContext: QtObject {
        readonly property var theme: FixtureTheme.create()
        readonly property QtObject compositor: root.fakeCompositor
        readonly property QtObject services: root.fakeServices
        readonly property QtObject profiles: root.fakeProfiles
        readonly property QtObject actions: root.fakeActions
        readonly property QtObject logger: QtObject {
            function debug(message) { console.log("launcher debug: " + message) }
            function info(message) { console.log("launcher info: " + message) }
            function warn(message) {
                root.warnings.push(message)
                console.log("launcher warn: " + message)
            }
            function error(message) { console.log("launcher error: " + message) }
        }
        readonly property QtObject settings: QtObject {
            readonly property string pluginId: "stillsuit.launcher"
            readonly property var values: ({
                remminaPath: Quickshell.env("LAUNCHER_FIXTURE_REMMINA"),
                remminaListPath: Quickshell.env("LAUNCHER_FIXTURE_REMMINA_LIST"),
                qalcPath: Quickshell.env("LAUNCHER_FIXTURE_QALC"),
                fdPath: Quickshell.env("LAUNCHER_FIXTURE_FD"),
                searchRoot: root.searchRoot,
                webEngine: "https://unduck.link?q=%TERM%",
                maxResults: 100
            })
            readonly property var paths: ({ stateRoot: root.stateRoot })
        }
        readonly property string instanceId: "fixture"
    }

    Launcher.Service {
        id: service
        context: root.fakeContext
    }

    FloatingWindow {
        id: window
        implicitWidth: 1000
        implicitHeight: 760
        color: root.fakeContext.theme.semantic.background.canvas
        visible: true

        Item {
            anchors.fill: parent

            TestEvent { id: events }

            TextInput {
                id: probeInput
                x: 0
                y: 0
                width: 10
                height: 10
            }

            Launcher.Menu {
                id: menu
                x: 20
                y: 20
                width: implicitWidth
                height: implicitHeight
                context: root.fakeContext
                service: service

                function fieldItem() {
                    return findNamed(menu, "launcher-field")
                }
                function findNamed(item, name) {
                    if (item.objectName === name)
                        return item
                    for (var index = 0; index < item.children.length; index++) {
                        var found = findNamed(item.children[index], name)
                        if (found)
                            return found
                    }
                    return null
                }
            }
        }
    }

    FileView {
        id: applicationFile
        atomicWrites: true
        printErrors: false
    }

    FileView {
        id: logFile
        path: root.logPath
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: historyFile
        path: root.stateRoot + "/launcher/history.v1.json"
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    function screenshot(name) {
        if (screenshotDir === "")
            return
        shot = ""
        menu.grabToImage(function(result) {
            result.saveToFile(root.screenshotDir + "/" + name + ".png")
            root.shot = name
        })
    }

    // {name, act(), until() -> bool, timeout ms (default 3000)}
    property var steps: [
        {
            name: "desktop entries scanned",
            until: function() { return DesktopEntries.applications.values.length >= 5 }
        },
        {
            name: "the closed launcher does no work after startup",
            act: function() { root.stepStarted = Date.now() },
            until: function() { return Date.now() - root.stepStarted > 2500 }
        },
        {
            name: "combi opens on apps and filters",
            act: function() {
                root.expect(!service.pendingWork && !service.opened && service.rows.length === 0,
                    "nothing is scheduled while closed")
                root.expect(service._apps.length === 0 && !service._historyLoaded,
                    "no snapshot or history is read before the first open")
                root.openMenu('{"mode":"combi"}')
                root.expect(service._apps.length >= 5 && !service._appsDirty,
                    "the first open builds the app snapshot")
                root.expect(service._historyLoaded, "the first open reads the history")
                root.expect(service.opened && service.mode === "combi", "opens in combi")
                root.expect(root.fieldFocused(), "the search field takes focus on open")
                root.expect(service.rows.length >= 5, "empty combi lists apps: " + root.rowTexts())
                root.expect(service.rows.every(function(row) { return row.provider === "apps" }),
                    "empty combi lists only apps: " + root.rowTexts())
                root.expect(root.rowIndex(function(row) { return row.text === "Hidden Tool" }) === -1,
                    "NoDisplay entries are skipped")
                root.type("ghost")
                root.expect(service.query === "ghost", "field text reaches the service")
                root.expect(service.rows.length > 0 && service.rows[0].text === "Ghostty",
                    "ghost -> Ghostty first: " + root.rowTexts())
                root.expect(service.rows[0].positions.length === 5, "match positions are exposed")
            },
            until: function() { return true }
        },
        {
            name: "screenshot combi",
            act: function() { root.screenshot("combi") },
            until: function() { return root.screenshotDir === "" || root.shot === "combi" }
        },
        {
            name: "Enter launches the app and records history",
            act: function() {
                root.expect(root.key(Qt.Key_Return), "Enter is handled")
                root.expect(root.lastCall("appLaunch") === '["com.mitchellh.ghostty",""]',
                    "Enter launches the main entry: " + root.lastCall("appLaunch"))
                root.expect(root.callsNamed("surfaceClose").length === 1, "launch closes the surface")
                root.expect(!service.opened && service.rows.length === 0, "closed service drops its rows")
                root.expect(service.history.boost("ghost", "apps:com.mitchellh.ghostty", Date.now()) > 0,
                    "launch is recorded in history")
            },
            until: function() {
                historyFile.reload()
                return historyFile.text().indexOf("apps:com.mitchellh.ghostty") !== -1
            }
        },
        {
            name: "Tab arms the desktop action",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.expect(service.query === "" && menu.fieldItem().text === "", "reopen resets the query")
                root.type("ghostty")
                root.expect(service.selectedRow && service.selectedRow.text === "Ghostty", "Ghostty selected")
                root.expect(root.key(Qt.Key_Tab), "Tab is handled")
                root.expect(service.selectedAction && service.selectedAction.id === "action:new-window",
                    "Tab arms the desktop action: " + JSON.stringify(service.selectedAction))
                root.key(Qt.Key_Backtab)
                root.expect(service.actionIndex === 0, "Shift+Tab cycles back")
                root.key(Qt.Key_Tab)
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("appLaunch") === '["com.mitchellh.ghostty","new-window"]',
                    "Tab+Enter runs the desktop action: " + root.lastCall("appLaunch"))
            },
            until: function() { return true }
        },
        {
            name: "keys move, cycle, and type through the field",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                var field = menu.fieldItem()
                var moves = [
                    [Qt.Key_Down, 0, 1, "Down"], [Qt.Key_J, Qt.ControlModifier, 2, "Ctrl+J"],
                    [Qt.Key_Up, 0, 1, "Up"], [Qt.Key_K, Qt.ControlModifier, 0, "Ctrl+K"],
                    [Qt.Key_PageDown, 0, Math.min(service.pageSize, service.rows.length - 1), "PageDown"],
                    [Qt.Key_PageUp, 0, 0, "PageUp"]
                ]
                root.expect(service.rows.length >= 5, "combi lists apps to move through")
                for (var index = 0; index < moves.length; index++) {
                    root.key(moves[index][0], moves[index][1])
                    root.expect(service.selectedIndex === moves[index][2],
                        moves[index][3] + " selects " + moves[index][2] + ": " + service.selectedIndex)
                    root.expect(field.text === "" && root.fieldFocused(),
                        moves[index][3] + " leaves the field empty and focused: '" + field.text + "'")
                }
                root.typeKeys("ghostty")
                root.expect(field.text === "ghostty" && service.query === "ghostty",
                    "typed keys reach the field and the service: " + field.text)
                root.expect(service.selectedRow && service.selectedRow.text === "Ghostty", "typing selects Ghostty")
                root.key(Qt.Key_Tab)
                root.expect(service.actionIndex === 1, "Tab arms the next action")
                root.key(Qt.Key_Backtab, Qt.ShiftModifier)
                root.expect(service.actionIndex === 0, "Shift+Tab as Backtab cycles back")
                root.key(Qt.Key_Tab, Qt.ShiftModifier)
                root.expect(service.actionIndex === 1, "Shift+Tab as shifted Tab cycles back and wraps")
                root.key(Qt.Key_Return, Qt.ControlModifier)
                root.expect(service.actionIndex === 0, "Ctrl+Enter cycles actions")
                root.key(Qt.Key_D, Qt.ControlModifier)
                root.expect(field.text === "ghostty" && service.opened && root.callsNamed("clipboard.remove").length === 0,
                    "Ctrl+D outside the clipboard does nothing")
                root.expect(field.text === "ghostty" && root.fieldFocused(), "action keys leave the field text alone")
                root.calls = []
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("appLaunch") === '["com.mitchellh.ghostty",""]',
                    "Enter runs the default action: " + root.lastCall("appLaunch"))
                root.openMenu('{"mode":"combi"}')
                root.key(Qt.Key_Escape)
                root.expect(!service.opened && root.callsNamed("surfaceClose").length === 2, "Escape closes")
            },
            until: function() { return true }
        },
        {
            name: "typing right after open lands in the field",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.typeKeys("obs")
                root.mark = Date.now()
            },
            until: function() { return Date.now() - root.mark > 150 }
        },
        {
            name: "open does not reset typed text later",
            act: function() {
                root.expect(menu.fieldItem().text === "obs" && service.query === "obs",
                    "text typed on open survives: '" + menu.fieldItem().text + "'")
                probeInput.forceActiveFocus()
                root.expect(!root.fieldFocused(), "the probe took focus")
                menu.forceActiveFocus()
                root.expect(root.fieldFocused(), "focusing the menu focuses the search field")
                root.typeKeys("i")
                root.expect(service.query === "obsi", "typing continues after refocus: " + service.query)
                root.fakeActions.surfaceClose("stillsuit.launcher")
            },
            until: function() { return true }
        },
        {
            name: "armed action survives an apps rescan",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.type("ghostty")
                root.key(Qt.Key_Tab)
                root.expect(service.selectedAction && service.selectedAction.id === "action:new-window",
                    "new-window armed: " + JSON.stringify(service.selectedAction))
                root.appsRevision = service._appsRevision
                root.writeApplication("com.mitchellh.ghostty", "[Desktop Entry]\nType=Application\nName=Ghostty\n"
                    + "GenericName=Terminal\nExec=ghostty\nIcon=com.mitchellh.ghostty\nKeywords=shell;terminal;\n"
                    + "Actions=new-tab;new-window;\n\n[Desktop Action new-tab]\nName=New Tab\nExec=ghostty --new-tab\n\n"
                    + "[Desktop Action new-window]\nName=New Window\nExec=ghostty --new-window\n")
            },
            until: function() { return service._appsRevision > root.appsRevision },
            timeout: 4000
        },
        {
            name: "armed action falls back when it disappears",
            act: function() {
                root.expect(service.selectedRow && service.selectedRow.text === "Ghostty", "Ghostty stays selected")
                root.expect(service.selectedRow.actions.length === 3, "the rescan added an action")
                root.expect(service.selectedAction && service.selectedAction.id === "action:new-window",
                    "the armed action follows its id: " + JSON.stringify(service.selectedAction))
                root.appsRevision = service._appsRevision
                root.writeApplication("com.mitchellh.ghostty", "[Desktop Entry]\nType=Application\nName=Ghostty\n"
                    + "GenericName=Terminal\nExec=ghostty\nIcon=com.mitchellh.ghostty\nKeywords=shell;terminal;\n")
            },
            until: function() { return service._appsRevision > root.appsRevision },
            timeout: 4000
        },
        {
            name: "restore the Ghostty entry",
            act: function() {
                root.expect(service.selectedRow && service.selectedRow.text === "Ghostty"
                    && service.selectedRow.actions.length === 1 && service.actionIndex === 0,
                    "a vanished action falls back to the default: " + service.actionIndex)
                root.appsRevision = service._appsRevision
                root.writeApplication("com.mitchellh.ghostty", "[Desktop Entry]\nType=Application\nName=Ghostty\n"
                    + "GenericName=Terminal\nExec=ghostty\nIcon=com.mitchellh.ghostty\nKeywords=shell;terminal;\n"
                    + "Actions=new-window;\n\n[Desktop Action new-window]\nName=New Window\nExec=ghostty --new-window\n")
            },
            until: function() { return service._appsRevision > root.appsRevision },
            timeout: 4000
        },
        {
            name: "armed clipboard action survives a new item",
            act: function() {
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.openMenu('{"mode":"clipboard"}')
                root.key(Qt.Key_Tab)
                root.expect(service.selectedRow.key === "clipboard:c1" && service.selectedAction.id === "remove",
                    "Tab arms Delete on the top item")
                root.savedItems = root.fakeClipboard.items
                root.fakeClipboard.items = [{ id: "c0", kind: "text", mime: "text/plain", bytes: 3, preview: "new",
                    created: 4000, lastUsed: 4000, path: "" }].concat(root.savedItems)
                root.fakeClipboard.revision++
                root.expect(root.rowTexts()[0] === "clipboard:new", "the new item is on top: " + root.rowTexts())
                root.expect(service.selectedRow.key === "clipboard:c1" && service.selectedIndex === 1,
                    "selection follows the armed row: " + service.selectedIndex)
                root.expect(service.selectedAction.id === "remove", "Delete stays armed")
                root.fakeClipboard.items = root.savedItems
                root.fakeClipboard.revision++
                root.fakeActions.surfaceClose("stillsuit.launcher")
            },
            until: function() { return true }
        },
        {
            name: "prefixes switch providers",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.type("$hel")
                root.expect(service.prefixProvider === "windows", "$ selects windows")
                root.expect(root.rowTexts().slice(0, 2).join("|") === "windows:Helium mail|windows:Helium docs",
                    "$hel lists Helium windows by recency: " + root.rowTexts())
                root.expect(service.rows[1].subtext.indexOf("workspace 1") !== -1
                    && service.rows[1].subtext.indexOf("DP-1") !== -1,
                    "window subtext names workspace and output: " + service.rows[1].subtext)
                root.type("!nix flake")
                root.expect(service.prefix === "" && service.rows[0].key === "web:search"
                    && service.rows[0].url === "https://unduck.link?q=!nix%20flake",
                    "a bang search row comes first: " + root.rowTexts())
                root.type(":")
                root.expect(service.prefixProvider === "clipboard" && service.rows.length === 3,
                    ": lists clipboard items: " + root.rowTexts())
                root.type("obs")
                root.expect(service.prefix === "" && service.rows.length > 0 && service.rows[0].provider === "apps",
                    "plain text is back to combi: " + root.rowTexts())
            },
            until: function() { return true }
        },
        {
            name: "calc row for the current text, stale answer dropped",
            act: function() {
                root.startCalls = root.linesMatching(/^qalc start/).length
                root.type("1+1")
            },
            until: function() { return root.linesMatching(/^qalc start .*-- 1\+1$/).length === 1 },
        },
        {
            name: "superseded qalc run does not answer",
            act: function() {
                root.expect(service.calcBusy, "calc is busy while qalc runs")
                root.type("3*3")
            },
            until: function() {
                return service.rows.length > 0 && service.rows[0].provider === "calc"
            }
        },
        {
            name: "calc answer is for the current text",
            act: function() {
                root.expect(service.rows[0].text === "9" && service.rows[0].subtext === "3*3",
                    "calc row answers 3*3: " + root.rowTexts())
                root.expect(root.linesMatching(/^qalc done 1\+1$/).length === 1,
                    "the stale run finished on its own")
                root.expect(root.rowIndex(function(row) { return row.text === "2" }) === -1,
                    "the stale answer never shows")
                var started = root.linesMatching(/^qalc start/)
                root.expect(started[started.length - 1].indexOf("-t -u8 -m 1000 -- 3*3") !== -1,
                    "qalc argv ends options before the expression: " + started[started.length - 1])
                root.type("-v")
                root.expect(service.rows.every(function(row) { return row.provider !== "calc" }),
                    "non-math text has no calc row")
                root.type("2+2*3")
            },
            until: function() { return service.rows.length > 0 && service.rows[0].provider === "calc" }
        },
        {
            name: "Enter copies the calc result",
            act: function() {
                root.expect(service.rows[0].text === "8", "2+2*3 -> 8 on top: " + root.rowTexts())
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("copyText") === '["8"]', "calc Enter copies: " + root.lastCall("copyText"))
                root.expect(!service.opened, "copy closes the launcher")
            },
            until: function() { return true }
        },
        {
            name: "files: fd follows directory links but not build output",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.type("/needle")
            },
            until: function() { return service.rows.length > 0 && service.rows[0].provider === "files" }
        },
        {
            name: "files: linked results",
            act: function() {
                root.expect(root.rowTexts().slice().sort().join("|")
                    === "files:proj/needle-src.txt|files:repos/project/needle-vault.txt",
                    "fd finds files behind a directory link and skips result links and node_modules: "
                    + root.rowTexts().slice(0, 12))
                root.type("/PROJ/needle")
            },
            until: function() {
                return root.linesMatching(/^fd start .*--case-sensitive --full-path -- .*PROJ\/needle /).length === 1
                    && !service.filesBusy
            }
        },
        {
            name: "files: a capital makes the search case-sensitive",
            act: function() {
                root.expect(service.rows.every(function(row) { return row.provider !== "files" }),
                    "PROJ does not match proj: " + root.rowTexts())
                root.type("/proj/needle")
            },
            until: function() { return service.rows.length > 0 && service.rows[0].provider === "files" }
        },
        {
            name: "files: a folder in the query matches the path",
            act: function() {
                root.expect(root.rowTexts().join("|") === "files:proj/needle-src.txt",
                    "proj/needle matches only inside proj: " + root.rowTexts())
                root.type("/repos/**/needle*.txt")
            },
            until: function() {
                return service.rows.length > 0 && service.rows[0].text === "repos/project/needle-vault.txt"
            }
        },
        {
            name: "files: path globs",
            act: function() {
                root.expect(root.rowTexts().join("|") === "files:repos/project/needle-vault.txt",
                    "repos/**/needle*.txt crosses folders: " + root.rowTexts())
                root.type("/needle-s*")
            },
            until: function() { return service.rows.length > 0 && service.rows[0].text === "proj/needle-src.txt" }
        },
        {
            name: "files: name globs",
            act: function() {
                root.expect(root.rowTexts().join("|") === "files:proj/needle-src.txt",
                    "needle-s* matches whole names: " + root.rowTexts())
                root.fakeActions.surfaceClose("stillsuit.launcher")
            },
            until: function() { return true }
        },
        {
            name: "files: superseded fd run is killed",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.type("/slow")
            },
            until: function() { return root.linesMatching(/^fd start .*-- slow /).length === 1 }
        },
        {
            name: "files: current fd run answers",
            act: function() {
                root.expect(service.filesBusy, "files lookup is busy")
                root.type("/main q")
            },
            until: function() { return service.rows.length > 0 && service.rows[0].provider === "files" }
        },
        {
            name: "files rows and actions",
            act: function() {
                root.expect(root.linesMatching(/^fd term slow$/).length === 1, "the superseded fd run was terminated")
                var started = root.linesMatching(/^fd start/)
                root.expect(started[started.length - 1].indexOf("--follow --max-results 200 --absolute-path --color never "
                    + "--exclude result --exclude result-* --exclude node_modules --exclude .direnv --exclude .git "
                    + "--exclude .cache --print0 --ignore-case -- main.*q " + root.searchRoot) !== -1,
                    "fd argv: " + started[started.length - 1])
                root.expect(root.rowTexts().slice().sort().join("|") === "files:docs/main-quick/|files:src/main.qml",
                    "fd paths become rows: " + root.rowTexts())
                service.select(root.rowIndex(function(row) { return row.text === "src/main.qml" }))
                root.key(Qt.Key_Tab)
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("openPath") === JSON.stringify([root.searchRoot + "/src/main.qml", "reveal"]),
                    "reveal opens the parent through openPath: " + root.lastCall("openPath"))
                root.openMenu('{"mode":"combi"}')
                root.type("/(")
            },
            until: function() { return root.linesMatching(/^fd start .*-- \\\( /).length === 1 }
        },
        {
            name: "a timed-out fd keeps only complete paths",
            act: function() {
                root.type("/partial")
            },
            until: function() { return service.rows.length > 0 },
            timeout: 5000
        },
        {
            name: "timed-out fd row check",
            act: function() {
                var paths = service.rows.map(function(row) { return row.path || "" })
                root.expect(paths.length === 1 && /partial-done\.txt$/.test(paths[0]),
                    "unterminated fd record is dropped: " + paths)
            },
            until: function() { return true }
        },
        {
            name: "closing kills a running fd",
            act: function() {
                root.type("/slow")
            },
            until: function() { return root.linesMatching(/^fd start .*-- slow /).length === 2 }
        },
        {
            name: "closed launcher runs nothing",
            act: function() {
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.startCalls = root.logLines().length
                root.fakeCompositor.revision++
                root.fakeCompositor.windows = root.fakeCompositor.windows.slice(0, 2)
                root.fakeClipboard.revision++
                root.fakeProfiles.revision++
            },
            until: function() { return root.linesMatching(/^fd term slow$/).length === 2 }
        },
        {
            name: "still nothing after a while",
            act: function() { root.stepStarted = Date.now() },
            until: function() { return Date.now() - root.stepStarted > 900 }
        },
        {
            name: "closed state checks",
            act: function() {
                var after = root.logLines().slice(root.startCalls)
                root.expect(after.filter(function(line) { return /start/.test(line) }).length === 0,
                    "no lookups start while closed: " + after)
                root.expect(!service.pendingWork, "no timer or process runs while closed")
                root.expect(service.rows.length === 0 && !service.busy, "closed launcher is idle")
                root.expect(service._windowsRevision === 1, "window snapshot is not rebuilt while closed")
            },
            until: function() { return true }
        },
        {
            name: "window focus closes first, focuses later",
            act: function() {
                root.calls = []
                root.openMenu('{"mode":"windows"}')
                root.expect(service._windowsRevision === 2, "window snapshot rebuilt on open")
                root.expect(root.rowTexts().join("|") === "windows:Helium docs|windows:Helium mail",
                    "empty windows query is alt-tab order: " + root.rowTexts())
                root.key(Qt.Key_Return)
                var names = root.calls.map(function(call) { return call.name })
                root.expect(names[0] === "surfaceClose" && names.lastIndexOf("surfaceClose") === 0,
                    "surface closes before focusing: " + JSON.stringify(root.calls))
            },
            until: function() { return root.callsNamed("windowFocus").length === 1 }
        },
        {
            name: "power rows load pack glyphs",
            act: function() { root.openMenu('{"mode":"power"}') },
            until: function() {
                return root.rowGlyphs().join(" ") === "lock sleep logout refresh power"
            }
        },
        {
            name: "power rows render pack glyphs, not theme lookups or letters",
            act: function() {
                // The fixture has no icon theme, like a system without
                // non-symbolic names; theme lookups would fall back to letters.
                root.expect(root.rowGlyphs().join(" ") === "lock sleep logout refresh power",
                    "power rows show ShellIcon glyphs: " + root.rowGlyphs())
                root.screenshot("power")
            },
            until: function() { return root.screenshotDir === "" || root.shot === "power" }
        },
        {
            name: "power and profiles",
            act: function() {
                root.expect(root.lastCall("windowFocus") === "[11]", "focuses the selected window")
                root.openMenu('{"mode":"power"}')
                root.expect(service.rows.length === 5 && service.rows[0].text === "Lock", "power lists its actions")
                root.expect(menu.implicitWidth === menu.compactWidth && menu.compactWidth < menu.standardWidth,
                    "power is compact: " + menu.implicitWidth)
                root.expect(menu.fieldItem().iconName === "power", "power field icon: " + menu.fieldItem().iconName)
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("sessionAction") === '["lock"]', "power row runs sessionAction")
                root.openMenu('{"mode":"profiles"}')
                root.expect(service.rows[0].text === "Default" && service.rows[0].current === true,
                    "current profile is first and marked")
                root.expect(menu.implicitWidth === menu.compactWidth && menu.fieldItem().iconName === "layers",
                    "profiles is compact with its icon: " + menu.implicitWidth + " " + menu.fieldItem().iconName)
                root.type("/x")
                root.expect(menu.implicitWidth === menu.standardWidth && menu.fieldItem().iconName === "folder",
                    "a files prefix widens the frame: " + menu.implicitWidth + " " + menu.fieldItem().iconName)
                root.type("")
                root.key(Qt.Key_Down)
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("profileActivate") === '["focus"]', "profile row activates")
            },
            until: function() { return true }
        },
        {
            name: "refused actions keep the menu open with a reason",
            act: function() {
                root.calls = []
                root.refusals = { appLaunch: "unavailable" }
                root.openMenu('{"mode":"combi"}')
                root.type("ghostty")
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.callsNamed("surfaceClose").length === 0,
                    "a refused launch keeps the menu open")
                root.expect(root.bannerText() === "Couldn't open Ghostty: launcher helper unavailable",
                    "the banner names the app and reason: " + root.bannerText())
                root.expect(root.bannerColor() === String(root.fakeContext.theme.semantic.surface.danger),
                    "the banner uses the danger surface: " + root.bannerColor())
                root.typeKeys("x")
                root.expect(root.bannerText() === "" && service.actionError === "", "a query change clears the banner")
                root.refusals = { sessionAction: "unknown" }
                root.openMenu('{"mode":"power"}')
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.bannerText() === "Couldn't lock: unknown action",
                    "refused session action: " + root.bannerText())
                root.refusals = { profileActivate: "busy" }
                root.openMenu('{"mode":"profiles"}')
                root.expect(root.bannerText() === "", "opening clears the banner")
                root.key(Qt.Key_Down)
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.bannerText() === "Couldn't switch to Focus: another profile switch is running",
                    "busy profile switch: " + root.bannerText())
                root.refusals = { profileActivate: "unknown" }
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.bannerText() === "Couldn't switch to Focus: the profile is not available",
                    "unknown profile: " + root.bannerText())
                root.refusals = {}
                root.key(Qt.Key_Return)
                root.expect(!service.opened && root.callsNamed("surfaceClose").length === 1,
                    "a started profile switch closes")
                root.refusals = { copyText: "error" }
                root.openMenu('{"mode":"combi"}')
                root.type("!nix")
                root.key(Qt.Key_Tab)
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.bannerText() === "Couldn't copy to the clipboard: it could not be started",
                    "refused copy: " + root.bannerText())
                root.refusals = { "clipboard.remove": "unavailable", "clipboard.copy": "unknown" }
                root.openMenu('{"mode":"clipboard"}')
                root.key(Qt.Key_D, Qt.ControlModifier)
                root.expect(service.opened && service.rows.length === 3
                    && root.bannerText() === "Couldn't delete the clipboard item: clipboard history is unavailable",
                    "refused delete: " + root.bannerText())
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.bannerText() === "Couldn't copy the clipboard item: the item is gone",
                    "refused clipboard copy: " + root.bannerText())
                root.refusals = {}
                root.savedItems = root.fakeClipboard.items
                root.key(Qt.Key_D, Qt.ControlModifier)
                root.expect(service.opened && service.rows.length === 2 && root.bannerText() === "",
                    "a successful action clears the banner")
                root.fakeClipboard.items = root.savedItems
                root.fakeClipboard.revision++
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.expect(service.actionError === "", "closing clears the error")
            },
            until: function() { return true }
        },
        {
            name: "a vanished window is reported before closing",
            act: function() {
                root.calls = []
                root.openMenu('{"mode":"windows"}')
                root.expect(service.rows[0].text === "Helium docs", "Helium docs is first: " + root.rowTexts())
                var windows = root.fakeCompositor.windows
                root.fakeCompositor.windows = windows.filter(function(window) { return window.id !== 11 })
                root.key(Qt.Key_Return)
                root.expect(service.opened && root.calls.length === 0,
                    "a vanished window neither closes nor focuses: " + JSON.stringify(root.calls))
                root.expect(root.bannerText() === "Couldn't focus Helium docs: the window is gone",
                    "the banner explains: " + root.bannerText())
                root.fakeCompositor.windows = windows
                root.refusals = { windowFocus: "unknown" }
                root.warnings = []
                root.key(Qt.Key_Return)
                root.expect(!service.opened && root.callsNamed("surfaceClose").length === 1, "a live window closes first")
            },
            until: function() { return root.callsNamed("windowFocus").length === 1 }
        },
        {
            name: "a late focus failure is only logged",
            act: function() {
                root.refusals = {}
                root.expect(root.warnings.indexOf("window focus returned unknown") !== -1,
                    "the deferred failure is logged: " + JSON.stringify(root.warnings))
                root.expect(!service.opened && service.actionError === "", "nothing is raised after close")
            },
            until: function() { return true }
        },
        {
            // niri flags no window once the menu holds focus, and its
            // debounced stamps can still put the previous window newest.
            name: "the window focused at open stays current",
            act: function() {
                var saved = root.fakeCompositor.windows
                var stamped = function(id, title, focused, secs) {
                    return { id: id, title: title, app_id: "app" + id, workspace_id: 1, is_focused: focused,
                        focus_timestamp: { secs: secs, nanos: 0 } }
                }
                root.fakeCompositor.windows = [
                    stamped(21, "Revisited", true, 100),
                    stamped(22, "Previous", false, 300),
                    stamped(23, "Older", false, 50)
                ]
                root.fakeCompositor.revision++
                root.openMenu('{"mode":"windows"}')
                root.fakeCompositor.windows = root.fakeCompositor.windows.map(function(window) {
                    return Object.assign({}, window, { is_focused: false })
                })
                root.fakeCompositor.revision++
                root.expect(root.rowTexts().join("|") === "windows:Previous|windows:Older|windows:Revisited",
                    "the window focused at open goes last: " + root.rowTexts())
                root.expect(service.rows[2].current === true && service.rows[0].current === false,
                    "the window focused at open is labeled current")
                root.openMenu('{"mode":"windows"}')
                root.expect(service.rows.length === 3 && service.rows[2].text === "Revisited" && service.rows[2].current,
                    "reopening while the menu holds focus keeps the capture: " + root.rowTexts())
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.fakeCompositor.windows = saved
                root.fakeCompositor.revision++
            },
            until: function() { return true }
        },
        {
            // Another layer surface (a Stillsuit panel) holds the keyboard as
            // the menu opens, so niri flags no window; the compositor's last
            // focused window stands in, unless it is no longer open.
            name: "with no flagged window the last focused one is current",
            act: function() {
                var saved = root.fakeCompositor.windows
                var stamped = function(id, title, secs) {
                    return { id: id, title: title, app_id: "app" + id, workspace_id: 1, is_focused: false,
                        focus_timestamp: { secs: secs, nanos: 0 } }
                }
                root.fakeCompositor.windows = [
                    stamped(21, "Revisited", 100),
                    stamped(22, "Previous", 300),
                    stamped(23, "Older", 50)
                ]
                root.fakeCompositor.lastFocusedWindowId = 21
                root.fakeCompositor.revision++
                root.openMenu('{"mode":"windows"}')
                root.expect(root.rowTexts().join("|") === "windows:Previous|windows:Older|windows:Revisited",
                    "the last focused window goes last: " + root.rowTexts())
                root.expect(service.rows[2].current === true && service.rows[0].current === false,
                    "the last focused window is labeled current")
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.fakeCompositor.lastFocusedWindowId = 99
                root.openMenu('{"mode":"windows"}')
                root.expect(service.rows[2].text === "Previous" && service.rows[2].current === true,
                    "a closed last focused window falls back to the newest stamp: " + root.rowTexts())
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.fakeCompositor.lastFocusedWindowId = null
                root.fakeCompositor.windows = saved
                root.fakeCompositor.revision++
            },
            until: function() { return true }
        },
        {
            name: "keepOpenOnToggle switches modes",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.expect(menu.keepOpenOnToggle('{"mode":"clipboard"}') === true, "combi -> clipboard switches")
                root.expect(menu.keepOpenOnToggle('{"mode":"combi"}') === false, "same mode closes")
                root.expect(menu.keepOpenOnToggle('{}') === false, "missing mode is combi")
                root.expect(menu.keepOpenOnToggle('not json') === false, "invalid payload is combi")
                root.type("ghost")
                root.key(Qt.Key_Down)
                menu.open('{"mode":"clipboard"}')
                root.expect(service.mode === "clipboard" && service.query === "" && service.selectedIndex === 0,
                    "switching mode resets query and selection")
                root.expect(menu.implicitWidth === menu.clipboardWidth && menu.clipboardWidth > menu.standardWidth,
                    "clipboard view is wide: " + menu.implicitWidth)
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.expect(menu.keepOpenOnToggle('{"mode":"clipboard"}') === false, "closed menu never stays open")
            },
            until: function() { return true }
        },
        {
            name: "narrowed rows keep their delegates",
            act: function() {
                root.savedItems = root.fakeClipboard.items
                root.fakeClipboard.items = root.noteItems()
                root.fakeClipboard.revision++
                root.openMenu('{"mode":"clipboard"}')
                root.expect(service.rows.length === 100, "100 clipboard rows: " + service.rows.length)
                var before = root.delegatesByKey()
                root.expect(Object.keys(before).length >= 9, "the list built the rows on screen")
                var started = Date.now()
                root.type("note")
                var elapsed = Date.now() - started
                console.log("launcher narrowing 100 -> 99 took " + elapsed + " ms")
                root.expect(service.rows.length === 99, "note narrows to 99 rows: " + service.rows.length)
                root.expect(elapsed < 250, "narrowing is cheap: " + elapsed + " ms")
                var after = root.checkDelegates(before, "narrowing")
                root.key(Qt.Key_Down)
                root.key(Qt.Key_Down)
                root.fakeClipboard.remove("n1")
                root.expect(service.rows.length === 98 && service.rows[1].key === "clipboard:n2",
                    "a mid-list removal drops the row: " + root.rowTexts().slice(0, 3))
                root.expect(service.selectedRow.key === "clipboard:n2", "selection stays on its row")
                root.checkDelegates(after, "mid-list removal")
                root.fakeClipboard.items = root.savedItems
                root.fakeClipboard.revision++
                root.fakeActions.surfaceClose("stillsuit.launcher")
            },
            until: function() { return true }
        },
        {
            name: "clipboard rows and preview",
            act: function() {
                root.openMenu('{"mode":"clipboard"}')
                root.expect(root.rowTexts().join("|") === "clipboard:hello world|clipboard:second clip line two|clipboard:Image",
                    "clipboard rows newest first: " + root.rowTexts())
                root.expect(menu.fieldItem().iconName === "clipboard", "clipboard field icon: " + menu.fieldItem().iconName)
                root.expect(root.key(Qt.Key_I, Qt.ControlModifier), "Ctrl+I is handled")
                root.expect(menu.imagesOnly && root.rowTexts().join("|") === "clipboard:Image",
                    "Ctrl+I lists images only: " + root.rowTexts())
                root.expect(menu.fieldItem().iconName === "image", "images-only field icon: " + menu.fieldItem().iconName)
                root.key(Qt.Key_I, Qt.ControlModifier)
                root.expect(!menu.imagesOnly && service.rows.length === 3, "Ctrl+I again lists everything")
                root.key(Qt.Key_I, Qt.ControlModifier)
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.openMenu('{"mode":"clipboard"}')
                root.expect(!menu.imagesOnly && service.rows.length === 3, "reopening clears the image filter")
                root.key(Qt.Key_Down)
                root.key(Qt.Key_Down)
                root.expect(menu.previewData && menu.previewData.kind === "image", "image row previews the blob")
            },
            until: function() { return true }
        },
        {
            name: "screenshot clipboard",
            act: function() { root.screenshot("clipboard") },
            until: function() { return root.screenshotDir === "" || root.shot === "clipboard" }
        },
        {
            name: "clipboard actions",
            act: function() {
                root.calls = []
                root.key(Qt.Key_Up)
                root.expect(root.key(Qt.Key_D, Qt.ControlModifier), "Ctrl+D is handled")
                root.expect(root.lastCall("clipboard.remove") === '["c2"]', "Ctrl+D removes the selected item")
                root.expect(root.callsNamed("surfaceClose").length === 0 && service.opened, "remove keeps the menu open")
                root.expect(root.rowTexts().join("|") === "clipboard:hello world|clipboard:Image",
                    "removed row disappears: " + root.rowTexts())
                root.expect(service.selectedIndex === 1, "selection stays in place after removal")
                root.key(Qt.Key_Up)
                root.key(Qt.Key_Return)
                root.expect(root.lastCall("clipboard.copy") === '["c1"]', "Enter copies the item")
                root.expect(root.callsNamed("surfaceClose").length === 1, "copy closes")
                root.openMenu('{"mode":"clipboard"}')
                root.key(Qt.Key_Tab)
                root.key(Qt.Key_Tab)
                root.expect(service.selectedAction.id === "clear", "Tab reaches clear")
                root.key(Qt.Key_Return)
                root.expect(root.callsNamed("clipboard.clear").length === 1, "clear runs on the service")
                root.fakeClipboard.status = "degraded"
                root.fakeClipboard.error = "clipboard watcher exited with status 1; retrying in 2 s"
                root.openMenu('{"mode":"clipboard"}')
                root.expect(menu.clipboardProblem && service.rows.length === 0, "degraded clipboard shows a status row")
            },
            until: function() { return true }
        },
        {
            name: "screenshot degraded",
            act: function() { root.screenshot("clipboard-degraded") },
            until: function() { return root.screenshotDir === "" || root.shot === "clipboard-degraded" }
        },
        {
            name: "escape closes",
            act: function() {
                root.calls = []
                root.key(Qt.Key_Escape)
                root.expect(root.callsNamed("surfaceClose").length === 1 && !service.opened, "Escape closes")
                root.expect(!service.pendingWork, "nothing runs after Escape")
            },
            until: function() { return true }
        },
        {
            name: "an apps rescan while closed only marks the snapshot stale",
            act: function() {
                root.openMenu('{"mode":"combi"}')
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.appsRevision = service._appsRevision
                root.writeApplication("rescan-probe", "[Desktop Entry]\nType=Application\nName=Rescan Probe\nExec=probe\n")
            },
            until: function() { return service._appsDirty },
            timeout: 4000
        },
        {
            name: "the rescan does no work while closed",
            act: function() {
                root.expect(!service.pendingWork, "nothing is scheduled while closed")
                root.expect(service._appsRevision === root.appsRevision, "the snapshot is not rebuilt while closed")
                root.openMenu('{"mode":"combi"}')
                root.type("rescan probe")
                root.expect(service.rows.length > 0 && service.rows[0].text === "Rescan Probe",
                    "the next open rebuilds the stale snapshot: " + root.rowTexts())
                root.fakeActions.surfaceClose("stillsuit.launcher")
                root.expect(!service.pendingWork, "closing leaves nothing scheduled")
            },
            until: function() { return true }
        }
        ,{
            name: "saved connections load as a flat list",
            act: function() { root.openMenu('{"mode":"remmina"}') },
            until: function() { return service.rows.length === 3 && !service.connectionsBusy }
        },
        {
            name: "connection groups are visible and searchable",
            act: function() {
                root.expect(service.rows[0].text === "Alpha", "connections sort by name")
                root.expect(service.rows[0].subtext === "Lab · SSH · alpha.example", "group is visible")
                root.type("lab")
                root.expect(service.rows.length === 2, "group search filters flat list")
                root.screenshot("remmina-group")
            },
            until: function() { return root.shot === "remmina-group" || root.screenshotDir === "" }
        },
        {
            name: "connection selection emits a validated saved path",
            act: function() {
                var intent = service.engine.activate(service.rows[0], "connect")
                root.expect(intent.type === "remmina.connect" && intent.path === "/tmp/alpha.remmina", "saved profile intent")
                root.expect(service.activate(0, "connect") === "ok", "connection launches")
                root.expect(!service.opened, "connection launch closes picker")
            },
            until: function() {
                return root.logLines().indexOf("remmina:--connect") !== -1
                    && root.logLines().indexOf("remmina:/tmp/alpha.remmina") !== -1
            }
        }
    ]

    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: root.tick()
    }

    // Real key delivery spins the event loop, so the timer can fire while a
    // step is still acting; a nested tick would advance the step twice.
    property bool ticking: false

    function tick() {
        if (ticking)
            return
        ticking = true
        try {
            tickStep()
        } finally {
            ticking = false
        }
    }

    function tickStep() {
        if (stepIndex >= steps.length)
            return
        if (stepIndex < 0) {
            stepIndex = 0
            stepStarted = Date.now()
            stepActed = false
        }
        var step = steps[stepIndex]
        if (!stepActed) {
            stepActed = true
            try {
                if (step.act) step.act()
            } catch (error) {
                expect(false, step.name + " threw: " + error + "\n" + error.stack)
            }
        }
        var done = false
        try {
            done = step.until ? step.until() : true
        } catch (error) {
            expect(false, step.name + " condition threw: " + error)
            done = true
        }
        if (!done && Date.now() - stepStarted > (step.timeout || 3000)) {
            expect(false, "timed out: " + step.name + " rows=" + rowTexts() + " log=" + logLines().join(" / "))
            done = true
        }
        if (!done)
            return
        if (failures.length > 0) {
            finish()
            return
        }
        stepIndex++
        stepStarted = Date.now()
        stepActed = false
        if (stepIndex >= steps.length)
            finish()
    }

    function finish() {
        stepIndex = steps.length
        if (failures.length === 0)
            console.log("LAUNCHER_QML_OK " + checks + " checks")
        Qt.callLater(Qt.quit)
    }
}
