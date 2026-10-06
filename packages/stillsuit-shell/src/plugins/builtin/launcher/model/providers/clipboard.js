// Snapshot: stillsuit.clipboard items
// {id, kind: "text"|"image", preview, mime, bytes, createdAt, lastUsed, path?}.
// Newest first by lastUsed. With a query, matches within
// Matcher.STRONG_MATCH_RATIO of the best one keep that order and weaker ones
// follow by score. The start offset is not penalised: where a match sits in a
// long clip says little about relevance.
// env.clipboardImagesOnly keeps only image items.

var meta = { id: "clipboard", label: "Clipboard", icon: "shell:copy", snapshot: "clipboardItems" }

var MAX_TITLE_LENGTH = 200
var ACTIONS = [
    { id: "copy", label: "Copy" },
    { id: "remove", label: "Delete" },
    { id: "clear", label: "Clear history" }
]
var MATCH_OPTIONS = { startPenalty: false, acronym: false }

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function finite(value, fallback) {
    var number = Number(value)
    return isFinite(number) ? number : fallback
}

function sizeLabel(bytes) {
    if (!(bytes >= 0)) return ""
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
}

function titleOf(preview) {
    var collapsed = preview.replace(/\s+/g, " ").trim()
    return collapsed.length > MAX_TITLE_LENGTH ? collapsed.slice(0, MAX_TITLE_LENGTH) + "…" : collapsed
}

function compareRecency(a, b) {
    if (a.lastUsed !== b.lastUsed) return b.lastUsed - a.lastUsed
    if (a.createdAt !== b.createdAt) return b.createdAt - a.createdAt
    return a.order - b.order
}

function prepare(items, matcher) {
    var result = []
    var seen = Object.create(null)
    if (!items || typeof items.length !== "number") return result
    for (var index = 0; index < items.length; index++) {
        var item = items[index]
        if (!item) continue
        var id = safeString(item.id)
        if (id === "" || seen[id] === true) continue
        seen[id] = true
        var image = item.kind === "image"
        var mime = safeString(item.mime)
        var bytes = finite(item.bytes, -1)
        var preview = safeString(item.preview)
        var createdAt = finite(item.createdAt, 0)
        var text = image ? "Image" : titleOf(preview)
        var details = [mime, sizeLabel(bytes)].filter(function(part) { return part !== "" })
        result.push({
            key: meta.id + ":" + id,
            itemId: id,
            image: image,
            text: text,
            subtext: details.join(" · "),
            preview: image ? { kind: "image", path: safeString(item.path) } : { kind: "text", text: preview },
            lastUsed: finite(item.lastUsed, createdAt),
            createdAt: createdAt,
            order: index,
            fields: image
                ? [matcher.prepare("image"), matcher.prepare(mime)]
                : [matcher.prepare(text), matcher.prepare(preview)]
        })
    }
    result.sort(compareRecency)
    return result
}

function itemsOf(env) {
    return env.prepared && env.prepared.clipboard ? env.prepared.clipboard : prepare(env.clipboardItems, env.matcher)
}

function query(text, env) {
    var items = itemsOf(env)
    if (env.clipboardImagesOnly === true)
        items = items.filter(function(item) { return item.image })
    var ordered = []
    if (text === "") {
        for (var index = 0; index < items.length; index++)
            ordered.push({ item: items[index], positions: [] })
    } else {
        var prepared = env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
        var matches = []
        var best = 0
        for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
            var match = env.matcher.score(prepared, items[itemIndex].fields, MATCH_OPTIONS)
            if (match.score <= 0) continue
            if (match.score > best) best = match.score
            matches.push({
                item: items[itemIndex],
                score: match.score,
                positions: match.field === 0 && !items[itemIndex].image ? match.positions : []
            })
        }
        var threshold = env.matcher.strongThreshold(best)
        var weak = []
        for (var matchIndex = 0; matchIndex < matches.length; matchIndex++) {
            if (matches[matchIndex].score >= threshold) ordered.push(matches[matchIndex])
            else weak.push(matches[matchIndex])
        }
        weak.sort(function(a, b) {
            return b.score - a.score || compareRecency(a.item, b.item)
        })
        ordered = ordered.concat(weak)
    }
    var rows = []
    for (var rowIndex = 0; rowIndex < ordered.length; rowIndex++) {
        var entry = ordered[rowIndex]
        rows.push({
            key: entry.item.key,
            provider: meta.id,
            text: entry.item.text,
            subtext: entry.item.subtext,
            icon: entry.item.image ? "shell:image" : "shell:copy",
            score: ordered.length - rowIndex,
            positions: entry.positions,
            actions: ACTIONS,
            preview: entry.item.preview,
            itemId: entry.item.itemId
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var id = safeString(row.itemId)
    if (id === "") return null
    var action = safeString(actionId)
    if (action === "" || action === "copy") return { type: "clipboard.copy", id: id }
    if (action === "remove") return { type: "clipboard.remove", id: id, keepOpen: true }
    if (action === "clear") return { type: "clipboard.clear" }
    return null
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        prepare: prepare,
        query: query,
        activate: activate
    }
}
