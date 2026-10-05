// Field order and the minimum score that gates the usage boost follow
// Elephant's desktopapplications provider (GPL-3.0, min_score 30).

var meta = { id: "apps", label: "Applications", icon: "applications-all", snapshot: "apps", history: true }

var MIN_SCORE = 30
var MATCH_OPTIONS = { minScore: MIN_SCORE }
var LAUNCH_ACTION = { id: "launch", label: "Launch" }
var ACTION_PREFIX = "action:"

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function stringList(values) {
    var result = []
    if (!values || typeof values.length !== "number") return result
    for (var index = 0; index < values.length; index++) {
        var value = safeString(values[index])
        if (value !== "") result.push(value)
    }
    return result
}

function prepare(apps, matcher) {
    var result = []
    var seen = Object.create(null)
    if (!apps || typeof apps.length !== "number") return result
    for (var index = 0; index < apps.length; index++) {
        var app = apps[index]
        if (!app) continue
        var id = safeString(app.id)
        var name = safeString(app.name)
        if (id === "" || name === "" || seen[id] === true) continue
        seen[id] = true
        var genericName = safeString(app.genericName)
        var comment = safeString(app.comment)
        var actions = [LAUNCH_ACTION]
        var desktopActions = app.actions && typeof app.actions.length === "number" ? app.actions : []
        for (var actionIndex = 0; actionIndex < desktopActions.length; actionIndex++) {
            var action = desktopActions[actionIndex]
            if (!action) continue
            var actionId = safeString(action.id)
            if (actionId === "") continue
            actions.push({ id: ACTION_PREFIX + actionId, label: safeString(action.name) || actionId })
        }
        result.push({
            key: meta.id + ":" + id,
            desktopId: id,
            name: name,
            subtext: genericName || comment,
            icon: safeString(app.icon) || "application-x-executable",
            sortKey: name.toLowerCase(),
            actions: actions,
            fields: [
                matcher.prepare(name),
                matcher.prepare(genericName),
                matcher.prepare(stringList(app.keywords).join(" ")),
                matcher.prepare(comment)
            ]
        })
    }
    return result
}

function itemsOf(env) {
    return env.prepared && env.prepared.apps ? env.prepared.apps : prepare(env.apps, env.matcher)
}

function rowOf(item, score, positions) {
    return {
        key: item.key,
        provider: meta.id,
        text: item.name,
        subtext: item.subtext,
        icon: item.icon,
        score: score,
        positions: positions,
        actions: item.actions,
        desktopId: item.desktopId,
        sortKey: item.sortKey
    }
}

function query(text, env) {
    var items = itemsOf(env)
    var history = env.history
    var now = env.now
    var rows = []
    if (text === "") {
        for (var index = 0; index < items.length; index++) {
            var item = items[index]
            rows.push(rowOf(item, history ? history.emptyQueryRank(item.key, now) : 0, []))
        }
        return rows
    }
    var prepared = env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
    for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        var candidate = items[itemIndex]
        var match = env.matcher.score(prepared, candidate.fields, MATCH_OPTIONS)
        if (match.score < MIN_SCORE) continue
        var score = match.score + (history ? history.boost(text, candidate.key, now) : 0)
        rows.push(rowOf(candidate, score, match.field === 0 ? match.positions : []))
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var desktopId = safeString(row.desktopId)
    if (desktopId === "") return null
    var action = safeString(actionId)
    if (action === "" || action === LAUNCH_ACTION.id) return { type: "app.launch", desktopId: desktopId }
    if (action.indexOf(ACTION_PREFIX) !== 0) return null
    var known = false
    for (var index = 0; index < row.actions.length; index++) {
        if (row.actions[index].id === action) known = true
    }
    if (!known) return null
    return { type: "app.launch", desktopId: desktopId, actionId: action.slice(ACTION_PREFIX.length) }
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        prepare: prepare,
        query: query,
        activate: activate,
        MIN_SCORE: MIN_SCORE
    }
}
