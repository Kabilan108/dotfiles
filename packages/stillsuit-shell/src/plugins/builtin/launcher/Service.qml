import QtQuick
import Quickshell
import Quickshell.Io
import "model/Engine.js" as Engine
import "model/Matcher.js" as Matcher
import "model/History.js" as History
import "model/Query.js" as Query
import "model/providers/remmina.js" as Remmina
import "model/providers/apps.js" as Apps
import "model/providers/calc.js" as Calc
import "model/providers/clipboard.js" as Clipboard
import "model/providers/files.js" as Files
import "model/providers/power.js" as Power
import "model/providers/profiles.js" as Profiles
import "model/providers/web.js" as Web
import "model/providers/windows.js" as Windows

// Launcher state and intent execution. The menu is a view over `rows`.
//
// Everything is driven by the menu being open: snapshots are rebuilt lazily
// when a provider that reads them is active and their source changed, and the
// qalc and fd lookups only run for the text currently shown. Closing kills
// any lookup, stops every timer, and drops the rows. Source changes that
// arrive while closed only mark a snapshot stale.
Scope {
    id: root

    required property var context

    readonly property string apiVersion: "1"
    readonly property string pluginId: context && context.settings && context.settings.pluginId
        ? String(context.settings.pluginId) : "stillsuit.launcher"
    readonly property var values: context && context.settings && context.settings.values
        ? context.settings.values : ({})
    readonly property string stateRoot: context && context.settings && context.settings.paths
        ? String(context.settings.paths.stateRoot || "") : ""
    readonly property string historyPath: stateRoot.charAt(0) === "/"
        ? stateRoot + "/launcher/history.v1.json" : ""
    readonly property string qalcPath: _absolute(values.qalcPath)
    readonly property string fdPath: _absolute(values.fdPath)
    readonly property string searchRoot: _absolute(values.searchRoot)
    readonly property var engineSettings: ({
        webEngine: String(values.webEngine || ""),
        maxResults: values.maxResults === undefined ? Engine.DEFAULT_MAX_RESULTS : values.maxResults,
        searchRoot: searchRoot
    })

    readonly property int qalcDebounceMs: 60
    readonly property int qalcTimeoutMs: 1500
    readonly property int fdDebounceMs: 120
    readonly property int fdTimeoutMs: 2000
    readonly property int fdMaxResults: 200
    readonly property int pageSize: 8

    readonly property string remminaListPath: _absolute(values.remminaListPath)
    readonly property string remminaPath: _absolute(values.remminaPath)
    property var connections: []
    property int connectionsRevision: 0
    property bool opened: false
    property string mode: Query.DEFAULT_MODE
    property string query: ""
    // Row objects from the engine's latest run; see model/Engine.js.
    property var rows: []
    property int selectedIndex: 0
    // Index into the selected row's actions that Enter runs.
    property int actionIndex: 0
    property string prefix: ""
    property var providerIds: []
    // The clipboard picker lists only images; reset on every open.
    property bool clipboardImagesOnly: false
    // Why the last action was refused, shown until the query changes or an
    // action succeeds; "" when there is nothing to report.
    property string actionError: ""
    // The provider a prefix selected, or "" without a prefix.
    readonly property string prefixProvider: prefix !== "" && providerIds.length === 1 ? providerIds[0] : ""
    readonly property var selectedRow: selectedIndex >= 0 && selectedIndex < rows.length ? rows[selectedIndex] : null
    readonly property var selectedAction: selectedRow && selectedRow.actions
        && actionIndex < selectedRow.actions.length ? selectedRow.actions[actionIndex] : null
    readonly property bool calcBusy: _calcWanted !== ""
    readonly property bool filesBusy: _filesWanted !== ""
    readonly property bool connectionsBusy: connectionsProcess.running
    readonly property bool busy: calcBusy || filesBusy || connectionsBusy
    readonly property bool clipboardActive: providerIds.indexOf("clipboard") !== -1
    // A lookup, debounce, or rescan is scheduled or running. Always false
    // while closed; the debounced history write is not counted.
    readonly property bool pendingWork: appsTimer.running || calcDebounce.running || calcTimeout.running
        || connectionsProcess.running || calcProcess.running || filesDebounce.running || filesTimeout.running || filesProcess.running

    // The clipboard service is a declared dependency; its own status reports
    // a broken watcher, and a missing service is reported here.
    readonly property QtObject clipboard: context && context.services
        ? (context.services.revision, context.services.get("stillsuit.clipboard")) : null
    readonly property string clipboardStatus: clipboard ? String(clipboard.status || "") : "error"
    readonly property string clipboardError: clipboard
        ? String(clipboard.error || "") : "Clipboard history is not available"

    readonly property var engine: Engine.create({
        Matcher: Matcher,
        History: History,
        Query: Query,
        providers: [Calc, Apps, Web, Windows, Power, Profiles, Files, Clipboard, Remmina]
    })

    property var history: History.create(null, Date.now())
    property bool _historyLoaded: false
    property string _lastText: ""
    property bool _userMoved: false

    property var _apps: []
    property int _appsRevision: 0
    property bool _appsDirty: true
    property var _iconCache: ({})
    property var _windows: []
    property int _windowsRevision: -1
    // The window niri flagged focused when the menu opened, else the
    // compositor's last focused window if it is still open, else null. Once
    // the menu (or a panel opened before it) holds keyboard focus niri flags
    // none, and its debounced focus stamps can still name the previous window.
    property var _currentWindowId: null
    property var _profiles: ({ active: "", available: [] })
    property int _profilesRevision: 0
    property string _profilesKey: ""
    property var _clipboardItems: []
    property int _clipboardRevision: -1
    property QtObject _clipboardSource: null

    property var calcResult: null
    property string _calcWanted: ""
    property int _calcGeneration: 0
    property int _calcRunGeneration: -1
    property string _calcRunText: ""
    property int _calcExitCode: -1
    property bool _calcRestart: false

    property var filesResult: null
    property string _filesWanted: ""
    property int _filesGeneration: 0
    property int _filesRunGeneration: -1
    property string _filesRunText: ""
    property int _filesExitCode: -1
    property bool _filesTimedOut: false
    property bool _filesRestart: false

    function open(payload) {
        var request = _request(payload)
        _ensureHistory()
        // A mode switch reopens the menu while it holds focus; keep what the
        // first open saw.
        var focusedId = _focusedWindowId()
        if (focusedId !== null || !opened)
            _currentWindowId = focusedId !== null ? focusedId : _lastFocusedWindowId()
        mode = request.mode
        query = request.query
        clipboardImagesOnly = false
        selectedIndex = 0
        actionIndex = 0
        actionError = ""
        _userMoved = false
        opened = true
        _rerun()
        if (providerIds.indexOf("remmina") !== -1)
            _loadConnections()
    }

    function _loadConnections() {
        if (remminaListPath === "") {
            actionError = "Remmina connection helper is unavailable"
            return
        }
        connections = []
        connectionsRevision++
        _rerun()
        connectionsProcess.running = true
    }

    function close() {
        _cancelCalc()
        _cancelFiles()
        connectionsProcess.running = false
        appsTimer.stop()
        if (!opened && rows.length === 0)
            return
        opened = false
        rows = []
        selectedIndex = 0
        actionIndex = 0
        actionError = ""
        calcResult = null
        filesResult = null
    }

    // The menu's requested mode, so a toggle can decide to switch instead of close.
    function requestedMode(payload) {
        return _request(payload).mode
    }

    function setQuery(text) {
        var next = String(text === undefined || text === null ? "" : text)
        if (next === query)
            return
        query = next
        actionError = ""
        if (Query.parse(query, mode).providerIds.indexOf("remmina") !== -1
            && providerIds.indexOf("remmina") === -1)
            _loadConnections()
        _userMoved = false
        _rerun()
    }

    function toggleClipboardImages() {
        if (!opened || !clipboardActive)
            return
        clipboardImagesOnly = !clipboardImagesOnly
        _userMoved = false
        _rerun()
    }

    function move(delta) {
        if (rows.length === 0)
            return
        select(Math.max(0, Math.min(rows.length - 1, selectedIndex + delta)))
    }

    function select(index) {
        if (index < 0 || index >= rows.length)
            return
        _userMoved = true
        if (index === selectedIndex)
            return
        selectedIndex = index
        actionIndex = 0
    }

    function cycleAction(delta) {
        var count = selectedRow && selectedRow.actions ? selectedRow.actions.length : 0
        if (count < 2)
            return
        // An armed action is a choice a background refresh must keep.
        _userMoved = true
        actionIndex = ((actionIndex + delta) % count + count) % count
    }

    // Runs `actionId` of rows[index], or the row's default action for "".
    // Returns the action's status, or "none" when nothing ran.
    function activate(index, actionId) {
        if (!opened || index < 0 || index >= rows.length)
            return "none"
        var row = rows[index]
        var intent = engine.activate(row, actionId === undefined ? "" : String(actionId))
        if (!intent)
            return "none"
        if (intent.type === "window.focus") {
            // Focus runs after the surface closes, too late to report a
            // failure, so a window that already vanished is caught here.
            var windowId = intent.id
            if (!_windowExists(windowId)) {
                _refuse(intent, row, "gone")
                return "unknown"
            }
            actionError = ""
            _closeSurface()
            var actions = context.actions
            Qt.callLater(function() { root._report("window focus", actions.windowFocus(windowId)) })
            return "ok"
        }
        var status = _execute(intent)
        if (!_succeeded(intent, status)) {
            _refuse(intent, row, status)
            return status
        }
        actionError = ""
        if (intent.type === "app.launch" && engine.record(history, _lastText, row, Date.now()))
            persistTimer.restart()
        if (intent.keepOpen !== true)
            _closeSurface()
        return status
    }

    // A window's app id names its desktop entry far more often than an icon.
    function iconForAppId(appId) {
        var key = String(appId || "")
        if (key === "")
            return ""
        if (_iconCache[key] !== undefined)
            return _iconCache[key]
        var entry = DesktopEntries.heuristicLookup(key)
        var icon = entry && entry.icon ? String(entry.icon) : key
        _iconCache[key] = icon
        return icon
    }

    function _request(payload) {
        var source = payload
        if (typeof payload === "string") {
            try {
                source = payload === "" ? {} : JSON.parse(payload)
            } catch (error) {
                source = {}
            }
        }
        if (!source || typeof source !== "object" || Array.isArray(source))
            source = {}
        return {
            mode: Query.normalizeMode(source.mode),
            query: typeof source.query === "string" ? source.query : ""
        }
    }

    function _absolute(value) {
        var path = String(value || "")
        return path.charAt(0) === "/" ? path : ""
    }

    function _report(what, status) {
        var result = String(status)
        if (result !== "ok" && result !== "started" && context && context.logger)
            context.logger.warn(what + " returned " + result)
        return result
    }

    function _succeeded(intent, status) {
        return status === "ok" || (intent.type === "profile.activate" && status === "started")
    }

    function _focusedWindowId() {
        var windows = context && context.compositor ? context.compositor.windows || [] : []
        for (var index = 0; index < windows.length; index++) {
            if (windows[index] && windows[index].is_focused === true)
                return windows[index].id === undefined ? null : windows[index].id
        }
        return null
    }

    function _lastFocusedWindowId() {
        var windowId = context && context.compositor ? context.compositor.lastFocusedWindowId : null
        return windowId !== undefined && windowId !== null && _windowExists(windowId) ? windowId : null
    }

    function _windowExists(windowId) {
        var windows = context && context.compositor ? context.compositor.windows || [] : []
        for (var index = 0; index < windows.length; index++) {
            if (windows[index] && String(windows[index].id) === String(windowId))
                return true
        }
        return false
    }

    function _refuse(intent, row, status) {
        actionError = _failureMessage(intent, String(row.text || ""), status)
    }

    function _failureMessage(intent, subject, status) {
        var attempt
        switch (intent.type) {
        case "window.focus": attempt = "Couldn't focus " + subject; break
        case "session": attempt = "Couldn't " + subject.toLowerCase(); break
        case "profile.activate": attempt = "Couldn't switch to " + subject; break
        case "text.copy": attempt = "Couldn't copy to the clipboard"; break
        case "path.reveal": attempt = "Couldn't reveal " + subject; break
        case "clipboard.copy": attempt = "Couldn't copy the clipboard item"; break
        case "clipboard.remove": attempt = "Couldn't delete the clipboard item"; break
        case "clipboard.clear": attempt = "Couldn't clear clipboard history"; break
        default: attempt = "Couldn't open " + subject
        }
        return attempt + ": " + _failureReason(intent.type, status)
    }

    function _failureReason(type, status) {
        var clipboardIntent = type.indexOf("clipboard.") === 0
        switch (status) {
        case "gone":
            return "the window is gone"
        case "unavailable":
            return clipboardIntent ? "clipboard history is unavailable" : "launcher helper unavailable"
        case "unknown":
            if (type === "app.launch")
                return "the application is no longer installed"
            if (type === "profile.activate")
                return "the profile is not available"
            return clipboardIntent ? "the item is gone" : "unknown action"
        case "invalid":
            return type === "url.open" ? "the address was rejected" : "the path was rejected"
        case "busy":
            return "another profile switch is running"
        }
        return "it could not be started"
    }

    function _closeSurface() {
        if (context && context.actions)
            context.actions.surfaceClose(pluginId)
        close()
    }

    function _execute(intent) {
        var actions = context.actions
        switch (intent.type) {
        case "remmina.connect":
            if (remminaPath === "") return "unavailable"
            if (!connections.some(function(item) { return item.path === intent.path })) return "unknown"
            Quickshell.execDetached([remminaPath, "--connect", intent.path])
            return "ok"
        case "app.launch":
            return _report("app launch", actions.appLaunch(intent.desktopId, intent.actionId || ""))
        case "session":
            return _report("session action", actions.sessionAction(intent.action))
        case "profile.activate":
            return _report("profile switch", actions.profileActivate(intent.id))
        case "url.open":
            return _report("open url", actions.openUrl(intent.url))
        case "text.copy":
            return _report("copy", actions.copyText(intent.text))
        case "path.open":
            return _report("open path", actions.openPath(intent.path, "open"))
        case "path.reveal":
            return _report("reveal path", actions.openPath(intent.path, "reveal"))
        case "clipboard.copy":
            return _report("clipboard copy", clipboard ? clipboard.copy(intent.id) : "unavailable")
        case "clipboard.remove":
            return _report("clipboard remove", clipboard ? clipboard.remove(intent.id) : "unavailable")
        case "clipboard.clear":
            return _report("clipboard clear", clipboard ? clipboard.clear() : "unavailable")
        }
        return "none"
    }

    function _rerun() {
        if (!opened)
            return
        var previousKey = _userMoved && selectedRow ? selectedRow.key : ""
        var previousActionId = previousKey !== "" && selectedAction ? selectedAction.id : ""
        var previousIndex = selectedIndex
        var result
        try {
            result = engine.run(query, mode, _env(query, mode))
        } catch (error) {
            if (context && context.logger)
                context.logger.error("launcher query failed: " + error)
            result = { rows: [], providerIds: [], prefix: "", text: "", pending: {} }
        }
        _lastText = result.text
        prefix = result.prefix
        providerIds = result.providerIds
        rows = result.rows
        var next = 0
        if (_userMoved) {
            next = -1
            for (var index = 0; previousKey !== "" && index < rows.length; index++) {
                if (rows[index].key === previousKey) {
                    next = index
                    break
                }
            }
            if (next < 0)
                next = Math.min(previousIndex, rows.length - 1)
        }
        selectedIndex = Math.max(0, next)
        actionIndex = selectedRow && selectedRow.key === previousKey
            ? _actionIndexOf(selectedRow, previousActionId) : 0
        _syncPending(result.pending || {})
    }

    // The armed action follows its id; one that disappeared falls back to
    // the default.
    function _actionIndexOf(row, actionId) {
        var actions = row.actions || []
        for (var index = 0; actionId !== "" && index < actions.length; index++) {
            if (actions[index].id === actionId)
                return index
        }
        return 0
    }

    function _env(input, inputMode) {
        var needed = Query.parse(input, inputMode).providerIds
        if (needed.indexOf("apps") !== -1)
            _ensureApps()
        if (needed.indexOf("windows") !== -1)
            _ensureWindows()
        if (needed.indexOf("profiles") !== -1)
            _ensureProfiles()
        if (needed.indexOf("clipboard") !== -1)
            _ensureClipboard()
        return {
            connections: connections,
            apps: _apps,
            windows: _windows,
            currentWindowId: _currentWindowId,
            profiles: _profiles,
            clipboardItems: _clipboardItems,
            clipboardImagesOnly: clipboardImagesOnly,
            filesResult: filesResult,
            calcResult: calcResult,
            history: history,
            settings: engineSettings,
            now: Date.now(),
            revisions: {
                connections: connectionsRevision,
                apps: _appsRevision,
                windows: _windowsRevision,
                profiles: _profilesRevision,
                clipboardItems: _clipboardRevision
            }
        }
    }

    function _list(values) {
        var result = []
        var count = values && values.length !== undefined ? values.length : 0
        for (var index = 0; index < count; index++)
            result.push(String(values[index]))
        return result
    }

    function _ensureApps() {
        if (!_appsDirty)
            return
        var entries = DesktopEntries.applications.values
        var apps = []
        for (var index = 0; index < entries.length; index++) {
            var entry = entries[index]
            if (!entry || entry.noDisplay)
                continue
            var actions = []
            var desktopActions = entry.actions || []
            for (var a = 0; a < desktopActions.length; a++) {
                var action = desktopActions[a]
                if (action)
                    actions.push({ id: String(action.id), name: String(action.name || ""), icon: String(action.icon || "") })
            }
            apps.push({
                id: String(entry.id),
                name: String(entry.name || ""),
                genericName: String(entry.genericName || ""),
                comment: String(entry.comment || ""),
                keywords: _list(entry.keywords),
                icon: String(entry.icon || ""),
                categories: _list(entry.categories),
                actions: actions,
                runInTerminal: entry.runInTerminal === true
            })
        }
        _apps = apps
        _appsRevision++
        _appsDirty = false
        _iconCache = {}
    }

    function _ensureWindows() {
        var compositor = context ? context.compositor : null
        var revision = compositor ? compositor.revision : 0
        if (revision === _windowsRevision)
            return
        var workspaces = {}
        var sourceWorkspaces = compositor ? compositor.workspaces || [] : []
        for (var w = 0; w < sourceWorkspaces.length; w++) {
            var workspace = sourceWorkspaces[w]
            if (workspace && workspace.id !== undefined)
                workspaces[String(workspace.id)] = workspace
        }
        var windows = []
        var sourceWindows = compositor ? compositor.windows || [] : []
        for (var index = 0; index < sourceWindows.length; index++) {
            var source = sourceWindows[index]
            if (!source)
                continue
            var copy = {}
            for (var key in source)
                copy[key] = source[key]
            var owner = workspaces[String(source.workspace_id)]
            if (owner) {
                copy.workspaceName = owner.name ? String(owner.name)
                    : owner.idx !== undefined ? String(owner.idx) : ""
                copy.outputName = owner.output ? String(owner.output) : ""
            }
            windows.push(copy)
        }
        _windows = windows
        _windowsRevision = revision
    }

    function _ensureProfiles() {
        var profiles = context ? context.profiles : null
        var active = profiles ? String(profiles.active || "") : ""
        var available = profiles && profiles.available ? profiles.available : []
        var key = active + "\u0000" + (profiles ? profiles.revision : 0) + "\u0000" + JSON.stringify(available)
        if (key === _profilesKey)
            return
        _profilesKey = key
        _profiles = { active: active, available: available }
        _profilesRevision++
    }

    function _ensureClipboard() {
        var service = clipboard
        var revision = service ? service.revision : -1
        if (service === _clipboardSource && revision === _clipboardRevision)
            return
        var items = []
        var source = service && service.items ? service.items : []
        for (var index = 0; index < source.length; index++) {
            var item = source[index]
            if (!item)
                continue
            items.push({
                id: String(item.id),
                kind: item.kind === "image" ? "image" : "text",
                preview: String(item.preview || ""),
                mime: String(item.mime || ""),
                bytes: item.bytes,
                createdAt: item.created,
                lastUsed: item.lastUsed,
                path: String(item.path || "")
            })
        }
        _clipboardSource = service
        _clipboardItems = items
        // A replaced service can restart its revision count.
        _clipboardRevision = _clipboardRevision === revision ? revision + 1 : revision
    }

    function _ensureHistory() {
        if (_historyLoaded)
            return
        _historyLoaded = true
        if (historyPath === "")
            return
        var raw = historyFile.text()
        if (raw === "")
            return
        try {
            history = History.create(JSON.parse(raw), Date.now())
        } catch (error) {
            if (context && context.logger)
                context.logger.warn("launcher history was unreadable; starting empty")
        }
    }

    function _flushHistory() {
        if (historyPath !== "" && _historyLoaded)
            historyFile.setText(JSON.stringify(history.toJSON()))
    }

    function _syncPending(pending) {
        if (pending.calc !== undefined)
            _requestCalc(String(pending.calc))
        else
            _cancelCalc()
        if (pending.files !== undefined)
            _requestFiles(String(pending.files))
        else
            _cancelFiles()
    }

    function _requestCalc(text) {
        if (text === _calcWanted)
            return
        _calcWanted = text
        _calcGeneration++
        calcDebounce.restart()
    }

    function _cancelCalc() {
        if (_calcWanted === "" && !calcProcess.running && !calcDebounce.running)
            return
        _calcWanted = ""
        _calcGeneration++
        _calcRestart = false
        calcDebounce.stop()
        calcTimeout.stop()
        if (calcProcess.running)
            calcProcess.running = false
    }

    function _startCalc() {
        if (!opened || _calcWanted === "")
            return
        if (qalcPath === "") {
            _finishCalc(_calcWanted, "", true)
            return
        }
        if (calcProcess.running) {
            _calcRestart = true
            calcProcess.running = false
            return
        }
        _calcRunGeneration = _calcGeneration
        _calcRunText = _calcWanted
        _calcExitCode = -1
        // "--" ends qalc's options, so input such as "-v" stays an expression.
        // ASCII output keeps a copied "-2" pasteable where U+2212 is not.
        calcProcess.command = [qalcPath, "-t", "-u8", "-m", String(qalcTimeoutMs - 500), "--", _calcRunText]
        calcProcess.running = true
        calcTimeout.restart()
    }

    function _onCalcStopped() {
        calcTimeout.stop()
        var generation = _calcRunGeneration
        _calcRunGeneration = -1
        if (generation === _calcGeneration && _calcWanted === _calcRunText && opened) {
            var value = ""
            var lines = String(calcOutput.text || "").split("\n")
            for (var index = 0; index < lines.length && value === ""; index++)
                value = lines[index].trim()
            _finishCalc(_calcRunText, value, _calcExitCode !== 0 || value === "")
        }
        if (_calcRestart) {
            _calcRestart = false
            _startCalc()
        }
    }

    function _finishCalc(text, value, failed) {
        calcResult = { text: text, value: failed ? "" : value, error: failed }
        if (_calcWanted === text)
            _calcWanted = ""
        _rerun()
    }

    function _requestFiles(text) {
        if (text === _filesWanted)
            return
        _filesWanted = text
        _filesGeneration++
        filesDebounce.restart()
    }

    function _cancelFiles() {
        if (_filesWanted === "" && !filesProcess.running && !filesDebounce.running)
            return
        _filesWanted = ""
        _filesGeneration++
        _filesRestart = false
        filesDebounce.stop()
        filesTimeout.stop()
        if (filesProcess.running)
            filesProcess.running = false
    }

    function _startFiles() {
        if (!opened || _filesWanted === "")
            return
        var search = Files.fdQuery(_filesWanted, searchRoot)
        if (fdPath === "" || searchRoot === "" || search === null) {
            _finishFiles(_filesWanted, [])
            return
        }
        if (filesProcess.running) {
            _filesRestart = true
            filesProcess.running = false
            return
        }
        _filesRunGeneration = _filesGeneration
        _filesRunText = _filesWanted
        _filesExitCode = -1
        _filesTimedOut = false
        // Hidden files are skipped and ignore files respected: under a home
        // directory those are caches, build output, and VCS internals.
        // Directory symlinks are followed because home directories link into
        // other volumes, which would also follow Nix `result` links into the
        // store and dependency trees, so those names are excluded.
        // The pattern syntax is documented in model/providers/files.js.
        var command = [fdPath, "--follow", "--max-results", String(fdMaxResults), "--absolute-path",
            "--color", "never", "--exclude", "result", "--exclude", "result-*",
            "--exclude", "node_modules", "--exclude", ".direnv", "--exclude", ".git",
            "--exclude", ".cache", "--print0", search.caseSensitive ? "--case-sensitive" : "--ignore-case"]
        if (search.fullPath)
            command.push("--full-path")
        filesProcess.command = command.concat(["--", search.pattern, searchRoot])
        filesProcess.running = true
        filesTimeout.restart()
    }

    function _onFilesStopped() {
        filesTimeout.stop()
        var generation = _filesRunGeneration
        _filesRunGeneration = -1
        if (generation === _filesGeneration && _filesWanted === _filesRunText && opened) {
            var paths = []
            if (_filesExitCode === 0 || _filesTimedOut) {
                var parts = String(filesOutput.text || "").split("\u0000")
                // A timed-out fd can stop mid-record; only NUL-terminated
                // records are complete paths.
                parts.pop()
                for (var index = 0; index < parts.length; index++) {
                    if (parts[index] !== "")
                        paths.push(parts[index])
                }
            }
            _finishFiles(_filesRunText, paths)
        }
        if (_filesRestart) {
            _filesRestart = false
            _startFiles()
        }
    }

    function _finishFiles(text, paths) {
        filesResult = { text: text, paths: paths }
        if (_filesWanted === text)
            _filesWanted = ""
        _rerun()
    }

    Component.onDestruction: {
        _cancelCalc()
        _cancelFiles()
        if (persistTimer.running) {
            persistTimer.stop()
            _flushHistory()
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root._appsDirty = true
            if (!root.opened)
                return
            // The first scan of a fresh process lands while the menu may
            // already show an empty list; later rescans are debounced.
            if (root._apps.length === 0)
                Qt.callLater(root._rerun)
            else
                appsTimer.restart()
        }
    }

    Connections {
        target: root.opened && root.context ? root.context.compositor : null
        function onRevisionChanged() {
            if (root.providerIds.indexOf("windows") !== -1)
                root._rerun()
        }
    }

    Connections {
        target: root.opened && root.context ? root.context.profiles : null
        function onRevisionChanged() { root._onProfilesChanged() }
        function onActiveChanged() { root._onProfilesChanged() }
        function onAvailableChanged() { root._onProfilesChanged() }
    }

    function _onProfilesChanged() {
        if (providerIds.indexOf("profiles") !== -1)
            Qt.callLater(_rerun)
    }

    Connections {
        target: root.opened && root.clipboardActive ? root.clipboard : null
        function onRevisionChanged() { root._rerun() }
    }

    Process {
        id: connectionsProcess
        command: [root.remminaListPath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.opened) return
                try {
                    var items = JSON.parse(text)
                    root.connections = Array.isArray(items) ? items : []
                    root.connectionsRevision++
                    root._rerun()
                } catch (error) {
                    root.actionError = "Could not read saved Remmina connections"
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.opened)
                root.actionError = "Could not read saved Remmina connections"
        }
    }

    FileView {
        id: historyFile
        path: root.historyPath
        preload: false
        blockLoading: true
        blockAllReads: true
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onSaveFailed: {
            if (root.context && root.context.logger)
                root.context.logger.warn("launcher history could not be written")
        }
    }

    Timer {
        id: persistTimer
        interval: 1000
        repeat: false
        onTriggered: root._flushHistory()
    }

    Timer {
        id: appsTimer
        interval: 750
        repeat: false
        onTriggered: root._rerun()
    }

    Timer {
        id: calcDebounce
        interval: root.qalcDebounceMs
        repeat: false
        onTriggered: root._startCalc()
    }

    Timer {
        id: calcTimeout
        interval: root.qalcTimeoutMs
        repeat: false
        onTriggered: {
            if (calcProcess.running)
                calcProcess.running = false
        }
    }

    Process {
        id: calcProcess
        stdout: StdioCollector { id: calcOutput }
        onExited: function(exitCode) { root._calcExitCode = exitCode }
        onRunningChanged: {
            if (!running)
                root._onCalcStopped()
        }
    }

    Timer {
        id: filesDebounce
        interval: root.fdDebounceMs
        repeat: false
        onTriggered: root._startFiles()
    }

    Timer {
        id: filesTimeout
        interval: root.fdTimeoutMs
        repeat: false
        onTriggered: {
            if (filesProcess.running) {
                root._filesTimedOut = true
                filesProcess.running = false
            }
        }
    }

    Process {
        id: filesProcess
        stdout: StdioCollector { id: filesOutput }
        onExited: function(exitCode) { root._filesExitCode = exitCode }
        onRunningChanged: {
            if (!running)
                root._onFilesStopped()
        }
    }
}
