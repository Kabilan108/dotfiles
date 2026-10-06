import QtQuick
import Quickshell
import Quickshell.Io

// Fixed-shape launch actions behind context.actions. Callers name a desktop
// entry, URL, path, text, or session action; argv always comes from the
// desktop entry index or the Nix-generated launch config, never the caller.
// execDetached reports nothing about the process it starts, so `ok` means
// submitted. The helper reports its own failures as desktop notifications,
// and launches through it return `unavailable` until `helper --check` has
// succeeded once.
QtObject {
    id: root

    property string helperPath: Quickshell.env("STILLSUIT_APP_LAUNCH_HELPER") || ""
    property string configPath: Quickshell.env("STILLSUIT_LAUNCH_CONFIG") || ""
    property var spawn: function(argv) { Quickshell.execDetached(argv) }
    property var findEntry: function(desktopId) { return DesktopEntries.byId(desktopId) }

    readonly property var sessionActions: ["lock", "suspend", "logout", "reboot", "poweroff"]
    readonly property int maxUrlBytes: 8192
    readonly property int maxPathBytes: 4096
    readonly property int maxCopyBytes: 1048576
    property var launchConfig: ({ terminal: [], browser: [], opener: [], session: {} })
    property string configError: ""
    property bool _configLoaded: false
    property var _copyPending: null
    property string _copyInFlight: ""
    // "checking", "ready", or "unavailable".
    property string helperState: "checking"
    property int helperChecks: 0
    property bool _helperCheckPassed: false

    property Process helperCheck: Process {
        onExited: function(exitCode, exitStatus) {
            root._helperCheckPassed = exitCode === 0
        }
        // A helper that cannot start changes running without an exit.
        onRunningChanged: if (!running) root._helperCheckFinished()
    }

    property FileView configFile: FileView {
        path: root.configPath
        preload: false
        blockLoading: true
        blockAllReads: true
        printErrors: false
    }

    property Process copyProcess: Process {
        id: copier
        command: ["wl-copy", "--type", "text/plain;charset=utf-8"]
        // Closing stdin after the write lets wl-copy see end of input.
        onStarted: {
            copier.write(root._copyInFlight)
            copier.stdinEnabled = false
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0)
                console.warn("[stillsuit] wl-copy exited with " + exitCode)
        }
        onRunningChanged: if (!running) root._copyFinished()
    }

    Component.onCompleted: {
        _ensureConfig()
        _checkHelper()
    }

    function appLaunch(desktopId, actionId) {
        if (typeof desktopId !== "string" || desktopId === "" || desktopId.length > 255
                || /[\/\u0000-\u001f]/.test(desktopId))
            return "unknown"
        var action = actionId === undefined || actionId === null ? "" : actionId
        if (typeof action !== "string")
            return "unknown"
        var entry
        try {
            entry = findEntry(desktopId)
        } catch (error) {
            return "error"
        }
        if (!entry)
            return "unknown"
        var source = entry
        if (action !== "") {
            source = null
            var actions = entry.actions || []
            for (var index = 0; index < actions.length; index++) {
                if (actions[index] && actions[index].id === action) {
                    source = actions[index]
                    break
                }
            }
            if (!source)
                return "unknown"
        }
        _ensureConfig()
        var command = _argv(source.command)
        if (command === null || command.length === 0)
            return "error"
        if (entry.runInTerminal === true) {
            if (launchConfig.terminal.length === 0)
                return "error"
            command = launchConfig.terminal.concat(command)
        }
        return _launch(String(entry.id || desktopId), String(entry.workingDirectory || ""), command)
    }

    function openUrl(url) {
        if (typeof url !== "string" || !/^https?:\/\/[^\/?#\s]/i.test(url)
                || /[\s\u0000-\u001f\u007f]/.test(url)
                || _utf8Exceeds(url, maxUrlBytes))
            return "invalid"
        _ensureConfig()
        var prefix = launchConfig.browser
        if (prefix.length === 0)
            return "error"
        return _launch(_basename(prefix[0]), "", prefix.concat([url]))
    }

    function openPath(path, mode) {
        if (typeof path !== "string" || path.charAt(0) !== "/" || path.indexOf("\u0000") !== -1
                || _utf8Exceeds(path, maxPathBytes)
                || (mode !== "open" && mode !== "reveal"))
            return "invalid"
        var target = mode === "reveal" ? _parentDirectory(path) : path
        _ensureConfig()
        var prefix = launchConfig.opener
        if (prefix.length === 0)
            return "error"
        return _launch(_basename(prefix[0]), "", prefix.concat([target]))
    }

    function copyText(text) {
        if (typeof text !== "string" || _utf8Exceeds(text, maxCopyBytes))
            return "error"
        if (copyProcess.running) {
            _copyPending = text
            return "ok"
        }
        _startCopy(text)
        return "ok"
    }

    function sessionAction(name) {
        if (typeof name !== "string" || sessionActions.indexOf(name) === -1)
            return "unknown"
        _ensureConfig()
        var argv = launchConfig.session[name] || []
        if (argv.length === 0)
            return "error"
        return _spawn(argv.slice())
    }

    function _launch(label, workingDirectory, command) {
        if (helperState !== "ready") {
            _checkHelper()
            return "unavailable"
        }
        var argv = [helperPath, "--name", label]
        if (workingDirectory !== "")
            argv.push("--cwd", workingDirectory)
        argv.push("--")
        return _spawn(argv.concat(command))
    }

    function _spawn(argv) {
        try {
            spawn(argv)
            return "ok"
        } catch (error) {
            console.warn("[stillsuit] launch failed: " + error)
            return "error"
        }
    }

    // One check per call: at startup, then again only when a launch finds
    // the helper unavailable and no check is running.
    function _checkHelper() {
        if (helperState === "checking" && helperChecks > 0)
            return
        helperChecks++
        if (helperPath.charAt(0) !== "/") {
            helperState = "unavailable"
            return
        }
        helperState = "checking"
        _helperCheckPassed = false
        helperCheck.command = [helperPath, "--check"]
        helperCheck.running = true
    }

    function _helperCheckFinished() {
        helperState = _helperCheckPassed ? "ready" : "unavailable"
    }

    function _startCopy(text) {
        _copyInFlight = text
        copyProcess.stdinEnabled = true
        copyProcess.running = true
    }

    function _copyFinished() {
        _copyInFlight = ""
        if (_copyPending === null)
            return
        var next = _copyPending
        _copyPending = null
        _startCopy(next)
    }

    // Read once, at completion or at the first action, whichever runs first.
    function _ensureConfig() {
        if (_configLoaded)
            return
        _configLoaded = true
        _loadConfig(configPath === "" ? "" : configFile.text())
    }

    function _loadConfig(text) {
        var parsed = null
        try {
            parsed = text === "" ? null : JSON.parse(text)
        } catch (error) {
            parsed = null
        }
        if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
            configError = configPath === "" ? "launch config is not set" : "cannot read " + configPath
            return
        }
        var session = {}
        var sessionSource = parsed.session && typeof parsed.session === "object" ? parsed.session : {}
        for (var index = 0; index < sessionActions.length; index++)
            session[sessionActions[index]] = _argv(sessionSource[sessionActions[index]]) || []
        launchConfig = {
            terminal: _argv(parsed.terminal) || [],
            browser: _argv(parsed.browser) || [],
            opener: _argv(parsed.opener) || [],
            session: session
        }
        configError = ""
    }

    function _argv(value) {
        if (value === null || value === undefined || typeof value.length !== "number")
            return null
        var result = []
        for (var index = 0; index < value.length; index++) {
            var item = value[index]
            if (typeof item !== "string" || item === "" || item.indexOf("\u0000") !== -1)
                return null
            result.push(item)
        }
        return result
    }

    function _basename(path) {
        var name = String(path)
        return name.substring(name.lastIndexOf("/") + 1)
    }

    function _parentDirectory(path) {
        var trimmed = path.replace(/\/+$/, "")
        var separator = trimmed.lastIndexOf("/")
        return separator <= 0 ? "/" : trimmed.substring(0, separator)
    }

    function _utf8Exceeds(text, limit) {
        if (text.length > limit)
            return true
        if (text.length * 3 <= limit)
            return false
        var bytes = 0
        for (var index = 0; index < text.length; index++) {
            var code = text.charCodeAt(index)
            if (code < 0x80) {
                bytes += 1
            } else if (code < 0x800) {
                bytes += 2
            } else if (code >= 0xd800 && code <= 0xdbff && index + 1 < text.length) {
                bytes += 4
                index++
            } else {
                bytes += 3
            }
            if (bytes > limit)
                return true
        }
        return false
    }
}
