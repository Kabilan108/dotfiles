import QtQuick
import Quickshell
import Quickshell.Io
import "ClipboardModel.js" as ClipboardModel

// Clipboard history. One supervised `wl-paste --watch` runs the Nix-provided
// collector per selection change; this service is the only writer of
// history.v1.json. Construction never fails on runtime problems: the launcher
// depends on this service, so problems surface through `status` and `error`.
//
// Blobs of entries this service drops are deleted explicitly through the
// collector's `rm`. A commit that drops entries is written synchronously and
// read back before any `rm` starts, so a crash can never leave history
// entries whose blobs are gone. Each removal batch stays in history.v1.json
// (`pendingRemovals`) until its `rm` exits successfully, so a failed run is
// retried and a shutdown or crash mid-run is finished at the next start. The
// grace-based `gc` sweep only collects crash leftovers.
//
// With a `model` (the workbench's fixture input) the service runs no helpers
// and touches no files: items come from the model and actions go to it.
Scope {
    id: root

    required property var context
    property var model: null

    readonly property string apiVersion: "1"
    // Newest first, expired entries omitted. Each item:
    // { id, kind: "text"|"image", mime, bytes, preview, created, lastUsed, path }.
    property var items: []
    property int revision: 0
    property string status: "degraded"
    property string error: ""

    readonly property var values: context && context.settings && context.settings.values
        ? context.settings.values : ({})
    readonly property var options: ClipboardModel.options(values)
    readonly property string collectorPath: String(values.collectorPath || "")
    readonly property string wlPastePath: String(values.wlPastePath || "")
    readonly property string wlCopyPath: String(values.wlCopyPath || "")
    readonly property string niriPath: String(values.niriPath || "")
    readonly property string stateRoot: context && context.settings && context.settings.paths
        ? String(context.settings.paths.stateRoot || "") : ""
    readonly property string stateDir: stateRoot.charAt(0) === "/" ? stateRoot + "/clipboard" : ""
    readonly property string blobDir: stateDir !== "" ? stateDir + "/blobs" : ""
    readonly property string historyPath: stateDir !== "" ? stateDir + "/history.v1.json" : ""

    property var _state: ClipboardModel.emptyState()
    property bool _ready: false
    property bool _failed: false
    property bool _shuttingDown: false
    property bool _modelDriven: false
    property bool _initExited: false
    property string _initError: ""
    property int _backoffMs: 1000
    property real _watcherStartedAt: 0
    property int _watcherExitCode: -1
    property bool _gcPending: false
    // A gc asked for while dropped entries may still be listed on disk; it
    // runs once a write without them has been read back.
    property bool _gcAwaitingPersist: false
    property real _expiryWakeAt: 0
    property bool _gcNextIsFollowUp: false
    property real _gcLastFollowUpAt: 0
    // { shas, before } batches for `rm`, oldest first; the running one is
    // _activeRemoval until its process exits. None starts until the history
    // holding the queued batches has been read back from disk.
    property var _removals: []
    property bool _removalsPersisted: true
    // Blob shas of the last history read back from disk; gc keeps them too.
    property var _durableShas: []
    property var _activeRemoval: null
    property int _removalExitCode: -1
    property int _removalBackoffMs: 5000
    property int _saveBackoffMs: 1000
    property bool _saveFailed: false
    // FileView keeps the text of a failed save as if it were on disk, and
    // skips a later save of the same text.
    property bool _historyCacheStale: false
    property var _pendingCopy: null
    property var _activeCopy: null
    property int _copyExitCode: -1

    function copy(id) {
        if (_modelDriven)
            return _modelCall("copy", id)
        if (!_ready)
            return "unavailable"
        var now = Date.now()
        var entry = ClipboardModel.find(_state, id)
        if (!entry)
            return "unknown"
        if (ClipboardModel.isExpired(entry, now, options)) {
            _pruneNow(now)
            return "unknown"
        }
        _pendingCopy = { id: entry.id, sha: entry.sha, mime: entry.mime, requestedAt: now }
        _runCopy()
        return "ok"
    }

    function remove(id) {
        if (_modelDriven)
            return _modelCall("remove", id)
        if (!_ready)
            return "unavailable"
        var result = ClipboardModel.remove(_state, String(id || ""))
        if (!result.changed)
            return "unknown"
        _commit(result.state, result.removed)
        return "ok"
    }

    function clear() {
        if (_modelDriven)
            return _modelCall("clear")
        if (!_ready)
            return "unavailable"
        var result = ClipboardModel.clearAll(_state)
        _commit(result.state, result.removed)
        return "ok"
    }

    // Once a model has been supplied the service stays model-driven, even if
    // the model is later withdrawn: the workbench never runs the collector.
    function _useModel() {
        if (!_modelDriven) {
            _modelDriven = true
            _stopHelpers()
        }
        _syncModel()
    }

    function _syncModel() {
        items = ClipboardModel.modelItems(model ? model.items : [])
        error = ""
        status = "ok"
        revision++
    }

    function _modelCall(name, id) {
        if (!model || typeof model[name] !== "function")
            return "unavailable"
        var result = model[name](id)
        return result === undefined ? "ok" : String(result)
    }

    // Unfinished removals stay in the history for the next start.
    function _stopHelpers() {
        _flushNow()
        _shuttingDown = true
        _ready = false
        persistTimer.stop()
        saveRetryTimer.stop()
        restartTimer.stop()
        expiryTimer.stop()
        gcTimer.stop()
        removalRetryTimer.stop()
        initProcess.running = false
        watcher.running = false
        copyProcess.running = false
        rmProcess.running = false
        gcProcess.running = false
    }

    function _configProblem() {
        if (stateDir === "")
            return "clipboard state root is not an absolute path"
        var paths = { collectorPath: collectorPath, wlPastePath: wlPastePath, wlCopyPath: wlCopyPath }
        for (var key in paths) {
            if (paths[key].charAt(0) !== "/")
                return "clipboard setting " + key + " must be an absolute path"
        }
        if (niriPath !== "" && niriPath.charAt(0) !== "/")
            return "clipboard setting niriPath must be an absolute path"
        return ""
    }

    function _fail(message) {
        _failed = true
        error = String(message)
        status = "error"
        revision++
        if (context && context.logger)
            context.logger.error(error)
    }

    function _start() {
        var problem = _configProblem()
        if (problem !== "") {
            _fail(problem)
            return
        }
        initProcess.command = [collectorPath, "init", "--state-dir", stateDir]
        initProcess.running = true
    }

    function _onInitLine(line) {
        try {
            var reply = JSON.parse(String(line || ""))
            if (reply && reply.ok === false)
                _initError = String(reply.error || "")
        } catch (parseError) {
            _initError = "clipboard collector returned invalid data"
        }
    }

    function _onInitStopped() {
        if (_shuttingDown || _failed || _ready)
            return
        if (!_initExited) {
            _fail("clipboard collector could not be started")
            return
        }
        if (_initError !== "") {
            _fail(_initError)
            return
        }
        historyFile.path = historyPath
    }

    function _hydrate(raw) {
        if (_ready || _failed || _shuttingDown)
            return
        var now = Date.now()
        var parsed = ClipboardModel.parseHistory(raw, now, options)
        _state = { entries: parsed.entries, lastRecorded: null }
        _removals = parsed.pendingRemovals
        _removalsPersisted = true
        _durableShas = ClipboardModel.shas(parsed.entries).concat(parsed.removed)
        _ready = true
        if (parsed.corrupt && context && context.logger)
            context.logger.warn("clipboard history was unreadable; kept "
                + parsed.entries.length + " valid entries")
        if (parsed.removed.length > 0) {
            _queueRemoval(parsed.removed)
            _persistRemovals()
        } else if (parsed.dirty) {
            persistTimer.restart()
        }
        _runRemoval()
        _publish()
        _rearm()
        _scheduleGc()
        _startWatcher()
    }

    function _watchCommand() {
        var command = [collectorPath, "watch", "--state-dir", stateDir,
            "--collector", collectorPath, "--wl-paste", wlPastePath,
            "--max-text-bytes", String(options.maxTextBytes),
            "--max-image-bytes", String(options.maxImageBytes),
            "--unattributed-firefox=" + options.unattributedFirefox,
            "--gecko-app-ids=" + options.geckoAppIds,
            "--focus-settle-ms=" + options.focusSettleMs,
            "--owner-pid", String(Quickshell.processId)]
        if (niriPath !== "")
            command.push("--niri=" + niriPath)
        for (var index = 0; index < options.secretSourcePrefixes.length; index++)
            command.push("--secret-source-prefix=" + options.secretSourcePrefixes[index])
        return command
    }

    function _startWatcher() {
        if (_shuttingDown || _failed)
            return
        watcher.command = _watchCommand()
        watcher.running = true
    }

    function _onWatcherStarted() {
        _watcherStartedAt = Date.now()
        if (status !== "ok" || error !== "") {
            error = ""
            status = "ok"
            revision++
        }
    }

    function _onWatcherStopped() {
        if (_shuttingDown || _failed || !_ready)
            return
        if (_watcherStartedAt > 0 && Date.now() - _watcherStartedAt > 60000)
            _backoffMs = 1000
        _watcherStartedAt = 0
        error = (_watcherExitCode >= 0
            ? "clipboard watcher exited with status " + _watcherExitCode
            : "clipboard watcher could not be started")
            + "; retrying in " + Math.round(_backoffMs / 1000) + " s"
        status = "degraded"
        revision++
        if (context && context.logger)
            context.logger.warn(error)
        restartTimer.interval = _backoffMs
        restartTimer.restart()
        _backoffMs = Math.min(_backoffMs * 2, 60000)
        _watcherExitCode = -1
        // A collection the watcher's group was killed in can leave temp files.
        _scheduleGc()
    }

    function _onEventLine(line) {
        if (!_ready)
            return
        var event = ClipboardModel.parseEvent(line)
        if (!event) {
            if (context && context.logger)
                context.logger.warn("clipboard collector sent an invalid event")
            return
        }
        var result = ClipboardModel.applyEvent(_state, event, Date.now(), options)
        if (result.changed)
            _commit(result.state, result.removed)
        else
            _state = result.state
    }

    function _commit(nextState, removed) {
        _state = nextState
        if (removed && removed.length > 0) {
            _queueRemoval(removed)
            _persistRemovals()
        } else {
            persistTimer.restart()
        }
        _publish()
        _rearm()
        _runRemoval()
    }

    function _pruneNow(now) {
        var pruned = ClipboardModel.prune(_state.entries, now, options)
        if (pruned.removed.length > 0)
            _commit({ entries: pruned.entries, lastRecorded: _state.lastRecorded }, pruned.removed)
    }

    function _publish() {
        items = ClipboardModel.publicItems(_state.entries, Date.now(), options, blobDir)
        revision++
    }

    // Commits only ever pull the TTL wake earlier; restarting it on each one
    // would starve it while copies keep arriving.
    function _rearm() {
        var now = Date.now()
        var expiresAt = ClipboardModel.nextExpiryAt(_state.entries, options)
        if (expiresAt === 0) {
            expiryTimer.stop()
            return
        }
        var delay = ClipboardModel.timerDelay(expiresAt, now, Math.random())
        if (!expiryTimer.running || now + delay < _expiryWakeAt) {
            _expiryWakeAt = now + delay
            expiryTimer.interval = delay
            expiryTimer.restart()
        }
    }

    function _onExpiryTimer() {
        var pruned = ClipboardModel.prune(_state.entries, Date.now(), options)
        if (pruned.removed.length > 0) {
            _commit({ entries: pruned.entries, lastRecorded: _state.lastRecorded }, pruned.removed)
        } else {
            _publish()
            _rearm()
        }
    }

    function _pendingRemovals() {
        return (_activeRemoval ? [_activeRemoval] : []).concat(_removals)
    }

    function _flush() {
        if (_ready)
            historyFile.setText(ClipboardModel.serialize(_state.entries, _pendingRemovals()))
    }

    function _readHistory() {
        historyCheck.path = ""
        historyCheck.path = historyPath
        return historyCheck.text()
    }

    // Writes the current history synchronously and reads it back: Quickshell's
    // FileView reports a failed atomic commit (ENOSPC on flush) as saved.
    function _writeDurably() {
        var entries = _state.entries
        var pending = _pendingRemovals()
        if (_historyCacheStale) {
            historyFile.path = ""
            historyFile.path = historyPath
        }
        _saveFailed = false
        historyFile.blockWrites = true
        historyFile.setText(ClipboardModel.serialize(entries, pending))
        historyFile.blockWrites = false
        var durable = !_saveFailed && ClipboardModel.historyMatches(_readHistory(), entries, pending)
        _historyCacheStale = !durable
        if (durable)
            _durableShas = ClipboardModel.shas(entries)
        return durable
    }

    // Queued removals may only run once the history without their entries,
    // and with their intent, is on disk. A failed write is retried with
    // backoff; until then no `rm` starts.
    function _persistRemovals() {
        if (!_ready || _shuttingDown)
            return
        persistTimer.stop()
        saveRetryTimer.stop()
        if (_writeDurably()) {
            _saveBackoffMs = 1000
            _onRemovalsPersisted()
            return
        }
        if (context && context.logger)
            context.logger.warn("clipboard history could not be written; retrying in "
                + Math.round(_saveBackoffMs / 1000) + " s")
        saveRetryTimer.interval = _saveBackoffMs
        saveRetryTimer.restart()
        _saveBackoffMs = Math.min(_saveBackoffMs * 2, 60000)
    }

    function _onRemovalsPersisted() {
        _removalsPersisted = true
        if (_gcAwaitingPersist && !_shuttingDown) {
            _gcAwaitingPersist = false
            if (!gcTimer.running) {
                gcTimer.interval = 1
                gcTimer.restart()
            }
        }
    }

    function _runCopy() {
        if (copyProcess.running || !_pendingCopy || _shuttingDown)
            return
        _activeCopy = _pendingCopy
        _pendingCopy = null
        _copyExitCode = -1
        copyProcess.command = [collectorPath, "copy", "--state-dir", stateDir,
            "--sha", _activeCopy.sha, "--mime", _activeCopy.mime, "--wl-copy", wlCopyPath]
        copyProcess.running = true
    }

    // A blob that is gone (a recapture raced a removal, or it was deleted
    // by hand) takes its entry with it, unless the content was captured again
    // since the copy was asked for.
    function _onCopyStopped() {
        var copied = _activeCopy
        _activeCopy = null
        var entry = copied && !_shuttingDown ? ClipboardModel.find(_state, copied.id) : null
        if (entry && entry.sha === copied.sha) {
            if (_copyExitCode === 0) {
                var touched = ClipboardModel.touch(_state, copied.id, Date.now())
                _commit(touched.state, [])
            } else if (_copyExitCode === ClipboardModel.COPY_BLOB_GONE && entry.captured < copied.requestedAt) {
                if (context && context.logger)
                    context.logger.warn("clipboard item's stored copy is gone; dropped it from history")
                var removed = ClipboardModel.remove(_state, copied.id)
                _commit(removed.state, removed.removed)
            }
        }
        _runCopy()
    }

    // Callers persist the history afterwards; _runRemoval waits for that.
    function _queueRemoval(shas) {
        if (!shas || shas.length === 0)
            return
        _removals = ClipboardModel.enqueueRemoval(_removals, shas, Date.now())
        _removalsPersisted = false
    }

    // Blob shas a live entry references are never removed, and with
    // --before-ms neither is a blob replaced after the removal was decided:
    // the same content may have been captured again and its event is on the way.
    function _removalCommand(batch) {
        var shas = []
        for (var index = 0; index < batch.shas.length; index++) {
            if (ClipboardModel.find(_state, batch.shas[index]) === null)
                shas.push(batch.shas[index])
        }
        if (shas.length === 0)
            return null
        return [collectorPath, "rm", "--state-dir", stateDir,
            "--before-ms", String(batch.before), "--sha"].concat(shas)
    }

    function _runRemoval() {
        while (_ready && !_shuttingDown && _removalsPersisted && _activeRemoval === null && !rmProcess.running
                && !removalRetryTimer.running && _removals.length > 0) {
            var batch = _removals[0]
            _removals = _removals.slice(1)
            var command = _removalCommand(batch)
            if (command === null) {
                persistTimer.restart()
                continue
            }
            _activeRemoval = batch
            _removalExitCode = -1
            rmProcess.command = command
            rmProcess.running = true
        }
    }

    function _onRemovalStopped() {
        if (_shuttingDown || !_ready)
            return
        var batch = _activeRemoval
        _activeRemoval = null
        if (batch === null)
            return
        if (_removalExitCode === 0) {
            _removalBackoffMs = 5000
            persistTimer.restart()
        } else {
            if (context && context.logger)
                context.logger.warn("clipboard blob removal failed with status " + _removalExitCode
                    + "; retrying in " + Math.round(_removalBackoffMs / 1000) + " s")
            _removals = [batch].concat(_removals)
            removalRetryTimer.interval = _removalBackoffMs
            removalRetryTimer.restart()
            _removalBackoffMs = Math.min(_removalBackoffMs * 2, 600000)
        }
        _runRemoval()
    }

    function _scheduleGc() {
        _gcNextIsFollowUp = false
        gcTimer.interval = 2000
        gcTimer.restart()
    }

    // Until a dropped entry's write is read back, the history on disk may
    // still list it, and its blob must survive a crash. gc waits for that
    // write and keeps what the last durable history listed as well.
    function _runGc() {
        if (!_ready || _shuttingDown)
            return
        if (gcProcess.running) {
            _gcPending = true
            return
        }
        if (!_removalsPersisted) {
            _gcAwaitingPersist = true
            return
        }
        if (_gcNextIsFollowUp)
            _gcLastFollowUpAt = Date.now()
        _gcNextIsFollowUp = false
        gcProcess.command = [collectorPath, "gc", "--state-dir", stateDir,
            "--grace-sec", String(options.gcGraceSec), "--keep"]
            .concat(ClipboardModel.union(ClipboardModel.shas(_state.entries), _durableShas))
        gcProcess.running = true
    }

    // Files a sweep deferred (orphans inside the grace period, staging files
    // younger than 10 minutes) get a follow-up sweep once the first of them is
    // eligible. Follow-ups are at least 10 minutes apart.
    function _onGcReply(line) {
        var reply
        try {
            reply = JSON.parse(String(line || ""))
        } catch (parseError) {
            return
        }
        var now = Date.now()
        var wakeAt = ClipboardModel.gcFollowUpAt(reply, now, _gcLastFollowUpAt, options.gcGraceSec)
        if (wakeAt > 0 && !_gcPending) {
            _gcNextIsFollowUp = true
            gcTimer.interval = Math.round(wakeAt - now)
            gcTimer.restart()
        }
    }

    // Processes cannot outlive this object, and an active `rm` dies with it.
    // The history keeps every unfinished batch for the next start; detached
    // `rm`s also finish them now in case the plugin does not come back. Only
    // batches known to be on disk qualify: the active one always is.
    function _flushRemovalsDetached() {
        var batches = _removalsPersisted ? _pendingRemovals() : (_activeRemoval ? [_activeRemoval] : [])
        for (var index = 0; index < batches.length; index++) {
            var command = _removalCommand(batches[index])
            if (command !== null)
                Quickshell.execDetached(command)
        }
    }

    onModelChanged: {
        if (model)
            _useModel()
        else if (_modelDriven)
            _syncModel()
    }

    Component.onCompleted: {
        try {
            if (model)
                _useModel()
            else
                _start()
        } catch (startError) {
            _fail("clipboard service failed to start: " + startError)
        }
    }

    // Every change restarts persistTimer or writes at once, so the file is
    // current unless the timer runs or a write failed.
    function _flushNow() {
        if (!_ready || (!persistTimer.running && _removalsPersisted && !saveRetryTimer.running))
            return
        persistTimer.stop()
        saveRetryTimer.stop()
        if (_writeDurably())
            _onRemovalsPersisted()
    }

    Component.onDestruction: {
        if (_ready) {
            _flushNow()
            _flushRemovalsDetached()
        }
        _shuttingDown = true
        restartTimer.stop()
        expiryTimer.stop()
        gcTimer.stop()
        removalRetryTimer.stop()
        saveRetryTimer.stop()
        watcher.running = false
    }

    Connections {
        target: root._modelDriven ? root.model : null
        ignoreUnknownSignals: true
        function onItemsChanged() { root._syncModel() }
        function onRevisionChanged() { root._syncModel() }
    }

    Process {
        id: initProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._onInitLine(line) }
        }
        onExited: function(exitCode) {
            root._initExited = true
            if (exitCode !== 0 && root._initError === "")
                root._initError = "clipboard collector init failed with status " + exitCode
        }
        onRunningChanged: {
            if (!running)
                root._onInitStopped()
        }
    }

    FileView {
        id: historyFile
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root._hydrate(text())
        onLoadFailed: root._hydrate("")
        onSaveFailed: {
            root._saveFailed = true
            root._historyCacheStale = true
            if (root.context && root.context.logger)
                root.context.logger.warn("clipboard history could not be written")
        }
    }

    FileView {
        id: historyCheck
        blockAllReads: true
        preload: false
        watchChanges: false
        printErrors: false
    }

    Process {
        id: watcher
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._onEventLine(line) }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                if (root.context && root.context.logger)
                    root.context.logger.warn("clipboard watcher: " + String(line).slice(0, 200))
            }
        }
        onStarted: root._onWatcherStarted()
        onExited: function(exitCode) { root._watcherExitCode = exitCode }
        onRunningChanged: {
            if (!running)
                root._onWatcherStopped()
        }
    }

    Process {
        id: copyProcess
        onExited: function(exitCode) {
            root._copyExitCode = exitCode
            if (exitCode !== 0 && root.context && root.context.logger)
                root.context.logger.warn("clipboard copy failed with status " + exitCode)
        }
        onRunningChanged: {
            if (!running)
                root._onCopyStopped()
        }
    }

    Process {
        id: rmProcess
        onExited: function(exitCode) { root._removalExitCode = exitCode }
        onRunningChanged: {
            if (!running)
                root._onRemovalStopped()
        }
    }

    Process {
        id: gcProcess
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) { root._onGcReply(line) }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.context && root.context.logger)
                root.context.logger.warn("clipboard blob cleanup failed with status " + exitCode)
            if (root._gcPending && !root._shuttingDown) {
                root._gcPending = false
                root._scheduleGc()
            }
        }
    }

    Timer {
        id: persistTimer
        interval: 250
        repeat: false
        onTriggered: root._flush()
    }

    Timer {
        id: saveRetryTimer
        repeat: false
        onTriggered: {
            root._persistRemovals()
            root._runRemoval()
        }
    }

    Timer {
        id: gcTimer
        interval: 2000
        repeat: false
        onTriggered: root._runGc()
    }

    Timer {
        id: expiryTimer
        repeat: false
        onTriggered: root._onExpiryTimer()
    }

    Timer {
        id: removalRetryTimer
        repeat: false
        onTriggered: root._runRemoval()
    }

    Timer {
        id: restartTimer
        repeat: false
        onTriggered: root._startWatcher()
    }
}
