// Entries and keywords mirror the Walker power menu in
// home/desktop/wayland/walker.nix.

var meta = { id: "power", label: "Power", icon: "system-shutdown" }

var ENTRIES = [
    { action: "lock", text: "Lock", icon: "system-lock-screen", keywords: ["lock", "sleep"] },
    { action: "suspend", text: "Suspend", icon: "system-suspend", keywords: ["sleep", "suspend"] },
    { action: "logout", text: "Logout", icon: "system-log-out", keywords: ["logout", "quit"] },
    { action: "reboot", text: "Reboot", icon: "system-reboot", keywords: ["reboot", "restart"] },
    { action: "poweroff", text: "Shutdown", icon: "system-shutdown", keywords: ["shutdown", "poweroff"] }
]

var ACTIONS = ["lock", "suspend", "logout", "reboot", "poweroff"]

var preparedEntries = null

function safeString(value) {
    if (value === undefined || value === null) return ""
    try {
        return String(value)
    } catch (error) {
        return ""
    }
}

function itemsOf(env) {
    if (preparedEntries) return preparedEntries
    var result = []
    for (var index = 0; index < ENTRIES.length; index++) {
        var entry = ENTRIES[index]
        result.push({
            entry: entry,
            actions: [{ id: entry.action, label: entry.text }],
            fields: [env.matcher.prepare(entry.text), env.matcher.prepare(entry.keywords.join(" "))]
        })
    }
    preparedEntries = result
    return result
}

function query(text, env) {
    var items = itemsOf(env)
    var prepared = text === "" ? null
        : env.query && env.query.text === text ? env.query : env.matcher.prepareQuery(text)
    var rows = []
    for (var index = 0; index < items.length; index++) {
        var item = items[index]
        var score = items.length - index
        var positions = []
        if (prepared) {
            var match = env.matcher.score(prepared, item.fields)
            if (match.score <= 0) continue
            // Equal matches keep menu order.
            score = match.score * 10 + items.length - index
            positions = match.field === 0 ? match.positions : []
        }
        rows.push({
            key: meta.id + ":" + item.entry.action,
            provider: meta.id,
            text: item.entry.text,
            subtext: "",
            icon: item.entry.icon,
            score: score,
            positions: positions,
            actions: item.actions,
            action: item.entry.action
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id) return null
    var action = safeString(row.action)
    var requested = safeString(actionId)
    if (requested !== "" && requested !== action) return null
    if (ACTIONS.indexOf(action) < 0) return null
    return { type: "session", action: action }
}

if (typeof module !== "undefined") {
    module.exports = {
        meta: meta,
        query: query,
        activate: activate,
        ENTRIES: ENTRIES
    }
}
