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
import "NotificationSource.js" as NotificationSource
import "NotificationLinks.js" as NotificationLinks
import "NotificationLayout.js" as NotificationLayout

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
    readonly property int unreadCount: NotificationModel.unreadCount(popups, history, policy.historyLimit)
    readonly property string unreadBadgeText: unreadCount > 9 ? "9+" : unreadCount > 0 ? String(unreadCount) : ""

    property bool ready: false
    property bool popupsVisible: true
    property string centerOutputId: ""
    property var popups: []
    property var history: []
    property int revision: 0
    property int sequence: 0
    property var liveRefs: ({})
    property var liveKeysById: ({})
    property bool hydrating: false
    property var snoozes: ({})
    property var heldArrivals: []
    property string activeDeckKey: ""
    property string pendingDeckKey: ""
    property var pausedKeys: ({})
    property double pausedAt: 0

    readonly property double globalSnoozeUntil: snoozes["*"] ? Number(snoozes["*"].until || 0) : 0
    readonly property bool quietActive: globalSnoozeUntil > Date.now()
    readonly property int snoozedSourceCount: Object.keys(snoozes).filter(function(key) {
        return key !== "*" && Number((snoozes[key] || {}).until || 0) > Date.now()
    }).length

    signal archived(string key, string reason)
    signal actionInvoked(string key, string identifier)
    signal bannerWillPresent(string outputId)

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
        if (historyIndex >= 0) return history[historyIndex]
        var heldIndex = indexByKey(heldArrivals, key)
        return heldIndex >= 0 ? heldArrivals[heldIndex] : null
    }

    function centerRows() {
        void(revision)
        return NotificationModel.centerRows(popups, history, policy.historyLimit)
    }

    function centerSections() {
        return NotificationLayout.group(centerRows())
    }

    function activeSnoozes() {
        var now = Date.now()
        return Object.keys(snoozes).filter(function(key) {
            return key !== "*" && Number((snoozes[key] || {}).until || 0) > now
        }).map(function(key) {
            var matching = centerRows().find(function(row) { return row.sourceKey === key })
            return {
                key: key,
                label: matching ? matching.sourceLabel : key.replace(/^app:|^web:/, ""),
                until: Number(snoozes[key].until)
            }
        })
    }

    function actionState(key) {
        void(revision)
        var snapshot = snapshotByKey(key)
        if (!snapshot || !Array.isArray(snapshot.actions) || snapshot.actions.length === 0)
            return "none"
        return liveRefs[key] ? "available" : "expired"
    }

    function viewState(snapshot) {
        return NotificationPolicy.viewState(snapshot)
    }

    function toastsForOutput(outputId) {
        void(revision)
        if (!popupsVisible || centerOutputId === String(outputId)) return []
        var outputs = outputIds()
        var focused = focusedOutputId()
        return popups.filter(function(snapshot) {
            return NotificationPolicy.shouldPresentOn(snapshot, outputId, outputs, focused, policy.avoidOutputs)
        })
    }

    function toastDecksForOutput(outputId) {
        return NotificationLayout.group(toastsForOutput(outputId))
    }

    function enrichSnapshot(snapshot, preserveIdentity) {
        var identified = preserveIdentity && snapshot.sourceKey ? {
            key: snapshot.sourceKey,
            label: snapshot.sourceLabel,
            kind: snapshot.sourceKind,
            hostname: snapshot.sourceHostname,
            body: snapshot.body
        } : NotificationSource.identify(snapshot)
        snapshot.sourceKey = identified.key
        snapshot.sourceLabel = identified.label
        snapshot.sourceKind = identified.kind
        snapshot.sourceHostname = identified.hostname
        snapshot.body = identified.body
        snapshot.link = NotificationLinks.primary(snapshot.summary, snapshot.body, snapshot.sourceHostname)
        return snapshot
    }

    function iconForSnapshot(snapshot) {
        var row = snapshot || {}
        var candidates = [row.appIcon, (row.hints || {})["desktop-entry"], row.appName]
        for (var index = 0; index < candidates.length; index++) {
            var candidate = String(candidates[index] || "").replace(/\.desktop$/i, "")
            if (!candidate || candidate.indexOf("image://") === 0) continue
            var resolved = Quickshell.iconPath(candidate, true)
            if (resolved) return resolved
        }
        return ""
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
            schemaVersion: 2,
            snoozes: snoozes,
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
        var now = Date.now()
        var restored = NotificationModel.parseState(raw, policy.popupLimit,
            policy.historyLimit, now, policy.historyMaxAgeMs)
        snoozes = restored.snoozes
        history = restored.history.map(function(row) { return enrichSnapshot(row, true) })
        popups = []
        for (var index = restored.popups.length - 1; index >= 0; index--) {
            var snapshot = enrichSnapshot(restored.popups[index], true)
            if (snapshot.deadline > 0 && snapshot.deadline <= now) {
                snapshot.closeReason = "expired-during-restart"
                history = NotificationModel.boundedHistory(history, snapshot, policy.historyLimit)
            } else if (snoozeReason(snapshot, now) !== "") {
                snapshot.quietClass = "silenced-retained"
                snapshot.heldReason = snoozeReason(snapshot, now)
                snapshot.closeReason = "snoozed-during-restart"
                snapshot.deadline = 0
                history = NotificationModel.boundedHistory(history, snapshot, policy.historyLimit)
            } else {
                popups.unshift(snapshot)
            }
        }
        enforceRetention(now)
        hydrating = false
        ready = true
        revision += 1
        restartDeadlineTimer()
        restartSnoozeTimer()
        if (restored.corrupt) {
            logWarning("recovered notification state while isolating malformed records")
        }
        persist()
    }

    function insertPopup(snapshot) {
        if (popupsVisible) {
            var outputs = outputIds()
            var focused = focusedOutputId()
            var targets = outputs.length ? outputs : [focused]
            for (var index = 0; index < targets.length; index++) {
                if (targets[index] !== centerOutputId
                        && NotificationPolicy.shouldPresentOn(snapshot, targets[index], outputs, focused, policy.avoidOutputs))
                    bannerWillPresent(targets[index])
            }
        }
        var next = popups.filter(function(row) { return row.key !== snapshot.key })
        next.unshift(snapshot)
        popups = next
        while (popups.length > policy.popupLimit) {
            var overflow = popups[popups.length - 1]
            archiveAndClose(overflow.key, "overflow", true)
        }
        enforceRetention(Date.now())
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

    function enforceRetention(now) {
        var previousPopups = popups
        var previousHistory = history
        popups = NotificationModel.pruneSnapshots(previousPopups, now,
            policy.historyMaxAgeMs, policy.popupLimit)
        history = NotificationModel.retainedHistory(popups, previousHistory,
            policy.historyLimit, now, policy.historyMaxAgeMs)
        var removedKeys = NotificationModel.historyKeysRemoved(
            previousPopups.concat(previousHistory), popups.concat(history))
        closeEvictedLive(removedKeys)
        return removedKeys.length
    }

    function pruneHistoryAt(now) {
        var removedCount = enforceRetention(Number(now))
        if (removedCount > 0) {
            revision += 1
            persist()
        }
        return removedCount
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
                logWarning("live notification closed before retention cleanup completed")
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
        if (activeDeckKey && !popups.some(function(row) { return row.sourceKey === activeDeckKey }))
            endDeckInteraction()
        enforceRetention(Date.now())
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

    function deleteHistory(key) {
        if (!snapshotByKey(key)) return "unknown"

        removePopupSnapshot(key)
        history = history.filter(function(row) { return row.key !== key })
        revision += 1
        persistTimer.stop()
        flushStateSynchronously()

        var ref = releaseLive(key)
        try {
            if (ref && typeof ref.dismiss === "function") ref.dismiss()
        } catch (error) {
            logWarning("live notification closed after history deletion")
        }
        restartDeadlineTimer()
        return "ok"
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
        if (activeDeckKey && !popups.some(function(row) { return row.sourceKey === activeDeckKey }))
            endDeckInteraction()
        enforceRetention(Date.now())
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

    function clearSource(sourceKey) {
        var normalized = String(sourceKey || "")
        if (!normalized) return "unknown"

        var rows = centerRows().concat(heldArrivals).filter(function(row) {
            return row.sourceKey === normalized
        })
        if (rows.length === 0) return "unknown"

        for (var index = 0; index < rows.length; index++) {
            var ref = releaseLive(rows[index].key)
            try {
                if (ref && typeof ref.dismiss === "function") ref.dismiss()
            } catch (error) {
                logWarning("live notification closed after source history clear")
            }
        }
        popups = popups.filter(function(row) { return row.sourceKey !== normalized })
        history = history.filter(function(row) { return row.sourceKey !== normalized })
        heldArrivals = heldArrivals.filter(function(row) { return row.sourceKey !== normalized })
        if (activeDeckKey === normalized || pendingDeckKey === normalized) {
            activeDeckKey = ""
            pendingDeckKey = ""
            pausedKeys = ({})
            pausedAt = 0
            hoverIntentTimer.stop()
            interactionExitTimer.stop()
        }
        revision += 1
        persistTimer.stop()
        flushStateSynchronously()
        restartDeadlineTimer()
        return "ok"
    }

    function clearHistory() {
        var rows = centerRows().concat(heldArrivals)
        for (var index = 0; index < rows.length; index++) {
            var ref = releaseLive(rows[index].key)
            try {
                if (ref && typeof ref.dismiss === "function") ref.dismiss()
            } catch (error) {
                logWarning("live notification closed after history clear")
            }
        }
        popups = []
        history = []
        heldArrivals = []
        activeDeckKey = ""
        pendingDeckKey = ""
        pausedKeys = ({})
        pausedAt = 0
        hoverIntentTimer.stop()
        interactionExitTimer.stop()
        arrivalSafetyTimer.stop()
        revision += 1
        persistTimer.stop()
        flushStateSynchronously()
        restartDeadlineTimer()
        return "ok"
    }

    function dismissAll() {
        return clearHistory()
    }

    function markRowsRead(keys, timestamp) {
        var nextPopups = NotificationModel.markRead(popups, keys, timestamp)
        var nextHistory = NotificationModel.markRead(history, keys, timestamp)
        if (nextPopups === popups && nextHistory === history) return false
        popups = nextPopups
        history = nextHistory
        revision += 1
        persist()
        return true
    }

    function openCenter(outputId) {
        pruneHistoryAt(Date.now())
        endDeckInteraction()
        var presentKeys = centerRows().map(function(row) { return row.key })
        centerOutputId = String(outputId || focusedOutputId())
        markRowsRead(presentKeys, Date.now())
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

    function snoozeReason(snapshot, now) {
        var referenceTime = Number(now || Date.now())
        var global = snoozes["*"] || {}
        if (Number(global.until || 0) > referenceTime) return "global-snooze"
        var source = snoozes[String((snapshot || {}).sourceKey || "")] || {}
        return Number(source.until || 0) > referenceTime ? "source-snooze" : ""
    }

    function snoozePresetUntil(preset, now) {
        var referenceTime = Number(now || Date.now())
        if (preset === "30m") return referenceTime + 30 * 60 * 1000
        if (preset === "1h") return referenceTime + 60 * 60 * 1000
        if (preset === "4h") return referenceTime + 4 * 60 * 60 * 1000
        if (preset === "tomorrow") return NotificationModel.tomorrowMorning(referenceTime)
        return 0
    }

    function snooze(key, preset) {
        var normalizedKey = String(key || "*")
        var now = Date.now()
        var until = snoozePresetUntil(String(preset || "1h"), now)
        if (until <= now) return "invalid-preset"
        var next = Object.assign({}, snoozes)
        next[normalizedKey] = { until: until, startedAt: now }
        snoozes = next

        var visibleRows = popups.concat(heldArrivals).filter(function(row) {
            return normalizedKey === "*" || row.sourceKey === normalizedKey
        })
        for (var index = 0; index < visibleRows.length; index++) {
            var snapshot = Object.assign({}, visibleRows[index], {
                quietClass: "silenced-retained",
                heldReason: normalizedKey === "*" ? "global-snooze" : "source-snooze"
            })
            archiveSnapshot(snapshot, snapshot.heldReason)
            removePopupSnapshot(snapshot.key)
        }
        var heldKeys = visibleRows.map(function(row) { return row.key })
        heldArrivals = heldArrivals.filter(function(row) {
            return heldKeys.indexOf(row.key) === -1
        })
        if (heldArrivals.length === 0) arrivalSafetyTimer.stop()
        if (normalizedKey === "*" || activeDeckKey === normalizedKey) endDeckInteraction()
        enforceRetention(Date.now())
        revision += 1
        persist()
        restartDeadlineTimer()
        restartSnoozeTimer()
        return String(until)
    }

    function wake(key) {
        var normalizedKey = String(key || "*")
        if (!snoozes[normalizedKey]) return "inactive"
        var next = Object.assign({}, snoozes)
        delete next[normalizedKey]
        snoozes = next
        revision += 1
        persist()
        restartSnoozeTimer()
        return "ok"
    }

    function wakeEverything() {
        snoozes = ({})
        revision += 1
        persist()
        restartSnoozeTimer()
        return "ok"
    }

    function pruneSnoozes() {
        var next = NotificationModel.validSnoozes(snoozes, Date.now())
        if (JSON.stringify(next) !== JSON.stringify(snoozes)) {
            snoozes = next
            revision += 1
            persist()
        }
        restartSnoozeTimer()
    }

    function restartSnoozeTimer() {
        var keys = Object.keys(snoozes)
        var earliest = 0
        var now = Date.now()
        for (var index = 0; index < keys.length; index++) {
            var until = Number((snoozes[keys[index]] || {}).until || 0)
            if (until > now && (earliest === 0 || until < earliest)) earliest = until
        }
        snoozeTimer.stop()
        if (earliest > 0) {
            snoozeTimer.interval = Math.max(1, earliest - now)
            snoozeTimer.start()
        }
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
            updated = enrichSnapshot(NotificationModel.replacementSnapshot(notification, previous))
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
        } else if (indexByKey(heldArrivals, key) >= 0) {
            updated.deadline = 0
            var nextHeld = heldArrivals.slice()
            nextHeld[indexByKey(heldArrivals, key)] = updated
            heldArrivals = nextHeld
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
        heldArrivals = heldArrivals.filter(function(row) { return row.key !== key })
        if (activeDeckKey && !popups.some(function(row) { return row.sourceKey === activeDeckKey }))
            endDeckInteraction()
        releaseLive(key)
        enforceRetention(Date.now())
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    function handleNotification(notification) {
        notification.tracked = true
        var now = Date.now()
        var key = nextKey(notification.id)
        var snapshot = enrichSnapshot(NotificationModel.snapshotOf(notification, {
            key: key,
            timestamp: now,
            outputId: focusedOutputId()
        }))
        var heldReason = snoozeReason(snapshot, now)
        snapshot.quietClass = NotificationPolicy.quietClass(snapshot, heldReason !== "", settings)
        snapshot.heldReason = snapshot.quietClass.indexOf("silenced-") === 0 ? heldReason : ""
        snapshot.deadline = deadlineFor(snapshot, now)
        liveRefs[key] = notification
        liveKeysById[notification.id] = key
        notification.closed.connect(function() { root.handleClosed(key) })
        connectUpdates(notification, key)

        if (snapshot.quietClass === "silenced-ephemeral") {
            releaseLive(key)
            notification.tracked = false
            return
        }
        if (snapshot.quietClass === "silenced-retained") {
            archiveSnapshot(snapshot, heldReason)
            enforceRetention(now)
            revision += 1
            persist()
            return
        }
        if (activeDeckKey !== "") queueArrival(snapshot)
        else insertPopup(snapshot)
        Qt.callLater(function() { root.refreshReplacement(notification, key) })
    }

    function restartDeadlineTimer() {
        var earliest = 0
        var now = Date.now()
        for (var index = 0; index < popups.length; index++) {
            if (pausedKeys[popups[index].key]) continue
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
            return !pausedKeys[snapshot.key]
                && Number(snapshot.deadline || 0) > 0 && Number(snapshot.deadline) <= now
        }).map(function(snapshot) { return snapshot.key })
        for (var index = 0; index < due.length; index++) archiveAndClose(due[index], "expired", true)
        restartDeadlineTimer()
    }

    function queueArrival(snapshot) {
        heldArrivals = heldArrivals.concat([snapshot])
        revision += 1
        if (!arrivalSafetyTimer.running) arrivalSafetyTimer.start()
    }

    function releaseHeldArrivals() {
        if (heldArrivals.length === 0) return 0
        var rows = heldArrivals.slice()
        heldArrivals = []
        arrivalSafetyTimer.stop()
        for (var index = rows.length - 1; index >= 0; index--) {
            rows[index].deadline = deadlineFor(rows[index], Date.now())
            insertPopup(rows[index])
        }
        return rows.length
    }

    function beginDeckInteraction(key) {
        var normalized = String(key || "")
        if (!normalized) return
        if (activeDeckKey && activeDeckKey !== normalized) endDeckInteraction()
        activeDeckKey = normalized
        pendingDeckKey = ""
        pausedAt = Date.now()
        var next = {}
        for (var index = 0; index < popups.length; index++)
            if (popups[index].sourceKey === normalized) next[popups[index].key] = true
        pausedKeys = next
        restartDeadlineTimer()
    }

    function endDeckInteraction() {
        if (!activeDeckKey) return
        var extension = Math.max(0, Date.now() - pausedAt)
        popups = popups.map(function(row) {
            if (!pausedKeys[row.key] || Number(row.deadline || 0) <= 0) return row
            return Object.assign({}, row, { deadline: Number(row.deadline) + extension })
        })
        activeDeckKey = ""
        pendingDeckKey = ""
        pausedKeys = ({})
        pausedAt = 0
        revision += 1
        persist()
        releaseHeldArrivals()
        restartDeadlineTimer()
    }

    function setDeckHovered(key, hovered) {
        var normalized = String(key || "")
        if (hovered) {
            interactionExitTimer.stop()
            if (activeDeckKey === normalized) return
            pendingDeckKey = normalized
            hoverIntentTimer.restart()
        } else {
            if (pendingDeckKey === normalized) {
                pendingDeckKey = ""
                hoverIntentTimer.stop()
            }
            if (activeDeckKey === normalized) interactionExitTimer.restart()
        }
    }

    function notificationStatus() {
        var decks = NotificationLayout.group(popups).map(function(deck) {
            return {
                key: deck.key,
                count: deck.rows.length,
                outputId: String((deck.rows[0] || {}).outputId || "")
            }
        })
        return JSON.stringify({
            apiVersion: 1,
            ready: ready,
            serverActive: serverActive,
            counts: {
                popups: popups.length,
                history: history.length,
                unread: unreadCount,
                heldArrivals: heldArrivals.length
            },
            quiet: {
                globalUntil: globalSnoozeUntil,
                snoozedSourceCount: snoozedSourceCount
            },
            presentation: {
                centerOutputId: centerOutputId,
                activeDeckKey: activeDeckKey,
                pausedNotificationCount: Object.keys(pausedKeys).length
            },
            decks: decks
        })
    }

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

    Timer {
        id: snoozeTimer
        repeat: false
        onTriggered: root.pruneSnoozes()
    }

    Timer {
        id: hoverIntentTimer
        interval: 150
        repeat: false
        onTriggered: root.beginDeckInteraction(root.pendingDeckKey)
    }

    Timer {
        id: interactionExitTimer
        interval: 120
        repeat: false
        onTriggered: root.endDeckInteraction()
    }

    Timer {
        id: arrivalSafetyTimer
        interval: 30000
        repeat: false
        onTriggered: root.releaseHeldArrivals()
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.ready
        onTriggered: root.pruneHistoryAt(Date.now())
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

    IpcHandler {
        target: "stillsuit-notifications"
        function status(): string { return root.notificationStatus() }
    }

    Component.onCompleted: stateFile.reload()
}
