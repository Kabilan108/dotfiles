// Ordering is most recently focused first, windows that were never focused
// last. The empty query is alt-tab style: the focused window moves to the end
// so the first row is the previous window. With a query, matches within
// Matcher.STRONG_MATCH_RATIO of the best one keep strict recency order, the
// focused window included; weaker matches follow by score.

var meta = { id: "windows", label: "Windows", icon: "preferences-system-windows", snapshot: "windows" }

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function timestampOf(window) {
    var stamp = window.focus_timestamp
    if (!stamp || typeof stamp !== "object") return null
    var secs = Number(stamp.secs)
    var nanos = Number(stamp.nanos)
    if (!isFinite(secs)) return null
    return { secs: secs, nanos: isFinite(nanos) ? nanos : 0 }
}

function compareRecency(a, b) {
    if (a.timestamp === null || b.timestamp === null) {
        if (a.timestamp === b.timestamp) return a.order - b.order
        return a.timestamp === null ? 1 : -1
    }
    if (a.timestamp.secs !== b.timestamp.secs) return b.timestamp.secs - a.timestamp.secs
    if (a.timestamp.nanos !== b.timestamp.nanos) return b.timestamp.nanos - a.timestamp.nanos
    return a.order - b.order
}

function subtextOf(window, appId) {
    var parts = []
    if (appId !== "") parts.push(appId)
    var workspace = safeString(window.workspaceName)
    if (workspace === "" && window.workspace_id !== undefined && window.workspace_id !== null)
        workspace = safeString(window.workspace_id)
    if (workspace !== "") parts.push("workspace " + workspace)
    var output = safeString(window.outputName)
    if (output !== "") parts.push(output)
    return parts.join(" · ")
}

function prepare(windows, matcher) {
    var result = []
    var seen = Object.create(null)
    if (!windows || typeof windows.length !== "number") return result
    for (var index = 0; index < windows.length; index++) {
        var window = windows[index]
        if (!window || window.id === undefined || window.id === null) continue
        var id = Number(window.id)
        if (!isFinite(id) || seen[id] === true) continue
        seen[id] = true
        var title = safeString(window.title)
        var appId = safeString(window.app_id)
        result.push({
            key: meta.id + ":" + id,
            windowId: id,
            title: title || appId || "Window " + id,
            subtext: subtextOf(window, appId),
            icon: appId || "application-x-executable",
            appId: appId,
            focused: window.is_focused === true,
            timestamp: timestampOf(window),
            order: index,
            fields: [matcher.prepare(title), matcher.prepare(appId)]
        })
    }
    result.sort(compareRecency)
    return result
}

function itemsOf(env) {
    return env.prepared && env.prepared.windows ? env.prepared.windows : prepare(env.windows, env.matcher)
}

function focusedLast(entries) {
    if (entries.length < 2) return entries
    for (var index = 0; index < entries.length - 1; index++) {
        if (entries[index].item.focused) {
            var focused = entries.splice(index, 1)[0]
            entries.push(focused)
            break
        }
    }
    return entries
}

function query(text, env) {
    var items = itemsOf(env)
    var strong = []
    var weak = []
    if (text === "") {
        for (var index = 0; index < items.length; index++)
            strong.push({ item: items[index], score: 0, positions: [] })
    } else {
        var prepared = env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
        var matches = []
        var best = 0
        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
            var match = env.matcher.score(prepared, items[itemIndex].fields)
            if (match.score <= 0) continue
            if (match.score > best) best = match.score
            matches.push({
                item: items[itemIndex],
                score: match.score,
                positions: match.field === 0 ? match.positions : []
            })
        }
        var threshold = env.matcher.strongThreshold(best)
        for (var matchIndex = 0; matchIndex < matches.length; matchIndex++) {
            if (matches[matchIndex].score >= threshold) strong.push(matches[matchIndex])
            else weak.push(matches[matchIndex])
        }
        weak.sort(function(a, b) {
            return b.score - a.score || compareRecency(a.item, b.item)
        })
    }
    var ordered = (text === "" ? focusedLast(strong) : strong).concat(weak)
    var rows = []
    for (var rowIndex = 0; rowIndex < ordered.length; rowIndex++) {
        var entry = ordered[rowIndex]
        var item = entry.item
        rows.push({
            key: item.key,
            provider: meta.id,
            text: item.title,
            subtext: item.subtext,
            icon: item.icon,
            score: ordered.length - rowIndex,
            positions: entry.positions,
            actions: [{ id: "focus", label: "Focus" }],
            current: item.focused,
            windowId: item.windowId,
            appId: item.appId
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var action = safeString(actionId)
    if (action !== "" && action !== "focus") return null
    var id = Number(row.windowId)
    if (!isFinite(id)) return null
    return { type: "window.focus", id: id }
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        prepare: prepare,
        query: query,
        activate: activate
    }
}
