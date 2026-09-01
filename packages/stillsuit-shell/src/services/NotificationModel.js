// Snapshot and replacement behavior is substantially derived from Omarchy
// Quattro's NotificationLogic.js at commit
// f0020448ca87329199de7cb12f2015ebc4a3e5e7, used under the MIT License.

var SNAPSHOT_ROLES = [
    "appName", "appIcon", "summary", "body", "image", "urgency",
    "expireTimeout", "actions", "hints"
]

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function finiteNumber(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function safeHintValue(value, depth) {
    if (depth > 3 || value === undefined || value === null) return null
    if (typeof value === "string" || typeof value === "boolean") return value
    if (typeof value === "number") return isFinite(value) ? value : null
    if (Array.isArray(value)) {
        var array = []
        var limit = Math.min(value.length, 64)
        for (var index = 0; index < limit; index++)
            array.push(safeHintValue(value[index], depth + 1))
        return array
    }
    return safeString(value)
}

function inertHints(hints) {
    var result = {}
    if (!hints) return result

    try {
        for (var key in hints) {
            if (key === "__proto__" || key === "constructor" || key === "prototype") continue
            result[safeString(key)] = safeHintValue(hints[key], 0)
        }
    } catch (error) {
        return result
    }
    return result
}

function actionSnapshots(actions) {
    var result = []
    if (!actions || typeof actions.length !== "number") return result

    for (var index = 0; index < actions.length && index < 32; index++) {
        var action = actions[index]
        if (!action) continue
        result.push({
            identifier: safeString(action.identifier),
            text: safeString(action.text)
        })
    }
    return result
}

function snapshotOf(notification, identity) {
    var source = notification || {}
    var meta = identity || {}
    var originalId = Math.max(0, Math.round(finiteNumber(
        source.id === undefined ? source.originalId : source.id, 0)))
    var timestamp = finiteNumber(meta.timestamp, Date.now())
    var expireTimeout = finiteNumber(source.expireTimeout, 0)
    if (expireTimeout < 0) expireTimeout = 0

    return {
        key: safeString(meta.key || (String(timestamp) + "-" + String(originalId))),
        originalId: originalId,
        appName: safeString(source.appName),
        appIcon: safeString(source.appIcon),
        summary: safeString(source.summary),
        body: safeString(source.body),
        image: safeString(source.image),
        urgency: Math.max(0, Math.min(2, Math.round(finiteNumber(source.urgency, 1)))),
        expireTimeout: Math.round(expireTimeout),
        actions: actionSnapshots(source.actions),
        hints: inertHints(source.hints),
        timestamp: timestamp,
        deadline: finiteNumber(meta.deadline, 0),
        outputId: safeString(meta.outputId),
        dndClass: safeString(meta.dndClass || "visible"),
        closeReason: safeString(meta.closeReason)
    }
}

function replacementSnapshot(notification, previous) {
    var old = previous || {}
    return snapshotOf(notification, {
        key: old.key,
        timestamp: old.timestamp,
        outputId: old.outputId,
        deadline: old.deadline,
        dndClass: old.dndClass,
        closeReason: old.closeReason
    })
}

function snapshotChanged(previous, next) {
    var old = previous || {}
    var updated = next || {}
    for (var index = 0; index < SNAPSHOT_ROLES.length; index++) {
        var role = SNAPSHOT_ROLES[index]
        if (JSON.stringify(old[role]) !== JSON.stringify(updated[role])) return true
    }
    return false
}

function validSnapshot(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null
    if (!safeString(value.key) || !isFinite(Number(value.timestamp))) return null

    return snapshotOf(value, {
        key: value.key,
        timestamp: Number(value.timestamp),
        outputId: value.outputId,
        deadline: value.deadline,
        dndClass: value.dndClass,
        closeReason: value.closeReason
    })
}

function isolateRecords(values, limit) {
    var result = []
    if (!Array.isArray(values)) return result
    for (var index = 0; index < values.length && result.length < limit; index++) {
        var record = validSnapshot(values[index])
        if (record) result.push(record)
    }
    return result
}

function parseState(raw, popupLimit, historyLimit) {
    var result = { dnd: false, popups: [], history: [], corrupt: false }
    var text = safeString(raw).trim()
    if (!text) return result

    try {
        var parsed = JSON.parse(text)
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
            result.corrupt = true
            return result
        }
        result.dnd = typeof parsed.dnd === "boolean" ? parsed.dnd : false
        result.popups = isolateRecords(parsed.popups, popupLimit)
        result.history = isolateRecords(parsed.history, historyLimit)
        result.corrupt = result.popups.length !== (Array.isArray(parsed.popups) ? Math.min(parsed.popups.length, popupLimit) : 0)
            || result.history.length !== (Array.isArray(parsed.history) ? Math.min(parsed.history.length, historyLimit) : 0)
        return result
    } catch (error) {
        result.corrupt = true
        return result
    }
}

function boundedHistory(history, snapshot, limit) {
    var key = safeString((snapshot || {}).key)
    var result = []
    if (snapshot) result.push(snapshot)
    var rows = Array.isArray(history) ? history : []
    for (var index = 0; index < rows.length && result.length < limit; index++) {
        if (safeString(rows[index].key) !== key) result.push(rows[index])
    }
    return result
}

function historyKeysRemoved(previous, next) {
    var retainedKeys = []
    var nextRows = Array.isArray(next) ? next : []
    for (var nextIndex = 0; nextIndex < nextRows.length; nextIndex++) {
        var retainedKey = safeString((nextRows[nextIndex] || {}).key)
        if (retainedKey && retainedKeys.indexOf(retainedKey) === -1)
            retainedKeys.push(retainedKey)
    }

    var removedKeys = []
    var previousRows = Array.isArray(previous) ? previous : []
    for (var previousIndex = 0; previousIndex < previousRows.length; previousIndex++) {
        var previousKey = safeString((previousRows[previousIndex] || {}).key)
        if (previousKey && retainedKeys.indexOf(previousKey) === -1
                && removedKeys.indexOf(previousKey) === -1)
            removedKeys.push(previousKey)
    }
    return removedKeys
}

function centerRows(popups, history, limit) {
    var result = []
    var seen = {}
    var sources = [Array.isArray(popups) ? popups : [], Array.isArray(history) ? history : []]
    for (var sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
        var rows = sources[sourceIndex]
        for (var index = 0; index < rows.length && result.length < limit; index++) {
            var row = rows[index]
            if (!row || seen[row.key]) continue
            seen[row.key] = true
            result.push(row)
        }
    }
    result.sort(function(left, right) { return Number(right.timestamp || 0) - Number(left.timestamp || 0) })
    return result.slice(0, limit)
}

if (typeof module !== "undefined") {
    module.exports = {
        SNAPSHOT_ROLES: SNAPSHOT_ROLES,
        inertHints: inertHints,
        actionSnapshots: actionSnapshots,
        snapshotOf: snapshotOf,
        replacementSnapshot: replacementSnapshot,
        snapshotChanged: snapshotChanged,
        validSnapshot: validSnapshot,
        parseState: parseState,
        boundedHistory: boundedHistory,
        historyKeysRemoved: historyKeysRemoved,
        centerRows: centerRows
    }
}
