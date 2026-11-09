// Snapshot and replacement behavior is substantially derived from Omarchy
// Quattro's NotificationLogic.js at commit
// f0020448ca87329199de7cb12f2015ebc4a3e5e7, used under the MIT License.

var SNAPSHOT_ROLES = [
    "appName", "appIcon", "summary", "body", "image", "urgency",
    "expireTimeout", "actions", "hints", "resident", "sourceKey", "sourceLabel",
    "sourceKind", "sourceHostname", "context", "link"
]

var HINT_ALLOWLIST = [
    "transient", "desktop-entry", "x-stillsuit-state", "value",
    "x-dunst-stack-tag", "x-canonical-private-synchronous"
]

var STATE_SCHEMA_VERSION = 3
var DEFAULT_MAX_AGE_MS = 24 * 60 * 60 * 1000

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

function safeHintValue(value) {
    if (value === undefined || value === null) return null
    if (typeof value === "string" || typeof value === "boolean") return value
    if (typeof value === "number") return isFinite(value) ? value : null
    return null
}

function inertHints(hints) {
    var result = {}
    if (!hints) return result

    try {
        for (var index = 0; index < HINT_ALLOWLIST.length; index++) {
            var key = HINT_ALLOWLIST[index]
            var value = safeHintValue(hints[key])
            if (value !== null) result[key] = value
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

// The spec's `value` hint, 0 to 100, as a fraction; -1 when there is none.
function progressOf(snapshot) {
    var hints = (snapshot || {}).hints || {}
    if (hints.value === undefined || hints.value === null || hints.value === "") return -1
    var value = Number(hints.value)
    return isFinite(value) ? Math.max(0, Math.min(1, value / 100)) : -1
}

// Volume and brightness tools reuse one card through a stack tag instead of
// a replaces_id they would have to remember.
function stackTagOf(snapshot) {
    var hints = (snapshot || {}).hints || {}
    return safeString(hints["x-dunst-stack-tag"] || hints["x-canonical-private-synchronous"])
}

function sameStack(left, right) {
    var tag = stackTagOf(right)
    return tag !== "" && stackTagOf(left) === tag
        && safeString((left || {}).appName) === safeString((right || {}).appName)
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
        resident: source.resident === true,
        timestamp: timestamp,
        deadline: finiteNumber(meta.deadline, 0),
        outputId: safeString(meta.outputId),
        quietClass: safeString(meta.quietClass || source.quietClass || "visible"),
        sourceKey: safeString(meta.sourceKey || source.sourceKey),
        sourceLabel: safeString(meta.sourceLabel || source.sourceLabel),
        sourceKind: safeString(meta.sourceKind || source.sourceKind),
        sourceHostname: safeString(meta.sourceHostname || source.sourceHostname),
        context: safeString(meta.context || source.context),
        link: source.link && typeof source.link === "object" ? {
            url: safeString(source.link.url),
            label: safeString(source.link.label),
            meeting: source.link.meeting === true
        } : null,
        heldReason: safeString(meta.heldReason || source.heldReason)
    }
}

function identityOf(previous) {
    var old = previous || {}
    return {
        key: old.key,
        timestamp: old.timestamp,
        outputId: old.outputId,
        deadline: old.deadline,
        quietClass: old.quietClass,
        sourceKey: old.sourceKey,
        sourceLabel: old.sourceLabel,
        sourceKind: old.sourceKind,
        sourceHostname: old.sourceHostname,
        context: old.context,
        heldReason: old.heldReason
    }
}

function replacementSnapshot(notification, previous) {
    return snapshotOf(notification, identityOf(previous))
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

    var identity = identityOf(value)
    identity.timestamp = Number(value.timestamp)
    return snapshotOf(value, identity)
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

function pruneSnapshots(snapshots, now, maxAgeMs, limit) {
    var rows = Array.isArray(snapshots) ? snapshots : []
    var referenceTime = finiteNumber(now, Date.now())
    var oldestTimestamp = referenceTime - Math.max(1, finiteNumber(maxAgeMs, DEFAULT_MAX_AGE_MS))
    var rowLimit = Math.max(1, Math.round(finiteNumber(limit, 100)))
    var result = []
    var seen = {}

    for (var index = 0; index < rows.length && result.length < rowLimit; index++) {
        var row = rows[index]
        if (!row || Number(row.timestamp || 0) < oldestTimestamp) continue
        var key = safeString(row.key)
        if (!key || seen[key]) continue
        seen[key] = true
        result.push(row)
    }
    return result
}

// Per-source mutes are finite; quiet mode is one indefinite switch.
function validMutes(value, now) {
    var result = {}
    if (!value || typeof value !== "object" || Array.isArray(value)) return result
    for (var key in value) {
        if (!Object.prototype.hasOwnProperty.call(value, key)) continue
        if (key === "*" || key === "__proto__" || key === "constructor" || key === "prototype") continue
        var entry = value[key] || {}
        var until = finiteNumber(entry.until, 0)
        if (!safeString(key) || until <= now) continue
        result[safeString(key)] = {
            until: until,
            startedAt: Math.max(0, finiteNumber(entry.startedAt, now))
        }
    }
    return result
}

function emptyState() {
    return { quiet: false, quietSince: 0, mutes: {}, popups: [], held: [], corrupt: false }
}

// Reads every schema this file has had. Version 2 kept history and finite
// global snoozes; neither survives, but its per-source snoozes become mutes.
function parseState(raw, limits, now) {
    var bounds = limits || {}
    var popupLimit = Math.max(1, Math.round(finiteNumber(bounds.popupRows, 40)))
    var heldLimit = Math.max(1, Math.round(finiteNumber(bounds.held, 50)))
    var maxAgeMs = finiteNumber(bounds.maxAgeMs, DEFAULT_MAX_AGE_MS)
    var referenceTime = finiteNumber(now, Date.now())
    var result = emptyState()
    var text = safeString(raw).trim()
    if (!text) return result

    try {
        var parsed = JSON.parse(text)
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
            result.corrupt = true
            return result
        }
        result.quiet = parsed.quiet === true || parsed.dnd === true
        result.quietSince = result.quiet ? finiteNumber(parsed.quietSince, referenceTime) : 0
        result.mutes = validMutes(parsed.mutes || parsed.snoozes, referenceTime)
        var isolatedPopups = isolateRecords(parsed.popups, popupLimit)
        result.popups = pruneSnapshots(isolatedPopups, referenceTime, maxAgeMs, popupLimit)
        var isolatedHeld = isolateRecords(parsed.held, heldLimit)
        result.held = pruneSnapshots(isolatedHeld, referenceTime, maxAgeMs, heldLimit)
        result.corrupt = isolatedPopups.length !== (Array.isArray(parsed.popups) ? Math.min(parsed.popups.length, popupLimit) : 0)
            || isolatedHeld.length !== (Array.isArray(parsed.held) ? Math.min(parsed.held.length, heldLimit) : 0)
        return result
    } catch (error) {
        result.corrupt = true
        return result
    }
}

function serializeState(state) {
    var value = state || {}
    return JSON.stringify({
        schemaVersion: STATE_SCHEMA_VERSION,
        quiet: value.quiet === true,
        quietSince: value.quiet === true ? finiteNumber(value.quietSince, 0) : 0,
        mutes: value.mutes || {},
        popups: Array.isArray(value.popups) ? value.popups : [],
        held: Array.isArray(value.held) ? value.held : []
    }, null, 2) + "\n"
}

// Keys present in `previous` and missing from `next`.
function keysRemoved(previous, next) {
    var retained = {}
    var nextRows = Array.isArray(next) ? next : []
    for (var nextIndex = 0; nextIndex < nextRows.length; nextIndex++)
        retained[safeString((nextRows[nextIndex] || {}).key)] = true

    var removed = []
    var previousRows = Array.isArray(previous) ? previous : []
    for (var previousIndex = 0; previousIndex < previousRows.length; previousIndex++) {
        var key = safeString((previousRows[previousIndex] || {}).key)
        if (key && !retained[key] && removed.indexOf(key) === -1) removed.push(key)
    }
    return removed
}

if (typeof module !== "undefined") {
    module.exports = {
        SNAPSHOT_ROLES: SNAPSHOT_ROLES,
        HINT_ALLOWLIST: HINT_ALLOWLIST,
        STATE_SCHEMA_VERSION: STATE_SCHEMA_VERSION,
        inertHints: inertHints,
        actionSnapshots: actionSnapshots,
        progressOf: progressOf,
        stackTagOf: stackTagOf,
        sameStack: sameStack,
        snapshotOf: snapshotOf,
        replacementSnapshot: replacementSnapshot,
        snapshotChanged: snapshotChanged,
        validSnapshot: validSnapshot,
        parseState: parseState,
        serializeState: serializeState,
        pruneSnapshots: pruneSnapshots,
        validMutes: validMutes,
        keysRemoved: keysRemoved
    }
}
