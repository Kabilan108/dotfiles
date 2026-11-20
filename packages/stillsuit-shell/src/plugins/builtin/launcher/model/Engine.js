var DEFAULT_MAX_RESULTS = 100
var MAX_RESULTS_LIMIT = 500

var INTENT_FIELDS = {
    "app.launch": { desktopId: "id", actionId: "id?" },
    "window.focus": { id: "windowId" },
    "session": { action: "session" },
    "profile.activate": { id: "id" },
    "url.open": { url: "url" },
    "text.copy": { text: "text" },
    "remmina.connect": { path: "path" },
    "path.open": { path: "path" },
    "path.reveal": { path: "path" },
    "clipboard.copy": { id: "id" },
    "clipboard.remove": { id: "id" },
    "clipboard.clear": {}
}
var SESSION_ACTIONS = ["lock", "suspend", "logout", "reboot", "poweroff"]
var MAX_SAFE_INTEGER = 9007199254740991
var MAX_URL_LENGTH = 8192

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function has(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key)
}

function validField(kind, value) {
    switch (kind) {
    case "id":
        return typeof value === "string" && value !== "" && value.indexOf("\u0000") < 0
    case "text":
        return typeof value === "string"
    case "path":
        return typeof value === "string" && value.charAt(0) === "/" && value.indexOf("\u0000") < 0
    case "url":
        return typeof value === "string" && value.length <= MAX_URL_LENGTH && /^https?:\/\/\S+$/i.test(value)
    case "windowId":
        return typeof value === "number" && Math.floor(value) === value && value > 0
            && value <= MAX_SAFE_INTEGER
    case "session":
        return typeof value === "string" && SESSION_ACTIONS.indexOf(value) >= 0
    }
    return false
}

function checkIntent(intent) {
    if (!intent || typeof intent !== "object" || Array.isArray(intent)) return false
    var type = intent.type
    if (typeof type !== "string" || !has(INTENT_FIELDS, type)) return false
    var schema = INTENT_FIELDS[type]
    var keys = Object.keys(intent)
    for (var index = 0; index < keys.length; index++) {
        var key = keys[index]
        if (key === "type") continue
        if (key === "keepOpen") {
            if (typeof intent.keepOpen !== "boolean") return false
            continue
        }
        if (!has(schema, key)) return false
    }
    var fields = Object.keys(schema)
    for (var field = 0; field < fields.length; field++) {
        var name = fields[field]
        var kind = schema[name]
        var optional = kind.charAt(kind.length - 1) === "?"
        if (optional) kind = kind.slice(0, -1)
        if (!has(intent, name)) {
            if (optional) continue
            return false
        }
        if (!validField(kind, intent[name])) return false
    }
    return true
}

function validIntent(intent) {
    try {
        return checkIntent(intent) === true
    } catch (error) {
        return false
    }
}

function compareRows(a, b) {
    if (a.score !== b.score) return b.score - a.score
    var left = rowSortText(a)
    var right = rowSortText(b)
    if (left < right) return -1
    if (left > right) return 1
    return 0
}

function rowSortText(row) {
    return row.sortKey !== undefined ? row.sortKey : row.text
}

function kthLargest(values, k) {
    var target = values.length - k
    var low = 0
    var high = values.length - 1
    while (low < high) {
        var a = values[low]
        var b = values[(low + high) >> 1]
        var c = values[high]
        var pivot = a < b ? (b < c ? b : a < c ? c : a) : (a < c ? a : b < c ? c : b)
        var i = low
        var j = high
        while (i <= j) {
            while (values[i] < pivot) i++
            while (values[j] > pivot) j--
            if (i <= j) {
                var swap = values[i]
                values[i] = values[j]
                values[j] = swap
                i++
                j--
            }
        }
        if (target <= j) high = j
        else if (target >= i) low = i
        else break
    }
    return values[target]
}

function rowsAt(rows, picks) {
    picks.sort(function(first, second) {
        return compareRows(rows[first], rows[second]) || first - second
    })
    var result = new Array(picks.length)
    for (var index = 0; index < picks.length; index++) result[index] = rows[picks[index]]
    return result
}

function allRanked(rows) {
    var picks = new Array(rows.length)
    for (var index = 0; index < rows.length; index++) picks[index] = index
    return rowsAt(rows, picks)
}

function leadingRows(rows, limit) {
    if (rows.length <= limit * 2) return allRanked(rows)
    var scores = []
    for (var index = 0; index < rows.length; index++) {
        var value = rows[index].score
        if (typeof value !== "number" || value !== value) return allRanked(rows)
        scores.push(value)
    }
    var cutoff = kthLargest(scores, limit)
    var above = []
    var tied = []
    for (var row = 0; row < rows.length; row++) {
        if (rows[row].score > cutoff) above.push(row)
        else if (rows[row].score === cutoff) tied.push(row)
    }
    var kept = rowsAt(rows, above)
    if (tied.length <= limit) {
        kept = kept.concat(rowsAt(rows, tied))
    } else {
        var groups = Object.create(null)
        var labels = []
        for (var tie = 0; tie < tied.length; tie++) {
            var label = String(rowSortText(rows[tied[tie]]))
            if (groups[label] === undefined) {
                groups[label] = []
                labels.push(label)
            }
            groups[label].push(rows[tied[tie]])
        }
        labels.sort()
        for (var group = 0; group < labels.length; group++) {
            var members = groups[labels[group]]
            for (var member = 0; member < members.length; member++) kept.push(members[member])
        }
    }
    var keys = Object.create(null)
    var distinct = 0
    for (var keep = 0; keep < kept.length && distinct < limit; keep++) {
        if (keys[kept[keep].key] === true) continue
        keys[kept[keep].key] = true
        distinct++
    }
    return distinct < limit ? allRanked(rows) : kept
}

function plainCopy(value, frozen) {
    if (value === null || typeof value !== "object") return value
    var copy
    if (Array.isArray(value)) {
        copy = new Array(value.length)
        for (var index = 0; index < value.length; index++) copy[index] = plainCopy(value[index], frozen)
    } else {
        copy = {}
        var keys = Object.keys(value)
        for (var key = 0; key < keys.length; key++) copy[keys[key]] = plainCopy(value[keys[key]], frozen)
    }
    return frozen ? Object.freeze(copy) : copy
}

function viewOf(row, generation) {
    var view = {}
    var keys = Object.keys(row)
    for (var index = 0; index < keys.length; index++) view[keys[index]] = plainCopy(row[keys[index]], true)
    view.generation = generation
    return Object.freeze(view)
}

function normalizeSettings(settings) {
    var source = settings && typeof settings === "object" ? settings : {}
    var maxResults = Math.floor(Number(source.maxResults))
    if (!isFinite(maxResults) || maxResults < 1) maxResults = DEFAULT_MAX_RESULTS
    if (maxResults > MAX_RESULTS_LIMIT) maxResults = MAX_RESULTS_LIMIT
    return {
        webEngine: safeString(source.webEngine),
        maxResults: maxResults,
        searchRoot: safeString(source.searchRoot)
    }
}

function create(modules) {
    var Matcher = modules.Matcher
    var History = modules.History
    var Query = modules.Query
    var providers = Object.create(null)
    var list = modules.providers || []
    for (var index = 0; index < list.length; index++) providers[list[index].meta.id] = list[index]

    var preparedSources = Object.create(null)
    var preparedRevisions = Object.create(null)
    var prepared = {}
    var historySource = undefined
    var historyInstance = null
    var settingsSource = undefined
    var settings = normalizeSettings(null)
    var generation = 0
    var currentRows = Object.create(null)

    function prepare(env) {
        var source = env || {}
        var revisions = source.revisions && typeof source.revisions === "object" ? source.revisions : null
        var ids = Object.keys(providers)
        for (var i = 0; i < ids.length; i++) {
            var provider = providers[ids[i]]
            var snapshotKey = provider.meta.snapshot
            if (!snapshotKey || typeof provider.prepare !== "function") continue
            var snapshot = source[snapshotKey]
            var revision = revisions && has(revisions, snapshotKey) ? revisions[snapshotKey] : undefined
            var fresh = has(prepared, provider.meta.id)
                && (revision !== undefined
                    ? preparedRevisions[snapshotKey] === revision
                    : preparedSources[snapshotKey] === snapshot)
            if (fresh) continue
            prepared[provider.meta.id] = provider.prepare(snapshot, Matcher)
            preparedSources[snapshotKey] = snapshot
            preparedRevisions[snapshotKey] = revision
        }
        return prepared
    }

    function historyOf(env, now) {
        var source = env ? env.history : undefined
        if (History.isHistory(source)) return source
        if (historyInstance === null || source !== historySource) {
            historyInstance = History.create(source, now)
            historySource = source
        }
        return historyInstance
    }

    function settingsOf(env) {
        var source = env ? env.settings : undefined
        if (source !== settingsSource) {
            settings = normalizeSettings(source)
            settingsSource = source
        }
        return settings
    }

    function context(env, parsed) {
        var source = env || {}
        var number = Number(source.now)
        var now = isFinite(number) ? number : Date.now()
        return {
            matcher: Matcher,
            query: Matcher.prepareQuery(parsed.text),
            text: parsed.text,
            prefix: parsed.prefix,
            mode: parsed.mode,
            providerIds: parsed.providerIds,
            history: historyOf(source, now),
            settings: settingsOf(source),
            now: now,
            prepared: prepare(source),
            apps: source.apps,
            windows: source.windows,
            currentWindowId: source.currentWindowId,
            profiles: source.profiles,
            clipboardItems: source.clipboardItems,
            clipboardImagesOnly: source.clipboardImagesOnly === true,
            filesResult: source.filesResult,
            calcResult: source.calcResult
        }
    }

    function run(rawInput, mode, env) {
        var parsed = Query.parse(rawInput, mode)
        var ctx = context(env, parsed)
        var rows = []
        var trailing = []
        var pending = {}
        for (var i = 0; i < parsed.providerIds.length; i++) {
            var provider = providers[parsed.providerIds[i]]
            if (!provider) continue
            if (typeof provider.pending === "function") {
                var lookup = provider.pending(parsed.text, ctx)
                if (lookup !== "") pending[provider.meta.id] = lookup
            }
            var produced = provider.query(parsed.text, ctx)
            for (var r = 0; r < produced.length; r++) {
                if (produced[r].trailing === true) trailing.push(produced[r])
                else rows.push(produced[r])
            }
        }
        var limit = parsed.providerIds.length === 1 && parsed.providerIds[0] === "remmina"
            ? rows.length : ctx.settings.maxResults
        rows = leadingRows(rows, limit)

        var seen = Object.create(null)
        var result = []
        for (var j = 0; j < rows.length && result.length < limit; j++) {
            if (seen[rows[j].key] === true) continue
            seen[rows[j].key] = true
            result.push(rows[j])
        }
        for (var t = 0; t < trailing.length && result.length < limit; t++) {
            if (seen[trailing[t].key] === true) continue
            seen[trailing[t].key] = true
            result.push(trailing[t])
        }

        generation++
        var snapshots = Object.create(null)
        var views = new Array(result.length)
        for (var k = 0; k < result.length; k++) {
            snapshots[result[k].key] = plainCopy(result[k], false)
            views[k] = viewOf(result[k], generation)
        }
        currentRows = snapshots
        return {
            rows: views,
            providerIds: parsed.providerIds,
            prefix: parsed.prefix,
            text: parsed.text,
            mode: parsed.mode,
            pending: pending
        }
    }

    function currentRow(row) {
        if (!row || typeof row !== "object") return null
        var key = safeString(row.key)
        if (!has(currentRows, key)) return null
        return row.generation === generation ? currentRows[key] : null
    }

    function activate(row, actionId) {
        var stored
        try {
            stored = currentRow(row)
        } catch (error) {
            return null
        }
        if (!stored || !has(providers, stored.provider)) return null
        var intent = providers[stored.provider].activate(stored, safeString(actionId))
        return validIntent(intent) ? intent : null
    }

    function record(history, text, row, now) {
        if (!row || !has(providers, safeString(row.provider))) return false
        if (providers[row.provider].meta.history !== true) return false
        if (!History.isHistory(history)) return false
        return history.record(text, row.key, now)
    }

    return {
        prepare: prepare,
        run: run,
        activate: activate,
        record: record,
        context: function(env, rawInput, mode) {
            return context(env, Query.parse(rawInput, mode))
        },
        providers: providers
    }
}

if (typeof module !== "undefined") {
    module.exports = {
        create: create,
        validIntent: validIntent,
        compareRows: compareRows,
        leadingRows: leadingRows,
        INTENT_FIELDS: INTENT_FIELDS,
        DEFAULT_MAX_RESULTS: DEFAULT_MAX_RESULTS
    }
}
