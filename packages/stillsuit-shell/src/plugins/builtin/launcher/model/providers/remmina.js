var meta = { id: "remmina", label: "Connections", icon: "shell:window", snapshot: "connections" }

function prepare(connections, matcher) {
    return (connections || []).filter(function(item) {
        return item && typeof item.path === "string" && item.path.charAt(0) === "/" && item.path.indexOf("\u0000") < 0
    }).map(function(item) {
        return {
            path: item.path,
            name: String(item.name || ""),
            group: String(item.group || ""),
            protocol: String(item.protocol || ""),
            server: String(item.server || ""),
            fields: [matcher.prepare(String(item.name || "")), matcher.prepare(String(item.group || "")),
                matcher.prepare(String(item.server || "")), matcher.prepare(String(item.protocol || ""))]
        }
    })
}

function query(text, env) {
    var items = env.prepared.remmina || []
    var rows = []
    for (var index = 0; index < items.length; index++) {
        var item = items[index]
        var match = text ? env.matcher.score(env.query, item.fields) : null
        if (match && match.score <= 0) continue
        rows.push({
            key: "remmina:" + item.path, provider: meta.id, text: item.name,
            subtext: [item.group, item.protocol, item.server].filter(function(value) { return value !== "" }).join(" · "),
            icon: meta.icon, score: match ? match.score : 0, sortKey: item.name.toLowerCase(),
            positions: match && match.field === 0 ? match.positions : [],
            actions: [{ id: "connect", label: "Connect" }], path: item.path
        })
    }
    return rows
}

function activate(row, actionId) {
    if (!row || row.provider !== meta.id || (actionId && actionId !== "connect")) return null
    return { type: "remmina.connect", path: row.path }
}

if (typeof module !== "undefined") {
    module.exports = { meta: meta, prepare: prepare, query: query, activate: activate }
}
