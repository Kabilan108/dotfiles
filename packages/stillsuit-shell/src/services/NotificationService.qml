// Snapshot replacement, live-reference separation, and archive-before-expire
// behavior are substantially derived from Omarchy Quattro's notification
// service at commit f0020448ca87329199de7cb12f2015ebc4a3e5e7, used under
// the MIT License.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "NotificationModel.js" as NotificationModel
import "NotificationPolicy.js" as NotificationPolicy

Scope {
    id: root

    required property var context

    readonly property var settings: context && context.settings ? context.settings.values || ({}) : ({})
    readonly property var policy: NotificationPolicy.notificationsPolicy(settings)
    readonly property bool ownsBus: !(settings && settings.shadowMode === true)
        && !(settings && settings.claimNotificationBus === false)
    readonly property string statePath: context.settings.paths.stateRoot + "/notifications-v1.json"
    readonly property bool serverActive: serverLoader.item !== null
    readonly property int trackedCount: NotificationModel.centerRows(popups, history, policy.historyLimit).length

    property bool ready: false
    property bool doNotDisturb: false
    property bool popupsVisible: true
    property string centerOutputId: ""
    property var popups: []
    property var history: []
    property int revision: 0
    property int sequence: 0
    property var liveRefs: ({})
    property var liveKeysById: ({})
    property bool hydrating: false

    signal archived(string key, string reason)
    signal actionInvoked(string key, string identifier)

    function logWarning(message) {
        if (context && context.logger && typeof context.logger.warn === "function")
            context.logger.warn(message)
        else
            console.warn("stillsuit notifications:", message)
    }

    function focusedOutputId() {
        return context && context.compositor ? String(context.compositor.focusedOutputId || "") : ""
    }

    function outputIds() {
        var outputs = context && context.compositor && Array.isArray(context.compositor.outputs)
            ? context.compositor.outputs : []
        var ids = []
        for (var index = 0; index < outputs.length; index++) {
            var output = outputs[index] || {}
            ids.push(String(output.id || output.name || ""))
        }
        return ids.filter(function(id) { return id !== "" })
    }

    function nextKey(notificationId) {
        sequence += 1
        return String(Date.now()) + "-" + String(notificationId) + "-" + String(sequence)
    }

    function indexByKey(rows, key) {
        for (var index = 0; index < rows.length; index++)
            if (rows[index] && rows[index].key === key) return index
        return -1
    }

    function snapshotByKey(key) {
        var popupIndex = indexByKey(popups, key)
        if (popupIndex >= 0) return popups[popupIndex]
        var historyIndex = indexByKey(history, key)
        return historyIndex >= 0 ? history[historyIndex] : null
    }

    function centerRows() {
        void(revision)
        return NotificationModel.centerRows(popups, history, policy.historyLimit)
    }

    function toastsForOutput(outputId) {
        void(revision)
        if (!popupsVisible) return []
        var outputs = outputIds()
        var focused = focusedOutputId()
        return popups.filter(function(snapshot) {
            return NotificationPolicy.shouldPresentOn(snapshot, outputId, outputs, focused)
        })
    }

    function deadlineFor(snapshot, now) {
        var duration = NotificationPolicy.durationFor(snapshot, settings)
        return duration > 0 ? now + duration : 0
    }

    function persist() {
        if (hydrating) return
        persistTimer.restart()
    }

    function flushState() {
        stateFile.setText(JSON.stringify({
            schemaVersion: 1,
            dnd: doNotDisturb,
            popups: popups,
            history: history
        }, null, 2) + "\n")
    }

    function flushStateSynchronously() {
        stateFile.waitForJob()
        var previousBlockWrites = stateFile.blockWrites
        stateFile.blockWrites = true
        flushState()
        stateFile.blockWrites = previousBlockWrites
    }

    function hydrate(raw) {
        hydrating = true
        var restored = NotificationModel.parseState(raw, policy.popupLimit, policy.historyLimit)
        doNotDisturb = restored.dnd
        history = restored.history
        popups = []
        var now = Date.now()
        for (var index = restored.popups.length - 1; index >= 0; index--) {
            var snapshot = restored.popups[index]
            if (snapshot.deadline > 0 && snapshot.deadline <= now) {
                snapshot.closeReason = "expired-during-restart"
                history = NotificationModel.boundedHistory(history, snapshot, policy.historyLimit)
            } else {
                popups.unshift(snapshot)
            }
        }
        hydrating = false
        ready = true
        revision += 1
        restartDeadlineTimer()
        if (restored.corrupt) {
            logWarning("recovered notification state while isolating malformed records")
            persist()
        }
    }

    function insertPopup(snapshot) {
        var next = popups.filter(function(row) { return row.key !== snapshot.key })
        next.unshift(snapshot)
        popups = next
        while (popups.length > policy.popupLimit) {
            var overflow = popups[popups.length - 1]
            archiveAndClose(overflow.key, "overflow", true)
        }
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    function archiveSnapshot(snapshot, reason) {
        if (!snapshot) return
        var archivedSnapshot = Object.assign({}, snapshot, { closeReason: reason, deadline: 0 })
        var previousHistory = history
        history = NotificationModel.boundedHistory(previousHistory, archivedSnapshot, policy.historyLimit)
        closeEvictedLive(NotificationModel.historyKeysRemoved(previousHistory, history))
        archived(snapshot.key, reason)
    }

    function removePopupSnapshot(key) {
        var next = popups.filter(function(row) { return row.key !== key })
        if (next.length === popups.length) return false
        popups = next
        return true
    }

    function releaseLive(key) {
        var ref = liveRefs[key]
        if (!ref) return null
        delete liveRefs[key]
        try {
            var id = Number(ref.id)
            if (liveKeysById[id] === key) delete liveKeysById[id]
        } catch (error) {
        }
        return ref
    }

    function closeEvictedLive(keys) {
        for (var index = 0; index < keys.length; index++) {
            var key = keys[index]
            if (indexByKey(popups, key) >= 0 || indexByKey(history, key) >= 0) continue
            var ref = releaseLive(key)
            try {
                if (ref && typeof ref.dismiss === "function") ref.dismiss()
            } catch (error) {
                logWarning("live notification closed before history eviction completed")
            }
        }
    }

    function archiveAndClose(key, reason, expire) {
        var snapshot = snapshotByKey(key)
        if (!snapshot) return "unknown"

        // Ordering matters. Persist the plain snapshot before a server close can
        // destroy its live QObject or sender-scoped image references.
        archiveSnapshot(snapshot, reason)
        removePopupSnapshot(key)
        revision += 1
        flushState()

        var ref = releaseLive(key)
        if (ref) {
            try {
                if (expire && typeof ref.expire === "function") ref.expire()
                else if (typeof ref.dismiss === "function") ref.dismiss()
            } catch (error) {
                logWarning("live notification closed before " + reason + " completed")
            }
        }
        restartDeadlineTimer()
        return "ok"
    }

    function dismiss(key) {
        return archiveAndClose(key, "dismissed", false)
    }

    function invokeAction(key, identifier) {
        var ref = liveRefs[key]
        if (!ref) return "unavailable"
        var selected = String(identifier || "default")
        var action = null
        try {
            for (var index = 0; index < ref.actions.length; index++) {
                if (ref.actions[index] && String(ref.actions[index].identifier) === selected) {
                    action = ref.actions[index]
                    break
                }
            }
        } catch (error) {
            return "unavailable"
        }
        if (!action || typeof action.invoke !== "function") return "unknown-action"

        var snapshot = snapshotByKey(key)
        archiveSnapshot(snapshot, "action:" + selected)
        removePopupSnapshot(key)
        revision += 1
        flushState()
        try {
            action.invoke()
            actionInvoked(key, selected)
        } catch (error) {
            releaseLive(key)
            return "unavailable"
        }
        var dismissedRef = releaseLive(key)
        try {
            if (dismissedRef && typeof dismissedRef.dismiss === "function") dismissedRef.dismiss()
        } catch (error) {
        }
        restartDeadlineTimer()
        return "ok"
    }

    function dismissAll() {
        var rows = centerRows().slice()
        for (var index = 0; index < rows.length; index++) {
            if (liveRefs[rows[index].key]) archiveAndClose(rows[index].key, "dismissed", false)
        }
        popups = []
        history = []
        revision += 1
        persistTimer.stop()
        flushStateSynchronously()
        restartDeadlineTimer()
        return "ok"
    }

    function openCenter(outputId) {
        centerOutputId = String(outputId || focusedOutputId())
        return "open"
    }

    function closeCenter(outputId) {
        if (!outputId || centerOutputId === String(outputId)) centerOutputId = ""
        return "closed"
    }

    function toggleCenter(outputId) {
        var id = String(outputId || focusedOutputId())
        if (centerOutputId === id) return closeCenter(id)
        return openCenter(id)
    }

    function toggleDnd() {
        doNotDisturb = !doNotDisturb
        return doNotDisturb ? "on" : "off"
    }

    function setDnd(value) {
        doNotDisturb = !!value
        return doNotDisturb ? "on" : "off"
    }

    function connectUpdates(notification, key) {
        var signals = [
            "summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged",
            "imageChanged", "urgencyChanged", "expireTimeoutChanged", "hintsChanged",
            "actionsChanged"
        ]
        function refresh() { root.refreshReplacement(notification, key) }
        for (var index = 0; index < signals.length; index++) {
            var signal = notification[signals[index]]
            if (signal && typeof signal.connect === "function") signal.connect(refresh)
        }
    }

    function refreshReplacement(notification, key) {
        if (liveRefs[key] !== notification) return
        var previous = snapshotByKey(key)
        if (!previous) return
        var updated
        try {
            updated = NotificationModel.replacementSnapshot(notification, previous)
        } catch (error) {
            return
        }
        if (!NotificationModel.snapshotChanged(previous, updated)) return

        var popupIndex = indexByKey(popups, key)
        if (popupIndex >= 0) {
            // A replaces_id update begins a fresh display lifetime, even if
            // only body text, an action label, or the timeout changed.
            updated.deadline = deadlineFor(updated, Date.now())
            var nextPopups = popups.slice()
            nextPopups[popupIndex] = updated
            popups = nextPopups
        } else {
            updated.deadline = 0
            var historyIndex = indexByKey(history, key)
            if (historyIndex < 0) return
            var nextHistory = history.slice()
            nextHistory[historyIndex] = updated
            history = nextHistory
        }
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    function handleClosed(key) {
        if (!liveRefs[key]) return
        var snapshot = snapshotByKey(key)
        if (snapshot && indexByKey(popups, key) >= 0) archiveSnapshot(snapshot, "sender")
        removePopupSnapshot(key)
        releaseLive(key)
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    function handleNotification(notification) {
        notification.tracked = true
        var now = Date.now()
        var key = nextKey(notification.id)
        var snapshot = NotificationModel.snapshotOf(notification, {
            key: key,
            timestamp: now,
            outputId: focusedOutputId()
        })
        snapshot.dndClass = NotificationPolicy.dndClass(snapshot, doNotDisturb, settings)
        snapshot.deadline = deadlineFor(snapshot, now)
        liveRefs[key] = notification
        liveKeysById[notification.id] = key
        notification.closed.connect(function() { root.handleClosed(key) })
        connectUpdates(notification, key)

        if (snapshot.dndClass === "silenced-ephemeral") {
            releaseLive(key)
            notification.tracked = false
            return
        }
        if (snapshot.dndClass === "silenced-retained") {
            archiveSnapshot(snapshot, "dnd")
            revision += 1
            persist()
            return
        }
        insertPopup(snapshot)
        Qt.callLater(function() { root.refreshReplacement(notification, key) })
    }

    function restartDeadlineTimer() {
        var earliest = 0
        var now = Date.now()
        for (var index = 0; index < popups.length; index++) {
            var deadline = Number(popups[index].deadline || 0)
            if (deadline > 0 && (earliest === 0 || deadline < earliest)) earliest = deadline
        }
        deadlineTimer.stop()
        if (earliest > 0) {
            deadlineTimer.interval = Math.max(1, earliest - now)
            deadlineTimer.start()
        }
    }

    function expireDue() {
        var now = Date.now()
        var due = popups.filter(function(snapshot) {
            return Number(snapshot.deadline || 0) > 0 && Number(snapshot.deadline) <= now
        }).map(function(snapshot) { return snapshot.key })
        for (var index = 0; index < due.length; index++) archiveAndClose(due[index], "expired", true)
        restartDeadlineTimer()
    }

    onDoNotDisturbChanged: persist()

    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        watchChanges: false
        printErrors: false
        onLoaded: root.hydrate(text())
        onLoadFailed: root.hydrate("")
    }

    Timer {
        id: persistTimer
        interval: 100
        repeat: false
        onTriggered: root.flushState()
    }

    Timer {
        id: deadlineTimer
        repeat: false
        onTriggered: root.expireDue()
    }

    Loader {
        id: serverLoader
        active: root.ownsBus
        sourceComponent: Component {
            NotificationServer {
                actionsSupported: true
                bodySupported: true
                bodyMarkupSupported: false
                imageSupported: true
                persistenceSupported: true
                onNotification: notification => root.handleNotification(notification)
            }
        }
    }

    Component.onCompleted: stateFile.reload()
}
