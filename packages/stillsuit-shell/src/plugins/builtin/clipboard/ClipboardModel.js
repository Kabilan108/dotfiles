// Clipboard history rules for stillsuit.clipboard. Pure functions over plain
// objects so node tests and the QML service share them; the service owns IO,
// timers and the clock.

var SCHEMA_VERSION = 1
var SHA_PATTERN = /^[0-9a-f]{64}$/
// The collector's `shape`: a sha256 prefix of the offered MIME types.
var SHAPE_PATTERN = /^[0-9a-f]{16}$/
// Mirrors MIME_RE in bin/stillsuit-clipboard-collector, which validates again
// before running wl-copy.
var MIME_PATTERN = /^(?:[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]{0,126}\/[A-Za-z0-9][A-Za-z0-9!#$&^_.+-]{0,126}(?:;[ ]?[A-Za-z0-9_.-]{1,64}=[A-Za-z0-9_.-]{1,64})?|[A-Z][A-Z0-9_]{0,63})$/
var PREVIEW_MAX_CHARS = 4096
// Mirrors BLOB_GONE in bin/stillsuit-clipboard-collector: `copy` found the
// blob missing or not holding its content.
var COPY_BLOB_GONE = 3
var DEFAULT_GECKO_APP_IDS = "^(zen|zen-beta|zen-browser|zen-alpha|zen-twilight|app\\.zen_browser\\.zen"
    + "|firefox|firefox-esr|firefox-nightly|librewolf|org\\.mozilla\\.firefox)$"
// TTL pruning batches expiries.
var MIN_TIMER_MS = 10 * 60 * 1000
var MAX_TIMER_MS = 6 * 60 * 60 * 1000
var MAX_JITTER_MS = 5000
var GC_FOLLOW_UP_GAP_MS = 10 * 60 * 1000
var GC_FOLLOW_UP_MARGIN_MS = 1000

var DEFAULT_SECRET_SOURCE_PREFIXES = [
    "chrome-extension://nngceckbapebfimnlniiiahkandclblb/",
    "https://vault.sole-pierce.ts.net"
]

function _number(value, fallback, min, max) {
    var number = Number(value)
    if (value === undefined || value === null || value === "" || !isFinite(number))
        number = fallback
    return Math.min(max, Math.max(min, number))
}

function _list(value, fallback) {
    // Settings lists arrive as QVariantList, which fails Array.isArray in Qt.
    if (!value || typeof value !== "object" || typeof value.length !== "number")
        return fallback.slice()
    var result = []
    for (var index = 0; index < value.length; index++) {
        var item = String(value[index] === undefined || value[index] === null ? "" : value[index])
        if (item !== "")
            result.push(item)
    }
    return result
}

function options(values) {
    var source = values && typeof values === "object" ? values : {}
    return {
        maxItems: Math.floor(_number(source.maxItems, 200, 1, 2000)),
        ttlMs: Math.round(_number(source.ttlHours, 72, 0.1, 24 * 365) * 3600 * 1000),
        purgeWindowMs: Math.round(_number(source.clearPurgeWindowSec, 330, 0, 3600) * 1000),
        unattributedFirefox: source.unattributedFirefox === "record" ? "record" : "skip",
        geckoAppIds: typeof source.geckoAppIds === "string" && source.geckoAppIds !== ""
            ? source.geckoAppIds : DEFAULT_GECKO_APP_IDS,
        maxTextBytes: Math.floor(_number(source.maxTextBytes, 1024 * 1024, 1, 64 * 1024 * 1024)),
        maxImageBytes: Math.floor(_number(source.maxImageBytes, 20 * 1024 * 1024, 1, 256 * 1024 * 1024)),
        gcGraceSec: Math.round(_number(source.gcGraceSec, 120, 0, 24 * 3600)),
        focusSettleMs: Math.round(_number(source.focusSettleMs, 2000, 0, 60000)),
        secretSourcePrefixes: _list(source.secretSourcePrefixes, DEFAULT_SECRET_SOURCE_PREFIXES)
    }
}

function emptyState() {
    // lastRecorded: sha of the entry the previous capture event recorded, ""
    // when the previous event recorded nothing, null when unknown (startup).
    return { entries: [], lastRecorded: null }
}

// A timestamp written while the clock ran ahead is clamped to now, so it can
// neither postpone expiry nor make a later clear look like it came first.
function _time(value, now) {
    var number = Number(value)
    return isFinite(number) && number > 0 ? Math.floor(Math.min(number, now)) : 0
}

function _shape(value) {
    return typeof value === "string" && SHAPE_PATTERN.test(value) ? value : ""
}

function normalizeEntry(raw, now) {
    if (!raw || typeof raw !== "object")
        return null
    var kind = raw.kind === "image" ? "image" : (raw.kind === "text" ? "text" : "")
    var sha = String(raw.sha || "")
    var mime = String(raw.mime || "")
    var bytes = Number(raw.bytes)
    var lastUsed = _time(raw.lastUsed, now)
    if (kind === "" || !SHA_PATTERN.test(sha) || !MIME_PATTERN.test(mime)
            || !isFinite(bytes) || bytes < 0 || lastUsed === 0)
        return null
    var created = _time(raw.created, now) || lastUsed
    var captured = _time(raw.captured, now) || lastUsed
    return {
        id: sha,
        kind: kind,
        sha: sha,
        mime: mime,
        bytes: Math.floor(bytes),
        preview: kind === "text" ? String(raw.preview || "").slice(0, PREVIEW_MAX_CHARS) : "",
        created: created,
        lastUsed: lastUsed,
        captured: captured,
        shape: kind === "text" ? _shape(raw.shape) : ""
    }
}

function parseEvent(line) {
    var event
    try {
        event = JSON.parse(String(line || ""))
    } catch (error) {
        return null
    }
    if (!event || typeof event !== "object")
        return null
    if (event.kind === "clear")
        return { kind: "clear", shape: _shape(event.shape) }
    if (event.kind === "skipped")
        return { kind: "skipped", reason: String(event.reason || "") }
    if (event.kind !== "text" && event.kind !== "image")
        return null
    var sha = String(event.sha || "")
    var mime = String(event.mime || "")
    var bytes = Number(event.bytes)
    if (!SHA_PATTERN.test(sha) || !MIME_PATTERN.test(mime) || !isFinite(bytes) || bytes < 0)
        return null
    return {
        kind: event.kind,
        sha: sha,
        mime: mime,
        bytes: Math.floor(bytes),
        preview: event.kind === "text" ? String(event.preview || "").slice(0, PREVIEW_MAX_CHARS) : "",
        shape: event.kind === "text" ? _shape(event.shape) : ""
    }
}

function isExpired(entry, now, opts) {
    return now - entry.lastUsed >= opts.ttlMs
}

// Removal results list the blob shas to delete in `removed`.
function prune(entries, now, opts) {
    var kept = []
    var removed = []
    for (var index = 0; index < entries.length; index++) {
        var entry = entries[index]
        if (isExpired(entry, now, opts) || kept.length >= opts.maxItems)
            removed.push(entry.sha)
        else
            kept.push(entry)
    }
    return { entries: kept, removed: removed }
}

// A pending removal is a batch of blob shas the service decided to delete at
// `before` (ms) and has not yet seen `rm` finish. They are persisted with the
// history so a shutdown or crash cannot lose them. A `before` from a clock
// that ran ahead is clamped, which only keeps more blobs.
//
// Each sha is pending in at most one batch, the one with its latest decision,
// so the queue never holds more shas than there are blobs and no intent is
// ever dropped to bound it.
function enqueueRemoval(batches, shas, before) {
    var incoming = []
    for (var index = 0; index < shas.length; index++) {
        var sha = String(shas[index])
        if (SHA_PATTERN.test(sha) && incoming.indexOf(sha) < 0)
            incoming.push(sha)
    }
    var result = []
    for (var b = 0; b < batches.length; b++) {
        var kept = []
        for (var s = 0; s < batches[b].shas.length; s++) {
            var queued = batches[b].shas[s]
            var at = incoming.indexOf(queued)
            if (at < 0)
                kept.push(queued)
            else if (batches[b].before > before) {
                kept.push(queued)
                incoming.splice(at, 1)
            }
        }
        if (kept.length > 0)
            result.push({ shas: kept, before: batches[b].before })
    }
    if (incoming.length === 0)
        return result
    var last = result.length > 0 ? result[result.length - 1] : null
    if (last !== null && last.before === before)
        last.shas = last.shas.concat(incoming)
    else
        result.push({ shas: incoming, before: before })
    return result
}

function normalizeRemovals(raw, now) {
    var batches = []
    if (!raw || typeof raw !== "object" || typeof raw.length !== "number")
        return batches
    for (var index = 0; index < raw.length; index++) {
        var batch = raw[index]
        var before = _time(batch && batch.before, now)
        if (before === 0 || !batch.shas || typeof batch.shas.length !== "number")
            continue
        var shas = []
        for (var s = 0; s < batch.shas.length; s++)
            shas.push(batch.shas[s])
        batches = enqueueRemoval(batches, shas, before)
    }
    return batches
}

// Whether a history read back from disk records exactly these entries (in
// order) and pending removals. Compares shas and decision times only, so text
// that changed in a UTF-8 round trip still matches.
function historyMatches(raw, entries, pendingRemovals) {
    var document
    try {
        document = JSON.parse(String(raw === undefined || raw === null ? "" : raw))
    } catch (error) {
        return false
    }
    if (!document || document.schemaVersion !== SCHEMA_VERSION || !Array.isArray(document.entries)
            || document.entries.length !== entries.length)
        return false
    for (var index = 0; index < entries.length; index++) {
        if (!document.entries[index] || document.entries[index].sha !== entries[index].sha)
            return false
    }
    var stored = document.pendingRemovals || []
    var expected = pendingRemovals || []
    if (!Array.isArray(stored) || stored.length !== expected.length)
        return false
    for (var b = 0; b < expected.length; b++) {
        if (!stored[b] || stored[b].before !== expected[b].before || !Array.isArray(stored[b].shas)
                || stored[b].shas.join() !== expected[b].shas.join())
            return false
    }
    return true
}

// `dirty` asks the caller to write the history back: something was dropped,
// clamped or otherwise normalized, so the file differs from what serialize()
// would write.
function parseHistory(raw, now, opts) {
    var text = String(raw === undefined || raw === null ? "" : raw)
    var broken = { entries: [], removed: [], pendingRemovals: [], corrupt: true, dirty: true }
    if (text.trim() === "")
        return { entries: [], removed: [], pendingRemovals: [], corrupt: false, dirty: false }
    var document
    try {
        document = JSON.parse(text)
    } catch (error) {
        return broken
    }
    if (!document || typeof document !== "object" || document.schemaVersion !== SCHEMA_VERSION
            || !Array.isArray(document.entries))
        return broken
    var seen = {}
    var entries = []
    var invalid = 0
    for (var index = 0; index < document.entries.length; index++) {
        var entry = normalizeEntry(document.entries[index], now)
        if (!entry) {
            invalid++
            continue
        }
        if (seen[entry.sha])
            continue
        seen[entry.sha] = true
        entries.push(entry)
    }
    entries.sort(function(left, right) { return right.lastUsed - left.lastUsed })
    var pruned = prune(entries, now, opts)
    var pendingRemovals = normalizeRemovals(document.pendingRemovals, now)
    return {
        entries: pruned.entries,
        removed: pruned.removed,
        pendingRemovals: pendingRemovals,
        corrupt: invalid > 0,
        dirty: serialize(pruned.entries, pendingRemovals) !== text
    }
}

function serialize(entries, pendingRemovals) {
    var rows = []
    for (var index = 0; index < entries.length; index++) {
        var entry = entries[index]
        var row = {
            sha: entry.sha,
            kind: entry.kind,
            mime: entry.mime,
            bytes: entry.bytes,
            preview: entry.preview,
            created: entry.created,
            lastUsed: entry.lastUsed,
            captured: entry.captured
        }
        if (entry.shape)
            row.shape = entry.shape
        rows.push(row)
    }
    var document = { schemaVersion: SCHEMA_VERSION, entries: rows }
    if (pendingRemovals && pendingRemovals.length > 0) {
        document.pendingRemovals = []
        for (var b = 0; b < pendingRemovals.length; b++)
            document.pendingRemovals.push({ shas: pendingRemovals[b].shas, before: pendingRemovals[b].before })
    }
    return JSON.stringify(document) + "\n"
}

function _indexOf(entries, id) {
    for (var index = 0; index < entries.length; index++) {
        if (entries[index].id === id)
            return index
    }
    return -1
}

function _withoutIndex(entries, index) {
    return entries.slice(0, index).concat(entries.slice(index + 1))
}

function _record(state, event, now, opts) {
    var index = _indexOf(state.entries, event.sha)
    var previous = index >= 0 ? state.entries[index] : null
    var entry = {
        id: event.sha,
        kind: event.kind,
        sha: event.sha,
        mime: event.mime,
        bytes: event.bytes,
        preview: event.preview,
        created: previous ? previous.created : now,
        lastUsed: now,
        captured: now,
        shape: event.shape || ""
    }
    var rest = index >= 0 ? _withoutIndex(state.entries, index) : state.entries
    var pruned = prune([entry].concat(rest), now, opts)
    return {
        state: { entries: pruned.entries, lastRecorded: event.sha },
        changed: true,
        removed: pruned.removed
    }
}

function _purge(state, event, now, opts) {
    var newest = state.entries.length > 0 ? state.entries[0] : null
    var age = newest !== null ? now - newest.captured : -1
    // A clear only belongs to the newest entry when the previous capture
    // recorded it. After a skipped secret, the clear belongs to that secret
    // and must not delete an unrelated earlier copy. A negative age means the
    // clock moved; the clear cannot be placed, so nothing is purged.
    //
    // An owner that offers text and sends no bytes also reads as a clear, so
    // the clear must offer the same types as the newest entry's capture did.
    // Bitwarden's Firefox clear offers the types of its copy. Entries saved
    // before shapes were recorded have none and are never purged.
    var eligible = newest !== null && newest.kind === "text"
        && age >= 0 && age < opts.purgeWindowMs
        && (state.lastRecorded === null || state.lastRecorded === newest.sha)
        && event.shape !== "" && event.shape === newest.shape
    if (!eligible)
        return _unchanged({ entries: state.entries, lastRecorded: "" })
    return {
        state: { entries: state.entries.slice(1), lastRecorded: "" },
        changed: true,
        removed: [newest.sha]
    }
}

function _unchanged(state) {
    return { state: state, changed: false, removed: [] }
}

// An "empty" skip (CLIPBOARD_STATE=nil, nothing offered) is not a capture:
// browsers announce both copies and clears with a nil event first, and it
// must not detach a following clear from the entry it belongs to. Every
// other skip may have been a secret, so the next clear belongs to it.
function applyEvent(state, event, now, opts) {
    if (!event)
        return _unchanged(state)
    if (event.kind === "text" || event.kind === "image")
        return _record(state, event, now, opts)
    if (event.kind === "clear")
        return _purge(state, event, now, opts)
    if (event.kind === "skipped" && event.reason === "empty")
        return _unchanged(state)
    return _unchanged({ entries: state.entries, lastRecorded: "" })
}

function touch(state, id, now) {
    var index = _indexOf(state.entries, id)
    if (index < 0)
        return { state: state, changed: false, entry: null }
    var entry = {}
    var source = state.entries[index]
    for (var key in source)
        entry[key] = source[key]
    entry.lastUsed = now
    return {
        state: { entries: [entry].concat(_withoutIndex(state.entries, index)), lastRecorded: state.lastRecorded },
        changed: true,
        entry: entry
    }
}

function remove(state, id) {
    var index = _indexOf(state.entries, id)
    if (index < 0)
        return _unchanged(state)
    return {
        state: { entries: _withoutIndex(state.entries, index), lastRecorded: state.lastRecorded },
        changed: true,
        removed: [state.entries[index].sha]
    }
}

function clearAll(state) {
    return {
        state: { entries: [], lastRecorded: "" },
        changed: state.entries.length > 0,
        removed: shas(state.entries)
    }
}

function find(state, id) {
    var index = _indexOf(state.entries, String(id || ""))
    return index >= 0 ? state.entries[index] : null
}

function publicItems(entries, now, opts, blobDir) {
    var items = []
    for (var index = 0; index < entries.length; index++) {
        var entry = entries[index]
        if (isExpired(entry, now, opts))
            continue
        items.push({
            id: entry.id,
            kind: entry.kind,
            mime: entry.mime,
            bytes: entry.bytes,
            preview: entry.preview,
            created: entry.created,
            lastUsed: entry.lastUsed,
            path: entry.kind === "image" && blobDir ? blobDir + "/" + entry.sha : ""
        })
    }
    return items
}

// Items a workbench fixture model supplies, coerced to the public shape.
function modelItems(raw) {
    var items = []
    if (!raw || typeof raw !== "object" || typeof raw.length !== "number")
        return items
    for (var index = 0; index < raw.length; index++) {
        var item = raw[index] || {}
        items.push({
            id: String(item.id || ""),
            kind: item.kind === "image" ? "image" : "text",
            mime: String(item.mime || "text/plain;charset=utf-8"),
            bytes: Number(item.bytes) || 0,
            preview: String(item.preview || "").slice(0, PREVIEW_MAX_CHARS),
            created: Number(item.created) || 0,
            lastUsed: Number(item.lastUsed) || 0,
            path: String(item.path || "")
        })
    }
    return items
}

function nextExpiryAt(entries, opts) {
    var next = 0
    for (var index = 0; index < entries.length; index++) {
        var at = entries[index].lastUsed + opts.ttlMs
        if (next === 0 || at < next)
            next = at
    }
    return next
}

function timerDelay(wakeAt, now, random) {
    var delay = Math.min(MAX_TIMER_MS, Math.max(MIN_TIMER_MS, wakeAt - now))
    var fraction = isFinite(random) ? Math.min(1, Math.max(0, random)) : 0
    return Math.round(delay + fraction * Math.min(MAX_JITTER_MS, delay * 0.05))
}

// When to sweep again after a gc that deferred files: just after the first of
// them becomes eligible (`nextEligibleMs`, wall-clock ms), but at least
// GC_FOLLOW_UP_GAP_MS after the previous follow-up, so files that stay young
// wake the service no more than once per gap. 0 when nothing was deferred.
function gcFollowUpAt(reply, now, lastFollowUpAt, graceSec) {
    if (!reply || !(reply.deferred > 0))
        return 0
    var eligible = Number(reply.nextEligibleMs)
    var wake = isFinite(eligible) && eligible > 0
        ? eligible + GC_FOLLOW_UP_MARGIN_MS : now + (graceSec + 1) * 1000
    if (lastFollowUpAt > 0)
        wake = Math.max(wake, lastFollowUpAt + GC_FOLLOW_UP_GAP_MS)
    return Math.min(now + MAX_TIMER_MS, Math.max(now + GC_FOLLOW_UP_MARGIN_MS, wake))
}

function shas(entries) {
    var result = []
    for (var index = 0; index < entries.length; index++)
        result.push(entries[index].sha)
    return result
}

function union(left, right) {
    var result = []
    var seen = {}
    var all = left.concat(right)
    for (var index = 0; index < all.length; index++) {
        if (!seen[all[index]]) {
            seen[all[index]] = true
            result.push(all[index])
        }
    }
    return result
}

if (typeof module !== "undefined") {
    module.exports = {
        SCHEMA_VERSION: SCHEMA_VERSION,
        DEFAULT_SECRET_SOURCE_PREFIXES: DEFAULT_SECRET_SOURCE_PREFIXES,
        DEFAULT_GECKO_APP_IDS: DEFAULT_GECKO_APP_IDS,
        COPY_BLOB_GONE: COPY_BLOB_GONE,
        MIN_TIMER_MS: MIN_TIMER_MS,
        MAX_TIMER_MS: MAX_TIMER_MS,
        options: options,
        emptyState: emptyState,
        normalizeEntry: normalizeEntry,
        normalizeRemovals: normalizeRemovals,
        enqueueRemoval: enqueueRemoval,
        historyMatches: historyMatches,
        parseEvent: parseEvent,
        parseHistory: parseHistory,
        serialize: serialize,
        prune: prune,
        applyEvent: applyEvent,
        touch: touch,
        remove: remove,
        clearAll: clearAll,
        find: find,
        isExpired: isExpired,
        publicItems: publicItems,
        modelItems: modelItems,
        nextExpiryAt: nextExpiryAt,
        timerDelay: timerDelay,
        gcFollowUpAt: gcFollowUpAt,
        GC_FOLLOW_UP_GAP_MS: GC_FOLLOW_UP_GAP_MS,
        shas: shas,
        union: union
    }
}
