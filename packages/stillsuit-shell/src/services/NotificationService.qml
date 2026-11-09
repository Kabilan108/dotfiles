// Snapshot replacement and live-reference separation are substantially
// derived from Omarchy Quattro's notification service at commit
// f0020448ca87329199de7cb12f2015ebc4a3e5e7, used under the MIT License.

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
    readonly property int heldCount: held.length
    readonly property string heldBadgeText: !quiet || heldCount === 0 ? "" : heldCount > 9 ? "9+" : String(heldCount)
    readonly property bool quietActive: quiet
    readonly property int mutedSourceCount: {
        void(revision)
        var now = Date.now()
        return Object.keys(mutes).filter(function(key) {
            return Number((mutes[key] || {}).until || 0) > now
        }).length
    }

    property bool ready: false
    property bool popupsVisible: true
    // Newest first. Popups show as toasts; held rows wait for quiet mode or a
    // source mute to end and then replay as toasts.
    property var popups: []
    property var held: []
    property bool quiet: false
    property double quietSince: 0
    property var mutes: ({})
    // Arrivals wait here while the pointer is over a deck, so nothing moves
    // under it.
    property var queuedArrivals: []
    property int revision: 0
    property int stateWrites: 0
    property int sequence: 0
    property var liveRefs: ({})
    property var liveKeysById: ({})
    property bool hydrating: false
    property string activeDeckKey: ""
    property string pendingDeckKey: ""
    property var pausedKeys: ({})
    property double pausedAt: 0

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
        var lists = [popups, queuedArrivals, held]
        for (var listIndex = 0; listIndex < lists.length; listIndex++) {
            var index = indexByKey(lists[listIndex], key)
            if (index >= 0) return lists[listIndex][index]
        }
        return null
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

    function sourceTint(sourceKey) {
        return NotificationPolicy.sourceTint(sourceKey)
    }

    function toastsForOutput(outputId) {
        void(revision)
        if (!popupsVisible) return []
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
        var slack = NotificationSource.isSlack(identified)
            ? NotificationSource.slackMessage(snapshot.summary, snapshot.body) : null
        if (slack) {
            snapshot.context = slack.context
            snapshot.summary = slack.summary
            snapshot.body = slack.body
        }
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

    // The picture a notification carries (an avatar, album art), unless it is
    // only the app's own icon again.
    function imageForSnapshot(snapshot) {
        var row = snapshot || {}
        var image = String(row.image || "")
        if (!image) return ""
        var plain = image.replace(/^file:\/\//, "")
        var icon = String(row.appIcon || "").replace(/^file:\/\//, "")
        if (icon && (plain === icon || image === icon)) return ""
        var resolved = iconForSnapshot(row).replace(/^file:\/\//, "")
        if (resolved && plain === resolved) return ""
        return image
    }

    function progressFor(snapshot) {
        return NotificationModel.progressOf(snapshot)
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
        stateWrites += 1
        stateFile.setText(NotificationModel.serializeState({
            quiet: quiet,
            quietSince: quietSince,
            mutes: mutes,
            popups: popups,
            held: held
        }))
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
        var restored = NotificationModel.parseState(raw, {
            popupRows: policy.popupLimit * policy.deckRowLimit,
            held: policy.heldLimit,
            maxAgeMs: policy.maxAgeMs
        }, now)
        quiet = restored.quiet
        quietSince = restored.quietSince
        mutes = restored.mutes
        held = restored.held.map(function(row) { return enrichSnapshot(row, true) })
        popups = []
        for (var index = restored.popups.length - 1; index >= 0; index--) {
            var snapshot = enrichSnapshot(restored.popups[index], true)
            if (snapshot.deadline > 0 && snapshot.deadline <= now) continue
            var reason = holdReason(snapshot, now)
            if (reason !== "") {
                snapshot.heldReason = reason
                snapshot.deadline = 0
                held = [snapshot].concat(held)
            } else {
                popups.unshift(snapshot)
            }
        }
        held = held.slice(0, policy.heldLimit)
        hydrating = false
        ready = true
        // A mute that expired, or quiet that ended, while the shell was down
        // releases its rows now.
        replayHeld()
        revision += 1
        restartDeadlineTimer()
        restartMuteTimer()
        if (restored.corrupt)
            logWarning("recovered notification state while isolating malformed records")
        persist()
    }

    function announce(snapshot) {
        if (!popupsVisible) return
        var outputs = outputIds()
        var focused = focusedOutputId()
        var targets = outputs.length ? outputs : [focused]
        for (var index = 0; index < targets.length; index++) {
            if (NotificationPolicy.shouldPresentOn(snapshot, targets[index], outputs, focused, policy.avoidOutputs))
                bannerWillPresent(targets[index])
        }
    }

    function insertPopup(snapshot) {
        announce(snapshot)
        var next = popups.filter(function(row) { return row.key !== snapshot.key })
        next.unshift(snapshot)
        popups = next
        enforcePopupLimits()
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    // At most popupLimit sources show, each with at most deckRowLimit rows;
    // the stalest go first.
    function enforcePopupLimits() {
        var decks = NotificationLayout.group(popups)
        var evicted = []
        for (var deckIndex = 0; deckIndex < decks.length; deckIndex++) {
            var rows = decks[deckIndex].rows
            var keep = deckIndex < policy.popupLimit ? policy.deckRowLimit : 0
            for (var rowIndex = keep; rowIndex < rows.length; rowIndex++) evicted.push(rows[rowIndex].key)
        }
        for (var index = 0; index < evicted.length; index++) closeRow(evicted[index], "overflow", true)
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

    function closeLive(ref, expire, reason) {
        if (!ref) return
        try {
            if (expire && typeof ref.expire === "function") ref.expire()
            else if (typeof ref.dismiss === "function") ref.dismiss()
        } catch (error) {
            logWarning("live notification closed before " + reason + " completed")
        }
    }

    function endInteractionIfEmpty() {
        if (activeDeckKey && !popups.some(function(row) { return row.sourceKey === activeDeckKey }))
            endDeckInteraction()
    }

    // Takes a row off screen (or out of the held list) and closes its sender.
    function closeRow(key, reason, expire) {
        var inPopups = removePopupSnapshot(key)
        var heldBefore = held.length
        held = held.filter(function(row) { return row.key !== key })
        var queuedBefore = queuedArrivals.length
        queuedArrivals = queuedArrivals.filter(function(row) { return row.key !== key })
        if (!inPopups && held.length === heldBefore && queuedArrivals.length === queuedBefore)
            return "unknown"
        endInteractionIfEmpty()
        revision += 1
        persist()
        closeLive(releaseLive(key), expire, reason)
        restartDeadlineTimer()
        return "ok"
    }

    function dismiss(key) {
        return closeRow(key, "dismissed", false)
    }

    function dismissAll() {
        var rows = popups.concat(queuedArrivals).concat(held)
        for (var index = 0; index < rows.length; index++)
            closeLive(releaseLive(rows[index].key), false, "clear")
        popups = []
        queuedArrivals = []
        held = []
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

        // A resident notification stays after an action, as the sender asked.
        var resident = false
        try {
            resident = ref.resident === true
        } catch (error) {
        }
        if (!resident) {
            removePopupSnapshot(key)
            endInteractionIfEmpty()
            revision += 1
            persist()
        }
        try {
            action.invoke()
            actionInvoked(key, selected)
        } catch (error) {
            releaseLive(key)
            return "unavailable"
        }
        if (!resident) closeLive(releaseLive(key), false, "action")
        restartDeadlineTimer()
        return "ok"
    }

    function holdReason(snapshot, now) {
        if (quiet) return "quiet"
        var mute = mutes[String((snapshot || {}).sourceKey || "")] || {}
        return Number(mute.until || 0) > Number(now || Date.now()) ? "source-mute" : ""
    }

    // Moves a row into the held list. Held rows keep their live reference so
    // their actions still work when they replay.
    function hold(snapshot, reason) {
        var row = Object.assign({}, snapshot, {
            heldReason: reason,
            quietClass: "silenced-retained",
            deadline: 0
        })
        var next = held.filter(function(existing) { return existing.key !== row.key })
        next.unshift(row)
        var evicted = next.slice(policy.heldLimit)
        held = next.slice(0, policy.heldLimit)
        for (var index = 0; index < evicted.length; index++)
            closeLive(releaseLive(evicted[index].key), true, "held overflow")
    }

    // Holds what is on screen (and waiting behind a hovered deck) that the
    // current quiet state and mutes now block.
    function holdBlockedRows() {
        var now = Date.now()
        var visible = popups.concat(queuedArrivals)
        for (var index = visible.length - 1; index >= 0; index--) {
            var row = visible[index]
            var reason = holdReason(row, now)
            if (reason === "") continue
            var quietClass = NotificationPolicy.quietClass(row, true, settings)
            if (quietClass === "bypass") continue
            removePopupSnapshot(row.key)
            queuedArrivals = queuedArrivals.filter(function(queued) { return queued.key !== row.key })
            if (quietClass === "silenced-ephemeral") closeLive(releaseLive(row.key), true, "quiet")
            else hold(row, reason)
        }
        if (queuedArrivals.length === 0) arrivalSafetyTimer.stop()
        endInteractionIfEmpty()
    }

    // Replays held rows that nothing blocks any more, oldest first so the
    // newest lands on top.
    function replayHeld() {
        var now = Date.now()
        var replay = held.filter(function(row) { return holdReason(row, now) === "" })
        if (replay.length === 0) return 0
        held = held.filter(function(row) { return holdReason(row, now) !== "" })
        for (var index = replay.length - 1; index >= 0; index--) {
            var row = Object.assign({}, replay[index], { heldReason: "", quietClass: "visible" })
            row.deadline = deadlineFor(row, now)
            if (activeDeckKey !== "") queueArrival(row)
            else insertPopup(row)
        }
        revision += 1
        persist()
        restartDeadlineTimer()
        return replay.length
    }

    function setQuiet(on) {
        var enabled = on === true
        if (quiet === enabled) return enabled ? "on" : "off"
        quiet = enabled
        quietSince = enabled ? Date.now() : 0
        if (enabled) holdBlockedRows()
        else replayHeld()
        revision += 1
        persist()
        restartDeadlineTimer()
        return enabled ? "on" : "off"
    }

    function toggleQuiet() {
        return setQuiet(!quiet)
    }

    function muteSource(sourceKey) {
        var key = String(sourceKey || "")
        if (!key) return "unknown"
        var now = Date.now()
        var next = Object.assign({}, mutes)
        next[key] = { until: now + policy.muteMs, startedAt: now }
        mutes = next
        holdBlockedRows()
        revision += 1
        persist()
        restartDeadlineTimer()
        restartMuteTimer()
        return String(next[key].until)
    }

    function unmuteSource(sourceKey) {
        var key = String(sourceKey || "")
        if (!mutes[key]) return "inactive"
        var next = Object.assign({}, mutes)
        delete next[key]
        mutes = next
        replayHeld()
        revision += 1
        persist()
        restartMuteTimer()
        return "ok"
    }

    function pruneMutes() {
        var next = NotificationModel.validMutes(mutes, Date.now())
        if (JSON.stringify(next) !== JSON.stringify(mutes)) {
            mutes = next
            replayHeld()
            revision += 1
            persist()
        }
        restartMuteTimer()
    }

    function restartMuteTimer() {
        var keys = Object.keys(mutes)
        var earliest = 0
        var now = Date.now()
        for (var index = 0; index < keys.length; index++) {
            var until = Number((mutes[keys[index]] || {}).until || 0)
            if (until > now && (earliest === 0 || until < earliest)) earliest = until
        }
        muteTimer.stop()
        if (earliest > 0) {
            muteTimer.interval = Math.max(1, earliest - now)
            muteTimer.start()
        }
    }

    function pruneAt(now) {
        var reference = Number(now)
        var previous = popups.concat(held)
        popups = NotificationModel.pruneSnapshots(popups, reference, policy.maxAgeMs, popups.length || 1)
        held = NotificationModel.pruneSnapshots(held, reference, policy.maxAgeMs, policy.heldLimit)
        var removed = NotificationModel.keysRemoved(previous, popups.concat(held))
        for (var index = 0; index < removed.length; index++)
            closeLive(releaseLive(removed[index]), true, "age cleanup")
        if (removed.length > 0) {
            endInteractionIfEmpty()
            revision += 1
            persist()
            restartDeadlineTimer()
        }
        return removed.length
    }

    function connectUpdates(notification, key) {
        var signals = [
            "summaryChanged", "bodyChanged", "appNameChanged", "appIconChanged",
            "imageChanged", "urgencyChanged", "expireTimeoutChanged", "hintsChanged",
            "actionsChanged", "residentChanged"
        ]
        function refresh() { root.refreshReplacement(notification, key) }
        for (var index = 0; index < signals.length; index++) {
            var signal = notification[signals[index]]
            if (signal && typeof signal.connect === "function") signal.connect(refresh)
        }
    }

    function replaceIn(rows, key, updated) {
        var index = indexByKey(rows, key)
        if (index < 0) return null
        var next = rows.slice()
        next[index] = updated
        return next
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

        if (indexByKey(popups, key) >= 0) {
            // A replaces_id update begins a fresh display lifetime, even if
            // only body text, an action label, or the timeout changed.
            updated.deadline = deadlineFor(updated, Date.now())
            popups = replaceIn(popups, key, updated)
        } else if (indexByKey(queuedArrivals, key) >= 0) {
            queuedArrivals = replaceIn(queuedArrivals, key, updated)
        } else if (NotificationPolicy.quietClass(updated, true, settings) === "bypass") {
            // A held row that its sender raised to critical breaks through now.
            held = held.filter(function(row) { return row.key !== key })
            updated.heldReason = ""
            updated.quietClass = "bypass"
            updated.deadline = deadlineFor(updated, Date.now())
            if (activeDeckKey !== "") queueArrival(updated)
            else insertPopup(updated)
        } else {
            updated.deadline = 0
            held = replaceIn(held, key, updated)
        }
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    function handleClosed(key, notification) {
        if (!liveRefs[key] || liveRefs[key] !== notification) return
        removePopupSnapshot(key)
        held = held.filter(function(row) { return row.key !== key })
        queuedArrivals = queuedArrivals.filter(function(row) { return row.key !== key })
        endInteractionIfEmpty()
        releaseLive(key)
        revision += 1
        persist()
        restartDeadlineTimer()
    }

    // A stack-tagged arrival takes over the card it continues: same key, same
    // place, fresh lifetime. Its predecessor closes.
    function stackPredecessor(snapshot) {
        var rows = popups.concat(queuedArrivals)
        for (var index = 0; index < rows.length; index++)
            if (NotificationModel.sameStack(rows[index], snapshot)) return rows[index]
        return null
    }

    function handleNotification(notification) {
        notification.tracked = true
        var now = Date.now()
        var snapshot = enrichSnapshot(NotificationModel.snapshotOf(notification, {
            key: nextKey(notification.id),
            timestamp: now,
            outputId: focusedOutputId()
        }))
        var reason = holdReason(snapshot, now)
        snapshot.quietClass = NotificationPolicy.quietClass(snapshot, reason !== "", settings)
        snapshot.deadline = deadlineFor(snapshot, now)

        var predecessor = snapshot.quietClass === "visible" || snapshot.quietClass === "bypass"
            ? stackPredecessor(snapshot) : null
        if (predecessor) {
            snapshot.key = predecessor.key
            snapshot.outputId = predecessor.outputId
            closeLive(releaseLive(predecessor.key), true, "stack replacement")
        }
        var key = snapshot.key
        liveRefs[key] = notification
        liveKeysById[notification.id] = key
        notification.closed.connect(function() { root.handleClosed(key, notification) })
        connectUpdates(notification, key)

        if (snapshot.quietClass === "silenced-ephemeral") {
            releaseLive(key)
            notification.tracked = false
            return
        }
        if (snapshot.quietClass === "silenced-retained") {
            hold(snapshot, reason)
            revision += 1
            persist()
            return
        }
        if (predecessor) {
            if (indexByKey(popups, key) >= 0) popups = replaceIn(popups, key, snapshot)
            else queuedArrivals = replaceIn(queuedArrivals, key, snapshot)
            revision += 1
            persist()
            restartDeadlineTimer()
        } else if (activeDeckKey !== "") {
            queueArrival(snapshot)
        } else {
            insertPopup(snapshot)
        }
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
        for (var index = 0; index < due.length; index++) closeRow(due[index], "expired", true)
        restartDeadlineTimer()
    }

    function queueArrival(snapshot) {
        queuedArrivals = queuedArrivals.concat([snapshot])
        revision += 1
        if (!arrivalSafetyTimer.running) arrivalSafetyTimer.start()
    }

    function releaseQueuedArrivals() {
        if (queuedArrivals.length === 0) return 0
        var rows = queuedArrivals.slice()
        queuedArrivals = []
        arrivalSafetyTimer.stop()
        for (var index = 0; index < rows.length; index++) {
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
        var now = Date.now()
        var paused = pausedAt
        popups = popups.map(function(row) {
            if (!pausedKeys[row.key] || Number(row.deadline || 0) <= 0) return row
            return Object.assign({}, row, {
                deadline: NotificationPolicy.resumedDeadline(row.deadline, paused, now, settings)
            })
        })
        activeDeckKey = ""
        pendingDeckKey = ""
        pausedKeys = ({})
        pausedAt = 0
        revision += 1
        persist()
        releaseQueuedArrivals()
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
            apiVersion: 2,
            ready: ready,
            serverActive: serverActive,
            counts: {
                popups: popups.length,
                held: held.length,
                queuedArrivals: queuedArrivals.length
            },
            quiet: {
                active: quiet,
                since: quietSince,
                mutedSourceCount: mutedSourceCount
            },
            presentation: {
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
        id: muteTimer
        repeat: false
        onTriggered: root.pruneMutes()
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
        onTriggered: root.releaseQueuedArrivals()
    }

    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: root.ready
        onTriggered: root.pruneAt(Date.now())
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
        function toggleQuiet(): string { return root.toggleQuiet() }
        function setQuiet(value: string): string {
            var normalized = String(value).toLowerCase()
            if (normalized !== "on" && normalized !== "off") return "invalid"
            return root.setQuiet(normalized === "on")
        }
    }

    Component.onCompleted: stateFile.reload()
}
